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

  static AppConfig resolve({
    required bool isRelease,
    String rawFlavor = const String.fromEnvironment('FLAVOR'),
    String webBaseUrlDefine = const String.fromEnvironment(
      'LUNARABI_WEB_BASE_URL',
    ),
    String apiBaseUrlDefine = const String.fromEnvironment(
      'LUNARABI_API_BASE_URL',
    ),
    String deepLinkHostDefine = const String.fromEnvironment(
      'LUNARABI_DEEP_LINK_HOST',
    ),
  }) {
    final flavor = parseFlavor(rawFlavor, isRelease: isRelease);
    final defaults = AppConfig.fromFlavor(flavor);
    return AppConfig(
      flavor: flavor,
      webBaseUrl: _resolveHttpsUrl(
        'LUNARABI_WEB_BASE_URL',
        webBaseUrlDefine,
        fallback: defaults.webBaseUrl,
      ),
      apiBaseUrl: _resolveHttpsUrl(
        'LUNARABI_API_BASE_URL',
        apiBaseUrlDefine,
        fallback: defaults.apiBaseUrl,
      ),
      deepLinkHost: _resolveDeepLinkHost(
        deepLinkHostDefine,
        fallback: defaults.deepLinkHost,
      ),
    );
  }

  void assertReleaseHosts() {
    _assertReleaseHost('LUNARABI_WEB_BASE_URL', webBaseUrl.host);
    _assertReleaseHost('LUNARABI_API_BASE_URL', apiBaseUrl.host);
    _assertReleaseHost('LUNARABI_DEEP_LINK_HOST', deepLinkHost);
  }
}

Uri _resolveHttpsUrl(String key, String value, {required Uri fallback}) {
  if (value.isEmpty) return fallback;
  final uri = Uri.tryParse(value);
  if (uri == null ||
      !uri.isAbsolute ||
      uri.scheme != 'https' ||
      uri.host.isEmpty) {
    throw FormatException('$key must be an absolute https URL', value);
  }
  return uri;
}

String _resolveDeepLinkHost(String value, {required String fallback}) {
  if (value.isEmpty) return fallback;
  if (value.trim() != value ||
      value.contains('://') ||
      value.contains('/') ||
      value.contains(r'\') ||
      value.contains(':')) {
    throw FormatException(
      'LUNARABI_DEEP_LINK_HOST must be a host without scheme, port, or path',
      value,
    );
  }
  final probe = Uri.tryParse('https://$value');
  if (probe == null || probe.host != value || probe.host.isEmpty) {
    throw FormatException('LUNARABI_DEEP_LINK_HOST must be host-only', value);
  }
  return value;
}

void _assertReleaseHost(String key, String host) {
  final normalized = host.toLowerCase();
  if (normalized.isEmpty ||
      normalized == 'localhost' ||
      normalized.endsWith('.localhost') ||
      normalized.endsWith('.example') ||
      normalized.endsWith('.invalid')) {
    throw StateError('$key is not a production host: $host');
  }
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
