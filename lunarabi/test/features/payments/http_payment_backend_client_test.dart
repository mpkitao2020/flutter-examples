import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

void main() {
  HttpPaymentBackendClient clientFor(
    Future<http.Response> Function(http.Request request) handler,
  ) {
    return HttpPaymentBackendClient(
      apiBaseUrl: Uri.parse('https://api.lunarabi.jp'),
      httpClient: MockClient((request) async => handler(request)),
    );
  }

  test('listProducts reads products from the API', () async {
    final client = clientFor((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://api.lunarabi.jp/payments/products',
      );
      return http.Response(
        jsonEncode({
          'products': [
            {'id': 'lunarabi.credit.100', 'displayName': 'Credit 100'},
          ],
        }),
        200,
      );
    });

    final products = await client.listProducts();

    expect(products.single.id, 'lunarabi.credit.100');
    expect(products.single.displayName, 'Credit 100');
  });

  test('createGmoLink posts productId and parses checkout URL', () async {
    final client = clientFor((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.lunarabi.jp/payments/gmo/link',
      );
      expect(jsonDecode(request.body), {'productId': 'lunarabi.credit.100'});
      return http.Response(
        jsonEncode({
          'paymentId': 'gmo-1',
          'checkoutUrl': 'https://checkout.example.test/gmo-1',
        }),
        200,
      );
    });

    final session = await client.createGmoLink(
      productId: 'lunarabi.credit.100',
    );

    expect(session.paymentId, 'gmo-1');
    expect(
      session.checkoutUrl.toString(),
      'https://checkout.example.test/gmo-1',
    );
  });

  test('confirmGmo posts paymentId', () async {
    final client = clientFor((request) async {
      expect(request.method, 'POST');
      expect(
        request.url.toString(),
        'https://api.lunarabi.jp/payments/gmo/confirm',
      );
      expect(jsonDecode(request.body), {'paymentId': 'gmo-1'});
      return http.Response('', 204);
    });

    await client.confirmGmo(paymentId: 'gmo-1');
  });

  test(
    'createAozoraTransfer posts productId and parses transfer session',
    () async {
      final expiresAt = DateTime.utc(2026, 8, 11, 12);
      final client = clientFor((request) async {
        expect(request.method, 'POST');
        expect(
          request.url.toString(),
          'https://api.lunarabi.jp/payments/aozora/transfers',
        );
        expect(jsonDecode(request.body), {'productId': 'lunarabi.credit.100'});
        return http.Response(
          jsonEncode({
            'paymentId': 'aozora-1',
            'accountDisplay': 'あおぞら銀行 999 支店 普通 1234567',
            'expiresAt': expiresAt.toIso8601String(),
          }),
          200,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      });

      final session = await client.createAozoraTransfer(
        productId: 'lunarabi.credit.100',
      );

      expect(session.paymentId, 'aozora-1');
      expect(session.accountDisplay, contains('あおぞら銀行'));
      expect(session.expiresAt, expiresAt);
    },
  );

  test('checkBankTransfer maps API status values', () async {
    final client = clientFor((request) async {
      expect(request.method, 'GET');
      expect(
        request.url.toString(),
        'https://api.lunarabi.jp/payments/bank-transfers/aozora-1',
      );
      return http.Response(jsonEncode({'status': 'success'}), 200);
    });

    expect(
      await client.checkBankTransfer(paymentId: 'aozora-1'),
      PaymentStatus.success,
    );
  });

  test(
    'confirmIap is unsupported because release IAP verify stays on the Web bridge',
    () {
      final client = clientFor((request) async => http.Response('', 500));

      expect(
        () => client.confirmIap(
          productId: 'lunarabi.credit.100',
          verificationData: 'receipt',
          source: 'app_store',
        ),
        throwsUnsupportedError,
      );
    },
  );

  test('non-success HTTP responses fail closed', () async {
    final client = clientFor((request) async => http.Response('nope', 500));

    expect(client.listProducts, throwsStateError);
  });
}
