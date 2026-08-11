import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_listener.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';

class _FakeNavigator implements AppNavigator {
  final opened = <Uri>[];

  @override
  Future<void> openDeepLink(Uri uri) async => opened.add(uri);

  @override
  Future<void> openFromNotification(Uri uri) async => opened.add(uri);
}

void main() {
  test('webPath は navigator を呼び、gmoComplete は呼ばない', () async {
    final guard = HostGuard(AppConfig.fromFlavor(Flavor.dev));
    final bus = DeepLinkBus();
    final navigator = _FakeNavigator();
    final controller = StreamController<Uri>.broadcast();
    final busEvents = <ParsedDeepLink>[];
    final busSub = bus.stream.listen(busEvents.add);

    addTearDown(() async {
      await busSub.cancel();
      await controller.close();
      await bus.dispose();
    });

    final listener = DeepLinkListener(
      guard: guard,
      bus: bus,
      navigator: navigator,
      getInitialLink: () async => null,
      uriLinkStream: controller.stream,
    );

    await listener.start();
    await Future<void>.delayed(Duration.zero);

    controller.add(Uri.parse('https://app.lunarabi.example/home'));
    await Future<void>.delayed(Duration.zero);
    expect(navigator.opened, hasLength(1));

    controller.add(
      Uri.parse('https://app.lunarabi.example/pay/gmo/complete?paymentId=x'),
    );
    await Future<void>.delayed(Duration.zero);

    expect(navigator.opened, hasLength(1));
    expect(busEvents.map((e) => e.kind), [
      DeepLinkKind.webPath,
      DeepLinkKind.gmoComplete,
    ]);

    await listener.dispose();
  });
}
