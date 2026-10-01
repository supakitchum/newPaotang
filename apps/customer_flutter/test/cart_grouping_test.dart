import 'package:customer_flutter/features/lottery/data/lottery_models.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_screens.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('cart grouping merges same lottery number across reservations', () {
    final groups = groupCartReservationsByNumber([
      _reservation(
        id: 'res_late',
        expiresAt: '2026-06-29T12:40:00+07:00',
        items: [
          _item('273707', localStockItemId: 'stock_1'),
        ],
      ),
      _reservation(
        id: 'res_early',
        expiresAt: '2026-06-29T12:30:00+07:00',
        items: [
          _item('273707', localStockItemId: 'stock_2'),
        ],
      ),
      _reservation(
        id: 'res_other',
        expiresAt: '2026-06-29T12:35:00+07:00',
        items: [
          _item('999999', localStockItemId: 'stock_3'),
        ],
      ),
    ]);

    expect(groups, hasLength(2));
    expect(groups.first.number, '273707');
    expect(groups.first.count, 2);
    expect(groups.first.reservationIds, ['res_late', 'res_early']);
    expect(groups.first.total, 160);
    expect(groups.first.deadlineReservation?.id, 'res_early');
    expect(groups.last.number, '999999');
  });
}

LotteryReservation _reservation({
  required String id,
  required String expiresAt,
  required List<Map<String, dynamic>> items,
}) {
  return LotteryReservation.fromJson({
    'id': id,
    'game_id': 'game_1',
    'status': 'active',
    'expires_at': expiresAt,
    'server_time': '2026-06-29T12:00:00+07:00',
    'items': items,
    'total': {'amount': items.length * 8000, 'currency': 'THB'},
  });
}

Map<String, dynamic> _item(
  String number, {
  required String localStockItemId,
}) {
  return {
    'id': 'vstock:game_1:$number:$localStockItemId',
    'local_stock_item_id': localStockItemId,
    'full_number': number,
    'store_name': 'ร้านทดสอบ',
    'price': {'amount': 8000, 'currency': 'THB'},
  };
}
