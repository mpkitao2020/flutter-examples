import 'dart:async';

import 'package:lunarabi/features/deeplink/deep_link_parser.dart';

/// Broadcast bus that buffers the latest event while there are no listeners
/// (cold start and brief rebind windows), then fans out live.
class DeepLinkBus {
  final StreamController<ParsedDeepLink> _controller =
      StreamController<ParsedDeepLink>.broadcast();
  ParsedDeepLink? _pending;

  Stream<ParsedDeepLink> get stream {
    return Stream<ParsedDeepLink>.multi((listener) {
      final pending = _pending;
      if (pending != null) {
        _pending = null;
        listener.add(pending);
      }

      final sub = _controller.stream.listen(
        listener.add,
        onError: listener.addError,
        onDone: listener.close,
      );
      listener.onCancel = () async {
        await sub.cancel();
      };
    });
  }

  void publish(ParsedDeepLink link) {
    if (!_controller.hasListener) {
      _pending = link;
      return;
    }
    _controller.add(link);
  }

  Future<void> dispose() => _controller.close();
}
