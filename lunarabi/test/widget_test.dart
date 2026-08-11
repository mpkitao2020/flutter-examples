import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';

void main() {
  // WebView は Platform View のため CI 上の widget test で pump しにくい。
  // シェル結合は HostGuard 単体と手動実機確認に寄せる。
  test('dev config remains the default smoke check', () {
    final config = AppConfig.fromFlavor(Flavor.dev);
    expect(config.webBaseUrl.host, 'dev.lunarabi.example');
  });
}
