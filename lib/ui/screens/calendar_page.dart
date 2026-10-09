import 'package:flutter/material.dart';
import '../../models/payment.dart';
import '../../state/app_store.dart';
import '../widgets/common.dart';
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

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: widget.store,
    builder: (context, _) {
      final daily = widget.store.items.where((item) => dateOnly(item.dueDate) == _selected).toList();
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
            Card(child: CalendarDatePicker(
              initialDate: _selected, firstDate: DateTime(2020), lastDate: DateTime(2120, 12, 31),
              onDateChanged: (value) => setState(() => _selected = value),
              onDisplayedMonthChanged: (value) => setState(() => _month = value),
            )),
            const SizedBox(height: 14),
            Text('${_month.month} / ${_month.year} · Bekleyen ödemeler',
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Borç: ${formatMoney(outgoing)}    Alacak: ${formatMoney(incoming)}'),
            const SizedBox(height: 22),
            SectionTitle(formatDate(_selected)),
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
