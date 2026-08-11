import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/bottom_nav_controller.dart';
import 'package:lunarabi/features/bridge/bridge_host.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';
import 'package:lunarabi/features/bridge/token_stores.dart';

void main() {
  late BottomNavController nav;
  late PushTokenStore push;
  late _MemoryAuthTokenRepository authRepo;
  late List<BridgeMessage> emitted;
  late Uri? committedUri;

  setUp(() {
    nav = BottomNavController();
    push = PushTokenStore();
    authRepo = _MemoryAuthTokenRepository();
    emitted = <BridgeMessage>[];
    committedUri = Uri.parse('https://web.lunarabi.example/account');
  });

  tearDown(() => push.dispose());

  BridgeHost buildHost({Uri? webBaseUrl}) {
    return BridgeHost(
      nav: nav,
      authRepo: authRepo,
      push: push,
      committedWebUri: () => committedUri,
      webBaseUrl: webBaseUrl ?? Uri.parse('https://web.lunarabi.example'),
      emitter: (message) async => emitted.add(message),
    );
  }

  Future<void> post(BridgeHost host, String type, String requestId) {
    return host.handleFromJs(
      '{"type":"$type","requestId":"$requestId","payload":{"token":"new-token"}}',
    );
  }

  test('trusted origin may set clear and read stored auth token', () async {
    final host = buildHost();

    await post(host, BridgeTypes.authSetBearerToken, 'set');
    expect(authRepo.token, 'new-token');

    await host.handleFromJs(
      '{"type":"${BridgeTypes.authGetStoredToken}","requestId":"read","payload":{}}',
    );
    expect(emitted.single.payload, {'ok': true, 'token': 'new-token'});

    await post(host, BridgeTypes.authClearBearerToken, 'clear');
    expect(authRepo.token, isNull);

    await host.handleFromJs(
      '{"type":"${BridgeTypes.authGetStoredToken}","requestId":"read-empty","payload":{}}',
    );
    expect(emitted.last.payload, {'ok': true, 'token': null});
  });

  test('distinct deep link host cannot set clear or read auth token', () async {
    authRepo.token = 'existing-token';
    committedUri = Uri.parse('https://app.lunarabi.example/deep-link');
    final host = buildHost();

    await post(host, BridgeTypes.authSetBearerToken, 'set');
    await post(host, BridgeTypes.authClearBearerToken, 'clear');
    await host.handleFromJs(
      '{"type":"${BridgeTypes.authGetStoredToken}","requestId":"read","payload":{}}',
    );

    expect(authRepo.token, 'existing-token');
    expect(
      emitted.map((message) => message.payload),
      everyElement({'ok': false, 'error': 'forbidden_origin'}),
    );
  });

  test(
    'same trusted host on a different port cannot set clear or read',
    () async {
      authRepo.token = 'existing-token';
      committedUri = Uri.parse('https://web.lunarabi.example:444/account');
      final host = buildHost();

      await post(host, BridgeTypes.authSetBearerToken, 'set');
      await post(host, BridgeTypes.authClearBearerToken, 'clear');
      await host.handleFromJs(
        '{"type":"${BridgeTypes.authGetStoredToken}","requestId":"read","payload":{}}',
      );

      expect(authRepo.token, 'existing-token');
      expect(
        emitted.map((message) => message.payload),
        everyElement({'ok': false, 'error': 'forbidden_origin'}),
      );
    },
  );

  test('null committed URL cannot set clear or read auth token', () async {
    authRepo.token = 'existing-token';
    committedUri = null;
    final host = buildHost();

    await post(host, BridgeTypes.authSetBearerToken, 'set');
    await post(host, BridgeTypes.authClearBearerToken, 'clear');
    await host.handleFromJs(
      '{"type":"${BridgeTypes.authGetStoredToken}","requestId":"read","payload":{}}',
    );

    expect(authRepo.token, 'existing-token');
    expect(
      emitted.map((message) => message.payload),
      everyElement({'ok': false, 'error': 'forbidden_origin'}),
    );
  });

  test('legacy getBearerToken is forbidden even on trusted origin', () async {
    authRepo.token = 'existing-token';
    final host = buildHost();

    await host.handleFromJs(
      '{"type":"auth.getBearerToken","requestId":"legacy","payload":{}}',
    );

    expect(emitted.single.payload, {'ok': false, 'error': 'forbidden'});
  });
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
