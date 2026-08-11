import 'package:lunarabi/core/navigation/app_navigator.dart';

enum DeepLinkKind { webPath, gmoComplete, unknown }

class ParsedDeepLink {
  const ParsedDeepLink({required this.kind, required this.uri});

  final DeepLinkKind kind;
  final Uri uri;
}

ParsedDeepLink parseDeepLink(Uri uri, HostGuard guard) {
  if (!guard.isAllowed(uri)) {
    return ParsedDeepLink(kind: DeepLinkKind.unknown, uri: uri);
  }
  if (uri.path == '/pay/gmo/complete') {
    return ParsedDeepLink(kind: DeepLinkKind.gmoComplete, uri: uri);
  }
  return ParsedDeepLink(kind: DeepLinkKind.webPath, uri: uri);
}
