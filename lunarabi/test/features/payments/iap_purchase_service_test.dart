// =============================================================================
// IAP ラッパー
// =============================================================================
//
// - purchased → confirmIap → completePurchase → success
// - error / canceled → failure
// - restored は consumable のため無視（confirm しない）
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

class _RecordingBackend implements PaymentBackendClient {
  final confirmCalls = <Map<String, String>>[];

  @override
  Future<List<ProductRef>> listProducts() async => const [];

  @override
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  }) async {
    confirmCalls.add({
      'productId': productId,
      'verificationData': verificationData,
      'source': source,
    });
  }

  @override
  Future<GmoLinkSession> createGmoLink({required String productId}) {
    throw UnimplementedError();
  }

  @override
  Future<void> confirmGmo({required String paymentId}) {
    throw UnimplementedError();
  }

  @override
  Future<AozoraTransferSession> createAozoraTransfer({
    required String productId,
  }) {
    throw UnimplementedError();
  }

  @override
  Future<PaymentStatus> checkBankTransfer({required String paymentId}) {
    throw UnimplementedError();
  }
}

class _FakeStore implements IapStore {
  _FakeStore({
    List<ProductDetails>? products,
    this.emitAfterBuy,
  }) : products = products ??
            [
              ProductDetails(
                id: 'lunarabi.credit.100',
                title: 'Credit 100',
                description: 'test',
                price: '¥100',
                rawPrice: 100,
                currencyCode: 'JPY',
              ),
            ];

  final List<ProductDetails> products;
  final List<PurchaseDetails>? emitAfterBuy;
  final completed = <PurchaseDetails>[];
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    final matched =
        products.where((p) => identifiers.contains(p.id)).toList();
    return ProductDetailsResponse(
      productDetails: matched,
      notFoundIDs: identifiers.difference(matched.map((e) => e.id).toSet()).toList(),
    );
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) async {
    final events = emitAfterBuy;
    if (events != null) {
      scheduleMicrotask(() => _controller.add(events));
    }
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  Future<void> dispose() => _controller.close();
}

PurchaseDetails _purchase({
  required PurchaseStatus status,
  String productId = 'lunarabi.credit.100',
}) {
  return PurchaseDetails(
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: 'server-token',
      source: 'test',
    ),
    transactionDate: '0',
    status: status,
  );
}

void main() {
  const product = ProductRef(
    id: 'lunarabi.credit.100',
    displayName: 'Credit 100',
  );

  test('purchased で confirm → complete → success', () async {
    final store = _FakeStore(
      emitAfterBuy: [_purchase(status: PurchaseStatus.purchased)],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(
      store: store,
      sourceOverride: 'google_play',
    );

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.success);
    expect(backend.confirmCalls, hasLength(1));
    expect(backend.confirmCalls.single['verificationData'], 'server-token');
    expect(store.completed, hasLength(1));
  });

  test('error は failure で confirm しない', () async {
    final store = _FakeStore(
      emitAfterBuy: [_purchase(status: PurchaseStatus.error)],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(store: store);

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
    expect(backend.confirmCalls, isEmpty);
    expect(store.completed, isEmpty);
  });

  test('restored は confirm せず、同バッチの canceled で failure', () async {
    final store = _FakeStore(
      emitAfterBuy: [
        _purchase(status: PurchaseStatus.restored),
        _purchase(status: PurchaseStatus.canceled),
      ],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(store: store);

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
    expect(backend.confirmCalls, isEmpty);
  });
}
