import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../../state/app_store.dart';
import '../../services/ledger_export.dart';
import '../../services/save_export.dart';
import '../../data/backup_codec.dart';
import '../widgets/common.dart';

class BackupPage extends StatefulWidget {
  final AppStore store;
  const BackupPage({super.key, required this.store});
  @override
  State<BackupPage> createState() => _BackupPageState();
}

class _BackupPageState extends State<BackupPage> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } catch (error) {
      if (mounted) showError(context, error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(String content, String extension) async {
    final date = DateTime.now().toIso8601String().substring(0, 10);
    final bytes = Uint8List.fromList(utf8.encode(content));
    final path = await FilePicker.platform.saveFile(
      dialogTitle: 'VADESİ dosyasını kaydet',
      fileName: 'vadesi-$date.$extension',
      type: FileType.custom,
      allowedExtensions: [extension],
      bytes: bytes,
    );
    if (path != null) {
      await finishExport(path, bytes);
      if (mounted) showSuccess(context, 'Dosya kaydedildi.');
    }
  }

  Future<void> _restore() async {
    final selected = await FilePicker.platform.pickFiles(
      type: FileType.custom, allowedExtensions: ['json'], withData: true,
    );
    if (selected == null || !mounted) return;
    final file = selected.files.single;
    if (file.size > 10000000 || file.bytes == null) {
      throw const FormatException('En fazla 10 MB boyutunda bir JSON yedeği seçin.');
    }
    final source = utf8.decode(file.bytes!);
    final preview = BackupCodec.decode(source);
    final allow = await confirmAction(context, title: 'Yedeği geri yükle',
      body: '${preview.plans.length} plan ve ${preview.occurrences.length} ödeme yüklenecek. '
        'Mevcut kayıtların tamamı bu yedekle değiştirilecek. Önce mevcut kayıtlarını yedeklediğinden emin ol.',
      confirm: 'Kayıtları değiştir', destructive: true);
    if (!allow) return;
    await widget.store.db.restoreBackup(source);
    await widget.store.refresh();
    if (mounted) showSuccess(context, 'Yedek geri yüklendi.');
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Yedekleme ve dışa aktarma')),
    body: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 720),
      child: ListView(padding: const EdgeInsets.all(20), children: [
        Text('VERİLERİN', style: TextStyle(color: Theme.of(context).colorScheme.primary,
          fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w800)),
        const SizedBox(height: 7),
        Text('Kayıtların yanında', style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 6),
        Text('Ödeme planlarını yedekle veya tablo olarak dışa aktar.',
          style: Theme.of(context).textTheme.bodyMedium),
        const SizedBox(height: 19),
        Card(child: Padding(padding: const EdgeInsets.all(18), child: Row(
          crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(Icons.info_outline_rounded, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 12),
          const Expanded(child: Text('JSON yedeği planları ve ödeme geçmişini içerir. '
            'Tema ve bildirim izinleri cihazda kalır. Dosya şifrelenmez; güvenli bir yerde saklayın.')),
        ]))),
        const SizedBox(height: 23),
        const SectionTitle('Dosya işlemleri'),
        Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
          leading: const Icon(Icons.download_outlined),
          title: const Text('JSON yedeği al'),
          subtitle: const Text('Başka cihazda da geri yüklenebilir.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : () => _run(() async => _save(await widget.store.db.exportBackup(), 'json')))),
        const SizedBox(height: 10),
        Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
          leading: const Icon(Icons.upload_file_outlined),
          title: const Text('JSON yedeğini geri yükle'),
          subtitle: const Text('Dosya doğrulandıktan ve onayladıktan sonra kayıtlar değiştirilir.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : () => _run(_restore))),
        const SizedBox(height: 10),
        Card(child: ListTile(contentPadding: const EdgeInsets.symmetric(horizontal: 17, vertical: 8),
          leading: const Icon(Icons.table_view_outlined),
          title: const Text('CSV olarak dışa aktar'),
          subtitle: const Text('Ödemeleri Excel veya başka bir tablo uygulamasında aç.'),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: _busy ? null : () => _run(() => _save(ledgerCsv(widget.store.items), 'csv')))),
        if (_busy) const Padding(padding: EdgeInsets.all(24),
          child: Center(child: CircularProgressIndicator())),
      ]),
    )),
  );
}
