import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/bridge/bottom_nav_bar.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/webview/webview_committed_url.dart';
import 'package:lunarabi/features/webview/webview_navigation_handler.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef NavigatorReady = void Function(AppNavigator navigator, HostGuard guard);

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
void handleWebViewShellPageFinished({
  required WebViewCommittedUrl committedUrl,
  required String url,
  required VoidCallback injectBootstrap,
}) {
  final uri = Uri.tryParse(url);
  if (uri != null) {
    committedUrl.markPageFinished(uri);
  }
  if (shouldInjectBridgeBootstrap(committedUrl)) {
    injectBootstrap();
  }
}

Future<bool> _launchUrl(
  Uri uri, {
  LaunchMode mode = LaunchMode.platformDefault,
}) {
  return launchUrl(uri, mode: mode);
}

class WebViewShell extends StatefulWidget {
  const WebViewShell({
    super.key,
    required this.config,
    this.onSwitchFlavor,
    this.onNavigatorReady,
    this.navController,
    this.authTokenStore,
    this.pushTokenStore,
    this.bridgeHost,
    this.launchUrlFn = _launchUrl,
  });

  final AppConfig config;
  final ValueChanged<Flavor>? onSwitchFlavor;
  final NavigatorReady? onNavigatorReady;
  final BottomNavController? navController;
  final AuthTokenStore? authTokenStore;
  final PushTokenStore? pushTokenStore;
  final BridgeHost? bridgeHost;
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
  late final AuthTokenStore _auth;
  late final PushTokenStore _push;
  late final BridgeHost _bridge;
  var _readyNotified = false;
  var _routeCanPop = true;

  @override
  void initState() {
    super.initState();
    _nav = widget.navController ?? BottomNavController();
    _auth = widget.authTokenStore ?? AuthTokenStore();
    _push = widget.pushTokenStore ?? PushTokenStore();
    _bridge =
        widget.bridgeHost ?? BridgeHost(nav: _nav, auth: _auth, push: _push);

    _configureNavigationState();
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
      injectBootstrap: () => unawaited(_injectBridgeBootstrap()),
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
    final decision = await decideWebViewSystemBack(
      canGoBack: _controller.canGoBack,
      goBack: _controller.goBack,
    );

    if (!mounted) {
      return;
    }

    if (decision == WebViewSystemBackDecision.allowRoutePop) {
      if (!_routeCanPop) {
        setState(() => _routeCanPop = true);
      }
      return;
    }

    await _refreshRoutePopState();
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

  Future<void> _injectBridgeBootstrap() async {
    final platform = defaultTargetPlatform == TargetPlatform.iOS
        ? 'ios'
        : 'android';
    try {
      await _bridge.injectBootstrap(platform: platform);
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
