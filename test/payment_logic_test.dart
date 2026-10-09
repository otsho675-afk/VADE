import 'package:flutter_test/flutter_test.dart';
import 'package:vadesi/models/payment.dart';

void main() {
  test('Ay sonu taksitleri ayin sonuna sabitlenir', () {
    final first = DateTime(2027, 1, 31);
    expect(addMonthsAnchored(first, 1, 31), DateTime(2027, 2, 28));
    expect(addMonthsAnchored(first, 2, 31), DateTime(2027, 3, 31));
    expect(addMonthsAnchored(DateTime(2028, 1, 31), 1, 31), DateTime(2028, 2, 29));
  });
  test('Turkce tutarlari kurus olarak saklar', () {
    expect(parseMoneyToCents('1.250,75'), 125075);
    expect(parseMoneyToCents('1250,75'), 125075);
    expect(parseMoneyToCents('1250'), 125000);
    expect(parseMoneyToCents('abc'), null);
    expect(parseMoneyToCents('1.2,34'), null);
    expect(parseMoneyToCents('9999999999,99'), 999999999999);
    expect(parseMoneyToCents('10000000000'), null);
    expect(parseMoneyToCents('9223372036854775807'), null);
    expect(parseMoneyToCents('-12,50'), null);
  });
  test('Turk IBAN dogrulama', () {
    expect(isValidIban('TR33 0006 1005 1978 6457 8413 26'), true);
    expect(isValidIban('TR33 0006 1005 1978 6457 8413 27'), false);
    expect(isValidIban(''), true);
  });
}
