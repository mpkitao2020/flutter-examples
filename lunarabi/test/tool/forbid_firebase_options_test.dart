// =============================================================================
// FirebaseOptions 禁止ルールの回帰テスト
// =============================================================================
//
// このプロジェクトは Firebase 設定を「ネイティブファイルだけ」で持つ。
// FlutterFire CLI が生成する lib/firebase_options.dart を使うと、
// その方針が崩れるので、ここでソースを読んで禁止パターンが無いことを確認する。
//
// 【ポイント】
// - これは「アプリを起動するテスト」ではない
// - リポジトリ内の文字列を検査する、ポリシー用のテスト
// - CI でも `bash tool/forbid_firebase_options.sh` を別途走らせるとより堅い
// =============================================================================

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('lib 配下に Dart 製 FirebaseOptions を置かない', () {
    // Arrange: パッケージの lib ディレクトリを探す
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue, reason: 'lib/ が無いとアプリ自体が壊れている');

    // 禁止したい文字列一覧（仕様の「やってはいけないこと」）
    const forbidden = <String>[
      'firebase_options.dart',
      'DefaultFirebaseOptions',
      'Firebase.initializeApp(options:',
      'FirebaseOptions(',
    ];

    // Act: すべての .dart ファイルを読んで禁止語が無いか調べる
    final hits = <String>[];
    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final content = entity.readAsStringSync();
      for (final pattern in forbidden) {
        if (content.contains(pattern)) {
          hits.add('${entity.path}: $pattern');
        }
      }
    }

    // Assert: 1 件もヒットしてはいけない
    expect(hits, isEmpty, reason: '禁止パターンが見つかった: $hits');

    // ファイル自体の存在も禁止
    expect(File('lib/firebase_options.dart').existsSync(), isFalse);
  });
}
