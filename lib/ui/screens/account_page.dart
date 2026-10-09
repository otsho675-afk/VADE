import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../state/app_store.dart';
import '../../services/cloud_config.dart';
import '../../services/purchase_service.dart';
import '../widgets/common.dart';
import '../widgets/brand_mark.dart';
import 'auth_page.dart';

class AccountPage extends StatefulWidget {
  final AppStore store;
  const AccountPage({super.key, required this.store});
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  bool _busy = false;
  AppStore get store => widget.store;

  @override
  void initState() {
    super.initState();
    store.purchases.loadProducts();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try { await action(); }
    catch (_) {
      if (mounted) showError(context, 'İşlem tamamlanamadı. Bağlantınızı, hesap bilgilerinizi ve üyeliğinizi kontrol edin.');
    } finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _link(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null || uri.scheme != 'https' || !await launchUrl(uri)) {
      throw StateError('Bağlantı açılamadı.');
    }
  }

  Future<void> _backup(bool restore) async {
    final confirmed = await confirmAction(context,
      title: restore ? 'Bulut yedeğini yükle' : 'Buluta yedekle',
      body: restore
        ? 'Bu cihazdaki kayıtlar bulut yedeğiyle değiştirilecek. Önce dosya yedeği alın.'
        : 'Finansal kayıtlarınız Firebase üzerinde hesabınıza kaydedilecek ve önceki bulut yedeğiniz değiştirilecek. Devam edilsin mi?',
      confirm: restore ? 'Kayıtları değiştir' : 'Yedekle', destructive: restore);
    if (!confirmed) return;
    if (restore) {
      await store.db.restoreBackup(await store.cloud.downloadBackup());
      await store.refresh();
    } else {
      await store.cloud.uploadBackup(await store.db.exportBackup());
    }
    if (mounted) showSuccess(context, 'Yedekleme işlemi tamamlandı.');
  }

  Future<void> _delete() async {
    final controller = TextEditingController();
    final password = await showDialog<String>(context: context, builder: (dialogContext) =>
      AlertDialog(title: const Text('Hesabımı sil'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
          const Text('Hesabınız ve bulut yedeğiniz silinir. Cihazdaki kayıtlar kalır. Mağaza aboneliğiniz otomatik iptal olmaz; ayrıca mağazadan iptal edin.'),
          TextField(controller: controller, obscureText: true,
            decoration: const InputDecoration(labelText: 'Onay için şifreniz')),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('Vazgeç')),
          FilledButton(onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Hesabı sil')),
        ]));
    // Wait until the dialog route has finished using its controller.
    await Future<void>.delayed(const Duration(milliseconds: 300));
    controller.dispose();
    if (password == null || password.isEmpty) return;
    await store.cloud.deleteAccount(password);
    if (mounted) showSuccess(context, 'Hesabınız silindi.');
  }


  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: Listenable.merge([store, store.cloud, store.purchases]),
    builder: (context, _) {
      final cloud = store.cloud;
      final purchases = store.purchases;
      final legalReady = CloudConfig.privacyUrl.startsWith('https://') &&
          CloudConfig.termsUrl.startsWith('https://');
      return Scaffold(appBar: AppBar(title: const Text('Hesabım ve Premium')),
        body: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(padding: const EdgeInsets.all(20), children: [
            if (!cloud.ready) const Card(child: Padding(padding: EdgeInsets.all(16),
              child: Text('Bulut hizmeti henüz etkinleştirilmedi. Ödemelerinizi cihazda tutmaya ve dosya yedeği almaya devam edebilirsiniz.'))),
            if (cloud.error != null) Text(cloud.error!),
            if (cloud.user == null) ...[
              const Center(child: BrandMark(size: 72)),
              const SizedBox(height: 18),
              Text('Hesabın, her zaman yanında.', textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: 10),
              const Text('Giriş yap veya yeni hesap oluştur. Yerel kayıtların bu cihazda korunur.',
                textAlign: TextAlign.center),
              const SizedBox(height: 22),
              FilledButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AuthPage(store: store))), child: const Text('Giriş yap')),
              const SizedBox(height: 10),
              OutlinedButton(onPressed: () => Navigator.push(context, MaterialPageRoute(
                builder: (_) => AuthPage(store: store, register: true))), child: const Text('Üye ol')),
              const SizedBox(height: 20),
            ],
            if (cloud.user != null) ...[
              if (!cloud.user!.emailVerified) Card(child: Padding(
                padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('E-posta adresini doğrula', style: TextStyle(fontWeight: FontWeight.w700)),
                  const Text('Gelen kutundaki doğrulama bağlantısını aç.'),
                  Wrap(spacing: 8, children: [
                    TextButton(onPressed: _busy ? null : () => _run(() async {
                      await cloud.resendVerification();
                      if (context.mounted) showSuccess(context, 'Doğrulama e-postası gönderildi.');
                    }), child: const Text('Tekrar gönder')),
                    TextButton(onPressed: _busy ? null : () => _run(cloud.refreshUser),
                      child: const Text('Doğrulamayı kontrol et')),
                  ]),
                ]))),

              ListTile(contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.account_circle),
                title: Text(cloud.user!.email ?? 'Hesabım'),
                subtitle: Text(cloud.premium ? 'Premium aktif' : 'Ücretsiz üyelik')),
              const Text('Premium: cihazlar arasında isteğe bağlı bulut yedekleme. '
                'Yerel ödeme takibi ve dosya yedekleme ücretsizdir.'),
              const SizedBox(height: 12),
              FilledButton.icon(onPressed: _busy || !cloud.premium ? null : () => _run(() => _backup(false)),
                icon: const Icon(Icons.cloud_upload_outlined), label: const Text('Buluta yedekle')),
              OutlinedButton.icon(onPressed: _busy ? null : () => _run(() => _backup(true)),
                icon: const Icon(Icons.cloud_download_outlined), label: const Text('Bulut yedeğini geri yükle')),
              const Text('Bulut yedeği elle güncellenir; eşzamanlı otomatik senkronizasyon yapılmaz. Mevcut yedeğinizi üyelik sona erse de indirebilirsiniz.'),
              const Divider(height: 32),
              Text('Premium abonelik', style: Theme.of(context).textTheme.titleLarge),
              if (purchases.loading) const LinearProgressIndicator(),
              for (final product in purchases.products)
                ListTile(contentPadding: EdgeInsets.zero,
                  title: Text(product.id == PurchaseService.monthlyId ? 'Aylık Premium' : 'Yıllık Premium'),
                  subtitle: Text('${product.price} / ${product.id == PurchaseService.monthlyId ? "ay" : "yıl"}'),
                  trailing: FilledButton(onPressed: _busy || !legalReady || cloud.premium ? null :
                    () => _run(() => purchases.buy(product)), child: const Text('Abone ol'))),
              if (purchases.message != null) Text(purchases.message!),
              const Text('Abonelik iptal edilmediği sürece seçilen dönem ve mağazada gösterilen fiyatla otomatik yenilenir. '
                'Ücret mağaza hesabınıza yansıtılır. İptal ve yönetim mağaza hesabınızdan yapılır.'),
              Wrap(spacing: 8, children: [
                TextButton(onPressed: _busy ? null : () => _run(purchases.loadProducts),
                  child: const Text('Ürünleri yenile')),
                TextButton(onPressed: _busy || !purchases.supported ? null : () => _run(purchases.restore),
                  child: const Text('Satın almaları geri yükle')),
                TextButton(onPressed: () => _run(() => _link('https://play.google.com/store/account/subscriptions')),
                  child: const Text('Google abonelikleri')),
                TextButton(onPressed: () => _run(() => _link('https://apps.apple.com/account/subscriptions')),
                  child: const Text('Apple abonelikleri')),
              ]),
              const Divider(),
              TextButton(onPressed: _busy ? null : () => _run(cloud.signOut), child: const Text('Çıkış yap')),
              TextButton(onPressed: _busy ? null : () => _run(_delete), child: const Text('Hesabımı sil')),
            ],
            const Divider(height: 32),
            SwitchListTile(contentPadding: EdgeInsets.zero, title: const Text('Duyuru bildirimleri'),
              subtitle: const Text('İzin verirseniz OneSignal üzerinden uygulama duyuruları alırsınız. Ödeme hatırlatmaları ayrı yönetilir.'),
              value: store.remotePush.enabled,
              onChanged: _busy || !store.remotePush.available ? null : (value) => _run(() async {
                final accepted = await store.remotePush.setEnabled(value);
                if (!accepted && context.mounted) showError(context, 'Bildirim izni verilmedi.');
              })),
            Wrap(spacing: 12, children: [
              TextButton(onPressed: CloudConfig.privacyUrl.isEmpty ? null :
                () => _run(() => _link(CloudConfig.privacyUrl)), child: const Text('Gizlilik politikası')),
              TextButton(onPressed: CloudConfig.termsUrl.isEmpty ? null :
                () => _run(() => _link(CloudConfig.termsUrl)), child: const Text('Kullanım koşulları')),
            ]),
            if (_busy) const Center(child: CircularProgressIndicator()),
          ]))));
    });
}
