import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/app_theme.dart';
import 'package:vadesi/ui/screens/home_shell.dart';
import 'package:vadesi/ui/screens/calendar_page.dart';

void main() {
  for (final width in [390.0, 1440.0]) {
    testWidgets('Home and settings render at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()..loading = false;
      await tester.pumpWidget(MaterialApp(
        locale: const Locale('tr', 'TR'),
        supportedLocales: const [Locale('tr', 'TR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        theme: AppTheme.light(),
        home: HomeShell(store: store),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Finansın kontrol altında'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ayarlar').last);
      await tester.pumpAndSettle();
      expect(find.text('Görünüm'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }

  testWidgets('Advanced filters and six-month report render on a narrow phone', (tester) async {
    tester.view.physicalSize = const Size(360, 840);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..loading = false;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: HomeShell(store: store)));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Ödemeler').last);
    await tester.pumpAndSettle();
    expect(find.text('Sırala:'), findsOneWidget);
    expect(find.text('En yakın vade'), findsOneWidget);
    expect(find.text('Bugün'), findsOneWidget);
    await tester.tap(find.text('Bugün'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Raporlar').last);
    await tester.pumpAndSettle();
    expect(find.text('Önümüzdeki 6 ay · Nakit akışı'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('Calendar permits month navigation and returns to today', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppStore()..loading = false;
    await tester.pumpWidget(MaterialApp(theme: AppTheme.light(), home: CalendarPage(store: store)));
    await tester.pumpAndSettle();
    final today = DateTime.now();
    expect(find.text('${today.month} / ${today.year}'), findsOneWidget);
    expect(find.textContaining('Aylık borç:'), findsOneWidget);
    await tester.tap(find.byTooltip('Sonraki ay').first);
    await tester.pumpAndSettle();
    final next = DateTime(today.year, today.month + 1);
    expect(find.text('${next.month} / ${next.year}'), findsOneWidget);
    await tester.tap(find.text('Bugün'));
    await tester.pumpAndSettle();
    expect(find.text('${today.month} / ${today.year}'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
