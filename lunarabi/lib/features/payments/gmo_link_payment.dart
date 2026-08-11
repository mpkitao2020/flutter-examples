import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';
import 'package:url_launcher/url_launcher.dart';

class GmoLinkPayment {
  GmoLinkPayment({
    required this.backend,
    required this.bus,
    required this.navigator,
    required this.config,
    this.launchUrlFn = launchUrl,
  });

  final PaymentBackendClient backend;
  final DeepLinkBus bus;
  final AppNavigator navigator;
  final AppConfig config;
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFn;

  StreamSubscription<ParsedDeepLink>? _sub;
  var _attached = false;

  Future<void> attachCompleter() async {
    if (_attached) return;
    _attached = true;
    _sub = bus.stream.listen((link) async {
      if (link.kind != DeepLinkKind.gmoComplete) return;
      final paymentId = link.uri.queryParameters['paymentId'];
      if (paymentId == null || paymentId.isEmpty) {
        debugPrint('GmoLinkPayment: missing paymentId');
        return;
      }
      await backend.confirmGmo(paymentId: paymentId);
      await navigator.openDeepLink(
        config.webBaseUrl.replace(path: '/pay/done'),
      );
    });
  }

  Future<void> startCheckout({required String productId}) async {
    final session = await backend.createGmoLink(productId: productId);
    await launchUrlFn(
      session.checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
