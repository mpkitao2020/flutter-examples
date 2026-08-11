import 'dart:async';

import 'package:lunarabi/features/payments/gmo_link_payment.dart';

/// Serializes GMO completer dispose → attach so two listeners never overlap.
class GmoCompleterLifecycle {
  Future<void> _chain = Future<void>.value();
  GmoLinkPayment? _current;

  GmoLinkPayment? get current => _current;

  /// Queues dispose of the previous instance then attach of [next].
  Future<void> rebind(GmoLinkPayment next) {
    final previous = _current;
    _current = next;
    _chain = _chain.then((_) async {
      await previous?.dispose();
      if (!identical(_current, next)) return;
      await next.attachCompleter();
    });
    return _chain;
  }

  /// Completes when the latest queued rebind finishes.
  Future<void> get ready => _chain;

  Future<void> clear() {
    final previous = _current;
    _current = null;
    _chain = _chain.then((_) async {
      await previous?.dispose();
    });
    return _chain;
  }
}
