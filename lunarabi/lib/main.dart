import 'package:app_links/app_links.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/app_services.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_listener.dart';
import 'package:lunarabi/features/push/notification_link_parser.dart';
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

class _LunarabiAppState extends State<LunarabiApp> {
  late AppConfig _config = widget.config;
  DeepLinkListener? _deepLinkListener;
  PushService? _pushService;
  var _pushStarted = false;

  void _switchFlavor(Flavor flavor) {
    setState(() => _config = _config.copyWithFlavor(flavor));
  }

  Future<void> _onNavigatorReady(
    AppNavigator navigator,
    HostGuard guard,
  ) async {
    await _deepLinkListener?.dispose();
    final listener = DeepLinkListener(
      guard: guard,
      bus: AppServices.deepLinkBus,
      navigator: navigator,
      appLinks: AppLinks(),
    );
    _deepLinkListener = listener;
    await listener.start();

    if (!_pushStarted) {
      _pushStarted = true;
      _pushService = PushService(
        navigator: navigator,
        guard: guard,
        backend: LoggingPushBackendClient(),
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
  void dispose() {
    _deepLinkListener?.dispose();
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
        authTokenStore: AppServices.authTokenStore,
        pushTokenStore: AppServices.pushTokenStore,
        bridgeHost: AppServices.bridgeHost,
      ),
    );
  }
}
