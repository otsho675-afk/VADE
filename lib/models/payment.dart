import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

enum PaymentKind { installment, invoice, subscription, single }
enum PaymentDirection { outgoing, incoming }
enum InvoiceCategory { electricity, water, gas, internet, telephone, rent, other }

extension KindDetails on PaymentKind {
  String get label => switch (this) {
    PaymentKind.installment => 'Taksit',
    PaymentKind.invoice => 'Fatura',
    PaymentKind.subscription => 'Abonelik',
    PaymentKind.single => 'Tek seferlik',
  };
  IconData get icon => switch (this) {
    PaymentKind.installment => Icons.credit_card_rounded,
    PaymentKind.invoice => Icons.receipt_long_rounded,
    PaymentKind.subscription => Icons.autorenew_rounded,
    PaymentKind.single => Icons.account_balance_wallet_outlined,
  };
  bool get isRecurring => this == PaymentKind.invoice || this == PaymentKind.subscription;
}

extension DirectionDetails on PaymentDirection {
  String get label => this == PaymentDirection.outgoing ? 'Ödeyeceğim' : 'Tahsil edeceğim';
}

extension InvoiceCategoryDetails on InvoiceCategory {
  String get label => switch (this) {
    InvoiceCategory.electricity => 'Elektrik',
    InvoiceCategory.water => 'Su',
    InvoiceCategory.gas => 'Doğalgaz',
    InvoiceCategory.internet => 'İnternet',
    InvoiceCategory.telephone => 'Telefon',
    InvoiceCategory.rent => 'Kira',
    InvoiceCategory.other => 'Diğer',
  };
  IconData get icon => switch (this) {
    InvoiceCategory.electricity => Icons.bolt_outlined,
    InvoiceCategory.water => Icons.water_drop_outlined,
    InvoiceCategory.gas => Icons.local_fire_department_outlined,
    InvoiceCategory.internet => Icons.wifi_rounded,
    InvoiceCategory.telephone => Icons.phone_android_rounded,
    InvoiceCategory.rent => Icons.home_outlined,
    InvoiceCategory.other => Icons.description_outlined,
  };
}

class PaymentPlan {
  final int id;
  final String title;
  final String party;
  final String iban;
  final String note;
  final PaymentKind kind;
  final PaymentDirection direction;
  final InvoiceCategory category;
  final int amountCents;
  final int count;
  final int anchorDay;
  final DateTime startDate;
  final DateTime createdAt;

  const PaymentPlan({
    required this.id,
    required this.title,
    required this.party,
    required this.iban,
    required this.note,
    required this.kind,
    required this.direction,
    required this.category,
    required this.amountCents,
    required this.count,
    required this.anchorDay,
    required this.startDate,
    required this.createdAt,
  });

  factory PaymentPlan.fromMap(Map<String, Object?> m) => PaymentPlan(
    id: m['id'] as int,
    title: m['title'] as String,
    party: m['party'] as String,
    iban: m['iban'] as String,
    note: m['note'] as String,
    kind: PaymentKind.values.byName(m['kind'] as String),
    direction: PaymentDirection.values.byName(m['direction'] as String),
    category: InvoiceCategory.values.byName(m['category'] as String),
    amountCents: m['amount_cents'] as int,
    count: m['installment_count'] as int,
    anchorDay: m['anchor_day'] as int,
    startDate: DateTime.parse(m['start_date'] as String),
    createdAt: DateTime.parse(m['created_at'] as String),
  );
  bool get isFinite => !kind.isRecurring;
}

class DueItem {
  final int id;
  final int planId;
  final int sequence;
  final DateTime dueDate;
  final int amountCents;
  final DateTime? paidAt;
  final PaymentPlan plan;

  const DueItem({
    required this.id, required this.planId, required this.sequence,
    required this.dueDate, required this.amountCents, required this.paidAt,
    required this.plan,
  });
  bool get isPaid => paidAt != null;
  bool get isLate => !isPaid && dateOnly(dueDate).isBefore(dateOnly(DateTime.now()));
  int get daysLeft => dateOnly(dueDate).difference(dateOnly(DateTime.now())).inDays;

  factory DueItem.fromMap(Map<String, Object?> m, PaymentPlan plan) => DueItem(
    id: m['id'] as int,
    planId: m['plan_id'] as int,
    sequence: m['sequence'] as int,
    dueDate: DateTime.parse(m['due_date'] as String),
    amountCents: m['amount_cents'] as int,
    paidAt: m['paid_at'] == null ? null : DateTime.parse(m['paid_at'] as String),
    plan: plan,
  );
}

class PlanDraft {
  final String title, party, iban, note;
  final PaymentKind kind;
  final PaymentDirection direction;
  final InvoiceCategory category;
  final int amountCents, count;
  final DateTime startDate;
  const PlanDraft({
    required this.title, required this.party, required this.iban,
    required this.note, required this.kind, required this.direction,
    required this.category, required this.amountCents, required this.count,
    required this.startDate,
  });
}

DateTime dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

/// Protects e.g. monthly bills due on the 31st: Feb -> last day; Mar -> 31st.
DateTime addMonthsAnchored(DateTime start, int months, int anchorDay) {
  final absoluteMonth = start.year * 12 + start.month - 1 + months;
  final year = absoluteMonth ~/ 12;
  final month = absoluteMonth % 12 + 1;
  final lastDay = DateTime(year, month + 1, 0).day;
  return DateTime(year, month, anchorDay.clamp(1, lastDay));
}

String sqlDate(DateTime date) => DateFormat('yyyy-MM-dd').format(date);
String formatDate(DateTime date) => DateFormat('dd.MM.yyyy').format(date);
String formatMoney(int cents) => NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: 2).format(cents / 100);
String formatCompactMoney(int cents) => NumberFormat.currency(locale: 'tr_TR', symbol: '₺', decimalDigits: cents % 100 == 0 ? 0 : 2).format(cents / 100);

int? parseMoneyToCents(String raw) {
  final input = raw.trim().replaceAll('₺', '').replaceAll(' ', '');
  if (input.isEmpty) return null;
  String canonical = input;
  if (canonical.contains(',') && canonical.contains('.')) {
    canonical = canonical.replaceAll('.', '').replaceAll(',', '.');
  } else if (canonical.contains(',')) {
    canonical = canonical.replaceAll(',', '.');
  } else if (RegExp(r'^\d{1,3}(\.\d{3})+$').hasMatch(canonical)) {
    canonical = canonical.replaceAll('.', '');
  }
  if (!RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(canonical)) return null;
  final parts = canonical.split('.');
  final whole = int.tryParse(parts[0]);
  if (whole == null) return null;
  final fractional = parts.length > 1 ? int.tryParse(parts[1].padRight(2, '0')) : 0;
  if (fractional == null) return null;
  final cents = whole * 100 + fractional;
  return cents > 999999999999 ? null : cents;
}

bool isValidIban(String raw) {
  final normalized = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
  if (normalized.isEmpty) return true;
  if (!RegExp(r'^TR\d{24}$').hasMatch(normalized)) return false;
  final rotated = normalized.substring(4) + normalized.substring(0, 4);
  final digits = StringBuffer();
  for (final rune in rotated.runes) {
    if (rune >= 65 && rune <= 90) {
      digits.write(rune - 55);
    } else {
      digits.writeCharCode(rune);
    }
  }
  int remainder = 0;
  for (final digit in digits.toString().codeUnits) {
    remainder = (remainder * 10 + digit - 48) % 97;
  }
  return remainder == 1;
}

void validateDraft(PlanDraft draft) {
  if (draft.title.trim().isEmpty || draft.title.length > 200 ||
      draft.party.length > 200 || draft.note.length > 5000 ||
      !isValidIban(draft.iban) ||
      draft.amountCents <= 0 || draft.amountCents > 999999999999 ||
      draft.count < 1 || draft.count > 240 ||
      draft.startDate.year < 2020 || draft.startDate.year > 2100) {
    throw const FormatException('Ödeme bilgilerini kontrol edin.');
  }
}
