import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';

typedef InitialLinkGetter = Future<Uri?> Function();

class DeepLinkListener {
  DeepLinkListener({
    required this.guard,
    required this.bus,
    required this.navigator,
    InitialLinkGetter? getInitialLink,
    Stream<Uri>? uriLinkStream,
    AppLinks? appLinks,
  })  : _getInitialLink = getInitialLink,
        _uriLinkStream = uriLinkStream,
        _appLinks = appLinks;

  final HostGuard guard;
  final DeepLinkBus bus;
  final AppNavigator navigator;
  final InitialLinkGetter? _getInitialLink;
  final Stream<Uri>? _uriLinkStream;
  final AppLinks? _appLinks;

  StreamSubscription<Uri>? _sub;
  var _started = false;

  Future<void> start() async {
    if (_started) return;
    _started = true;

    final initial = await _resolveInitial();
    if (initial != null) {
      await _handle(initial);
    }

    final stream = _uriLinkStream ?? _appLinks?.uriLinkStream;
    if (stream != null) {
      _sub = stream.listen(
        (uri) {
          unawaited(_handle(uri));
        },
        onError: (Object error, StackTrace stack) {
          debugPrint('DeepLinkListener stream error: $error');
          debugPrint('$stack');
        },
      );
    }
  }

  Future<Uri?> _resolveInitial() async {
    if (_getInitialLink != null) return _getInitialLink!();
    return _appLinks?.getInitialLink();
  }

  Future<void> _handle(Uri uri) async {
    final parsed = parseDeepLink(uri, guard);
    bus.publish(parsed);
    switch (parsed.kind) {
      case DeepLinkKind.webPath:
        await navigator.openDeepLink(parsed.uri);
        return;
      case DeepLinkKind.gmoComplete:
        // Payments listens on the bus; do not navigate here.
        debugPrint('DeepLinkListener: gmoComplete ${parsed.uri}');
        return;
      case DeepLinkKind.unknown:
        debugPrint('DeepLinkListener: ignored ${parsed.uri}');
        return;
    }
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
  }
}
