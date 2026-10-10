import '../models/payment.dart';

/// Read-only payment analytics. Never changes the underlying ledger.
class MonthlyCashFlow {
  final DateTime month;
  final int outgoingCents;
  final int incomingCents;
  const MonthlyCashFlow(this.month, this.outgoingCents, this.incomingCents);
  int get netCents => incomingCents - outgoingCents;
}

enum LedgerSort { nearest, latest, highest, lowest, name }

class LedgerInsights {
  static bool dueWithin(DueItem item, DateTime start, DateTime end) {
    final date = dateOnly(item.dueDate);
    return !date.isBefore(dateOnly(start)) && date.isBefore(dateOnly(end));
  }

  static String normalize(String raw) => raw.toLowerCase()
    .replaceAll('ç', 'c').replaceAll('ğ', 'g').replaceAll('ı', 'i')
    .replaceAll('ö', 'o').replaceAll('ş', 's').replaceAll('ü', 'u')
    .replaceAll('i̇', 'i').trim();

  /// Search title, counterparty, notes, category and IBAN; every word must match.
  static bool matchesSearch(DueItem item, String query) {
    final words = normalize(query).split(RegExp(r'\s+')).where((e) => e.isNotEmpty);
    final haystack = normalize([
      item.plan.title, item.plan.party, item.plan.note, item.plan.iban,
      item.plan.category.label, item.plan.kind.label,
    ].join(' '));
    return words.every(haystack.contains);
  }

  static bool matchesFilter(DueItem item, String filter, {DateTime? today}) {
    final now = dateOnly(today ?? DateTime.now());
    if (filter == 'Geçmiş') return item.isPaid;
    if (item.isPaid) return false;
    return switch (filter) {
      'Taksit' => item.plan.kind == PaymentKind.installment,
      'Fatura' => item.plan.kind == PaymentKind.invoice,
      'Abonelik' => item.plan.kind == PaymentKind.subscription,
      'Tek seferlik' => item.plan.kind == PaymentKind.single,
      'Borçlar' => item.plan.direction == PaymentDirection.outgoing,
      'Alacaklar' => item.plan.direction == PaymentDirection.incoming,
      'Gecikenler' => dateOnly(item.dueDate).isBefore(now),
      'Bugün' => dateOnly(item.dueDate) == now,
      '7 Gün' => dueWithin(item, now, now.add(const Duration(days: 7))),
      'Bu ay' => item.dueDate.year == now.year && item.dueDate.month == now.month,
      _ => true,
    };
  }

  static List<DueItem> filterAndSort(
    Iterable<DueItem> source, {
    String filter = 'Tümü',
    String search = '',
    LedgerSort sort = LedgerSort.nearest,
    DateTime? today,
  }) {
    final results = source.where((item) =>
      matchesFilter(item, filter, today: today) && matchesSearch(item, search)
    ).toList();
    results.sort((a, b) {
      final comparison = switch (sort) {
        LedgerSort.nearest => a.dueDate.compareTo(b.dueDate),
        LedgerSort.latest => b.dueDate.compareTo(a.dueDate),
        LedgerSort.highest => b.amountCents.compareTo(a.amountCents),
        LedgerSort.lowest => a.amountCents.compareTo(b.amountCents),
        LedgerSort.name => normalize(a.plan.title).compareTo(normalize(b.plan.title)),
      };
      return comparison != 0 ? comparison : a.id.compareTo(b.id);
    });
    return results;
  }

  /// Six-month projection uses only outstanding existing occurrences.
  /// Recurring invoices are not projected beyond periods already created.
  static List<MonthlyCashFlow> forecast(
    Iterable<DueItem> source, {DateTime? today, int months = 6}
  ) {
    if (months < 1 || months > 24) throw ArgumentError.value(months, 'months');
    final now = today ?? DateTime.now();
    final first = DateTime(now.year, now.month);
    return List.generate(months, (index) {
      final month = DateTime(first.year, first.month + index);
      var outgoing = 0;
      var incoming = 0;
      for (final item in source) {
        if (item.isPaid || item.dueDate.year != month.year ||
            item.dueDate.month != month.month) continue;
        if (item.plan.direction == PaymentDirection.outgoing) {
          outgoing += item.amountCents;
        } else {
          incoming += item.amountCents;
        }
      }
      return MonthlyCashFlow(month, outgoing, incoming);
    });
  }

  static int overdueIncoming(
    Iterable<DueItem> source, {DateTime? today}
  ) {
    final now = dateOnly(today ?? DateTime.now());
    return source.where((item) =>
      !item.isPaid && item.plan.direction == PaymentDirection.incoming &&
      dateOnly(item.dueDate).isBefore(now)
    ).fold<int>(0, (sum, item) => sum + item.amountCents);
  }
}
