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
    final payload = unwrapPayload(json);
    final meta = asMap(payload['meta'] ?? json['meta']);
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
    required this.number,
    required this.sellerName,
    required this.price,
    required this.remainingCount,
    required this.status,
  });

  factory StoreLotteryTicket.fromJson(Map<String, dynamic> json) {
    final number = (json['number'] ??
            json['full_number'] ??
            json['lottery_number'] ??
            json['fullNumber'])
        ?.toString()
        .replaceAll(RegExp(r'\D'), '');
    return StoreLotteryTicket(
      id: (json['id'] ?? json['stock_item_id'] ?? json['token'])?.toString() ??
          '',
      token: json['token']?.toString() ?? '',
      number: (number ?? '').padLeft(6, '0').substring(0, 6),
      sellerName:
          (json['seller'] ?? json['seller_name'] ?? json['store_name'] ?? '')
              .toString(),
      price: moneyToDisplayNumber(json['price'], fallback: 80),
      remainingCount: int.tryParse(json['remaining_count']?.toString() ?? '') ??
          int.tryParse(json['available_count']?.toString() ?? '') ??
          1,
      status: json['availability_status']?.toString() ??
          json['status']?.toString() ??
          'available',
    );
  }

  final String id;
  final String token;
  final String number;
  final String sellerName;
  final double price;
  final int remainingCount;
  final String status;

  bool get isAvailable => remainingCount > 0 && status != 'sold_out';
}

class StoreLotteryPage {
  const StoreLotteryPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.gameId,
    required this.sellerName,
  });

  factory StoreLotteryPage.fromJson(Map<String, dynamic> json) {
    final meta = asMap(json['meta']);
    final seller = asMap(json['seller']);
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
    );
  }

  final List<StoreLotteryTicket> items;
  final String nextCursor;
  final bool hasMore;
  final String gameId;
  final String sellerName;
}
