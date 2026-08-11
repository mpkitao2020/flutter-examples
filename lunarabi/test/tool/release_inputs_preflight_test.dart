import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('release input preflight', () {
    test('single entrypoint fails the current placeholder tree', () async {
      final script = File('tool/verify_release_inputs.sh');
      expect(script.existsSync(), isTrue);

      final result = await Process.run('bash', [script.path]);

      expect(result.exitCode, isNot(0));
      expect(
        '${result.stdout}\n${result.stderr}',
        anyOf(contains('LUNARABI_WEB_BASE_URL'), contains('release gate')),
      );
    });

    test(
      'release gates verifier requires evidence before gates close',
      () async {
        final script = File('tool/verify_release_gates_manifest.sh');
        expect(script.existsSync(), isTrue);

        final result = await Process.run('bash', [script.path]);

        expect(result.exitCode, isNot(0));
        expect('${result.stdout}\n${result.stderr}', contains('status=closed'));
      },
    );
  });
}
