// =============================================================================
// WebViewNavigationPolicy の単体テスト
// =============================================================================
//
// WebView 内の遷移リクエストを allow / openExternal / block に振り分ける。
// HostGuard と組み合わせ、許可ホストの https のみアプリ内継続とする。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';

void main() {
  late HostGuard guard;
  late WebViewNavigationPolicy policy;

  setUp(() {
    guard = HostGuard(AppConfig.fromFlavor(Flavor.dev));
    policy = WebViewNavigationPolicy(guard);
  });

  group('WebViewNavigationPolicy.decide', () {
    test('https かつ許可ホストなら allow', () {
      final uri = Uri.parse('https://dev.lunarabi.example/articles/1');
      expect(policy.decide(uri), WebViewNavAction.allow);
    });

    test('https かつディープリンクホストなら allow', () {
      final uri = Uri.parse('https://app.lunarabi.example/pay');
      expect(policy.decide(uri), WebViewNavAction.allow);
    });

    test('https かつ未知ホストは openExternal', () {
      final uri = Uri.parse('https://evil.example/phish');
      expect(policy.decide(uri), WebViewNavAction.openExternal);
    });

    test('http は許可ホストでも openExternal（アプリ内継続しない）', () {
      final uri = Uri.parse('http://dev.lunarabi.example/articles/1');
      expect(policy.decide(uri), WebViewNavAction.openExternal);
    });

    test('mailto は openExternal', () {
      final uri = Uri.parse('mailto:support@lunarabi.example');
      expect(policy.decide(uri), WebViewNavAction.openExternal);
    });

    test('tel は openExternal', () {
      final uri = Uri.parse('tel:+81123456789');
      expect(policy.decide(uri), WebViewNavAction.openExternal);
    });

    test('カスタムスキームは block', () {
      final uri = Uri.parse('myapp://callback');
      expect(policy.decide(uri), WebViewNavAction.block);
    });
  });
}
