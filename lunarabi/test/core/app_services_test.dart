import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/app_services.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

void main() {
  final config = AppConfig(
    flavor: Flavor.prod,
    webBaseUrl: Uri.parse('https://www.lunarabi.jp'),
    apiBaseUrl: Uri.parse('https://api.lunarabi.jp'),
    deepLinkHost: 'app.lunarabi.jp',
  );

  test('debug/profile payment backend stays fake for local flows', () {
    final backend = AppServices.createPaymentBackend(
      config: config,
      isRelease: false,
    );

    expect(backend, isA<FakePaymentBackendClient>());
  });

  test('release payment backend uses HTTP API client', () {
    final backend = AppServices.createPaymentBackend(
      config: config,
      isRelease: true,
    );

    expect(backend, isA<HttpPaymentBackendClient>());
  });
}
