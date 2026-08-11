import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:lunarabi/features/payments/payment_models.dart';

export 'package:lunarabi/features/payments/payment_models.dart';

abstract interface class PaymentBackendClient {
  Future<List<ProductRef>> listProducts();
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  });
  Future<GmoLinkSession> createGmoLink({required String productId});
  Future<void> confirmGmo({required String paymentId});
  Future<AozoraTransferSession> createAozoraTransfer({
    required String productId,
  });
  Future<PaymentStatus> checkBankTransfer({required String paymentId});
}

class FakePaymentBackendClient implements PaymentBackendClient {
  final Map<String, int> _bankChecks = {};
  var _gmoSeq = 0;
  var _aozoraSeq = 0;

  @override
  Future<List<ProductRef>> listProducts() async {
    return const [
      ProductRef(id: 'lunarabi.credit.100', displayName: 'Credit 100'),
    ];
  }

  @override
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  }) async {}

  @override
  Future<GmoLinkSession> createGmoLink({required String productId}) async {
    _gmoSeq += 1;
    final paymentId = 'gmo-$_gmoSeq';
    return GmoLinkSession(
      paymentId: paymentId,
      checkoutUrl: Uri.parse(
        'https://app.lunarabi.example/mock-gmo-checkout?paymentId=$paymentId',
      ),
    );
  }

  @override
  Future<void> confirmGmo({required String paymentId}) async {}

  @override
  Future<AozoraTransferSession> createAozoraTransfer({
    required String productId,
  }) async {
    _aozoraSeq += 1;
    final paymentId = 'aozora-$_aozoraSeq';
    return AozoraTransferSession(
      paymentId: paymentId,
      accountDisplay: 'あおぞら銀行 999 支店 普通 1234567',
      expiresAt: DateTime.now().toUtc().add(const Duration(days: 3)),
    );
  }

  @override
  Future<PaymentStatus> checkBankTransfer({required String paymentId}) async {
    final n = (_bankChecks[paymentId] ?? 0) + 1;
    _bankChecks[paymentId] = n;
    return n >= 2 ? PaymentStatus.success : PaymentStatus.pending;
  }
}

class HttpPaymentBackendClient implements PaymentBackendClient {
  HttpPaymentBackendClient({required this.apiBaseUrl, http.Client? httpClient})
    : _http = httpClient ?? http.Client();

  final Uri apiBaseUrl;
  final http.Client _http;

  Uri _endpoint(String path) {
    final basePath = apiBaseUrl.path.endsWith('/')
        ? apiBaseUrl.path.substring(0, apiBaseUrl.path.length - 1)
        : apiBaseUrl.path;
    return apiBaseUrl.replace(path: '$basePath$path');
  }

  Map<String, String> get _jsonHeaders => const {
    'accept': 'application/json',
    'content-type': 'application/json',
  };

  Future<Object?> _getJson(String path) async {
    final url = _endpoint(path);
    final response = await _http.get(url, headers: _jsonHeaders);
    return _decodeJson(response, 'GET', url);
  }

  Future<Object?> _postJson(String path, Map<String, Object?> body) async {
    final url = _endpoint(path);
    final response = await _http.post(
      url,
      headers: _jsonHeaders,
      body: jsonEncode(body),
    );
    return _decodeJson(response, 'POST', url);
  }

  Object? _decodeJson(http.Response response, String method, Uri url) {
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Payment backend request failed: $method $url ${response.statusCode}',
      );
    }
    if (response.body.trim().isEmpty) return null;
    return jsonDecode(response.body) as Object?;
  }

  @override
  Future<List<ProductRef>> listProducts() async {
    final json = await _getJson('/payments/products');
    final products =
        (json as Map<String, Object?>)['products'] as List<Object?>;
    return [
      for (final product in products)
        ProductRef(
          id: (product as Map<String, Object?>)['id']! as String,
          displayName: product['displayName']! as String,
        ),
    ];
  }

  @override
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  }) async {
    throw UnsupportedError('IAP confirmation is handled by the Web bridge');
  }

  @override
  Future<GmoLinkSession> createGmoLink({required String productId}) async {
    final json =
        await _postJson('/payments/gmo/link', {'productId': productId})
            as Map<String, Object?>;
    return GmoLinkSession(
      paymentId: json['paymentId']! as String,
      checkoutUrl: Uri.parse(json['checkoutUrl']! as String),
    );
  }

  @override
  Future<void> confirmGmo({required String paymentId}) async {
    await _postJson('/payments/gmo/confirm', {'paymentId': paymentId});
  }

  @override
  Future<AozoraTransferSession> createAozoraTransfer({
    required String productId,
  }) async {
    final json =
        await _postJson('/payments/aozora/transfers', {'productId': productId})
            as Map<String, Object?>;
    return AozoraTransferSession(
      paymentId: json['paymentId']! as String,
      accountDisplay: json['accountDisplay']! as String,
      expiresAt: DateTime.parse(json['expiresAt']! as String),
    );
  }

  @override
  Future<PaymentStatus> checkBankTransfer({required String paymentId}) async {
    final json =
        await _getJson('/payments/bank-transfers/$paymentId')
            as Map<String, Object?>;
    return switch (json['status']) {
      'pending' => PaymentStatus.pending,
      'success' => PaymentStatus.success,
      'failure' => PaymentStatus.failure,
      _ => throw StateError('Unknown bank transfer status: ${json['status']}'),
    };
  }
}

/// Release default until a real HTTP client is wired.
///
/// Products are empty so the purchase sheet has nothing to sell; mutating
/// calls throw so a misconfigured release build cannot fake success.
class FailClosedPaymentBackendClient implements PaymentBackendClient {
  static const _message = 'PaymentBackendClient not configured';

  Never _fail() => throw StateError(_message);

  @override
  Future<List<ProductRef>> listProducts() async => const [];

  @override
  Future<void> confirmIap({
    required String productId,
    required String verificationData,
    required String source,
  }) async => _fail();

  @override
  Future<GmoLinkSession> createGmoLink({required String productId}) async =>
      _fail();

  @override
  Future<void> confirmGmo({required String paymentId}) async => _fail();

  @override
  Future<AozoraTransferSession> createAozoraTransfer({
    required String productId,
  }) async => _fail();

  @override
  Future<PaymentStatus> checkBankTransfer({required String paymentId}) async {
    return PaymentStatus.failure;
  }
}
