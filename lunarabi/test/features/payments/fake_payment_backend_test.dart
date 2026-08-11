// =============================================================================
// FakePaymentBackendClient の契約
// =============================================================================
//
// - 商品 ID は consumable `lunarabi.credit.100`
// - あおぞら入金確認は paymentId ごとに 1 回目 pending、2 回目 success
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

void main() {
  test('listProducts は lunarabi.credit.100 を返す', () async {
    final client = FakePaymentBackendClient();
    final products = await client.listProducts();
    expect(products, hasLength(1));
    expect(products.single.id, 'lunarabi.credit.100');
    expect(products.single.displayName, 'Credit 100');
  });

  test('createGmoLink は mock checkout URL を返す', () async {
    final client = FakePaymentBackendClient();
    final session = await client.createGmoLink(productId: 'lunarabi.credit.100');
    expect(session.paymentId, isNotEmpty);
    expect(
      session.checkoutUrl.toString(),
      'https://app.lunarabi.example/mock-gmo-checkout?paymentId=${session.paymentId}',
    );
  });

  test('checkBankTransfer は 1 回目 pending、2 回目 success', () async {
    final client = FakePaymentBackendClient();
    final session = await client.createAozoraTransfer(
      productId: 'lunarabi.credit.100',
    );
    expect(session.accountDisplay, contains('あおぞら銀行'));

    expect(
      await client.checkBankTransfer(paymentId: session.paymentId),
      PaymentStatus.pending,
    );
    expect(
      await client.checkBankTransfer(paymentId: session.paymentId),
      PaymentStatus.success,
    );
  });
}
