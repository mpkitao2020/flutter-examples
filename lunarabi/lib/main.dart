import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:lunarabi/core/env/app_config.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: _PlaceholderHome(
        config: _config,
        onSwitchFlavor: kReleaseMode ? null : _switchFlavor,
      ),
    );
  }
}

/// Temporary home until the WebView shell lands in the next task.
class _PlaceholderHome extends StatelessWidget {
  const _PlaceholderHome({
    required this.config,
    required this.onSwitchFlavor,
  });

  final AppConfig config;
  final ValueChanged<Flavor>? onSwitchFlavor;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Lunarabi (${config.flavor.name})'),
        actions: [
          if (onSwitchFlavor != null)
            PopupMenuButton<Flavor>(
              onSelected: onSwitchFlavor,
              itemBuilder: (context) => [
                for (final flavor in Flavor.values)
                  PopupMenuItem(
                    value: flavor,
                    child: Text(flavor.name),
                  ),
              ],
            ),
        ],
      ),
      body: Center(
        child: Text(config.webBaseUrl.toString()),
      ),
    );
  }
}
