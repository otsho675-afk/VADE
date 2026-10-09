import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/screens/auth_page.dart';
import 'package:vadesi/ui/screens/welcome_page.dart';
import 'package:vadesi/ui/widgets/wheel_date_picker.dart';
import 'package:vadesi/ui/widgets/smart_keyboard.dart';

Widget app(Widget home) => MaterialApp(locale: const Locale('tr'),
  supportedLocales: const [Locale('tr')],
  localizationsDelegates: GlobalMaterialLocalizations.delegates, home: home);

void main() {
  test('IBAN paste groups characters and preserves a valid cursor', () {
    final formatter = IbanInputFormatter();
    final formatted = formatter.formatEditUpdate(TextEditingValue.empty,
      const TextEditingValue(text: 'tr330006100519786457841326',
        selection: TextSelection.collapsed(offset: 26)));
    expect(formatted.text, 'TR33 0006 1005 1978 6457 8413 26');
    expect(formatted.selection.extentOffset, formatted.text.length);
    final overflow = formatter.formatEditUpdate(formatted,
      TextEditingValue(text: formatted.text + '1'));
    expect(overflow, formatted);
  });

  for (final width in [320.0, 390.0, 1024.0]) {
    testWidgets('registration and login remain discoverable at width $width', (tester) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final store = AppStore()..loading = false;
      await tester.pumpWidget(app(WelcomeGate(store: store)));
      await tester.pumpAndSettle();
      expect(find.text('Üye ol'), findsOneWidget);
      await tester.ensureVisible(find.text('Üye ol'));
      await tester.tap(find.text('Üye ol'));
      await tester.pumpAndSettle();
      expect(find.text('Birlikte başlayalım.'), findsOneWidget);
      expect(find.text('Şifre tekrar'), findsOneWidget);
      final submit = tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Hesabımı oluştur'));
      expect(submit.onPressed, isNull);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }

  testWidgets('registration validates confirmation before calling Firebase', (tester) async {
    final store = AppStore()..cloud.ready = true;
    await tester.pumpWidget(app(AuthPage(store: store, register: true)));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).at(0), 'test@example.com');
    await tester.enterText(find.byType(TextFormField).at(1), 'abcdef123');
    await tester.enterText(find.byType(TextFormField).at(2), 'different');
    final button = find.widgetWithText(FilledButton, 'Hesabımı oluştur');
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
    expect(find.text('Şifreler eşleşmiyor.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('wheel date cancel returns no date and confirmation keeps leap day', (tester) async {
    DateTime? result;
    await tester.pumpWidget(app(Builder(builder: (context) => Scaffold(
      body: TextButton(onPressed: () async {
        result = await showWheelDatePicker(context: context, initialDate: DateTime(2028, 2, 29),
          firstDate: DateTime(2020), lastDate: DateTime(2100));
      }, child: const Text('Tarih aç')),
    ))));
    await tester.tap(find.text('Tarih aç'));
    await tester.pumpAndSettle();
    expect(find.byType(CupertinoDatePicker), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await tester.pumpAndSettle();
    expect(result, isNull);
    await tester.tap(find.text('Tarih aç'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tamam'));
    await tester.pumpAndSettle();
    expect(result, DateTime(2028, 2, 29));
  });
}
