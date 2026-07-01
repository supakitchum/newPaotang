import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class StoreItem {
  const StoreItem({
    required this.id,
    required this.name,
    required this.code,
  });

  factory StoreItem.fromJson(Map<String, dynamic> json) {
    return StoreItem(
      id: (json['affiliate_id'] ?? json['id'])?.toString() ?? '',
      name: (json['store_name'] ?? json['name'])?.toString() ?? '',
      code: json['code']?.toString() ?? '',
    );
  }

  final String id;
  final String name;
  final String code;
}

class StorePage {
  const StorePage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory StorePage.fromJson(Map<String, dynamic> json) {
    final meta = unwrapMeta(json);
    return StorePage(
      items: unwrapDataList(json).map(StoreItem.fromJson).toList(
            growable: false,
          ),
      nextCursor: meta['next_cursor']?.toString() ?? '',
      hasMore: meta['has_more'] == true,
    );
  }

  final List<StoreItem> items;
  final String nextCursor;
  final bool hasMore;
}

class StoreLotteryTicket {
  const StoreLotteryTicket({
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
    required this.imageUrl,
    required this.thumbUrl,
    required this.imageStatus,
    required this.imageError,
    this.priceTrend = '',
    this.priceFlashKey = 0,
  });

  factory StoreLotteryTicket.fromJson(Map<String, dynamic> json) {
    final id =
        (json['id'] ?? json['stock_item_id'] ?? json['token'])?.toString() ??
            '';
    final localStockItemId =
        (json['local_stock_item_id'] ?? json['id'] ?? json['token'])
                ?.toString() ??
            '';
    final number = (json['number'] ??
            json['full_number'] ??
            json['lottery_number'] ??
            json['fullNumber'])
        ?.toString()
        .replaceAll(RegExp(r'\D'), '');
    final sellerName =
        (json['seller'] ?? json['seller_name'] ?? json['store_name'] ?? '')
            .toString();
    return StoreLotteryTicket(
      id: id,
      token: json['token']?.toString() ?? id,
      localStockItemId: localStockItemId,
      stockRef:
          (json['stock_ref'] ?? json['virtual_stock_ref'] ?? id)?.toString() ??
              '',
      number: (number ?? '').padLeft(6, '0').substring(0, 6),
      sellerName: sellerName,
      storeName: (json['store_name'] ?? sellerName).toString(),
      price: moneyToDisplayNumber(json['price'], fallback: 80),
      remainingCount: int.tryParse(json['remaining_count']?.toString() ?? '') ??
          int.tryParse(json['available_count']?.toString() ?? '') ??
          1,
      status: json['availability_status']?.toString() ??
          json['status']?.toString() ??
          'available',
      reservationId: json['reservation_id']?.toString() ?? '',
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
      imageStatus: (json['image_status'] ?? '').toString(),
      imageError: (json['image_error'] ?? '').toString(),
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
  final String imageUrl;
  final String thumbUrl;
  final String imageStatus;
  final String imageError;
  final String priceTrend;
  final int priceFlashKey;

  StoreLotteryTicket copyWith({
    double? price,
    int? remainingCount,
    String? status,
    String? imageUrl,
    String? thumbUrl,
    String? imageStatus,
    String? imageError,
    String? priceTrend,
    int? priceFlashKey,
  }) {
    return StoreLotteryTicket(
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
      imageUrl: imageUrl ?? this.imageUrl,
      thumbUrl: thumbUrl ?? this.thumbUrl,
      imageStatus: imageStatus ?? this.imageStatus,
      imageError: imageError ?? this.imageError,
      priceTrend: priceTrend ?? this.priceTrend,
      priceFlashKey: priceFlashKey ?? this.priceFlashKey,
    );
  }

  bool get isAvailable =>
      remainingCount > 0 &&
      status != 'sold_out' &&
      status != 'reserved' &&
      status != 'sold';
}

class StoreLotteryPage {
  const StoreLotteryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.gameId,
    required this.sellerName,
    this.canReserve = true,
  });

  factory StoreLotteryPage.fromJson(Map<String, dynamic> json) {
    final payload = unwrapPayload(json);
    final meta = {
      ...asMap(payload['pagination']),
      ...unwrapMeta(json),
    };
    final seller = asMap(payload['seller'] ?? json['seller']);
    return StoreLotteryPage(
      items: unwrapDataList(json).map(StoreLotteryTicket.fromJson).toList(
            growable: false,
          ),
      nextCursor: meta['next_cursor']?.toString() ??
          meta['cursor']?.toString() ??
          meta['seed']?.toString() ??
          '',
      hasMore: meta['has_more'] == true,
      gameId: meta['game_id']?.toString() ?? '',
      sellerName: (seller['name'] ?? meta['seller_name'])?.toString() ?? '',
      canReserve: _storeLotteryPageCanReserve(
        payload['can_reserve'] ??
            payload['can_buy'] ??
            payload['bet_status'] ??
            meta['can_reserve'] ??
            meta['can_buy'] ??
            meta['bet_status'],
      ),
    );
  }

  final List<StoreLotteryTicket> items;
  final String nextCursor;
  final bool hasMore;
  final String gameId;
  final String sellerName;
  final bool canReserve;
}

bool _storeLotteryPageCanReserve(Object? value) {
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
