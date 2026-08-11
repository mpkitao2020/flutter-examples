// =============================================================================
// 初期リンクはプロセスで一度だけ
// =============================================================================

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_listener.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';
import 'package:lunarabi/features/payments/gmo_link_payment.dart';
import 'package:lunarabi/features/payments/handled_id_set.dart';
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
  test('sticky initial link を二度読んでも confirm は 1 回', () async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final backend = _RecordingBackend();
    final handled = HandledIdSet();
    final initialUri = Uri.parse(
      'https://app.lunarabi.example/pay/gmo/complete?paymentId=cold',
    );
    var initialReads = 0;

    Future<Uri?> stickyInitial() async {
      initialReads += 1;
      return initialUri;
    }

    addTearDown(bus.dispose);

    Future<void> startPair({required bool consumeInitial}) async {
      var coldHandled = false;
      final listener = DeepLinkListener(
        guard: HostGuard(config),
        bus: bus,
        navigator: navigator,
        getInitialLink: () async {
          if (!consumeInitial || coldHandled) return null;
          coldHandled = true;
          return stickyInitial();
        },
        uriLinkStream: const Stream<Uri>.empty(),
      );
      final gmo = GmoLinkPayment(
        backend: backend,
        bus: bus,
        navigator: navigator,
        config: config,
        handledPaymentIds: handled,
        launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async =>
            true,
      );
      await gmo.attachCompleter();
      await listener.start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
      await listener.dispose();
      await gmo.dispose();
    }

    // First boot consumes initial.
    await startPair(consumeInitial: true);
    // Flavor rebind must not re-read sticky initial (mirrors main.dart flag).
    await startPair(consumeInitial: false);

    expect(initialReads, 1);
    expect(backend.confirmed, ['cold']);
  });

  test('共有 HandledIdSet なら別 GMO インスタンスでも二重 confirm しない', () async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final backend = _RecordingBackend();
    final handled = HandledIdSet();
    addTearDown(bus.dispose);

    final first = GmoLinkPayment(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
      handledPaymentIds: handled,
      launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async =>
          true,
    );
    await first.attachCompleter();
    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse(
          'https://app.lunarabi.example/pay/gmo/complete?paymentId=shared',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await first.dispose();

    final second = GmoLinkPayment(
      backend: backend,
      bus: bus,
      navigator: navigator,
      config: config,
      handledPaymentIds: handled,
      launchUrlFn: (url, {LaunchMode mode = LaunchMode.externalApplication}) async =>
          true,
    );
    await second.attachCompleter();
    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse(
          'https://app.lunarabi.example/pay/gmo/complete?paymentId=shared',
        ),
      ),
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    await second.dispose();

    expect(backend.confirmed, ['shared']);
  });
}
