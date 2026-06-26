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
import '../../wallet/data/wallet_repository.dart';
import '../data/reward_claim_repository.dart';

final claimRealtimeEnabledProvider = Provider<bool>((_) => true);

final rewardClaimRealtimeTickProvider = StateProvider<int>((_) => 0);
final activityClaimRealtimeTickProvider = StateProvider<int>((_) => 0);

bool shouldRefreshRewardClaimsFromRealtimeEvent(CustomerRealtimeEvent event) {
  return event.name == 'reward.claim.updated';
}

bool shouldRefreshActivityClaimsFromRealtimeEvent(CustomerRealtimeEvent event) {
  return event.name == 'activity.claim.updated';
}

String? claimIdFromRealtimePayload(Map<String, dynamic> payload) {
  final direct = payload['claim_id'] ??
      payload['reward_claim_id'] ??
      payload['activity_claim_id'] ??
      payload['id'];
  final directText = direct?.toString().trim() ?? '';
  if (directText.isNotEmpty) return directText;

  final claim = payload['claim'];
  if (claim is Map) {
    final nested = claim['id']?.toString().trim() ?? '';
    if (nested.isNotEmpty) return nested;
  }

  return null;
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
  String _signature = '';
  bool _pendingRewardRefresh = false;
  bool _pendingActivityRefresh = false;
  String? _pendingRewardClaimId;
  String? _pendingActivityClaimId;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant CustomerClaimRealtimeMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
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
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _sync()),
    );
    ref.listen<AuthController>(
      authControllerProvider,
      (_, __) => WidgetsBinding.instance.addPostFrameCallback((_) => _sync()),
    );
    return widget.child;
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
    _refreshThrottle?.cancel();
    _refreshThrottle = null;
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    final reward = shouldRefreshRewardClaimsFromRealtimeEvent(event);
    final activity = shouldRefreshActivityClaimsFromRealtimeEvent(event);
    if (!reward && !activity) return;

    final claimId = claimIdFromRealtimePayload(event.payload);
    if (reward) {
      _pendingRewardRefresh = true;
      _pendingRewardClaimId = claimId ?? _pendingRewardClaimId;
    }
    if (activity) {
      _pendingActivityRefresh = true;
      _pendingActivityClaimId = claimId ?? _pendingActivityClaimId;
    }

    if (_refreshThrottle?.isActive ?? false) return;
    _refreshThrottle = Timer(const Duration(milliseconds: 500), _flushRefresh);
  }

  void _flushRefresh() {
    if (!mounted) return;

    final rewardClaimId = _pendingRewardClaimId;
    final activityClaimId = _pendingActivityClaimId;
    final refreshReward = _pendingRewardRefresh;
    final refreshActivity = _pendingActivityRefresh;
    _pendingRewardRefresh = false;
    _pendingActivityRefresh = false;
    _pendingRewardClaimId = null;
    _pendingActivityClaimId = null;

    if (refreshReward) {
      if (rewardClaimId != null) {
        ref.invalidate(rewardClaimDetailProvider(rewardClaimId));
      }
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
