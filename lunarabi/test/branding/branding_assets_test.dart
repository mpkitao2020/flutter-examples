// =============================================================================
// ブランディング成果物の存在チェック
// =============================================================================
//
// 画像そのものの見た目は自動テストしにくいので、
// 「必要なファイルがリポジトリにあるか」だけを確認する。
// 差し替え後も同じパスを保てば、このテストは通ったままになる。
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const navIconPaths = <String>[
    'branding/nav/home.svg',
    'branding/nav/search.svg',
    'branding/nav/notify.svg',
    'branding/nav/account.svg',
  ];

  test('ソース画像と生成物の主要パスが存在する', () {
    // Arrange: 確認したいパス一覧
    const requiredPaths = <String>[
      // 差し替え元（人が触るファイル）
      'branding/app_icon.png',
      'branding/splash.png',
      'branding/splash_dark.png',
      'branding/notification_icon.png',
      'branding/README.md',
      ...navIconPaths,
      // Android アプリアイコン（flutter_launcher_icons が生成）
      'android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png',
      // Android 通知アイコン（白単色）
      'android/app/src/main/res/drawable/ic_stat_lunarabi.png',
      // iOS アプリアイコン
      'ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json',
    ];

    // Act / Assert: 1 つでも欠けていたら失敗し、どれが無いか分かるようにする
    final missing = <String>[
      for (final path in requiredPaths)
        if (!File(path).existsSync()) path,
    ];

    expect(missing, isEmpty, reason: '不足ファイル: $missing');
  });

  test('pubspec にボトムナビ SVG が asset 登録されている', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();

    for (final path in navIconPaths) {
      expect(pubspec, contains('- $path'));
    }
  });

  test('AndroidManifest に通知アイコンの meta-data がある', () {
    final manifest = File('android/app/src/main/AndroidManifest.xml').readAsStringSync();

    // FCM がステータスバーで使う小さいアイコンを指定していること
    expect(manifest.contains('default_notification_icon'), isTrue);
    expect(manifest.contains('@drawable/ic_stat_lunarabi'), isTrue);
  });
}
