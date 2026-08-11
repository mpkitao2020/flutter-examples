import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/features/webview/webview_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Native-only Firebase config (google-services.json / GoogleService-Info.plist).
  // Do not pass FirebaseOptions here.
  await Firebase.initializeApp();

  const rawFlavor = String.fromEnvironment('FLAVOR');
  final flavor = parseFlavor(rawFlavor, isRelease: kReleaseMode);
  final config = AppConfig.fromFlavor(flavor);

  runApp(LunarabiApp(config: config));
}

class LunarabiApp extends StatefulWidget {
  const LunarabiApp({super.key, required this.config});

  final AppConfig config;

  @override
  State<LunarabiApp> createState() => _LunarabiAppState();
}

class _LunarabiAppState extends State<LunarabiApp> {
  late AppConfig _config = widget.config;

  void _switchFlavor(Flavor flavor) {
    setState(() => _config = _config.copyWithFlavor(flavor));
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Lunarabi',
      home: WebViewShell(
        config: _config,
        onSwitchFlavor: kReleaseMode ? null : _switchFlavor,
      ),
    );
  }
}
