// =============================================================================
// IAP ラッパー
// =============================================================================
//
// - purchased → confirmIap → completePurchase → success
// - error / canceled → failure
// - restored 単独は hang せず timeout → failure（confirm しない）
// - buy 前の backlog purchased はセッション成功にしない
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

class _RecordingBackend implements PaymentBackendClient {
  final confirmCalls = <Map<String, String>>[];
  Object? confirmError;
  Duration? confirmDelay;

  @override
  Future<List<ProductRef>> listProducts() async => const [];

  @override
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  }) async {
    final delay = confirmDelay;
    if (delay != null) await Future<void>.delayed(delay);
    if (confirmError != null) throw confirmError!;
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
    this.backlogOnListen,
    this.buyResult = true,
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
  final List<PurchaseDetails>? backlogOnListen;
  final bool buyResult;
  final completed = <PurchaseDetails>[];
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream {
    return Stream<List<PurchaseDetails>>.multi((listener) {
      final backlog = backlogOnListen;
      if (backlog != null) {
        listener.add(backlog);
      }
      final sub = _controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = () async {
        await sub.cancel();
      };
    });
  }

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
      notFoundIDs:
          identifiers.difference(matched.map((e) => e.id).toSet()).toList(),
    );
  }

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) async {
    final events = emitAfterBuy;
    if (events != null) {
      scheduleMicrotask(() => _controller.add(events));
    }
    return buyResult;
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
  String? purchaseID,
  String serverData = 'server-token',
}) {
  return PurchaseDetails(
    purchaseID: purchaseID,
    productID: productId,
    verificationData: PurchaseVerificationData(
      localVerificationData: 'local',
      serverVerificationData: serverData,
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
      emitAfterBuy: [
        _purchase(status: PurchaseStatus.purchased, purchaseID: 'tx-1'),
      ],
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
    expect(store.completed, hasLength(1));
  });

  test('同一 purchase の再配信では confirm を二重に呼ばない', () async {
    final purchase =
        _purchase(status: PurchaseStatus.purchased, purchaseID: 'tx-dup');
    final store = _FakeStore(emitAfterBuy: [purchase, purchase]);
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(store: store, sourceOverride: 'google_play');

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.success);
    expect(backend.confirmCalls, hasLength(1));
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
  });

  test('restored 単独は confirm せず短 timeout で failure', () async {
    final store = _FakeStore(
      emitAfterBuy: [_purchase(status: PurchaseStatus.restored)],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(
      store: store,
      buyTimeout: const Duration(milliseconds: 50),
    );

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
    expect(backend.confirmCalls, isEmpty);
  });

  test('buyConsumable が false なら即 failure', () async {
    final store = _FakeStore(buyResult: false);
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(store: store);

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
    expect(backend.confirmCalls, isEmpty);
  });

  test('confirm 例外は failure', () async {
    final store = _FakeStore(
      emitAfterBuy: [
        _purchase(status: PurchaseStatus.purchased, purchaseID: 'tx-err'),
      ],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend()..confirmError = Exception('boom');
    final service = IapPurchaseService(store: store, sourceOverride: 'google_play');

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
  });

  test('buy 前 backlog の purchased はセッション成功に使わない', () async {
    final store = _FakeStore(
      backlogOnListen: [
        _purchase(
          status: PurchaseStatus.purchased,
          purchaseID: 'old-tx',
          serverData: 'old',
        ),
      ],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend();
    final service = IapPurchaseService(
      store: store,
      sourceOverride: 'google_play',
      buyTimeout: const Duration(milliseconds: 80),
    );

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
    // Hygiene confirm may run for backlog; must not treat as this buy success.
    expect(
      backend.confirmCalls.where((c) => c['verificationData'] == 'old'),
      isNotEmpty,
    );
  });

  test('遅い hygiene confirm 中でも backlog はセッション成功に使わない', () async {
    final store = _FakeStore(
      backlogOnListen: [
        _purchase(
          status: PurchaseStatus.purchased,
          purchaseID: 'old-1',
          serverData: 'old-1',
        ),
        _purchase(
          status: PurchaseStatus.purchased,
          purchaseID: 'old-2',
          serverData: 'old-2',
        ),
      ],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend()
      ..confirmDelay = const Duration(milliseconds: 40);
    final service = IapPurchaseService(
      store: store,
      sourceOverride: 'google_play',
      buyTimeout: const Duration(milliseconds: 100),
    );

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.failure);
    expect(backend.confirmCalls, hasLength(2));
  });

  test('confirm 中の canceled でも success を維持', () async {
    final purchase =
        _purchase(status: PurchaseStatus.purchased, purchaseID: 'tx-race');
    final store = _FakeStore(emitAfterBuy: [purchase]);
    addTearDown(store.dispose);
    final backend = _RecordingBackend()
      ..confirmDelay = const Duration(milliseconds: 60);
    final service = IapPurchaseService(
      store: store,
      sourceOverride: 'google_play',
    );

    final buyFuture = service.buy(product: product, backend: backend);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    store.emit([
      _purchase(status: PurchaseStatus.canceled, purchaseID: 'tx-race'),
    ]);
    final status = await buyFuture;

    expect(status, PaymentStatus.success);
    expect(backend.confirmCalls, hasLength(1));
  });

  test('timeout 中に confirm が終われば success', () async {
    final store = _FakeStore(
      emitAfterBuy: [
        _purchase(status: PurchaseStatus.purchased, purchaseID: 'tx-slow'),
      ],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend()
      ..confirmDelay = const Duration(milliseconds: 80);
    final service = IapPurchaseService(
      store: store,
      sourceOverride: 'google_play',
      buyTimeout: const Duration(milliseconds: 20),
    );

    final status = await service.buy(product: product, backend: backend);

    expect(status, PaymentStatus.success);
  });

  test('並行 buy は二件目を failure', () async {
    final store = _FakeStore(
      emitAfterBuy: [
        _purchase(status: PurchaseStatus.purchased, purchaseID: 'tx-a'),
      ],
    );
    addTearDown(store.dispose);
    final backend = _RecordingBackend()
      ..confirmDelay = const Duration(milliseconds: 50);
    final service = IapPurchaseService(
      store: store,
      sourceOverride: 'google_play',
    );

    final first = service.buy(product: product, backend: backend);
    final second = await service.buy(product: product, backend: backend);
    expect(second, PaymentStatus.failure);
    expect(await first, PaymentStatus.success);
  });
}
