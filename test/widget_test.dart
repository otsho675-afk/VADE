import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/app_theme.dart';
import 'package:vadesi/ui/screens/home_shell.dart';

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
      expect(find.text('Ödemeleriniz tek yerde'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Ayarlar').last);
      await tester.pumpAndSettle();
      expect(find.text('Görünüm'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }
}
