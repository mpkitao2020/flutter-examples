// =============================================================================
// GmoCompleterLifecycle — dispose → attach 直列化
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';
import 'package:lunarabi/features/payments/gmo_completer_lifecycle.dart';
import 'package:lunarabi/features/payments/gmo_link_payment.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';
import 'package:url_launcher/url_launcher.dart';

class _FakeNavigator implements AppNavigator {
  final opened = <Uri>[];

  @override
  Future<void> openDeepLink(Uri uri) async => opened.add(uri);

  @override
  Future<void> openFromNotification(Uri uri) async => opened.add(uri);
}

class _RecordingBackend extends FakePaymentBackendClient {
  final confirmed = <String>[];

  @override
  Future<void> confirmGmo({required String paymentId}) async {
    confirmed.add(paymentId);
  }
}

GmoLinkPayment _gmo({
  required PaymentBackendClient backend,
  required DeepLinkBus bus,
  required AppNavigator navigator,
  required AppConfig config,
}) {
  return GmoLinkPayment(
    backend: backend,
    bus: bus,
    navigator: navigator,
    config: config,
    launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async =>
        true,
  );
}

void main() {
  test('連続 rebind でも confirm は最新 listener で 1 回', () async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final backend = _RecordingBackend();
    final lifecycle = GmoCompleterLifecycle();
    addTearDown(() async {
      await lifecycle.clear();
      await bus.dispose();
    });

    final first = _gmo(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
    );
    final second = _gmo(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
    );

    // Queue two rebinds without awaiting between them.
    lifecycle.rebind(first);
    lifecycle.rebind(second);
    await lifecycle.ready;

    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse(
          'https://app.lunarabi.example/pay/gmo/complete?paymentId=once',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(backend.confirmed, ['once']);
    expect(lifecycle.current, same(second));
  });
}
