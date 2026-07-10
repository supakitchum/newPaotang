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
      id: (json['affiliate_id'] ?? json['store_id'] ?? json['id'])
              ?.toString() ??
          '',
      name: (json['store_name'] ??
                  json['name'] ??
                  json['display_name'] ??
                  json['seller_name'])
              ?.toString() ??
          '',
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
    final payload = unwrapPayload(json);
    final meta = {
      ...asMap(payload['pagination']),
      ...unwrapMeta(json),
    };
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : asMapList(
            payload['stores'] ??
                payload['store_list'] ??
                payload['affiliates'] ??
                payload['items'],
          );
    return StorePage(
      items: items.map(StoreItem.fromJson).toList(
            growable: false,
          ),
      nextCursor:
          (meta['next_cursor'] ?? meta['cursor'] ?? meta['seed'])?.toString() ??
              '',
      hasMore: _storeListHasMore(meta['has_more']),
    );
  }

  final List<StoreItem> items;
  final String nextCursor;
  final bool hasMore;
}

bool _storeListHasMore(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

class StoreLotteryTicket {
  const StoreLotteryTicket({
    required this.id,
    required this.token,
    required this.localStockItemId,
    required this.stockRef,
    required this.number,
    required this.drawNumber,
    required this.setNumber,
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
    this.raw = const {},
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
    final number = _normalizeStoreLotteryNumber(
      json['number'] ??
          json['full_number'] ??
          json['lottery_number'] ??
          json['fullNumber'],
    );
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
      number: number,
      drawNumber: _storeLotteryMetaText([
        json['draw_no'],
        json['drawNo'],
        json['draw_number'],
        json['drawNumber'],
        json['game_no'],
        json['gameNo'],
        json['lottery_draw_no'],
        json['lotteryDrawNo'],
        json['draw'],
      ]),
      setNumber: _storeLotteryMetaText([
        json['set'],
        json['set_no'],
        json['setNo'],
        json['set_number'],
        json['setNumber'],
        json['lottery_set'],
        json['lottery_set_no'],
        json['lotterySetNo'],
      ]),
      sellerName: sellerName,
      storeName: (json['store_name'] ?? sellerName).toString(),
      price: moneyToDisplayNumber(json['price'], fallback: 80),
      remainingCount: int.tryParse(json['remaining_count']?.toString() ?? '') ??
          int.tryParse(json['available_count']?.toString() ?? '') ??
          1,
      status: (json['availability_status'] ?? json['status'] ?? 'available')
          .toString()
          .trim()
          .toLowerCase(),
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
      raw: Map<String, dynamic>.unmodifiable(json),
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
  final String drawNumber;
  final String setNumber;
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
  final Map<String, dynamic> raw;
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
      drawNumber: drawNumber,
      setNumber: setNumber,
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
      raw: raw,
      priceTrend: priceTrend ?? this.priceTrend,
      priceFlashKey: priceFlashKey ?? this.priceFlashKey,
    );
  }

  bool get isAvailable =>
      remainingCount > 0 && !_unavailableStoreLotteryStatuses.contains(status);
}

const _unavailableStoreLotteryStatuses = {
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
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : asMapList(payload['lotteries'] ?? payload['items']);
    return StoreLotteryPage(
      items: items.map(StoreLotteryTicket.fromJson).toList(
            growable: false,
          ),
      nextCursor: meta['next_cursor']?.toString() ??
          meta['cursor']?.toString() ??
          meta['seed']?.toString() ??
          '',
      hasMore: _storeListHasMore(meta['has_more']),
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

String _normalizeStoreLotteryNumber(Object? value) {
  final digits = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  if (digits.length >= 6) {
    return digits.substring(digits.length - 6);
  }
  return digits.padLeft(6, '0');
}

String _storeLotteryMetaText(List<Object?> values) {
  for (final value in values) {
    final text = _storeLotteryScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _storeLotteryScalarText(Object? value) {
  if (value == null) return '';
  if (value is Map) {
    for (final key in const ['value', 'number', 'no', 'code', 'key', 'label']) {
      final text = _storeLotteryScalarText(value[key]);
      if (text.isNotEmpty) return text;
    }
    return '';
  }
  final text = value.toString().trim();
  if (text.isEmpty || text.toLowerCase() == 'null') return '';
  return text;
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
