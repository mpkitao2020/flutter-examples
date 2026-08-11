import 'package:lunarabi/core/navigation/app_navigator.dart';

/// Parses FCM data payload `link` and applies [HostGuard].
Uri? parseNotificationLink(Map<String, dynamic> data, HostGuard guard) {
  final raw = data['link'];
  if (raw is! String) return null;
  final uri = Uri.tryParse(raw);
  if (uri == null) return null;
  if (!guard.isAllowed(uri)) return null;
  return uri;
}

abstract interface class PushBackendClient {
  Future<void> register(String token);
}

class LoggingPushBackendClient implements PushBackendClient {
  @override
  Future<void> register(String token) async {
    final masked =
        token.length <= 6 ? '***' : '***${token.substring(token.length - 6)}';
    // ignore: avoid_print
    print('PushBackendClient.register: $masked');
  }
}
