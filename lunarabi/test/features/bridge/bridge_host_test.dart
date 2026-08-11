// =============================================================================
// BridgeHost の振る舞いテスト（WebView なし）
// =============================================================================
//
// emit 先をメモリのリストに差し替え、JS→Flutter の各 type が
// コントローラ／Store を正しく更新するかを確認する。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  late BottomNavController nav;
  late AuthTokenStore auth;
  late PushTokenStore push;
  late List<BridgeMessage> emitted;
  late BridgeHost host;

  setUp(() {
    nav = BottomNavController();
    auth = AuthTokenStore();
    push = PushTokenStore();
    emitted = <BridgeMessage>[];
    host = BridgeHost(
      nav: nav,
      auth: auth,
      push: push,
      emitter: (message) async => emitted.add(message),
    );
  });

  tearDown(() => push.dispose());

  test('nav.setVisible / setBadge / setActive が効く', () async {
    await host.handleFromJs(
      '{"type":"nav.setVisible","payload":{"visible":false}}',
    );
    await host.handleFromJs(
      '{"type":"nav.setBadge","payload":{"id":"notify","count":2}}',
    );
    await host.handleFromJs(
      '{"type":"nav.setActive","payload":{"id":"account"}}',
    );

    expect(nav.visible, isFalse);
    expect(nav.badgeOf(NavTabId.notify), 2);
    expect(nav.active, NavTabId.account);
  });

  test('auth.setBearerToken / getBearerToken / clear', () async {
    await host.handleFromJs(
      '{"type":"auth.setBearerToken","payload":{"token":"abc-token"}}',
    );
    expect(auth.bearerToken, 'abc-token');

    await host.handleFromJs(
      '{"type":"auth.getBearerToken","requestId":"r1","payload":{}}',
    );
    expect(emitted, isNotEmpty);
    final response = emitted.last;
    expect(response.type, BridgeTypes.bridgeResponse);
    expect(response.requestId, 'r1');
    expect(response.payload['ok'], isTrue);
    expect(response.payload['token'], 'abc-token');

    await host.handleFromJs('{"type":"auth.clearBearerToken","payload":{}}');
    expect(auth.bearerToken, isNull);
  });

  test('未知 type は bridge.response で unknown_type', () async {
    await host.handleFromJs(
      '{"type":"nope.what","requestId":"x","payload":{}}',
    );
    expect(emitted.single.payload['ok'], isFalse);
    expect(emitted.single.payload['error'], 'unknown_type');
  });

  test('notifyTabSelected が Flutter→JS メッセージを出す', () async {
    await host.notifyTabSelected(NavTabId.search);
    expect(emitted.single.type, BridgeTypes.navTabSelected);
    expect(emitted.single.payload['id'], 'search');
  });

  test('push.getToken は Store の値を返す', () async {
    push.setToken('fcm-1');
    await host.handleFromJs(
      '{"type":"push.getToken","requestId":"p1","payload":{}}',
    );
    expect(emitted.single.payload['token'], 'fcm-1');
  });

  test('injectBootstrap は channel を増やさず trusted page ごとに ready を出す', () async {
    var readyCount = 0;
    host = BridgeHost(
      nav: nav,
      auth: auth,
      push: push,
      emitter: (message) async => emitted.add(message),
      onReady: () => readyCount += 1,
    );
    final platform = _FakePlatformWebViewController();
    final controller = WebViewController.fromPlatform(platform);

    await host.ensureChannel(controller);
    await host.injectBootstrap(platform: 'android');
    await host.injectBootstrap(platform: 'android');

    expect(platform.channelNames, [BridgeHost.channelName]);
    expect(
      platform.javaScripts.where((script) => script.contains('LunarabiBridge')),
      hasLength(2),
    );
    expect(
      emitted.where((message) => message.type == BridgeTypes.bridgeReady),
      hasLength(2),
    );
    expect(readyCount, 2);
  });
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController()
    : super.implementation(const PlatformWebViewControllerCreationParams());

  final channelNames = <String>[];
  final javaScripts = <String>[];

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {
    channelNames.add(params.name);
  }

  @override
  Future<void> runJavaScript(String javaScript) async {
    javaScripts.add(javaScript);
  }
}
