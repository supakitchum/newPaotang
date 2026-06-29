import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class LotteryStockPage {
  const LotteryStockPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.gameId,
    required this.sellerName,
  });

  factory LotteryStockPage.fromJson(Object? json) {
    final payload = unwrapPayload(json);
    final meta = unwrapMeta(json);
    final seller = asMap(payload['seller']);
    return LotteryStockPage(
      items: unwrapDataList(payload).map(LotteryStockItem.fromJson).toList(
            growable: false,
          ),
      nextCursor:
          (meta['next_cursor'] ?? meta['cursor'] ?? meta['seed'])?.toString() ??
              '',
      hasMore: meta['has_more'] == true,
      gameId: meta['game_id']?.toString() ?? '',
      sellerName: (seller['name'] ?? meta['seller_name'])?.toString() ?? '',
    );
  }

  final List<LotteryStockItem> items;
  final String nextCursor;
  final bool hasMore;
  final String gameId;
  final String sellerName;
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
          .toString(),
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
      raw: Map<String, dynamic>.from(json),
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
  final Map<String, dynamic> raw;

  bool get isAvailable =>
      remainingCount > 0 &&
      status != 'sold_out' &&
      status != 'reserved' &&
      status != 'sold';

  bool get isReserved => reservationId.isNotEmpty;
}

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
    return LotteryReservation(
      id: json['id']?.toString() ?? '',
      gameId: json['game_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'active',
      expiresAt: json['expires_at'],
      expiresInSeconds:
          int.tryParse(json['expires_in_seconds']?.toString() ?? '') ?? 0,
      serverTime: json['server_time'],
      items: asMapList(json['items']).map((item) {
        return LotteryStockItem.fromJson({
          ...item,
          'reservation_id': json['id'],
          'reservation_expires_at': json['expires_at'],
          'server_time': json['server_time'],
        });
      }).toList(growable: false),
      total: moneyToDisplayNumber(json['total']),
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
    final reservations = asMapList(payload['reservations'])
        .map(LotteryReservation.fromJson)
        .toList(growable: false);
    return LotteryCart(
      reservations: reservations,
      total: moneyToDisplayNumber(payload['total']),
      itemCount: int.tryParse(payload['item_count']?.toString() ?? '') ??
          reservations.fold<int>(0, (sum, row) => sum + row.items.length),
      serverTime: payload['server_time'],
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
    final payload = unwrapPayload(json);
    return LotteryCheckoutOrder(
      id: payload['id']?.toString() ?? '',
      reference: payload['reference']?.toString() ?? '',
      status: payload['status']?.toString() ?? '',
      paymentStatus: payload['payment_status']?.toString() ?? '',
      paymentMethod: payload['payment_method']?.toString() ?? '',
      total: moneyToDisplayNumber(payload['total']),
      ticketCount: int.tryParse(payload['ticket_count']?.toString() ?? '') ??
          asMapList(payload['tickets']).length,
      redirectUrl: payload['redirect_url']?.toString() ?? '',
      paidAt: payload['paid_at'],
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
}

String _normalizeLotteryNumber(Object? value) {
  final digits = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length >= 6) {
    return digits.substring(digits.length - 6);
  }
  return digits.padLeft(6, '0');
}
