/// FIFO set with a hard size cap to bound process-lifetime growth.
class HandledIdSet {
  HandledIdSet({this.maxSize = 64}) : assert(maxSize > 0);

  final int maxSize;
  final List<String> _order = [];
  final Set<String> _set = {};

  bool contains(String id) => _set.contains(id);

  void add(String id) {
    if (_set.contains(id)) return;
    _set.add(id);
    _order.add(id);
    while (_order.length > maxSize) {
      final oldest = _order.removeAt(0);
      _set.remove(oldest);
    }
  }

  bool remove(String id) {
    final removed = _set.remove(id);
    if (removed) {
      _order.remove(id);
    }
    return removed;
  }

  int get length => _set.length;
}
