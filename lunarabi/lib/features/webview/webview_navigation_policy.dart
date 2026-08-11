import 'package:lunarabi/core/navigation/app_navigator.dart';

enum WebViewNavAction { allow, openExternal, block }

class WebViewNavigationPolicy {
  WebViewNavigationPolicy(this.guard);

  final HostGuard guard;

  WebViewNavAction decide(Uri uri) {
    if (uri.scheme == 'https' && guard.isAllowed(uri)) {
      return WebViewNavAction.allow;
    }
    if (uri.scheme == 'http' ||
        uri.scheme == 'https' ||
        uri.scheme == 'mailto' ||
        uri.scheme == 'tel') {
      return WebViewNavAction.openExternal;
    }
    return WebViewNavAction.block;
  }
}
