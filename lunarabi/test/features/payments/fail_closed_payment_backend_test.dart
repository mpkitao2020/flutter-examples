// =============================================================================
// FailClosedPaymentBackendClient
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

void main() {
  final client = FailClosedPaymentBackendClient();

  test('listProducts は空', () async {
    expect(await client.listProducts(), isEmpty);
  });

  test('confirm / create は StateError', () async {
    expect(
      () => client.confirmIap(
        productId: 'x',
        verificationData: 'y',
        source: 'google_play',
      ),
      throwsStateError,
    );
    expect(() => client.createGmoLink(productId: 'x'), throwsStateError);
    expect(() => client.confirmGmo(paymentId: 'x'), throwsStateError);
    expect(() => client.createAozoraTransfer(productId: 'x'), throwsStateError);
  });

  test('checkBankTransfer は failure', () async {
    expect(
      await client.checkBankTransfer(paymentId: 'x'),
      PaymentStatus.failure,
    );
  });
}
