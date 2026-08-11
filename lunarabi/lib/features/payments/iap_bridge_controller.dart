import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/payments/iap_pending_store.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';
import 'package:lunarabi/features/webview/trusted_bridge_origin.dart';

class IapBridgeController {
  IapBridgeController({
    required IapPurchaseService iap,
    required BridgeHost bridge,
    required IapPendingStore pending,
    required Uri? Function() committedWebUri,
    required Uri webBaseUrl,
    this.allowedProductIds = const {'lunarabi.credit.100'},
    this.confirmTimeout = const Duration(minutes: 2),
  }) : _iap = iap,
       _bridge = bridge,
       _pending = pending,
       _committedWebUri = committedWebUri,
       _webBaseUrl = webBaseUrl;

  final IapPurchaseService _iap;
  final BridgeHost _bridge;
  final IapPendingStore _pending;
  final Uri? Function() _committedWebUri;
  final Uri _webBaseUrl;
  final Set<String> allowedProductIds;
  final Duration confirmTimeout;

  final _livePurchases = <String, PurchaseDetails>{};
  final _completedKeys = <String>{};
  final _confirmTimers = <String, Timer>{};
  StreamSubscription<List<PurchaseDetails>>? _purchaseSub;

  Future<void> handleFromJs(BridgeMessage message) async {
    switch (message.type) {
      case BridgeTypes.iapStart:
        await _handleStart(message);
      case BridgeTypes.iapConfirmResult:
        await _handleConfirmResult(message);
      default:
        await _respondError(message, 'unknown_type');
    }
  }

  Future<void> startPurchaseStream() async {
    if (_purchaseSub != null) return;
    _purchaseSub = _iap.purchaseStream.listen(
      (purchases) {
        unawaited(_handlePurchases(purchases));
      },
      onError: (Object error, StackTrace stack) {
        debugPrint('IapBridgeController: purchase stream error $error');
        debugPrint('$stack');
      },
    );
    await _reemitWaitingPurchases();
  }

  Future<void> onAppResumed() => _reemitWaitingPurchases();

  Future<void> onBridgeReady() => _reemitWaitingPurchases();

  Future<void> dispose() async {
    for (final timer in _confirmTimers.values) {
      timer.cancel();
    }
    _confirmTimers.clear();
    await _purchaseSub?.cancel();
    _purchaseSub = null;
  }

  Future<void> _handleStart(BridgeMessage message) async {
    if (!await _requireTrustedBridgeOrigin(message)) return;

    final productId = message.payload['productId'];
    if (productId is! String || productId.isEmpty) {
      await _respondError(message, 'invalid_payload');
      return;
    }
    if (!allowedProductIds.contains(productId)) {
      await _respondError(message, 'product_not_allowed');
      return;
    }

    final productDetails = await _iap.productDetailsFor(productId);
    if (productDetails == null) {
      await _respondError(message, 'product_not_found');
      return;
    }

    final started = await _iap.buyProduct(productDetails);
    if (!started) {
      await _respondError(message, 'purchase_not_started');
      return;
    }
    await _respondOk(message, <String, dynamic>{});
  }

  Future<void> _handleConfirmResult(BridgeMessage message) async {
    if (!await _requireTrustedBridgeOrigin(message)) return;

    final purchaseKey = message.payload['purchaseKey'];
    final ok = message.payload['ok'];
    if (purchaseKey is! String || purchaseKey.isEmpty || ok is! bool) {
      await _respondError(message, 'invalid_payload');
      return;
    }

    if (_completedKeys.contains(purchaseKey)) {
      await _respondError(message, 'duplicate_confirm');
      return;
    }

    final record = await _pending.getByKey(purchaseKey);
    if (record == null) {
      await _respondError(message, 'unknown_purchase');
      return;
    }
    if (!record.waitingConfirm) {
      await _respondError(message, 'confirm_not_waiting');
      return;
    }

    if (!ok) {
      await _emitFinished(
        purchaseKey: record.purchaseKey,
        productId: record.productId,
        status: 'failed',
        reason: 'verification_failed',
      );
      await _respondOk(message, <String, dynamic>{});
      return;
    }

    final livePurchase = _livePurchases[purchaseKey];
    if (livePurchase == null) {
      await _respondError(message, 'no_live_purchase');
      return;
    }

    _completedKeys.add(purchaseKey);
    _confirmTimers.remove(purchaseKey)?.cancel();
    await _iap.completePurchase(livePurchase);
    _livePurchases.remove(purchaseKey);
    await _pending.remove(purchaseKey);
    await _emitFinished(
      purchaseKey: record.purchaseKey,
      productId: record.productId,
      status: 'completed',
    );
    await _respondOk(message, <String, dynamic>{});
  }

  Future<void> _handlePurchases(List<PurchaseDetails> purchases) async {
    for (final purchase in purchases) {
      switch (purchase.status) {
        case PurchaseStatus.purchased:
          await _handlePurchased(purchase);
        case PurchaseStatus.canceled:
          await _handleTerminalPurchase(purchase, status: 'canceled');
        case PurchaseStatus.error:
          await _handleTerminalPurchase(purchase, status: 'failed');
        case PurchaseStatus.pending:
        case PurchaseStatus.restored:
          break;
      }
    }
  }

  Future<void> _handlePurchased(PurchaseDetails purchase) async {
    final record = _recordForPurchase(purchase).copyWith(
      waitingConfirm: true,
      status: IapPendingStatus.waiting,
      updatedAt: DateTime.now().toUtc(),
    );
    _livePurchases[record.purchaseKey] = purchase;
    await _pending.upsert(record);
    _armConfirmTimeout(record.purchaseKey);
    await _emitPurchaseUpdated(record);
  }

  Future<void> _handleTerminalPurchase(
    PurchaseDetails purchase, {
    required String status,
  }) async {
    final record = _recordForPurchase(purchase);
    _livePurchases.remove(record.purchaseKey);
    _confirmTimers.remove(record.purchaseKey)?.cancel();
    await _pending.remove(record.purchaseKey);
    await _emitFinished(
      purchaseKey: record.purchaseKey,
      productId: record.productId,
      status: status,
    );
  }

  IapPendingRecord _recordForPurchase(PurchaseDetails purchase) {
    final platform = _iap.platform;
    final verificationData = purchase.verificationData.serverVerificationData;
    return IapPendingRecord(
      purchaseKey: IapPendingRecord.purchaseKeyFor(
        purchaseId: purchase.purchaseID,
        platform: platform,
        productId: purchase.productID,
        verificationData: verificationData,
      ),
      purchaseId: purchase.purchaseID,
      productId: purchase.productID,
      platform: platform,
      verificationData: verificationData,
      waitingConfirm: true,
      updatedAt: DateTime.now().toUtc(),
    );
  }

  void _armConfirmTimeout(String purchaseKey) {
    _confirmTimers.remove(purchaseKey)?.cancel();
    _confirmTimers[purchaseKey] = Timer(confirmTimeout, () {
      unawaited(_markTimedOut(purchaseKey));
    });
  }

  Future<void> _markTimedOut(String purchaseKey) async {
    _confirmTimers.remove(purchaseKey);
    final record = await _pending.getByKey(purchaseKey);
    if (record == null || !record.waitingConfirm) return;
    final timedOut = record.copyWith(
      waitingConfirm: false,
      status: IapPendingStatus.timedOut,
      updatedAt: DateTime.now().toUtc(),
    );
    await _pending.upsert(timedOut);
    await _emitFinished(
      purchaseKey: timedOut.purchaseKey,
      productId: timedOut.productId,
      status: 'failed',
      reason: 'timed_out',
    );
  }

  Future<void> _reemitWaitingPurchases() async {
    if (!_isTrustedBridgeOrigin) return;
    final records = await _pending.allWaiting();
    for (final record in records) {
      await _emitPurchaseUpdated(record);
    }
  }

  Future<bool> _requireTrustedBridgeOrigin(BridgeMessage request) async {
    if (_isTrustedBridgeOrigin) return true;
    await _respondError(request, 'forbidden_origin');
    return false;
  }

  bool get _isTrustedBridgeOrigin =>
      isTrustedBridgeOrigin(_committedWebUri(), _webBaseUrl);

  Future<void> _emitPurchaseUpdated(IapPendingRecord record) async {
    if (!_isTrustedBridgeOrigin) return;
    await _bridge.emitToJs(
      BridgeMessage(
        type: BridgeTypes.iapPurchaseUpdated,
        payload: {
          'purchaseKey': record.purchaseKey,
          'purchaseId': record.purchaseId,
          'productId': record.productId,
          'platform': record.platform,
          'verificationData': record.verificationData,
        },
      ),
    );
  }

  Future<void> _emitFinished({
    required String purchaseKey,
    required String productId,
    required String status,
    String? reason,
  }) async {
    if (!_isTrustedBridgeOrigin) return;
    await _bridge.emitToJs(
      BridgeMessage(
        type: BridgeTypes.iapFinished,
        payload: {
          'purchaseKey': purchaseKey,
          'productId': productId,
          'status': status,
          if (reason != null) 'reason': reason,
        },
      ),
    );
  }

  Future<void> _respondOk(BridgeMessage request, Map<String, dynamic> payload) {
    final requestId = request.requestId;
    if (requestId == null) return Future<void>.value();
    return _bridge.emitToJs(
      BridgeMessage(
        type: BridgeTypes.bridgeResponse,
        requestId: requestId,
        payload: {'ok': true, ...payload},
      ),
    );
  }

  Future<void> _respondError(BridgeMessage request, String error) {
    final requestId = request.requestId;
    if (requestId == null) return Future<void>.value();
    return _bridge.emitToJs(
      BridgeMessage(
        type: BridgeTypes.bridgeResponse,
        requestId: requestId,
        payload: {'ok': false, 'error': error},
      ),
    );
  }
}
