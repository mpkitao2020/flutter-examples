import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';
import 'package:lunarabi/features/payments/handled_id_set.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';
import 'package:url_launcher/url_launcher.dart';

class GmoLinkPayment {
  GmoLinkPayment({
    required this.backend,
    required this.bus,
    required this.navigator,
    required this.config,
    this.launchUrlFn = launchUrl,
    HandledIdSet? handledPaymentIds,
  }) : _handledPaymentIds = handledPaymentIds ?? HandledIdSet();

  final PaymentBackendClient backend;
  final DeepLinkBus bus;
  final AppNavigator navigator;
  final AppConfig config;
  final Future<bool> Function(Uri url, {LaunchMode mode}) launchUrlFn;
  final HandledIdSet _handledPaymentIds;

  StreamSubscription<ParsedDeepLink>? _sub;
  var _attached = false;

  Future<void> attachCompleter() async {
    if (_attached) return;
    _attached = true;
    _sub = bus.stream.listen((link) {
      unawaited(_onLink(link));
    });
  }

  Future<void> _onLink(ParsedDeepLink link) async {
    if (link.kind != DeepLinkKind.gmoComplete) return;
    final paymentId = link.uri.queryParameters['paymentId']?.trim();
    if (paymentId == null || paymentId.isEmpty) {
      debugPrint('GmoLinkPayment: missing paymentId');
      return;
    }
    if (_handledPaymentIds.contains(paymentId)) {
      debugPrint('GmoLinkPayment: duplicate paymentId=$paymentId');
      return;
    }
    _handledPaymentIds.add(paymentId);
    try {
      await backend.confirmGmo(paymentId: paymentId);
    } catch (error, stack) {
      _handledPaymentIds.remove(paymentId);
      debugPrint('GmoLinkPayment: confirm failed $error');
      debugPrint('$stack');
      return;
    }
    try {
      await navigator.openDeepLink(
        config.webBaseUrl.replace(path: '/pay/done'),
      );
    } catch (error, stack) {
      // Confirm already succeeded — keep paymentId handled to avoid re-confirm.
      debugPrint('GmoLinkPayment: navigate failed $error');
      debugPrint('$stack');
    }
  }

  /// Opens the external GMO checkout. Returns false if the URL could not launch.
  Future<bool> startCheckout({required String productId}) async {
    final session = await backend.createGmoLink(productId: productId);
    final launched = await launchUrlFn(
      session.checkoutUrl,
      mode: LaunchMode.externalApplication,
    );
    if (!launched) {
      debugPrint('GmoLinkPayment: failed to launch ${session.checkoutUrl}');
    }
    return launched;
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    _attached = false;
  }
}
