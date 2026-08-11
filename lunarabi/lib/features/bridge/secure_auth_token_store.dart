import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';

class SecureAuthTokenStore implements AuthTokenRepository {
  SecureAuthTokenStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static const storageKey = 'lunarabi.sanctum.bearer';

  final FlutterSecureStorage _storage;

  @override
  Future<void> save(String token) {
    return _storage.write(key: storageKey, value: token);
  }

  @override
  Future<String?> read() {
    return _storage.read(key: storageKey);
  }

  @override
  Future<void> clear() {
    return _storage.delete(key: storageKey);
  }
}
