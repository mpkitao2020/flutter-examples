// =============================================================================
// PaymentSheet のラベル
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/payments/payment_models.dart';
import 'package:lunarabi/features/payments/payment_sheet.dart';

void main() {
  testWidgets(
    'Web-started IAP only leaves external payment methods in the sheet',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PaymentSheet(
              product: ProductRef(
                id: 'lunarabi.credit.100',
                displayName: 'Credit 100',
              ),
            ),
          ),
        ),
      );

      expect(find.text('Credit 100'), findsOneWidget);
      expect(find.text(PaymentSheet.storeLabel), findsNothing);
      expect(find.text(PaymentSheet.gmoLabel), findsOneWidget);
      expect(find.text(PaymentSheet.aozoraLabel), findsOneWidget);
    },
  );
}
