import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/deeplink/deep_link_bus.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';

void main() {
  test('購読前の publish は最初の listener に replay される', () async {
    final bus = DeepLinkBus();
    addTearDown(bus.dispose);

    final link = ParsedDeepLink(
      kind: DeepLinkKind.gmoComplete,
      uri: Uri.parse('https://app.lunarabi.example/pay/gmo/complete?paymentId=1'),
    );
    bus.publish(link);

    final first = await bus.stream.first;
    expect(first.kind, DeepLinkKind.gmoComplete);
    expect(first.uri.queryParameters['paymentId'], '1');
  });

  test('live 中の publish はストリームに流れる', () async {
    final bus = DeepLinkBus();
    addTearDown(bus.dispose);

    final events = <ParsedDeepLink>[];
    final sub = bus.stream.listen(events.add);
    addTearDown(sub.cancel);

    // Ensure listen side effects run.
    await Future<void>.delayed(Duration.zero);

    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.webPath,
        uri: Uri.parse('https://app.lunarabi.example/a'),
      ),
    );
    await Future<void>.delayed(Duration.zero);

    expect(events, hasLength(1));
    expect(events.single.kind, DeepLinkKind.webPath);
  });
  test('購読者が消えたあとの publish は次の listener に replay される', () async {
    final bus = DeepLinkBus();
    addTearDown(bus.dispose);

    final firstSub = bus.stream.listen((_) {});
    await Future<void>.delayed(Duration.zero);
    await firstSub.cancel();
    await Future<void>.delayed(Duration.zero);

    bus.publish(
      ParsedDeepLink(
        kind: DeepLinkKind.gmoComplete,
        uri: Uri.parse(
          'https://app.lunarabi.example/pay/gmo/complete?paymentId=gap',
        ),
      ),
    );

    final replayed = await bus.stream.first;
    expect(replayed.uri.queryParameters['paymentId'], 'gap');
  });
}
