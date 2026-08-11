import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/core/env/app_config.dart';
import 'package:lunarabi/main.dart';

void main() {
  testWidgets('shows web base URL from config', (tester) async {
    final config = AppConfig.fromFlavor(Flavor.dev);
    await tester.pumpWidget(LunarabiApp(config: config));
    expect(find.text('https://dev.lunarabi.example'), findsOneWidget);
  });
}
