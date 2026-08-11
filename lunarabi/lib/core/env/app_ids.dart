/// Store / package identifiers per [Flavor].
///
/// Android uses `applicationId` (+ suffix). iOS uses `PRODUCT_BUNDLE_IDENTIFIER`.
/// Keep these in sync with:
/// - `android/app/build.gradle.kts` productFlavors
/// - `ios/Runner.xcodeproj` Debug/Profile/Release bundle IDs
/// - Firebase `google-services.json` / `GoogleService-Info.plist`
library;

import 'package:lunarabi/core/env/app_config.dart';

abstract final class AppIds {
  static const prod = 'com.wandit.lunarabi';
  static const dev = 'com.wandit.lunarabi.dev';
  static const stg = 'com.wandit.lunarabi.stg';

  static String forFlavor(Flavor flavor) {
    return switch (flavor) {
      Flavor.dev => dev,
      Flavor.stg => stg,
      Flavor.prod => prod,
    };
  }
}
