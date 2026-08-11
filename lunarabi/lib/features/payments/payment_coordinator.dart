import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/payments/aozora_transfer_page.dart';
import 'package:lunarabi/features/payments/gmo_link_payment.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';
import 'package:lunarabi/features/payments/payment_sheet.dart';

/// Opens the payment sheet and routes to IAP / GMO / Aozora.
class PaymentCoordinator {
  PaymentCoordinator({
    required this.backend,
    required this.iap,
    required this.gmo,
    required this.config,
  });

  final PaymentBackendClient backend;
  final IapPurchaseService iap;
  final GmoLinkPayment gmo;
  final AppConfig config;

  Future<void> openPurchase(
    BuildContext context, {
    required AppNavigator navigator,
  }) async {
    final products = await backend.listProducts();
    if (products.isEmpty) {
      debugPrint('PaymentCoordinator: no products');
      return;
    }
    if (!context.mounted) return;

    final product = products.first;
    final method = await showPaymentSheet(context, product: product);
    if (method == null || !context.mounted) return;

    switch (method) {
      case PaymentMethod.storeIap:
        final status = await iap.buy(product: product, backend: backend);
        if (!context.mounted) return;
        if (status == PaymentStatus.success) {
          await navigator.openDeepLink(
            config.webBaseUrl.replace(path: '/pay/done'),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('購入を完了できませんでした')),
          );
        }
      case PaymentMethod.gmoLink:
        final launched = await gmo.startCheckout(productId: product.id);
        if (!launched && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('決済ページを開けませんでした')),
          );
        }
      case PaymentMethod.aozoraTransfer:
        final session = await backend.createAozoraTransfer(
          productId: product.id,
        );
        if (!context.mounted) return;
        await Navigator.of(context).push<PaymentStatus>(
          MaterialPageRoute(
            builder: (_) => AozoraTransferPage(
              session: session,
              backend: backend,
              navigator: navigator,
              config: config,
            ),
          ),
        );
    }
  }
}
