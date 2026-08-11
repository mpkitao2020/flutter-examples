// =============================================================================
// HandledIdSet — FIFO 上限
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/payments/handled_id_set.dart';

void main() {
  test('maxSize を超えると最古が消える', () {
    final set = HandledIdSet(maxSize: 2);
    set.add('a');
    set.add('b');
    set.add('c');

    expect(set.contains('a'), isFalse);
    expect(set.contains('b'), isTrue);
    expect(set.contains('c'), isTrue);
    expect(set.length, 2);
  });

  test('重複 add は順序を進めない', () {
    final set = HandledIdSet(maxSize: 2);
    set.add('a');
    set.add('a');
    set.add('b');
    expect(set.length, 2);
    expect(set.contains('a'), isTrue);
  });

  test('remove 後は再 add できる', () {
    final set = HandledIdSet(maxSize: 2);
    set.add('a');
    expect(set.remove('a'), isTrue);
    set.add('b');
    set.add('c');
    expect(set.contains('a'), isFalse);
    expect(set.contains('b'), isTrue);
  });
}
