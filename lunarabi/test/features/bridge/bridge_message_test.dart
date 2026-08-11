// =============================================================================
// BridgeMessage の encode / decode テスト
// =============================================================================
//
// Web と Flutter は JSON 文字列で会話する。
// ここで「型が崩れたときに例外になる」「requestId が往復する」を固定する。
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:lunarabi/features/bridge/bridge_message.dart';

void main() {
  test('toJson / fromJson で type・payload・requestId が往復する', () {
    // Arrange
    const original = BridgeMessage(
      type: BridgeTypes.navSetBadge,
      payload: {'id': 'notify', 'count': 3},
      requestId: 'req-1',
    );

    // Act
    final roundTrip = BridgeMessage.fromJson(original.toJson());

    // Assert
    expect(roundTrip.type, BridgeTypes.navSetBadge);
    expect(roundTrip.payload['id'], 'notify');
    expect(roundTrip.payload['count'], 3);
    expect(roundTrip.requestId, 'req-1');
  });

  test('decode は JSON 文字列からメッセージを復元する', () {
    final message = BridgeMessage.decode(
      '{"type":"nav.setVisible","payload":{"visible":false}}',
    );
    expect(message.type, BridgeTypes.navSetVisible);
    expect(message.payload['visible'], isFalse);
    expect(message.requestId, isNull);
  });

  test('type が無い JSON は FormatException', () {
    expect(
      () => BridgeMessage.decode('{"payload":{}}'),
      throwsA(isA<FormatException>()),
    );
  });
}
