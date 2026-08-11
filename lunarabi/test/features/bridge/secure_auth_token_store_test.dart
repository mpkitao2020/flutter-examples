import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/secure_auth_token_store.dart';

void main() {
  group('SecureAuthTokenStore', () {
    late SecureAuthTokenStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = SecureAuthTokenStore(storage: const FlutterSecureStorage());
    });

    test('save persists the bearer token under the app storage key', () async {
      await store.save('bearer-token-123');

      expect(await store.read(), 'bearer-token-123');
      expect(
        await const FlutterSecureStorage().read(
          key: SecureAuthTokenStore.storageKey,
        ),
        'bearer-token-123',
      );
    });

    test('read returns null when no bearer token has been saved', () async {
      expect(await store.read(), isNull);
    });

    test('clear removes the saved bearer token', () async {
      await store.save('bearer-token-123');

      await store.clear();

      expect(await store.read(), isNull);
    });
  });
}
