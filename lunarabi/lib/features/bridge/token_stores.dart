import 'package:flutter/foundation.dart';

String maskSecret(String? value, {int keepTail = 4}) {
  if (value == null || value.isEmpty) return '(empty)';
  if (value.length <= keepTail) return '***';
  return '***${value.substring(value.length - keepTail)}';
}

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
