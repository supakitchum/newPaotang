import '../../../core/payment/payment_redirect_url.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class PurchaseHistoryTicket {
  const PurchaseHistoryTicket({
    required this.id,
    required this.number,
    required this.statusRaw,
  });

  factory PurchaseHistoryTicket.fromJson(Map<String, dynamic> json) {
    return PurchaseHistoryTicket(
      id: _firstPurchaseHistoryText([
        json['id'],
        json['ticket_id'],
        json['ticketId'],
      ]),
      number: _firstPurchaseHistoryText([
        json['full_number'],
        json['fullNumber'],
        json['number'],
        json['lottery_number'],
        json['lotteryNumber'],
      ]),
      statusRaw: _statusRaw(json),
    );
  }

  final String id;
  final String number;
  final String statusRaw;

  static String _statusRaw(Map<String, dynamic> json) {
    final rewardStatus = asMap(json['reward_status']);
    final rewardStatusCamel = asMap(json['rewardStatus']);
    return _firstPurchaseHistoryText([
      rewardStatus['status'],
      rewardStatusCamel['status'],
      json['status'],
    ]).toLowerCase();
  }
}

class PurchaseHistoryOrder {
  const PurchaseHistoryOrder({
    required this.id,
    required this.reference,
    required this.status,
    required this.paymentStatus,
    required this.paymentMethod,
    required this.total,
    required this.ticketCount,
    required this.tickets,
    required this.gameName,
    required this.drawAt,
    required this.walletId,
    required this.walletName,
    required this.paymentProvider,
    required this.paymentReference,
    required this.redirectUrl,
    required this.storeName,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseHistoryOrder.fromJson(Map<String, dynamic> json) {
    final payload = _purchaseHistoryOrderPayload(json);
    final ticketRows = _purchaseHistoryTicketRows(payload);
    final game = _purchaseHistoryGame(payload, ticketRows);
    final wallet = _firstPurchaseHistoryMap([
      payload['wallet'],
      payload['primary_wallet'],
      payload['primaryWallet'],
    ]);
    final payment = _firstPurchaseHistoryMap([
      payload['payment'],
      payload['payment_channel'],
      payload['paymentChannel'],
    ]);
    final store = _firstPurchaseHistoryMap([
      payload['store'],
      payload['seller'],
      payload['shop'],
    ]);
    final tickets =
        ticketRows.map(PurchaseHistoryTicket.fromJson).toList(growable: false);
    final parsedTicketCount = int.tryParse(
      _firstPurchaseHistoryText([
        payload['ticket_count'],
        payload['ticketCount'],
        payload['item_count'],
        payload['count'],
      ]),
    );
    final countedTickets = ticketRows.fold<int>(
      0,
      (total, ticket) =>
          total +
          (int.tryParse(
                _firstPurchaseHistoryText([
                  ticket['count'],
                  ticket['quantity'],
                  ticket['qty'],
                ]),
              ) ??
              1),
    );

    return PurchaseHistoryOrder(
      id: _firstPurchaseHistoryText([
        payload['id'],
        payload['order_id'],
        payload['orderId'],
        payload['purchase_order_id'],
        payload['purchaseOrderId'],
      ]),
      reference: _firstPurchaseHistoryText([
        payload['reference'],
        payload['order_reference'],
        payload['orderReference'],
        payload['reference_code'],
        payload['referenceCode'],
        payload['transaction_id'],
        payload['transactionId'],
        payment['reference'],
        payment['provider_reference'],
        payment['providerReference'],
        payment['payment_reference'],
        payment['paymentReference'],
        payment['transaction_id'],
        payment['transactionId'],
      ]),
      status: _firstPurchaseHistoryText([
        payload['status'],
        payment['order_status'],
        payment['orderStatus'],
      ]),
      paymentStatus: _firstPurchaseHistoryText([
        payload['payment_status'],
        payload['paymentStatus'],
        payment['status'],
      ]),
      paymentMethod: _firstPurchaseHistoryText([
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
      tickets: tickets,
      gameName: _firstPurchaseHistoryText([
        game['name'],
        game['display_name'],
        game['displayName'],
        payload['game_name'],
        payload['gameName'],
      ]),
      drawAt: _firstPurchaseHistoryValue([
        game['draw_at'],
        game['drawAt'],
        payload['draw_at'],
        payload['drawAt'],
      ]),
      walletId: _firstPurchaseHistoryText([
        wallet['id'],
        wallet['wallet_id'],
        wallet['walletId'],
        payload['wallet_id'],
        payload['walletId'],
      ]),
      walletName: _firstPurchaseHistoryText([
        wallet['name'],
        wallet['display_name'],
        wallet['displayName'],
        wallet['wallet_name'],
        wallet['walletName'],
        wallet['label'],
        payload['wallet_name'],
        payload['walletName'],
      ]),
      paymentProvider: _firstPurchaseHistoryText([
        payment['provider'],
        payment['provider_name'],
        payment['providerName'],
        payment['display_name'],
        payment['displayName'],
        payment['channel_name'],
        payment['channelName'],
        payment['label'],
        payload['payment_provider'],
        payload['paymentProvider'],
      ]),
      paymentReference: _firstPurchaseHistoryText([
        payment['provider_reference'],
        payment['providerReference'],
        payment['reference'],
        payment['payment_reference'],
        payment['paymentReference'],
        payment['transaction_reference'],
        payment['transactionReference'],
        payment['transaction_id'],
        payment['transactionId'],
        payload['payment_reference'],
        payload['paymentReference'],
        payload['transaction_reference'],
        payload['transactionReference'],
        payload['transaction_id'],
        payload['transactionId'],
      ]),
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
        payload['links'],
        payload['link'],
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
      storeName: _firstPurchaseHistoryText([
        store['name'],
        store['display_name'],
        store['displayName'],
        store['shop_name'],
        store['shopName'],
        store['label'],
        payload['store_name'],
        payload['storeName'],
        payload['seller_name'],
        payload['sellerName'],
      ]),
      paidAt: _firstPurchaseHistoryValue([
        payload['paid_at'],
        payload['paidAt'],
        payload['completed_at'],
        payload['completedAt'],
        payment['paid_at'],
        payment['paidAt'],
        payment['completed_at'],
        payment['completedAt'],
      ]),
      createdAt: _firstPurchaseHistoryValue([
        payload['created_at'],
        payload['createdAt'],
      ]),
      updatedAt: _firstPurchaseHistoryValue([
        payload['updated_at'],
        payload['updatedAt'],
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
  final List<PurchaseHistoryTicket> tickets;
  final String gameName;
  final Object? drawAt;
  final String walletId;
  final String walletName;
  final String paymentProvider;
  final String paymentReference;
  final String redirectUrl;
  final String storeName;
  final Object? paidAt;
  final Object? createdAt;
  final Object? updatedAt;

  Object? get transactionAt => paidAt ?? updatedAt ?? createdAt;

  String get displayReference {
    if (reference.isNotEmpty) return reference;
    if (id.isNotEmpty) return 'ORDER-$id';
    return '-';
  }

  String get maskedPaymentReference {
    final raw = (walletId.isNotEmpty
            ? walletId
            : paymentReference.isNotEmpty
                ? paymentReference
                : reference)
        .replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final source = digits.isEmpty ? raw : digits;
    if (source.length <= 4) return source;
    final hiddenCount = source.length - 7 < 6 ? 6 : source.length - 7;
    final hidden = List.filled(hiddenCount, 'X').join();
    return '${source.substring(0, 3)} $hidden ${source.substring(source.length - 4)}';
  }

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

Map<String, dynamic> _purchaseHistoryOrderPayload(Map<String, dynamic> json) {
  final receipt = _purchaseHistoryReceiptPayload(json);
  final order = _purchaseHistoryNestedOrder(receipt);
  if (order.isEmpty) return receipt;

  final merged = Map<String, dynamic>.from(order);

  for (final key in const [
    'reference',
    'order_reference',
    'orderReference',
    'status',
    'payment_status',
    'paymentStatus',
    'payment_method',
    'paymentMethod',
    'reference_code',
    'referenceCode',
    'redirect_url',
    'redirectUrl',
    'redirect_uri',
    'redirectUri',
    'payment_url',
    'paymentUrl',
    'payment_uri',
    'paymentUri',
    'checkout_url',
    'checkoutUrl',
    'checkout_uri',
    'checkoutUri',
    'authorization_url',
    'authorizationUrl',
    'approval_url',
    'approvalUrl',
    'payment_link',
    'paymentLink',
    'checkout_link',
    'checkoutLink',
    'web_url',
    'webUrl',
    'mobile_url',
    'mobileUrl',
    'deep_link',
    'deepLink',
    'payment_session',
    'paymentSession',
    'checkout_session',
    'checkoutSession',
    'provider_payload',
    'providerPayload',
    'next_action',
    'nextAction',
    'links',
    'link',
    'wallet_name',
    'walletName',
    'wallet_id',
    'walletId',
    'store_name',
    'storeName',
    'seller_name',
    'sellerName',
    'payment_provider',
    'paymentProvider',
    'payment_reference',
    'paymentReference',
    'transaction_reference',
    'transactionReference',
    'transaction_id',
    'transactionId',
    'paid_at',
    'paidAt',
    'completed_at',
    'completedAt',
    'created_at',
    'createdAt',
    'updated_at',
    'updatedAt',
  ]) {
    _preferPurchaseHistoryReceiptValue(merged, key, receipt[key]);
  }

  _preferPurchaseHistoryReceiptValue(merged, 'total', receipt['total']);
  _preferPurchaseHistoryReceiptValue(
    merged,
    'grand_total',
    receipt['grand_total'] ?? receipt['grandTotal'],
  );
  _preferPurchaseHistoryReceiptValue(merged, 'amount', receipt['amount']);
  _preferPurchaseHistoryReceiptValue(merged, 'price', receipt['price']);
  _preferPurchaseHistoryReceiptValue(
    merged,
    'ticket_count',
    receipt['ticket_count'] ??
        receipt['ticketCount'] ??
        receipt['item_count'] ??
        receipt['itemCount'] ??
        receipt['count'],
  );

  for (final aliases in const [
    ['game', 'lottery_game', 'lotteryGame'],
    ['wallet', 'primary_wallet', 'primaryWallet'],
    ['payment', 'payment_channel', 'paymentChannel'],
    ['store', 'seller', 'shop'],
  ]) {
    Map<String, dynamic> value = const {};
    for (final alias in aliases) {
      final candidate = asMap(receipt[alias]);
      if (candidate.isNotEmpty) {
        value = candidate;
        break;
      }
    }
    if (value.isNotEmpty) {
      final targetKey = aliases.first;
      merged[targetKey] = {
        ...asMap(merged[targetKey]),
        ...value,
      };
    }
  }

  for (final key in const [
    'tickets',
    'lotteries',
    'items',
    'order_items',
    'orderItems',
    'customer_tickets',
    'customerTickets',
    'purchase_items',
    'purchaseItems',
  ]) {
    final value = asMapList(receipt[key]);
    if (value.isNotEmpty && _purchaseHistoryTicketRows(merged).isEmpty) {
      merged[key] = value;
    }
  }

  return merged;
}

Map<String, dynamic> _purchaseHistoryReceiptPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in const [
    'receipt',
    'order_receipt',
    'orderReceipt',
    'resource',
    'data',
    'result',
    'payload',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    return _mergePurchaseHistoryWrapper(
      json,
      _purchaseHistoryReceiptPayload(nested, depth + 1),
    );
  }

  return json;
}

Map<String, dynamic> _purchaseHistoryNestedOrder(Map<String, dynamic> json) {
  final order = asMap(json['order']);
  if (order.isNotEmpty) return order;
  final checkoutOrder = asMap(json['checkout_order']);
  if (checkoutOrder.isNotEmpty) return checkoutOrder;
  final checkoutOrderCamel = asMap(json['checkoutOrder']);
  if (checkoutOrderCamel.isNotEmpty) return checkoutOrderCamel;
  final purchaseOrder = asMap(json['purchase_order']);
  if (purchaseOrder.isNotEmpty) return purchaseOrder;
  final purchaseOrderCamel = asMap(json['purchaseOrder']);
  if (purchaseOrderCamel.isNotEmpty) return purchaseOrderCamel;
  final purchaseOrderResource = asMap(json['purchase_order_resource']);
  if (purchaseOrderResource.isNotEmpty) return purchaseOrderResource;
  final purchaseOrderResourceCamel = asMap(json['purchaseOrderResource']);
  if (purchaseOrderResourceCamel.isNotEmpty) {
    return purchaseOrderResourceCamel;
  }
  return const <String, dynamic>{};
}

Map<String, dynamic> _mergePurchaseHistoryWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..remove('receipt')
    ..remove('order_receipt')
    ..remove('orderReceipt')
    ..remove('resource')
    ..remove('data')
    ..remove('result')
    ..remove('payload');
  merged.addAll(nested);
  return merged;
}

void _preferPurchaseHistoryReceiptValue(
  Map<String, dynamic> target,
  String key,
  Object? value,
) {
  if (value == null) return;
  if (value is String && value.trim().isEmpty) return;
  target[key] = value;
}

List<Map<String, dynamic>> _purchaseHistoryTicketRows(
  Map<String, dynamic> json,
) {
  final tickets = asMapList(json['tickets']);
  if (tickets.isNotEmpty) return tickets;
  final lotteries = asMapList(json['lotteries']);
  if (lotteries.isNotEmpty) return lotteries;
  final items = asMapList(json['items']);
  if (items.isNotEmpty) return items;
  final orderItems = asMapList(json['order_items']);
  if (orderItems.isNotEmpty) return orderItems;
  final orderItemsCamel = asMapList(json['orderItems']);
  if (orderItemsCamel.isNotEmpty) return orderItemsCamel;
  final customerTickets = asMapList(json['customer_tickets']);
  if (customerTickets.isNotEmpty) return customerTickets;
  final customerTicketsCamel = asMapList(json['customerTickets']);
  if (customerTicketsCamel.isNotEmpty) return customerTicketsCamel;
  final purchaseItems = asMapList(json['purchase_items']);
  if (purchaseItems.isNotEmpty) return purchaseItems;
  return asMapList(json['purchaseItems']);
}

Map<String, dynamic> _purchaseHistoryGame(
  Map<String, dynamic> json,
  List<Map<String, dynamic>> ticketRows,
) {
  final game = asMap(json['game']);
  if (game.isNotEmpty) return game;
  final lotteryGame = asMap(json['lottery_game']);
  if (lotteryGame.isNotEmpty) return lotteryGame;
  final lotteryGameCamel = asMap(json['lotteryGame']);
  if (lotteryGameCamel.isNotEmpty) return lotteryGameCamel;

  for (final ticket in ticketRows) {
    final ticketGame = asMap(ticket['game']);
    if (ticketGame.isNotEmpty) return ticketGame;
  }

  return const <String, dynamic>{};
}

String _firstPurchaseHistoryText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _purchaseHistoryScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Object? _firstPurchaseHistoryValue(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = _purchaseHistoryScalarText(value);
    if (text.isNotEmpty) return text;
    if (value is! Map && value is! List) return value;
  }
  return null;
}

String _purchaseHistoryScalarText(Object? value, [int depth = 0]) {
  if (value == null) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString().trim();
  if (depth >= 3) return '';

  final map = asMap(value);
  if (map.isEmpty) return '';
  for (final key in const [
    'value',
    'code',
    'key',
    'id',
    'uuid',
    'reference',
    'name',
    'label',
    'text',
    'display_name',
    'displayName',
    'raw_value',
    'rawValue',
    'iso',
    'date',
    'date_time',
    'dateTime',
    'datetime',
    'timestamp',
  ]) {
    final text = _purchaseHistoryScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Map<String, dynamic> _firstPurchaseHistoryMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

class PurchaseHistoryPage {
  const PurchaseHistoryPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  factory PurchaseHistoryPage.fromJson(Map<String, dynamic> json) {
    final payload = _purchaseHistoryPagePayload(json);
    final meta = _purchaseHistoryPageMeta(json, payload);
    return PurchaseHistoryPage(
      items: _purchaseHistoryPageRows(json, payload)
          .map(PurchaseHistoryOrder.fromJson)
          .toList(growable: false),
      currentPage: _purchaseHistoryPageNumber(
        [
          meta['current_page'],
          meta['currentPage'],
          meta['page'],
          meta['page_number'],
          meta['pageNumber'],
        ],
        fallback: 1,
      ),
      lastPage: _purchaseHistoryPageNumber(
        [
          meta['last_page'],
          meta['lastPage'],
          meta['total_pages'],
          meta['totalPages'],
          meta['page_count'],
          meta['pageCount'],
          meta['pages'],
        ],
        fallback: 1,
      ),
    );
  }

  final List<PurchaseHistoryOrder> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

Map<String, dynamic> _purchaseHistoryPagePayload(Map<String, dynamic> json) {
  var current = json;
  for (var depth = 0; depth < 4; depth++) {
    Map<String, dynamic> nested = const {};
    for (final key in const ['data', 'result', 'resource', 'payload']) {
      final candidate = asMap(current[key]);
      if (candidate.isNotEmpty) {
        nested = candidate;
        break;
      }
    }
    if (nested.isEmpty) break;
    current = nested;
  }
  return current;
}

List<Map<String, dynamic>> _purchaseHistoryPageRows(
  Map<String, dynamic> json,
  Map<String, dynamic> payload,
) {
  final standardRows = unwrapDataList(json);
  if (standardRows.isNotEmpty) return standardRows;

  for (final source in [payload, json]) {
    for (final key in const [
      'orders',
      'histories',
      'items',
      'purchase_orders',
      'purchaseOrders',
      'order_history',
      'orderHistory',
    ]) {
      final rows = asMapList(source[key]);
      if (rows.isNotEmpty || source[key] is List) return rows;
    }
  }
  return const [];
}

Map<String, dynamic> _purchaseHistoryPageMeta(
  Map<String, dynamic> json,
  Map<String, dynamic> payload,
) {
  final standardMeta = unwrapMeta(json);
  if (standardMeta.isNotEmpty) return standardMeta;
  for (final source in [payload, json]) {
    final nested = _purchaseHistoryNestedPageMeta(source);
    if (nested.isNotEmpty) return nested;
  }
  return const {};
}

Map<String, dynamic> _purchaseHistoryNestedPageMeta(
  Map<String, dynamic> source, [
  int depth = 0,
]) {
  if (depth >= 5) return const {};
  final pagination = asMap(source['pagination']);
  if (pagination.isNotEmpty) return pagination;
  final meta = asMap(source['meta']);
  if (meta.isNotEmpty) return meta;

  for (final key in const ['data', 'result', 'resource', 'payload']) {
    final nested = asMap(source[key]);
    if (nested.isEmpty) continue;
    final candidate = _purchaseHistoryNestedPageMeta(nested, depth + 1);
    if (candidate.isNotEmpty) return candidate;
  }
  return const {};
}

int _purchaseHistoryPageNumber(
  Iterable<Object?> values, {
  required int fallback,
}) {
  for (final value in values) {
    final parsed = int.tryParse(_purchaseHistoryScalarText(value));
    if (parsed != null && parsed > 0) return parsed;
  }
  return fallback;
}

String normalizeDrawName(String value) {
  var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return '-';
  return text;
}
