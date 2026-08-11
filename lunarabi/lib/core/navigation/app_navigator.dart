import 'package:flutter/foundation.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:webview_flutter/webview_flutter.dart';

/// Allowlist for HTTPS hosts that the app may open in the WebView.
class HostGuard {
  HostGuard(this.config);

  final AppConfig config;

  bool isAllowed(Uri uri) {
    return uri.scheme == 'https' &&
        (uri.host == config.deepLinkHost || uri.host == config.webBaseUrl.host);
  }

  /// Maps deep-link host URLs onto the env web base.
  /// Returns null when [uri] is not allowed.
  Uri? resolveForWebView(Uri uri) {
    if (!isAllowed(uri)) return null;
    if (uri.host == config.webBaseUrl.host) return uri;
    return config.webBaseUrl.replace(
      path: uri.path,
      query: uri.hasQuery ? uri.query : null,
      fragment: uri.hasFragment ? uri.fragment : null,
    );
  }
}

abstract interface class AppNavigator {
  Future<void> openDeepLink(Uri uri);
  Future<void> openFromNotification(Uri uri);
}

class WebViewAppNavigator implements AppNavigator {
  WebViewAppNavigator({
    required this.guard,
    required this.controller,
  });

  final HostGuard guard;
  final WebViewController controller;

  @override
  Future<void> openDeepLink(Uri uri) => _open(uri);

  @override
  Future<void> openFromNotification(Uri uri) => _open(uri);

  Future<void> _open(Uri uri) async {
    final target = guard.resolveForWebView(uri);
    if (target == null) {
      debugPrint('AppNavigator: blocked uri=$uri');
      return;
    }
    await controller.loadRequest(target);
  }
}
