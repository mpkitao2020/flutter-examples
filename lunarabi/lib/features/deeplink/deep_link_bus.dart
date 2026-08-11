import 'dart:async';

import 'package:lunarabi/features/deeplink/deep_link_parser.dart';

/// Broadcast bus that keeps the latest event until the first subscriber
/// appears (cold start), then switches to live fan-out.
class DeepLinkBus {
  final StreamController<ParsedDeepLink> _controller =
      StreamController<ParsedDeepLink>.broadcast();
  ParsedDeepLink? _pending;
  var _live = false;

  Stream<ParsedDeepLink> get stream {
    return Stream<ParsedDeepLink>.multi((listener) {
      final pending = _pending;
      if (!_live && pending != null) {
        _live = true;
        _pending = null;
        listener.add(pending);
      } else {
        _live = true;
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
    if (!_live) {
      _pending = link;
      return;
    }
    _controller.add(link);
  }

  Future<void> dispose() => _controller.close();
}
