import 'package:lunarabi/features/payments/payment_models.dart';

export 'package:lunarabi/features/payments/payment_models.dart';

abstract interface class PaymentBackendClient {
  Future<List<ProductRef>> listProducts();
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  });
  Future<GmoLinkSession> createGmoLink({required String productId});
  Future<void> confirmGmo({required String paymentId});
  Future<AozoraTransferSession> createAozoraTransfer({required String productId});
  Future<PaymentStatus> checkBankTransfer({required String paymentId});
}

class FakePaymentBackendClient implements PaymentBackendClient {
  final Map<String, int> _bankChecks = {};
  var _gmoSeq = 0;
  var _aozoraSeq = 0;

  @override
  Future<List<ProductRef>> listProducts() async {
    return const [
      ProductRef(id: 'lunarabi.credit.100', displayName: 'Credit 100'),
    ];
  }

  @override
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  }) async {}

  @override
  Future<GmoLinkSession> createGmoLink({required String productId}) async {
    _gmoSeq += 1;
    final paymentId = 'gmo-$_gmoSeq';
    return GmoLinkSession(
      paymentId: paymentId,
      checkoutUrl: Uri.parse(
        'https://app.lunarabi.example/mock-gmo-checkout?paymentId=$paymentId',
      ),
    );
  }

  @override
  Future<void> confirmGmo({required String paymentId}) async {}

  @override
  Future<AozoraTransferSession> createAozoraTransfer({
    required String productId,
  }) async {
    _aozoraSeq += 1;
    final paymentId = 'aozora-$_aozoraSeq';
    return AozoraTransferSession(
      paymentId: paymentId,
      accountDisplay: 'あおぞら銀行 999 支店 普通 1234567',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
  }

  @override
  Future<PaymentStatus> checkBankTransfer({required String paymentId}) async {
    final n = (_bankChecks[paymentId] ?? 0) + 1;
    _bankChecks[paymentId] = n;
    return n >= 2 ? PaymentStatus.success : PaymentStatus.pending;
  }
}
