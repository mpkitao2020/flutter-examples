// =============================================================================
// 通知ペイロードの link パース
// =============================================================================
//
// FCM data の `link` は HTTPS かつ HostGuard 許可ホストのみ通す。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/navigation/app_navigator.dart';
import 'package:lunarabi/features/push/notification_link_parser.dart';

void main() {
  late HostGuard guard;

  setUp(() {
    guard = HostGuard(AppConfig.fromFlavor(Flavor.dev));
  });

  test('許可ホストの https link を返す', () {
    final uri = parseNotificationLink(
      {'link': 'https://app.lunarabi.example/promo'},
      guard,
    );
    expect(uri?.host, 'app.lunarabi.example');
  });

  test('http / 悪ホスト / 欠落は null', () {
    expect(
      parseNotificationLink({'link': 'http://app.lunarabi.example/x'}, guard),
      isNull,
    );
    expect(
      parseNotificationLink({'link': 'https://evil.example/x'}, guard),
      isNull,
    );
    expect(parseNotificationLink(<String, dynamic>{}, guard), isNull);
    expect(parseNotificationLink({'link': 1}, guard), isNull);
  });
}
