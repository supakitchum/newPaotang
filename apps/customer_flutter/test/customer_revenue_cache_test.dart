import 'package:customer_flutter/features/lottery/data/customer_revenue_cache.dart';
import 'package:customer_flutter/features/tickets/data/ticket_models.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:customer_flutter/features/wallet/data/wallet_models.dart';
import 'package:customer_flutter/features/wallet/data/wallet_repository.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('settled order refreshes cart purchases wallet and tickets', () async {
    var walletLoads = 0;
    var ticketLoads = 0;
    final container = ProviderContainer(
      overrides: [
        walletSummaryProvider.overrideWith((_) async {
          walletLoads++;
          return const WalletSummary(wallets: [], ledger: []);
        }),
        currentTicketsProvider.overrideWith((_) async {
          ticketLoads++;
          return const <CustomerTicket>[];
        }),
      ],
    );
    addTearDown(container.dispose);
    final walletSubscription = container.listen(
      walletSummaryProvider,
      (_, __) {},
      fireImmediately: true,
    );
    final ticketSubscription = container.listen(
      currentTicketsProvider,
      (_, __) {},
      fireImmediately: true,
    );
    addTearDown(walletSubscription.close);
    addTearDown(ticketSubscription.close);

    await container.read(walletSummaryProvider.future);
    await container.read(currentTicketsProvider.future);

    container
        .read(customerRevenueCacheProvider)
        .orderChanged(orderIds: const ['ord_1']);

    await container.read(walletSummaryProvider.future);
    await container.read(currentTicketsProvider.future);

    expect(walletLoads, 2);
    expect(ticketLoads, 2);
    expect(container.read(cartRealtimeTickProvider), 1);
    expect(container.read(ticketRealtimeTickProvider), 1);
    expect(container.read(purchaseHistoryRefreshTickProvider), 1);
  });

  test(
    'pending external order does not refresh settled balance or tickets',
    () async {
      var walletLoads = 0;
      var ticketLoads = 0;
      final container = ProviderContainer(
        overrides: [
          walletSummaryProvider.overrideWith((_) async {
            walletLoads++;
            return const WalletSummary(wallets: [], ledger: []);
          }),
          currentTicketsProvider.overrideWith((_) async {
            ticketLoads++;
            return const <CustomerTicket>[];
          }),
        ],
      );
      addTearDown(container.dispose);
      final walletSubscription = container.listen(
        walletSummaryProvider,
        (_, __) {},
        fireImmediately: true,
      );
      final ticketSubscription = container.listen(
        currentTicketsProvider,
        (_, __) {},
        fireImmediately: true,
      );
      addTearDown(walletSubscription.close);
      addTearDown(ticketSubscription.close);

      await container.read(walletSummaryProvider.future);
      await container.read(currentTicketsProvider.future);

      container
          .read(customerRevenueCacheProvider)
          .orderChanged(
            orderIds: const ['ord_pending'],
            settlementChanged: false,
          );

      await Future<void>.delayed(Duration.zero);

      expect(walletLoads, 1);
      expect(ticketLoads, 1);
      expect(container.read(cartRealtimeTickProvider), 1);
      expect(container.read(ticketRealtimeTickProvider), 0);
      expect(container.read(purchaseHistoryRefreshTickProvider), 1);
    },
  );
}
