import 'package:timezone/timezone.dart' as tz;
import '../models/payment.dart';

class PlannedReminder {
  final int id;
  final tz.TZDateTime when;
  final String title, body;
  final bool urgent;
  const PlannedReminder(this.id, this.when, this.title, this.body, this.urgent);
}

/// Pure planning logic shared by both mobile platforms.
List<PlannedReminder> planReminders(
  List<DueItem> items, {
  required tz.TZDateTime now,
  required int hour,
}) {
  if (hour < 0 || hour > 23) throw ArgumentError.value(hour, 'hour');
  final unpaid = items.where((item) => !item.isPaid).toList()
    ..sort((a, b) {
      final date = a.dueDate.compareTo(b.dueDate);
      return date == 0 ? a.id.compareTo(b.id) : date;
    });
  final nextByPlan = <int, DueItem>{};
  for (final item in unpaid) {
    nextByPlan.putIfAbsent(item.planId, () => item);
  }
  final result = <PlannedReminder>[];
  for (final item in nextByPlan.values) {
    final due = tz.TZDateTime(
      now.location,
      item.dueDate.year,
      item.dueDate.month,
      item.dueDate.day,
      hour,
    );
    final amount = formatCompactMoney(item.amountCents);
    final label = item.plan.direction == PaymentDirection.outgoing
        ? 'ödemeniz'
        : 'tahsilatınız';
    final prefix = '${item.plan.title}: $amount tutarındaki $label';
    void add(
      int offset,
      tz.TZDateTime when,
      String title,
      String body,
      bool urgent,
    ) {
      if (when.isAfter(now)) {
        result.add(
          PlannedReminder(item.id * 10 + offset, when, title, body, urgent),
        );
      }
    }

    add(
      1,
      due.subtract(const Duration(days: 5)),
      'Yaklaşan ${item.plan.kind.label.toLowerCase()}',
      '$prefix için 5 gün kaldı.',
      false,
    );
    add(
      2,
      due.subtract(const Duration(days: 1)),
      'Dikkat: Yarın vade günü',
      '$prefix yarın. Ödeme durumunu kontrol edin.',
      true,
    );
    add(3, due, 'Bugün son ödeme günü', '$prefix bugün vadesinde.', true);
    var overdue = tz.TZDateTime(
      now.location,
      due.year,
      due.month,
      due.day + 1,
      hour,
    );
    // A restored/previously overdue payment still gets a future reminder.
    if (!overdue.isAfter(now)) {
      overdue = tz.TZDateTime(now.location, now.year, now.month, now.day, hour);
      if (!overdue.isAfter(now)) {
        overdue = tz.TZDateTime(
          now.location,
          now.year,
          now.month,
          now.day + 1,
          hour,
        );
      }
    }
    add(
      4,
      overdue,
      'Vade tarihi geçti',
      '$prefix gecikti. Ödeme durumunu kontrol edin.',
      true,
    );
  }
  result.sort((a, b) {
    final time = a.when.compareTo(b.when);
    return time == 0 ? a.id.compareTo(b.id) : time;
  });
  // Keep the nearest events within Apple's pending-notification limit.
  return result.take(60).toList();
}

/// Return the currently relevant warning when its original time has passed.
PlannedReminder? missedReminder(
  DueItem item, {
  required tz.TZDateTime now,
  required int hour,
}) {
  if (item.isPaid) return null;
  final due = tz.TZDateTime(
    now.location,
    item.dueDate.year,
    item.dueDate.month,
    item.dueDate.day,
    hour,
  );
  final today = tz.TZDateTime(now.location, now.year, now.month, now.day);
  final dueDay = tz.TZDateTime(now.location, due.year, due.month, due.day);
  final days = dueDay.difference(today).inDays;
  final todayHour = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    hour,
  );
  String title, text;
  if (days < 0 && !due.add(const Duration(days: 1)).isAfter(now)) {
    title = 'Vade tarihi geçti';
    text = 'Vadesi geçti. Ödeme durumunu kontrol edin.';
  } else if (days == 0 && !todayHour.isAfter(now)) {
    title = 'Bugün son ödeme günü';
    text = 'Bugün vadesinde.';
  } else if (days == 1 && !todayHour.isAfter(now)) {
    title = 'Dikkat: Yarın vade günü';
    text = 'Yarın vadesinde.';
  } else if (days >= 2 &&
      days <= 5 &&
      !due.subtract(const Duration(days: 5)).isAfter(now)) {
    title = 'Yaklaşan vade';
    text = 'Vadesine $days gün kaldı.';
  } else {
    return null;
  }
  return PlannedReminder(
    item.id * 10 + 4,
    now,
    title,
    '${item.plan.title}: ${formatCompactMoney(item.amountCents)}. $text',
    true,
  );
}
