import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:customer_flutter/features/topup/presentation/topup_realtime_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile realtime config requires an explicit public URL', () {
    final disabled = MobileRealtimeConfig.fromJson({
      'enabled': true,
      'key': 'newpaotang-customer',
    });
    final enabled = MobileRealtimeConfig.fromJson({
      'enabled': true,
      'url': 'https://realtime.example.com',
      'key': 'tenant-key',
    });

    expect(disabled.configured, isFalse);
    expect(enabled.configured, isTrue);
    expect(enabled.authEndpoint, '/customer/realtime/auth');
  });

  test('buildRealtimeSocketUri mirrors Pusher protocol URL rules', () {
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'https://realtime.example.com',
        key: 'tenant key',
      ).toString(),
      'wss://realtime.example.com/app/tenant%20key?protocol=7&client=newpaotang-customer&version=1.0&flash=false',
    );
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'ws://localhost:8080/app/existing?protocol=7',
        key: 'ignored',
      ).toString(),
      'ws://localhost:8080/app/existing?protocol=7',
    );
  });

  test('realtime message parser normalizes events and nested data', () {
    final message = parseRealtimeMessage(
      '{"event":".stock.availability.updated","channel":"customer.tenant.ten.stock.game.game_1","data":"{\\"available\\":5}"}',
    );

    expect(message.normalizedEvent, 'stock.availability.updated');
    expect(message.dataMap['available'], 5);
    expect(parseRealtimeData('plain text'), {'value': 'plain text'});
  });

  test('customer realtime channel names match Nuxt customer channels', () {
    expect(
      stockAvailabilityChannel(tenantId: 'ten_1', gameId: 'game_1'),
      'customer.tenant.ten_1.stock.game.game_1',
    );
    expect(
      salePriceChannel(tenantId: 'ten_1'),
      'customer.tenant.ten_1.sale-price',
    );
    expect(
      siteConfigChannel(tenantId: 'ten_1'),
      'customer.tenant.ten_1.site-config',
    );
    expect(
      customerTopupChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.topups',
    );
    expect(
      customerRewardClaimChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
    );
    expect(
      customerActivityClaimChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.activity-claims',
    );
    expect(
      customerPresenceChannel(tenantId: 'ten_1'),
      'presence-customer.tenant.ten_1.customers',
    );
    expect(publicLatestResultChannel(), 'public.results.latest');
    expect(
      publicGameResultChannel(gameId: 'game_1'),
      'public.results.game.game_1',
    );
    expect(
      isAuthorizedRealtimeChannel('private-customer.tenant.ten_1'),
      isTrue,
    );
    expect(
      isAuthorizedRealtimeChannel('presence-customer.tenant.ten_1'),
      isTrue,
    );
    expect(isAuthorizedRealtimeChannel('customer.tenant.ten_1'), isFalse);
  });

  test('lottery stock realtime events refresh only relevant stock state', () {
    expect(
      shouldRefreshLotteryStockFromRealtimeEvent(
        event: const CustomerRealtimeEvent(
          name: 'stock.availability.updated',
          channel: 'customer.tenant.ten_1.stock.game.game_1',
          payload: {'game_id': 'game_2'},
        ),
        gameId: 'game_1',
      ),
      isTrue,
    );
    expect(
      shouldRefreshLotteryStockFromRealtimeEvent(
        event: const CustomerRealtimeEvent(
          name: 'stock.price.updated',
          channel: 'customer.tenant.ten_1.sale-price',
          payload: {'game_id': 'game_1'},
        ),
        gameId: 'game_1',
      ),
      isTrue,
    );
    expect(
      shouldRefreshLotteryStockFromRealtimeEvent(
        event: const CustomerRealtimeEvent(
          name: 'stock.price.updated',
          channel: 'customer.tenant.ten_1.sale-price',
          payload: {'game_id': 'game_2'},
        ),
        gameId: 'game_1',
      ),
      isFalse,
    );
  });

  test('topup realtime refreshes only topup update events', () {
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'topup.updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.topups',
          payload: {'id': 'top_1'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'stock.availability.updated',
          channel: 'customer.tenant.ten_1.stock.game.game_1',
          payload: {},
        ),
      ),
      isFalse,
    );
  });

  test('claim realtime refreshes claim update events and extracts claim ids',
      () {
    expect(
      shouldRefreshRewardClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'reward.claim.updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
          payload: {'claim_id': 'rcl_1'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshActivityClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'activity.claim.updated',
          channel:
              'private-customer.tenant.ten_1.customer.cus_1.activity-claims',
          payload: {
            'claim': {'id': 'acl_1'},
          },
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshRewardClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'topup.updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.topups',
          payload: {},
        ),
      ),
      isFalse,
    );
    expect(claimIdFromRealtimePayload({'claim_id': 'rcl_1'}), 'rcl_1');
    expect(
      claimIdFromRealtimePayload({
        'claim': {'id': 'acl_1'},
      }),
      'acl_1',
    );
  });
}
