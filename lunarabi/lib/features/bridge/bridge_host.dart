import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/webview/trusted_bridge_origin.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef BridgeEmitter = Future<void> Function(BridgeMessage message);
typedef BridgeBootstrapGuard = bool Function();
typedef BridgeReadyCallback = FutureOr<void> Function();
typedef BridgeMessageHandler = FutureOr<void> Function(BridgeMessage message);

/// Bidirectional bridge between WebView JS and Flutter.
class BridgeHost {
  BridgeHost({
    required this.nav,
    required this.authRepo,
    required this.push,
    required Uri? Function() committedWebUri,
    required Uri webBaseUrl,
    this._emitter,
    BridgeReadyCallback? onReady,
  }) : _committedWebUri = committedWebUri,
       _webBaseUrl = webBaseUrl {
    if (onReady != null) {
      _readyListeners.add(onReady);
    }
  }

  final BottomNavController nav;
  final AuthTokenRepository authRepo;
  final PushTokenStore push;
  Uri? Function() _committedWebUri;
  Uri _webBaseUrl;

  final _readyListeners = <BridgeReadyCallback>[];
  final _handlers = <String, BridgeMessageHandler>{};
  BridgeEmitter? _emitter;
  WebViewController? _controller;
  var _channelEnsured = false;

  static const channelName = 'LunarabiBridgeNative';

  bool get isAttached => _channelEnsured;

  bool get isCommittedWebUriTrusted =>
      isTrustedBridgeOrigin(_committedWebUri(), _webBaseUrl);

  void setEmitter(BridgeEmitter emitter) {
    _emitter = emitter;
  }

  void addReadyListener(BridgeReadyCallback listener) {
    _readyListeners.add(listener);
  }

  void removeReadyListener(BridgeReadyCallback listener) {
    _readyListeners.remove(listener);
  }

  void registerHandler(String typePrefix, BridgeMessageHandler handler) {
    _handlers[typePrefix] = handler;
  }

  void updateTrustedOrigin({
    required Uri? Function() committedWebUri,
    required Uri webBaseUrl,
  }) {
    _committedWebUri = committedWebUri;
    _webBaseUrl = webBaseUrl;
  }

  Future<void> ensureChannel(WebViewController controller) async {
    _controller = controller;
    _emitter ??= _emitViaController;
    if (_channelEnsured) return;

    await controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) {
        // Fire-and-forget; errors are logged inside handleFromJs.
        handleFromJs(message.message);
      },
    );
    _channelEnsured = true;
  }

  Future<void> injectBootstrap({
    required String platform,
    BridgeBootstrapGuard? shouldContinue,
  }) async {
    final controller = _controller;
    if (controller == null) {
      debugPrint('BridgeHost: cannot inject bootstrap before ensureChannel');
      return;
    }
    if (!_shouldContinueBootstrap(shouldContinue)) {
      return;
    }
    await controller.runJavaScript(_bootstrapJs);
    if (!_shouldContinueBootstrap(shouldContinue)) {
      return;
    }
    await emitToJs(
      BridgeMessage(
        type: BridgeTypes.bridgeReady,
        payload: {'platform': platform},
      ),
    );
    if (!_shouldContinueBootstrap(shouldContinue)) {
      return;
    }
    await _notifyReadyListeners();
  }

  bool _shouldContinueBootstrap(BridgeBootstrapGuard? shouldContinue) {
    return shouldContinue == null || shouldContinue();
  }

  Future<void> _notifyReadyListeners() async {
    for (final listener in List<BridgeReadyCallback>.of(_readyListeners)) {
      await listener();
    }
  }

  Future<void> attach(
    WebViewController controller, {
    required String platform,
  }) async {
    await ensureChannel(controller);
    await injectBootstrap(platform: platform);
  }

  Future<void> emitToJs(BridgeMessage message) async {
    final emitter = _emitter;
    if (emitter == null) {
      debugPrint('BridgeHost: no emitter for ${message.type}');
      return;
    }
    await emitter(message);
  }

  Future<void> handleFromJs(String rawJson) async {
    try {
      final message = BridgeMessage.decode(rawJson);
      await _dispatch(message);
    } catch (error, stack) {
      debugPrint('BridgeHost: invalid message error=$error');
      debugPrint('$stack');
    }
  }

  Future<void> _dispatch(BridgeMessage message) async {
    final handler = _handlerFor(message.type);
    if (handler != null) {
      await handler(message);
      return;
    }

    switch (message.type) {
      case BridgeTypes.navSetVisible:
        final visible = message.payload['visible'];
        if (visible is! bool) {
          await _respondError(message, 'invalid_payload');
          return;
        }
        nav.setVisible(visible);
        return;
      case BridgeTypes.navSetBadge:
        final id = NavTabIdX.tryParse(message.payload['id'] as String?);
        final count = message.payload['count'];
        if (id == null || count is! num) {
          await _respondError(message, 'invalid_payload');
          return;
        }
        nav.setBadge(id, count.toInt());
        return;
      case BridgeTypes.navSetActive:
        final id = NavTabIdX.tryParse(message.payload['id'] as String?);
        if (id == null) {
          await _respondError(message, 'invalid_payload');
          return;
        }
        nav.setActive(id);
        return;
      case BridgeTypes.authSetBearerToken:
        if (!await _requireTrustedBridgeOrigin(message)) {
          return;
        }
        final token = message.payload['token'];
        if (token is! String || token.isEmpty) {
          await _respondError(message, 'invalid_payload');
          return;
        }
        await authRepo.save(token);
        debugPrint('BridgeHost: auth token set ${maskSecret(token)}');
        return;
      case BridgeTypes.authClearBearerToken:
        if (!await _requireTrustedBridgeOrigin(message)) {
          return;
        }
        await authRepo.clear();
        debugPrint('BridgeHost: auth token cleared');
        return;
      case BridgeTypes.authGetStoredToken:
        if (!await _requireTrustedBridgeOrigin(message)) {
          return;
        }
        await _respondOk(message, {'token': await authRepo.read()});
        return;
      case BridgeTypes.authGetBearerToken:
        if (!await _requireTrustedBridgeOrigin(message)) {
          return;
        }
        await _respondError(message, 'forbidden');
        return;
      case BridgeTypes.pushGetToken:
        await _respondOk(message, {'token': push.token});
        return;
      default:
        await _respondError(message, 'unknown_type');
    }
  }

  BridgeMessageHandler? _handlerFor(String type) {
    for (final entry in _handlers.entries) {
      if (type.startsWith(entry.key)) {
        return entry.value;
      }
    }
    return null;
  }

  Future<void> notifyTabSelected(NavTabId id) {
    return emitToJs(
      BridgeMessage(
        type: BridgeTypes.navTabSelected,
        payload: {'id': id.wireId},
      ),
    );
  }

  Future<void> notifyPushToken(String token, {required String platform}) {
    push.setToken(token);
    return emitToJs(
      BridgeMessage(
        type: BridgeTypes.pushSetToken,
        payload: {'token': token, 'platform': platform},
      ),
    );
  }

  Future<bool> _requireTrustedBridgeOrigin(BridgeMessage request) async {
    if (isTrustedBridgeOrigin(_committedWebUri(), _webBaseUrl)) {
      return true;
    }
    await _respondError(request, 'forbidden_origin');
    return false;
  }

  Future<void> _respondOk(BridgeMessage request, Map<String, dynamic> payload) {
    final requestId = request.requestId;
    if (requestId == null) return Future.value();
    return emitToJs(
      BridgeMessage(
        type: BridgeTypes.bridgeResponse,
        requestId: requestId,
        payload: {'ok': true, ...payload},
      ),
    );
  }

  Future<void> _respondError(BridgeMessage request, String error) {
    final requestId = request.requestId;
    if (requestId == null) return Future.value();
    return emitToJs(
      BridgeMessage(
        type: BridgeTypes.bridgeResponse,
        requestId: requestId,
        payload: {'ok': false, 'error': error},
      ),
    );
  }

  Future<void> _emitViaController(BridgeMessage message) async {
    final controller = _controller;
    if (controller == null) return;
    final encoded = jsonEncode(message.toJson());
    // Pass JSON as a JS object literal via JSON.parse for safety.
    final script =
        'window.__LUNARABI_NATIVE_EVENT__ && window.__LUNARABI_NATIVE_EVENT__(JSON.parse(${jsonEncode(encoded)}));';
    await controller.runJavaScript(script);
  }

  static String get _bootstrapJs => '''
(function() {
  if (!window.__LUNARABI_NATIVE_EVENT__) {
    window.__LUNARABI_NATIVE_EVENT__ = function(msg) {};
  }
  window.LunarabiBridge = {
    post: function(msg) {
      try {
        LunarabiBridgeNative.postMessage(JSON.stringify(msg));
      } catch (e) {
        console.error('[LunarabiBridge] post failed', e);
      }
    }
  };
})();
''';
}
