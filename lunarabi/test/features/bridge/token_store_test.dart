// =============================================================================
// トークン Store のテスト
// =============================================================================
//
// Bearer / FCM トークンは生値をログに出さない。
// maskedForLog が末尾だけ残すことと、clear で消えることを確認する。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';

void main() {
  group('AuthTokenStore', () {
    test('set / get / clear とマスク', () {
      final store = AuthTokenStore();

      store.setToken('eyJhbGciOi-secret-token');
      expect(store.bearerToken, 'eyJhbGciOi-secret-token');
      // 生トークン全体がマスク文字列に含まれないこと
      expect(store.maskedForLog, isNot(contains('eyJhbGciOi-secret')));
      expect(store.maskedForLog.startsWith('***'), isTrue);

      store.clear();
      expect(store.bearerToken, isNull);
      expect(store.maskedForLog, '(empty)');
    });
  });

  group('PushTokenStore', () {
    test('listenable が更新される', () {
      final store = PushTokenStore();
      addTearDown(store.dispose);

      expect(store.token, isNull);
      store.setToken('fcm-token-abcdef');
      expect(store.listenable.value, 'fcm-token-abcdef');
      // keepTail 既定は末尾 4 文字
      expect(store.maskedForLog, '***cdef');
    });
  });
}
