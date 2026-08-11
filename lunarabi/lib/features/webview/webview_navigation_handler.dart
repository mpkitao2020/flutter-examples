import 'package:flutter/foundation.dart';
import 'package:lunarabi/features/webview/webview_committed_url.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef WebViewLaunchUrl = Future<bool> Function(Uri uri, {LaunchMode mode});

class WebViewNavigationHandler {
  WebViewNavigationHandler({
    required this.policy,
    required this.committedUrl,
    required this.launchUrlFn,
  });

  final WebViewNavigationPolicy policy;
  final WebViewCommittedUrl committedUrl;
  final WebViewLaunchUrl launchUrlFn;

  Future<NavigationDecision> handleNavigationRequest(
    NavigationRequest request,
  ) async {
    if (!request.isMainFrame) {
      return NavigationDecision.navigate;
    }

    final uri = Uri.tryParse(request.url);
    if (uri == null || !uri.hasScheme) {
      committedUrl.clear();
      debugPrint('WebViewNavigationHandler: blocked uri=${request.url}');
      return NavigationDecision.prevent;
    }

    committedUrl.markNavigationStarted(uri);
    return switch (policy.decide(uri)) {
      WebViewNavAction.allow => NavigationDecision.navigate,
      WebViewNavAction.openExternal => _openExternal(uri),
      WebViewNavAction.block => _block(uri),
    };
  }

  Future<NavigationDecision> _openExternal(Uri uri) async {
    try {
      final launched = await launchUrlFn(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        debugPrint('WebViewNavigationHandler: failed to launch $uri');
      }
    } catch (error, stack) {
      debugPrint('WebViewNavigationHandler: launch failed $error');
      debugPrint('$stack');
    }
    return NavigationDecision.prevent;
  }

  NavigationDecision _block(Uri uri) {
    debugPrint('WebViewNavigationHandler: blocked uri=$uri');
    return NavigationDecision.prevent;
  }
}
