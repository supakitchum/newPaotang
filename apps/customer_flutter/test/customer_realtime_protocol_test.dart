import 'package:customer_flutter/core/realtime/customer_realtime_client.dart';
import 'package:customer_flutter/core/realtime/customer_realtime_protocol.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/features/lottery/presentation/customer_revenue_realtime_monitor.dart';
import 'package:customer_flutter/features/lottery/presentation/lottery_stock_realtime_monitor.dart';
import 'package:customer_flutter/features/reward_claims/presentation/claim_realtime_monitor.dart';
import 'package:customer_flutter/features/topup/presentation/topup_realtime_monitor.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile realtime config requires an explicit public URL', () {
    final disabled = MobileRealtimeConfig.fromJson({
      'enabled': true,
      'key': 'tenant-key',
    });
    final missingKey = MobileRealtimeConfig.fromJson({
      'enabled': true,
      'url': 'https://realtime.example.com',
    });
    final enabled = MobileRealtimeConfig.fromJson({
      'enabled': true,
      'url': 'https://realtime.example.com',
      'key': 'tenant-key',
    });

    expect(disabled.configured, isFalse);
    expect(missingKey.configured, isFalse);
    expect(enabled.configured, isTrue);
    expect(enabled.authEndpoint, '/customer/realtime/auth');
    expect(enabled.client, 'customer-flutter');

    final boAliases = MobileRealtimeConfig.fromJson({
      'enabled': true,
      'websocketUrl': 'https://socket.example.com',
      'pusherAppKey': 'tenant-key',
      'channelAuthEndpoint': '/mobile/realtime/auth',
    });
    expect(boAliases.configured, isTrue);
    expect(boAliases.url, 'https://socket.example.com');
    expect(boAliases.key, 'tenant-key');
    expect(boAliases.authEndpoint, '/mobile/realtime/auth');
  });

  test('buildRealtimeSocketUri mirrors Pusher protocol URL rules', () {
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'https://realtime.example.com',
        key: 'tenant key',
      ).toString(),
      'wss://realtime.example.com/app/tenant%20key?protocol=7&client=customer-flutter&version=1.0&flash=false',
    );
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'wss://realtime.example.com/app',
        key: 'tenant-key',
      ).toString(),
      'wss://realtime.example.com/app/tenant-key?protocol=7&client=customer-flutter&version=1.0&flash=false',
    );
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'https://realtime.example.com/ws/',
        key: 'tenant key',
      ).toString(),
      'wss://realtime.example.com/ws/app/tenant%20key?protocol=7&client=customer-flutter&version=1.0&flash=false',
    );
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'https://realtime.example.com/app/existing?cluster=ap1',
        key: 'ignored',
      ).toString(),
      'wss://realtime.example.com/app/existing?cluster=ap1&protocol=7&client=customer-flutter&version=1.0&flash=false',
    );
    expect(
      buildRealtimeSocketUri(
        baseUrl: 'ws://localhost:8080/app/existing?protocol=7',
        key: 'ignored',
      ).toString(),
      'ws://localhost:8080/app/existing?protocol=7',
    );
  });

  test('buildRealtimeSocketUri rejects missing runtime app key', () {
    expect(
      () => buildRealtimeSocketUri(
        baseUrl: 'https://realtime.example.com',
        key: '',
      ),
      throwsA(isA<ArgumentError>()),
    );
  });

  test('realtime message parser normalizes events and nested data', () {
    final message = parseRealtimeMessage(
      '{"event":".stock.availability.updated","channel":"customer.tenant.ten.stock.game.game_1","data":"{\\"available\\":5}"}',
    );

    expect(message.normalizedEvent, 'stock.availability.updated');
    expect(message.dataMap['available'], 5);
    expect(parseRealtimeData('plain text'), {'value': 'plain text'});

    final aliasedMessage = parseRealtimeMessage({
      'eventName': 'bridge.message',
      'channelName': 'private-customer.tenant.ten_1.customer.cus_1.wallet',
      'payload_json':
          '{"event_type":"wallet.ledger.updated","wallet_id":"wal_1","metadata":{"details":{"ledgerId":"led_1"}}}',
    });
    expect(aliasedMessage.event, 'bridge.message');
    expect(
      aliasedMessage.channel,
      'private-customer.tenant.ten_1.customer.cus_1.wallet',
    );
    expect(aliasedMessage.dataMap['wallet_id'], 'wal_1');
    expect(aliasedMessage.dataMap['ledgerId'], 'led_1');
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: aliasedMessage.event,
        payload: aliasedMessage.dataMap,
      ),
      'topup.updated',
    );

    final nestedMessage = parseRealtimeMessage({
      'name': 'sync.outbox',
      'subscription': {
        'channelName':
            'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
      },
      'messagePayload': {
        'eventName': 'reward.claim.paid',
        'rewardClaimId': 'rcl_1',
      },
    });
    expect(nestedMessage.event, 'sync.outbox');
    expect(
      nestedMessage.channel,
      'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
    );
    expect(nestedMessage.dataMap['rewardClaimId'], 'rcl_1');
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: nestedMessage.event,
        payload: nestedMessage.dataMap,
      ),
      'reward.claim.updated',
    );

    final groupedEnvelopeMessage = parseRealtimeMessage({
      'channelInfo': {
        'channelName': {
          'label': 'private-customer.tenant.ten_1.customer.cus_1.orders',
        },
      },
      'messageEnvelope': {
        'eventEnvelope': {
          'eventLabel': {'rawValue': 'order.paid.v1'},
        },
        'dataEnvelope': {
          'ticketIds': ['tic_grouped'],
          'orderId': 'ord_grouped',
        },
      },
    });
    expect(groupedEnvelopeMessage.event, 'order.paid.v1');
    expect(
      groupedEnvelopeMessage.channel,
      'private-customer.tenant.ten_1.customer.cus_1.orders',
    );
    expect(groupedEnvelopeMessage.dataMap['ticketIds'], ['tic_grouped']);
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: groupedEnvelopeMessage.event,
        payload: groupedEnvelopeMessage.dataMap,
      ),
      'order.updated',
    );

    final siblingContextMessage = parseRealtimeMessage({
      'eventName': 'bridge.message',
      'channelName':
          'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
      'payload': {
        'eventName': 'reward.claim.paid',
      },
      'metadata': {
        'object': {
          'rewardClaimId': 'rcl_sibling',
          'ticket': {'id': 'tic_sibling'},
        },
      },
    });
    expect(siblingContextMessage.event, 'bridge.message');
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: siblingContextMessage.event,
        payload: siblingContextMessage.dataMap,
      ),
      'reward.claim.updated',
    );
    expect(
      claimIdFromRealtimePayload(siblingContextMessage.dataMap),
      'rcl_sibling',
    );
    expect(
      ticketIdFromRewardClaimRealtimePayload(siblingContextMessage.dataMap),
      'tic_sibling',
    );

    final topLevelPayloadMessage = parseRealtimeMessage({
      'event_type': 'order.paid.v1',
      'channel': 'private-customer.tenant.ten_1.customer.cus_1.orders',
      'ticketIds': ['tic_1'],
    });
    expect(topLevelPayloadMessage.event, 'order.paid.v1');
    expect(topLevelPayloadMessage.dataMap['ticketIds'], ['tic_1']);
    expect(
      normalizeRealtimeEventName('StockAvailabilityUpdated'),
      'stock.availability.updated',
    );
    expect(
      normalizeRealtimeEventName('stock.sold.v1'),
      'stock.availability.updated',
    );
    expect(
      normalizeRealtimeEventName('stock.unavailable.v1'),
      'stock.availability.updated',
    );
    expect(
      normalizeRealtimeEventName(
        r'App\Modules\Reward\Events\RewardClaimUpdated',
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventName('reward_result_live_updated'),
      'reward.result.live.updated',
    );
    expect(
      normalizeRealtimeEventName('reward.published.v1'),
      'reward.result.live.updated',
    );
    expect(
      normalizeRealtimeEventName('maintenance.changed.v1'),
      'site-config.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {'event_type': 'stock.sold.v1'},
      ),
      'stock.availability.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {
          'event_type': {'value': 'stock.sold.v1'},
        },
      ),
      'stock.availability.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {'broadcastAs': 'cart.reservation.expired'},
      ),
      'cart.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {'domainEventName': 'customer.wallet.balance.updated'},
      ),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {'messageName': 'reward.claim.approved'},
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {'notificationName': 'activity.claim.rejected'},
      ),
      'activity.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {
          'payload': {
            'action': 'order.paid.v1',
            'order_id': 'ord_1',
          },
        },
      ),
      'order.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {
          'payload': {
            'action': {'code': 'order.paid.v1'},
            'order_id': 'ord_1',
          },
        },
      ),
      'order.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'data': '{"event":"reward.claim.updated","claim_id":"rcl_nested"}',
        },
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'data':
              '{"event":{"value":"reward.claim.updated"},"claim_id":"rcl_object"}',
        },
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'envelope': {
            'messageData': {
              'broadcast_as': {'code': 'reward.claim.failed'},
            },
          },
        },
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'notificationData':
              '{"domainEvent":"activity.claim.cancelled","claim_id":"acl_1"}',
        },
      ),
      'activity.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'messagePayload': {
            'eventKey': 'customer.wallet.ledger.updated',
          },
        },
      ),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'type': 'notification',
          'payload': {
            'event_type': 'wallet.updated.v1',
          },
        },
      ),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'type': 'notification',
          'payload': {
            'event': {'key': 'wallet.updated.v1'},
          },
        },
      ),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'site-config.updated',
        payload: {'event_type': 'stock.sold.v1'},
      ),
      'site-config.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {
          'payload_json':
              '{"event_type":"reward.published.v1","game_id":"game_outbox"}',
        },
      ),
      'reward.result.live.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {
          'metadata': {
            'eventClass': r'App\Modules\Topups\Events\CustomerTopupUpdated',
            'details': {'topupId': 'top_meta'},
          },
        },
      ),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'context': {
            'class_name': r'App\Modules\Rewards\Events\CustomerRewardClaimPaid',
            'object': {'rewardClaimId': 'rcl_meta'},
          },
        },
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'bridge.message',
        payload: {
          'context': {
            'class_name': {
              'value': r'App\Modules\Rewards\Events\CustomerRewardClaimPaid',
            },
            'object': {'rewardClaimId': 'rcl_object'},
          },
        },
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimePayload({
        'event': 'bridge.message',
        'payload': '{"ticketIds":["tic_wrapped"],"gameId":"game_wrapped"}',
      }),
      containsPair('ticketIds', ['tic_wrapped']),
    );
    expect(
      normalizeRealtimePayload({
        'event_type': 'order.paid.v1',
        'payload_json': '{"ticket_ids":["tic_outbox"],"game_id":"game_outbox"}',
      }),
      containsPair('ticket_ids', ['tic_outbox']),
    );
    expect(
      normalizeRealtimePayload({
        'event': 'bridge.message',
        'metadata':
            '{"details":{"ticketIds":["tic_meta"],"rewardClaimId":"rcl_meta"}}',
      }),
      containsPair('ticketIds', ['tic_meta']),
    );
    expect(
      normalizeRealtimePayload({
        'recordEnvelope': {
          'outboxMessage': {
            'eventText': {'text': 'reward.claim.approved'},
            'payloadEnvelope': {
              'rewardClaimId': 'rcl_envelope',
              'ticketId': 'tic_envelope',
            },
          },
        },
      }),
      containsPair('rewardClaimId', 'rcl_envelope'),
    );
    expect(
      normalizeRealtimeEventNameWithPayload(
        eventName: 'sync.outbox',
        payload: {
          'recordEnvelope': {
            'outboxMessage': {
              'eventText': {'text': 'reward.claim.approved'},
              'payloadEnvelope': {'rewardClaimId': 'rcl_envelope'},
            },
          },
        },
      ),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventName('customer.topup.status.updated'),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventName('wallet.balance.updated'),
      'topup.updated',
    );
    expect(normalizeRealtimeEventName('wallet.updated.v1'), 'topup.updated');
    expect(
      normalizeRealtimeEventName('wallet.transaction.created'),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventName('wallet.ledger.entry.updated'),
      'topup.updated',
    );
    expect(
      normalizeRealtimeEventName('reservation.released.v1'),
      'cart.updated',
    );
    expect(
      normalizeRealtimeEventName('reservation.expired.v1'),
      'cart.updated',
    );
    expect(normalizeRealtimeEventName('order.paid.v1'), 'order.updated');
    expect(
      normalizeRealtimeEventName('customer.ticket.updated'),
      'tickets.updated',
    );
    expect(
      normalizeRealtimeEventName('reward_claim_status_updated'),
      'reward.claim.updated',
    );
    expect(
      normalizeRealtimeEventName('activity.claim.paid'),
      'activity.claim.updated',
    );
    expect(
      normalizeRealtimeEventName('result.published'),
      'reward.result.live.updated',
    );
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
      customerWalletChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.wallet',
    );
    expect(
      customerCartChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.cart',
    );
    expect(
      customerOrdersChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.orders',
    );
    expect(
      customerTicketsChannel(tenantId: 'ten_1', customerId: 'cus_1'),
      'private-customer.tenant.ten_1.customer.cus_1.tickets',
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

  test('revenue realtime events refresh cart and ticket surfaces', () {
    const cartChannel = 'private-customer.tenant.ten_1.customer.cus_1.cart';
    const ordersChannel = 'private-customer.tenant.ten_1.customer.cus_1.orders';
    const ticketsChannel =
        'private-customer.tenant.ten_1.customer.cus_1.tickets';

    final cartEvent = CustomerRealtimeEvent(
      name: 'reservation.expired.v1',
      channel: cartChannel,
      payload: const {'reservation_id': 'res_1'},
    );
    expect(shouldRefreshCartFromRealtimeEvent(cartEvent), isTrue);
    expect(shouldRefreshTicketsFromRealtimeEvent(cartEvent), isFalse);

    final wrappedOrderEvent = CustomerRealtimeEvent(
      name: 'sync.outbox',
      channel: ordersChannel,
      payload: const {
        'payload': {
          'action': 'order.paid.v1',
          'ticketIds': ['tic_nested'],
        },
      },
    );
    expect(shouldRefreshCartFromRealtimeEvent(wrappedOrderEvent), isTrue);
    expect(shouldRefreshTicketsFromRealtimeEvent(wrappedOrderEvent), isTrue);
    expect(ticketIdsFromRealtimePayload(wrappedOrderEvent.payload), {
      'tic_nested',
    });

    final orderEvent = CustomerRealtimeEvent(
      name: 'order.paid.v1',
      channel: ordersChannel,
      payload: const {
        'order_id': 'ord_1',
        'ticket_ids': ['tic_1', 'tic_2'],
      },
    );
    expect(shouldRefreshCartFromRealtimeEvent(orderEvent), isTrue);
    expect(shouldRefreshTicketsFromRealtimeEvent(orderEvent), isTrue);
    expect(
      ticketIdsFromRealtimePayload(orderEvent.payload),
      {'tic_1', 'tic_2'},
    );

    final outboxOrderEvent = CustomerRealtimeEvent(
      name: 'sync.outbox',
      channel: ordersChannel,
      payload: const {
        'event_type': 'order.paid.v1',
        'payload_json': '{"order_id":"ord_2","ticket_ids":["tic_outbox"]}',
      },
    );
    expect(shouldRefreshCartFromRealtimeEvent(outboxOrderEvent), isTrue);
    expect(shouldRefreshTicketsFromRealtimeEvent(outboxOrderEvent), isTrue);
    expect(ticketIdsFromRealtimePayload(outboxOrderEvent.payload), {
      'tic_outbox',
    });

    final metadataOrderEvent = CustomerRealtimeEvent(
      name: 'sync.outbox',
      channel: ordersChannel,
      payload: const {
        'metadata': {
          'eventClass': r'App\Modules\Orders\Events\OrderPaid',
          'details': {
            'ticketIds': ['tic_meta'],
          },
        },
      },
    );
    expect(shouldRefreshCartFromRealtimeEvent(metadataOrderEvent), isTrue);
    expect(shouldRefreshTicketsFromRealtimeEvent(metadataOrderEvent), isTrue);
    expect(ticketIdsFromRealtimePayload(metadataOrderEvent.payload), {
      'tic_meta',
    });

    final ticketEvent = CustomerRealtimeEvent(
      name: 'customer.ticket.updated',
      channel: ticketsChannel,
      payload: const {
        'ticket': {'id': 'tic_3'},
      },
    );
    expect(shouldRefreshCartFromRealtimeEvent(ticketEvent), isFalse);
    expect(shouldRefreshTicketsFromRealtimeEvent(ticketEvent), isTrue);
    expect(ticketIdsFromRealtimePayload(ticketEvent.payload), {'tic_3'});
  });

  test('topup realtime refreshes only topup update events', () {
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'CustomerTopupUpdated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.topups',
          payload: {'id': 'top_1'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'sync.outbox',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.topups',
          payload: {
            'metadata': {
              'event_class_name':
                  r'App\Modules\Topups\Events\CustomerTopupStatusUpdated',
              'object': {'topupId': 'top_meta'},
            },
          },
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'wallet.updated.v1',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.wallet',
          payload: {'walletId': 'wallet_1'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'bridge.message',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.wallet',
          payload: {
            'data': {'event': 'wallet.updated.v1'},
          },
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'sync.outbox',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.wallet',
          payload: {
            'metadata': {
              'event_class_name':
                  r'App\Modules\Wallet\Events\CustomerWalletTransactionCreated',
              'object': {'walletId': 'wallet_1', 'transactionId': 'txn_1'},
            },
          },
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshTopupsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'bridge.message',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.wallet',
          payload: {
            'data': {
              'event': 'wallet.ledger.entry.updated',
              'walletTransaction': {'id': 'txn_2'},
            },
          },
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
          name: 'reward_claim_updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
          payload: {'rewardClaimId': 'rcl_1'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshRewardClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'customer.reward_claim.status.updated',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
          payload: {'claim_id': 'rcl_2'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshActivityClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'ActivityClaimUpdated',
          channel:
              'private-customer.tenant.ten_1.customer.cus_1.activity-claims',
          payload: {
            'activityClaim': {'id': 'acl_1'},
          },
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshActivityClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'activity_claim_paid',
          channel:
              'private-customer.tenant.ten_1.customer.cus_1.activity-claims',
          payload: {'activity_claim_id': 'acl_2'},
        ),
      ),
      isTrue,
    );
    expect(
      shouldRefreshRewardClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'sync.outbox',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
          payload: {
            'message': '{"type":"reward.claim.updated","claim_id":"rcl_3"}',
          },
        ),
      ),
      isTrue,
    );
    const metadataRewardClaimPayload = {
      'metadata': {
        'eventClass': r'App\Modules\Rewards\Events\CustomerRewardClaimPaid',
        'object': {
          'rewardClaimId': 'rcl_meta',
          'ticket': {'id': 'tic_meta'},
        },
      },
    };
    expect(
      shouldRefreshRewardClaimsFromRealtimeEvent(
        const CustomerRealtimeEvent(
          name: 'sync.outbox',
          channel: 'private-customer.tenant.ten_1.customer.cus_1.reward-claims',
          payload: metadataRewardClaimPayload,
        ),
      ),
      isTrue,
    );
    expect(claimIdFromRealtimePayload(metadataRewardClaimPayload), 'rcl_meta');
    expect(
      ticketIdFromRewardClaimRealtimePayload(metadataRewardClaimPayload),
      'tic_meta',
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
    expect(claimIdFromRealtimePayload({'rewardClaimId': 'rcl_2'}), 'rcl_2');
    expect(
      claimIdFromRealtimePayload({
        'payload': '{"rewardClaimId":"rcl_wrapped"}',
      }),
      'rcl_wrapped',
    );
    expect(
      claimIdFromRealtimePayload({
        'payload_json': '{"rewardClaimId":"rcl_outbox"}',
      }),
      'rcl_outbox',
    );
    expect(
      claimIdFromRealtimePayload({
        'activityClaim': {'claimId': 'acl_1'},
      }),
      'acl_1',
    );
    expect(
      ticketIdFromRewardClaimRealtimePayload({
        'claim': {
          'id': 'rcl_1',
          'ticket': {'id': 'tic_1'},
        },
      }),
      'tic_1',
    );
    expect(
      ticketIdFromRewardClaimRealtimePayload({
        'claim': {'id': 'rcl_without_ticket'},
      }),
      isNull,
    );
    expect(
      ticketIdFromRewardClaimRealtimePayload({
        'resource': '{"claim":{"ticket":{"id":"tic_wrapped"}}}',
      }),
      'tic_wrapped',
    );
  });
}
