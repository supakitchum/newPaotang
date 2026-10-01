import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/realtime/customer_realtime_monitor.dart';
import '../../../core/realtime/customer_realtime_protocol.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../activity_claims/data/activity_claim_repository.dart';
import '../../tickets/data/ticket_repository.dart';
import '../../wallet/data/wallet_repository.dart';
import '../data/reward_claim_repository.dart';

final claimRealtimeEnabledProvider = Provider<bool>((_) => true);

final rewardClaimRealtimeTickProvider = StateProvider<int>((_) => 0);
final activityClaimRealtimeTickProvider = StateProvider<int>((_) => 0);

bool shouldRefreshRewardClaimsFromRealtimeEvent(CustomerRealtimeEvent event) {
  return normalizeRealtimeEventNameWithPayload(
        eventName: event.name,
        payload: event.payload,
      ) ==
      'reward.claim.updated';
}

bool shouldRefreshActivityClaimsFromRealtimeEvent(CustomerRealtimeEvent event) {
  return normalizeRealtimeEventNameWithPayload(
        eventName: event.name,
        payload: event.payload,
      ) ==
      'activity.claim.updated';
}

String? claimIdFromRealtimePayload(Map<String, dynamic> payload) {
  final normalized = normalizeRealtimePayload(payload);

  String? collect(Object? value, {bool allowIdFallback = false}) {
    if (value == null) return null;
    if (value is List) {
      for (final item in value) {
        final id = collect(item, allowIdFallback: allowIdFallback);
        if (id != null) return id;
      }
      return null;
    }
    if (value is! Map) return _claimRealtimeScalarText(value);

    final id = _claimRealtimeScalarText(
      value['claim_id'] ??
          value['claimId'] ??
          value['reward_claim_id'] ??
          value['rewardClaimId'] ??
          value['activity_claim_id'] ??
          value['activityClaimId'] ??
          (allowIdFallback ? value['id'] ?? value['uuid'] : null),
    );
    if (id.isNotEmpty) return id;

    for (final key in const [
      'claim',
      'reward_claim',
      'rewardClaim',
      'activity_claim',
      'activityClaim',
      'submission',
      'record',
      'item',
    ]) {
      final nested = collect(value[key], allowIdFallback: true);
      if (nested != null) return nested;
    }

    for (final key in const [
      'award',
      'activity_award',
      'activityAward',
      'reward',
      'prize',
      'payout',
      'metadata',
      'details',
      'context',
    ]) {
      final nested = collect(value[key], allowIdFallback: false);
      if (nested != null) return nested;
    }

    return null;
  }

  return collect(normalized, allowIdFallback: true);
}

String? ticketIdFromRewardClaimRealtimePayload(
  Map<String, dynamic> payload, {
  bool allowIdFallback = false,
}) {
  final normalized = normalizeRealtimePayload(payload);
  final ids = <String>[];

  void addId(Object? value) {
    final text = _claimRealtimeScalarText(value);
    if (text.isNotEmpty) ids.add(text);
  }

  void collect(Object? value, {bool allowNestedIdFallback = false}) {
    if (ids.isNotEmpty || value == null) return;
    if (value is List) {
      for (final item in value) {
        collect(item, allowNestedIdFallback: allowNestedIdFallback);
        if (ids.isNotEmpty) return;
      }
      return;
    }
    if (value is! Map) {
      addId(value);
      return;
    }

    addId(
      value['ticket_id'] ??
          value['ticketId'] ??
          value['customer_ticket_id'] ??
          value['customerTicketId'] ??
          value['lottery_ticket_id'] ??
          value['lotteryTicketId'] ??
          value['ticket_uuid'] ??
          value['ticketUuid'],
    );
    if (ids.isNotEmpty) return;
    if (allowNestedIdFallback) {
      addId(value['id'] ?? value['uuid']);
      if (ids.isNotEmpty) return;
    }

    for (final key in const [
      'ticket',
      'customer_ticket',
      'customerTicket',
      'lottery_ticket',
      'lotteryTicket',
      'ticket_item',
      'ticketItem',
    ]) {
      collect(value[key], allowNestedIdFallback: true);
      if (ids.isNotEmpty) return;
    }

    for (final key in const [
      'claim',
      'reward_claim',
      'rewardClaim',
      'submission',
      'record',
      'item',
    ]) {
      collect(value[key], allowNestedIdFallback: false);
      if (ids.isNotEmpty) return;
    }

    for (final key in const [
      'tickets',
      'customer_tickets',
      'customerTickets',
      'lottery_tickets',
      'lotteryTickets',
      'order_items',
      'orderItems',
      'items',
      'entries',
      'rows',
    ]) {
      collect(value[key], allowNestedIdFallback: true);
      if (ids.isNotEmpty) return;
    }
  }

  collect(normalized, allowNestedIdFallback: allowIdFallback);
  return ids.isEmpty ? null : ids.first;
}

String _claimRealtimeScalarText(Object? value, [int depth = 0]) {
  if (value == null || depth > 3) return '';
  if (value is Map) {
    for (final key in const ['value', 'code', 'key', 'id', 'uuid']) {
      final nested = _claimRealtimeScalarText(value[key], depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _claimRealtimeScalarText(item, depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  return value.toString().trim();
}

class CustomerClaimRealtimeMonitor extends ConsumerStatefulWidget {
  const CustomerClaimRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CustomerClaimRealtimeMonitor> createState() =>
      _CustomerClaimRealtimeMonitorState();
}

class _CustomerClaimRealtimeMonitorState
    extends ConsumerState<CustomerClaimRealtimeMonitor> {
  CustomerRealtimeClient? _client;
  StreamSubscription<CustomerRealtimeEvent>? _events;
  Timer? _refreshThrottle;
  final CustomerRealtimeSubscriptionTracker _subscriptionTracker =
      CustomerRealtimeSubscriptionTracker();
  Future<void> _syncQueue = Future<void>.value();
  String _signature = '';
  bool _pendingRewardRefresh = false;
  bool _pendingActivityRefresh = false;
  String? _pendingRewardClaimId;
  String? _pendingActivityClaimId;
  String? _pendingRewardTicketId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
  }

  @override
  void didUpdateWidget(covariant CustomerClaimRealtimeMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
  }

  @override
  void dispose() {
    _refreshThrottle?.cancel();
    unawaited(_events?.cancel());
    unawaited(_client?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MobileBootstrap>>(
      mobileBootstrapProvider,
      (_, __) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync()),
    );
    ref.listen<AuthController>(
      authControllerProvider,
      (_, __) =>
          WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync()),
    );
    return widget.child;
  }

  void _scheduleSync() {
    _syncQueue = _syncQueue.then((_) async {
      if (mounted) await _sync();
    });
  }

  Future<void> _sync() async {
    if (!mounted || !ref.read(claimRealtimeEnabledProvider)) {
      await _stop();
      return;
    }

    final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
    final auth = ref.read(authControllerProvider);
    final customerId =
        ref.read(authTokenStoreProvider).customerId?.trim() ?? '';
    if (bootstrap == null ||
        bootstrap.tenantId.isEmpty ||
        !bootstrap.realtime.configured ||
        !auth.isAuthenticated ||
        customerId.isEmpty) {
      await _stop();
      return;
    }

    final channels = [
      customerRewardClaimChannel(
        tenantId: bootstrap.tenantId,
        customerId: customerId,
      ),
      customerActivityClaimChannel(
        tenantId: bootstrap.tenantId,
        customerId: customerId,
      ),
    ];
    final signature = [
      bootstrap.tenantId,
      bootstrap.realtime.url,
      bootstrap.realtime.key,
      customerId,
      ...channels,
    ].join('|');

    if (_client != null && _signature == signature) {
      _client!.updateChannels(channels);
      return;
    }

    await _stop();
    if (!mounted) return;
    _subscriptionTracker.updateChannels(channels);
    _signature = signature;
    final client =
        ref.read(customerRealtimeClientFactoryProvider)(bootstrap.realtime);
    _client = client;
    _events = client.events.listen(_handleEvent);
    await client.connect(channels);
  }

  Future<void> _stop() async {
    _signature = '';
    _pendingRewardRefresh = false;
    _pendingActivityRefresh = false;
    _pendingRewardClaimId = null;
    _pendingActivityClaimId = null;
    _pendingRewardTicketId = null;
    _refreshThrottle?.cancel();
    _refreshThrottle = null;
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
    _subscriptionTracker.clear();
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    if (_subscriptionTracker.register(event)) {
      final channel = event.channel.trim();
      if (channel.endsWith('.reward-claims')) {
        _pendingRewardRefresh = true;
      }
      if (channel.endsWith('.activity-claims')) {
        _pendingActivityRefresh = true;
      }
      if (_pendingRewardRefresh || _pendingActivityRefresh) {
        _scheduleRefresh();
      }
      return;
    }

    final reward = shouldRefreshRewardClaimsFromRealtimeEvent(event);
    final activity = shouldRefreshActivityClaimsFromRealtimeEvent(event);
    if (!reward && !activity) return;

    final claimId = claimIdFromRealtimePayload(event.payload);
    if (reward) {
      _pendingRewardRefresh = true;
      _pendingRewardClaimId = claimId ?? _pendingRewardClaimId;
      _pendingRewardTicketId =
          ticketIdFromRewardClaimRealtimePayload(event.payload) ??
              _pendingRewardTicketId;
    }
    if (activity) {
      _pendingActivityRefresh = true;
      _pendingActivityClaimId = claimId ?? _pendingActivityClaimId;
    }

    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    if (_refreshThrottle?.isActive ?? false) return;
    _refreshThrottle = Timer(const Duration(milliseconds: 500), _flushRefresh);
  }

  void _flushRefresh() {
    if (!mounted) return;

    final rewardClaimId = _pendingRewardClaimId;
    final activityClaimId = _pendingActivityClaimId;
    final rewardTicketId = _pendingRewardTicketId;
    final refreshReward = _pendingRewardRefresh;
    final refreshActivity = _pendingActivityRefresh;
    _pendingRewardRefresh = false;
    _pendingActivityRefresh = false;
    _pendingRewardClaimId = null;
    _pendingActivityClaimId = null;
    _pendingRewardTicketId = null;

    if (refreshReward) {
      if (rewardClaimId != null) {
        ref.invalidate(rewardClaimDetailProvider(rewardClaimId));
      }
      if (rewardTicketId != null) {
        ref.invalidate(ticketDetailProvider(rewardTicketId));
      }
      ref.invalidate(currentTicketsProvider);
      ref.read(rewardClaimRealtimeTickProvider.notifier).state++;
    }

    if (refreshActivity) {
      if (activityClaimId != null) {
        ref.invalidate(activityClaimDetailProvider(activityClaimId));
      }
      ref.read(activityClaimRealtimeTickProvider.notifier).state++;
    }

    if (refreshReward || refreshActivity) {
      ref.invalidate(walletSummaryProvider);
    }
  }
}
