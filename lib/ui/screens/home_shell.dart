import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/material.dart';
import 'account_page.dart';
import 'auth_page.dart';
import '../widgets/brand_mark.dart';
import '../widgets/wheel_date_picker.dart';
import '../../models/payment.dart';
import '../../state/app_store.dart';
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
  final _searchController = TextEditingController();

  AppStore get store => widget.store;

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openAdd() async {
    final created = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => PaymentFormPage(store: store)));
    if (!mounted || created != true || store.notificationsEnabled || !store.supportsNotifications) return;
    final want = await confirmAction(context,
      title: 'Hatırlatmaları etkinleştir',
      body: 'Ödemeleriniz için 5 gün önce, 1 gün önce ve vade günü cihaz bildirimi almak ister misiniz?',
      confirm: 'Bildirimleri aç');
    if (!want) return;
    try {
      final granted = await store.setNotifications(true);
      if (!granted && mounted) showError(context, 'Bildirim izni verilmedi. Ayarlardan daha sonra açabilirsiniz.');
    } catch (e) {
      if (mounted) showError(context, e);
    }
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
              padding: EdgeInsets.symmetric(horizontal: width < 420 ? 15 : 22, vertical: 13),
              decoration: BoxDecoration(color: Theme.of(context).scaffoldBackgroundColor,
                border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor))),
              child: Row(children: [
                if (!desktop) ...[
                  Container(padding: const EdgeInsets.all(7), decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withValues(alpha: .09),
                    borderRadius: BorderRadius.circular(10)),
                    child: const BrandMark(size: 30)),
                  const SizedBox(width: 9),
                  Text('VADESİ', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: .8)),
                ] else Text(['Genel bakış', 'Ödemeler', 'Raporlar', 'Ayarlar'][_selected],
                  style: Theme.of(context).textTheme.headlineSmall),
                const Spacer(),
                IconButton(tooltip: store.cloud.user == null ? 'Giriş yap / Üye ol' : 'Hesabım',
                  icon: const Icon(Icons.person_outline_rounded),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => AccountPage(store: store)))),
                IconButton(tooltip: 'Ödeme takvimi', icon: const Icon(Icons.calendar_month_outlined),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(
                    builder: (_) => CalendarPage(store: store)))),

                if (desktop) FilledButton.icon(onPressed: _openAdd, icon: const Icon(Icons.add_rounded),
                  label: const Text('Yeni ödeme'))
                else IconButton.filledTonal(icon: const Icon(Icons.add_rounded),
                  tooltip: 'Yeni ödeme ekle', onPressed: _openAdd),
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
        bottomNavigationBar: desktop ? null : NavigationBar(
          selectedIndex: _selected,
          onDestinationSelected: (v) => setState(() => _selected = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.grid_view_outlined),
              selectedIcon: Icon(Icons.grid_view_rounded), label: 'Genel'),
            NavigationDestination(icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long_rounded), label: 'Ödemeler'),
            NavigationDestination(icon: Icon(Icons.insert_chart_outlined),
              selectedIcon: Icon(Icons.insert_chart_rounded), label: 'Raporlar'),
            NavigationDestination(icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings_rounded), label: 'Ayarlar'),
          ],
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
    Text('Ödemeleriniz tek yerde', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 5),
    Text('Taksit, fatura ve alacaklarınızı zamanında takip edin.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 22),
    Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFF104C46), Color(0xFF237C65)]),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [BoxShadow(color: const Color(0xFF104C46).withValues(alpha: .18),
          blurRadius: 24, offset: const Offset(0, 10))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Expanded(child: Text('BU AYA KADAR ÖDENECEK',
            style: TextStyle(color: Color(0xFFD8F4E4), fontSize: 11, letterSpacing: 1.4, fontWeight: FontWeight.w600))),
          const Icon(Icons.account_balance_wallet_outlined, color: Color(0xFFD8F4E4)),
        ]),
        const SizedBox(height: 14),
        FittedBox(fit: BoxFit.scaleDown, child: Text(formatCompactMoney(store.monthOutgoing),
          style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1))),
        const SizedBox(height: 8),
        const Text('Vadesi gelen ve gecikmiş borçların toplamı',
          style: TextStyle(color: Color(0xFFD8F4E4), fontSize: 12)),
        const SizedBox(height: 20),
        Wrap(spacing: 12, runSpacing: 10, children: [
          FilledButton.icon(style: FilledButton.styleFrom(backgroundColor: const Color(0xFFD7F7B4),
              foregroundColor: const Color(0xFF173F32)),
            onPressed: _openAdd, icon: const Icon(Icons.add_rounded), label: const Text('Ödeme ekle')),
          TextButton.icon(style: TextButton.styleFrom(foregroundColor: Colors.white),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CalendarPage(store: store))),
            icon: const Icon(Icons.calendar_month_outlined), label: const Text('Takvimim')),
        ]),
      ]),
    ),
    const SizedBox(height: 16),
    LayoutBuilder(builder: (context, constraints) {
      final width = constraints.maxWidth < 320 ? constraints.maxWidth : (constraints.maxWidth - 12) / 2;
      return Wrap(spacing: 12, runSpacing: 12, children: [
        SizedBox(width: width, child: SummaryTile(title: 'Beklenen tahsilat', value: formatCompactMoney(store.monthIncoming),
          footer: 'Bu aya kadar alacaklar', icon: Icons.south_west_rounded)),
        SizedBox(width: width, child: SummaryTile(title: 'Geciken kayıt', value: '${store.lateCount}',
          footer: store.lateCount == 0 ? 'Her şey yolunda' : 'Kontrol etmen gerekiyor', icon: Icons.schedule_rounded)),
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
    const SizedBox(height: 27),
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
      decoration: const InputDecoration(prefixIcon: Icon(Icons.search_rounded), hintText: 'Ödeme veya kişi ara'),
    ),
    const SizedBox(height: 10),
    SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
      for (final f in ['Tümü', 'Taksit', 'Fatura', 'Abonelik', 'Alacaklar', 'Gecikenler', 'Geçmiş']) ...[
        ChoiceChip(label: Text(f), selected: _filter == f, onSelected: (_) => setState(() => _filter = f)),
        const SizedBox(width: 8),
      ],
    ])),
    const SizedBox(height: 18),
    Builder(builder: (context) {
      final source = _filter == 'Geçmiş' ? store.history : store.upcoming;
      final filtered = source.where((p) {
        final matchesText = _search.isEmpty || p.plan.title.toLowerCase().contains(_search)
          || p.plan.party.toLowerCase().contains(_search);
        final matchesFilter = switch (_filter) {
          'Taksit' => p.plan.kind == PaymentKind.installment,
          'Fatura' => p.plan.kind == PaymentKind.invoice,
          'Abonelik' => p.plan.kind == PaymentKind.subscription,
          'Alacaklar' => p.plan.direction == PaymentDirection.incoming,
          'Gecikenler' => p.isLate,
          _ => true,
        };
        return matchesText && matchesFilter;
      }).toList();
      return Column(children: filtered.isEmpty
        ? [const Card(child: EmptyView(title: 'Sonuç bulunamadı', message: 'Filtreyi değiştirin veya yeni ödeme ekleyin.', icon: Icons.search_off_rounded))]
        : [for (final p in filtered) ...[
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
          ]]);
    }),
  ]));

  Widget _reportsPage() {
    final all = store.items;
    final historical = store.history;
    final outgoingPaid = historical.where((p) => p.plan.direction == PaymentDirection.outgoing)
      .fold<int>(0, (value, item) => value + item.amountCents);
    final received = historical.where((p) => p.plan.direction == PaymentDirection.incoming)
      .fold<int>(0, (value, item) => value + item.amountCents);
    final futureInstallments = all.where((p) => !p.isPaid && p.plan.isFinite)
      .fold<int>(0, (sum, p) => sum + (p.plan.direction == PaymentDirection.outgoing ? p.amountCents : 0));
    final categories = <String, int>{};
    for (final p in store.upcoming.where((p) => p.plan.direction == PaymentDirection.outgoing)) {
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
            footer: '${historical.length} tamamlanan kayıt', icon: Icons.check_circle_outline)),
          SizedBox(width: w, child: SummaryTile(title: 'Tahsil edilen', value: formatCompactMoney(received),
            footer: 'Alacak geçmişi', icon: Icons.call_received_rounded)),
          SizedBox(width: w, child: SummaryTile(title: 'Kalan planlı borç', value: formatCompactMoney(futureInstallments),
            footer: 'Sınırlı taksit ve tek seferlik ödemeler', icon: Icons.calendar_month_outlined)),
        ]);
      }),
      const SizedBox(height: 23),
      const SectionTitle('Yaklaşan borçların dağılımı'),
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
    Text('Ayarlar', style: Theme.of(context).textTheme.headlineMedium),
    const SizedBox(height: 5),
    Text('Görünüm, hatırlatma ve gizlilik tercihleri.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
    const SizedBox(height: 20),
    Card(child: ListTile(
      leading: const Icon(Icons.account_circle_outlined),
      title: const Text('Hesabım ve Premium'),
      subtitle: const Text('Bulut yedeği, üyelik ve duyuru bildirimleri'),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AccountPage(store: store))),
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
        title: const Text('Ödeme bildirimleri'),
        subtitle: Text(store.supportsNotifications
          ? '5 gün önce, 1 gün önce, vade günü ve vade geçtikten sonra'
          : 'Yerel bildirimler Android ve iOS uygulamasında kullanılabilir.'),
        value: store.notificationsEnabled,
        onChanged: !store.supportsNotifications ? null : (v) async {
          try {
            final accepted = await store.setNotifications(v);
            if (!accepted && mounted) showError(context, 'Bildirim izni reddedildi. Telefon ayarlarından izin verebilirsiniz.');
          } catch (e) {
            if (mounted) showError(context, e);
          }
        },
      ),
      const Divider(height: 1),
      ListTile(
        title: const Text('Bildirim saati'),
        subtitle: const Text('Türkiye saati (Europe/Istanbul), tam saat olarak'),
        trailing: Text('${store.notifyHour.toString().padLeft(2, '0')}:00'),
        onTap: () async {
          final time = await showWheelHourPicker(context, store.notifyHour);
          if (time != null) {
            try { await store.setNotifyHour(time); }
            catch (e) { if (mounted) showError(context, e); }
          }
        },
      ),
    ])),
    if (defaultTargetPlatform == TargetPlatform.android && store.supportsNotifications)
      OutlinedButton.icon(
        icon: const Icon(Icons.alarm),
        label: Text(store.reminders.exactTimingAllowed ? 'Tam saat izni açık' : 'Tam saat iznini aç'),
        onPressed: () async {
          try {
            final accepted = await store.reminders.requestExactTiming();
            await store.refresh();
            if (!accepted && mounted) showError(context, 'Tam saat izni verilmedi; Android hatırlatmayı erteleyebilir.');
          } catch (error) {
            if (mounted) showError(context, error);
          }
        },
      ),
    if (store.supportsNotifications) OutlinedButton.icon(
      icon: const Icon(Icons.notifications_outlined),
      label: const Text('Test bildirimi gönder'),
      onPressed: () async {
        try {
          await store.reminders.sendTestNotification();
          if (mounted) showSuccess(context, 'Test bildirimi telefona iletildi. Bildirim perdesini kontrol edin.');
        } catch (error) {
          if (mounted) showError(context, error);
        }
      },
    ),    const SizedBox(height: 11),
    Text('Bildirimler cihaz üzerinde zamanlanır. Telefon kapalıysa, izin verilmediyse veya işletim sistemi ertelerse bildirimin tam zamanında ulaşması garanti değildir.',
      style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
    if (store.reminderError != null) ...[
      const SizedBox(height: 9),
      Text('Bildirim planlama hatası: ${store.reminderError}',
        style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
    ],
    const SizedBox(height: 21),
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
    Center(child: Text('VADESİ · 1.2.0',
      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant))),
  ]));
}
