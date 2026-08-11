import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:webview_flutter/webview_flutter.dart';

typedef BridgeEmitter = Future<void> Function(BridgeMessage message);

/// Bidirectional bridge between WebView JS and Flutter.
class BridgeHost {
  BridgeHost({
    required this.nav,
    required this.auth,
    required this.push,
    this._emitter,
  });

  final BottomNavController nav;
  final AuthTokenStore auth;
  final PushTokenStore push;

  BridgeEmitter? _emitter;
  WebViewController? _controller;
  var _attached = false;

  static const channelName = 'LunarabiBridgeNative';

  bool get isAttached => _attached;

  void setEmitter(BridgeEmitter emitter) {
    _emitter = emitter;
  }

  Future<void> attach(WebViewController controller, {required String platform}) async {
    _controller = controller;
    _emitter ??= _emitViaController;

    await controller.addJavaScriptChannel(
      channelName,
      onMessageReceived: (message) {
        // Fire-and-forget; errors are logged inside handleFromJs.
        handleFromJs(message.message);
      },
    );

    await controller.runJavaScript(_bootstrapJs);
    _attached = true;

    await emitToJs(
      BridgeMessage(
        type: BridgeTypes.bridgeReady,
        payload: {'platform': platform},
      ),
    );

    // If a push token already exists, notify Web once.
    final existing = push.token;
    if (existing != null) {
      await emitToJs(
        BridgeMessage(
          type: BridgeTypes.pushSetToken,
          payload: {'token': existing},
        ),
      );
    }
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
        final token = message.payload['token'];
        if (token is! String || token.isEmpty) {
          await _respondError(message, 'invalid_payload');
          return;
        }
        auth.setToken(token);
        debugPrint('BridgeHost: auth token set ${auth.maskedForLog}');
        return;
      case BridgeTypes.authClearBearerToken:
        auth.clear();
        debugPrint('BridgeHost: auth token cleared');
        return;
      case BridgeTypes.authGetBearerToken:
        await _respondOk(message, {'token': auth.bearerToken});
        return;
      case BridgeTypes.pushGetToken:
        await _respondOk(message, {'token': push.token});
        return;
      default:
        await _respondError(message, 'unknown_type');
    }
  }

  Future<void> notifyTabSelected(NavTabId id) {
    return emitToJs(
      BridgeMessage(
        type: BridgeTypes.navTabSelected,
        payload: {'id': id.wireId},
      ),
    );
  }

  Future<void> notifyPushToken(String token) {
    push.setToken(token);
    return emitToJs(
      BridgeMessage(
        type: BridgeTypes.pushSetToken,
        payload: {'token': token},
      ),
    );
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
