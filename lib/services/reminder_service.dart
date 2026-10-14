import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/payment.dart';
import 'reminder_plan.dart';

class ReminderService {
  static const MethodChannel _iosPermissions = MethodChannel('vadesi/notifications');
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
  bool _nativeIos = false;
  String? _initializationError;
  bool exactTimingAllowed = false;
  bool get supported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Default regional timezone for the Turkish-language edition.
  /// Times are scheduled on the device by the OS, not via an external server.
  Future<void> initialize() async {
    if (!supported) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    // VADESİ ships its own UNUserNotificationCenter bridge for iOS.
    // Plugin initialization may return false even while system authorization
    // is granted, so prefer the native service when the bridge is available.
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      try {
        final status = await _iosPermissions.invokeMethod<String>('authorizationStatus');
        if (status != null) {
          _nativeIos = true;
          _ready = true;
          _initializationError = null;
          return;
        }
      } on MissingPluginException {
        // Existing tests and older host apps use flutter_local_notifications.
      } on PlatformException catch (error) {
        debugPrint('Native iOS notification bridge unavailable: $error');
      }
    }
    try {
      _initializationError = null;
      _ready =
          await _plugin.initialize(
            const InitializationSettings(android: android, iOS: ios),
          ) ??
          false;
      if (_ready && defaultTargetPlatform == TargetPlatform.android) {
        // FCM targets this same channel even if no local reminder is scheduled.
        // Channel importance cannot be changed after the OS creates it.
        try {
          await _plugin
              .resolvePlatformSpecificImplementation<
                  AndroidFlutterLocalNotificationsPlugin>()
              ?.createNotificationChannel(const AndroidNotificationChannel(
                'vadesi_risk',
                'Vade uyarıları',
                description: 'Vade öncesi, vade günü ve gecikme uyarıları',
                importance: Importance.high,
              ));
        } catch (error) {
          debugPrint('Android notification channel setup failed: $error');
        }
      }
    } catch (error) {
      // Keep the local ledger working, but never report a plugin failure as a user denial.
      _initializationError = '$error';
      debugPrint('Notification initialization failed: $error');
      _ready = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!supported) return false;
    if (!_ready) await initialize();
    if (!_ready) return false;
    if (_nativeIos) {
      return await _iosPermissions.invokeMethod<bool>('requestPermission') ?? false;
    }

    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }

    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      // Request directly from iOS. Unlike the plugin's false return value,
      // the system authorization status is independently inspectable.
      try {
        return await _iosPermissions.invokeMethod<bool>('requestPermission') ??
            false;
      } on MissingPluginException {
        // Allow iOS builds without the native bridge to keep working.
      } on PlatformException catch (error) {
        debugPrint('Native notification permission request failed: $error');
      }
      return await ios.requestPermissions(
            alert: true, badge: true, sound: true,
          ) ?? false;
    }
    return false;
  }

  Future<String?> _iosAuthorizationStatus() async {
    if (defaultTargetPlatform != TargetPlatform.iOS || kIsWeb) return null;
    try {
      return await _iosPermissions.invokeMethod<String>('authorizationStatus');
    } on MissingPluginException {
      return null;
    } on PlatformException catch (error) {
      debugPrint('Could not check native notification permission: $error');
      return null;
    }
  }

  Future<String> permissionFailureMessage() async {
    if (!_ready) {
      return 'iPhone bildirim hizmeti başlatılamadı. '
          'Uygulamayı kapatıp yeniden açın. '
          'Sorun sürerse uygulamanın güncel sürümünü yükleyin.'
          '${_initializationError == null ? '' : ' (Teknik hata: $_initializationError)'}';
    }
    final status = await _iosAuthorizationStatus();
    if (status == 'denied') {
      return 'iPhone bildirim izni kapalı. '
          'Ayarlar > Bildirimler > VADESİ bölümünden izin verin.';
    }
    if (status == 'notDetermined') {
      return 'iPhone henüz bildirim izni istemedi. '
          'Ödeme bildirimlerini açıp izin penceresini onaylayın.';
    }
    if (status == 'authorized' || status == 'provisional') {
      return 'Bildirim izni açık görünüyor fakat bildirim servisi '
          'işlemi tamamlayamadı. Uygulamayı yeniden açın.';
    }
    return 'Bildirim izni alınamadı. '
        'Ayarlar > Bildirimler > VADESİ bölümünü kontrol edin.';
  }

  Future<bool> openIosNotificationSettings() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
    try {
      return await _iosPermissions.invokeMethod<bool>('openSettings') ?? false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  Future<void> _pendingSync = Future<void>.value();

  Future<void> sync(
    List<DueItem> allItems, {
    required bool enabled,
    required int hour,
  }) {
    final snapshot = List<DueItem>.of(allItems);
    final next = _pendingSync.then(
      (_) => _sync(snapshot, enabled: enabled, hour: hour),
    );
    _pendingSync = next.catchError((Object _) {});
    return next;
  }

  Future<void> _sync(
    List<DueItem> allItems, {
    required bool enabled,
    required int hour,
  }) async {
    if (!_ready) {
      if (enabled && supported)
        throw StateError(
          'Bildirim hizmeti başlatılamadı. Uygulamayı yeniden açın.',
        );
      return;
    }
    final prefs = await SharedPreferences.getInstance();
    if (!enabled) {
      if (_nativeIos) {
        await _iosPermissions.invokeMethod<void>('cancelAll');
      } else {
        await _plugin.cancelAll();
      }
      await prefs.remove('reminder_ids');
      return;
    }
    if (!await permissionGranted()) {
      throw StateError(
        'Telefonun bildirim izni kapalı. Telefon ayarlarından VADESİ bildirimlerine izin verin.',
      );
    }
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    exactTimingAllowed = android != null && (await android.canScheduleExactNotifications() ?? false);
    final now = tz.TZDateTime.now(tz.local);
    final planned = planReminders(allItems, now: now, hour: hour);
    final ids = planned.map((r) => r.id.toString()).toSet();
    final previous = prefs.getStringList('reminder_ids') ?? [];
    final pendingIds = _nativeIos
        ? (await _iosPermissions.invokeListMethod<int>('pendingIds') ?? <int>[])
        : (await _plugin.pendingNotificationRequests()).map((r) => r.id).toList();
    final obsolete = {...previous, ...pendingIds.map((id) => id.toString())}
        .where((id) => !ids.contains(id))
        .map(int.parse)
        .toList();
    if (_nativeIos) {
      if (obsolete.isNotEmpty) {
        await _iosPermissions.invokeMethod<void>('cancelIds', {'ids': obsolete});
      }
    } else {
      for (final id in obsolete) {
        await _plugin.cancel(id);
      }
    }
    await prefs.setStringList('reminder_ids', ids.toList());
    for (final reminder in planned) {
      await _schedule(
        reminder.id,
        reminder.when,
        now,
        reminder.title,
        reminder.body,
        urgent: reminder.urgent,
      );
      if (reminder.id % 10 != 4) continue;
      final item = allItems.firstWhere((i) => i.id == reminder.id ~/ 10);
      final missed = missedReminder(item, now: now, hour: hour);
      if (missed == null) continue;
      final key = 'catchup_shown_${item.id}';
      final stamp = '${sqlDate(item.dueDate)}:${missed.title}';
      if (prefs.getString(key) != stamp) {
        if (_nativeIos) {
          await _iosPermissions.invokeMethod<void>('showNow', {
            'id': missed.id, 'title': missed.title, 'body': missed.body,
          });
        } else {
          await _plugin.show(
            missed.id,
            missed.title,
            missed.body,
            _urgentDetails,
          );
        }
        await prefs.setString(key, stamp);
      }
    }
  }

  Future<bool> permissionGranted() async {
    if (!_ready) return false;
    if (_nativeIos) {
      final status = await _iosAuthorizationStatus();
      return status == 'authorized' || status == 'provisional';
    }
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      return await android.areNotificationsEnabled() ?? false;
    }
    final status = await _iosAuthorizationStatus();
    if (status != null) {
      return status == 'authorized' || status == 'provisional';
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    return (await ios?.checkPermissions())?.isEnabled ?? false;
  }

  static const _urgentDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'vadesi_risk',
      'Vade uyarıları',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(presentAlert: true, presentSound: true),
  );

  Future<bool> requestExactTiming() async {
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android == null) return false;
    exactTimingAllowed = await android.requestExactAlarmsPermission() ?? false;
    return exactTimingAllowed;
  }

  Future<void> sendTestNotification() async {
    // The user granted permission from onboarding or the single settings toggle.
    // Testing a notification must not trigger another iOS authorization prompt.
    if (!await permissionGranted()) {
      throw StateError(await permissionFailureMessage());
    }
    if (_nativeIos) {
      await _iosPermissions.invokeMethod<void>('showNow', {
        'id': 2147483646,
        'title': 'VADESİ test bildirimi',
        'body': 'Telefon bildirim bağlantısı çalışıyor.',
      });
    } else {
      await _plugin.show(
        2147483646,
        'VADESİ test bildirimi',
        'Telefon bildirim bağlantısı çalışıyor.',
        _urgentDetails,
      );
    }
  }

  Future<void> _schedule(
    int id,
    tz.TZDateTime when,
    tz.TZDateTime now,
    String title,
    String body, {
    required bool urgent,
  }) async {
    if (!when.isAfter(now)) return;
    if (_nativeIos) {
      await _iosPermissions.invokeMethod<void>('schedule', {
        'id': id,
        'epochMillis': when.millisecondsSinceEpoch,
        'title': title,
        'body': body,
        'urgent': urgent,
      });
      return;
    }
    const normal = AndroidNotificationDetails(
      'vadesi_normal',
      'Ödeme hatırlatmaları',
      channelDescription: 'Vadesinden 5 gün önceki normal bildirimler',
      importance: Importance.defaultImportance,
      priority: Priority.defaultPriority,
    );
    const risk = AndroidNotificationDetails(
      'vadesi_risk',
      'Vade uyarıları',
      channelDescription: 'Vade öncesi, vade günü ve gecikme bildirimleri',
      importance: Importance.high,
      priority: Priority.high,
    );
    await _plugin.zonedSchedule(
      id,
      title,
      body,
      when,
      NotificationDetails(
        android: urgent ? risk : normal,
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      ),
      androidScheduleMode: exactTimingAllowed ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle,
    );
  }
}
