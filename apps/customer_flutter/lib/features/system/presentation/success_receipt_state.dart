import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../lottery/data/lottery_models.dart';
import '../../purchase_history/data/purchase_history_models.dart';

final successReceiptFallbackOrderProvider =
    StateProvider<PurchaseHistoryOrder?>((ref) => null);

PurchaseHistoryOrder successReceiptFallbackFromCheckout({
  required LotteryCheckoutOrder order,
  required LotteryCart cart,
}) {
  final firstItem = cart.items.isEmpty ? null : cart.items.first;
  final storeName = (firstItem?.storeName.trim().isNotEmpty == true
          ? firstItem!.storeName
          : firstItem?.sellerName)
      ?.trim();
  final total = order.total > 0 ? order.total : cart.total;
  final ticketCount =
      order.ticketCount > 0 ? order.ticketCount : cart.itemCount;
  return PurchaseHistoryOrder.fromJson({
    'id': order.id,
    'reference': order.reference,
    'status': order.status,
    'payment_status': order.paymentStatus,
    'payment_method': order.paymentMethod,
    'total': total,
    'ticket_count': ticketCount,
    'paid_at': order.paidAt,
    if (storeName != null && storeName.isNotEmpty) 'store': {'name': storeName},
    'tickets': [
      for (final item in cart.items)
        {
          'id': item.id,
          'full_number': item.number,
          'status': item.status,
        },
    ],
  });
}

PurchaseHistoryOrder? successReceiptFallbackForOrderId(
  PurchaseHistoryOrder? fallback,
  String orderId,
) {
  if (fallback == null) return null;
  final id = orderId.trim();
  if (id.isEmpty ||
      fallback.id == id ||
      fallback.reference == id ||
      fallback.displayReference == id) {
    return fallback;
  }
  return null;
}
