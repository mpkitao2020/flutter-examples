import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';
import 'package:lunarabi/features/push/notification_link_parser.dart';
import 'package:lunarabi/features/push/push_service.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

void main() {
  late AppConfig config;
  late HostGuard guard;
  late PushTokenStore push;
  late List<BridgeMessage> emitted;
  late Uri? committedUri;
  late BridgeHost host;

  setUp(() {
    config = AppConfig.fromFlavor(Flavor.dev);
    guard = HostGuard(config);
    push = PushTokenStore();
    emitted = <BridgeMessage>[];
    committedUri = Uri.parse('https://dev.lunarabi.example/articles/1');
    host = BridgeHost(
      nav: BottomNavController(),
      authRepo: _MemoryAuthTokenRepository(),
      push: push,
      committedWebUri: () => committedUri,
      webBaseUrl: config.webBaseUrl,
      emitter: (message) async => emitted.add(message),
    );
  });

  tearDown(() => push.dispose());

  test(
    'publishToken hands token to Web without native backend register',
    () async {
      final backend = _ThrowingPushBackend();
      final service = PushService(
        navigator: _FakeNavigator(),
        guard: guard,
        backend: backend,
        bridgeHost: host,
      );

      await service.publishToken('fcm-web-owned');

      expect(backend.registeredTokens, isEmpty);
      expect(push.token, 'fcm-web-owned');
      expect(emitted, hasLength(1));
      expect(emitted.single.type, BridgeTypes.pushSetToken);
      expect(emitted.single.payload, {
        'token': 'fcm-web-owned',
        'platform': 'android',
      });
    },
  );

  test('trusted bridge.ready replays stored token every time', () async {
    final service = PushService(
      navigator: _FakeNavigator(),
      guard: guard,
      bridgeHost: host,
    );
    addTearDown(service.dispose);
    push.setToken('stored-fcm-token');
    final platform = _FakePlatformWebViewController();
    final controller = WebViewController.fromPlatform(platform);

    await host.ensureChannel(controller);
    await host.injectBootstrap(platform: 'android');
    await host.injectBootstrap(platform: 'android');

    expect(
      emitted.where((message) => message.type == BridgeTypes.bridgeReady),
      hasLength(2),
    );
    final pushEvents = emitted
        .where((message) => message.type == BridgeTypes.pushSetToken)
        .toList();
    expect(pushEvents, hasLength(2));
    expect(
      pushEvents.map((message) => message.payload),
      everyElement({'token': 'stored-fcm-token', 'platform': 'android'}),
    );
  });

  test('non-trusted bridge.ready does not replay stored token', () async {
    committedUri = Uri.parse('https://app.lunarabi.example/articles/1');
    final service = PushService(
      navigator: _FakeNavigator(),
      guard: guard,
      bridgeHost: host,
    );
    addTearDown(service.dispose);
    push.setToken('stored-fcm-token');
    final platform = _FakePlatformWebViewController();
    final controller = WebViewController.fromPlatform(platform);

    await host.ensureChannel(controller);
    await host.injectBootstrap(platform: 'android');

    expect(
      emitted.where((message) => message.type == BridgeTypes.pushSetToken),
      isEmpty,
    );
  });
}

class _FakeNavigator implements AppNavigator {
  @override
  Future<void> openDeepLink(Uri uri) async {}

  @override
  Future<void> openFromNotification(Uri uri) async {}
}

class _MemoryAuthTokenRepository implements AuthTokenRepository {
  String? token;

  @override
  Future<void> save(String token) async {
    this.token = token;
  }

  @override
  Future<String?> read() async {
    return token;
  }

  @override
  Future<void> clear() async {
    token = null;
  }
}

class _ThrowingPushBackend implements PushBackendClient {
  final registeredTokens = <String>[];

  @override
  Future<void> register(String token) async {
    registeredTokens.add(token);
    throw StateError('native register must not run');
  }
}

class _FakePlatformWebViewController extends PlatformWebViewController {
  _FakePlatformWebViewController()
    : super.implementation(const PlatformWebViewControllerCreationParams());

  @override
  Future<void> addJavaScriptChannel(JavaScriptChannelParams params) async {}

  @override
  Future<void> runJavaScript(String javaScript) async {}
}
