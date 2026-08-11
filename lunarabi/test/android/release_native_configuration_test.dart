import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Android release native configuration', () {
    test('Manifest uses the deepLinkHost placeholder', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(manifest, contains('android:host="\${deepLinkHost}"'));
      expect(manifest, isNot(contains('android:host="app.lunarabi.example"')));
    });

    test(
      'Gradle injects deepLinkHost and rejects placeholder release hosts',
      () {
        final gradle = File('android/app/build.gradle.kts').readAsStringSync();

        expect(gradle, contains('manifestPlaceholders["deepLinkHost"]'));
        expect(gradle, contains('LUNARABI_DEEP_LINK_HOST'));
        expect(gradle, contains('app.lunarabi.example'));
        expect(gradle, contains('Release deep link host must be set'));
        expect(
          gradle,
          contains('releaseDeepLinkHost.trim() != releaseDeepLinkHost'),
        );
        expect(gradle, contains('releaseDeepLinkHost.contains("\\\\")'));
      },
    );

    test('Gradle release tasks depend on the release input verifier', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('verifyLunarabiReleaseInputs'));
      expect(gradle, contains('Exec'));
      expect(
        gradle,
        contains('commandLine("bash", "tool/verify_release_inputs.sh")'),
      );
      expect(gradle, contains('dependsOn(verifyLunarabiReleaseInputs)'));
    });

    test('Gradle release signing has no debug fallback', () {
      final gradle = File('android/app/build.gradle.kts').readAsStringSync();

      expect(gradle, contains('create("release")'));
      expect(
        gradle,
        contains('signingConfig = signingConfigs.getByName("release")'),
      );
      expect(
        gradle,
        isNot(contains('signingConfig = signingConfigs.getByName("debug")')),
      );
    });
  });
}
