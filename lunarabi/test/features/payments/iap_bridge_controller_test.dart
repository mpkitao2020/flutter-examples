import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/payments/iap_bridge_controller.dart';
import 'package:lunarabi/features/payments/iap_pending_store.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';

void main() {
  const productId = 'lunarabi.credit.100';

  test(
    'happy path gates completion on ok confirm with a live purchase',
    () async {
      final h = _Harness(confirmTimeout: const Duration(seconds: 1));
      addTearDown(h.dispose);
      await h.controller.startPurchaseStream();

      await h.start(productId);
      expect(h.store.buyAutoConsumeValues, [false]);

      final purchase = _purchase(purchaseID: 'tx-1', productId: productId);
      h.store.emit([purchase]);
      await _flush();

      expect(h.store.completed, isEmpty);
      expect((await h.pending.getByKey('tx-1'))!.waitingConfirm, isTrue);
      expect(h.byType(BridgeTypes.iapPurchaseUpdated).single.payload, {
        'purchaseKey': 'tx-1',
        'purchaseId': 'tx-1',
        'productId': productId,
        'platform': 'google_play',
        'verificationData': 'server-token',
      });

      await h.confirm('tx-1', ok: true);

      expect(h.store.completed, [purchase]);
      expect(await h.pending.getByKey('tx-1'), isNull);
      expect(h.byType(BridgeTypes.iapFinished).last.payload, {
        'purchaseKey': 'tx-1',
        'productId': productId,
        'status': 'completed',
      });
    },
  );

  test('canceled and error store updates finish without completing', () async {
    final h = _Harness();
    addTearDown(h.dispose);
    await h.controller.startPurchaseStream();
    await h.start(productId);

    h.store.emit([
      _purchase(status: PurchaseStatus.canceled, purchaseID: 'c1'),
    ]);
    h.store.emit([_purchase(status: PurchaseStatus.error, purchaseID: 'e1')]);
    await _flush();

    expect(h.store.completed, isEmpty);
    expect(h.byType(BridgeTypes.iapFinished).map((m) => m.payload['status']), [
      'canceled',
      'failed',
    ]);
  });

  test(
    'ok false leaves the pending record waiting and never completes',
    () async {
      final h = _Harness(confirmTimeout: const Duration(seconds: 1));
      addTearDown(h.dispose);
      await h.controller.startPurchaseStream();
      await h.start(productId);
      h.store.emit([_purchase(purchaseID: 'tx-false')]);
      await _flush();

      await h.confirm('tx-false', ok: false);

      expect(h.store.completed, isEmpty);
      final record = await h.pending.getByKey('tx-false');
      expect(record, isNotNull);
      expect(record!.waitingConfirm, isTrue);
      expect(
        h.byType(BridgeTypes.iapFinished).last.payload['status'],
        'failed',
      );
    },
  );

  test('timeout disarms waiting and rejects a late ok confirm', () async {
    final h = _Harness(confirmTimeout: const Duration(milliseconds: 20));
    addTearDown(h.dispose);
    await h.controller.startPurchaseStream();
    await h.start(productId);
    h.store.emit([_purchase(purchaseID: 'tx-timeout')]);
    await Future<void>.delayed(const Duration(milliseconds: 60));

    final record = await h.pending.getByKey('tx-timeout');
    expect(record, isNotNull);
    expect(record!.waitingConfirm, isFalse);
    expect(record.status, IapPendingStatus.timedOut);
    expect(h.byType(BridgeTypes.iapFinished).last.payload, {
      'purchaseKey': 'tx-timeout',
      'productId': productId,
      'status': 'failed',
      'reason': 'timed_out',
    });

    await h.confirm('tx-timeout', ok: true, requestId: 'late');

    expect(h.store.completed, isEmpty);
    expect(h.response('late').payload, {
      'ok': false,
      'error': 'confirm_not_waiting',
    });
  });

  test('unknown product is rejected before the Store is called', () async {
    final h = _Harness();
    addTearDown(h.dispose);

    await h.start('not.allowed', requestId: 'bad-product');

    expect(h.store.buyAutoConsumeValues, isEmpty);
    expect(h.response('bad-product').payload, {
      'ok': false,
      'error': 'product_not_allowed',
    });
  });

  test('duplicate, stale, and unknown confirms never complete twice', () async {
    final h = _Harness(confirmTimeout: const Duration(seconds: 1));
    addTearDown(h.dispose);
    await h.controller.startPurchaseStream();
    await h.start(productId);
    final purchase = _purchase(purchaseID: 'tx-dup');
    h.store.emit([purchase]);
    await _flush();
    await h.confirm('tx-dup', ok: true, requestId: 'first');

    await h.confirm('tx-dup', ok: true, requestId: 'duplicate');
    await h.confirm('missing', ok: true, requestId: 'unknown');
    await h.pending.upsert(
      IapPendingRecord(
        purchaseKey: 'stale',
        purchaseId: 'stale',
        productId: productId,
        platform: 'google_play',
        verificationData: 'stale-data',
        waitingConfirm: false,
        updatedAt: DateTime.utc(2026, 8, 11),
      ),
    );
    await h.confirm('stale', ok: true, requestId: 'stale');

    expect(h.store.completed, [purchase]);
    expect(h.response('duplicate').payload['ok'], isFalse);
    expect(h.response('unknown').payload['ok'], isFalse);
    expect(h.response('stale').payload, {
      'ok': false,
      'error': 'confirm_not_waiting',
    });
  });

  test(
    'deepLinkHost cannot start, confirm, or receive receipt events',
    () async {
      final h = _Harness(
        committedUri: Uri.parse('https://app.lunarabi.example/deep-link'),
      );
      addTearDown(h.dispose);
      await h.controller.startPurchaseStream();

      await h.start(productId, requestId: 'start-forbidden');
      h.store.emit([_purchase(purchaseID: 'tx-hidden')]);
      await _flush();
      await h.confirm('tx-hidden', ok: true, requestId: 'confirm-forbidden');

      expect(h.store.buyAutoConsumeValues, isEmpty);
      expect(h.store.completed, isEmpty);
      expect(h.byType(BridgeTypes.iapPurchaseUpdated), isEmpty);
      expect(h.byType(BridgeTypes.iapFinished), isEmpty);
      expect(
        h.response('start-forbidden').payload['error'],
        'forbidden_origin',
      );
      expect(
        h.response('confirm-forbidden').payload['error'],
        'forbidden_origin',
      );
    },
  );

  test(
    'rehydrated pending without a live Store tx re-emits but cannot complete',
    () async {
      final h = _Harness();
      addTearDown(h.dispose);
      await h.pending.upsert(
        IapPendingRecord(
          purchaseKey: 'tx-rehydrate',
          purchaseId: 'tx-rehydrate',
          productId: productId,
          platform: 'google_play',
          verificationData: 'server-token',
          waitingConfirm: true,
          updatedAt: DateTime.utc(2026, 8, 11),
        ),
      );

      await h.controller.onBridgeReady();
      await h.confirm('tx-rehydrate', ok: true, requestId: 'no-live');

      expect(
        h.byType(BridgeTypes.iapPurchaseUpdated).single.payload['purchaseKey'],
        'tx-rehydrate',
      );
      expect(h.store.completed, isEmpty);
      expect(h.response('no-live').payload, {
        'ok': false,
        'error': 'no_live_purchase',
      });
    },
  );
}

class _Harness {
  _Harness({
    Uri? committedUri,
    Duration confirmTimeout = const Duration(seconds: 1),
  }) : committedUri =
           committedUri ?? Uri.parse('https://web.lunarabi.example/account') {
    bridge = BridgeHost(
      nav: BottomNavController(),
      authRepo: _MemoryAuthTokenRepository(),
      push: push,
      committedWebUri: () => this.committedUri,
      webBaseUrl: webBaseUrl,
      emitter: (message) async => emitted.add(message),
    );
    controller = IapBridgeController(
      iap: IapPurchaseService(store: store, sourceOverride: 'google_play'),
      bridge: bridge,
      pending: pending,
      committedWebUri: () => this.committedUri,
      webBaseUrl: webBaseUrl,
      confirmTimeout: confirmTimeout,
    );
  }

  final webBaseUrl = Uri.parse('https://web.lunarabi.example');
  final store = _FakeStore();
  final pending = _MemoryIapPendingStore();
  final push = PushTokenStore();
  final emitted = <BridgeMessage>[];
  Uri? committedUri;
  late final BridgeHost bridge;
  late final IapBridgeController controller;

  Future<void> start(String productId, {String requestId = 'start'}) {
    return controller.handleFromJs(
      BridgeMessage(
        type: BridgeTypes.iapStart,
        requestId: requestId,
        payload: {'productId': productId},
      ),
    );
  }

  Future<void> confirm(
    String purchaseKey, {
    required bool ok,
    String requestId = 'confirm',
  }) {
    return controller.handleFromJs(
      BridgeMessage(
        type: BridgeTypes.iapConfirmResult,
        requestId: requestId,
        payload: {'purchaseKey': purchaseKey, 'ok': ok},
      ),
    );
  }

  Iterable<BridgeMessage> byType(String type) {
    return emitted.where((message) => message.type == type);
  }

  BridgeMessage response(String requestId) {
    return emitted.singleWhere(
      (message) =>
          message.type == BridgeTypes.bridgeResponse &&
          message.requestId == requestId,
    );
  }

  Future<void> dispose() async {
    await controller.dispose();
    await store.dispose();
    push.dispose();
  }
}

class _FakeStore implements IapStore {
  final _controller = StreamController<List<PurchaseDetails>>.broadcast();
  final completed = <PurchaseDetails>[];
  final buyAutoConsumeValues = <bool>[];
  var available = true;
  var products = <ProductDetails>[
    ProductDetails(
      id: 'lunarabi.credit.100',
      title: 'Credit 100',
      description: 'test',
      price: '¥100',
      rawPrice: 100,
      currencyCode: 'JPY',
    ),
  ];

  void emit(List<PurchaseDetails> purchases) => _controller.add(purchases);

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _controller.stream;

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<ProductDetailsResponse> queryProductDetails(
    Set<String> identifiers,
  ) async {
    final matched = products.where((p) => identifiers.contains(p.id)).toList();
    return ProductDetailsResponse(
      productDetails: matched,
      notFoundIDs: identifiers
          .difference(matched.map((p) => p.id).toSet())
          .toList(),
    );
  }

  @override
  Future<bool> buyConsumable({
    required PurchaseParam purchaseParam,
    bool autoConsume = false,
  }) async {
    buyAutoConsumeValues.add(autoConsume);
    return true;
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) async {
    completed.add(purchase);
  }

  Future<void> dispose() => _controller.close();
}

class _MemoryIapPendingStore implements IapPendingStore {
  final records = <String, IapPendingRecord>{};

  @override
  Future<void> upsert(IapPendingRecord record) async {
    records[record.purchaseKey] = record;
  }

  @override
  Future<IapPendingRecord?> getByKey(String purchaseKey) async {
    return records[purchaseKey];
  }

  @override
  Future<List<IapPendingRecord>> allWaiting() async {
    return records.values.where((record) => record.waitingConfirm).toList();
  }

  @override
  Future<void> remove(String purchaseKey) async {
    records.remove(purchaseKey);
  }
}

class _MemoryAuthTokenRepository implements AuthTokenRepository {
  @override
  Future<void> save(String token) async {}

  @override
  Future<String?> read() async => null;

  @override
  Future<void> clear() async {}
}

PurchaseDetails _purchase({
  PurchaseStatus status = PurchaseStatus.purchased,
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

Future<void> _flush() async {
  await Future<void>.delayed(Duration.zero);
  await Future<void>.delayed(Duration.zero);
}
