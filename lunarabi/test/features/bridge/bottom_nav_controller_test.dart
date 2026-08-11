// =============================================================================
// BottomNavController のテスト
// =============================================================================
//
// ボトムナビの「表示」「アクティブ」「バッジ数字」は Web からブリッジ経由で
// 書き換えられる。UI を起動せず、状態だけを検証する。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';

void main() {
  test('visible / active / badge を更新できる', () {
    final nav = BottomNavController();

    expect(nav.visible, isTrue);
    expect(nav.active, NavTabId.home);
    expect(nav.badgeOf(NavTabId.notify), 0);

    nav.setVisible(false);
    nav.setActive(NavTabId.notify);
    nav.setBadge(NavTabId.notify, 3);

    expect(nav.visible, isFalse);
    expect(nav.active, NavTabId.notify);
    expect(nav.badgeOf(NavTabId.notify), 3);
  });

  test('負のバッジは 0 に丸める', () {
    final nav = BottomNavController();
    nav.setBadge(NavTabId.home, -5);
    expect(nav.badgeOf(NavTabId.home), 0);
  });

  test('wire id のパース', () {
    expect(NavTabIdX.tryParse('search'), NavTabId.search);
    expect(NavTabIdX.tryParse('unknown'), isNull);
  });
}
