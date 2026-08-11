// =============================================================================
// フロント契約との type 面の同期テスト
// =============================================================================
//
// docs/superpowers/frontend/2026-08-11-lunarabi-webview-bridge-contract.md
// に載っている type 文字列と、Dart の BridgeTypes.all が一致していること。
// 契約に type を足したら、ここも更新する。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';

void main() {
  test('BridgeTypes.all がフロント契約の type 一式と一致する', () {
    // 契約書 § の type 一覧（変更時は契約書と両方直す）
    const fromContract = <String>{
      'nav.setVisible',
      'nav.setBadge',
      'nav.setActive',
      'nav.tabSelected',
      'auth.setBearerToken',
      'auth.clearBearerToken',
      'auth.getStoredToken',
      'push.setToken',
      'push.getToken',
      'bridge.ready',
      'bridge.response',
    };

    expect(BridgeTypes.all, fromContract);
  });
}
