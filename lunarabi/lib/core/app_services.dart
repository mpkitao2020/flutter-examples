import 'package:flutter/foundation.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/secure_auth_token_store.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/payments/handled_id_set.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

/// Process-wide services shared across features (bridge / deeplink / push / payments).
class AppServices {
  AppServices._();

  static final deepLinkBus = DeepLinkBus();
  static final navController = BottomNavController();
  static final authTokenRepository = SecureAuthTokenStore();
  static final pushTokenStore = PushTokenStore();
  static BridgeHost? _bridgeHost;

  static BridgeHost get bridgeHost {
    final host = _bridgeHost;
    if (host == null) {
      throw StateError('BridgeHost has not been configured');
    }
    return host;
  }

  static BridgeHost createBridgeHost({
    required BottomNavController nav,
    required AuthTokenRepository authRepo,
    required PushTokenStore push,
    required Uri? Function() committedWebUri,
    required Uri webBaseUrl,
  }) {
    final host = BridgeHost(
      nav: nav,
      authRepo: authRepo,
      push: push,
      committedWebUri: committedWebUri,
      webBaseUrl: webBaseUrl,
    );
    _bridgeHost = host;
    return host;
  }

  /// Shared across GMO completer rebinds so cold-start paymentIds are not
  /// confirmed twice when the listener is recreated (e.g. flavor switch).
  static final gmoHandledPaymentIds = HandledIdSet();

  /// Fake in debug/profile for local flows; fail-closed in release until a
  /// real HTTP [PaymentBackendClient] is injected.
  static final PaymentBackendClient paymentBackend = kReleaseMode
      ? FailClosedPaymentBackendClient()
      : FakePaymentBackendClient();

  static final iapPurchaseService = IapPurchaseService();
}
