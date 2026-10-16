import 'package:flutter/material.dart';
import '../../models/payment.dart';
import '../../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/transfer_details_card.dart';
import '../widgets/wheel_date_picker.dart';
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
    final choice = await showWheelDatePicker(
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(22),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF163340), Color(0xFF0D766F)]),
                  borderRadius: BorderRadius.circular(25)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Expanded(child: Text('ÖDEME PLANI', style: TextStyle(
                      color: Color(0xFFB9E9DE), fontSize: 11,
                      letterSpacing: 1.4, fontWeight: FontWeight.w800))),
                    Icon(plan.kind == PaymentKind.invoice ? plan.category.icon : plan.kind.icon,
                      color: Colors.white, size: 25),
                  ]),
                  const SizedBox(height: 15),
                  Text(plan.title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: Colors.white, height: 1.17)),
                  const SizedBox(height: 7),
                  Text('${plan.kind.label} · ${plan.direction.label}',
                    style: const TextStyle(color: Color(0xFFD4F3EB), fontSize: 13)),
                  const SizedBox(height: 20),
                  const Divider(color: Color(0x6686C7BE), height: 1),
                  const SizedBox(height: 16),
                  const Text('PLAN TUTARI', style: TextStyle(color: Color(0xFFB9E9DE),
                    fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1.2)),
                  const SizedBox(height: 5),
                  FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
                    child: Text(formatMoney(plan.amountCents), style: const TextStyle(
                      color: Colors.white, fontSize: 31, fontWeight: FontWeight.w900,
                      letterSpacing: -1))),
                ]),
              ),
              const SizedBox(height: 13),
              Card(child: Padding(padding: const EdgeInsets.all(19), child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Plan özeti', style: Theme.of(context).textTheme.titleLarge),
                  const SizedBox(height: 17),
                  _detailLine(context, 'İlk vade', formatDate(plan.startDate)),
                  if (plan.kind == PaymentKind.installment)
                    _detailLine(context, 'Taksit sayısı', '${paid.length} / ${plan.count} ödendi'),
                  if (plan.kind.isRecurring)
                    _detailLine(context, 'Tekrar', 'Her ay · ödendiğinde sonraki dönem oluşturulur'),
                  _detailLine(context, 'Ödenen toplam', formatMoney(totalPaid)),
                  if (plan.isFinite)
                    _detailLine(context, 'Kalan tutar', formatMoney(remaining.fold(0, (sum, e) => sum + e.amountCents))),
                ],
              ))),
              if (plan.party.isNotEmpty || plan.iban.isNotEmpty) ...[
                const SizedBox(height: 13),
                TransferDetailsCard(party: plan.party, iban: plan.iban),
              ],
              if (plan.note.isNotEmpty) ...[
                const SizedBox(height: 13),
                Card(child: Padding(padding: const EdgeInsets.all(19),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Not', style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 9),
                    Text(plan.note),
                  ]))),
              ],
              const SizedBox(height: 25),
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
