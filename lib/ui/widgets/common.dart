import 'package:flutter/material.dart';
import '../../models/payment.dart';

class SectionTitle extends StatelessWidget {
  final String text;
  final Widget? trailing;
  const SectionTitle(this.text, {super.key, this.trailing});
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 13),
    child: Row(children: [
      Expanded(child: Text(text, style: Theme.of(context).textTheme.titleLarge)),
      if (trailing != null) trailing!,
    ]),
  );
}

class SummaryTile extends StatelessWidget {
  final String title, value, footer;
  final IconData icon;
  const SummaryTile({super.key, required this.title, required this.value,
    required this.footer, required this.icon});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(child: Padding(
      padding: const EdgeInsets.all(17),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 42, height: 42, alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: .10),
              borderRadius: BorderRadius.circular(14)),
            child: Icon(icon, color: scheme.primary, size: 21)),
        ]),
        const SizedBox(height: 16),
        Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
          child: Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w900, letterSpacing: -.5))),
        const SizedBox(height: 6),
        Text(footer, maxLines: 2, overflow: TextOverflow.ellipsis,
          style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11, height: 1.3)),
      ]),
    ));
  }
}

class StatusPill extends StatelessWidget {
  final DueItem due;
  const StatusPill({super.key, required this.due});
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (label, foreground) = switch ((due.isPaid, due.daysLeft)) {
      (true, _) => ('Ödendi', dark ? const Color(0xFF91DDB9) : const Color(0xFF23794F)),
      (false, < 0) => ('Gecikti', dark ? const Color(0xFFFFB1A5) : const Color(0xFFAE3D37)),
      (false, 0) => ('Bugün', dark ? const Color(0xFFFFB1A5) : const Color(0xFFAE3D37)),
      (false, 1) => ('Yarın', dark ? const Color(0xFFFFC58D) : const Color(0xFF996010)),
      (false, <= 5) => ('Yaklaşıyor', dark ? const Color(0xFFFFC58D) : const Color(0xFF996010)),
      _ => ('Planlandı', Theme.of(context).colorScheme.primary),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: foreground.withValues(alpha: .10), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: foreground, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }
}

class PaymentRowCard extends StatelessWidget {
  final DueItem due;
  final VoidCallback onTap;
  final VoidCallback onPaid;
  const PaymentRowCard({super.key, required this.due,
    required this.onTap, required this.onPaid});
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = due.plan.kind == PaymentKind.invoice
      ? due.plan.category.icon : due.plan.kind.icon;
    final incoming = due.plan.direction == PaymentDirection.incoming;
    final amountColor = incoming ? scheme.primary : scheme.onSurface;
    return Card(child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(builder: (context, c) {
          final narrow = c.maxWidth < 475;
          final heading = Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Container(width: 46, height: 46, alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .09),
                borderRadius: BorderRadius.circular(15)),
              child: Icon(icon, size: 23, color: scheme.primary)),
            const SizedBox(width: 13),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(due.plan.title, maxLines: 2, overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800)),
              const SizedBox(height: 5),
              Text(due.plan.party.isEmpty ? due.plan.kind.label : due.plan.party,
                maxLines: 1, overflow: TextOverflow.ellipsis,
                style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              const SizedBox(height: 9),
              Wrap(spacing: 7, runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center, children: [
                StatusPill(due: due),
                Text(formatDate(due.dueDate),
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                if (due.plan.kind == PaymentKind.installment)
                  Text('${due.sequence}/${due.plan.count} taksit',
                    style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ]),
            ])),
          ]);
          final amount = Text(formatCompactMoney(due.amountCents),
            maxLines: 1, overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: amountColor, fontWeight: FontWeight.w900, letterSpacing: -.5));
          final action = FilledButton.tonalIcon(
            onPressed: onPaid, icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
            label: Text(incoming ? 'Tahsil edildi' : 'Ödendi'),
          );
          if (narrow) {
            return Column(children: [
              heading,
              const SizedBox(height: 15),
              Divider(height: 1, color: scheme.outlineVariant.withValues(alpha: .55)),
              const SizedBox(height: 11),
              Row(children: [
                Expanded(child: amount),
                const SizedBox(width: 8),
                action,
              ]),
            ]);
          }
          return Row(children: [
            Expanded(child: heading),
            const SizedBox(width: 15),
            Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
              amount,
              const SizedBox(height: 10),
              action,
            ]),
          ]);
        }),
      ),
    ));
  }
}

class EmptyView extends StatelessWidget {
  final String title, message;
  final IconData icon;
  const EmptyView({super.key, required this.title, required this.message, required this.icon});
  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Center(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 46), child: Column(
      mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 48, color: color.onSurfaceVariant.withValues(alpha: .65)),
        const SizedBox(height: 15),
        Text(title, style: Theme.of(context).textTheme.titleLarge, textAlign: TextAlign.center),
        const SizedBox(height: 7),
        Text(message, textAlign: TextAlign.center, style: TextStyle(color: color.onSurfaceVariant)),
      ],
    )));
  }
}

Future<bool> confirmAction(BuildContext context, {required String title, required String body, String confirm = 'Onayla', bool destructive = false}) async {
  return await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title), content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(dialogContext, false), child: const Text('Vazgeç')),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.error,
            foregroundColor: Theme.of(context).colorScheme.onError) : null,
          onPressed: () => Navigator.pop(dialogContext, true), child: Text(confirm),
        ),
      ],
    ),
  ) ?? false;
}

void showError(BuildContext context, Object error) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('İşlem tamamlanamadı: $error')));
}

void showSuccess(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}
