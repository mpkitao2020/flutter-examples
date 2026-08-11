import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

/// Testable surface over [InAppPurchase].
abstract interface class IapStore {
  Future<bool> isAvailable();
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers);
  Stream<List<PurchaseDetails>> get purchaseStream;
  Future<bool> buyConsumable({required PurchaseParam purchaseParam});
  Future<void> completePurchase(PurchaseDetails purchase);
}

class PluginIapStore implements IapStore {
  PluginIapStore([InAppPurchase? instance])
      : _iap = instance ?? InAppPurchase.instance;

  final InAppPurchase _iap;

  @override
  Future<bool> isAvailable() => _iap.isAvailable();

  @override
  Future<ProductDetailsResponse> queryProductDetails(Set<String> identifiers) {
    return _iap.queryProductDetails(identifiers);
  }

  @override
  Stream<List<PurchaseDetails>> get purchaseStream => _iap.purchaseStream;

  @override
  Future<bool> buyConsumable({required PurchaseParam purchaseParam}) {
    return _iap.buyConsumable(purchaseParam: purchaseParam);
  }

  @override
  Future<void> completePurchase(PurchaseDetails purchase) {
    return _iap.completePurchase(purchase);
  }
}

/// Thin wrapper around store purchase for testability.
class IapPurchaseService {
  IapPurchaseService({
    IapStore? store,
    this.sourceOverride,
    this.buyTimeout = const Duration(minutes: 2),
  }) : _store = store ?? PluginIapStore();

  final IapStore _store;

  /// When set (tests), skips [defaultTargetPlatform] mapping.
  final String? sourceOverride;

  /// Caps how long [buy] waits for a terminal purchase event.
  final Duration buyTimeout;

  final Set<String> _handledPurchaseKeys = {};

  String _key(PurchaseDetails purchase) {
    return purchase.purchaseID ??
        '${purchase.productID}:${purchase.verificationData.serverVerificationData}:${purchase.status}';
  }

  Future<PaymentStatus> buy({
    required ProductRef product,
    required PaymentBackendClient backend,
  }) async {
    final available = await _store.isAvailable();
    if (!available) return PaymentStatus.failure;

    final response = await _store.queryProductDetails({product.id});
    if (response.productDetails.isEmpty) {
      debugPrint('IapPurchaseService: product not found ${product.id}');
      return PaymentStatus.failure;
    }

    final details = response.productDetails.first;
    final completer = Completer<PaymentStatus>();
    // Purchases observed before buyConsumable must not complete this session.
    final seenBeforeBuy = <String>{};
    var buyLaunched = false;

    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _store.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != product.id) continue;
        final key = _key(purchase);

        if (!buyLaunched) {
          // Only remember unfinished *purchased* txs so pending/canceled IDs
          // cannot poison a later purchased event with the same purchaseID.
          if (purchase.status == PurchaseStatus.purchased) {
            seenBeforeBuy.add(key);
            await _confirmPurchased(
              purchase: purchase,
              product: product,
              backend: backend,
            );
          }
          continue;
        }

        if (seenBeforeBuy.contains(key)) continue;

        switch (purchase.status) {
          case PurchaseStatus.purchased:
            if (completer.isCompleted) break;
            if (_handledPurchaseKeys.contains(key)) break;
            final ok = await _confirmPurchased(
              purchase: purchase,
              product: product,
              backend: backend,
            );
            if (!completer.isCompleted) {
              completer.complete(ok ? PaymentStatus.success : PaymentStatus.failure);
            }
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) {
              completer.complete(PaymentStatus.failure);
            }
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.restored:
            // Consumable: ignore restore path for this buy session.
            break;
        }
      }
    });

    // Drain any immediate backlog before accepting new buy events.
    await Future<void>.delayed(Duration.zero);
    buyLaunched = true;

    final started = await _store.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started && !completer.isCompleted) {
      await sub.cancel();
      return PaymentStatus.failure;
    }

    try {
      return await completer.future.timeout(
        buyTimeout,
        onTimeout: () => PaymentStatus.failure,
      );
    } finally {
      await sub.cancel();
    }
  }

  Future<bool> _confirmPurchased({
    required PurchaseDetails purchase,
    required ProductRef product,
    required PaymentBackendClient backend,
  }) async {
    final key = _key(purchase);
    if (_handledPurchaseKeys.contains(key)) return true;
    _handledPurchaseKeys.add(key);

    final source = sourceOverride ??
        (defaultTargetPlatform == TargetPlatform.iOS ? 'app_store' : 'google_play');
    try {
      await backend.confirmIap(
        productId: product.id,
        verificationData: purchase.verificationData.serverVerificationData,
        source: source,
      );
      await _store.completePurchase(purchase);
      return true;
    } catch (error, stack) {
      debugPrint('IapPurchaseService: confirm failed $error');
      debugPrint('$stack');
      _handledPurchaseKeys.remove(key);
      return false;
    }
  }
}
