import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/deeplink/deep_link_parser.dart';

void main() {
  late HostGuard guard;

  setUp(() {
    guard = HostGuard(AppConfig.fromFlavor(Flavor.dev));
  });

  test('https deep host path → webPath', () {
    final parsed = parseDeepLink(
      Uri.parse('https://app.lunarabi.example/articles/1'),
      guard,
    );
    expect(parsed.kind, DeepLinkKind.webPath);
  });

  test('https /pay/gmo/complete → gmoComplete', () {
    final parsed = parseDeepLink(
      Uri.parse('https://app.lunarabi.example/pay/gmo/complete?paymentId=p1'),
      guard,
    );
    expect(parsed.kind, DeepLinkKind.gmoComplete);
  });

  test('http は unknown', () {
    final parsed = parseDeepLink(
      Uri.parse('http://app.lunarabi.example/x'),
      guard,
    );
    expect(parsed.kind, DeepLinkKind.unknown);
  });

  test('custom scheme は unknown', () {
    final parsed = parseDeepLink(
      Uri.parse('myapp://app.lunarabi.example/x'),
      guard,
    );
    expect(parsed.kind, DeepLinkKind.unknown);
  });

  test('悪ホストは unknown', () {
    final parsed = parseDeepLink(
      Uri.parse('https://evil.example/x'),
      guard,
    );
    expect(parsed.kind, DeepLinkKind.unknown);
  });
}
