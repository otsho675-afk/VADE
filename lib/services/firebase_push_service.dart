import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

import '../models/payment.dart';
import 'cloud_config.dart';
import 'reminder_plan.dart';

/// Notification payloads are displayed by Android/iOS even when UI is stopped.
/// This handler also supports any future data-only background work.
@pragma('vm:entry-point')
Future<void> vadesiFirebaseBackgroundHandler(RemoteMessage message) async {
  if (!CloudConfig.configured) return;
  await Firebase.initializeApp(options: CloudConfig.options);
}

/// Firebase delivery complements (but never replaces) offline local alarms.
class FirebasePushService with WidgetsBindingObserver {
  bool get supported => !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  bool _started = false;
  bool _disposed = false;
  bool _enabled = false;
  String? _deviceId;
  String? _fcmToken;
  List<PlannedReminder> _planned = const [];
  Future<void> _pending = Future<void>.value();
  StreamSubscription<User?>? _auth;
  StreamSubscription<String>? _tokenRefresh;
  StreamSubscription<RemoteMessage>? _foregroundMessages;

  Future<void> initialize() async {
    if (_started || !supported || !CloudConfig.configured) return;
    _started = true;
    try {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      final prefs = await SharedPreferences.getInstance();
      var id = prefs.getString('vadesi_push_device_id');
      if (id == null || !RegExp(r'^[a-zA-Z0-9_-]{22}$').hasMatch(id)) {
        final random = Random.secure();
        id = base64UrlEncode(List<int>.generate(16, (_) => random.nextInt(256)))
            .replaceAll('=', '');
        await prefs.setString('vadesi_push_device_id', id);
      }
      _deviceId = id;
      FirebaseMessaging.onBackgroundMessage(vadesiFirebaseBackgroundHandler);
      _auth = FirebaseAuth.instance.authStateChanges().listen((_) {
        unawaited(_enqueue());
      });
      _tokenRefresh = FirebaseMessaging.instance.onTokenRefresh.listen((token) {
        _fcmToken = token;
        unawaited(_enqueue());
      });
      // Local notifications already show foreground alarms.
      _foregroundMessages = FirebaseMessaging.onMessage.listen((_) {});
      WidgetsBinding.instance.addObserver(this);
      await _enqueue();
    } catch (error) {
      debugPrint('FCM initialization could not finish: $error');
    }
  }

  Future<void> updateSchedule(List<DueItem> items, {
    required bool enabled,
    required int hour,
  }) {
    _enabled = enabled;
    if (enabled) {
      tzdata.initializeTimeZones();
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
      _planned = planReminders(items, now: tz.TZDateTime.now(tz.local), hour: hour);
    } else {
      _planned = const [];
    }
    return _enqueue();
  }

  Future<void> _enqueue() {
    if (!_started || _disposed || _deviceId == null) return Future<void>.value();
    // Serialize writes so older schedule snapshots cannot overwrite new ones.
    _pending = _pending.then((_) => _publish()).catchError((Object error) {
      debugPrint('FCM schedule sync unavailable: $error');
    });
    return _pending;
  }

  Future<void> _publish() async {
    if (_disposed) return;
    final user = FirebaseAuth.instance.currentUser;
    final device = _deviceId;
    if (user == null || device == null) return;
    final doc = FirebaseFirestore.instance.collection('push_devices')
        .doc('${user.uid}_$device');
    if (!_enabled) {
      await doc.delete();
      return;
    }

    // iOS requires an APNs token before calling FirebaseMessaging.getToken.
    if (defaultTargetPlatform == TargetPlatform.iOS &&
        await FirebaseMessaging.instance.getAPNSToken() == null) {
      return; // Will retry on app resume / refresh.
    }
    final token = _fcmToken ?? await FirebaseMessaging.instance.getToken();
    if (token == null || token.isEmpty) return;
    _fcmToken = token;
    await doc.set({
      'uid': user.uid,
      'fcmToken': token,
      'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      'enabled': true,
      // Indexed cursor: Spark scheduler queries only devices with due alarms.
      'nextDueAtMillis': _planned.isEmpty
          ? 253402300799000
          : _planned.first.when.millisecondsSinceEpoch,
      'reminders': _planned.map((r) => {
        'id': r.id,
        'atMillis': r.when.millisecondsSinceEpoch,
        'title': r.title,
        // Never place merchant names, amounts or personal financial details in FCM.
        'body': 'Ödeme veya tahsilat durumunuzu kontrol edin.',
      }).toList(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Call while the current user is authenticated; never leave old account
  /// notification registrations behind on the phone during explicit logout.
  Future<void> unregister() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final device = _deviceId;
    if (!_started || uid == null || device == null) return;
    await _pending;
    await FirebaseFirestore.instance.collection('push_devices')
        .doc('${uid}_$device').delete();
    _fcmToken = null;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(_enqueue());
  }

  void dispose() {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    unawaited(_auth?.cancel());
    unawaited(_tokenRefresh?.cancel());
    unawaited(_foregroundMessages?.cancel());
  }
}
