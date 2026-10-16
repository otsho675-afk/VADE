import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/app_theme.dart';
import 'package:vadesi/ui/screens/payment_form_page.dart';

void main() {
  for (final width in [320.0, 390.0, 780.0]) {
    testWidgets('Payment form adapts to screen width $width', (tester) async {
      tester.view.physicalSize = Size(width, 950);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppStore()..loading = false;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: PaymentFormPage(store: store),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Yeni ödeme ekle'), findsOneWidget);
      expect(find.text('Taksit'), findsOneWidget);
      expect(find.text('Fatura'), findsOneWidget);
      expect(find.text('Abonelik'), findsOneWidget);
      expect(find.text('Tek seferlik'), findsOneWidget);
      expect(find.text('Ödeyeceğim'), findsOneWidget);
      expect(find.text('Alacağım'), findsOneWidget);
      expect(find.text('Ödeme planını oluştur'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
      store.dispose();
    });
  }

  testWidgets('Payment type and direction change the visible fields', (tester) async {
    final store = AppStore()..loading = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: PaymentFormPage(store: store),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Fatura'));
    await tester.pumpAndSettle();
    expect(find.text('Fatura kategorisi'), findsOneWidget);
    expect(find.text('Toplam taksit sayısı *'), findsNothing);

    await tester.tap(find.text('Alacağım'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('Kişi / kurum adı (isteğe bağlı)'), 250,
      scrollable: find.byType(Scrollable).first);
    expect(find.text('Kişi / kurum adı (isteğe bağlı)'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('Save button validates required fields without writing incomplete payments', (tester) async {
    final store = AppStore()..loading = false;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: PaymentFormPage(store: store),
    ));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Ödeme planını oluştur'));
    await tester.pump();
    expect(find.text('Ödeme adı girin.'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
