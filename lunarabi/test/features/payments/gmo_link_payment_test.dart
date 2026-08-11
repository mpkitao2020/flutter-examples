// =============================================================================
// GMO リンク決済 + deeplink complete
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';
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

void main() {
  test('gmoComplete で confirm して /pay/done へ', () async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final backend = _RecordingBackend();
    final launched = <Uri>[];

    final gmo = GmoLinkPayment(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
      launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async {
        launched.add(url);
        return true;
      },
    );
    addTearDown(() async {
      await gmo.dispose();
      await bus.dispose();
    });

    await gmo.attachCompleter();
    await gmo.startCheckout(productId: 'lunarabi.credit.100');
    expect(launched, hasLength(1));

    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse(
          'https://app.lunarabi.example/pay/gmo/complete?paymentId=gmo-1',
        ),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.confirmed, ['gmo-1']);
    expect(navigator.opened.single.path, '/pay/done');
    expect(navigator.opened.single.host, config.webBaseUrl.host);
  });

  test('paymentId 欠落時は confirm / 遷移しない', () async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final backend = _RecordingBackend();

    final gmo = GmoLinkPayment(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
      launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async =>
          true,
    );
    addTearDown(() async {
      await gmo.dispose();
      await bus.dispose();
    });

    await gmo.attachCompleter();
    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse('https://app.lunarabi.example/pay/gmo/complete'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(backend.confirmed, isEmpty);
    expect(navigator.opened, isEmpty);
  });

  test('attach 前の bus イベントを replay する', () async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final backend = _RecordingBackend();

    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse(
          'https://app.lunarabi.example/pay/gmo/complete?paymentId=early',
        ),
      ),
    );

    final gmo = GmoLinkPayment(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
      launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async =>
          true,
    );
    addTearDown(() async {
      await gmo.dispose();
      await bus.dispose();
    });

    await gmo.attachCompleter();
    await Future<void>.delayed(Duration.zero);

    expect(backend.confirmed, ['early']);
    expect(navigator.opened, hasLength(1));
  });
}
