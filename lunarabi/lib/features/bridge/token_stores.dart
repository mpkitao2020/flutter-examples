import 'package:flutter/foundation.dart';

String maskSecret(String? value, {int keepTail = 4}) {
  if (value == null || value.isEmpty) return '(empty)';
  if (value.length <= keepTail) return '***';
  return '***${value.substring(value.length - keepTail)}';
}

abstract interface class AuthTokenRepository {
  Future<void> save(String token);
  Future<String?> read();
  Future<void> clear();
}

/// Legacy in-memory auth token cache used by the current bridge.
///
/// Use an [AuthTokenRepository] implementation for bearer tokens that must
/// survive process restarts.
class AuthTokenStore {
  String? _bearerToken;

  String? get bearerToken => _bearerToken;

  String get maskedForLog => maskSecret(_bearerToken);

  void setToken(String? token) {
    _bearerToken = (token == null || token.isEmpty) ? null : token;
  }

  void clear() => setToken(null);
}

class PushTokenStore {
  PushTokenStore() : listenable = ValueNotifier<String?>(null);

  final ValueNotifier<String?> listenable;

  String? get token => listenable.value;

  String get maskedForLog => maskSecret(token);

  void setToken(String? token) {
    final next = (token == null || token.isEmpty) ? null : token;
    if (listenable.value == next) return;
    listenable.value = next;
  }

  void dispose() => listenable.dispose();
}
