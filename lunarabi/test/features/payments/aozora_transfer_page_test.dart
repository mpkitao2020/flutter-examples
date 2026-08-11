// =============================================================================
// あおぞら振込ページ（手動確認）
// =============================================================================
//
// - 1 回目 pending → メッセージ表示、navigator 未呼出し
// - 2 回目 success → /pay/done
// - failure → エラー表示、navigator 未呼出し
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/payments/aozora_transfer_page.dart';
import 'package:lunarabi/features/payments/payment_backend_client.dart';

class _FakeNavigator implements AppNavigator {
  final opened = <Uri>[];

  @override
  Future<void> openDeepLink(Uri uri) async => opened.add(uri);

  @override
  Future<void> openFromNotification(Uri uri) async => opened.add(uri);
}

class _ScriptedBackend extends FakePaymentBackendClient {
  _ScriptedBackend(this.results);

  final List<PaymentStatus> results;
  var _i = 0;
  var calls = 0;

  @override
  Future<PaymentStatus> checkBankTransfer({required String paymentId}) async {
    calls += 1;
    if (_i >= results.length) return PaymentStatus.failure;
    return results[_i++];
  }
}

void main() {
  final session = AozoraTransferSession(
    paymentId: 'aozora-1',
    accountDisplay: 'あおぞら銀行 999 支店 普通 1234567',
    expiresAt: DateTime.utc(2030, 1, 1),
  );
  final config = AppConfig.fromFlavor(Flavor.dev);

  Future<void> pumpPage(
    WidgetTester tester, {
    required PaymentBackendClient backend,
    required _FakeNavigator navigator,
  }) {
    return tester.pumpWidget(
      MaterialApp(
        home: AozoraTransferPage(
          session: session,
          backend: backend,
          navigator: navigator,
          config: config,
        ),
      ),
    );
  }

  testWidgets('pending → success で navigator を呼ぶ', (tester) async {
    final backend = _ScriptedBackend([
      PaymentStatus.pending,
      PaymentStatus.success,
    ]);
    final navigator = _FakeNavigator();
    await pumpPage(tester, backend: backend, navigator: navigator);

    expect(find.text(session.accountDisplay), findsOneWidget);

    await tester.tap(find.byKey(const Key('aozora-confirm-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(backend.calls, 1);
    expect(navigator.opened, isEmpty);
    expect(find.byKey(const Key('aozora-status-message')), findsOneWidget);

    await tester.tap(find.byKey(const Key('aozora-confirm-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(backend.calls, 2);
    expect(navigator.opened, hasLength(1));
    expect(navigator.opened.single.path, '/pay/done');
  });

  testWidgets('failure はエラー表示し navigator を呼ばない', (tester) async {
    final backend = _ScriptedBackend([PaymentStatus.failure]);
    final navigator = _FakeNavigator();
    await pumpPage(tester, backend: backend, navigator: navigator);

    await tester.tap(find.byKey(const Key('aozora-confirm-button')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(backend.calls, 1);
    expect(navigator.opened, isEmpty);
    expect(find.text('入金確認に失敗しました'), findsOneWidget);
  });
}
