import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/services/reminder_service.dart';
import 'reminder_plan_test.dart' show item;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('dexterous.com/flutter/local_notifications');
  const iosPermissionChannel = MethodChannel('vadesi/notifications');
  final calls = <MethodCall>[];
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    AndroidFlutterLocalNotificationsPlugin.registerWith();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize' ||
              call.method == 'requestNotificationsPermission')
            return true;
          if (call.method == 'areNotificationsEnabled') return true;
          if (call.method == 'checkPermissions') return {'isEnabled': true};
          if (call.method == 'pendingNotificationRequests') return [];
          return null;
        });
  });
  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosPermissionChannel, null);
  });
  test(
    'overdue item reaches native scheduler and paid item cancels it',
    () async {
      final service = ReminderService();
      await service.initialize();
      expect(await service.requestPermissions(), isTrue);
      final due = DateTime.now().subtract(const Duration(days: 10));
      await service.sync([item(1, due)], enabled: true, hour: 9);
      final scheduled = calls.where((c) => c.method == 'zonedSchedule').single;
      expect(scheduled.arguments['id'], 14);
      expect(scheduled.arguments['title'], 'Vade tarihi geçti');
      calls.clear();
      await service.sync([item(1, due, paid: true)], enabled: true, hour: 9);
      expect(
        calls.where((c) => c.method == 'cancel').single.arguments['id'],
        14,
      );
    },
  );
  test('iOS schedules overdue alert and clears it when disabled', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final service = ReminderService();
    await service.initialize();
    calls.clear();
    await service.sync([item(1, DateTime(2020))], enabled: true, hour: 9);
    expect(
      calls.where((c) => c.method == 'zonedSchedule').single.arguments['id'],
      14,
    );
    calls.clear();
    await service.sync([], enabled: false, hour: 9);
    expect(calls.map((c) => c.method), ['cancelAll']);
  });
  test(
    'missed overdue alert is shown immediately only once across service restart',
    () async {
      final service = ReminderService();
      await service.initialize();
      final items = [item(1, DateTime(2020))];
      await service.sync(items, enabled: true, hour: 9);
      expect(calls.where((c) => c.method == 'show').length, 1);
      calls.clear();
      final restarted = ReminderService();
      await restarted.initialize();
      await restarted.sync(items, enabled: true, hour: 9);
      expect(calls.where((c) => c.method == 'show'), isEmpty);
      expect(calls.where((c) => c.method == 'cancelAll'), isEmpty);
    },
  );
  test(
    'tomorrow warning reaches native show once after reminder hour',
    () async {
      final service = ReminderService();
      await service.initialize();
      final tomorrow = DateTime.now().toUtc().add(
        const Duration(hours: 3, days: 1),
      );
      final items = [
        item(1, DateTime(tomorrow.year, tomorrow.month, tomorrow.day)),
      ];
      await service.sync(items, enabled: true, hour: 0);
      expect(
        calls.where((c) => c.method == 'show').single.arguments['title'],
        'Dikkat: Yarın vade günü',
      );
      calls.clear();
      await service.sync(items, enabled: true, hour: 0);
      expect(calls.where((c) => c.method == 'show'), isEmpty);
    },
  );
  test('iOS native notification request, status and settings link work', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final nativeCalls = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosPermissionChannel, (call) async {
          nativeCalls.add(call.method);
          if (call.method == 'requestPermission') return true;
          if (call.method == 'authorizationStatus') return 'authorized';
          if (call.method == 'openSettings') return true;
          return null;
        });

    final service = ReminderService();
    await service.initialize();
    expect(await service.requestPermissions(), isTrue);
    expect(await service.permissionGranted(), isTrue);
    expect(await service.openIosNotificationSettings(), isTrue);
    expect(nativeCalls, [
      'authorizationStatus', // native bridge detection during initialize
      'requestPermission',
      'authorizationStatus',
      'openSettings',
    ]);
  });

  test('iOS denied permission gives an actionable explanation', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosPermissionChannel, (call) async {
          if (call.method == 'requestPermission') return false;
          if (call.method == 'authorizationStatus') return 'denied';
          return null;
        });

    final service = ReminderService();
    await service.initialize();
    expect(await service.requestPermissions(), isFalse);
    expect(await service.permissionFailureMessage(), contains('Ayarlar > Bildirimler'));
  });

  test('iOS works through native bridge even if Flutter notification plugin fails', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final nativeCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosPermissionChannel, (call) async {
          nativeCalls.add(call);
          switch (call.method) {
            case 'authorizationStatus':
              return 'authorized';
            case 'requestPermission':
              return true;
            case 'pendingIds':
              return <int>[];
            case 'openSettings':
              return true;
            case 'showNow':
            case 'schedule':
            case 'cancelIds':
            case 'cancelAll':
              return null;
          }
          return null;
        });
    // The installed Flutter plugin cannot initialize: native notifications
    // must still schedule and deliver without touching the plugin channel.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          if (call.method == 'initialize') throw PlatformException(code: 'UNAVAILABLE');
          return null;
        });

    final service = ReminderService();
    await service.initialize();
    expect(calls.where((c) => c.method == 'initialize'), isEmpty);
    expect(await service.requestPermissions(), isTrue);
    expect(await service.permissionGranted(), isTrue);
    final due = DateTime.now().subtract(const Duration(days: 10));
    await service.sync([item(1, due)], enabled: true, hour: 9);
    final scheduled = nativeCalls.where((c) => c.method == 'schedule').single;
    expect(scheduled.arguments['id'], 14);
    expect(scheduled.arguments['title'], 'Vade tarihi geçti');
    expect(scheduled.arguments['epochMillis'], isA<int>());

    await service.sendTestNotification();
    expect(nativeCalls.where((c) => c.method == 'showNow').last.arguments['id'], 2147483646);

    await service.sync([], enabled: false, hour: 9);
    expect(nativeCalls.where((c) => c.method == 'cancelAll'), hasLength(1));
    expect(calls.where((c) => c.method == 'show' || c.method == 'zonedSchedule'), isEmpty);
  });

  test('iOS native reminders cancel obsolete due items', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    IOSFlutterLocalNotificationsPlugin.registerWith();
    final nativeCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(iosPermissionChannel, (call) async {
          nativeCalls.add(call);
          if (call.method == 'authorizationStatus') return 'authorized';
          if (call.method == 'pendingIds') return <int>[14, 24];
          if (call.method == 'requestPermission') return true;
          return null;
        });
    final service = ReminderService();
    await service.initialize();
    await service.sync([item(1, DateTime(2020))], enabled: true, hour: 9);
    final cancelled = nativeCalls.where((c) => c.method == 'cancelIds').single;
    expect(cancelled.arguments['ids'], contains(24));
    expect(cancelled.arguments['ids'], isNot(contains(14)));
  });

  test('test button submits an immediate notification', () async {
    final service = ReminderService();
    await service.initialize();
    await service.sendTestNotification();
    expect(
      calls.where((c) => c.method == 'show').single.arguments['title'],
      'VADESİ test bildirimi',
    );
  });
  test(
    'revoked phone permission is surfaced instead of silent scheduling',
    () async {
      final service = ReminderService();
      await service.initialize();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            channel,
            (call) async =>
                call.method == 'areNotificationsEnabled' ? false : null,
          );
      await expectLater(
        service.sync([item(1, DateTime(2020))], enabled: true, hour: 9),
        throwsA(isA<StateError>()),
      );
    },
  );
  test('switching reminders off cancels pending notifications', () async {
    final service = ReminderService();
    await service.initialize();
    calls.clear();
    await service.sync([item(1, DateTime(2030))], enabled: false, hour: 9);
    expect(calls.map((c) => c.method), ['cancelAll']);
  });
  test('scheduler failure surfaces and next sync can recover', () async {
    final service = ReminderService();
    await service.initialize();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'zonedSchedule')
            throw PlatformException(code: 'schedule_failed');
          if (call.method == 'areNotificationsEnabled') return true;
          if (call.method == 'checkPermissions') return {'isEnabled': true};
          if (call.method == 'pendingNotificationRequests') return [];
          return null;
        });
    await expectLater(
      service.sync([item(1, DateTime(2030))], enabled: true, hour: 9),
      throwsA(isA<PlatformException>()),
    );
    await service.sync([], enabled: false, hour: 9);
  });
  test('exact alarm permission selects precise native scheduling', () async {
    final service = ReminderService();
    await service.initialize();
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'areNotificationsEnabled' || call.method == 'canScheduleExactNotifications') return true;
      if (call.method == 'pendingNotificationRequests') return [];
      return null;
    });
    await service.sync([item(1, DateTime(2030))], enabled: true, hour: 9);
    expect(service.exactTimingAllowed, isTrue);
    expect(calls.where((c) => c.method == 'zonedSchedule'), isNotEmpty);
  });
}