import 'package:lunarabi/features/webview/trusted_bridge_origin.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';

class WebViewCommittedUrlSnapshot {
  const WebViewCommittedUrlSnapshot({
    required this.uri,
    required this.generation,
  });

  final Uri uri;
  final int generation;
}

class WebViewCommittedUrl {
  WebViewCommittedUrl({required this.webBaseUrl, required this.policy});

  final Uri webBaseUrl;
  final WebViewNavigationPolicy policy;
  Uri? _committedUri;
  var _generation = 0;

  Uri? get committedUri => _committedUri;
  int get generation => _generation;
  bool get isTrusted => isTrustedBridgeOrigin(_committedUri, webBaseUrl);
  WebViewCommittedUrlSnapshot? get trustedSnapshot {
    final uri = _committedUri;
    if (uri == null || !isTrusted) {
      return null;
    }
    return WebViewCommittedUrlSnapshot(uri: uri, generation: _generation);
  }

  bool isCurrentTrusted(WebViewCommittedUrlSnapshot snapshot) {
    return _generation == snapshot.generation &&
        _committedUri == snapshot.uri &&
        isTrustedBridgeOrigin(_committedUri, webBaseUrl);
  }

  void clear() {
    _committedUri = null;
    _generation += 1;
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
      _generation += 1;
    }
  }
}
