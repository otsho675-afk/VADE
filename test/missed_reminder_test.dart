import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vadesi/services/reminder_plan.dart';
import 'reminder_plan_test.dart' show item;

void main() {
  tzdata.initializeTimeZones();
  final zone = tz.getLocation('Europe/Istanbul');
  final now = tz.TZDateTime(zone, 2026, 10, 10, 12);
  test('tomorrow payment added after 9am gets warning now', () {
    expect(
      missedReminder(item(1, DateTime(2026, 10, 11)), now: now, hour: 9)?.title,
      'Dikkat: Yarın vade günü',
    );
  });
  test('today payment added after 9am gets warning now', () {
    expect(
      missedReminder(item(1, DateTime(2026, 10, 10)), now: now, hour: 9)?.title,
      'Bugün son ödeme günü',
    );
  });
  test('before selected hour no early catch-up for tomorrow or today', () {
    expect(
      missedReminder(item(1, DateTime(2026, 10, 11)), now: now, hour: 18),
      isNull,
    );
    expect(
      missedReminder(item(1, DateTime(2026, 10, 10)), now: now, hour: 18),
      isNull,
    );
  });
  test('upcoming window gives accurate remaining days', () {
    expect(
      missedReminder(item(1, DateTime(2026, 10, 13)), now: now, hour: 9)?.body,
      contains('3 gün'),
    );
    expect(
      missedReminder(item(1, DateTime(2026, 10, 16)), now: now, hour: 9),
      isNull,
    );
  });
  test('paid items do not alert', () {
    expect(
      missedReminder(
        item(1, DateTime(2026, 10, 11), paid: true),
        now: now,
        hour: 9,
      ),
      isNull,
    );
  });
}
