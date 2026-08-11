import 'package:flutter/material.dart';
import 'package:lunarabi/features/payments/payment_models.dart';

/// Bottom sheet that lists one product and three payment methods.
Future<PaymentMethod?> showPaymentSheet(
  BuildContext context, {
  required ProductRef product,
}) {
  return showModalBottomSheet<PaymentMethod>(
    context: context,
    builder: (context) => PaymentSheet(product: product),
  );
}

class PaymentSheet extends StatelessWidget {
  const PaymentSheet({super.key, required this.product});

  final ProductRef product;

  static const storeLabel = 'ストアで購入';
  static const gmoLabel = 'クレジットカード (GMO)';
  static const aozoraLabel = '銀行振込 (あおぞら)';

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(product.displayName, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(product.id, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 16),
            ListTile(
              title: const Text(storeLabel),
              onTap: () => Navigator.pop(context, PaymentMethod.storeIap),
            ),
            ListTile(
              title: const Text(gmoLabel),
              onTap: () => Navigator.pop(context, PaymentMethod.gmoLink),
            ),
            ListTile(
              title: const Text(aozoraLabel),
              onTap: () => Navigator.pop(context, PaymentMethod.aozoraTransfer),
            ),
          ],
        ),
      ),
    );
  }
}
