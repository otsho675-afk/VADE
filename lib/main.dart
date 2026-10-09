import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/semantics.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart';
import 'state/app_store.dart';
import 'ui/app_theme.dart';
import 'ui/screens/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Keep the web interface available to screen readers for the app lifetime.
  if (kIsWeb) SemanticsBinding.instance.ensureSemantics();
  Intl.defaultLocale = 'tr_TR';
  runApp(const VadesiApp());
}

class VadesiApp extends StatefulWidget {
  const VadesiApp({super.key});
  @override
  State<VadesiApp> createState() => _VadesiAppState();
}

class _VadesiAppState extends State<VadesiApp> {
  late final AppStore _store;

  @override
  void initState() {
    super.initState();
    _store = AppStore();
    _store.initialize();
  }

  @override
  void dispose() {
    _store.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(animation: _store, builder: (_, __) => MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'VADESİ · Ödeme Takibi',
      locale: const Locale('tr', 'TR'),
      supportedLocales: const [Locale('tr', 'TR')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: _store.themeMode,
      home: HomeShell(store: _store),
    ));
  }
}
