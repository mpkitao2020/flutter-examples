import 'package:lunarabi/features/webview/trusted_bridge_origin.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';

class WebViewCommittedUrl {
  WebViewCommittedUrl({required this.webBaseUrl, required this.policy});

  final Uri webBaseUrl;
  final WebViewNavigationPolicy policy;
  Uri? _committedUri;

  Uri? get committedUri => _committedUri;
  bool get isTrusted => isTrustedBridgeOrigin(_committedUri, webBaseUrl);

  void clear() {
    _committedUri = null;
  }

  void markNavigationStarted(Uri uri) {
    clear();
  }

  void markPageStarted(Uri uri) {
    clear();
  }

  void markPageFinished(Uri uri) {
    if (policy.decide(uri) == WebViewNavAction.allow) {
      _committedUri = uri;
    }
  }
}
