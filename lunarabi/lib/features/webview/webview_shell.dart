import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef NavigatorReady = void Function(AppNavigator navigator, HostGuard guard);

class WebViewShell extends StatefulWidget {
  const WebViewShell({
    super.key,
    required this.config,
    this.onSwitchFlavor,
    this.onNavigatorReady,
  });

  final AppConfig config;
  final ValueChanged<Flavor>? onSwitchFlavor;
  final NavigatorReady? onNavigatorReady;

  @override
  State<WebViewShell> createState() => _WebViewShellState();
}

class _WebViewShellState extends State<WebViewShell> {
  late final WebViewController _controller;
  late HostGuard _guard;
  late WebViewAppNavigator _navigator;
  var _readyNotified = false;

  @override
  void initState() {
    super.initState();
    _guard = HostGuard(widget.config);
    _controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadRequest(widget.config.webBaseUrl);
    _navigator = WebViewAppNavigator(guard: _guard, controller: _controller);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_readyNotified) {
        _readyNotified = true;
        widget.onNavigatorReady?.call(_navigator, _guard);
      }
    });
  }

  @override
  void didUpdateWidget(covariant WebViewShell oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.flavor != widget.config.flavor) {
      _guard = HostGuard(widget.config);
      _navigator = WebViewAppNavigator(guard: _guard, controller: _controller);
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
    );
  }
}
