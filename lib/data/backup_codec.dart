import 'dart:convert';
import '../models/payment.dart';

class BackupCodec {
  final List<Map<String, Object?>> plans;
  final List<Map<String, Object?>> occurrences;
  BackupCodec._(this.plans, this.occurrences);

  static BackupCodec decode(String source) {
    if (source.length > 10000000) {
      throw const FormatException('Yedek en fazla 10 MB olabilir.');
    }
    try {
      final root = jsonDecode(source) as Map<String, dynamic>;
      if (root['app'] != 'vadesi' || root['version'] != 1) {
        throw const FormatException('Desteklenmeyen yedek sürümü.');
      }
      final plans = _rows(root['plans']);
      final occurrences = _rows(root['occurrences']);
      if (plans.length > 10000 || occurrences.length > 100000) {
        throw const FormatException('Yedekte çok fazla kayıt var.');
      }
      final planMap = <int, PaymentPlan>{};
      for (final row in plans) {
        _keys(row, const ['id', 'title', 'party', 'iban', 'note', 'kind',
          'direction', 'category', 'amount_cents', 'installment_count',
          'anchor_day', 'start_date', 'created_at']);
        final plan = PaymentPlan.fromMap(row);
        if (!_id(plan.id) || planMap.containsKey(plan.id) ||
            plan.anchorDay < 1 || plan.anchorDay > 31 ||
            !_date(row['start_date']) || plan.createdAt.year < 2000 ||
            plan.createdAt.year > 2200) {
          throw const FormatException('Geçersiz ödeme planı.');
        }
        validateDraft(PlanDraft(title: plan.title, party: plan.party,
          iban: plan.iban, note: plan.note, kind: plan.kind,
          direction: plan.direction, category: plan.category,
          amountCents: plan.amountCents, count: plan.count,
          startDate: plan.startDate));
        planMap[plan.id] = plan;
      }
      final ids = <int>{};
      final sequences = <String>{};
      final plansWithItems = <int>{};
      for (final row in occurrences) {
        _keys(row, const ['id', 'plan_id', 'sequence', 'due_date',
          'amount_cents', 'paid_at']);
        final plan = planMap[row['plan_id']];
        if (plan == null) throw const FormatException('Ödemenin planı bulunamadı.');
        final item = DueItem.fromMap(row, plan);
        if (!_id(item.id) || !ids.add(item.id) ||
            !sequences.add('${item.planId}:${item.sequence}') ||
            item.sequence < 1 || item.sequence > 100000 ||
            (plan.kind == PaymentKind.installment && item.sequence > plan.count) ||
            (plan.kind == PaymentKind.single && item.sequence != 1) ||
            item.amountCents <= 0 || item.amountCents > 999999999999 ||
            !_date(row['due_date']) ||
            (item.paidAt != null && (item.paidAt!.year < 2000 || item.paidAt!.year > 2200))) {
          throw const FormatException('Geçersiz ödeme kaydı.');
        }
        plansWithItems.add(plan.id);
      }
      if (plansWithItems.length != planMap.length) {
        throw const FormatException('Ödemesi olmayan plan bulundu.');
      }
      return BackupCodec._(plans, occurrences);
    } on FormatException {
      rethrow;
    } catch (_) {
      throw const FormatException('Dosya geçerli bir VADESİ yedeği değil.');
    }
  }

  static bool _id(int value) => value > 0 && value <= 200000000;
  static bool _date(Object? value) {
    if (value is! String || !RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)) return false;
    final parsed = DateTime.tryParse(value);
    return parsed != null && parsed.year >= 2020 && parsed.year <= 2120 &&
        sqlDate(parsed) == value;
  }
  static List<Map<String, Object?>> _rows(dynamic value) =>
      (value as List).map((row) => Map<String, Object?>.from(row as Map)).toList();
  static void _keys(Map<String, Object?> row, List<String> expected) {
    if (row.length != expected.length || expected.any((key) => !row.containsKey(key))) {
      throw const FormatException('Yedek alanları eksik veya uyumsuz.');
    }
  }
}
