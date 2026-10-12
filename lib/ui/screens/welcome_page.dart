import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../state/app_store.dart';
import '../widgets/brand_mark.dart';
import 'auth_page.dart';
import 'home_shell.dart';

class WelcomeGate extends StatefulWidget {
  final AppStore store;
  const WelcomeGate({super.key, required this.store});
  @override
  State<WelcomeGate> createState() => _WelcomeGateState();
}

class _WelcomeGateState extends State<WelcomeGate> {
  bool? _entered;
  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (mounted) setState(() => _entered = prefs.getBool('welcome_completed') ?? false);
    } catch (_) {
      if (mounted) setState(() => _entered = false);
    }
  }

  Future<void> _enter() async {
    try {
      await (await SharedPreferences.getInstance()).setBool('welcome_completed', true);
    } catch (_) {}
    if (mounted) setState(() => _entered = true);
  }

  Future<void> _auth(bool register) async {
    final success = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) =>
        AuthPage(store: widget.store, register: register)));
    if (success == true && mounted) await _enter();
  }

  Widget _feature(IconData icon, String label) {
    final scheme = Theme.of(context).colorScheme;
    return Row(children: [
      Container(width: 34, height: 34,
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: .10),
          borderRadius: BorderRadius.circular(11)),
        child: Icon(icon, size: 19, color: scheme.primary)),
      const SizedBox(width: 12),
      Expanded(child: Text(label, style: Theme.of(context).textTheme.titleMedium)),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    if (_entered == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_entered!) return HomeShell(store: widget.store);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 590),
      child: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(26, 28, 26, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Row(children: [
              Container(width: 64, height: 64,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF153C51), Color(0xFF116C69)]),
                  borderRadius: BorderRadius.circular(20)),
                child: const BrandMark(size: 47)),
              const SizedBox(width: 14),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('VADESİ', maxLines: 1, overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    letterSpacing: 1.4, fontWeight: FontWeight.w900)),
                Text('Kişisel vade asistanın', maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
              ])),
            ]),
            const SizedBox(height: 33),
            Text('Ödemelerin düzenli.\nAklın rahat.',
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                height: 1.13, letterSpacing: -1.5)),
            const SizedBox(height: 14),
            Text('Taksitlerini, faturalarını ve alacaklarını takip et. '
              'Sürpriz ödeme günlerini geride bırak.',
              style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 28),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [Color(0xFF102C43), Color(0xFF166A6C), Color(0xFF22808A)]),
                borderRadius: BorderRadius.circular(28)),
              padding: const EdgeInsets.all(25),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Row(children: [
                  Icon(Icons.calendar_month_rounded, color: Color(0xFFD8FAF3), size: 33),
                  Spacer(),
                  Icon(Icons.auto_awesome_rounded, color: Color(0xFFB4E7DE), size: 23),
                ]),
                const SizedBox(height: 25),
                const Text('Her vade, tam zamanında.',
                  style: TextStyle(color: Colors.white,
                    fontSize: 23, fontWeight: FontWeight.w900)),
                const SizedBox(height: 10),
                const Text('Bir kez izin ver; yaklaşan ve geciken ödemelerini '
                  'telefonun sana hatırlatsın.',
                  style: TextStyle(color: Color(0xFFDAEFEF),
                    height: 1.55, fontSize: 14)),
              ]),
            ),
            const SizedBox(height: 27),
            _feature(Icons.receipt_long_outlined, 'Taksit ve fatura takibi'),
            const SizedBox(height: 12),
            _feature(Icons.notifications_active_outlined, 'Tek seferde bildirim izni'),
            const SizedBox(height: 12),
            _feature(Icons.shield_outlined, 'Kayıtlar cihazında, kontrol sende'),
          ]),
        )),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 6, 26, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            FilledButton.icon(onPressed: () => _auth(true),
              icon: const Icon(Icons.person_add_alt_1_rounded),
              label: const Text('Üye ol')),
            const SizedBox(height: 10),
            OutlinedButton(onPressed: () => _auth(false),
              child: const Text('Giriş yap')),
            TextButton(onPressed: _enter,
              child: const Text('Misafir olarak devam et')),
            const SizedBox(height: 4),
            Text('Üyelik zorunlu değil. Gerçek para transferi yapılmaz.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ]),
    ))));
  }
}
