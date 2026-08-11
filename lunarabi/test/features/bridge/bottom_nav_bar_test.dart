// =============================================================================
// ボトムナビ Widget のスモーク
// =============================================================================
//
// WebView は乗せない。NavigationBar の表示／非表示とバッジだけ見る。
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/bottom_nav_bar.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';

void main() {
  testWidgets('visible=false でバーが消える', (tester) async {
    final nav = BottomNavController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LunarabiBottomNavBar(
            controller: nav,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.byType(NavigationBar), findsOneWidget);

    nav.setVisible(false);
    await tester.pump();

    expect(find.byType(NavigationBar), findsNothing);
  });

  testWidgets('バッジ数字が表示される', (tester) async {
    final nav = BottomNavController()..setBadge(NavTabId.notify, 3);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: LunarabiBottomNavBar(
            controller: nav,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    expect(find.text('3'), findsOneWidget);
  });
}
