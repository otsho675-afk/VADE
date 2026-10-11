import '../models/payment.dart';

String ledgerCsv(List<DueItem> items) {
  String cell(String value) {
    // Prevent spreadsheet formula execution when opening user-entered text.
    if (RegExp(r'^[\s]*[=+@\-]').hasMatch(value)) value = "'$value";
    return '"${value.replaceAll('"', '""')}"';
  }
  final rows = <List<String>>[
    ['Ödeme', 'Kişi/Kurum', 'Yön', 'Tür', 'Taksit', 'Vade', 'Tutar (TL)', 'Durum', 'Ödeme tarihi'],
    for (final item in items)
      [item.plan.title, item.plan.party, item.plan.direction.label, item.plan.kind.label,
       '${item.sequence}', formatDate(item.dueDate),
       (item.amountCents / 100).toStringAsFixed(2).replaceAll('.', ','),
       item.isPaid ? 'Tamamlandı' : 'Bekliyor',
       item.paidAt == null ? '' : formatDate(item.paidAt!)],
  ];
  return '\uFEFF${rows.map((row) => row.map(cell).join(';')).join('\r\n')}\r\n';
}
