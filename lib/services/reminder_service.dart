import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/payment.dart';

class ReminderService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  /// Default regional timezone for the Turkish-language edition.
  /// Times are scheduled on the device by the OS, not via an external server.
  Future<void> initialize() async {
    if (kIsWeb) return;
    tzdata.initializeTimeZones();
    tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    try {
      _ready = await _plugin.initialize(
        const InitializationSettings(android: android, iOS: ios),
      ) ?? false;
    } catch (_) {
      // Desktop/web emulator without a native notification host: the ledger still works.
      _ready = false;
    }
  }

  Future<bool> requestPermissions() async {
    if (!_ready) return false;
    final android = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) return await android.requestNotificationsPermission() ?? false;
    final ios = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    }
    return false;
  }

  Future<void> sync(List<DueItem> allItems, {required bool enabled, required int hour}) async {
    if (!_ready) return;
    await _plugin.cancelAll();
    if (!enabled) return;
    // Only the next unpaid payment from each plan is actionable.
    final nextByPlan = <int, DueItem>{};
    for (final item in allItems) {
      if (item.isPaid) continue;
      nextByPlan.putIfAbsent(item.planId, () => item);
    }
    final prioritized = nextByPlan.values.toList()
      ..sort((a, b) => a.dueDate.compareTo(b.dueDate));
    // Apple limits pending local notifications. Keep 3 notifications for
    // the nearest 20 payments (60 total), leaving a few OS slots free.
    for (final item in prioritized.take(20)) {
      await _scheduleItem(item, hour);
    }
  }

  Future<void> _scheduleItem(DueItem item, int hour) async {
    final now = tz.TZDateTime.now(tz.local);
    final due = tz.TZDateTime(tz.local, item.dueDate.year, item.dueDate.month, item.dueDate.day, hour);
    final amount = formatCompactMoney(item.amountCents);
    final label = item.plan.direction == PaymentDirection.outgoing ? 'ödemeniz' : 'tahsilatınız';
    await _schedule(
      item.id * 10 + 1,
      due.subtract(const Duration(days: 5)), now,
      'Yaklaşan ${item.plan.kind.label.toLowerCase()}',
      '${item.plan.title}: $amount tutarındaki $label için 5 gün kaldı.',
      urgent: false,
    );
    await _schedule(
      item.id * 10 + 2,
      due.subtract(const Duration(days: 1)), now,
      'Dikkat: Yarın vade günü',
      '${item.plan.title}: $amount tutarındaki $label yarın. Ödeme durumunu kontrol edin.',
      urgent: true,
    );
    await _schedule(
      item.id * 10 + 3,
      due, now,
      'Bugün son ödeme günü',
      '${item.plan.title}: $amount tutarındaki $label bugün vadesinde.',
      urgent: true,
    );
  }

  Future<void> _schedule(int id, tz.TZDateTime when, tz.TZDateTime now,
      String title, String body, {required bool urgent}) async {
    if (!when.isAfter(now)) return;
    const normal = AndroidNotificationDetails(
      'vadesi_normal', 'Ödeme hatırlatmaları',
      channelDescription: 'Vadesinden 5 gün önceki normal bildirimler',
      importance: Importance.defaultImportance, priority: Priority.defaultPriority,
    );
    const risk = AndroidNotificationDetails(
      'vadesi_risk', 'Vade uyarıları',
      channelDescription: 'Vade günü ve bir gün önceki dikkat bildirimleri',
      importance: Importance.high, priority: Priority.high,
    );
    await _plugin.zonedSchedule(
      id, title, body, when,
      NotificationDetails(
        android: urgent ? risk : normal,
        iOS: const DarwinNotificationDetails(presentAlert: true, presentBadge: true, presentSound: true),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
    );
  }
}
