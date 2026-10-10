import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'package:vadesi/models/payment.dart';
import 'package:vadesi/services/reminder_plan.dart';

DueItem item(int id, DateTime due, {int? planId, bool paid = false}) {
  final plan = PaymentPlan(id: planId ?? id, title: 'Test', party: '', iban: '',
      note: '', kind: PaymentKind.single, direction: PaymentDirection.outgoing,
      category: InvoiceCategory.other, amountCents: 10000, count: 1,
      anchorDay: due.day, startDate: due, createdAt: due);
  return DueItem(id: id, planId: plan.id, sequence: id, dueDate: due,
      amountCents: 10000, paidAt: paid ? due : null, plan: plan);
}

void main() {
  tzdata.initializeTimeZones();
  final istanbul = tz.getLocation('Europe/Istanbul');
  final now = tz.TZDateTime(istanbul, 2026, 10, 10, 8);

  test('future payment includes next-day overdue alert without reopening app', () {
    final events = planReminders([item(1, DateTime(2026, 10, 20))], now: now, hour: 9);
    expect(events.map((e) => e.when.day), [15, 19, 20, 21]);
    expect(events.last.title, 'Vade tarihi geçti');
    expect(events.every((e) => e.when.hour == 9), isTrue);
  });
  test('overdue payment is retained and scheduled at next selected hour', () {
    final events = planReminders([item(1, DateTime(2026, 10, 1))], now: now, hour: 9);
    expect(events.single.when, tz.TZDateTime(istanbul, 2026, 10, 10, 9));
    expect(events.single.urgent, isTrue);
  });
  test('after reminder hour overdue event moves to tomorrow', () {
    final events = planReminders([item(1, DateTime(2026, 10, 1))],
        now: tz.TZDateTime(istanbul, 2026, 10, 10, 10), hour: 9);
    expect(events.single.when, tz.TZDateTime(istanbul, 2026, 10, 11, 9));
  });
  test('today after reminder hour still has next-day overdue event', () {
    final events = planReminders([item(1, DateTime(2026, 10, 10))],
        now: tz.TZDateTime(istanbul, 2026, 10, 10, 10), hour: 9);
    expect(events.single.when.day, 11);
  });
  test('paid and deleted items have no pending events', () {
    expect(planReminders([item(1, DateTime(2026, 10, 1), paid: true)],
        now: now, hour: 9), isEmpty);
    expect(planReminders([], now: now, hour: 9), isEmpty);
  });
  test('unsorted installments select earliest unpaid per plan', () {
    final events = planReminders([
      item(2, DateTime(2026, 11, 1), planId: 1),
      item(1, DateTime(2026, 10, 1), planId: 1),
    ], now: now, hour: 9);
    expect(events.single.id, 14);
  });
  test('nearest events respect iOS pending notification limit', () {
    final events = planReminders(List.generate(100,
        (i) => item(i + 1, DateTime(2026, 10, 20 + i))),
        now: now, hour: 9);
    expect(events.length, 60);
    expect(events.map((e) => e.id).toSet().length, 60);
    for (var i = 1; i < events.length; i++) {
      expect(events[i].when.isBefore(events[i - 1].when), isFalse);
    }
  });
  test('rescheduling replaces old due and overdue dates', () {
    final events = planReminders([item(1, DateTime(2026, 11, 1))], now: now, hour: 18);
    expect(events.last.when, tz.TZDateTime(istanbul, 2026, 11, 2, 18));
    expect(() => planReminders([], now: now, hour: 24), throwsArgumentError);
  });
}
