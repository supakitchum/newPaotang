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
    required this.storeName,
    required this.paidAt,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PurchaseHistoryOrder.fromJson(Map<String, dynamic> json) {
    final game = asMap(json['game']);
    final wallet = asMap(json['wallet']);
    final payment = asMap(json['payment']);
    final store = asMap(json['store']);
    final tickets = asMapList(json['tickets'])
        .map(PurchaseHistoryTicket.fromJson)
        .toList(growable: false);

    return PurchaseHistoryOrder(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      paymentStatus: json['payment_status']?.toString() ?? '',
      paymentMethod: json['payment_method']?.toString() ?? '',
      total: moneyToDisplayNumber(json['total'] ?? json['amount']),
      ticketCount: int.tryParse(
            (json['ticket_count'] ?? tickets.length).toString(),
          ) ??
          tickets.length,
      tickets: tickets,
      gameName: game['name']?.toString() ??
          (tickets.isEmpty ? '' : asMap(json['game'])['name']?.toString()) ??
          '',
      drawAt: game['draw_at'],
      walletName: wallet['name']?.toString() ?? 'G Wallet',
      paymentProvider: payment['provider']?.toString() ?? '',
      paymentReference:
          (payment['provider_reference'] ?? payment['reference'] ?? '')
              .toString(),
      storeName: (store['name'] ?? '').toString(),
      paidAt: json['paid_at'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
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
