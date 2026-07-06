import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_token_store.dart';
import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/realtime/customer_realtime_monitor.dart';
import '../../../core/realtime/customer_realtime_protocol.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../tickets/data/ticket_repository.dart';

final customerRevenueRealtimeEnabledProvider = Provider<bool>((_) => true);

final cartRealtimeTickProvider = StateProvider<int>((_) => 0);
final ticketRealtimeTickProvider = StateProvider<int>((_) => 0);

bool shouldRefreshCartFromRealtimeEvent(CustomerRealtimeEvent event) {
  final eventName = normalizeRealtimeEventNameWithPayload(
    eventName: event.name,
    payload: event.payload,
  );
  return eventName == 'cart.updated' ||
      eventName == 'order.updated' ||
      eventName == 'stock.availability.updated';
}

bool shouldRefreshTicketsFromRealtimeEvent(CustomerRealtimeEvent event) {
  final eventName = normalizeRealtimeEventNameWithPayload(
    eventName: event.name,
    payload: event.payload,
  );
  return eventName == 'tickets.updated' || eventName == 'order.updated';
}

Set<String> ticketIdsFromRealtimePayload(Map<String, Object?> payload) {
  final normalized = normalizeRealtimePayload(
    Map<String, dynamic>.from(payload),
  );
  final ids = <String>{};

  void addId(Object? value) {
    final text = _revenueRealtimeScalarText(value);
    if (text.isNotEmpty) ids.add(text);
  }

  void collect(Object? value) {
    if (value is List) {
      for (final item in value) {
        collect(item);
      }
      return;
    }
    if (value is Map) {
      addId(
        value['ticket_id'] ??
            value['ticketId'] ??
            value['customer_ticket_id'] ??
            value['customerTicketId'] ??
            value['lottery_ticket_id'] ??
            value['lotteryTicketId'] ??
            value['ticket_uuid'] ??
            value['ticketUuid'] ??
            value['id'] ??
            value['uuid'],
      );
      for (final key in const [
        'ticket',
        'customer_ticket',
        'customerTicket',
        'lottery_ticket',
        'lotteryTicket',
        'ticket_item',
        'ticketItem',
      ]) {
        collect(value[key]);
      }
      return;
    }
    addId(value);
  }

  for (final key in const [
    'ticket_id',
    'ticketId',
    'customer_ticket_id',
    'customerTicketId',
    'ticket_ids',
    'ticketIds',
    'customer_ticket_ids',
    'customerTicketIds',
    'ticket',
    'customer_ticket',
    'customerTicket',
    'tickets',
    'customer_tickets',
    'customerTickets',
    'lottery_tickets',
    'lotteryTickets',
    'order_items',
    'orderItems',
    'checkout_items',
    'checkoutItems',
    'items',
    'entries',
    'lines',
    'rows',
    'order',
    'checkout_order',
    'checkoutOrder',
    'purchase_order',
    'purchaseOrder',
  ]) {
    collect(normalized[key]);
  }

  return ids;
}

String _revenueRealtimeScalarText(Object? value, [int depth = 0]) {
  if (value == null || depth > 3) return '';
  if (value is Map) {
    for (final key in const ['value', 'code', 'key', 'id', 'uuid']) {
      final nested = _revenueRealtimeScalarText(value[key], depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  if (value is Iterable) {
    for (final item in value) {
      final nested = _revenueRealtimeScalarText(item, depth + 1);
      if (nested.isNotEmpty) return nested;
    }
    return '';
  }
  return value.toString().trim();
}

class CustomerRevenueRealtimeMonitor extends ConsumerStatefulWidget {
  const CustomerRevenueRealtimeMonitor({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<CustomerRevenueRealtimeMonitor> createState() =>
      _CustomerRevenueRealtimeMonitorState();
}

class _CustomerRevenueRealtimeMonitorState
    extends ConsumerState<CustomerRevenueRealtimeMonitor> {
  CustomerRealtimeClient? _client;
  StreamSubscription<CustomerRealtimeEvent>? _events;
  Timer? _refreshThrottle;
  final Set<String> _pendingTicketIds = {};
  String _signature = '';
  bool _pendingCartRefresh = false;
  bool _pendingTicketRefresh = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    WidgetsBinding.instance.addPostFrameCallback((_) => _sync());
  }

  @override
  void didUpdateWidget(covariant CustomerRevenueRealtimeMonitor oldWidget) {
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
    if (!mounted || !ref.read(customerRevenueRealtimeEnabledProvider)) {
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
      customerCartChannel(
        tenantId: bootstrap.tenantId,
        customerId: customerId,
      ),
      customerOrdersChannel(
        tenantId: bootstrap.tenantId,
        customerId: customerId,
      ),
      customerTicketsChannel(
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
    _pendingCartRefresh = false;
    _pendingTicketRefresh = false;
    _pendingTicketIds.clear();
    _refreshThrottle?.cancel();
    _refreshThrottle = null;
    await _events?.cancel();
    _events = null;
    await _client?.dispose();
    _client = null;
  }

  void _handleEvent(CustomerRealtimeEvent event) {
    final refreshCart = shouldRefreshCartFromRealtimeEvent(event);
    final refreshTickets = shouldRefreshTicketsFromRealtimeEvent(event);
    if (!refreshCart && !refreshTickets) return;

    _pendingCartRefresh = _pendingCartRefresh || refreshCart;
    _pendingTicketRefresh = _pendingTicketRefresh || refreshTickets;
    if (refreshTickets) {
      _pendingTicketIds.addAll(ticketIdsFromRealtimePayload(event.payload));
    }

    if (_refreshThrottle?.isActive ?? false) return;
    _refreshThrottle = Timer(const Duration(milliseconds: 500), _flushRefresh);
  }

  void _flushRefresh() {
    if (!mounted) return;

    final refreshCart = _pendingCartRefresh;
    final refreshTickets = _pendingTicketRefresh;
    final ticketIds = Set<String>.from(_pendingTicketIds);
    _pendingCartRefresh = false;
    _pendingTicketRefresh = false;
    _pendingTicketIds.clear();

    if (refreshCart) {
      ref.read(cartRealtimeTickProvider.notifier).state++;
    }

    if (refreshTickets) {
      ref.invalidate(currentTicketsProvider);
      for (final ticketId in ticketIds) {
        ref.invalidate(ticketDetailProvider(ticketId));
      }
      ref.read(ticketRealtimeTickProvider.notifier).state++;
    }
  }
}
