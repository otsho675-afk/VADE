import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/state/app_store.dart';
import 'package:vadesi/ui/screens/account_page.dart';

void main() {
  testWidgets('unconfigured cloud leaves local access available and purchases disabled', (tester) async {
    final store = AppStore();
    await tester.pumpWidget(MaterialApp(home: AccountPage(store: store)));
    await tester.pump();
    expect(find.textContaining('Bulut hizmeti henüz etkinleştirilmedi'), findsOneWidget);
    expect(find.text('Abone ol'), findsNothing);
    expect(find.text('Hesap oluştur'), findsNothing);
    final toggle = tester.widget<SwitchListTile>(find.byType(SwitchListTile));
    expect(toggle.onChanged, isNotNull); // OneSignal announcements do not require a Firebase login.
    await tester.pumpWidget(const SizedBox.shrink());
    store.dispose();
  });
}
