import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vadesi/data/local_database.dart';
import 'package:vadesi/models/payment.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/services/ledger_export.dart';

PlanDraft draft({PaymentKind kind = PaymentKind.installment}) => PlanDraft(
  title: '=1+1', party: 'Test', iban: '', note: '', kind: kind,
  direction: PaymentDirection.outgoing, category: InvoiceCategory.other,
  amountCents: 125075, count: kind == PaymentKind.installment ? 3 : 1,
  startDate: DateTime(2026, 1, 31),
);

void main() {
  sqfliteFfiInit();
  late LocalDatabase db;
  setUp(() { db = LocalDatabase(factory: databaseFactoryFfi, databasePath: inMemoryDatabasePath); });
  tearDown(() => db.close());

  test('Installments, paid history, backup and atomic restore', () async {
    await db.addPlan(draft());
    var items = await db.allItems();
    expect(items.map((item) => item.dueDate), [DateTime(2026,1,31), DateTime(2026,2,28), DateTime(2026,3,31)]);
    await db.pay(items.first);
    await db.pay(items.first);
    items = await db.allItems();
    expect(items.where((item) => item.isPaid).length, 1);
    final backup = await db.exportBackup();
    await db.deletePlan(items.first.planId);
    expect(await db.allItems(), isEmpty);
    await db.restoreBackup(backup);
    expect((await db.allItems()).length, 3);
    await expectLater(db.restoreBackup('{"app":"other","version":1}'), throwsFormatException);
    expect((await db.allItems()).length, 3);
    expect(ledgerCsv(items), contains("'=1+1"));
  });

  test('Recurring pay is idempotent and undo removes next period', () async {
    await db.addPlan(draft(kind: PaymentKind.invoice));
    final first = (await db.allItems()).single;
    await db.pay(first);
    await db.pay(first);
    expect((await db.allItems()).length, 2);
    await db.undo(first);
    final items = await db.allItems();
    expect(items.length, 1);
    expect(items.single.isPaid, false);
  });

  test('Month total includes all overdue installments', () async {
    await db.addPlan(draft());
    final store = AppStore(database: db);
    store.items = await db.allItems();
    expect(store.upcoming.length, 1);
    // All dates in this test are before the month containing the test run.
    final end = DateTime(DateTime.now().year, DateTime.now().month + 1);
    final expected = store.items.where((item) => item.dueDate.isBefore(end))
      .fold<int>(0, (sum, item) => sum + item.amountCents);
    expect(store.monthOutgoing, expected);
  });

  test('Overdue summary counts individual installments and separates incoming amounts', () async {
    await db.addPlan(draft());
    final incoming = PlanDraft(
      title: 'Alacak', party: 'Müşteri', iban: '', note: '',
      kind: PaymentKind.single, direction: PaymentDirection.incoming,
      category: InvoiceCategory.other, amountCents: 20000, count: 1,
      startDate: DateTime(2026, 1, 1),
    );
    await db.addPlan(incoming);
    final store = AppStore(database: db);
    store.items = await db.allItems();
    expect(store.upcoming.length, 2);
    expect(store.unpaidItems.length, 4);
    expect(store.lateCount, 4);
    expect(store.lateOutgoingAmount, 3 * 125075);
    expect(store.next7DaysOutgoing, 0);
  });

  test('Undo of an unpaid recurrence does not delete later pending periods', () async {
    await db.addPlan(draft(kind: PaymentKind.subscription));
    final first = (await db.allItems()).single;
    await db.pay(first);
    final second = (await db.allItems()).last;
    final connection = await db.connection;
    await connection.insert('occurrences', {
      'plan_id': first.planId, 'sequence': 3, 'due_date': '2026-03-31',
      'amount_cents': first.amountCents, 'paid_at': null,
    });
    await db.undo(second);
    expect((await db.allItems()).length, 3);
    expect((await db.allItems()).where((e) => e.isPaid).length, 1);
  });

  test('Duplicate backup IDs leave the existing ledger untouched', () async {
    await db.addPlan(draft());
    final backup = jsonDecode(await db.exportBackup()) as Map<String, dynamic>;
    (backup['occurrences'] as List).add((backup['occurrences'] as List).first);
    await expectLater(db.restoreBackup(jsonEncode(backup)), throwsFormatException);
    expect((await db.allItems()).length, 3);
  });

  test('Recurring undo protects later paid history', () async {
    await db.addPlan(draft(kind: PaymentKind.subscription));
    final first = (await db.allItems()).single;
    await db.pay(first);
    final next = (await db.allItems()).last;
    await db.pay(next);
    await expectLater(db.undo(first), throwsStateError);
    expect((await db.allItems()).where((item) => item.isPaid).length, 2);
  });

  test('Invalid input is rejected before database mutation', () async {
    await expectLater(db.addPlan(PlanDraft(title: '', party: '', iban: '', note: '',
      kind: PaymentKind.single, direction: PaymentDirection.outgoing,
      category: InvoiceCategory.other, amountCents: -1, count: 1,
      startDate: DateTime(2026))), throwsFormatException);
    expect(await db.allItems(), isEmpty);
  });
}
