import 'package:flutter/foundation.dart';

enum NavTabId { home, search, notify, account }

extension NavTabIdX on NavTabId {
  String get wireId => name;

  static NavTabId? tryParse(String? raw) {
    if (raw == null) return null;
    for (final id in NavTabId.values) {
      if (id.name == raw) return id;
    }
    return null;
  }
}

class BottomNavController extends ChangeNotifier {
  bool _visible = true;
  NavTabId _active = NavTabId.home;
  final Map<NavTabId, int> _badges = {
    for (final id in NavTabId.values) id: 0,
  };

  bool get visible => _visible;
  NavTabId get active => _active;
  Map<NavTabId, int> get badges => Map.unmodifiable(_badges);

  int badgeOf(NavTabId id) => _badges[id] ?? 0;

  void setVisible(bool value) {
    if (_visible == value) return;
    _visible = value;
    notifyListeners();
  }

  void setActive(NavTabId id) {
    if (_active == id) return;
    _active = id;
    notifyListeners();
  }

  void setBadge(NavTabId id, int count) {
    final normalized = count < 0 ? 0 : count;
    if (_badges[id] == normalized) return;
    _badges[id] = normalized;
    notifyListeners();
  }
}
