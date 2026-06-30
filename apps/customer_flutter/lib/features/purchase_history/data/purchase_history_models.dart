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
    final parsedTicketCount =
        int.tryParse(payload['ticket_count']?.toString() ?? '');
    final countedTickets = ticketRows.fold<int>(
      0,
      (total, ticket) =>
          total + (int.tryParse(ticket['count']?.toString() ?? '') ?? 1),
    );

    return PurchaseHistoryOrder(
      id: payload['id']?.toString() ?? '',
      reference: payload['reference']?.toString() ?? '',
      status: payload['status']?.toString() ?? '',
      paymentStatus: payload['payment_status']?.toString() ?? '',
      paymentMethod: payload['payment_method']?.toString() ?? '',
      total: moneyToDisplayNumber(payload['total'] ?? payload['amount']),
      ticketCount: parsedTicketCount ?? countedTickets,
      tickets: tickets,
      gameName: game['name']?.toString() ?? '',
      drawAt: game['draw_at'],
      walletName: wallet['name']?.toString() ?? 'G Wallet',
      paymentProvider: payment['provider']?.toString() ?? '',
      paymentReference:
          (payment['provider_reference'] ?? payment['reference'] ?? '')
              .toString(),
      redirectUrl:
          (payload['redirect_url'] ?? payment['redirect_url'])?.toString() ??
              '',
      storeName: (store['name'] ?? '').toString(),
      paidAt: payload['paid_at'],
      createdAt: payload['created_at'],
      updatedAt: payload['updated_at'],
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
  final order = asMap(json['order']);
  if (order.isEmpty) return json;

  final merged = Map<String, dynamic>.from(order);

  for (final key in const [
    'reference',
    'status',
    'payment_status',
    'payment_method',
    'redirect_url',
    'paid_at',
    'created_at',
    'updated_at',
  ]) {
    _preferPurchaseHistoryReceiptValue(merged, key, json[key]);
  }

  _preferPurchaseHistoryReceiptValue(merged, 'total', json['total']);
  _preferPurchaseHistoryReceiptValue(merged, 'amount', json['amount']);
  _preferPurchaseHistoryReceiptValue(
    merged,
    'ticket_count',
    json['ticket_count'] ?? json['count'],
  );

  for (final key in const ['game', 'wallet', 'payment', 'store']) {
    final value = asMap(json[key]);
    if (value.isNotEmpty) {
      merged[key] = {
        ...asMap(merged[key]),
        ...value,
      };
    }
  }

  for (final key in const ['tickets', 'lotteries']) {
    final value = asMapList(json[key]);
    if (value.isNotEmpty && _purchaseHistoryTicketRows(merged).isEmpty) {
      merged[key] = value;
    }
  }

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
  return asMapList(json['lotteries']);
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
