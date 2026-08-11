import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('iOS Runner push configuration', () {
    test(
      'Runner Debug/Profile/Release attach the expected entitlements files',
      () {
        final project = PbxProject(
          File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
        );

        final buildSettings = project.runnerBuildSettingsByConfiguration();

        expect(buildSettings.keys.toSet(), {'Debug', 'Profile', 'Release'});
        expect(
          buildSettings['Debug']?['CODE_SIGN_ENTITLEMENTS'],
          'Runner/Runner.entitlements',
        );
        expect(
          buildSettings['Profile']?['CODE_SIGN_ENTITLEMENTS'],
          'Runner/Runner.entitlements',
        );
        expect(
          buildSettings['Release']?['CODE_SIGN_ENTITLEMENTS'],
          'Runner/Runner.Release.entitlements',
        );
      },
    );

    test('Runner runs release preflight before compiling sources', () {
      final project = PbxProject(
        File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync(),
      );

      final buildPhases = project.runnerBuildPhases();
      final sourcesIndex = buildPhases.indexWhere(
        (phase) => phase.comment == 'Sources',
      );
      final preflightIndex = buildPhases.indexWhere(
        (phase) => phase.body.contains('verify_release_inputs.sh'),
      );

      expect(preflightIndex, isNonNegative);
      expect(sourcesIndex, isNonNegative);
      expect(preflightIndex, lessThan(sourcesIndex));

      final preflight = buildPhases[preflightIndex].body;
      expect(preflight, contains(r'bash "${SRCROOT}/../tool/verify_release_inputs.sh"'));
      expect(preflight, contains(r'CONFIGURATION'));
      expect(preflight, contains(r'Release'));
    });

    test('Runner entitlements keep domains and split APNs environments', () {
      final debugProfileEntitlements = File(
        'ios/Runner/Runner.entitlements',
      ).readAsStringSync();
      final releaseEntitlements = File(
        'ios/Runner/Runner.Release.entitlements',
      ).readAsStringSync();

      expect(
        plistStringValue(debugProfileEntitlements, 'aps-environment'),
        'development',
      );
      expect(
        plistArrayValues(
          debugProfileEntitlements,
          'com.apple.developer.associated-domains',
        ),
        contains('applinks:app.lunarabi.example'),
      );
      expect(
        plistStringValue(releaseEntitlements, 'aps-environment'),
        'production',
      );
      expect(
        plistArrayValues(
          releaseEntitlements,
          'com.apple.developer.associated-domains',
        ),
        contains('applinks:app.lunarabi.example'),
      );
    });

    test('Runner Info.plist enables remote notification background mode', () {
      final infoPlist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(
        plistArrayValues(infoPlist, 'UIBackgroundModes'),
        contains('remote-notification'),
      );
    });

    test(
      'materialize script updates both associated-domain entitlement files',
      () async {
        final temp = Directory.systemTemp.createTempSync(
          'lunarabi-entitlements-',
        );
        addTearDown(() => temp.deleteSync(recursive: true));
        final runnerDir = Directory('${temp.path}/ios/Runner')
          ..createSync(recursive: true);
        for (final name in [
          'Runner.entitlements',
          'Runner.Release.entitlements',
        ]) {
          File('ios/Runner/$name').copySync('${runnerDir.path}/$name');
        }

        final result = await Process.run(
          'bash',
          ['tool/materialize_ios_deeplink_host.sh'],
          environment: {
            ...Platform.environment,
            'LUNARABI_ROOT': temp.path,
            'LUNARABI_DEEP_LINK_HOST': 'app.lunarabi.jp',
          },
        );

        expect(
          result.exitCode,
          0,
          reason: '${result.stdout}\n${result.stderr}',
        );
        for (final name in [
          'Runner.entitlements',
          'Runner.Release.entitlements',
        ]) {
          final entitlements = File(
            '${runnerDir.path}/$name',
          ).readAsStringSync();
          expect(
            plistArrayValues(
              entitlements,
              'com.apple.developer.associated-domains',
            ),
            ['applinks:app.lunarabi.jp'],
          );
        }
      },
    );
  });
}

class PbxProject {
  PbxProject(this.source);

  final String source;

  Map<String, Map<String, String>> runnerBuildSettingsByConfiguration() {
    final runnerTargetId = _objectIdsWithComment('Runner').firstWhere((id) {
      final body = _objectBody(id);
      return body.contains('isa = PBXNativeTarget;') &&
          body.contains('name = Runner;');
    });
    final runnerTargetBody = _objectBody(runnerTargetId);
    final configurationListId = _valueId(
      runnerTargetBody,
      'buildConfigurationList',
    );
    final configurationListBody = _objectBody(configurationListId);
    final configurationIds =
        RegExp(r'([A-Z0-9]+) /\* (Debug|Release|Profile) \*/')
            .allMatches(configurationListBody)
            .map((match) => match.group(1)!)
            .toList();

    return {
      for (final id in configurationIds)
        _configName(_objectBody(id)): _buildSettings(_objectBody(id)),
    };
  }

  List<PbxBuildPhase> runnerBuildPhases() {
    final runnerTargetId = _objectIdsWithComment('Runner').firstWhere((id) {
      final body = _objectBody(id);
      return body.contains('isa = PBXNativeTarget;') &&
          body.contains('name = Runner;');
    });
    final runnerTargetBody = _objectBody(runnerTargetId);
    final buildPhasesMatch = RegExp(
      r'buildPhases = \((?<phases>[\s\S]*?)^\s*\);',
      multiLine: true,
    ).firstMatch(runnerTargetBody);
    if (buildPhasesMatch == null) {
      throw StateError('Runner build phases missing');
    }

    return [
      for (final match in RegExp(
        r'^\s*([A-Z0-9]+) /\* (.*?) \*/,',
        multiLine: true,
      ).allMatches(buildPhasesMatch.namedGroup('phases')!))
        PbxBuildPhase(
          id: match.group(1)!,
          comment: match.group(2)!,
          body: _objectBody(match.group(1)!),
        ),
    ];
  }

  Iterable<String> _objectIdsWithComment(String comment) {
    return RegExp(
      '^\\s*([A-Z0-9]+) /\\* ${RegExp.escape(comment)} \\*/ = \\{',
      multiLine: true,
    ).allMatches(source).map((match) => match.group(1)!);
  }

  String _objectBody(String id) {
    final match = RegExp(
      '^\\s*${RegExp.escape(id)} /\\* .*? \\*/ = \\{',
      multiLine: true,
    ).firstMatch(source);
    if (match == null) {
      throw StateError('pbxproj object not found: $id');
    }

    var index = match.end;
    var depth = 1;
    while (index < source.length) {
      final char = source.codeUnitAt(index);
      if (char == 0x7B) {
        depth++;
      } else if (char == 0x7D) {
        depth--;
        if (depth == 0) {
          return source.substring(match.end, index);
        }
      }
      index++;
    }
    throw StateError('pbxproj object not closed: $id');
  }

  String _valueId(String body, String key) {
    final match = RegExp('$key = ([A-Z0-9]+) /\\*').firstMatch(body);
    if (match == null) {
      throw StateError('pbxproj value missing: $key');
    }
    return match.group(1)!;
  }

  String _configName(String body) {
    final match = RegExp(r'name = (Debug|Profile|Release);').firstMatch(body);
    if (match == null) {
      throw StateError('build configuration name missing');
    }
    return match.group(1)!;
  }

  Map<String, String> _buildSettings(String body) {
    final match = RegExp(
      r'buildSettings = \{(?<settings>[\s\S]*?)^\s*\};',
      multiLine: true,
    ).firstMatch(body);
    if (match == null) {
      throw StateError('buildSettings missing');
    }
    final settings = match.namedGroup('settings')!;
    return {
      for (final line in RegExp(
        r'^\s*([A-Z0-9_]+) = ([^;]+);',
        multiLine: true,
      ).allMatches(settings))
        line.group(1)!: line.group(2)!.replaceAll('"', ''),
    };
  }
}

class PbxBuildPhase {
  const PbxBuildPhase({
    required this.id,
    required this.comment,
    required this.body,
  });

  final String id;
  final String comment;
  final String body;
}

String? plistStringValue(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<string>([^<]+)</string>',
  ).firstMatch(plist);
  return match?.group(1);
}

List<String> plistArrayValues(String plist, String key) {
  final match = RegExp(
    '<key>${RegExp.escape(key)}</key>\\s*<array>([\\s\\S]*?)</array>',
  ).firstMatch(plist);
  if (match == null) {
    return const [];
  }
  return RegExp(
    r'<string>([^<]+)</string>',
  ).allMatches(match.group(1)!).map((match) => match.group(1)!).toList();
}
