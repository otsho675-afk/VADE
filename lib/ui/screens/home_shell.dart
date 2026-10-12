import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'account_page.dart';
import 'auth_page.dart';
import '../widgets/brand_mark.dart';
import '../widgets/wheel_date_picker.dart';
import '../../models/payment.dart';
import '../../services/ledger_insights.dart';
import '../../state/app_store.dart';
import '../../services/cloud_config.dart';
import '../widgets/common.dart';
import 'payment_detail_page.dart';
import 'payment_form_page.dart';
import 'backup_page.dart';
import 'calendar_page.dart';

class HomeShell extends StatefulWidget {
  final AppStore store;
  const HomeShell({super.key, required this.store});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _selected = 0;
  String _search = '';
  String _filter = 'Tümü';
  LedgerSort _sort = LedgerSort.nearest;
  bool _showAllInstallments = false;
  bool _notificationIntroScheduled = false;
  final _searchController = TextEditingController();

  AppStore get store => widget.store;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    // Adding a payment never shows another notification opt-in prompt.
    await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => PaymentFormPage(store: store)));
  }

  void _showFirstNotificationChoice() {
    if (!mounted || store.notificationIntroSeen) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      enableDrag: false,
      useSafeArea: true,
      builder: (sheetContext) {
        final scheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(26, 6, 26, 30),
          child: Column(mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Align(alignment: Alignment.centerLeft, child: Container(
              width: 62, height: 62,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: .11),
                borderRadius: BorderRadius.circular(19)),
              child: Icon(Icons.notifications_active_outlined,
                color: scheme.primary, size: 31),
            )),
            const SizedBox(height: 23),
            Text('Vadelerini birlikte hatırlayalım',
              style: Theme.of(sheetContext).textTheme.headlineMedium),
            const SizedBox(height: 11),
            Text('Taksit ve faturaların yaklaşırken sana haber verelim. '
              'Tek dokunuşla aç, zamanında haberdar ol.',
              style: Theme.of(sheetContext).textTheme.bodyLarge),
            const SizedBox(height: 22),
            for (final (icon, title) in [
              (Icons.event_available_rounded, 'Vadeden 5 gün önce'),
              (Icons.notifications_none_rounded, 'Bir gün önce ve vade günü'),
              (Icons.history_toggle_off_rounded, 'Geciken ödemelerde'),
            ]) Padding(padding: const EdgeInsets.only(bottom: 12),
              child: Row(children: [
                Icon(icon, color: scheme.primary, size: 21),
                const SizedBox(width: 13),
                Expanded(child: Text(title,
                  style: Theme.of(sheetContext).textTheme.titleMedium)),
              ])),
            const SizedBox(height: 14),
            FilledButton.icon(
              icon: const Icon(Icons.notifications_active_outlined),
              label: const Text('Bildirimleri aç'),
              onPressed: () async {
                Navigator.pop(sheetContext);
                try {
                  final granted = await store.setNotifications(true);
                  if (!granted && mounted) {
                    showError(context, await store.reminders.permissionFailureMessage());
                  }
                } catch (error) {
                  if (mounted) showError(context, error);
                }
              },
            ),
            const SizedBox(height: 6),
            TextButton(
              onPressed: () async {
                Navigator.pop(sheetContext);
                await store.finishNotificationIntro();
              },
              child: const Text('Şimdi değil'),
            ),
            const SizedBox(height: 5),
            Text('Kararını Ayarlar bölümünden istediğin zaman değiştirebilirsin.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ]),
        );
      },
    );
  }

  void _openDetails(DueItem item) => Navigator.push(context,
    MaterialPageRoute(builder: (_) => PaymentDetailPage(store: store, planId: item.planId)));

  Future<void> _pay(DueItem item) async {
    try {
      await store.markPaid(item);
      if (!mounted) return;
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(item.plan.direction == PaymentDirection.incoming
          ? 'Tahsilat kaydedildi, takip güncellendi.'
          : 'Ödeme kaydedildi, sonraki taksit hazır.'),
        action: SnackBarAction(label: 'GERİ AL', onPressed: () async {
          try {
            await store.undoPaid(item);
          } catch (e) {
            if (mounted) showError(context, e);
          }
        }),
      ));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    final desktop = width >= 960;
    final extended = width >= 1240;
    return AnimatedBuilder(animation: Listenable.merge([store, store.cloud]), builder: (context, _) {
      if (store.loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
      if (store.notificationIntroReady && !store.notificationIntroSeen &&
          store.supportsNotifications && !_notificationIntroScheduled &&
          store.error == null) {
        _notificationIntroScheduled = true;
        WidgetsBinding.instance.addPostFrameCallback((_) => _showFirstNotificationChoice());
      }
      if (store.error != null) { return Scaffold(body: SafeArea(child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          EmptyView(title: 'Uygulama açılamadı', message: store.error!, icon: Icons.error_outline),
          FilledButton.icon(onPressed: store.initialize, icon: const Icon(Icons.refresh),
            label: const Text('Yeniden dene')),
        ],
      ))); }
      return Scaffold(
        body: SafeArea(child: Row(children: [
          if (desktop) ...[
            NavigationRail(
              selectedIndex: _selected,
              extended: extended,
              minExtendedWidth: 210,
              onDestinationSelected: (v) => setState(() => _selected = v),
              leading: Padding(
                padding: const EdgeInsets.fromLTRB(12, 19, 12, 34),
                child: extended ? Row(mainAxisSize: MainAxisSize.min, children: [
                  const BrandMark(size: 36),
                  const SizedBox(width: 10),
                  const Text('VADESİ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, letterSpacing: .8)),
                ]) : const BrandMark(size: 36),
              ),
              destinations: const [
                NavigationRailDestination(icon: Icon(Icons.grid_view_outlined),
                  selectedIcon: Icon(Icons.grid_view_rounded), label: Text('Genel bakış')),
                NavigationRailDestination(icon: Icon(Icons.receipt_long_outlined),
                  selectedIcon: Icon(Icons.receipt_long_rounded), label: Text('Ödemeler')),
                NavigationRailDestination(icon: Icon(Icons.insert_chart_outlined),
                  selectedIcon: Icon(Icons.insert_chart_rounded), label: Text('Raporlar')),
                NavigationRailDestination(icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings_rounded), label: Text('Ayarlar')),
              ],
            ),
            VerticalDivider(width: 1, color: Theme.of(context).dividerColor),
          ],
          Expanded(child: Column(children: [
            Container(
              padding: EdgeInsets.fromLTRB(width < 420 ? 17 : 24, 12,
                  width < 420 ? 17 : 24, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
              ),
              child: Row(children: [
                if (!desktop) ...[
                  Container(
                    width: 45, height: 45,
                    padding: const EdgeInsets.all(7),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF153C51), Color(0xFF166969)],
                        begin: Alignment.topLeft, end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(15)),
                    child: const BrandMark(size: 31),
                  ),
                  const SizedBox(width: 11),
                  Expanded(child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('VADESİ', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900, letterSpacing: .6)),
                    Text(['Finansal kontrol panelin', 'Ödemelerini yönet', 'Nakit akışını keşfet', 'Tercihlerin'][_selected],
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant,
                        fontSize: 11)),
                  ])),
                ] else Expanded(child: Text(
                  ['Genel bakış', 'Ödemeler', 'Raporlar', 'Ayarlar'][_selected],
                  style: Theme.of(context).textTheme.headlineSmall)),
                IconButton(
                  tooltip: 'Ödeme takvimi',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .08)),
                  icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => CalendarPage(store: store))),
                ),
                const SizedBox(width: 7),
                IconButton(
                  tooltip: store.cloud.user == null ? 'Giriş yap / Üye ol' : 'Hesabım',
                  style: IconButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .08)),
                  icon: const Icon(Icons.person_outline_rounded),
                  onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => AccountPage(store: store))),
                ),
                const SizedBox(width: 7),
                if (desktop) FilledButton.icon(
                  onPressed: _openAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni ödeme'))
                else IconButton.filled(
                  tooltip: 'Yeni ödeme ekle',
                  onPressed: _openAdd,
                  icon: const Icon(Icons.add_rounded),
                ),
              ]),
            ),
            Expanded(child: switch (_selected) {
              0 => _dashboard(),
              1 => _paymentsPage(),
              2 => _reportsPage(),
              _ => _settingsPage(),
            }),
          ])),
        ])),
        bottomNavigationBar: desktop ? null : DecoratedBox(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .04),
              blurRadius: 18, offset: const Offset(0, -4))],
          ),
          child: NavigationBar(
            selectedIndex: _selected,
            onDestinationSelected: (v) => setState(() => _selected = v),
            destinations: const [
              NavigationDestination(icon: Icon(Icons.space_dashboard_outlined),
                selectedIcon: Icon(Icons.space_dashboard_rounded), label: 'Genel'),
              NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
                selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Ödemeler'),
              NavigationDestination(icon: Icon(Icons.bar_chart_outlined),
                selectedIcon: Icon(Icons.bar_chart_rounded), label: 'Raporlar'),
              NavigationDestination(icon: Icon(Icons.tune_rounded),
                selectedIcon: Icon(Icons.tune_rounded), label: 'Ayarlar'),
            ],
          ),
        ),
      );
    });
  }

  Widget _pageLayout(Widget child) => LayoutBuilder(builder: (context, constraints) {
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(18, 21, 18, 42),
      child: Align(alignment: Alignment.topCenter, child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1120), child: child)),
    );
  });

  Widget _dashboard() => _pageLayout(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Finansın kontrol altında', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('Taksitlerin, faturaların ve alacakların tek ekranda.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      Container(
        width: 43, height: 43,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
          borderRadius: BorderRadius.circular(14)),
        child: Icon(Icons.insights_rounded, color: Theme.of(context).colorScheme.primary)),
    ]),
    const SizedBox(height: 22),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF112E43), Color(0xFF126565), Color(0xFF1B777B)]),
        borderRadius: BorderRadius.circular(26),
        boxShadow: [BoxShadow(color: const Color(0xFF112E43).withValues(alpha: .19),
          blurRadius: 30, offset: const Offset(0, 13))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('TOPLAM AÇIK BORÇ',
            style: TextStyle(color: Color(0xFFDCEEF8), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600))),
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFDCEEF8)),
        ]),
        const SizedBox(height: 14),
        FittedBox(fit: BoxFit.scaleDown, child: Text(formatCompactMoney(store.monthOutgoing),
          style: const TextStyle(color: Colors.white, fontSize: 39, fontWeight: FontWeight.w900, letterSpacing: -1.2))),
        const SizedBox(height: 8),
        const Text('Vadesi gelen ve gecikmiş borçların toplamı',
          style: TextStyle(color: Color(0xFFDCEEF8), fontSize: 12)),
        const SizedBox(height: 18),
        const Divider(color: Color(0x557BC3C5), height: 1),
        const SizedBox(height: 18),
        Wrap(spacing: 10, runSpacing: 10, children: [
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFE7FCF8),
              foregroundColor: const Color(0xFF123C49)),
            onPressed: _openAdd, icon: const Icon(Icons.add_rounded), label: const Text('Ödeme ekle')),
          TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarPage(store: store))),
            icon: const Icon(Icons.calendar_month_outlined), label: const Text('Takvim')),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth < 320 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: width, child: SummaryTile(title: 'Beklenen tahsilat', value: formatCompactMoney(store.monthIncoming),
          footer: 'Bu aya kadar alacaklar', icon: Icons.south_west_rounded)),
        SizedBox(width: width, child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: store.lateCount == 0 ? null : () => setState(() {
            _selected = 1;
            _filter = 'Gecikenler';
            _showAllInstallments = true;
          }),
          child: SummaryTile(title: 'Geciken kayıt', value: '${store.lateCount}',
            footer: store.lateCount == 0 ? 'Her şey yolunda' : 'Dokun, geciken taksitleri gör',
            icon: Icons.schedule_rounded),
        )),
        SizedBox(width: width, child: SummaryTile(title: 'Geciken borç', value: formatCompactMoney(store.lateOutgoingAmount),
          footer: 'Vadesi geçmiş ödenmemiş borçlar', icon: Icons.warning_amber_rounded)),
        SizedBox(width: width, child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => setState(() { _selected = 1; _filter = '7 Gün'; _showAllInstallments = true; }),
          child: SummaryTile(title: 'Önümüzdeki 7 gün', value: formatCompactMoney(store.next7DaysOutgoing),
            footer: 'Dokun, bu haftanın ödemelerini gör', icon: Icons.date_range_outlined),
        )),
      ]);
    }),
    if (store.cloud.user == null) ...[
      const SizedBox(height: 18),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('VADESİ hesabınla devam et', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text('Üyeliğini ve isteğe bağlı bulut yedeğini tek yerden yönet.'),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AuthPage(store: store))), child: const Text('Giriş yap')),
            TextButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
              builder: (_) => AuthPage(store: store, register: true))), child: const Text('Üye ol')),
          ]),
        ],
      ))),
    ],
    const SizedBox(height: 17),
    Wrap(spacing: 8, runSpacing: 8, children: [
      ActionChip(
        avatar: const Icon(Icons.today_rounded, size: 18),
        label: const Text('Bugünün ödemeleri'),
        onPressed: () => setState(() {
          _selected = 1;
          _filter = 'Bugün';
          _showAllInstallments = true;
        }),
      ),
      ActionChip(
        avatar: const Icon(Icons.bar_chart_rounded, size: 18),
        label: const Text('6 aylık nakit akışı'),
        onPressed: () => setState(() => _selected = 2),
      ),
    ]),
    const SizedBox(height: 22),
    SectionTitle('Sıradaki ödemeler', trailing: TextButton(onPressed: () => setState(() => _selected = 1),
      child: const Text('Tümünü gör'))),
    if (store.upcoming.isEmpty)
      const Card(child: EmptyView(title: 'Henüz ödeme yok',
        message: 'İlk taksitinizi veya faturanızı ekleyerek başlayın.', icon: Icons.fact_check_outlined))
    else for (final item in store.upcoming.take(7)) ...[
      PaymentRowCard(due: item, onTap: () => _openDetails(item), onPaid: () => _pay(item)),
      const SizedBox(height: 10),
    ],
    const SizedBox(height: 14),
    Card(child: Padding(padding: const EdgeInsets.all(17), child: Row(children: [
      Icon(Icons.notifications_active_outlined, color: Theme.of(context).colorScheme.primary),
      const SizedBox(width: 12),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Bildirimler', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 4),
        Text(store.reminderError ?? (store.notificationsEnabled
            ? 'Vade öncesi, vade günü ve gecikme uyarıları planlandı.'
            : 'Bildirimler kapalı. Ayarlar bölümünden açabilirsiniz.'),
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
      ])),
      TextButton(onPressed: () => setState(() => _selected = 3), child: const Text('Ayarla')),
    ]))),
  ]));

  Widget _paymentsPage() => _pageLayout(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Text('Ödeme listesi', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 4),
    Text('Borç, taksit, fatura ve alacak kayıtlarını görüntüleyin.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 17),
    TextField(
      controller: _searchController,
      textInputAction: TextInputAction.search,
      onSubmitted: (_) => FocusManager.instance.primaryFocus?.unfocus(),
      onChanged: (v) => setState(() => _search = v.trim().toLowerCase()),
      decoration: InputDecoration(
        prefixIcon: const Icon(Icons.search_rounded),
        hintText: 'Ödeme veya kişi ara',
        suffixIcon: _search.isEmpty ? null : IconButton(
          tooltip: 'Aramayı temizle',
          onPressed: () { _searchController.clear(); setState(() => _search = ''); },
          icon: const Icon(Icons.close_rounded),
        ),
      ),
    ),
    const SizedBox(height: 10),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      for (final f in ['Tümü', 'Bugün', '7 Gün', 'Bu ay', 'Gecikenler', 'Borçlar', 'Alacaklar', 'Taksit', 'Fatura', 'Abonelik', 'Tek seferlik', 'Geçmiş']) ...[
        ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
        const SizedBox(width: 8),
      ],
    ])),
    const SizedBox(height: 12),
    Wrap(spacing: 8, runSpacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
      const Text('Sırala:'),
      DropdownButton<LedgerSort>(
        value: _sort,
        items: const [
          DropdownMenuItem(value: LedgerSort.nearest, child: Text('En yakın vade')),
          DropdownMenuItem(value: LedgerSort.latest, child: Text('En uzak vade')),
          DropdownMenuItem(value: LedgerSort.highest, child: Text('En yüksek tutar')),
          DropdownMenuItem(value: LedgerSort.lowest, child: Text('En düşük tutar')),
          DropdownMenuItem(value: LedgerSort.name, child: Text('Ada göre')),
        ],
        onChanged: (value) { if (value != null) setState(() => _sort = value); },
      ),
    ]),
    const SizedBox(height: 7),
    Row(children: [
      const Expanded(child: Text('Tüm açık taksitleri ayrı ayrı göster')),
      Switch.adaptive(
        value: _showAllInstallments,
        onChanged: (value) => setState(() => _showAllInstallments = value),
      ),
    ]),
    const SizedBox(height: 12),
    Builder(builder: (context) {
      final showEveryPeriod = _showAllInstallments ||
        const ['Gecikenler', 'Bugün', '7 Gün', 'Bu ay'].contains(_filter);
      final source = _filter == 'Geçmiş' ? store.history :
        (showEveryPeriod ? store.unpaidItems : store.upcoming);
      final filtered = LedgerInsights.filterAndSort(
        source, filter: _filter, search: _search, sort: _sort,
      );
      final outstanding = filtered.where((e) => e.plan.direction == PaymentDirection.outgoing)
        .fold<int>(0, (sum, e) => sum + e.amountCents);
      return Column(children: [
        Align(alignment: Alignment.centerLeft, child: Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_filter == 'Geçmiş' ? '${filtered.length} tamamlanan kayıt'
            : '${filtered.length} kayıt · ${formatCompactMoney(outstanding)} gösterilen borç',
            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        )),
        if (filtered.isEmpty) ...[
          const Card(child: EmptyView(title: 'Sonuç bulunamadı',
            message: 'Arama veya filtre koşullarını değiştirebilirsiniz.', icon: Icons.search_off_rounded)),
          TextButton.icon(
            icon: const Icon(Icons.filter_alt_off_outlined),
            label: const Text('Filtreleri temizle'),
            onPressed: () { _searchController.clear(); setState(() {
              _search = '';
              _filter = 'Tümü';
              _showAllInstallments = false;
              _sort = LedgerSort.nearest;
            }); },
          ),
        ] else ...[for (final p in filtered) ...[
            if (_filter == 'Geçmiş')
              Card(child: ListTile(
                leading: const Icon(Icons.check_circle_outline_rounded),
                title: Text(p.plan.title),
                subtitle: Text('${formatDate(p.dueDate)} · ${p.plan.party}'),
                trailing: Text(formatCompactMoney(p.amountCents)),
                onTap: () => _openDetails(p),
              ))
            else PaymentRowCard(due: p, onTap: () => _openDetails(p), onPaid: () => _pay(p)),
            const SizedBox(height: 10),
          ]],
      ]);
    }),
  ]));

  Widget _reportsPage() {
    final all = store.items;
    final historical = store.history;
    final cashFlow = LedgerInsights.forecast(store.items);
    final overdueIncoming = LedgerInsights.overdueIncoming(store.items);
    final outgoingOpen = store.unpaidItems.where((p) =>
      p.plan.direction == PaymentDirection.outgoing
    ).fold<int>(0, (sum, p) => sum + p.amountCents);
    final chartMax = cashFlow.fold<int>(0, (maxValue, month) {
      final candidate = month.outgoingCents > month.incomingCents
        ? month.outgoingCents : month.incomingCents;
      return candidate > maxValue ? candidate : maxValue;
    });
    const monthNames = [
      'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
      'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık',
    ];
    final outgoingPaid = historical.where((p) => p.plan.direction == PaymentDirection.outgoing)
      .fold<int>(0, (value, item) => value + item.amountCents);
    final received = historical.where((p) => p.plan.direction == PaymentDirection.incoming)
      .fold<int>(0, (value, item) => value + item.amountCents);
    final futureInstallments = all.where((p) => !p.isPaid && p.plan.isFinite)
      .fold<int>(0, (sum, p) => sum + (p.plan.direction == PaymentDirection.outgoing ? p.amountCents : 0));
    final categories = <String, int>{};
    for (final p in store.unpaidItems.where((p) => p.plan.direction == PaymentDirection.outgoing)) {
      final key = p.plan.kind == PaymentKind.invoice ? p.plan.category.label : p.plan.kind.label;
      categories[key] = (categories[key] ?? 0) + p.amountCents;
    }
    final sortedCategories = categories.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return _pageLayout(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Finansal özet', style: Theme.of(context).textTheme.headlineMedium),
      const SizedBox(height: 5),
      Text('Kaydettiğiniz işlemlere dayalı kişisel takip raporu.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      const SizedBox(height: 21),
      LayoutBuilder(builder: (context, c) {
        final cols = c.maxWidth >= 740 ? 3 : c.maxWidth >= 420 ? 2 : 1;
        final w = (c.maxWidth - 12 * (cols - 1)) / cols;
        return Wrap(spacing: 12, runSpacing: 12, children: [
          SizedBox(width: w, child: SummaryTile(title: 'Kaydedilen ödemeler', value: formatCompactMoney(outgoingPaid),
            footer: '${historical.where((p) => p.plan.direction == PaymentDirection.outgoing).length} ödeme', icon: Icons.check_circle_outline)),
          SizedBox(width: w, child: SummaryTile(title: 'Tahsil edilen', value: formatCompactMoney(received),
            footer: 'Alacak geçmişi', icon: Icons.call_received_rounded)),
          SizedBox(width: w, child: SummaryTile(title: 'Kalan planlı borç', value: formatCompactMoney(futureInstallments),
            footer: 'Sınırlı taksit ve tek seferlik ödemeler', icon: Icons.calendar_month_outlined)),
          SizedBox(width: w, child: SummaryTile(title: 'Toplam bekleyen borç', value: formatCompactMoney(outgoingOpen),
            footer: 'Kayıtlı tüm ödenmemiş dönemler', icon: Icons.account_balance_wallet_outlined)),
          SizedBox(width: w, child: SummaryTile(title: 'Geciken tahsilatlar', value: formatCompactMoney(overdueIncoming),
            footer: 'Vadesi geçmiş alacak toplamı', icon: Icons.schedule_send_outlined)),
        ]);
      }),
      const SizedBox(height: 23),
      const SectionTitle('Önümüzdeki 6 ay · Nakit akışı'),
      const SizedBox(height: 8),
      Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('Yalnızca ödenmemiş ve kayıtlı dönemler gösterilir. Geçmiş gecikmeler bu tahmine dahil değildir.'),
          const SizedBox(height: 16),
          for (final month in cashFlow) ...[
            Row(children: [
              Expanded(child: Text('${monthNames[month.month.month - 1]} ${month.month.year}',
                style: Theme.of(context).textTheme.titleMedium)),
              Text('Net: ${formatCompactMoney(month.netCents)}',
                style: Theme.of(context).textTheme.bodySmall),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              const SizedBox(width: 52, child: Text('Borç')),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: chartMax == 0 ? 0 : month.outgoingCents / chartMax,
                  minHeight: 9,
                  backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .08),
                ))),
              const SizedBox(width: 10),
              SizedBox(width: 94, child: Text(formatCompactMoney(month.outgoingCents),
                textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 6),
            Row(children: [
              const SizedBox(width: 52, child: Text('Alacak')),
              Expanded(child: ClipRRect(borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: chartMax == 0 ? 0 : month.incomingCents / chartMax,
                  color: Theme.of(context).colorScheme.tertiary,
                  minHeight: 9,
                  backgroundColor: Theme.of(context).colorScheme.tertiary.withValues(alpha: .08),
                ))),
              const SizedBox(width: 10),
              SizedBox(width: 94, child: Text(formatCompactMoney(month.incomingCents),
                textAlign: TextAlign.right, maxLines: 1, overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 16),
          ],
        ],
      ))),
      const SizedBox(height: 23),
      const SectionTitle('Bekleyen borçların türlere göre dağılımı'),
      if (sortedCategories.isEmpty)
        const Card(child: EmptyView(title: 'Rapor için kayıt yok', message: 'Ödeme ekledikçe dağılım burada gösterilir.', icon: Icons.pie_chart_outline))
      else Card(child: Padding(padding: const EdgeInsets.all(18), child: Column(children: [
        for (final category in sortedCategories) ...[
          Row(children: [
            Expanded(child: Text(category.key, style: Theme.of(context).textTheme.bodyMedium)),
            Text(formatCompactMoney(category.value), style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 9),
          ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(
            value: sortedCategories.first.value == 0 ? 0 : category.value / sortedCategories.first.value,
            minHeight: 7,
            backgroundColor: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
          )),
          const SizedBox(height: 19),
        ],
      ]))),
      const SizedBox(height: 15),
      Text('Not: Fatura ve abonelikler için yalnızca oluşturulan dönemler hesaba katılır. Banka hesabınızdan otomatik işlem kontrolü yapılmaz.',
        style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    ]));
  }

  Widget _settingsPage() => _pageLayout(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('Ayarlar', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 5),
        Text('Her şey sana göre, her şey tek yerde.',
          style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
      ])),
      Container(width: 48, height: 48,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(15)),
        child: Icon(Icons.tune_rounded, color: Theme.of(context).colorScheme.primary)),
    ]),
    const SizedBox(height: 22),
    Card(child: ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: Text(CloudConfig.premiumEnabled ? 'Hesabım ve Premium' : 'Hesabım'),
      subtitle: Text(CloudConfig.premiumEnabled
        ? 'Bulut yedeği, üyelik ve duyuru bildirimleri'
        : 'İsteğe bağlı hesap, hesap silme ve duyurular'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountPage(store: store))),
    )),
    const SizedBox(height: 12),
    Card(child: ListTile(
      leading: const Icon(Icons.help_outline_rounded),
      title: const Text('Nasıl kullanılır?'),
      subtitle: const Text('Misafir kullanım, ödeme ekleme ve hesap işlemleri'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('VADESİ kullanım rehberi'),
          content: const SingleChildScrollView(child: Text(
            '1. Hesap açmadan misafir olarak başlayabilirsiniz.\n\n'
            '2. Sağ üstteki + düğmesinden taksit, fatura, abonelik veya alacak ekleyin.\n\n'
            '3. Ödemeler sekmesinden kayıtları arayın, düzenleyin ve ödendi olarak işaretleyin.\n\n'
            '4. Takvim ve Raporlar sekmelerinden vadeleri inceleyin.\n\n'
            '5. Ayarlar bölümünden yerel hatırlatmaları ve dosya yedeğini yönetin.\n\n'
            '6. Hesap isteğe bağlıdır: Hesabım > Üye ol veya Giriş yap. Hesabınızı Hesabım > Hesabımı sil yolundan silebilirsiniz.\n\n'
            'Not: Gerçek para veya fatura ödemesi yapılmaz; bilgiler kişisel takip amaçlıdır.')),
          actions: [TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Tamam'),
          )],
        ),
      ),
    )),
    const SizedBox(height: 20),
    const SectionTitle('Görünüm'),
    Card(child: ListTile(
      leading: const Icon(Icons.palette_outlined),
      title: const Text('Uygulama teması'),
      trailing: DropdownButton<ThemeMode>(
        value: store.themeMode,
        items: const [
          DropdownMenuItem(value: ThemeMode.system, child: Text('Sistem')),
          DropdownMenuItem(value: ThemeMode.light, child: Text('Aydınlık')),
          DropdownMenuItem(value: ThemeMode.dark, child: Text('Karanlık')),
        ],
        onChanged: (value) async {
          if (value == null) return;
          try { await store.setTheme(value); }
          catch (error) { if (mounted) showError(context, error); }
        },
      ),
    )),
    const SizedBox(height: 21),
    const SectionTitle('Hatırlatmalar'),
    Card(child: Column(children: [
      SwitchListTile.adaptive(
        contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 9),
        secondary: Container(width: 45, height: 45,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: .10),
            borderRadius: BorderRadius.circular(13)),
          child: Icon(Icons.notifications_active_outlined,
            color: Theme.of(context).colorScheme.primary)),
        title: const Text('Ödeme hatırlatmaları',
          style: TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(!store.supportsNotifications
          ? 'Bildirimler yalnızca iOS ve Android sürümünde kullanılabilir.'
          : store.notificationsEnabled
            ? 'Aktif · Vadeleri telefonunda hatırlatır'
            : 'Kapalı · Açmak için tek dokunuş yeterli'),
        value: store.notificationsEnabled,
        onChanged: !store.supportsNotifications ? null : (value) async {
          try {
            final accepted = await store.setNotifications(value);
            if (!accepted && mounted) {
              showError(context, await store.reminders.permissionFailureMessage());
            }
          } catch (error) {
            if (mounted) showError(context, error);
          }
        },
      ),
      if (store.notificationsEnabled) ...[
        const Divider(height: 1),
        ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 19),
          leading: const Icon(Icons.tune_rounded),
          title: const Text('Hatırlatma tercihleri'),
          subtitle: const Text('Saat, test ve sistem ayarları'),
          children: [
            ListTile(
              title: const Text('Bildirim saati'),
              subtitle: const Text('Türkiye saati'),
              trailing: Text('${store.notifyHour.toString().padLeft(2, '0')}:00',
                style: Theme.of(context).textTheme.titleMedium),
              onTap: () async {
                final hour = await showWheelHourPicker(context, store.notifyHour);
                if (hour != null) {
                  try { await store.setNotifyHour(hour); }
                  catch (error) { if (mounted) showError(context, error); }
                }
              },
            ),
            ListTile(
              leading: const Icon(Icons.notifications_outlined),
              title: const Text('Test bildirimi gönder'),
              onTap: () async {
                try {
                  await store.reminders.sendTestNotification();
                  if (mounted) showSuccess(context,
                    'Test bildirimi hazırlandı. Bildirim merkezini kontrol et.');
                } catch (error) {
                  if (mounted) showError(context, error);
                }
              },
            ),
            if (defaultTargetPlatform == TargetPlatform.iOS)
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const Text('iPhone bildirim ayarları'),
                onTap: () async {
                  final opened = await store.reminders.openIosNotificationSettings();
                  if (!opened && mounted) {
                    showError(context, 'iPhone Ayarlar > Bildirimler bölümünden VADESİ uygulamasını aç.');
                  }
                },
              ),
            if (defaultTargetPlatform == TargetPlatform.android)
              ListTile(
                leading: const Icon(Icons.alarm_outlined),
                title: const Text('Tam saat izni'),
                subtitle: Text(store.reminders.exactTimingAllowed ? 'Açık' : 'İsteğe bağlı'),
                onTap: () async {
                  try {
                    final allowed = await store.reminders.requestExactTiming();
                    await store.refresh();
                    if (!allowed && mounted) {
                      showError(context, 'Android tam saat bildirimlerini erteleyebilir.');
                    }
                  } catch (error) {
                    if (mounted) showError(context, error);
                  }
                },
              ),
          ],
        ),
      ],
    ])),
    const SizedBox(height: 11),
    Text('Bildirimler yalnızca cihazında planlanır. İstediğin zaman tek anahtarla kapatabilirsin.',
      style: TextStyle(fontSize: 12,
        color: Theme.of(context).colorScheme.onSurfaceVariant)),
    if (store.reminderError != null) ...[
      const SizedBox(height: 10),
      Text('Hatırlatma sorunu: ${store.reminderError}',
        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
    ],
    const SizedBox(height: 24),
    const SectionTitle('Yedekleme ve dışa aktarma'),
    Card(child: ListTile(
      leading: const Icon(Icons.backup_outlined),
      title: const Text('Yedek al, geri yükle ve CSV aktar'),
      subtitle: const Text('Kayıtlarını bir dosyada sakla veya tablo olarak dışa aktar.'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => BackupPage(store: store))),
    )),
    const SizedBox(height: 21),
    const SectionTitle('Veri ve gizlilik'),
    const Card(child: Padding(padding: EdgeInsets.all(17), child: Column(
      crossAxisAlignment: CrossAxisAlignment.start, children: [
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.phone_android_outlined),
          title: Text('Veriler bu cihazda'),
          subtitle: Text('Kayıtlar bu cihazda tutulur. Web sürümünde tarayıcı verilerini temizlemek kayıtları siler. Düzenli yedek alın.')),
        Divider(),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.info_outline_rounded),
          title: Text('Otomatik banka bağlantısı yok'),
          subtitle: Text('Uygulama banka hesabınızdaki transferleri veya kurumlardaki güncel borçları otomatik sorgulamaz.')),
        Divider(),
        ListTile(contentPadding: EdgeInsets.zero, leading: Icon(Icons.security_outlined),
          title: Text('Hassas bilgiler'),
          subtitle: Text('IBAN ve ödeme bilgileri cihazda tutulur; bu sürümde veritabanı şifreli değildir. Telefon ekran kilidini kullanın.')),
      ]))),
    const SizedBox(height: 21),
    Center(child: Text('VADESİ · 1.3.0',
      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
  ]));
}
