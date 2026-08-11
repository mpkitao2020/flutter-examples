import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/bridge/bottom_nav_bar.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef NavigatorReady = void Function(AppNavigator navigator, HostGuard guard);

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
  });

  final AppConfig config;
  final ValueChanged<Flavor>? onSwitchFlavor;
  final NavigatorReady? onNavigatorReady;
  final BottomNavController? navController;
  final AuthTokenStore? authTokenStore;
  final PushTokenStore? pushTokenStore;
  final BridgeHost? bridgeHost;

  @override
  State<WebViewShell> createState() => _WebViewShellState();
}

class _WebViewShellState extends State<WebViewShell> {
  late final WebViewController _controller;
  late HostGuard _guard;
  late WebViewAppNavigator _navigator;
  late final BottomNavController _nav;
  late final AuthTokenStore _auth;
  late final PushTokenStore _push;
  late final BridgeHost _bridge;
  var _readyNotified = false;
  var _bridgeAttached = false;

  @override
  void initState() {
    super.initState();
    _nav = widget.navController ?? BottomNavController();
    _auth = widget.authTokenStore ?? AuthTokenStore();
    _push = widget.pushTokenStore ?? PushTokenStore();
    _bridge = widget.bridgeHost ??
        BridgeHost(nav: _nav, auth: _auth, push: _push);

    _guard = HostGuard(widget.config);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageFinished: (_) => _ensureBridgeAttached(),
        ),
      )
      ..loadRequest(widget.config.webBaseUrl);
    _navigator = WebViewAppNavigator(guard: _guard, controller: _controller);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_readyNotified) {
        _readyNotified = true;
        widget.onNavigatorReady?.call(_navigator, _guard);
      }
    });
  }

  Future<void> _ensureBridgeAttached() async {
    if (_bridgeAttached) return;
    _bridgeAttached = true;
    final platform = defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
    try {
      await _bridge.attach(_controller, platform: platform);
    } catch (error, stack) {
      // Platform views / missing channel support in tests should not crash the shell.
      debugPrint('Bridge attach failed: $error');
      debugPrint('$stack');
      _bridgeAttached = false;
    }
  }

  @override
  void didUpdateWidget(covariant WebViewShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.flavor != widget.config.flavor) {
      _guard = HostGuard(widget.config);
      _navigator = WebViewAppNavigator(guard: _guard, controller: _controller);
      _bridgeAttached = false;
      _controller.loadRequest(widget.config.webBaseUrl);
      widget.onNavigatorReady?.call(_navigator, _guard);
    }
  }

  @override
  Widget build(BuildContext context) {
    final showEnv = !kReleaseMode && widget.onSwitchFlavor != null;

    return Scaffold(
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
                  PopupMenuItem(
                    value: flavor,
                    child: Text(flavor.name),
                  ),
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
    );
  }
}
