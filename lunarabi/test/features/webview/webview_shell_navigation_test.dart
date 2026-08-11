// =============================================================================
// WebViewShell navigation wiring tests
// =============================================================================
//
// Platform WebView の Widget は起動せず、Shell が使う判定ヘルパーだけを見る。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/webview/trusted_bridge_origin.dart';
import 'package:lunarabi/features/webview/webview_committed_url.dart';
import 'package:lunarabi/features/webview/webview_navigation_handler.dart';
import 'package:lunarabi/features/webview/webview_navigation_policy.dart';
import 'package:lunarabi/features/webview/webview_shell.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

void main() {
  late AppConfig config;
  late WebViewCommittedUrl committedUrl;
  late WebViewNavigationHandler handler;
  late List<({Uri uri, LaunchMode mode})> launches;

  setUp(() {
    config = AppConfig.fromFlavor(Flavor.dev);
    final policy = WebViewNavigationPolicy(HostGuard(config));
    committedUrl = WebViewCommittedUrl(
      webBaseUrl: config.webBaseUrl,
      policy: policy,
    );
    launches = [];
    handler = WebViewNavigationHandler(
      policy: policy,
      committedUrl: committedUrl,
      launchUrlFn: (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
        launches.add((uri: uri, mode: mode));
        return true;
      },
    );
  });

  NavigationRequest mainFrame(String url) {
    return NavigationRequest(url: url, isMainFrame: true);
  }

  group('WebViewNavigationHandler.handleNavigationRequest', () {
    test('未知の https ホストは外部起動して WebView 遷移を防ぐ', () async {
      final decision = await handler.handleNavigationRequest(
        mainFrame('https://evil.example/phish'),
      );

      expect(decision, NavigationDecision.prevent);
      expect(launches, [
        (
          uri: Uri.parse('https://evil.example/phish'),
          mode: LaunchMode.externalApplication,
        ),
      ]);
    });

    test('外部起動が失敗しても WebView 遷移を防ぎ、evil は committed にしない', () async {
      handler = WebViewNavigationHandler(
        policy: WebViewNavigationPolicy(HostGuard(config)),
        committedUrl: committedUrl,
        launchUrlFn:
            (uri, {LaunchMode mode = LaunchMode.platformDefault}) async {
              launches.add((uri: uri, mode: mode));
              return false;
            },
      );

      final decision = await handler.handleNavigationRequest(
        mainFrame('https://evil.example/phish'),
      );

      expect(decision, NavigationDecision.prevent);
      expect(launches.single.mode, LaunchMode.externalApplication);
      expect(committedUrl.committedUri, isNull);
      expect(committedUrl.isTrusted, isFalse);
    });

    test('許可ホストは WebView 遷移を許可し、外部起動しない', () async {
      final decision = await handler.handleNavigationRequest(
        mainFrame('https://dev.lunarabi.example/articles/1'),
      );

      expect(decision, NavigationDecision.navigate);
      expect(launches, isEmpty);
    });
  });

  group('WebViewCommittedUrl', () {
    test('page start でクリアし、許可ホストの page finish 後だけ committed にする', () {
      final allowed = Uri.parse('https://dev.lunarabi.example/articles/1');

      committedUrl.markPageFinished(allowed);
      expect(committedUrl.committedUri, allowed);
      expect(committedUrl.isTrusted, isTrue);

      committedUrl.markPageStarted(allowed);
      expect(committedUrl.committedUri, isNull);
      expect(committedUrl.isTrusted, isFalse);

      committedUrl.markPageFinished(allowed);
      expect(committedUrl.committedUri, allowed);
      expect(committedUrl.isTrusted, isTrue);
    });

    test('許可されないホストの page finish では committed にしない', () {
      committedUrl.markPageFinished(Uri.parse('https://evil.example/phish'));

      expect(committedUrl.committedUri, isNull);
      expect(committedUrl.isTrusted, isFalse);
    });
  });

  group('isTrustedBridgeOrigin', () {
    test('同じホストでも port が違えば trusted ではない', () {
      expect(
        isTrustedBridgeOrigin(
          Uri.parse('https://dev.lunarabi.example:8443/articles/1'),
          config.webBaseUrl,
        ),
        isFalse,
      );
    });

    test('deepLinkHost は WebView 遷移可能でも trusted bridge origin ではない', () {
      expect(
        isTrustedBridgeOrigin(
          Uri.parse('https://app.lunarabi.example/pay'),
          config.webBaseUrl,
        ),
        isFalse,
      );
    });
  });

  group('bridge bootstrap injection gate', () {
    test('deepLinkHost の page finish では full bridge bootstrap を注入しない', () {
      committedUrl.markPageFinished(
        Uri.parse('https://app.lunarabi.example/pay'),
      );

      expect(
        committedUrl.committedUri,
        Uri.parse('https://app.lunarabi.example/pay'),
      );
      expect(committedUrl.isTrusted, isFalse);
      expect(shouldInjectBridgeBootstrap(committedUrl), isFalse);
    });

    test('webBaseUrl origin の page finish では full bridge bootstrap を注入する', () {
      committedUrl.markPageFinished(
        Uri.parse('https://dev.lunarabi.example/articles/1'),
      );

      expect(shouldInjectBridgeBootstrap(committedUrl), isTrue);
    });
  });

  group('WebViewShell page finished bridge wiring', () {
    test('deepLinkHost の page finish では bridge bootstrap を呼ばない', () {
      var injectCount = 0;

      handleWebViewShellPageFinished(
        committedUrl: committedUrl,
        url: 'https://app.lunarabi.example/pay',
        injectBootstrap: () => injectCount += 1,
      );

      expect(
        committedUrl.committedUri,
        Uri.parse('https://app.lunarabi.example/pay'),
      );
      expect(committedUrl.isTrusted, isFalse);
      expect(injectCount, 0);
    });

    test('webBaseUrl origin の page finish では bridge bootstrap を呼ぶ', () {
      var injectCount = 0;

      handleWebViewShellPageFinished(
        committedUrl: committedUrl,
        url: 'https://dev.lunarabi.example/articles/1',
        injectBootstrap: () => injectCount += 1,
      );

      expect(committedUrl.isTrusted, isTrue);
      expect(injectCount, 1);
    });
  });

  group('WebViewShell system back decision', () {
    test('WebView 履歴があるときは goBack して route pop を止める', () async {
      var goBackCount = 0;

      final decision = await decideWebViewSystemBack(
        canGoBack: () async => true,
        goBack: () async {
          goBackCount += 1;
        },
      );

      expect(decision, WebViewSystemBackDecision.handledByWebView);
      expect(goBackCount, 1);
    });

    test('WebView 履歴がないときは route pop に任せる', () async {
      var goBackCount = 0;

      final decision = await decideWebViewSystemBack(
        canGoBack: () async => false,
        goBack: () async {
          goBackCount += 1;
        },
      );

      expect(decision, WebViewSystemBackDecision.allowRoutePop);
      expect(goBackCount, 0);
    });

    test('WebView 履歴がない system back は route pop を実行する', () async {
      var goBackCount = 0;
      var popRouteCount = 0;

      final decision = await handleWebViewSystemBack(
        canGoBack: () async => false,
        goBack: () async {
          goBackCount += 1;
        },
        popRoute: () async {
          popRouteCount += 1;
          return true;
        },
      );

      expect(decision, WebViewSystemBackDecision.allowRoutePop);
      expect(goBackCount, 0);
      expect(popRouteCount, 1);
    });
  });
}
