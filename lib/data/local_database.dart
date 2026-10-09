import 'dart:convert';
import 'package:path/path.dart';
import 'database_platform.dart';
import 'backup_codec.dart';
import 'package:sqflite/sqflite.dart';
import '../models/payment.dart';

class LocalDatabase {
  Database? _db;
  Future<Database>? _opening;
  final DatabaseFactory? factory;
  final String? databasePath;
  LocalDatabase({this.factory, this.databasePath});

  Future<Database> get connection async {
    if (_db != null) return _db!;
    return _opening ??= _open();
  }

  Future<Database> _open() async {
    final selectedFactory = factory ?? platformDatabaseFactory();
    try {
    final path = databasePath ?? join(await selectedFactory.getDatabasesPath(), 'vadesi.db');
    _db = await selectedFactory.openDatabase(
      path,
      options: OpenDatabaseOptions(version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE plans (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            party TEXT NOT NULL DEFAULT '',
            iban TEXT NOT NULL DEFAULT '',
            note TEXT NOT NULL DEFAULT '',
            kind TEXT NOT NULL,
            direction TEXT NOT NULL,
            category TEXT NOT NULL,
            amount_cents INTEGER NOT NULL,
            installment_count INTEGER NOT NULL,
            anchor_day INTEGER NOT NULL,
            start_date TEXT NOT NULL,
            created_at TEXT NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE occurrences (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            plan_id INTEGER NOT NULL,
            sequence INTEGER NOT NULL,
            due_date TEXT NOT NULL,
            amount_cents INTEGER NOT NULL,
            paid_at TEXT,
            UNIQUE(plan_id, sequence),
            FOREIGN KEY (plan_id) REFERENCES plans(id) ON DELETE CASCADE
          )
        ''');
        await db.execute('CREATE INDEX occurrence_due_index ON occurrences(due_date, paid_at)');
        await db.execute('CREATE INDEX occurrence_plan_index ON occurrences(plan_id, sequence)');
      },
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON')),
    );
    return _db!;
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<List<DueItem>> allItems() async {
    final db = await connection;
    final plans = (await db.query('plans')).map(PaymentPlan.fromMap).toList();
    final planById = {for (final plan in plans) plan.id: plan};
    final records = await db.query('occurrences', orderBy: 'due_date ASC, id ASC');
    return [
      for (final m in records)
        if (planById[m['plan_id']] != null)
          DueItem.fromMap(m, planById[m['plan_id']]!),
    ];
  }

  Future<int> addPlan(PlanDraft draft) async {
    validateDraft(draft);
    final db = await connection;
    return db.transaction((txn) async {
      final id = await txn.insert('plans', {
        'title': draft.title,
        'party': draft.party,
        'iban': draft.iban,
        'note': draft.note,
        'kind': draft.kind.name,
        'direction': draft.direction.name,
        'category': draft.category.name,
        'amount_cents': draft.amountCents,
        'installment_count': draft.count,
        'anchor_day': draft.startDate.day,
        'start_date': sqlDate(draft.startDate),
        'created_at': DateTime.now().toIso8601String(),
      });
      final n = draft.kind == PaymentKind.installment ? draft.count : 1;
      for (var i = 0; i < n; i++) {
        final dueDate = addMonthsAnchored(draft.startDate, i, draft.startDate.day);
        await txn.insert('occurrences', {
          'plan_id': id,
          'sequence': i + 1,
          'due_date': sqlDate(dueDate),
          'amount_cents': draft.amountCents,
          'paid_at': null,
        });
      }
      return id;
    });
  }

  /// Updates only unpaid amounts; paid history remains immutable.
  /// Schedule/count remain unchanged for existing plans to protect ledger history.
  Future<void> updatePlan(PaymentPlan plan, PlanDraft draft) async {
    validateDraft(draft);
    final db = await connection;
    await db.transaction((txn) async {
      await txn.update('plans', {
        'title': draft.title,
        'party': draft.party,
        'iban': draft.iban,
        'note': draft.note,
        'amount_cents': draft.amountCents,
        'category': draft.category.name,
      }, where: 'id = ?', whereArgs: [plan.id]);
      await txn.update('occurrences', {'amount_cents': draft.amountCents},
          where: 'plan_id = ? AND paid_at IS NULL', whereArgs: [plan.id]);
    });
  }

  Future<void> pay(DueItem occurrence) async {
    final db = await connection;
    await db.transaction((txn) async {
      final affected = await txn.update('occurrences', {
        'paid_at': DateTime.now().toIso8601String(),
      }, where: 'id = ? AND paid_at IS NULL', whereArgs: [occurrence.id]);
      if (affected == 0) return;
      if (occurrence.plan.kind.isRecurring) {
        final nextDue = addMonthsAnchored(
          occurrence.plan.startDate,
          occurrence.sequence,
          occurrence.plan.anchorDay,
        );
        await txn.insert('occurrences', {
          'plan_id': occurrence.planId,
          'sequence': occurrence.sequence + 1,
          'due_date': sqlDate(nextDue),
          'amount_cents': occurrence.plan.amountCents,
          'paid_at': null,
        }, conflictAlgorithm: ConflictAlgorithm.ignore);
      }
    });
  }

  Future<void> undo(DueItem occurrence) async {
    final db = await connection;
    await db.transaction((txn) async {
      final laterPaid = Sqflite.firstIntValue(await txn.rawQuery(
        'SELECT COUNT(*) FROM occurrences WHERE plan_id = ? AND sequence > ? AND paid_at IS NOT NULL',
        [occurrence.planId, occurrence.sequence],
      )) ?? 0;
      if (laterPaid > 0) throw StateError('Daha sonraki ödemeler kaydedildi. Önce son ödemeyi geri alın.');
      await txn.update('occurrences', {'paid_at': null}, where: 'id = ?', whereArgs: [occurrence.id]);
      if (occurrence.plan.kind.isRecurring) {
        await txn.delete('occurrences',
          where: 'plan_id = ? AND sequence > ? AND paid_at IS NULL',
          whereArgs: [occurrence.planId, occurrence.sequence],
        );
      }
    });
  }

  Future<void> updateDueDate(DueItem occurrence, DateTime dueDate) async {
    final db = await connection;
    await db.update('occurrences', {'due_date': sqlDate(dueDate)},
      where: 'id = ? AND paid_at IS NULL', whereArgs: [occurrence.id]);
  }

  Future<void> deletePlan(int id) async {
    final db = await connection;
    await db.delete('plans', where: 'id = ?', whereArgs: [id]);
  }

  Future<String> exportBackup() async {
    final db = await connection;
    return db.transaction((txn) async => const JsonEncoder.withIndent('  ').convert({
      'app': 'vadesi', 'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'plans': await txn.query('plans', orderBy: 'id'),
      'occurrences': await txn.query('occurrences', orderBy: 'id'),
    }));
  }

  Future<void> restoreBackup(String source) async {
    final backup = BackupCodec.decode(source);
    final db = await connection;
    await db.transaction((txn) async {
      await txn.delete('occurrences');
      await txn.delete('plans');
      for (final row in backup.plans) {
        await txn.insert('plans', row);
      }
      for (final row in backup.occurrences) {
        await txn.insert('occurrences', row);
      }
    });
  }

  Future<void> close() async {
    if (_opening != null) {
      try { await _opening; } catch (_) { /* Failed open has no handle. */ }
    }
    await _db?.close();
    _db = null;
    _opening = null;
  }
}
