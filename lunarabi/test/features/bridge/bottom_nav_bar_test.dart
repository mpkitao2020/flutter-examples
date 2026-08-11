// =============================================================================
// ボトムナビ Widget のスモーク
// =============================================================================
//
// WebView は乗せない。NavigationBar の表示／非表示とバッジだけ見る。
// =============================================================================

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:lunarabi/features/bridge/bottom_nav_bar.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';

void main() {
  test('NavTabId と SVG asset path の対応が全タブ分ある', () {
    const expected = <NavTabId, String>{
      NavTabId.home: 'branding/nav/home.svg',
      NavTabId.search: 'branding/nav/search.svg',
      NavTabId.notify: 'branding/nav/notify.svg',
      NavTabId.account: 'branding/nav/account.svg',
    };

    expect(bottomNavIconAssetPaths, expected);
    expect(bottomNavIconAssetPaths.keys.toSet(), NavTabId.values.toSet());

    final pubspec = File('pubspec.yaml').readAsStringSync();
    for (final path in bottomNavIconAssetPaths.values) {
      expect(pubspec, contains('- $path'));
    }
  });

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

  testWidgets('ボトムナビは登録済み SVG asset を描画する', (tester) async {
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

    final assetNames = tester
        .widgetList<SvgPicture>(find.byType(SvgPicture))
        .map((picture) => (picture.bytesLoader as SvgAssetLoader).assetName)
        .toSet();

    expect(assetNames, containsAll(bottomNavIconAssetPaths.values));
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
