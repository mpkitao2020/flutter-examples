import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/bridge/bottom_nav_bar.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/secure_auth_token_store.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/webview/webview_committed_url.dart';
import 'package:lunarabi/features/webview/webview_navigation_handler.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef NavigatorReady = void Function(AppNavigator navigator, HostGuard guard);
typedef BridgeHostFactory =
    BridgeHost Function({
      required BottomNavController nav,
      required AuthTokenRepository authRepo,
      required PushTokenStore push,
      required Uri? Function() committedWebUri,
      required Uri webBaseUrl,
    });
typedef BridgeBootstrapInjector =
    void Function(WebViewCommittedUrlSnapshot snapshot);

enum WebViewSystemBackDecision { handledByWebView, allowRoutePop }

@visibleForTesting
bool shouldInjectBridgeBootstrap(WebViewCommittedUrl committedUrl) {
  return committedUrl.isTrusted;
}

@visibleForTesting
Future<WebViewSystemBackDecision> decideWebViewSystemBack({
  required Future<bool> Function() canGoBack,
  required Future<void> Function() goBack,
}) async {
  if (!await canGoBack()) {
    return WebViewSystemBackDecision.allowRoutePop;
  }

  await goBack();
  return WebViewSystemBackDecision.handledByWebView;
}

@visibleForTesting
Future<WebViewSystemBackDecision> handleWebViewSystemBack({
  required Future<bool> Function() canGoBack,
  required Future<void> Function() goBack,
  required Future<bool> Function() popRoute,
}) async {
  final decision = await decideWebViewSystemBack(
    canGoBack: canGoBack,
    goBack: goBack,
  );
  if (decision == WebViewSystemBackDecision.allowRoutePop) {
    await popRoute();
  }
  return decision;
}

@visibleForTesting
void handleWebViewShellPageFinished({
  required WebViewCommittedUrl committedUrl,
  required String url,
  required BridgeBootstrapInjector injectBootstrap,
}) {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    committedUrl.markPageFinished(uri);
  }
  final snapshot = committedUrl.trustedSnapshot;
  if (snapshot != null) {
    injectBootstrap(snapshot);
  }
}

Future<bool> _launchUrl(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(uri, mode: mode);
}

BridgeHost _createBridgeHost({
  required BottomNavController nav,
  required AuthTokenRepository authRepo,
  required PushTokenStore push,
  required Uri? Function() committedWebUri,
  required Uri webBaseUrl,
}) {
  return BridgeHost(
    nav: nav,
    authRepo: authRepo,
    push: push,
    committedWebUri: committedWebUri,
    webBaseUrl: webBaseUrl,
  );
}

class WebViewShell extends StatefulWidget {
  const WebViewShell({
    super.key,
    required this.config,
    this.onSwitchFlavor,
    this.onNavigatorReady,
    this.navController,
    this.authTokenRepository,
    this.pushTokenStore,
    this.bridgeHost,
    this.bridgeHostFactory = _createBridgeHost,
    this.launchUrlFn = _launchUrl,
  });

  final AppConfig config;
  final ValueChanged<Flavor>? onSwitchFlavor;
  final NavigatorReady? onNavigatorReady;
  final BottomNavController? navController;
  final AuthTokenRepository? authTokenRepository;
  final PushTokenStore? pushTokenStore;
  final BridgeHost? bridgeHost;
  final BridgeHostFactory bridgeHostFactory;
  final WebViewLaunchUrl launchUrlFn;

  @override
  State<WebViewShell> createState() => _WebViewShellState();
}

class _WebViewShellState extends State<WebViewShell> {
  late final WebViewController _controller;
  late HostGuard _guard;
  late WebViewAppNavigator _navigator;
  late WebViewCommittedUrl _committedUrl;
  late WebViewNavigationHandler _navigationHandler;
  late final BottomNavController _nav;
  late final AuthTokenRepository _authRepo;
  late final PushTokenStore _push;
  late final BridgeHost _bridge;
  var _readyNotified = false;
  var _routeCanPop = true;

  @override
  void initState() {
    super.initState();
    _nav = widget.navController ?? BottomNavController();
    _authRepo = widget.authTokenRepository ?? SecureAuthTokenStore();
    _push = widget.pushTokenStore ?? PushTokenStore();

    _configureNavigationState();
    _bridge = _createOrUseBridgeHost();
    _controller = WebViewController();
    _navigator = WebViewAppNavigator(guard: _guard, controller: _controller);
    unawaited(_configureControllerAndLoad());

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_readyNotified) {
        _readyNotified = true;
        widget.onNavigatorReady?.call(_navigator, _guard);
      }
    });
  }

  void _configureNavigationState() {
    _guard = HostGuard(widget.config);
    final policy = WebViewNavigationPolicy(_guard);
    _committedUrl = WebViewCommittedUrl(
      webBaseUrl: widget.config.webBaseUrl,
      policy: policy,
    );
    _navigationHandler = WebViewNavigationHandler(
      policy: policy,
      committedUrl: _committedUrl,
      launchUrlFn: widget.launchUrlFn,
    );
  }

  BridgeHost _createOrUseBridgeHost() {
    return widget.bridgeHost ??
        widget.bridgeHostFactory(
          nav: _nav,
          authRepo: _authRepo,
          push: _push,
          committedWebUri: () => _committedUrl.committedUri,
          webBaseUrl: widget.config.webBaseUrl,
        );
  }

  NavigationDelegate _buildNavigationDelegate() {
    return NavigationDelegate(
      onNavigationRequest: _navigationHandler.handleNavigationRequest,
      onPageStarted: _markPageStarted,
      onPageFinished: _markPageFinished,
    );
  }

  void _markPageStarted(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) {
      _committedUrl.clear();
      unawaited(_refreshRoutePopState());
      return;
    }
    _committedUrl.markPageStarted(uri);
    unawaited(_refreshRoutePopState());
  }

  void _markPageFinished(String url) {
    handleWebViewShellPageFinished(
      committedUrl: _committedUrl,
      url: url,
      injectBootstrap: (snapshot) =>
          unawaited(_injectBridgeBootstrap(snapshot)),
    );
    unawaited(_refreshRoutePopState());
  }

  Future<void> _refreshRoutePopState() async {
    final routeCanPop = !await _controller.canGoBack();
    if (!mounted || _routeCanPop == routeCanPop) {
      return;
    }
    setState(() => _routeCanPop = routeCanPop);
  }

  Future<void> _handleSystemBack() async {
    final navigator = Navigator.of(context);
    final decision = await handleWebViewSystemBack(
      canGoBack: _controller.canGoBack,
      goBack: _controller.goBack,
      popRoute: () => _popRouteOrExit(navigator),
    );

    if (!mounted) {
      return;
    }

    if (decision == WebViewSystemBackDecision.allowRoutePop) {
      return;
    }

    await _refreshRoutePopState();
  }

  Future<bool> _popRouteOrExit(NavigatorState navigator) async {
    if (!mounted) {
      return true;
    }

    if (!_routeCanPop) {
      setState(() => _routeCanPop = true);
      await WidgetsBinding.instance.endOfFrame;
      if (!mounted) {
        return true;
      }
    }

    if (await navigator.maybePop()) {
      return true;
    }

    await SystemNavigator.pop();
    return true;
  }

  Future<void> _configureControllerAndLoad() async {
    await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    await _controller.setNavigationDelegate(_buildNavigationDelegate());
    await _ensureBridgeChannel();
    await _controller.loadRequest(widget.config.webBaseUrl);
  }

  Future<void> _ensureBridgeChannel() async {
    try {
      await _bridge.ensureChannel(_controller);
    } catch (error, stack) {
      // Platform views / missing channel support in tests should not crash the shell.
      debugPrint('Bridge channel setup failed: $error');
      debugPrint('$stack');
    }
  }

  Future<void> _injectBridgeBootstrap(
    WebViewCommittedUrlSnapshot trustedSnapshot,
  ) async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    try {
      await _bridge.injectBootstrap(
        platform: platform,
        shouldContinue: () => _committedUrl.isCurrentTrusted(trustedSnapshot),
      );
    } catch (error, stack) {
      // Platform views / missing channel support in tests should not crash the shell.
      debugPrint('Bridge bootstrap inject failed: $error');
      debugPrint('$stack');
    }
  }

  @override
  void didUpdateWidget(covariant WebViewShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.flavor != widget.config.flavor ||
        oldWidget.launchUrlFn != widget.launchUrlFn) {
      _configureNavigationState();
      _bridge.updateTrustedOrigin(
        committedWebUri: () => _committedUrl.committedUri,
        webBaseUrl: widget.config.webBaseUrl,
      );
      _navigator = WebViewAppNavigator(guard: _guard, controller: _controller);
      unawaited(
        _reconfigureController(
          reload: oldWidget.config.flavor != widget.config.flavor,
        ),
      );
      widget.onNavigatorReady?.call(_navigator, _guard);
    }
  }

  Future<void> _reconfigureController({required bool reload}) async {
    await _controller.setNavigationDelegate(_buildNavigationDelegate());
    await _ensureBridgeChannel();
    if (reload) {
      await _controller.loadRequest(widget.config.webBaseUrl);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showEnv = !kReleaseMode && widget.onSwitchFlavor != null;

    return PopScope<void>(
      canPop: _routeCanPop,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        unawaited(_handleSystemBack());
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            showEnv ? 'Lunarabi (${widget.config.flavor.name})' : 'Lunarabi',
          ),
          actions: [
            if (showEnv)
              PopupMenuButton<Flavor>(
                tooltip: '環境切替',
                onSelected: widget.onSwitchFlavor,
                itemBuilder: (context) => [
                  for (final flavor in Flavor.values)
                    PopupMenuItem(value: flavor, child: Text(flavor.name)),
                ],
              ),
          ],
        ),
        body: WebViewWidget(controller: _controller),
        bottomNavigationBar: LunarabiBottomNavBar(
          controller: _nav,
          onSelect: (id) {
            _bridge.notifyTabSelected(id);
          },
        ),
      ),
    );
  }
}
