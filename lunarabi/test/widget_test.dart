// =============================================================================
// スモーク用の最小テスト
// =============================================================================
//
// WebView は実機／エミュレータ上の Platform View なので、
// `pumpWidget(LunarabiApp(...))` すると CI で落ちやすい。
// そのためここでは「設定オブジェクトが仕様どおりか」だけを軽く確認する。
//
// 詳しいテストの読み方は:
//   test/core/env/app_config_test.dart
//   test/core/navigation/host_guard_test.dart
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';

void main() {
  test('dev config remains the default smoke check', () {
    // Arrange / Act
    final config = AppConfig.fromFlavor(Flavor.dev);

    // Assert: ホスト名だけ見れば、間違った環境ファイルを読んでいないかが分かる
    expect(config.webBaseUrl.host, 'dev.lunarabi.example');
  });
}
