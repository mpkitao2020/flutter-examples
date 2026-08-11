// =============================================================================
// アプリ ID（パッケージ名 / Bundle ID）の単体テスト
// =============================================================================
//
// 環境ごとにアプリを同時インストールできるように ID を分けている。
// このテストは「仕様として約束した文字列」を固定するためのもの。
// Gradle / Xcode / Firebase 側を変えたら、ここも同じ値に揃える。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/core/env/app_ids.dart';

void main() {
  group('AppIds.forFlavor', () {
    test('dev / stg は接尾辞付き、prod は本体のみ', () {
      // Arrange / Act / Assert
      expect(AppIds.forFlavor(Flavor.dev), 'com.wandit.lunarabi.dev');
      expect(AppIds.forFlavor(Flavor.stg), 'com.wandit.lunarabi.stg');
      expect(AppIds.forFlavor(Flavor.prod), 'com.wandit.lunarabi');
    });

    test('定数と forFlavor の結果が一致する', () {
      expect(AppIds.dev, AppIds.forFlavor(Flavor.dev));
      expect(AppIds.stg, AppIds.forFlavor(Flavor.stg));
      expect(AppIds.prod, AppIds.forFlavor(Flavor.prod));
    });
  });
}
