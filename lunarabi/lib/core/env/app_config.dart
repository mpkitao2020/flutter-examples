enum Flavor { dev, stg, prod }

class AppConfig {
  const AppConfig({
    required this.flavor,
    required this.webBaseUrl,
    required this.apiBaseUrl,
    required this.deepLinkHost,
  });

  final Flavor flavor;
  final Uri webBaseUrl;
  final Uri apiBaseUrl;
  final String deepLinkHost;

  static AppConfig fromFlavor(Flavor flavor) {
    return switch (flavor) {
      Flavor.dev => AppConfig(
          flavor: Flavor.dev,
          webBaseUrl: Uri.parse('https://dev.lunarabi.example'),
          apiBaseUrl: Uri.parse('https://api-dev.lunarabi.example'),
          deepLinkHost: 'app.lunarabi.example',
        ),
      Flavor.stg => AppConfig(
          flavor: Flavor.stg,
          webBaseUrl: Uri.parse('https://stg.lunarabi.example'),
          apiBaseUrl: Uri.parse('https://api-stg.lunarabi.example'),
          deepLinkHost: 'app.lunarabi.example',
        ),
      Flavor.prod => AppConfig(
          flavor: Flavor.prod,
          webBaseUrl: Uri.parse('https://www.lunarabi.example'),
          apiBaseUrl: Uri.parse('https://api.lunarabi.example'),
          deepLinkHost: 'app.lunarabi.example',
        ),
    };
  }

  AppConfig copyWithFlavor(Flavor flavor) => AppConfig.fromFlavor(flavor);
}

/// Maps `--dart-define=FLAVOR=` raw string to [Flavor].
///
/// Empty / unknown values fall back to [Flavor.prod] in release builds and
/// [Flavor.dev] otherwise.
Flavor parseFlavor(String raw, {required bool isRelease}) {
  return switch (raw) {
    'dev' => Flavor.dev,
    'stg' => Flavor.stg,
    'prod' => Flavor.prod,
    _ => isRelease ? Flavor.prod : Flavor.dev,
  };
}
