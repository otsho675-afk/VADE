import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/services/cloud_service.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/screens/account_page.dart';

class FakeCloud extends CloudService {
  int registrations = 0;
  String? failure;
  FakeCloud() { ready = true; }
  @override
  Future<void> signIn(String email, String password, {bool register = false}) async {
    if (register) registrations++;
    if (failure != null) throw FirebaseAuthException(code: failure!);
  }
}

void main() {
  testWidgets('registration works without optional legal URL configuration', (tester) async {
    final cloud = FakeCloud();
    final store = AppStore(cloudService: cloud);
    await tester.pumpWidget(MaterialApp(home: AccountPage(store: store)));
    await tester.enterText(find.byType(TextField).first, 'test@example.com');
    await tester.enterText(find.byType(TextField).last, 'test123456');
    await tester.tap(find.text('Hesap oluştur'));
    await tester.pumpAndSettle();
    expect(cloud.registrations, 1);
    expect(find.text('Hesap oluşturuldu. Doğrulama e-postanızı kontrol edin.'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  testWidgets('registration displays actionable Firebase error', (tester) async {
    final cloud = FakeCloud()..failure = 'email-already-in-use';
    final store = AppStore(cloudService: cloud);
    await tester.pumpWidget(MaterialApp(home: AccountPage(store: store)));
    await tester.tap(find.text('Hesap oluştur'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Bu e-posta zaten kayıtlı. Giriş yapın veya şifrenizi yenileyin.'), findsOneWidget);
    expect(tester.widget<OutlinedButton>(find.widgetWithText(OutlinedButton, 'Hesap oluştur')).onPressed, isNotNull);
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
  test('cloud rejects invalid credentials before calling Firebase', () async {
    final cloud = CloudService()..ready = true;
    await expectLater(cloud.signIn('invalid', '123456', register: true), throwsFormatException);
    await expectLater(cloud.signIn('test@example.com', '123', register: true), throwsFormatException);
    cloud.dispose();
  });
}
