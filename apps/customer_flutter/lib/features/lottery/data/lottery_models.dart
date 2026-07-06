import '../../../core/payment/payment_redirect_url.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class LotteryStockPage {
  const LotteryStockPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.gameId,
    required this.sellerName,
    this.canReserve = true,
  });

  factory LotteryStockPage.fromJson(Object? json) {
    final payload = unwrapPayload(json);
    final meta = {
      ...asMap(payload['pagination']),
      ...unwrapMeta(json),
    };
    final seller = asMap(payload['seller']);
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : asMapList(payload['lotteries'] ?? payload['items']);
    return LotteryStockPage(
      items: items.map(LotteryStockItem.fromJson).toList(
            growable: false,
          ),
      nextCursor:
          (meta['next_cursor'] ?? meta['cursor'] ?? meta['seed'])?.toString() ??
              '',
      hasMore: _stockPageHasMore(meta['has_more']),
      gameId: meta['game_id']?.toString() ?? '',
      sellerName: (seller['name'] ?? meta['seller_name'])?.toString() ?? '',
      canReserve: _stockPageCanReserve(
        payload['can_reserve'] ??
            payload['can_buy'] ??
            payload['bet_status'] ??
            meta['can_reserve'] ??
            meta['can_buy'] ??
            meta['bet_status'],
      ),
    );
  }

  final List<LotteryStockItem> items;
  final String nextCursor;
  final bool hasMore;
  final String gameId;
  final String sellerName;
  final bool canReserve;
}

class LotteryStockItem {
  const LotteryStockItem({
    required this.id,
    required this.token,
    required this.localStockItemId,
    required this.stockRef,
    required this.number,
    required this.sellerName,
    required this.storeName,
    required this.price,
    required this.remainingCount,
    required this.status,
    required this.reservationId,
    required this.reservationExpiresAt,
    required this.serverTime,
    required this.imageUrl,
    required this.thumbUrl,
    required this.raw,
    this.imageStatus = '',
    this.imageError = '',
    this.priceTrend = '',
    this.priceFlashKey = 0,
  });

  factory LotteryStockItem.fromJson(Map<String, dynamic> json) {
    final id =
        (json['id'] ?? json['stock_item_id'] ?? json['token'])?.toString() ??
            '';
    final localStockItemId =
        (json['local_stock_item_id'] ?? json['id'] ?? json['token'])
                ?.toString() ??
            '';
    final number = _normalizeLotteryNumber(
      json['full_number'] ??
          json['number'] ??
          json['lottery_number'] ??
          json['fullNumber'],
    );
    return LotteryStockItem(
      id: id,
      token: json['token']?.toString() ?? id,
      localStockItemId: localStockItemId,
      stockRef:
          (json['stock_ref'] ?? json['virtual_stock_ref'] ?? id)?.toString() ??
              '',
      number: number,
      sellerName: (json['seller'] ??
              json['seller_name'] ??
              json['store_name'] ??
              json['store']?['name'] ??
              '')
          .toString(),
      storeName:
          (json['store_name'] ?? json['store']?['name'] ?? json['seller'] ?? '')
              .toString(),
      price: moneyToDisplayNumber(json['price'], fallback: 80),
      remainingCount: int.tryParse(json['remaining_count']?.toString() ?? '') ??
          int.tryParse(json['available_count']?.toString() ?? '') ??
          1,
      status: (json['availability_status'] ?? json['status'] ?? 'available')
          .toString()
          .trim()
          .toLowerCase(),
      reservationId: json['reservation_id']?.toString() ?? '',
      reservationExpiresAt:
          json['reservation_expires_at'] ?? json['expires_at'],
      serverTime: json['server_time'],
      imageUrl: (json['image_url'] ??
              json['image_full_url'] ??
              json['preview_image_url'] ??
              json['image'] ??
              '')
          .toString(),
      thumbUrl: (json['image_thumb_url'] ??
              json['thumb_url'] ??
              json['thumbnail_url'] ??
              '')
          .toString(),
      imageStatus: (json['image_status'] ?? '').toString().toLowerCase(),
      imageError: (json['image_error'] ?? '').toString(),
      raw: Map<String, dynamic>.from(json),
      priceTrend: (json['priceTrend'] ?? json['price_trend'] ?? '')
          .toString()
          .trim()
          .toLowerCase(),
      priceFlashKey: int.tryParse(
            (json['priceFlashKey'] ?? json['price_flash_key'] ?? '').toString(),
          ) ??
          0,
    );
  }

  final String id;
  final String token;
  final String localStockItemId;
  final String stockRef;
  final String number;
  final String sellerName;
  final String storeName;
  final double price;
  final int remainingCount;
  final String status;
  final String reservationId;
  final Object? reservationExpiresAt;
  final Object? serverTime;
  final String imageUrl;
  final String thumbUrl;
  final String imageStatus;
  final String imageError;
  final Map<String, dynamic> raw;
  final String priceTrend;
  final int priceFlashKey;

  LotteryStockItem copyWith({
    double? price,
    int? remainingCount,
    String? status,
    String? priceTrend,
    int? priceFlashKey,
  }) {
    return LotteryStockItem(
      id: id,
      token: token,
      localStockItemId: localStockItemId,
      stockRef: stockRef,
      number: number,
      sellerName: sellerName,
      storeName: storeName,
      price: price ?? this.price,
      remainingCount: remainingCount ?? this.remainingCount,
      status: status ?? this.status,
      reservationId: reservationId,
      reservationExpiresAt: reservationExpiresAt,
      serverTime: serverTime,
      imageUrl: imageUrl,
      thumbUrl: thumbUrl,
      imageStatus: imageStatus,
      imageError: imageError,
      raw: raw,
      priceTrend: priceTrend ?? this.priceTrend,
      priceFlashKey: priceFlashKey ?? this.priceFlashKey,
    );
  }

  bool get isAvailable =>
      remainingCount > 0 && !_unavailableStockStatuses.contains(status);

  bool get isReserved => reservationId.isNotEmpty;
}

const _unavailableStockStatuses = {
  'sold_out',
  'sold',
  'reserved',
  'booked',
  'unavailable',
  'not_available',
  'disabled',
  'inactive',
  'recalled',
  'voided',
  'expired',
  'cancelled',
  'canceled',
  'blocked',
  'locked',
  'hold',
  'held',
};

class LotteryReservation {
  const LotteryReservation({
    required this.id,
    required this.gameId,
    required this.status,
    required this.expiresAt,
    required this.expiresInSeconds,
    required this.serverTime,
    required this.items,
    required this.total,
  });

  factory LotteryReservation.fromJson(Map<String, dynamic> json) {
    final reservation = asMap(json['reservation']);
    final id = _firstLotteryText([
      json['id'],
      json['reservation_id'],
      json['reservationId'],
      reservation['id'],
    ]);
    final expiresAt = json['expires_at'] ??
        json['expiresAt'] ??
        json['exp'] ??
        json['reservation_expires_at'] ??
        reservation['expires_at'] ??
        reservation['expiresAt'] ??
        reservation['exp'] ??
        reservation['reservation_expires_at'];
    final serverTime = json['server_time'] ??
        json['serverTime'] ??
        reservation['server_time'] ??
        reservation['serverTime'];
    final rootRows = _reservationItemRows(json);
    final itemRows =
        rootRows.isNotEmpty ? rootRows : _reservationItemRows(reservation);
    final items = itemRows.map((item) {
      return LotteryStockItem.fromJson({
        ...item,
        if (id.isNotEmpty) 'reservation_id': id,
        if (expiresAt != null) 'reservation_expires_at': expiresAt,
        if (serverTime != null) 'server_time': serverTime,
      });
    }).toList(growable: false);
    final computedTotal = items.fold<double>(
      0,
      (sum, item) => sum + item.price,
    );
    return LotteryReservation(
      id: id,
      gameId: _firstLotteryText([
        json['game_id'],
        json['gameId'],
        reservation['game_id'],
        reservation['gameId'],
        if (items.isNotEmpty) items.first.raw['game_id'],
      ]),
      status: _firstLotteryText([
        json['status'],
        reservation['status'],
        'active',
      ]).toLowerCase(),
      expiresAt: expiresAt,
      expiresInSeconds: int.tryParse(
            _firstLotteryText([
              json['expires_in_seconds'],
              json['expiresInSeconds'],
              json['expires_in'],
              reservation['expires_in_seconds'],
              reservation['expiresInSeconds'],
              reservation['expires_in'],
            ]),
          ) ??
          0,
      serverTime: serverTime,
      items: items,
      total: moneyToDisplayNumber(
        json['total'] ??
            json['amount'] ??
            json['price'] ??
            reservation['total'] ??
            reservation['amount'] ??
            reservation['price'],
        fallback: computedTotal,
      ),
    );
  }

  final String id;
  final String gameId;
  final String status;
  final Object? expiresAt;
  final int expiresInSeconds;
  final Object? serverTime;
  final List<LotteryStockItem> items;
  final double total;
}

class LotteryCart {
  const LotteryCart({
    required this.reservations,
    required this.total,
    required this.itemCount,
    required this.serverTime,
    required this.warnings,
  });

  factory LotteryCart.empty() {
    return const LotteryCart(
      reservations: [],
      total: 0,
      itemCount: 0,
      serverTime: null,
      warnings: [],
    );
  }

  factory LotteryCart.fromJson(Object? json) {
    final payload = unwrapPayload(json);
    final reservations = _cartReservationsFromPayload(payload, original: json);
    final computedTotal = reservations.fold<double>(
      0,
      (sum, reservation) => sum + reservation.total,
    );
    return LotteryCart(
      reservations: reservations,
      total: moneyToDisplayNumber(
        payload['total'] ??
            payload['amount'] ??
            payload['price'] ??
            asMap(payload['cart_order'])['total'] ??
            asMap(payload['order'])['total'],
        fallback: computedTotal,
      ),
      itemCount: int.tryParse(
            _firstLotteryText([
              payload['item_count'],
              payload['ticket_count'],
              payload['count'],
              asMap(payload['cart_order'])['item_count'],
              asMap(payload['cart_order'])['count'],
              asMap(payload['order'])['item_count'],
              asMap(payload['order'])['count'],
            ]),
          ) ??
          reservations.fold<int>(0, (sum, row) => sum + row.items.length),
      serverTime: payload['server_time'] ??
          payload['serverTime'] ??
          asMap(payload['cart_order'])['server_time'] ??
          asMap(payload['cart_order'])['created_at'] ??
          asMap(payload['order'])['server_time'] ??
          asMap(payload['order'])['created_at'],
      warnings: (payload['warnings'] is List)
          ? (payload['warnings'] as List)
              .map((item) => item.toString())
              .toList()
          : const [],
    );
  }

  final List<LotteryReservation> reservations;
  final double total;
  final int itemCount;
  final Object? serverTime;
  final List<String> warnings;

  List<LotteryStockItem> get items =>
      reservations.expand((reservation) => reservation.items).toList(
            growable: false,
          );

  List<String> get reservationIds => reservations
      .where((reservation) => reservation.status == 'active')
      .map((reservation) => reservation.id)
      .where((id) => id.isNotEmpty)
      .toList(growable: false);

  bool get isEmpty => items.isEmpty;
}

List<Map<String, dynamic>> _reservationItemRows(Map<String, dynamic> json) {
  for (final key in const ['items', 'lotteries', 'carts']) {
    final rows = asMapList(json[key]);
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}

List<LotteryReservation> _cartReservationsFromPayload(
  Map<String, dynamic> payload, {
  Object? original,
}) {
  final directReservations = asMapList(payload['reservations']);
  if (directReservations.isNotEmpty) {
    return directReservations.map((reservation) {
      return LotteryReservation.fromJson({
        if (payload['server_time'] != null)
          'server_time': payload['server_time'],
        if (payload['serverTime'] != null) 'serverTime': payload['serverTime'],
        ...reservation,
      });
    }).toList(
      growable: false,
    );
  }

  for (final key in const [
    'cart_order',
    'order',
    'checkout_order',
    'waiting',
  ]) {
    final order = asMap(payload[key]);
    final reservations = _cartReservationsFromOrder(order, payload);
    if (reservations.isNotEmpty) return reservations;
  }

  for (final key in const ['orders', 'carts']) {
    final order = asMap(payload[key]);
    final reservations = _cartReservationsFromOrder(order, payload);
    if (reservations.isNotEmpty) return reservations;

    final rows = asMapList(payload[key]);
    if (rows.isEmpty) continue;
    Map<String, dynamic>? nestedOrder;
    for (final row in rows) {
      if (_looksLikeLegacyCartOrder(row)) {
        nestedOrder = row;
        break;
      }
    }
    if (nestedOrder != null) {
      final nestedReservations = _cartReservationsFromOrder(
        nestedOrder,
        payload,
      );
      if (nestedReservations.isNotEmpty) return nestedReservations;
    }
    return _legacyCartRowsToReservations(
      rows,
      fallbackServerTime: payload['server_time'] ?? payload['serverTime'],
    );
  }

  final rootRows = asMapList(original);
  if (rootRows.isNotEmpty) return _legacyCartRowsToReservations(rootRows);

  return const [];
}

List<LotteryReservation> _cartReservationsFromOrder(
  Map<String, dynamic> order,
  Map<String, dynamic> fallback,
) {
  if (order.isEmpty) return const [];

  final directReservations = asMapList(order['reservations']);
  if (directReservations.isNotEmpty) {
    return directReservations.map((reservation) {
      return LotteryReservation.fromJson({
        if (fallback['server_time'] != null)
          'server_time': fallback['server_time'],
        ...reservation,
      });
    }).toList(growable: false);
  }

  final rows = _reservationItemRows(order);
  if (rows.isEmpty) return const [];

  return _legacyCartRowsToReservations(
    rows,
    fallbackGameId: _firstLotteryText([
      order['game_id'],
      order['gameId'],
      fallback['game_id'],
      fallback['gameId'],
    ]),
    fallbackExpiresAt:
        order['expires_at'] ?? order['expiresAt'] ?? order['exp'],
    fallbackServerTime: order['server_time'] ??
        order['serverTime'] ??
        order['created_at'] ??
        fallback['server_time'] ??
        fallback['serverTime'],
    fallbackReservationId: _firstLotteryText([
      order['reservation_id'],
      order['reservationId'],
    ]),
  );
}

List<LotteryReservation> _legacyCartRowsToReservations(
  List<Map<String, dynamic>> rows, {
  String fallbackGameId = '',
  Object? fallbackExpiresAt,
  Object? fallbackServerTime,
  String fallbackReservationId = '',
}) {
  final grouped = <String, _LegacyCartReservationGroup>{};
  for (var index = 0; index < rows.length; index++) {
    final row = rows[index];
    final reservation = asMap(row['reservation']);
    final reservationId = _firstLotteryText([
      row['reservation_id'],
      row['reservationId'],
      reservation['id'],
      fallbackReservationId,
    ]);
    final groupKey =
        reservationId.isEmpty ? 'legacy_row_$index' : reservationId;
    final group = grouped.putIfAbsent(
      groupKey,
      () => _LegacyCartReservationGroup(reservationId),
    );
    group.rows.add(row);
  }

  return grouped.values.map((group) {
    final first = group.rows.first;
    final reservation = asMap(first['reservation']);
    return LotteryReservation.fromJson({
      'id': group.reservationId,
      'game_id': _firstLotteryText([
        first['game_id'],
        first['gameId'],
        reservation['game_id'],
        fallbackGameId,
      ]),
      'status': _firstLotteryText([
        first['reservation_status'],
        reservation['status'],
        'active',
      ]),
      'expires_at': first['expires_at'] ??
          first['expiresAt'] ??
          first['exp'] ??
          first['reservation_expires_at'] ??
          reservation['expires_at'] ??
          fallbackExpiresAt,
      'expires_in_seconds': first['expires_in_seconds'] ??
          first['expiresInSeconds'] ??
          reservation['expires_in_seconds'],
      'server_time': first['server_time'] ??
          first['serverTime'] ??
          reservation['server_time'] ??
          fallbackServerTime,
      'items': group.rows,
    });
  }).toList(growable: false);
}

bool _looksLikeLegacyCartOrder(Map<String, dynamic> value) {
  return asMapList(value['reservations']).isNotEmpty ||
      _reservationItemRows(value).isNotEmpty;
}

class _LegacyCartReservationGroup {
  _LegacyCartReservationGroup(this.reservationId);

  final String reservationId;
  final List<Map<String, dynamic>> rows = [];
}

String _firstLotteryText(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> checkoutOrderPayload(Object? json) {
  return _checkoutOrderPayload(json);
}

Map<String, dynamic> _checkoutOrderPayload(Object? json, [int depth = 0]) {
  final payload = asMap(json);
  if (payload.isEmpty) return const <String, dynamic>{};
  if (depth >= 4) return payload;

  for (final key in const [
    'receipt',
    'order_receipt',
    'orderReceipt',
    'resource',
    'data',
    'result',
  ]) {
    final nested = asMap(payload[key]);
    if (nested.isNotEmpty) {
      return _mergeCheckoutOrderPayload(
        payload,
        _checkoutOrderPayload(nested, depth + 1),
      );
    }
  }

  final nestedOrder = _checkoutNestedOrder(payload);
  if (nestedOrder.isNotEmpty) {
    return _mergeCheckoutOrderPayload(payload, nestedOrder);
  }
  return payload;
}

Map<String, dynamic> _checkoutNestedOrder(Map<String, dynamic> payload) {
  for (final key in const [
    'order',
    'checkout_order',
    'checkoutOrder',
    'purchase_order',
    'purchaseOrder',
  ]) {
    final nested = asMap(payload[key]);
    if (nested.isNotEmpty) return nested;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _mergeCheckoutOrderPayload(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> order,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..remove('order')
    ..remove('checkout_order')
    ..remove('checkoutOrder')
    ..remove('purchase_order')
    ..remove('purchaseOrder')
    ..remove('receipt')
    ..remove('order_receipt')
    ..remove('orderReceipt')
    ..remove('resource')
    ..remove('data')
    ..remove('result');
  final wrapperPayment = asMap(wrapper['payment']);
  final orderPayment = asMap(order['payment']);
  merged.addAll(order);
  if (wrapperPayment.isNotEmpty || orderPayment.isNotEmpty) {
    merged['payment'] = {
      ...wrapperPayment,
      ...orderPayment,
    };
  }
  return merged;
}

class LotteryCheckoutOrder {
  const LotteryCheckoutOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.total,
    required this.ticketCount,
    required this.redirectUrl,
    required this.paidAt,
  });

  factory LotteryCheckoutOrder.fromJson(Object? json) {
    final payload = checkoutOrderPayload(json);
    final payment = asMap(payload['payment']);
    final ticketRows = _checkoutTicketRows(payload);
    final parsedTicketCount = int.tryParse(
      _firstCheckoutText([
        payload['ticket_count'],
        payload['ticketCount'],
        payload['item_count'],
        payload['itemCount'],
        payload['count'],
      ]),
    );
    final countedTickets = ticketRows.fold<int>(
      0,
      (total, ticket) =>
          total +
          (int.tryParse(
                _firstCheckoutText([
                  ticket['count'],
                  ticket['quantity'],
                  ticket['qty'],
                ]),
              ) ??
              1),
    );
    return LotteryCheckoutOrder(
      id: _firstCheckoutText([
        payload['id'],
        payload['order_id'],
        payload['orderId'],
        payload['checkout_order_id'],
        payload['checkoutOrderId'],
        payload['purchase_order_id'],
        payload['purchaseOrderId'],
      ]),
      reference: _firstCheckoutText([
        payload['reference'],
        payload['order_reference'],
        payload['orderReference'],
        payload['reference_code'],
        payload['referenceCode'],
        payment['reference'],
        payment['provider_reference'],
        payment['providerReference'],
        payment['payment_reference'],
        payment['paymentReference'],
        payment['transaction_reference'],
        payment['transactionReference'],
      ]),
      status: _firstCheckoutText([
        payload['status'],
        payload['order_status'],
        payload['orderStatus'],
        payment['order_status'],
        payment['orderStatus'],
      ]),
      paymentStatus: _firstCheckoutText([
        payload['payment_status'],
        payload['paymentStatus'],
        payment['payment_status'],
        payment['paymentStatus'],
        payment['status'],
      ]),
      paymentMethod: _firstCheckoutText([
        payload['payment_method'],
        payload['paymentMethod'],
        payment['payment_method'],
        payment['paymentMethod'],
        payment['method'],
      ]),
      total: moneyToDisplayNumber(
        payload['total'] ??
            payload['grand_total'] ??
            payload['grandTotal'] ??
            payload['amount'] ??
            payload['price'] ??
            payment['amount'] ??
            payment['total'],
      ),
      ticketCount: parsedTicketCount ?? countedTickets,
      redirectUrl: firstPaymentRedirectUrl([
        payload['redirect_url'],
        payload['redirectUrl'],
        payload['redirect_uri'],
        payload['redirectUri'],
        payload['payment_url'],
        payload['paymentUrl'],
        payload['payment_uri'],
        payload['paymentUri'],
        payload['checkout_url'],
        payload['checkoutUrl'],
        payload['checkout_uri'],
        payload['checkoutUri'],
        payload['authorization_url'],
        payload['authorizationUrl'],
        payload['approval_url'],
        payload['approvalUrl'],
        payload['payment_link'],
        payload['paymentLink'],
        payload['checkout_link'],
        payload['checkoutLink'],
        payload['web_url'],
        payload['webUrl'],
        payload['mobile_url'],
        payload['mobileUrl'],
        payload['deep_link'],
        payload['deepLink'],
        payload['payment_session'],
        payload['paymentSession'],
        payload['checkout_session'],
        payload['checkoutSession'],
        payload['provider_payload'],
        payload['providerPayload'],
        payload['next_action'],
        payload['nextAction'],
        payload['url'],
        payload['uri'],
        payload['href'],
        payload['link'],
        payload['links'],
        payment['redirect_url'],
        payment['redirectUrl'],
        payment['redirect_uri'],
        payment['redirectUri'],
        payment['payment_url'],
        payment['paymentUrl'],
        payment['payment_uri'],
        payment['paymentUri'],
        payment['checkout_url'],
        payment['checkoutUrl'],
        payment['checkout_uri'],
        payment['checkoutUri'],
        payment['authorization_url'],
        payment['authorizationUrl'],
        payment['approval_url'],
        payment['approvalUrl'],
        payment['payment_link'],
        payment['paymentLink'],
        payment['checkout_link'],
        payment['checkoutLink'],
        payment['web_url'],
        payment['webUrl'],
        payment['mobile_url'],
        payment['mobileUrl'],
        payment['deep_link'],
        payment['deepLink'],
        payment['payment_session'],
        payment['paymentSession'],
        payment['checkout_session'],
        payment['checkoutSession'],
        payment['provider_payload'],
        payment['providerPayload'],
        payment['next_action'],
        payment['nextAction'],
        payment['url'],
        payment['uri'],
        payment['href'],
        payment['link'],
        payment['links'],
        payment,
      ]),
      paidAt: _firstCheckoutText([
        payload['paid_at'],
        payload['paidAt'],
        payload['completed_at'],
        payload['completedAt'],
        payment['paid_at'],
        payment['paidAt'],
        payment['completed_at'],
        payment['completedAt'],
      ]),
    );
  }

  final String id;
  final String reference;
  final String status;
  final String paymentStatus;
  final String paymentMethod;
  final double total;
  final int ticketCount;
  final String redirectUrl;
  final Object? paidAt;

  Uri? get redirectUri {
    final uri = Uri.tryParse(redirectUrl.trim());
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'javascript' || scheme == 'data' || scheme == 'file') {
      return null;
    }
    return uri;
  }
}

List<Map<String, dynamic>> _checkoutTicketRows(Map<String, dynamic> payload) {
  for (final key in const [
    'tickets',
    'lotteries',
    'items',
    'order_items',
    'orderItems',
  ]) {
    final rows = asMapList(payload[key]);
    if (rows.isNotEmpty) return rows;
  }
  return const <Map<String, dynamic>>[];
}

String _firstCheckoutText(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _normalizeLotteryNumber(Object? value) {
  final digits = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length >= 6) {
    return digits.substring(digits.length - 6);
  }
  return digits.padLeft(6, '0');
}

bool _stockPageCanReserve(Object? value) {
  if (value == null) return true;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return true;
  return !{
    '0',
    'false',
    'closed',
    'disabled',
    'no',
    'not_allowed',
  }.contains(normalized);
}

bool _stockPageHasMore(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}
