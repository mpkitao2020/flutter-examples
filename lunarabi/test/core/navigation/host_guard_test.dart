// =============================================================================
// HostGuard の単体テスト
// =============================================================================
//
// HostGuard は「この URL を WebView で開いてよいか」を判定する門番。
// ディープリンク・プッシュ通知・WebView ロードの前に必ず通す。
//
// ここでは UI（WebView）を起動しない。純粋な URL 判定だけをテストする。
// Platform View を含む Widget テストは壊れやすいので、門番ロジックは
// こうして切り離して検証する。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';

void main() {
  // 各テストで同じ設定を使う。dev 環境の webBase は
  // https://dev.lunarabi.example / deepLinkHost は app.lunarabi.example
  late HostGuard guard;

  setUp(() {
    // setUp は「各 test の直前」に毎回呼ばれる初期化フック。
    guard = HostGuard(AppConfig.fromFlavor(Flavor.dev));
  });

  group('HostGuard.isAllowed', () {
    test('https かつディープリンクホストなら許可する', () {
      final uri = Uri.parse('https://app.lunarabi.example/pay');
      expect(guard.isAllowed(uri), isTrue);
    });

    test('https かつその環境の Web ホストなら許可する', () {
      final uri = Uri.parse('https://dev.lunarabi.example/articles/1');
      expect(guard.isAllowed(uri), isTrue);
    });

    test('http（暗号化なし）は拒否する', () {
      // Universal Links / App Links は https のみ、という仕様の守り。
      final uri = Uri.parse('http://app.lunarabi.example/x');
      expect(guard.isAllowed(uri), isFalse);
    });

    test('未知のホストは拒否する', () {
      // フィッシングや意図しない遷移を防ぐための allowlist。
      final uri = Uri.parse('https://evil.example/x');
      expect(guard.isAllowed(uri), isFalse);
    });

    test('カスタムスキームは拒否する', () {
      final uri = Uri.parse('myapp://app.lunarabi.example/x');
      expect(guard.isAllowed(uri), isFalse);
    });
  });

  group('HostGuard.resolveForWebView', () {
    test('ディープリンクホストの path/query を Web ベース URL に載せ替える', () {
      // 例: https://app.lunarabi.example/a?b=1
      //  → https://dev.lunarabi.example/a?b=1
      // これにより「共有用ドメイン」と「実コンテンツのドメイン」を分けられる。
      final input = Uri.parse('https://app.lunarabi.example/a?b=1');
      final resolved = guard.resolveForWebView(input);

      expect(resolved, isNotNull);
      expect(resolved.toString(), 'https://dev.lunarabi.example/a?b=1');
    });

    test('すでに Web ホストの URL はそのまま返す', () {
      final input = Uri.parse('https://dev.lunarabi.example/path');
      final resolved = guard.resolveForWebView(input);

      expect(resolved.toString(), 'https://dev.lunarabi.example/path');
    });

    test('許可されない URL は null を返す', () {
      // null = 「開くな」。呼び出し側はログして無視する。
      final input = Uri.parse('https://evil.example/x');
      expect(guard.resolveForWebView(input), isNull);
    });

    test('fragment も維持する', () {
      final input = Uri.parse('https://app.lunarabi.example/docs#section');
      final resolved = guard.resolveForWebView(input);

      expect(resolved.toString(), 'https://dev.lunarabi.example/docs#section');
    });
  });
}
