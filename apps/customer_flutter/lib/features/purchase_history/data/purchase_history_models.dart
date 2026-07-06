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
      id: json['id']?.toString() ?? '',
      number: (json['full_number'] ?? json['number'] ?? json['lottery_number'])
              ?.toString() ??
          '',
      statusRaw: _statusRaw(json),
    );
  }

  final String id;
  final String number;
  final String statusRaw;

  static String _statusRaw(Map<String, dynamic> json) {
    final rewardStatus = asMap(json['reward_status']);
    return (rewardStatus['status'] ?? json['status'])
            ?.toString()
            .toLowerCase() ??
        '';
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
    final wallet = asMap(payload['wallet']);
    final payment = asMap(payload['payment']);
    final store = asMap(payload['store']);
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
          total + (int.tryParse(ticket['count']?.toString() ?? '') ?? 1),
    );

    return PurchaseHistoryOrder(
      id: _firstPurchaseHistoryText([
        payload['id'],
        payload['order_id'],
        payload['orderId'],
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
        payment['method'],
      ]),
      total: moneyToDisplayNumber(
        payload['total'] ?? payload['amount'] ?? payload['price'],
      ),
      ticketCount: parsedTicketCount ?? countedTickets,
      tickets: tickets,
      gameName: game['name']?.toString() ?? '',
      drawAt: game['draw_at'],
      walletName: _firstPurchaseHistoryText([
        wallet['name'],
        payload['wallet_name'],
        payload['walletName'],
      ]).ifEmpty('G Wallet'),
      paymentProvider: _firstPurchaseHistoryText([
        payment['provider'],
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
        payload['store_name'],
        payload['storeName'],
        payload['seller_name'],
        payload['sellerName'],
      ]),
      paidAt: payload['paid_at'] ??
          payload['paidAt'] ??
          payment['paid_at'] ??
          payment['paidAt'],
      createdAt: payload['created_at'] ?? payload['createdAt'],
      updatedAt: payload['updated_at'] ?? payload['updatedAt'],
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
  final String walletName;
  final String paymentProvider;
  final String paymentReference;
  final String redirectUrl;
  final String storeName;
  final Object? paidAt;
  final Object? createdAt;
  final Object? updatedAt;

  Object? get transactionAt => paidAt ?? updatedAt ?? createdAt;

  String get displayReference => reference.isEmpty ? 'ORDER-$id' : reference;

  String get maskedPaymentReference {
    final raw = (paymentReference.isNotEmpty ? paymentReference : reference)
        .replaceAll(RegExp(r'\s+'), '');
    if (raw.isEmpty) return '';
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    final source = digits.isEmpty ? raw : digits;
    if (source.length <= 4) return source;
    final hiddenCount = (source.length - 7).clamp(6, 24).toInt();
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
    'created_at',
    'createdAt',
    'updated_at',
    'updatedAt',
  ]) {
    _preferPurchaseHistoryReceiptValue(merged, key, receipt[key]);
  }

  _preferPurchaseHistoryReceiptValue(merged, 'total', receipt['total']);
  _preferPurchaseHistoryReceiptValue(merged, 'amount', receipt['amount']);
  _preferPurchaseHistoryReceiptValue(merged, 'price', receipt['price']);
  _preferPurchaseHistoryReceiptValue(
    merged,
    'ticket_count',
    receipt['ticket_count'] ??
        receipt['ticketCount'] ??
        receipt['item_count'] ??
        receipt['count'],
  );

  for (final key in const ['game', 'wallet', 'payment', 'store']) {
    final value = asMap(receipt[key]);
    if (value.isNotEmpty) {
      merged[key] = {
        ...asMap(merged[key]),
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
    ..remove('result');
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
  return asMapList(json['orderItems']);
}

Map<String, dynamic> _purchaseHistoryGame(
  Map<String, dynamic> json,
  List<Map<String, dynamic>> ticketRows,
) {
  final game = asMap(json['game']);
  if (game.isNotEmpty) return game;

  for (final ticket in ticketRows) {
    final ticketGame = asMap(ticket['game']);
    if (ticketGame.isNotEmpty) return ticketGame;
  }

  return const <String, dynamic>{};
}

String _firstPurchaseHistoryText(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

extension _PurchaseHistoryStringFallback on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

class PurchaseHistoryPage {
  const PurchaseHistoryPage({
    required this.items,
    required this.currentPage,
    required this.lastPage,
  });

  factory PurchaseHistoryPage.fromJson(Map<String, dynamic> json) {
    final meta = unwrapMeta(json);
    return PurchaseHistoryPage(
      items: unwrapDataList(json)
          .map(PurchaseHistoryOrder.fromJson)
          .toList(growable: false),
      currentPage: int.tryParse((meta['current_page'] ?? 1).toString()) ?? 1,
      lastPage: int.tryParse((meta['last_page'] ?? 1).toString()) ?? 1,
    );
  }

  final List<PurchaseHistoryOrder> items;
  final int currentPage;
  final int lastPage;

  bool get hasMore => currentPage < lastPage;
}

String normalizeDrawName(String value) {
  var text = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (text.isEmpty) return '-';
  return text;
}
