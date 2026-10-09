import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../models/payment.dart';
import '../../state/app_store.dart';
import '../widgets/common.dart';
import 'payment_form_page.dart';

class PaymentDetailPage extends StatelessWidget {
  final AppStore store;
  final int planId;
  const PaymentDetailPage({super.key, required this.store, required this.planId});

  Future<void> _paid(BuildContext context, DueItem item) async {
    try {
      await store.markPaid(item);
      if (context.mounted) showSuccess(context, 'Ödeme kaydedildi. Sonraki taksit güncellendi.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _undo(BuildContext context, DueItem item) async {
    final ok = await confirmAction(context,
      title: 'Ödemeyi geri al',
      body: 'Bu kaydı yeniden ödenmemiş olarak işaretlemek istiyor musunuz?',
      confirm: 'Geri al');
    if (!ok) return;
    try {
      await store.undoPaid(item);
      if (context.mounted) showSuccess(context, 'Ödeme geri alındı.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  Future<void> _editDate(BuildContext context, DueItem item) async {
    final choice = await showDatePicker(
      context: context,
      firstDate: DateTime(2020), lastDate: DateTime(2120, 12, 31),
      initialDate: item.dueDate,
      helpText: 'Bu ödemenin vadesini değiştir',
    );
    if (choice == null) return;
    try {
      await store.reschedule(item, choice);
      if (context.mounted) showSuccess(context, 'Vade tarihi değiştirildi.');
    } catch (e) {
      if (context.mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: store,
      builder: (context, _) {
        final payments = store.planItems(planId);
        if (payments.isEmpty) { return Scaffold(appBar: AppBar(title: const Text('Ödeme detayı')),
          body: const EmptyView(title: 'Kayıt bulunamadı', message: 'Bu ödeme silinmiş olabilir.', icon: Icons.info_outline)); }
        final plan = payments.first.plan;
        final remaining = payments.where((p) => !p.isPaid).toList();
        final paid = payments.where((p) => p.isPaid).toList();
        final totalPaid = paid.fold<int>(0, (v, p) => v + p.amountCents);
        final isCompact = MediaQuery.sizeOf(context).width < 580;
        return Scaffold(
          appBar: AppBar(
            title: const Text('Ödeme detayı'),
            actions: [
              IconButton(
                tooltip: 'Düzenle',
                icon: const Icon(Icons.edit_outlined),
                onPressed: () => Navigator.push(context, MaterialPageRoute(
                  builder: (_) => PaymentFormPage(store: store, editing: plan))),
              ),
              PopupMenuButton<String>(
                tooltip: 'Diğer işlemler',
                onSelected: (v) async {
                  if (v != 'delete') return;
                  final allow = await confirmAction(context, title: 'Planı sil',
                    body: 'Bu ödeme planının tüm taksitleri ve ödeme geçmişi cihazdan silinecek. Bu işlem geri alınamaz.',
                    confirm: 'Kalıcı olarak sil', destructive: true);
                  if (!allow) return;
                  try {
                    await store.removePlan(planId);
                    if (context.mounted) Navigator.pop(context);
                  } catch (e) {
                    if (context.mounted) showError(context, e);
                  }
                },
                itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('Planı sil'))],
              ),
            ],
          ),
          body: Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 850),
            child: ListView(padding: const EdgeInsets.fromLTRB(18, 15, 18, 30), children: [
              Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .09), borderRadius: BorderRadius.circular(14)),
                      child: Icon(plan.kind == PaymentKind.invoice ? plan.category.icon : plan.kind.icon,
                        color: Theme.of(context).colorScheme.primary, size: 26)),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(plan.title, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 5),
                      Text('${plan.kind.label} · ${plan.direction.label}',
                        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    ])),
                  ]),
                  const SizedBox(height: 18),
                  const Divider(),
                  const SizedBox(height: 10),
                  _detailLine(context, 'Tutar', formatMoney(plan.amountCents)),
                  if (plan.party.isNotEmpty) _detailLine(context, 'Kişi / kurum', plan.party),
                  _detailLine(context, 'İlk vade', formatDate(plan.startDate)),
                  if (plan.kind == PaymentKind.installment)
                    _detailLine(context, 'Taksit sayısı', '${paid.length} / ${plan.count} ödendi'),
                  if (plan.kind.isRecurring)
                    _detailLine(context, 'Tekrar', 'Her ay · ödendiğinde sonraki dönem oluşturulur'),
                  _detailLine(context, 'Ödenen toplam', formatMoney(totalPaid)),
                  if (plan.isFinite)
                    _detailLine(context, 'Kalan tutar', formatMoney(remaining.fold(0, (sum, e) => sum + e.amountCents))),
                  if (plan.iban.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Text('Kayıtlı IBAN', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    DecoratedBox(decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withValues(alpha: .05),
                      borderRadius: BorderRadius.circular(12)),
                      child: Padding(padding: const EdgeInsets.all(12), child: Row(children: [
                        Expanded(child: SelectableText(plan.iban, style: const TextStyle(fontWeight: FontWeight.w600))),
                        IconButton(tooltip: 'IBAN kopyala', icon: const Icon(Icons.copy_outlined), onPressed: () {
                          Clipboard.setData(ClipboardData(text: plan.iban));
                          showSuccess(context, 'IBAN kopyalandı.');
                        }),
                      ])),
                    ),
                  ],
                  if (plan.note.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Text('Not', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 5),
                    Text(plan.note),
                  ],
                ],
              ))),
              const SizedBox(height: 23),
              const SectionTitle('Ödeme takvimi'),
              if (remaining.isEmpty)
                const Card(child: Padding(padding: EdgeInsets.all(22), child: Text('Bu plandaki tüm ödemeler tamamlandı.'))),
              for (final occurrence in payments) ...[
                Card(child: Padding(padding: const EdgeInsets.all(14), child: Row(children: [
                  Icon(occurrence.isPaid ? Icons.check_circle_rounded : Icons.event_note_outlined,
                    color: occurrence.isPaid ? const Color(0xFF2E8C60) : Theme.of(context).colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(plan.kind == PaymentKind.installment
                      ? '${occurrence.sequence}. taksit' : '${occurrence.sequence}. dönem',
                      style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 3),
                    Text(formatDate(occurrence.dueDate),
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
                    const SizedBox(height: 5),
                    StatusPill(due: occurrence),
                  ])),
                  if (!isCompact) ...[
                    Text(formatCompactMoney(occurrence.amountCents), style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(width: 8),
                  ],
                  PopupMenuButton<String>(
                    tooltip: 'Taksit işlemleri',
                    onSelected: (value) {
                      if (value == 'pay') _paid(context, occurrence);
                      if (value == 'undo') _undo(context, occurrence);
                      if (value == 'date') _editDate(context, occurrence);
                    },
                    itemBuilder: (_) => occurrence.isPaid ? [
                      const PopupMenuItem(value: 'undo', child: Text('Ödemeyi geri al')),
                    ] : [
                      const PopupMenuItem(value: 'pay', child: Text('Ödendi olarak işaretle')),
                      const PopupMenuItem(value: 'date', child: Text('Vade tarihini değiştir')),
                    ],
                  ),
                ]))),
                const SizedBox(height: 9),
              ],
              if (remaining.isNotEmpty) ...[
                const SizedBox(height: 12),
                FilledButton.icon(onPressed: () => _paid(context, remaining.first),
                  icon: const Icon(Icons.check_circle_outline),
                  label: Text(plan.direction == PaymentDirection.incoming ? 'Sıradaki tahsilat alındı' : 'Sıradaki ödeme yapıldı')),
              ],
              const SizedBox(height: 24),
              Text('Ödeme işaretlemek gerçek para transferi yapmaz; yalnızca kendi takibinizi günceller.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
            ]),
          )),
        );
      },
    );
  }

  Widget _detailLine(BuildContext context, String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 13))),
      Expanded(child: Text(value, style: Theme.of(context).textTheme.bodyLarge)),
    ]),
  );
}
