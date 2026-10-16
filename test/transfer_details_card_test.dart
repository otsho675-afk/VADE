import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/models/payment.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/app_theme.dart';
import 'package:vadesi/ui/screens/payment_detail_page.dart';
import 'package:vadesi/ui/widgets/transfer_details_card.dart';

void main() {
  testWidgets(
    'name and IBAN copy independently and together on a narrow iPhone',
    (tester) async {
      String? clipboardText;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            clipboardText =
                (call.arguments as Map<Object?, Object?>)['text'] as String?;
          }
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      tester.view.physicalSize = const Size(320, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: SafeArea(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: TransferDetailsCard(
                    party: 'Ahmet Yılmaz',
                    iban: 'TR330006100519786457841326',
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);

      await tester.tap(find.text('Ahmet Yılmaz'));
      await tester.pumpAndSettle();
      expect(clipboardText, 'Ahmet Yılmaz');

      await tester.tap(find.text('TR33 0006 1005 1978 6457 8413 26'));
      await tester.pumpAndSettle();
      expect(clipboardText, 'TR330006100519786457841326');

      await tester.tap(find.text('İsim ve IBAN’ı birlikte kopyala'));
      await tester.pumpAndSettle();
      expect(
        clipboardText,
        'Kişi / Kurum: Ahmet Yılmaz\nIBAN: TR330006100519786457841326',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('payment details keep transfer actions readable at 320px', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final plan = PaymentPlan(
      id: 1,
      title: 'Kira ödemesi',
      party: 'Ahmet Yılmaz',
      iban: 'TR330006100519786457841326',
      note: 'Ekim kirası',
      kind: PaymentKind.single,
      direction: PaymentDirection.outgoing,
      category: InvoiceCategory.rent,
      amountCents: 1250000,
      count: 1,
      anchorDay: 16,
      startDate: DateTime(2026, 10, 16),
      createdAt: DateTime(2026, 10, 1),
    );
    final store = AppStore()..loading = false;
    store.items = [
      DueItem(
        id: 1,
        planId: 1,
        sequence: 1,
        dueDate: DateTime(2026, 10, 16),
        amountCents: 1250000,
        paidAt: null,
        plan: plan,
      ),
    ];
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: PaymentDetailPage(store: store, planId: 1),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    await tester.scrollUntilVisible(
      find.text('Havale bilgileri'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('KİŞİ / KURUM'), findsOneWidget);
    expect(find.text('IBAN'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
