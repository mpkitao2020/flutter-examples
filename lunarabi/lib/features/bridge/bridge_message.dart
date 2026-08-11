import 'dart:convert';

/// Message types shared with the Web frontend contract.
abstract final class BridgeTypes {
  static const navSetVisible = 'nav.setVisible';
  static const navSetBadge = 'nav.setBadge';
  static const navSetActive = 'nav.setActive';
  static const navTabSelected = 'nav.tabSelected';
  static const authSetBearerToken = 'auth.setBearerToken';
  static const authClearBearerToken = 'auth.clearBearerToken';
  static const authGetStoredToken = 'auth.getStoredToken';
  // Legacy command kept only so BridgeHost can return a deliberate forbidden
  // response instead of leaking through an unknown-type fallback.
  static const authGetBearerToken = 'auth.getBearerToken';
  static const pushSetToken = 'push.setToken';
  static const pushGetToken = 'push.getToken';
  static const bridgeReady = 'bridge.ready';
  static const bridgeResponse = 'bridge.response';

  /// All types that appear in the frontend contract (lock surface).
  static const all = <String>{
    navSetVisible,
    navSetBadge,
    navSetActive,
    navTabSelected,
    authSetBearerToken,
    authClearBearerToken,
    authGetStoredToken,
    pushSetToken,
    pushGetToken,
    bridgeReady,
    bridgeResponse,
  };
}

class BridgeMessage {
  const BridgeMessage({
    required this.type,
    required this.payload,
    this.requestId,
  });

  final String type;
  final Map<String, dynamic> payload;
  final String? requestId;

  Map<String, dynamic> toJson() {
    return <String, dynamic>{
      'type': type,
      'payload': payload,
      if (requestId != null) 'requestId': requestId,
    };
  }

  static BridgeMessage fromJson(Map<String, dynamic> json) {
    final type = json['type'];
    if (type is! String || type.isEmpty) {
      throw FormatException('BridgeMessage.type must be a non-empty String');
    }
    final rawPayload = json['payload'];
    final payload = rawPayload is Map
        ? Map<String, dynamic>.from(rawPayload)
        : <String, dynamic>{};
    final requestId = json['requestId'];
    return BridgeMessage(
      type: type,
      payload: payload,
      requestId: requestId is String ? requestId : null,
    );
  }

  static BridgeMessage decode(String raw) {
    final value = jsonDecode(raw);
    if (value is! Map) {
      throw FormatException('Bridge message root must be a JSON object');
    }
    return BridgeMessage.fromJson(Map<String, dynamic>.from(value));
  }

  String encode() => jsonEncode(toJson());
}
