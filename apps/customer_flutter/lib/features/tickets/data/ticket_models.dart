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
    final payload = _ticketPayload(json);
    final game = asMap(payload['game']);
    final rewardStatus = TicketRewardStatus.fromJson(
      asMap(
        payload['reward_status'] ??
            payload['rewardStatus'] ??
            payload['status_detail'] ??
            payload['statusDetail'],
      ),
    );
    final prizes = rewardStatus.prizes.isNotEmpty
        ? rewardStatus.prizes
        : asMapList(payload['prizes'])
            .map(TicketPrize.fromJson)
            .toList(growable: false);
    final amount = rewardStatus.prizeAmount > 0
        ? rewardStatus.prizeAmount
        : moneyToDisplayNumber(payload['prize_amount']);

    return CustomerTicket(
      id: _firstTicketText([
        payload['id'],
        payload['ticket_id'],
        payload['ticketId'],
        payload['customer_ticket_id'],
        payload['customerTicketId'],
        payload['lottery_id'],
        payload['lotteryId'],
      ]),
      orderId: _firstTicketText([payload['order_id'], payload['orderId']]),
      gameId:
          _firstTicketText([payload['game_id'], payload['gameId'], game['id']]),
      gameName: _firstTicketText([
        game['name'],
        payload['game_name'],
        payload['gameName'],
        payload['draw_name'],
        payload['drawName'],
      ]),
      drawAt: game['draw_at'] ??
          game['drawAt'] ??
          game['draw_date'] ??
          game['drawDate'] ??
          payload['draw_at'] ??
          payload['drawAt'] ??
          payload['draw_date'] ??
          payload['drawDate'],
      drawNumber: (payload['draw_no'] ??
              payload['drawNo'] ??
              payload['draw'] ??
              payload['game_no'] ??
              payload['gameNo'] ??
              game['draw_no'] ??
              game['drawNo'] ??
              game['draw'] ??
              game['game_no'] ??
              game['gameNo'] ??
              '')
          .toString(),
      setNumber: (payload['set'] ??
              payload['set_no'] ??
              payload['setNo'] ??
              payload['sort_order'] ??
              payload['sortOrder'] ??
              payload['series'] ??
              '')
          .toString(),
      number: (payload['full_number'] ??
                  payload['fullNumber'] ??
                  payload['number'] ??
                  payload['lottery_number'] ??
                  payload['lotteryNumber'] ??
                  payload['ticket_number'] ??
                  payload['ticketNumber'])
              ?.toString() ??
          '',
      status: payload['status']?.toString().toLowerCase() ?? '',
      rewardStatus: rewardStatus,
      count: int.tryParse((payload['count'] ?? 1).toString()) ?? 1,
      prizes: prizes,
      prizeAmount: prizes.isNotEmpty
          ? prizes.fold<double>(0, (total, prize) => total + prize.amount)
          : amount,
      claimable: _ticketBool(payload['claimable']) || rewardStatus.claimable,
      rewardClaimId: _firstTicketText([
        rewardStatus.rewardClaimId,
        payload['reward_claim_id'],
        payload['rewardClaimId'],
        payload['claim_id'],
        payload['claimId'],
      ]),
      imageUrl: _firstTicketText([
        payload['image_url'],
        payload['imageUrl'],
        payload['image'],
      ]),
      imageThumbUrl: _firstTicketText([
        payload['image_thumb_url'],
        payload['imageThumbUrl'],
        payload['thumb_url'],
        payload['thumbUrl'],
      ]),
      previewImageUrl: _firstTicketText([
        payload['preview_image_url'],
        payload['previewImageUrl'],
      ]),
      imageStatus: _firstTicketText([
        payload['image_status'],
        payload['imageStatus'],
      ]).toLowerCase(),
      imageError: _firstTicketText([
        payload['image_error'],
        payload['imageError'],
      ]),
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
    final payload = _ticketRewardStatusPayload(json);
    final claim = asMap(
      payload['claim'] ??
          payload['reward_claim'] ??
          payload['rewardClaim'] ??
          payload['submission'],
    );
    final payout = asMap(payload['payout']);
    return TicketRewardStatus(
      status: _normalizedTicketStatus(
        _firstTicketText([
          payload['status'],
          payload['status_code'],
          payload['statusCode'],
          payload['presentation_status'],
          payload['presentationStatus'],
          payload['state'],
          claim['ticket_status'],
          claim['ticketStatus'],
        ]),
      ),
      claimStatus: _firstTicketText([
        payload['claim_status'],
        payload['claimStatus'],
        payload['claim_status_code'],
        payload['claimStatusCode'],
        payload['presentation_status'],
        payload['presentationStatus'],
        claim['status'],
        claim['claim_status'],
        claim['claimStatus'],
        claim['presentation_status'],
        claim['presentationStatus'],
        claim['state'],
        payout['status'],
        payout['state'],
      ]).toNormalizedTicketStatus(),
      claimable: _ticketBool(
        payload['claimable'] ??
            payload['is_claimable'] ??
            payload['isClaimable'] ??
            payload['can_claim'] ??
            payload['canClaim'],
      ),
      prizeType: _firstTicketText([
        payload['prize_type'],
        payload['prizeType'],
        payload['reward_type'],
        payload['rewardType'],
        claim['prize_type'],
        claim['prizeType'],
        claim['reward_type'],
        claim['rewardType'],
      ]),
      prizeNumber: _firstTicketText([
        payload['prize_number'],
        payload['prizeNumber'],
        payload['reward_number'],
        payload['rewardNumber'],
        claim['prize_number'],
        claim['prizeNumber'],
        claim['reward_number'],
        claim['rewardNumber'],
      ]),
      prizeAmount: moneyToDisplayNumber(
        payload['prize_amount'] ??
            payload['prizeAmount'] ??
            payload['reward_amount'] ??
            payload['rewardAmount'] ??
            claim['prize_amount'] ??
            claim['prizeAmount'] ??
            claim['reward_amount'] ??
            claim['rewardAmount'],
      ),
      prizes: asMapList(payload['prizes'] ?? claim['prizes'])
          .map(TicketPrize.fromJson)
          .toList(growable: false),
      rewardClaimId: _firstTicketText([
        payload['reward_claim_id'],
        payload['rewardClaimId'],
        payload['claim_id'],
        payload['claimId'],
        claim['id'],
        claim['claim_id'],
        claim['claimId'],
        claim['reward_claim_id'],
        claim['rewardClaimId'],
      ]),
      payoutMethod: _firstTicketText([
        payload['payout_method'],
        payload['payoutMethod'],
        payload['payout_channel'],
        payload['payoutChannel'],
        claim['payout_method'],
        claim['payoutMethod'],
        claim['payout_channel'],
        claim['payoutChannel'],
        payout['payout_method'],
        payout['payoutMethod'],
        payout['method'],
      ]),
      adminNote: _firstTicketText([
        payload['admin_note'],
        payload['adminNote'],
        payload['review_note'],
        payload['reviewNote'],
        claim['admin_note'],
        claim['adminNote'],
        claim['review_note'],
        claim['reviewNote'],
        payout['admin_note'],
        payout['adminNote'],
      ]),
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
      _ticketClaimRetryStatuses.contains(status) ||
      _ticketClaimRetryStatuses.contains(claimStatus);
}

String _normalizedTicketStatus(Object? value) {
  return _ticketScalarText(value).toLowerCase().replaceAll('-', '_');
}

extension on String {
  String toNormalizedTicketStatus() => _normalizedTicketStatus(this);
}

const _ticketClaimRetryStatuses = {
  'rejected',
  'claim_rejected',
  'cancelled',
  'canceled',
  'claim_cancelled',
  'claim_canceled',
};

class TicketPrize {
  const TicketPrize({
    required this.prizeType,
    required this.prizeNumber,
    required this.amount,
  });

  factory TicketPrize.fromJson(Map<String, dynamic> json) {
    return TicketPrize(
      prizeType: _firstTicketText([
        json['prize_type'],
        json['prizeType'],
        json['reward_type'],
        json['rewardType'],
      ]),
      prizeNumber: _firstTicketText([
        json['prize_number'],
        json['prizeNumber'],
        json['reward_number'],
        json['rewardNumber'],
      ]),
      amount: moneyToDisplayNumber(
        json['amount'] ??
            json['prize_amount'] ??
            json['prizeAmount'] ??
            json['reward'] ??
            json['reward_amount'] ??
            json['rewardAmount'],
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
    final payload = unwrapPayload(json);
    final meta = {
      ...asMap(payload['pagination']),
      ...unwrapMeta(json),
    };
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : asMapList(
            payload['tickets'] ??
                payload['customer_tickets'] ??
                payload['items'],
          );
    final nextCursor =
        (meta['next_cursor'] ?? meta['cursor'] ?? meta['seed'])?.toString();
    return TicketPage(
      items: items.map(CustomerTicket.fromJson).toList(growable: false),
      nextCursor: nextCursor,
      hasMore: _ticketPageHasMore(meta['has_more']) &&
          nextCursor != null &&
          nextCursor.isNotEmpty,
      total: int.tryParse((meta['total'] ?? 0).toString()) ?? 0,
    );
  }

  final List<CustomerTicket> items;
  final String? nextCursor;
  final bool hasMore;
  final int total;
}

bool _ticketPageHasMore(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

class RewardClaimSubmission {
  const RewardClaimSubmission({
    required this.id,
    required this.status,
    required this.createdAt,
  });

  factory RewardClaimSubmission.fromJson(Map<String, dynamic> json) {
    final payload = _rewardClaimSubmissionPayload(json);
    return RewardClaimSubmission(
      id: _firstTicketText([
        payload['id'],
        payload['claim_id'],
        payload['claimId'],
        payload['reward_claim_id'],
        payload['rewardClaimId'],
      ]),
      status: _firstTicketText([
        payload['status'],
        payload['claim_status'],
        payload['claimStatus'],
        payload['presentation_status'],
        payload['presentationStatus'],
        payload['state'],
      ]),
      createdAt: _firstTicketValue([
        payload['submitted_at'],
        payload['submittedAt'],
        payload['created_at'],
        payload['createdAt'],
        payload['updated_at'],
        payload['updatedAt'],
      ]),
    );
  }

  final String id;
  final String status;
  final Object? createdAt;
}

Map<String, dynamic> _ticketPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _ticketWrapperKeys) {
    final ticket = asMap(json[key]);
    if (ticket.isEmpty) continue;
    return _mergeTicketWrapper(json, _ticketPayload(ticket, depth + 1));
  }
  return json;
}

const _ticketWrapperKeys = [
  'ticket',
  'customer_ticket',
  'customerTicket',
  'lottery',
  'item',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _ticketRewardStatusPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _ticketRewardStatusWrapperKeys) {
    final status = asMap(json[key]);
    if (status.isEmpty) continue;
    return _mergeTicketRewardStatusWrapper(
      json,
      _ticketRewardStatusPayload(status, depth + 1),
    );
  }
  return json;
}

const _ticketRewardStatusWrapperKeys = [
  'reward_status',
  'rewardStatus',
  'status_detail',
  'statusDetail',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _rewardClaimSubmissionPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _rewardClaimSubmissionWrapperKeys) {
    final claim = asMap(json[key]);
    if (claim.isEmpty) continue;
    return _mergeRewardClaimSubmissionWrapper(
      json,
      _rewardClaimSubmissionPayload(claim, depth + 1),
    );
  }
  return json;
}

const _rewardClaimSubmissionWrapperKeys = [
  'claim',
  'reward_claim',
  'rewardClaim',
  'submission',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _mergeTicketWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> ticket,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _ticketWrapperKeys.contains(key));
  merged.addAll(ticket);
  return merged;
}

Map<String, dynamic> _mergeTicketRewardStatusWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> status,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _ticketRewardStatusWrapperKeys.contains(key));
  merged.addAll(status);
  return merged;
}

Map<String, dynamic> _mergeRewardClaimSubmissionWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> claim,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere(
      (key, _) => _rewardClaimSubmissionWrapperKeys.contains(key),
    );
  merged.addAll(claim);
  return merged;
}

String _firstTicketText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _ticketScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Object? _firstTicketValue(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = _ticketScalarText(value);
    if (text.isNotEmpty) return text;
    if (value is! Map && value is! List) return value;
  }
  return null;
}

String _ticketScalarText(Object? value, [int depth = 0]) {
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
    'slug',
    'status',
    'state',
    'claim_status',
    'claimStatus',
    'presentation_status',
    'presentationStatus',
    'method',
    'channel',
    'payout_method',
    'payoutMethod',
    'payout_channel',
    'payoutChannel',
    'type',
    'name',
    'label',
    'title',
    'display_name',
    'displayName',
    'number',
    'account_number',
    'accountNumber',
    'ledger_id',
    'ledgerId',
  ]) {
    if (!map.containsKey(key)) continue;
    final text = _ticketScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }

  if (map.length == 1) {
    final entry = map.entries.single;
    if (_ticketBool(entry.value)) return entry.key.toString().trim();
  }

  return '';
}

bool _ticketBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return const {'1', 'true', 'yes', 'y', 'on'}.contains(normalized);
}
