import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/payments/iap_pending_store.dart';

void main() {
  group('SecureIapPendingStore', () {
    late SecureIapPendingStore store;

    setUp(() {
      FlutterSecureStorage.setMockInitialValues({});
      store = SecureIapPendingStore(storage: const FlutterSecureStorage());
    });

    test('upsert persists pending records by purchaseKey', () async {
      final updatedAt = DateTime.utc(2026, 8, 11, 1, 2, 3);
      final record = IapPendingRecord(
        purchaseKey: 'tx-1',
        purchaseId: 'tx-1',
        productId: 'lunarabi.credit.100',
        platform: 'google_play',
        verificationData: 'server-token',
        waitingConfirm: true,
        updatedAt: updatedAt,
      );

      await store.upsert(record);

      final restored = await store.getByKey('tx-1');
      expect(restored, isNotNull);
      expect(restored!.purchaseKey, 'tx-1');
      expect(restored.purchaseId, 'tx-1');
      expect(restored.productId, 'lunarabi.credit.100');
      expect(restored.platform, 'google_play');
      expect(restored.verificationData, 'server-token');
      expect(restored.waitingConfirm, isTrue);
      expect(restored.updatedAt, updatedAt);
    });

    test(
      'allWaiting excludes timed-out records and remove deletes by key',
      () async {
        final now = DateTime.utc(2026, 8, 11);
        await store.upsert(
          IapPendingRecord(
            purchaseKey: 'waiting',
            purchaseId: 'waiting',
            productId: 'lunarabi.credit.100',
            platform: 'google_play',
            verificationData: 'waiting-data',
            waitingConfirm: true,
            updatedAt: now,
          ),
        );
        await store.upsert(
          IapPendingRecord(
            purchaseKey: 'timed-out',
            purchaseId: 'timed-out',
            productId: 'lunarabi.credit.100',
            platform: 'google_play',
            verificationData: 'timed-out-data',
            waitingConfirm: false,
            status: IapPendingStatus.timedOut,
            updatedAt: now,
          ),
        );

        expect((await store.allWaiting()).map((r) => r.purchaseKey), [
          'waiting',
        ]);

        await store.remove('waiting');

        expect(await store.getByKey('waiting'), isNull);
        expect(await store.getByKey('timed-out'), isNotNull);
      },
    );
  });

  test(
    'purchaseKey prefers purchaseID and falls back to platform/product/receipt',
    () {
      expect(
        IapPendingRecord.purchaseKeyFor(
          purchaseId: 'tx-1',
          platform: 'google_play',
          productId: 'lunarabi.credit.100',
          verificationData: 'receipt',
        ),
        'tx-1',
      );
      expect(
        IapPendingRecord.purchaseKeyFor(
          purchaseId: null,
          platform: 'google_play',
          productId: 'lunarabi.credit.100',
          verificationData: 'receipt',
        ),
        'google_play:lunarabi.credit.100:receipt',
      );
    },
  );
}
