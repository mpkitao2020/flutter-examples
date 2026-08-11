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
  }) : _store = store ?? PluginIapStore();

  final IapStore _store;

  /// When set (tests), skips [defaultTargetPlatform] mapping.
  final String? sourceOverride;

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
    late final StreamSubscription<List<PurchaseDetails>> sub;
    sub = _store.purchaseStream.listen((purchases) async {
      for (final purchase in purchases) {
        if (purchase.productID != product.id) continue;
        switch (purchase.status) {
          case PurchaseStatus.purchased:
            final source = sourceOverride ??
                (defaultTargetPlatform == TargetPlatform.iOS
                    ? 'app_store'
                    : 'google_play');
            await backend.confirmIap(
              productId: product.id,
              verificationData: purchase.verificationData.serverVerificationData,
              source: source,
            );
            await _store.completePurchase(purchase);
            if (!completer.isCompleted) {
              completer.complete(PaymentStatus.success);
            }
          case PurchaseStatus.error:
          case PurchaseStatus.canceled:
            if (!completer.isCompleted) {
              completer.complete(PaymentStatus.failure);
            }
          case PurchaseStatus.pending:
            break;
          case PurchaseStatus.restored:
            // Consumable: ignore restore path.
            break;
        }
      }
    });

    final started = await _store.buyConsumable(
      purchaseParam: PurchaseParam(productDetails: details),
    );
    if (!started && !completer.isCompleted) {
      await sub.cancel();
      return PaymentStatus.failure;
    }

    final result = await completer.future.timeout(
      const Duration(minutes: 2),
      onTimeout: () => PaymentStatus.failure,
    );
    await sub.cancel();
    return result;
  }
}
