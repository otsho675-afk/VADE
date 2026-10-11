import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/payment.dart';
import 'reminder_plan.dart';

class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();
  bool _ready = false;
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
    try {
      _ready =
          await _plugin.initialize(
            const InitializationSettings(android: android, iOS: ios),
          ) ??
          false;
    } catch (_) {
      // Desktop/web emulator without a native notification host: the ledger still works.
      _ready = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null)
      return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
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
      await _plugin.cancelAll();
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
    final pending = await _plugin.pendingNotificationRequests();
    for (final id in {...previous, ...pending.map((r) => r.id.toString())}) {
      if (!ids.contains(id)) await _plugin.cancel(int.parse(id));
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
        await _plugin.show(
          missed.id,
          missed.title,
          missed.body,
          _urgentDetails,
        );
        await prefs.setString(key, stamp);
      }
    }
  }

  Future<bool> permissionGranted() async {
    if (!_ready) return false;
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null)
      return await android.areNotificationsEnabled() ?? false;
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
    if (!await requestPermissions()) {
      throw StateError(
        'Bildirim izni verilmedi. Telefon ayarlarından izin verin.',
      );
    }
    await _plugin.show(
      2147483646,
      'VADESİ test bildirimi',
      'Telefon bildirim bağlantısı çalışıyor.',
      _urgentDetails,
    );
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
