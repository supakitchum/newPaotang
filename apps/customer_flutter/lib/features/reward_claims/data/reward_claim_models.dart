import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

enum RewardClaimStatus {
  submitted,
  approved,
  paid,
  rejected,
  cancelled,
  unknown;

  static RewardClaimStatus fromApi(Object? value) {
    final normalized =
        _rewardClaimScalarText(value).toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'submitted' ||
      'claim_submitted' ||
      'claim_pending' ||
      'under_review' ||
      'pending_review' ||
      'in_review' ||
      'pending' =>
        RewardClaimStatus.submitted,
      'approved' ||
      'claim_approved' ||
      'pending_transfer' ||
      'transfer_pending' ||
      'waiting_transfer' =>
        RewardClaimStatus.approved,
      'paid' ||
      'paid_out' ||
      'claim_paid' ||
      'transferred' ||
      'transfer_completed' ||
      'payout_completed' ||
      'payment_completed' ||
      'completed' ||
      'complete' ||
      'success' =>
        RewardClaimStatus.paid,
      'rejected' ||
      'claim_rejected' ||
      'declined' =>
        RewardClaimStatus.rejected,
      'cancelled' ||
      'canceled' ||
      'claim_cancelled' ||
      'claim_canceled' =>
        RewardClaimStatus.cancelled,
      _ => RewardClaimStatus.unknown,
    };
  }
}

class RewardClaimPrize {
  const RewardClaimPrize({
    required this.prizeType,
    required this.prizeNumber,
    required this.amount,
  });

  factory RewardClaimPrize.fromJson(Map<String, dynamic> json) {
    final payload = _rewardClaimPrizePayload(json);
    return RewardClaimPrize(
      prizeType: _firstRewardClaimText([
        payload['prize_type'],
        payload['prizeType'],
        payload['reward_type'],
        payload['rewardType'],
        payload['type'],
      ]),
      prizeNumber: _firstRewardClaimText([
        payload['prize_number'],
        payload['prizeNumber'],
        payload['reward_number'],
        payload['rewardNumber'],
        payload['number'],
      ]),
      amount: moneyToDisplayNumber(
        payload['amount'] ??
            payload['prize_amount'] ??
            payload['prizeAmount'] ??
            payload['reward'] ??
            payload['reward_amount'] ??
            payload['rewardAmount'],
      ),
    );
  }

  final String prizeType;
  final String prizeNumber;
  final double amount;
}

class RewardClaimTicket {
  const RewardClaimTicket({
    required this.id,
    required this.number,
    required this.gameName,
    required this.drawAt,
  });

  factory RewardClaimTicket.fromJson(Map<String, dynamic> json) {
    final payload = _rewardClaimTicketPayload(json);
    final game = asMap(payload['game']);
    return RewardClaimTicket(
      id: _firstRewardClaimText([
        payload['id'],
        payload['ticket_id'],
        payload['ticketId'],
        payload['customer_ticket_id'],
        payload['customerTicketId'],
        payload['lottery_id'],
        payload['lotteryId'],
      ]),
      number: _firstRewardClaimText([
        payload['full_number'],
        payload['fullNumber'],
        payload['number'],
        payload['lottery_number'],
        payload['lotteryNumber'],
        payload['ticket_number'],
        payload['ticketNumber'],
      ]),
      gameName: _firstRewardClaimText([
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
          payload['drawDate'] ??
          payload['game_draw_at'] ??
          payload['gameDrawAt'],
    );
  }

  final String id;
  final String number;
  final String gameName;
  final Object? drawAt;
}

class RewardClaimItem {
  const RewardClaimItem({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.ticket,
    required this.prizes,
    required this.prizeType,
    required this.prizeAmount,
    required this.status,
    required this.statusRaw,
    required this.payoutMethod,
    required this.payoutLedgerId,
    required this.bankName,
    required this.bankAccountNumber,
    required this.walletName,
    required this.submittedAt,
    required this.reviewedAt,
    required this.paidAt,
    required this.createdAt,
    required this.adminNote,
  });

  factory RewardClaimItem.fromJson(Map<String, dynamic> json) {
    final payload = _rewardClaimItemPayload(json);
    final customer = asMap(payload['customer']);
    final ticketJson = _rewardClaimTicketJson(payload);
    final ticketPayload = asMap(
      payload['ticket'] ??
          payload['customer_ticket'] ??
          payload['customerTicket'] ??
          payload['lottery'] ??
          payload['lottery_ticket'] ??
          payload['lotteryTicket'],
    );
    final ticketRewardStatus = asMap(
      ticketPayload['reward_status'] ?? ticketPayload['rewardStatus'],
    );
    final payout = asMap(payload['payout']);
    final bankTransferPayout = _firstRewardClaimMap([
      payload['bank_transfer'],
      payload['bankTransfer'],
      payload['payout_bank_transfer'],
      payload['payoutBankTransfer'],
      payout['bank_transfer'],
      payout['bankTransfer'],
    ]);
    final walletCreditPayout = _firstRewardClaimMap([
      payload['wallet_credit'],
      payload['walletCredit'],
      payload['payout_wallet_credit'],
      payload['payoutWalletCredit'],
      payout['wallet_credit'],
      payout['walletCredit'],
    ]);
    final bank = asMap(
      payload['bank_account'] ??
          payload['bankAccount'] ??
          payload['payout_bank_account'] ??
          payload['payoutBankAccount'] ??
          payload['bank'] ??
          payout['bank_account'] ??
          payout['bankAccount'] ??
          payout['bank'] ??
          bankTransferPayout['bank_account'] ??
          bankTransferPayout['bankAccount'] ??
          bankTransferPayout['payout_bank_account'] ??
          bankTransferPayout['payoutBankAccount'] ??
          bankTransferPayout['recipient_bank'] ??
          bankTransferPayout['recipientBank'] ??
          bankTransferPayout['destination_bank'] ??
          bankTransferPayout['destinationBank'] ??
          bankTransferPayout['bank'],
    );
    final wallet = asMap(
      payload['payout_wallet'] ??
          payload['payoutWallet'] ??
          payload['wallet'] ??
          payout['payout_wallet'] ??
          payout['payoutWallet'] ??
          payout['wallet'] ??
          walletCreditPayout['payout_wallet'] ??
          walletCreditPayout['payoutWallet'] ??
          walletCreditPayout['destination_wallet'] ??
          walletCreditPayout['destinationWallet'] ??
          walletCreditPayout['wallet'],
    );
    final payoutLedger = asMap(
      payload['payout_ledger'] ??
          payload['payoutLedger'] ??
          payload['ledger'] ??
          payout['payout_ledger'] ??
          payout['payoutLedger'] ??
          payout['ledger'] ??
          bankTransferPayout['payout_ledger'] ??
          bankTransferPayout['payoutLedger'] ??
          bankTransferPayout['ledger'] ??
          walletCreditPayout['payout_ledger'] ??
          walletCreditPayout['payoutLedger'] ??
          walletCreditPayout['ledger'],
    );
    final prizes = _firstRewardClaimMapList([
      payload['prizes'],
      payload['reward_prizes'],
      payload['rewardPrizes'],
      payload['winning_prizes'],
      payload['winningPrizes'],
      ticketRewardStatus['prizes'],
      ticketPayload['prizes'],
    ]).map(RewardClaimPrize.fromJson).toList(growable: false);
    final prizeType = _firstRewardClaimText([
      payload['prize_type'],
      payload['prizeType'],
      payload['reward_type'],
      payload['rewardType'],
      payload['type'],
      prizes.isEmpty ? null : prizes.first.prizeType,
    ]);
    final prizeAmount = prizes.fold<double>(
      0,
      (total, prize) => total + prize.amount,
    );
    final statusValue = _firstRewardClaimText([
      payload['status'],
      payload['status_code'],
      payload['statusCode'],
      payload['claim_status'],
      payload['claimStatus'],
      payload['claim_status_code'],
      payload['claimStatusCode'],
      payload['presentation_status'],
      payload['presentationStatus'],
      payload['state'],
      payout['status'],
      payout['state'],
      bankTransferPayout['status'],
      bankTransferPayout['state'],
      walletCreditPayout['status'],
      walletCreditPayout['state'],
    ]);
    final payoutMethod = _normalizedRewardClaimPayoutMethod(
      _firstRewardClaimText([
        payload['payout_method'],
        payload['payoutMethod'],
        payload['payout_method_code'],
        payload['payoutMethodCode'],
        payload['payout_channel'],
        payload['payoutChannel'],
        payload['payout_type'],
        payload['payoutType'],
        payload['method'],
        payout['payout_method'],
        payout['payoutMethod'],
        payout['payout_channel'],
        payout['payoutChannel'],
        payout['payout_type'],
        payout['payoutType'],
        payout['method'],
        bankTransferPayout['payout_method'],
        bankTransferPayout['payoutMethod'],
        bankTransferPayout['payout_channel'],
        bankTransferPayout['payoutChannel'],
        bankTransferPayout['method'],
        walletCreditPayout['payout_method'],
        walletCreditPayout['payoutMethod'],
        walletCreditPayout['payout_channel'],
        walletCreditPayout['payoutChannel'],
        walletCreditPayout['method'],
        bankTransferPayout.isEmpty ? null : 'bank_transfer',
        walletCreditPayout.isEmpty ? null : 'wallet_credit',
      ]),
    );

    return RewardClaimItem(
      id: _firstRewardClaimText([
        payload['id'],
        payload['claim_id'],
        payload['claimId'],
        payload['reward_claim_id'],
        payload['rewardClaimId'],
      ]),
      reference: _firstRewardClaimText([
        payload['reference'],
        payload['claim_reference'],
        payload['claimReference'],
        payload['transaction_reference'],
        payload['transactionReference'],
      ]),
      customerName: _firstRewardClaimText([
        customer['name'],
        customer['full_name'],
        customer['fullName'],
        customer['display_name'],
        customer['displayName'],
        payload['customer_name'],
        payload['customerName'],
        payload['customer_full_name'],
        payload['customerFullName'],
        payload['customer_display_name'],
        payload['customerDisplayName'],
        payload['full_name'],
        payload['fullName'],
        payload['display_name'],
        payload['displayName'],
        payload['name'],
      ]),
      ticket:
          ticketJson.isEmpty ? null : RewardClaimTicket.fromJson(ticketJson),
      prizes: prizes,
      prizeType: prizeType,
      prizeAmount: prizeAmount > 0
          ? prizeAmount
          : moneyToDisplayNumber(
              payload['prize_amount'] ??
                  payload['prizeAmount'] ??
                  payload['amount'] ??
                  payload['reward_amount'] ??
                  payload['rewardAmount'],
            ),
      status: RewardClaimStatus.fromApi(statusValue),
      statusRaw: statusValue.toLowerCase(),
      payoutMethod: payoutMethod,
      payoutLedgerId: _firstRewardClaimText([
        payload['payout_ledger_id'],
        payload['payoutLedgerId'],
        payload['ledger_id'],
        payload['ledgerId'],
        payoutLedger['id'],
        payoutLedger['ledger_id'],
        payoutLedger['ledgerId'],
        payout['payout_ledger_id'],
        payout['payoutLedgerId'],
        payout['ledger_id'],
        payout['ledgerId'],
        bankTransferPayout['payout_ledger_id'],
        bankTransferPayout['payoutLedgerId'],
        bankTransferPayout['ledger_id'],
        bankTransferPayout['ledgerId'],
        walletCreditPayout['payout_ledger_id'],
        walletCreditPayout['payoutLedgerId'],
        walletCreditPayout['ledger_id'],
        walletCreditPayout['ledgerId'],
      ]),
      bankName: _firstRewardClaimText([
        bank['bank_name'],
        bank['bankName'],
        bank['bank'],
        bank['display_name'],
        bank['displayName'],
        bank['bank_display_name'],
        bank['bankDisplayName'],
        bank['name'],
        bank['display'],
        payload['bank_name'],
        payload['bankName'],
        payload['payout_bank_name'],
        payload['payoutBankName'],
        bankTransferPayout['bank_name'],
        bankTransferPayout['bankName'],
        bankTransferPayout['payout_bank_name'],
        bankTransferPayout['payoutBankName'],
      ]),
      bankAccountNumber: _firstRewardClaimText([
        bank['account_number'],
        bank['accountNumber'],
        bank['account_no'],
        bank['accountNo'],
        bank['bank_account_no'],
        bank['bankAccountNo'],
        bank['bank_deposit_number'],
        bank['bankDepositNumber'],
        bank['bank_deposit_no'],
        bank['bankDepositNo'],
        bank['number'],
        payload['bank_account_number'],
        payload['bankAccountNumber'],
        payload['account_number'],
        payload['accountNumber'],
        payload['account_no'],
        payload['accountNo'],
        payload['bank_account_no'],
        payload['bankAccountNo'],
        payload['bank_deposit_number'],
        payload['bankDepositNumber'],
        payload['bank_deposit_no'],
        payload['bankDepositNo'],
        bankTransferPayout['bank_account_number'],
        bankTransferPayout['bankAccountNumber'],
        bankTransferPayout['account_number'],
        bankTransferPayout['accountNumber'],
      ]),
      walletName: _firstRewardClaimText([
        wallet['name'],
        wallet['display_name'],
        wallet['displayName'],
        wallet['wallet_name'],
        wallet['walletName'],
        wallet['label'],
        payload['wallet_name'],
        payload['walletName'],
        payload['payout_wallet_name'],
        payload['payoutWalletName'],
        walletCreditPayout['wallet_name'],
        walletCreditPayout['walletName'],
        walletCreditPayout['payout_wallet_name'],
        walletCreditPayout['payoutWalletName'],
      ]),
      submittedAt: _firstRewardClaimValue([
        payload['submitted_at'],
        payload['submittedAt'],
        payload['requested_at'],
        payload['requestedAt'],
        payload['claimed_at'],
        payload['claimedAt'],
      ]),
      reviewedAt: _firstRewardClaimValue([
        payload['reviewed_at'],
        payload['reviewedAt'],
      ]),
      paidAt: _firstRewardClaimValue([
        payload['paid_at'],
        payload['paidAt'],
        payload['transferred_at'],
        payload['transferredAt'],
        payload['payout_at'],
        payload['payoutAt'],
        payout['paid_at'],
        payout['paidAt'],
        payout['transferred_at'],
        payout['transferredAt'],
        payout['payout_at'],
        payout['payoutAt'],
        bankTransferPayout['paid_at'],
        bankTransferPayout['paidAt'],
        bankTransferPayout['transferred_at'],
        bankTransferPayout['transferredAt'],
        bankTransferPayout['payout_at'],
        bankTransferPayout['payoutAt'],
        walletCreditPayout['paid_at'],
        walletCreditPayout['paidAt'],
        walletCreditPayout['transferred_at'],
        walletCreditPayout['transferredAt'],
        walletCreditPayout['payout_at'],
        walletCreditPayout['payoutAt'],
      ]),
      createdAt: _firstRewardClaimValue([
        payload['created_at'],
        payload['createdAt'],
      ]),
      adminNote: _firstRewardClaimText([
        payload['admin_note'],
        payload['adminNote'],
        payload['review_note'],
        payload['reviewNote'],
      ]),
    );
  }

  final String id;
  final String reference;
  final String customerName;
  final RewardClaimTicket? ticket;
  final List<RewardClaimPrize> prizes;
  final String prizeType;
  final double prizeAmount;
  final RewardClaimStatus status;
  final String statusRaw;
  final String payoutMethod;
  final String payoutLedgerId;
  final String bankName;
  final String bankAccountNumber;
  final String walletName;
  final Object? submittedAt;
  final Object? reviewedAt;
  final Object? paidAt;
  final Object? createdAt;
  final String adminNote;

  bool get isPaid {
    if (status == RewardClaimStatus.paid) return true;
    return status == RewardClaimStatus.approved &&
        (paidAt != null ||
            payoutLedgerId.trim().isNotEmpty ||
            payoutMethod == 'bank_transfer');
  }

  bool get isRejected =>
      status == RewardClaimStatus.rejected ||
      status == RewardClaimStatus.cancelled;

  bool get isPending => !isPaid && !isRejected;

  String get displayReference => reference.isEmpty ? '#$id' : reference;
}

Map<String, dynamic> _rewardClaimItemPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _rewardClaimWrapperKeys) {
    final claim = asMap(json[key]);
    if (claim.isEmpty) continue;
    return _mergeRewardClaimWrapper(
      json,
      _rewardClaimItemPayload(claim, depth + 1),
    );
  }
  return json;
}

const _rewardClaimWrapperKeys = [
  'claim',
  'reward_claim',
  'rewardClaim',
  'item',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _rewardClaimPrizePayload(Map<String, dynamic> json) {
  for (final key in const [
    'prize',
    'reward_prize',
    'rewardPrize',
    'item',
    'resource',
  ]) {
    final prize = asMap(json[key]);
    if (prize.isEmpty) continue;
    final merged = Map<String, dynamic>.from(json)
      ..remove('prize')
      ..remove('reward_prize')
      ..remove('rewardPrize')
      ..remove('item')
      ..remove('resource');
    merged.addAll(prize);
    return merged;
  }
  return json;
}

Map<String, dynamic> _rewardClaimTicketPayload(Map<String, dynamic> json) {
  for (final key in const [
    'ticket',
    'customer_ticket',
    'customerTicket',
    'lottery',
    'lottery_ticket',
    'lotteryTicket',
    'item',
    'resource',
  ]) {
    final ticket = asMap(json[key]);
    if (ticket.isEmpty) continue;
    final merged = Map<String, dynamic>.from(json)
      ..remove('ticket')
      ..remove('customer_ticket')
      ..remove('customerTicket')
      ..remove('lottery')
      ..remove('lottery_ticket')
      ..remove('lotteryTicket')
      ..remove('item')
      ..remove('resource');
    merged.addAll(ticket);
    return merged;
  }
  return json;
}

Map<String, dynamic> _rewardClaimTicketJson(Map<String, dynamic> payload) {
  for (final key in const [
    'ticket',
    'customer_ticket',
    'customerTicket',
    'lottery',
    'lottery_ticket',
    'lotteryTicket',
  ]) {
    final ticket = asMap(payload[key]);
    if (ticket.isNotEmpty) {
      final merged = Map<String, dynamic>.from(payload)
        ..remove('ticket')
        ..remove('customer_ticket')
        ..remove('customerTicket')
        ..remove('lottery')
        ..remove('lottery_ticket')
        ..remove('lotteryTicket');
      merged.addAll(ticket);
      return merged;
    }
  }

  final number = _firstRewardClaimText([
    payload['ticket_number'],
    payload['ticketNumber'],
    payload['full_number'],
    payload['fullNumber'],
    payload['lottery_number'],
    payload['lotteryNumber'],
    payload['number'],
  ]);
  final ticketId = _firstRewardClaimText([
    payload['ticket_id'],
    payload['ticketId'],
    payload['customer_ticket_id'],
    payload['customerTicketId'],
    payload['lottery_id'],
    payload['lotteryId'],
  ]);
  final gameName = _firstRewardClaimText([
    payload['game_name'],
    payload['gameName'],
    payload['draw_name'],
    payload['drawName'],
  ]);
  final drawAt = payload['draw_at'] ??
      payload['drawAt'] ??
      payload['draw_date'] ??
      payload['drawDate'] ??
      payload['game_draw_at'] ??
      payload['gameDrawAt'];
  final game = asMap(payload['game']);

  if (number.isEmpty &&
      ticketId.isEmpty &&
      gameName.isEmpty &&
      drawAt == null) {
    return const <String, dynamic>{};
  }

  return {
    if (ticketId.isNotEmpty) 'id': ticketId,
    if (number.isNotEmpty) 'full_number': number,
    if (game.isNotEmpty || gameName.isNotEmpty || drawAt != null)
      'game': {
        ...game,
        if (gameName.isNotEmpty && !game.containsKey('name')) 'name': gameName,
        if (drawAt != null && !game.containsKey('draw_at')) 'draw_at': drawAt,
      },
    if (drawAt != null) 'draw_at': drawAt,
  };
}

Map<String, dynamic> _mergeRewardClaimWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> claim,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _rewardClaimWrapperKeys.contains(key));
  merged.addAll(claim);
  return merged;
}

String _normalizedRewardClaimPayoutMethod(String value) {
  return switch (value.trim().toLowerCase()) {
    'bank' ||
    'bank_account' ||
    'bank-transfer' ||
    'banktransfer' =>
      'bank_transfer',
    'wallet' ||
    'wallet-credit' ||
    'walletcredit' ||
    'g_wallet' ||
    'g-wallet' =>
      'wallet_credit',
    final method => method,
  };
}

String _firstRewardClaimText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _rewardClaimScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Object? _firstRewardClaimValue(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = _rewardClaimScalarText(value);
    if (text.isNotEmpty) return text;
    if (value is! Map && value is! List) return value;
  }
  return null;
}

String _rewardClaimScalarText(Object? value, [int depth = 0]) {
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
    final text = _rewardClaimScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }

  if (map.length == 1) {
    final entry = map.entries.single;
    if (_rewardClaimTruthy(entry.value)) return entry.key.toString().trim();
  }

  return '';
}

bool _rewardClaimTruthy(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return const {'1', 'true', 'yes', 'y', 'on', 'active', 'enabled'}
      .contains(normalized);
}

List<Map<String, dynamic>> _firstRewardClaimMapList(Iterable<Object?> values) {
  for (final value in values) {
    final rows = asMapList(value);
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}

Map<String, dynamic> _firstRewardClaimMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

class RewardClaimPage {
  const RewardClaimPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory RewardClaimPage.fromJson(Map<String, dynamic> json) {
    final payload = _rewardClaimPagePayload(json);
    final meta = _rewardClaimPageMeta(json, payload);
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : asMapList(
            payload['claims'] ??
                payload['reward_claims'] ??
                payload['rewardClaims'] ??
                payload['items'],
          );
    final nextCursor = (meta['next_cursor'] ??
            meta['nextCursor'] ??
            meta['cursor'] ??
            meta['seed'])
        ?.toString();
    return RewardClaimPage(
      items: items.map(RewardClaimItem.fromJson).toList(growable: false),
      nextCursor: nextCursor,
      hasMore: _rewardClaimPageHasMore(meta['has_more'] ?? meta['hasMore']) &&
          nextCursor != null &&
          nextCursor.isNotEmpty,
    );
  }

  final List<RewardClaimItem> items;
  final String? nextCursor;
  final bool hasMore;
}

Map<String, dynamic> _rewardClaimPagePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _rewardClaimPageWrapperKeys) {
    final page = asMap(json[key]);
    if (page.isEmpty) continue;
    return _mergeRewardClaimPageWrapper(
      json,
      _rewardClaimPagePayload(page, depth + 1),
    );
  }

  return json;
}

const _rewardClaimPageWrapperKeys = [
  'page',
  'claim_page',
  'claimPage',
  'claims_page',
  'claimsPage',
  'reward_claim_page',
  'rewardClaimPage',
  'reward_claims_page',
  'rewardClaimsPage',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _rewardClaimPageMeta(
  Map<String, dynamic> original,
  Map<String, dynamic> payload,
) {
  return {
    ...unwrapMeta(original),
    ...asMap(payload['pagination']),
    ...asMap(payload['meta']),
  };
}

Map<String, dynamic> _mergeRewardClaimPageWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _rewardClaimPageWrapperKeys.contains(key));
  final wrapperMeta = asMap(merged['meta']);
  final nestedMeta = asMap(nested['meta']);
  final wrapperPagination = asMap(merged['pagination']);
  final nestedPagination = asMap(nested['pagination']);

  merged.addAll(nested);

  if (wrapperMeta.isNotEmpty || nestedMeta.isNotEmpty) {
    merged['meta'] = {...wrapperMeta, ...nestedMeta};
  }
  if (wrapperPagination.isNotEmpty || nestedPagination.isNotEmpty) {
    merged['pagination'] = {...wrapperPagination, ...nestedPagination};
  }

  return merged;
}

bool _rewardClaimPageHasMore(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String maskBankAccount(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'x xxx9';
  if (digits.length <= 4) return digits;
  return 'x xxx${digits.substring(digits.length - 4)}';
}
