import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/screens/launch_screen.dart';
import 'package:vadesi/ui/widgets/brand_mark.dart';

void main() {
  testWidgets('Launch logo animates before opening the existing dashboard', (tester) async {
    SharedPreferences.setMockInitialValues({'welcome_completed': true});
    final store = AppStore()..loading = false;
    await tester.pumpWidget(MaterialApp(home: LaunchScreen(
      store: store, displayDuration: const Duration(milliseconds: 1100),
    )));
    expect(find.byType(BrandMark), findsOneWidget);
    expect(find.text('VADESİ'), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('Finansın kontrol altında'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });

  testWidgets('Launch preserves first-time login and guest buttons', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final store = AppStore()..loading = false;
    await tester.pumpWidget(MaterialApp(home: LaunchScreen(
      store: store, displayDuration: const Duration(milliseconds: 1100),
    )));
    expect(find.byType(BrandMark), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1600));
    await tester.pumpAndSettle();
    expect(find.text('Üye ol'), findsOneWidget);
    expect(find.text('Misafir olarak devam et'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
