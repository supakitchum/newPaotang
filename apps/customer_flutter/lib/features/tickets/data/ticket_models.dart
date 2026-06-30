import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class CustomerTicket {
  const CustomerTicket({
    required this.id,
    required this.gameId,
    required this.gameName,
    required this.drawAt,
    required this.drawNumber,
    required this.setNumber,
    required this.number,
    required this.status,
    required this.rewardStatus,
    required this.count,
    required this.prizes,
    required this.prizeAmount,
    required this.claimable,
    required this.rewardClaimId,
    required this.imageUrl,
    required this.imageThumbUrl,
    required this.previewImageUrl,
    required this.imageStatus,
    required this.imageError,
    this.orderId = '',
  });

  factory CustomerTicket.fromJson(Map<String, dynamic> json) {
    final game = asMap(json['game']);
    final rewardStatus = TicketRewardStatus.fromJson(
      asMap(json['reward_status']),
    );
    final prizes = rewardStatus.prizes.isNotEmpty
        ? rewardStatus.prizes
        : asMapList(json['prizes'])
            .map(TicketPrize.fromJson)
            .toList(growable: false);
    final amount = rewardStatus.prizeAmount > 0
        ? rewardStatus.prizeAmount
        : moneyToDisplayNumber(json['prize_amount']);

    return CustomerTicket(
      id: json['id']?.toString() ?? '',
      orderId: json['order_id']?.toString() ?? '',
      gameId: (json['game_id'] ?? game['id'] ?? '').toString(),
      gameName: (game['name'] ?? '').toString(),
      drawAt: game['draw_at'] ?? json['draw_at'],
      drawNumber: (json['draw_no'] ??
              json['draw'] ??
              json['game_no'] ??
              game['draw_no'] ??
              game['draw'] ??
              game['game_no'] ??
              '')
          .toString(),
      setNumber: (json['set'] ??
              json['set_no'] ??
              json['sort_order'] ??
              json['series'] ??
              '')
          .toString(),
      number: (json['full_number'] ?? json['number'] ?? json['lottery_number'])
              ?.toString() ??
          '',
      status: json['status']?.toString().toLowerCase() ?? '',
      rewardStatus: rewardStatus,
      count: int.tryParse((json['count'] ?? 1).toString()) ?? 1,
      prizes: prizes,
      prizeAmount: prizes.isNotEmpty
          ? prizes.fold<double>(0, (total, prize) => total + prize.amount)
          : amount,
      claimable: json['claimable'] == true || rewardStatus.claimable,
      rewardClaimId: (rewardStatus.rewardClaimId ??
              json['reward_claim_id'] ??
              json['claim_id'] ??
              '')
          .toString(),
      imageUrl: (json['image_url'] ?? json['image'] ?? '').toString(),
      imageThumbUrl: (json['image_thumb_url'] ?? '').toString(),
      previewImageUrl: (json['preview_image_url'] ?? '').toString(),
      imageStatus: (json['image_status'] ?? '').toString().toLowerCase(),
      imageError: (json['image_error'] ?? '').toString(),
    );
  }

  final String id;
  final String orderId;
  final String gameId;
  final String gameName;
  final Object? drawAt;
  final String drawNumber;
  final String setNumber;
  final String number;
  final String status;
  final TicketRewardStatus rewardStatus;
  final int count;
  final List<TicketPrize> prizes;
  final double prizeAmount;
  final bool claimable;
  final String rewardClaimId;
  final String imageUrl;
  final String imageThumbUrl;
  final String previewImageUrl;
  final String imageStatus;
  final String imageError;

  String get primaryImageUrl {
    if (imageUrl.trim().isNotEmpty) return imageUrl;
    if (previewImageUrl.trim().isNotEmpty) return previewImageUrl;
    return imageThumbUrl;
  }

  String get thumbnailUrl {
    if (imageThumbUrl.trim().isNotEmpty) return imageThumbUrl;
    if (previewImageUrl.trim().isNotEmpty) return previewImageUrl;
    return imageUrl;
  }

  bool get hasImage => primaryImageUrl.trim().isNotEmpty;

  bool get hasExistingClaim => rewardClaimId.trim().isNotEmpty;

  String get displayDrawNumber {
    final value = drawNumber.trim();
    if (value.isNotEmpty) return value;
    return gameId.trim();
  }

  String get displaySetNumber {
    final value = setNumber.trim();
    if (value.isNotEmpty) return value;
    return count > 0 ? count.toString() : '';
  }

  bool get canCreateClaim {
    if (!claimable) return false;
    if (hasExistingClaim && !rewardStatus.isRejectedOrCancelled) return false;
    return true;
  }
}

class TicketRewardStatus {
  const TicketRewardStatus({
    required this.status,
    required this.claimStatus,
    required this.claimable,
    required this.prizeType,
    required this.prizeNumber,
    required this.prizeAmount,
    required this.prizes,
    required this.rewardClaimId,
    required this.payoutMethod,
    required this.adminNote,
  });

  factory TicketRewardStatus.fromJson(Map<String, dynamic> json) {
    return TicketRewardStatus(
      status: json['status']?.toString().toLowerCase() ?? '',
      claimStatus: json['claim_status']?.toString().toLowerCase() ?? '',
      claimable: json['claimable'] == true,
      prizeType: json['prize_type']?.toString() ?? '',
      prizeNumber: json['prize_number']?.toString() ?? '',
      prizeAmount: moneyToDisplayNumber(json['prize_amount']),
      prizes: asMapList(json['prizes'])
          .map(TicketPrize.fromJson)
          .toList(growable: false),
      rewardClaimId: json['reward_claim_id']?.toString(),
      payoutMethod: json['payout_method']?.toString() ?? '',
      adminNote: json['admin_note']?.toString() ?? '',
    );
  }

  final String status;
  final String claimStatus;
  final bool claimable;
  final String prizeType;
  final String prizeNumber;
  final double prizeAmount;
  final List<TicketPrize> prizes;
  final String? rewardClaimId;
  final String payoutMethod;
  final String adminNote;

  bool get isRejectedOrCancelled =>
      claimStatus == 'rejected' || claimStatus == 'cancelled';
}

class TicketPrize {
  const TicketPrize({
    required this.prizeType,
    required this.prizeNumber,
    required this.amount,
  });

  factory TicketPrize.fromJson(Map<String, dynamic> json) {
    return TicketPrize(
      prizeType: json['prize_type']?.toString() ?? '',
      prizeNumber: json['prize_number']?.toString() ?? '',
      amount: moneyToDisplayNumber(
        json['amount'] ?? json['prize_amount'] ?? json['reward'],
      ),
    );
  }

  final String prizeType;
  final String prizeNumber;
  final double amount;
}

class TicketPage {
  const TicketPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.total,
  });

  factory TicketPage.fromJson(Map<String, dynamic> json) {
    final meta = unwrapMeta(json);
    return TicketPage(
      items: unwrapDataList(json)
          .map(CustomerTicket.fromJson)
          .toList(growable: false),
      nextCursor: meta['next_cursor']?.toString(),
      hasMore: meta['has_more'] == true && meta['next_cursor'] != null,
      total: int.tryParse((meta['total'] ?? 0).toString()) ?? 0,
    );
  }

  final List<CustomerTicket> items;
  final String? nextCursor;
  final bool hasMore;
  final int total;
}

class RewardClaimSubmission {
  const RewardClaimSubmission({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory RewardClaimSubmission.fromJson(Map<String, dynamic> json) {
    return RewardClaimSubmission(
      id: json['id']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt:
          json['submitted_at'] ?? json['created_at'] ?? json['updated_at'],
    );
  }

  final String id;
  final String status;
  final Object? createdAt;
}
