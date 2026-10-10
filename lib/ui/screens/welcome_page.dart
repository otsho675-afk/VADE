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
    } catch (_) { if (mounted) setState(() => _entered = false); }
  }
  Future<void> _enter() async {
    // The welcome screen must not block the ledger if preference storage is unavailable.
    try { await (await SharedPreferences.getInstance()).setBool('welcome_completed', true); } catch (_) {}
    if (mounted) setState(() => _entered = true);
  }
  Future<void> _auth(bool register) async {
    final success = await Navigator.push<bool>(context,
      MaterialPageRoute(builder: (_) => AuthPage(store: widget.store, register: register)));
    if (success == true && mounted) await _enter();
  }
  @override
  Widget build(BuildContext context) {
    if (_entered == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (_entered!) return HomeShell(store: widget.store);
    return Scaffold(body: SafeArea(child: Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 600),
      child: Column(children: [
      Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(28, 28, 28, 12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SizedBox(height: 20),
        const Align(alignment: Alignment.centerLeft, child: BrandMark(size: 76)),
        const SizedBox(height: 24),
        Text('VADESİ', style: Theme.of(context).textTheme.titleLarge?.copyWith(letterSpacing: 3)),
        const SizedBox(height: 12),
        Text('Bugünü yaşa.\nVadeni unutma.', style: Theme.of(context).textTheme.displaySmall?.copyWith(
          fontWeight: FontWeight.w800, height: 1.12, letterSpacing: -1.5)),
        const SizedBox(height: 16),
        const Text('Taksitlerin, faturaların ve alacakların tek bir sakin alanda. '
          'Ne zaman, ne kadar ödeyeceğini her zaman bil.'),
        const SizedBox(height: 28),
        Container(padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [Color(0xFF104C46), Color(0xFF1E7767)]),
            borderRadius: BorderRadius.circular(28)),
          child: const Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Icon(Icons.calendar_month_rounded, color: Color(0xFFC6F4D8), size: 34),
            SizedBox(height: 18),
            Text('Planla. Hatırla. Rahatla.', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            SizedBox(height: 10),
            Text('Kaydırmalı tarih seçimi • Vade hatırlatmaları\nCihazda kayıt • İsteğe bağlı bulut yedeği',
              style: TextStyle(color: Color(0xFFE0F5E9), height: 1.7)),
          ])),
        ]))),
        Padding(padding: const EdgeInsets.fromLTRB(28, 8, 28, 16),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FilledButton(onPressed: () => _auth(true), child: const Text('Üye ol')),
        const SizedBox(height: 10),
        OutlinedButton(onPressed: () => _auth(false), child: const Text('Giriş yap')),
        const SizedBox(height: 8),
        TextButton(onPressed: _enter, child: const Text('Misafir olarak devam et')),
        const SizedBox(height: 12),
        const Text('Yerel ödeme takibi için hesap açmak zorunda değilsin.',
          textAlign: TextAlign.center, style: TextStyle(fontSize: 12)),
        ])),
      ]),
    ))));
  }
}
