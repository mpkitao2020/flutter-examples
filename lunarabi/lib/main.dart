import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/app_services.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_listener.dart';
import 'package:lunarabi/features/payments/gmo_completer_lifecycle.dart';
import 'package:lunarabi/features/payments/gmo_link_payment.dart';
import 'package:lunarabi/features/payments/payment_coordinator.dart';
import 'package:lunarabi/features/push/push_service.dart';
import 'package:lunarabi/features/webview/webview_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native-only Firebase config (google-services.json / GoogleService-Info.plist).
  // Do not pass FirebaseOptions here.
  await Firebase.initializeApp();
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  const rawFlavor = String.fromEnvironment('FLAVOR');
  final flavor = parseFlavor(rawFlavor, isRelease: kReleaseMode);
  final config = AppConfig.fromFlavor(flavor);

  runApp(LunarabiApp(config: config));
}

class LunarabiApp extends StatefulWidget {
  const LunarabiApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<LunarabiApp> createState() => _LunarabiAppState();
}

class _LunarabiAppState extends State<LunarabiApp> with WidgetsBindingObserver {
  late AppConfig _config = widget.config;
  DeepLinkListener? _deepLinkListener;
  PushService? _pushService;
  PaymentCoordinator? _payments;
  final _gmoLifecycle = GmoCompleterLifecycle();
  var _pushStarted = false;
  var _coldStartLinkHandled = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  void _switchFlavor(Flavor flavor) {
    _payments = null;
    // Queue clear on the same chain so a later rebind cannot overlap.
    _gmoLifecycle.clear();
    setState(() => _config = _config.copyWithFlavor(flavor));
  }

  PaymentCoordinator _ensurePayments(AppNavigator navigator) {
    final existing = _payments;
    if (existing != null && identical(existing.config, _config)) {
      return existing;
    }
    final gmo = GmoLinkPayment(
      backend: AppServices.paymentBackend,
      bus: AppServices.deepLinkBus,
      navigator: navigator,
      config: _config,
      handledPaymentIds: AppServices.gmoHandledPaymentIds,
    );
    // Serialized dispose → attach (await via [_gmoLifecycle.ready]).
    _gmoLifecycle.rebind(gmo);
    final coordinator = PaymentCoordinator(
      backend: AppServices.paymentBackend,
      gmo: gmo,
      config: _config,
    );
    _payments = coordinator;
    return coordinator;
  }

  Future<void> _onNavigatorReady(
    AppNavigator navigator,
    HostGuard guard,
  ) async {
    await _deepLinkListener?.dispose();
    final appLinks = AppLinks();
    final listener = DeepLinkListener(
      guard: guard,
      bus: AppServices.deepLinkBus,
      navigator: navigator,
      // Sticky getInitialLink must only be consumed once per process.
      getInitialLink: () async {
        if (_coldStartLinkHandled) return null;
        _coldStartLinkHandled = true;
        return appLinks.getInitialLink();
      },
      appLinks: appLinks,
    );
    _deepLinkListener = listener;
    await listener.start();

    _ensurePayments(navigator);
    await _gmoLifecycle.ready;

    if (!_pushStarted) {
      _pushStarted = true;
      _pushService = PushService(
        navigator: navigator,
        guard: guard,
        bridgeHost: AppServices.bridgeHost,
      );
      try {
        await _pushService!.start();
      } catch (error, stack) {
        debugPrint('PushService start failed: $error');
        debugPrint('$stack');
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final controller = AppServices.iapBridgeController;
      if (controller != null) {
        unawaited(controller.onAppResumed());
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _deepLinkListener?.dispose();
    _pushService?.dispose();
    _gmoLifecycle.clear();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lunarabi',
      home: WebViewShell(
        config: _config,
        onSwitchFlavor: kReleaseMode ? null : _switchFlavor,
        onNavigatorReady: _onNavigatorReady,
        navController: AppServices.navController,
        authTokenRepository: AppServices.authTokenRepository,
        pushTokenStore: AppServices.pushTokenStore,
        bridgeHostFactory: AppServices.createBridgeHost,
      ),
    );
  }
}
