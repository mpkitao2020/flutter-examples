import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/payments/iap_purchase_service.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

/// Process-wide services shared across features (bridge / deeplink / push / payments).
class AppServices {
  AppServices._();

  static final deepLinkBus = DeepLinkBus();
  static final navController = BottomNavController();
  static final authTokenStore = AuthTokenStore();
  static final pushTokenStore = PushTokenStore();
  static final bridgeHost = BridgeHost(
    nav: navController,
    auth: authTokenStore,
    push: pushTokenStore,
  );
  /// Scaffold default. Replace with a real HTTP client before production release.
  /// Fake confirms are no-ops; UI may still navigate to `/pay/done`.
  static final PaymentBackendClient paymentBackend = FakePaymentBackendClient();
  static final iapPurchaseService = IapPurchaseService();
}
