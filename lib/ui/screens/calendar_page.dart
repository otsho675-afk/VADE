import 'package:flutter/material.dart';
import '../../models/payment.dart';
import '../../state/app_store.dart';
import '../widgets/common.dart';
import '../widgets/wheel_date_picker.dart';
import 'payment_detail_page.dart';

class CalendarPage extends StatefulWidget {
  final AppStore store;
  const CalendarPage({super.key, required this.store});
  @override
  State<CalendarPage> createState() => _CalendarPageState();
}

class _CalendarPageState extends State<CalendarPage> {
  DateTime _selected = dateOnly(DateTime.now());
  DateTime _month = dateOnly(DateTime.now());

  void _jumpMonth(int offset) {
    final next = DateTime(_month.year, _month.month + offset, 1);
    if (next.isBefore(DateTime(2020)) || next.isAfter(DateTime(2120, 12))) return;
    final lastDay = DateTime(next.year, next.month + 1, 0).day;
    setState(() {
      _month = next;
      _selected = DateTime(next.year, next.month, _selected.day.clamp(1, lastDay));
    });
  }

  void _jumpToday() => setState(() {
    _selected = dateOnly(DateTime.now());
    _month = DateTime(_selected.year, _selected.month);
  });

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final daily = widget.store.items.where((item) => dateOnly(item.dueDate) == _selected).toList()
        ..sort((a, b) {
          if (a.isPaid != b.isPaid) return a.isPaid ? 1 : -1;
          return a.amountCents.compareTo(b.amountCents);
        });
      final dayOutgoing = daily.where((item) => !item.isPaid &&
          item.plan.direction == PaymentDirection.outgoing).fold<int>(0, (sum, item) => sum + item.amountCents);
      final dayIncoming = daily.where((item) => !item.isPaid &&
          item.plan.direction == PaymentDirection.incoming).fold<int>(0, (sum, item) => sum + item.amountCents);
      final overdue = widget.store.unpaidItems.where((item) => item.isLate).length;
      final monthly = widget.store.items.where((item) => !item.isPaid &&
          item.dueDate.year == _month.year && item.dueDate.month == _month.month);
      final outgoing = monthly.where((item) => item.plan.direction == PaymentDirection.outgoing)
          .fold<int>(0, (sum, item) => sum + item.amountCents);
      final incoming = monthly.where((item) => item.plan.direction == PaymentDirection.incoming)
          .fold<int>(0, (sum, item) => sum + item.amountCents);
      return Scaffold(
        appBar: AppBar(title: const Text('Ödeme takvimi')),
        body: Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: ListView(padding: const EdgeInsets.all(18), children: [
            Text('VADE TAKVİMİ', style: TextStyle(color: Theme.of(context).colorScheme.primary,
              fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
            const SizedBox(height: 7),
            Text('Vadelerin bir bakışta', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 5),
            Text('Gün seçerek bekleyen ödemeleri ve tahsilatları gör.',
              style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 19),
            OutlinedButton.icon(
              onPressed: () async {
                final date = await showWheelDatePicker(context: context, initialDate: _selected,
                  firstDate: DateTime(2020), lastDate: DateTime(2120, 12, 31));
                if (date != null && mounted) setState(() { _selected = date; _month = date; });
              },
              icon: const Icon(Icons.unfold_more_rounded), label: const Text('Kaydırarak tarih seç')),
            const SizedBox(height: 12),
            Card(child: Column(children: [
              Padding(padding: const EdgeInsets.fromLTRB(9, 8, 9, 1), child: Row(children: [
                IconButton(tooltip: 'Önceki ay', onPressed: () => _jumpMonth(-1),
                  icon: const Icon(Icons.chevron_left_rounded)),
                Expanded(child: Center(child: Text('${_month.month} / ${_month.year}',
                  style: Theme.of(context).textTheme.titleMedium))),
                TextButton(onPressed: _jumpToday, child: const Text('Bugün')),
                IconButton(tooltip: 'Sonraki ay', onPressed: () => _jumpMonth(1),
                  icon: const Icon(Icons.chevron_right_rounded)),
              ])),
              const Divider(height: 1),
              CalendarDatePicker(
              key: ValueKey(_selected),
              initialDate: _selected, firstDate: DateTime(2020), lastDate: DateTime(2120, 12, 31),
              onDateChanged: (value) => setState(() { _selected = value; _month = DateTime(value.year, value.month); }),
              onDisplayedMonthChanged: (value) => setState(() {
                _month = DateTime(value.year, value.month);
                if (_selected.year != value.year || _selected.month != value.month) {
                  final lastDay = DateTime(value.year, value.month + 1, 0).day;
                  _selected = DateTime(value.year, value.month, _selected.day.clamp(1, lastDay));
                }
              }),
              ),
            ])),
            const SizedBox(height: 19),
            SectionTitle('${_month.month} / ${_month.year} · Bekleyen ödemeler'),
            Card(child: Padding(padding: const EdgeInsets.all(17), child: Column(children: [
              Row(children: [
                Expanded(child: _CalendarMetric(label: 'Aylık borç', value: formatMoney(outgoing),
                  icon: Icons.north_east_rounded)),
                const SizedBox(width: 12),
                Expanded(child: _CalendarMetric(label: 'Aylık alacak', value: formatMoney(incoming),
                  icon: Icons.south_west_rounded)),
              ]),
              const Divider(height: 25),
              Row(children: [
                Icon(Icons.schedule_rounded, size: 18, color: Theme.of(context).colorScheme.error),
                const SizedBox(width: 7),
                Expanded(child: Text('Geciken kayıtlar: $overdue',
                  style: Theme.of(context).textTheme.titleMedium)),
              ]),
            ]))),
            const SizedBox(height: 22),
            SectionTitle(formatDate(_selected)),
            const SizedBox(height: 7),
            Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(children: [
              Expanded(child: _CalendarMetric(label: 'Günlük borç', value: formatMoney(dayOutgoing),
                icon: Icons.north_east_rounded)),
              const SizedBox(width: 12),
              Expanded(child: _CalendarMetric(label: 'Günlük alacak', value: formatMoney(dayIncoming),
                icon: Icons.south_west_rounded)),
            ]))),
            const SizedBox(height: 12),
            if (daily.isEmpty) const EmptyView(title: 'Bu gün için kayıt yok',
              message: 'Başka bir tarih seçebilirsiniz.', icon: Icons.event_available_outlined),
            for (final item in daily) ...[
              Card(child: ListTile(
                leading: Icon(item.isPaid ? Icons.check_circle_outline : Icons.event_outlined),
                title: Text(item.plan.title),
                subtitle: Text('${item.plan.direction.label} · ${item.isPaid ? "Tamamlandı" : "Bekliyor"}'),
                trailing: Text(formatCompactMoney(item.amountCents)),
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) =>
                  PaymentDetailPage(store: widget.store, planId: item.planId))),
              )),
              const SizedBox(height: 8),
            ],
            const SizedBox(height: 18),
            const Text('Fatura ve aboneliklerde yalnızca oluşturulmuş dönemler gösterilir.'),
          ]),
        )),
      );
    },
  );
}

class _CalendarMetric extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _CalendarMetric({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Icon(icon, size: 18, color: scheme.primary),
      const SizedBox(height: 7),
      Text(label, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 11,
        fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      FittedBox(alignment: Alignment.centerLeft, fit: BoxFit.scaleDown,
        child: Text(value, style: Theme.of(context).textTheme.titleMedium)),
    ]);
  }
}
