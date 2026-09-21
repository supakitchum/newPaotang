import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/realtime/customer_revenue_refresh_ticks.dart';
import '../../purchase_history/data/purchase_history_repository.dart';
import '../../tickets/data/ticket_repository.dart';
import '../../wallet/data/wallet_repository.dart';

export '../../../core/realtime/customer_revenue_refresh_ticks.dart';

final customerRevenueCacheProvider = Provider<CustomerRevenueCache>((ref) {
  return CustomerRevenueCache(ref);
});

class CustomerRevenueCache {
  const CustomerRevenueCache(this._ref);

  final Ref<CustomerRevenueCache> _ref;

  void cartChanged() {
    _ref.read(cartRealtimeTickProvider.notifier).state++;
  }

  void ticketsChanged({Iterable<String> ticketIds = const []}) {
    _ref.invalidate(currentTicketsProvider);
    for (final ticketId in _normalizedIds(ticketIds)) {
      _ref.invalidate(ticketDetailProvider(ticketId));
    }
    _ref.read(ticketRealtimeTickProvider.notifier).state++;
  }

  void orderChanged({
    Iterable<String> orderIds = const [],
    Iterable<String> ticketIds = const [],
    bool settlementChanged = true,
    bool invalidateOrderDetails = true,
  }) {
    cartChanged();
    _ref.read(purchaseHistoryRefreshTickProvider.notifier).state++;

    if (invalidateOrderDetails) {
      for (final orderId in _normalizedIds(orderIds)) {
        _ref.invalidate(purchaseHistoryDetailProvider(orderId));
      }
    }

    if (!settlementChanged) return;

    _ref.invalidate(walletSummaryProvider);
    ticketsChanged(ticketIds: ticketIds);
  }
}

Set<String> _normalizedIds(Iterable<String> values) {
  return values
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet();
}
