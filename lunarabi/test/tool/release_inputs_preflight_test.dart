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

    test('single entrypoint also forbids Dart FirebaseOptions', () {
      final script = File('tool/verify_release_inputs.sh').readAsStringSync();

      expect(script, contains('tool/forbid_firebase_options.sh'));
    });

    test('signing preflight rejects unreadable store files', () async {
      final script = File('tool/verify_release_inputs.sh');
      expect(script.existsSync(), isTrue);

      final result = await Process.run(
        'bash',
        [script.path],
        environment: {
          'LUNARABI_WEB_BASE_URL': 'https://www.lunarabi.jp',
          'LUNARABI_API_BASE_URL': 'https://api.lunarabi.jp',
          'LUNARABI_DEEP_LINK_HOST': 'app.lunarabi.jp',
          'LUNARABI_ANDROID_STORE_FILE': '/tmp/lunarabi-missing-release.jks',
          'LUNARABI_ANDROID_STORE_PASSWORD': 'password',
          'LUNARABI_ANDROID_KEY_ALIAS': 'release',
          'LUNARABI_ANDROID_KEY_PASSWORD': 'password',
        },
      );

      expect(result.exitCode, isNot(0));
      expect('${result.stdout}\n${result.stderr}', contains('is not readable'));
    });

    test(
      'release build wrapper verifies inputs before forwarding to Flutter',
      () {
        final script = File('tool/build_release.sh');

        expect(script.existsSync(), isTrue);
        final source = script.readAsStringSync();
        expect(source, contains('tool/verify_release_inputs.sh'));
        expect(source, contains(r'fvm flutter build "$@"'));
      },
    );

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

    group('release gates manifest verifier', () {
      test(
        'accepts existing non-markdown artifacts with real metadata',
        () async {
          final root = await _createVerifierRoot();
          addTearDown(() => root.deleteSync(recursive: true));
          await _writeArtifact(root, 'firebase-prod-files.json', 'x' * 32);
          await _writeManifest(
            root,
            evidence: 'docs/evidence/artifacts/firebase-prod-files.json',
          );

          final result = await _runVerifier(root);

          expect(result.exitCode, 0);
        },
      );

      for (final scenario in [
        _ManifestScenario(
          name: 'rejects docs/superpowers evidence',
          evidence: 'docs/superpowers/runbooks/lunarabi-release-gates.md',
          expectedError: 'docs/superpowers',
        ),
        _ManifestScenario(
          name: 'rejects runbook evidence paths',
          evidence: 'docs/evidence/artifacts/release-runbook.log',
          artifactName: 'release-runbook.log',
          artifactContents: 'x' * 32,
          expectedError: 'runbook',
        ),
        _ManifestScenario(
          name: 'rejects markdown-only fake proof',
          evidence: 'docs/evidence/artifacts/fake-proof.md',
          artifactName: 'fake-proof.md',
          artifactContents: 'x' * 32,
          expectedError: 'markdown',
        ),
        _ManifestScenario(
          name: 'rejects missing evidence files',
          evidence: 'docs/evidence/artifacts/missing.json',
          expectedError: 'does not exist',
        ),
        _ManifestScenario(
          name: 'rejects too-short artifacts',
          evidence: 'docs/evidence/artifacts/short.json',
          artifactName: 'short.json',
          artifactContents: 'too short',
          expectedError: 'at least 32 bytes',
        ),
        _ManifestScenario(
          name: 'rejects invalid dates',
          evidence: 'docs/evidence/artifacts/date.json',
          artifactName: 'date.json',
          artifactContents: 'x' * 32,
          date: '2026/08/11',
          expectedError: 'date must match',
        ),
        _ManifestScenario(
          name: 'rejects short owners',
          evidence: 'docs/evidence/artifacts/owner.json',
          artifactName: 'owner.json',
          artifactContents: 'x' * 32,
          owner: 'qa',
          expectedError: 'owner must be at least 3 characters',
        ),
        _ManifestScenario(
          name: 'rejects short sign-offs',
          evidence: 'docs/evidence/artifacts/signoff.json',
          artifactName: 'signoff.json',
          artifactContents: 'x' * 32,
          signOff: 'x',
          expectedError: 'signOff must be at least 2 characters',
        ),
      ]) {
        test(scenario.name, () async {
          final root = await _createVerifierRoot();
          addTearDown(() => root.deleteSync(recursive: true));
          if (scenario.artifactName != null) {
            await _writeArtifact(
              root,
              scenario.artifactName!,
              scenario.artifactContents!,
            );
          }
          await _writeManifest(
            root,
            evidence: scenario.evidence,
            date: scenario.date ?? '2026-08-11',
            owner: scenario.owner ?? 'release-owner',
            signOff: scenario.signOff ?? 'ok',
          );

          final result = await _runVerifier(root);

          expect(result.exitCode, isNot(0));
          expect(
            '${result.stdout}\n${result.stderr}',
            contains(scenario.expectedError),
          );
        });
      }
    });
  });
}

class _ManifestScenario {
  const _ManifestScenario({
    required this.name,
    required this.evidence,
    required this.expectedError,
    this.artifactName,
    this.artifactContents,
    this.date,
    this.owner,
    this.signOff,
  });

  final String name;
  final String evidence;
  final String expectedError;
  final String? artifactName;
  final String? artifactContents;
  final String? date;
  final String? owner;
  final String? signOff;
}

Future<Directory> _createVerifierRoot() async {
  final root = await Directory.systemTemp.createTemp('release-gates-');
  await Directory('${root.path}/tool').create(recursive: true);
  await Directory(
    '${root.path}/docs/evidence/artifacts',
  ).create(recursive: true);
  await File(
    'tool/verify_release_gates_manifest.sh',
  ).copy('${root.path}/tool/verify_release_gates_manifest.sh');
  return root;
}

Future<void> _writeArtifact(
  Directory root,
  String name,
  String contents,
) async {
  await File(
    '${root.path}/docs/evidence/artifacts/$name',
  ).writeAsString(contents);
}

Future<void> _writeManifest(
  Directory root, {
  required String evidence,
  String date = '2026-08-11',
  String owner = 'release-owner',
  String signOff = 'ok',
}) async {
  await File(
    '${root.path}/docs/evidence/release_gates.manifest.json',
  ).writeAsString('''
{
  "schemaVersion": 1,
  "gates": [
    {
      "id": "firebase-prod-files",
      "name": "Firebase prod files replaced",
      "status": "closed",
      "evidence": "$evidence",
      "owner": "$owner",
      "date": "$date",
      "signOff": "$signOff"
    }
  ]
}
''');
}

Future<ProcessResult> _runVerifier(Directory root) {
  return Process.run('bash', [
    '${root.path}/tool/verify_release_gates_manifest.sh',
  ]);
}
