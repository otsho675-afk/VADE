import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/models/payment.dart';
import 'package:vadesi/services/ledger_insights.dart';

PaymentPlan plan(int id, String title, PaymentDirection direction, {PaymentKind kind = PaymentKind.installment, String note = ''}) =>
  PaymentPlan(id: id, title: title, party: 'Çağrı', iban: 'TR33 0006', note: note,
    kind: kind, direction: direction, category: InvoiceCategory.internet,
    amountCents: 10000, count: 3, anchorDay: 15,
    startDate: DateTime(2026, 10, 15), createdAt: DateTime(2026, 10, 1));

DueItem item(int id, DateTime due, int amount, PaymentPlan p, {bool paid = false}) =>
  DueItem(id: id, planId: p.id, sequence: id, dueDate: due,
    amountCents: amount, paidAt: paid ? DateTime(2026, 10, 1) : null, plan: p);

void main() {
  final today = DateTime(2026, 10, 10);
  final debt = plan(1, 'Elektrik Ödemesi', PaymentDirection.outgoing, note: 'Ekim gideri');
  final income = plan(2, 'Müşteri Tahsilatı', PaymentDirection.incoming, kind: PaymentKind.single);
  final rows = [
    item(1, DateTime(2026, 10, 9), 10000, debt),
    item(2, DateTime(2026, 10, 10), 25000, debt),
    item(3, DateTime(2026, 10, 16), 30000, income),
    item(4, DateTime(2026, 11, 12), 55000, debt),
    item(5, DateTime(2026, 10, 8), 10000, debt, paid: true),
  ];

  test('Date and direction filters do not include completed payments', () {
    expect(LedgerInsights.filterAndSort(rows, filter: 'Bugün', today: today).map((e) => e.id), [2]);
    expect(LedgerInsights.filterAndSort(rows, filter: '7 Gün', today: today).map((e) => e.id), [2, 3]);
    expect(LedgerInsights.filterAndSort(rows, filter: 'Gecikenler', today: today).map((e) => e.id), [1]);
    expect(LedgerInsights.filterAndSort(rows, filter: 'Bu ay', today: today).length, 3);
    expect(LedgerInsights.filterAndSort(rows, filter: 'Alacaklar', today: today).map((e) => e.id), [3]);
    expect(LedgerInsights.filterAndSort(rows, filter: 'Geçmiş', today: today).map((e) => e.id), [5]);
  });

  test('Turkish insensitive search handles notes, categories and multiple words', () {
    expect(LedgerInsights.filterAndSort(rows, search: 'ELEKTRIK ekim', today: today).length, 3);
    expect(LedgerInsights.filterAndSort(rows, search: 'çAĞRI iNTERNET', today: today).length, 4);
    expect(LedgerInsights.filterAndSort(rows, search: 'not-exists', today: today), isEmpty);
    expect(LedgerInsights.filterAndSort(rows, sort: LedgerSort.highest, today: today).first.id, 4);
  });

  test('Payment history keeps most recently paid records first', () {
    final earlier = DueItem(id: 20, planId: debt.id, sequence: 4,
      dueDate: DateTime(2026, 9, 15), amountCents: 10000,
      paidAt: DateTime(2026, 10, 1), plan: debt);
    final later = DueItem(id: 21, planId: debt.id, sequence: 5,
      dueDate: DateTime(2026, 8, 15), amountCents: 12000,
      paidAt: DateTime(2026, 10, 9), plan: debt);
    final result = LedgerInsights.filterAndSort([earlier, later],
      filter: 'Geçmiş', today: today);
    expect(result.map((item) => item.id), [21, 20]);
  });

  test('Forecast excludes paid and limits recurring periods to existing records', () {
    final months = LedgerInsights.forecast(rows, today: today, months: 3);
    expect(months.length, 3);
    expect(months.first.outgoingCents, 35000);
    expect(months.first.incomingCents, 30000);
    expect(months.first.netCents, -5000);
    expect(months[1].outgoingCents, 55000);
    expect(months[2].outgoingCents, 0);
    expect(LedgerInsights.overdueIncoming(rows, today: today), 0);
    expect(() => LedgerInsights.forecast(rows, months: 0), throwsArgumentError);
  });
}
