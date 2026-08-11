// =============================================================================
// AppConfig の単体テスト
// =============================================================================
//
// 【このファイルの読み方】（テストを書いたことがない人向け）
//
// 1. `void main()` … テストの入口。`flutter test` はこの関数から実行する。
// 2. `test('名前', () { ... })` … 1 つの確認項目。名前は「何を保証するか」を書く。
// 3. `expect(実際の値, 期待する値)` … 左右が一致しなければテスト失敗。
//
// 【TDD（テスト駆動）の流れ】
//
//   RED   → まだ実装がない／仕様と違うので、まずテストを失敗させる
//   GREEN → 最小の本番コードを書いてテストを通す
//   REFACTOR → 通ったままコードをきれいにする
//
// このテストは「環境（dev/stg/prod）ごとの URL が仕様どおりか」と
// 「FLAVOR 未指定時のフォールバック」を固定するためのもの。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';

void main() {
  // group で関連テストをまとめると、失敗時のレポートが読みやすい。
  group('AppConfig.fromFlavor', () {
    test('dev は開発用の Web / API URL を返す', () {
      // Arrange（準備）: 検証したい入力を決める
      // Act（実行）: 本番コードを呼び出す
      final config = AppConfig.fromFlavor(Flavor.dev);

      // Assert（検証）: 仕様書どおりの URL になっているか確認する
      // toString() で文字列比較すると、スキーム・ホストの取りこぼしに気づきやすい。
      expect(config.webBaseUrl.toString(), 'https://dev.lunarabi.example');
      expect(config.apiBaseUrl.toString(), 'https://api-dev.lunarabi.example');

      // ディープリンク用ホストは全環境で共通（Universal Links のドメイン）
      expect(config.deepLinkHost, 'app.lunarabi.example');
      expect(config.flavor, Flavor.dev);
    });

    test('stg は検証用の Web / API URL を返す', () {
      final config = AppConfig.fromFlavor(Flavor.stg);

      expect(config.webBaseUrl.toString(), 'https://stg.lunarabi.example');
      expect(config.apiBaseUrl.toString(), 'https://api-stg.lunarabi.example');
      expect(config.deepLinkHost, 'app.lunarabi.example');
      expect(config.flavor, Flavor.stg);
    });

    test('prod の API ホストには flavor サフィックスを付けない', () {
      // 本番だけ api.lunarabi.example（api-prod ではない）という仕様を固定する。
      final config = AppConfig.fromFlavor(Flavor.prod);

      expect(config.webBaseUrl.toString(), 'https://www.lunarabi.example');
      expect(config.apiBaseUrl.toString(), 'https://api.lunarabi.example');
      expect(config.deepLinkHost, 'app.lunarabi.example');
      expect(config.flavor, Flavor.prod);
    });
  });

  group('parseFlavor', () {
    // --dart-define=FLAVOR=... の文字列を Flavor に変換する関数のテスト。
    // 純粋関数（入出力だけ、画面やファイルに依存しない）なので単体テストしやすい。

    test('明示的な文字列を対応する Flavor に変換する', () {
      expect(parseFlavor('dev', isRelease: false), Flavor.dev);
      expect(parseFlavor('stg', isRelease: false), Flavor.stg);
      expect(parseFlavor('prod', isRelease: false), Flavor.prod);
    });

    test('未指定かつ release ビルドなら prod にフォールバックする', () {
      // kReleaseMode が true の本番バイナリで FLAVOR を付け忘れた場合の安全策。
      expect(parseFlavor('', isRelease: true), Flavor.prod);
    });

    test('未指定かつ debug/profile なら dev にフォールバックする', () {
      // 開発中は誤って本番 URL を開きにくくするため。
      expect(parseFlavor('', isRelease: false), Flavor.dev);
    });

    test('未知の文字列もフォールバック規則に従う', () {
      // タイポ（例: "production"）を黙って prod 扱いしないよう、
      // 未知値は「未指定と同じ」扱いにする。
      expect(parseFlavor('production', isRelease: true), Flavor.prod);
      expect(parseFlavor('production', isRelease: false), Flavor.dev);
    });
  });

  group('AppConfig.copyWithFlavor', () {
    test('別 flavor の設定オブジェクトを返す（元は変えない）', () {
      // デバッグメニューで環境を切り替えるときに使う想定。
      final original = AppConfig.fromFlavor(Flavor.dev);
      final switched = original.copyWithFlavor(Flavor.stg);

      expect(switched.flavor, Flavor.stg);
      expect(switched.webBaseUrl.toString(), 'https://stg.lunarabi.example');
      // イミュータブル（変更不能）であることを確認: 元のオブジェクトは触らない
      expect(original.flavor, Flavor.dev);
    });
  });

  group('AppConfig.resolve', () {
    test('dart-define 相当の値を flavor default より優先する', () {
      final config = AppConfig.resolve(
        isRelease: false,
        rawFlavor: 'prod',
        webBaseUrlDefine: 'https://web.lunarabi.jp',
        apiBaseUrlDefine: 'https://api.lunarabi.jp',
        deepLinkHostDefine: 'app.lunarabi.jp',
      );

      expect(config.webBaseUrl.toString(), 'https://web.lunarabi.jp');
      expect(config.apiBaseUrl.toString(), 'https://api.lunarabi.jp');
      expect(config.deepLinkHost, 'app.lunarabi.jp');
      expect(config.flavor, Flavor.prod);
    });

    test('未指定の define は flavor default を使う', () {
      final config = AppConfig.resolve(isRelease: false, rawFlavor: 'dev');

      expect(config.webBaseUrl.toString(), 'https://dev.lunarabi.example');
      expect(config.apiBaseUrl.toString(), 'https://api-dev.lunarabi.example');
      expect(config.deepLinkHost, 'app.lunarabi.example');
    });

    test('URL define は absolute https だけ許可する', () {
      expect(
        () => AppConfig.resolve(
          isRelease: false,
          webBaseUrlDefine: 'http://web.lunarabi.jp',
        ),
        throwsFormatException,
      );
      expect(
        () => AppConfig.resolve(isRelease: false, apiBaseUrlDefine: '/api'),
        throwsFormatException,
      );
    });

    test('deep link host define は scheme や path を持てない', () {
      expect(
        () => AppConfig.resolve(
          isRelease: false,
          deepLinkHostDefine: 'https://app.lunarabi.jp',
        ),
        throwsFormatException,
      );
      expect(
        () => AppConfig.resolve(
          isRelease: false,
          deepLinkHostDefine: 'app.lunarabi.jp/path',
        ),
        throwsFormatException,
      );
    });
  });

  group('AppConfig.assertReleaseHosts', () {
    test('placeholder / localhost / invalid TLD を release で拒否する', () {
      for (final host in [
        'app.lunarabi.example',
        'api.lunarabi.invalid',
        'localhost',
      ]) {
        final config = AppConfig(
          flavor: Flavor.prod,
          webBaseUrl: Uri.parse('https://www.lunarabi.jp'),
          apiBaseUrl: Uri.parse('https://api.lunarabi.jp'),
          deepLinkHost: host,
        );

        expect(config.assertReleaseHosts, throwsStateError);
      }
    });

    test('本物の https URL と host-only deep link host は release で通る', () {
      final config = AppConfig(
        flavor: Flavor.prod,
        webBaseUrl: Uri.parse('https://www.lunarabi.jp'),
        apiBaseUrl: Uri.parse('https://api.lunarabi.jp'),
        deepLinkHost: 'app.lunarabi.jp',
      );

      expect(config.assertReleaseHosts, returnsNormally);
    });
  });
}
