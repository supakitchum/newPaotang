import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

enum ActivityClaimStatus {
  submitted,
  approved,
  paid,
  rejected,
  cancelled,
  unknown;

  static ActivityClaimStatus fromApi(Object? value) {
    final normalized =
        value?.toString().trim().toLowerCase().replaceAll('-', '_');
    return switch (normalized) {
      'submitted' ||
      'claim_submitted' ||
      'claim_pending' ||
      'under_review' ||
      'pending_review' ||
      'in_review' ||
      'pending' =>
        ActivityClaimStatus.submitted,
      'approved' ||
      'claim_approved' ||
      'pending_transfer' ||
      'transfer_pending' ||
      'waiting_transfer' =>
        ActivityClaimStatus.approved,
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
        ActivityClaimStatus.paid,
      'rejected' ||
      'claim_rejected' ||
      'declined' =>
        ActivityClaimStatus.rejected,
      'cancelled' ||
      'canceled' ||
      'claim_cancelled' ||
      'claim_canceled' =>
        ActivityClaimStatus.cancelled,
      _ => ActivityClaimStatus.unknown,
    };
  }
}

enum ActivityClaimPayoutMethod {
  walletCredit,
  bankTransfer;

  String get apiValue {
    return switch (this) {
      ActivityClaimPayoutMethod.walletCredit => 'wallet_credit',
      ActivityClaimPayoutMethod.bankTransfer => 'bank_transfer',
    };
  }
}

class ActivityClaimAward {
  const ActivityClaimAward({
    required this.id,
    required this.activityName,
    required this.type,
    required this.predictionType,
    required this.amount,
  });

  factory ActivityClaimAward.fromJson(Map<String, dynamic> json) {
    final payload = _activityClaimAwardPayload(json);
    final activity = asMap(payload['activity']);
    return ActivityClaimAward(
      id: _firstActivityClaimText([
        payload['id'],
        payload['award_id'],
        payload['awardId'],
        payload['activity_award_id'],
        payload['activityAwardId'],
      ]),
      activityName: _firstActivityClaimText([
        payload['activity_name'],
        payload['activityName'],
        activity['name'],
        activity['title'],
      ]),
      type: _firstActivityClaimText([
        payload['type'],
        payload['award_type'],
        payload['awardType'],
        payload['reward_type'],
        payload['rewardType'],
      ]),
      predictionType: _firstActivityClaimText([
        payload['prediction_type'],
        payload['predictionType'],
        payload['prediction'],
      ]),
      amount: moneyToDisplayNumber(
        payload['amount'] ??
            payload['claim_amount'] ??
            payload['claimAmount'] ??
            payload['award_amount'] ??
            payload['awardAmount'] ??
            payload['reward_amount'] ??
            payload['rewardAmount'],
      ),
    );
  }

  final String id;
  final String activityName;
  final String type;
  final String predictionType;
  final double amount;

  bool get isCashback => type == 'cashback';
}

class ActivityClaimItem {
  const ActivityClaimItem({
    required this.id,
    required this.reference,
    required this.customerName,
    required this.activityName,
    required this.award,
    required this.type,
    required this.predictionType,
    required this.amount,
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
    required this.customerNote,
    required this.adminNote,
  });

  factory ActivityClaimItem.fromJson(Map<String, dynamic> json) {
    final payload = _activityClaimItemPayload(json);
    final customer = asMap(payload['customer']);
    final payout = asMap(payload['payout']);
    final bankTransferPayout = _firstActivityClaimMap([
      payload['bank_transfer'],
      payload['bankTransfer'],
      payload['payout_bank_transfer'],
      payload['payoutBankTransfer'],
      payout['bank_transfer'],
      payout['bankTransfer'],
    ]);
    final walletCreditPayout = _firstActivityClaimMap([
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
    final awardJson = _activityClaimAwardJson(payload);
    final award =
        awardJson.isEmpty ? null : ActivityClaimAward.fromJson(awardJson);
    final activity = asMap(payload['activity']);
    final activityName = _firstActivityClaimText([
      payload['activity_name'],
      payload['activityName'],
      award?.activityName,
      awardJson['activity_name'],
      awardJson['activityName'],
      activity['name'],
      activity['title'],
    ]);
    final amount = moneyToDisplayNumber(
      payload['claim_amount'] ??
          payload['claimAmount'] ??
          payload['amount'] ??
          payload['award_amount'] ??
          payload['awardAmount'] ??
          payload['reward_amount'] ??
          payload['rewardAmount'] ??
          awardJson['amount'],
    );
    final statusValue = _firstActivityClaimText([
      payload['status'],
      payload['claim_status'],
      payload['claimStatus'],
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
    final payoutMethod = _normalizedActivityClaimPayoutMethod(
      _firstActivityClaimText([
        payload['payout_method'],
        payload['payoutMethod'],
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

    return ActivityClaimItem(
      id: _firstActivityClaimText([
        payload['id'],
        payload['claim_id'],
        payload['claimId'],
        payload['activity_claim_id'],
        payload['activityClaimId'],
      ]),
      reference: _firstActivityClaimText([
        payload['reference'],
        payload['claim_reference'],
        payload['claimReference'],
        payload['transaction_reference'],
        payload['transactionReference'],
      ]),
      customerName: _firstActivityClaimText([
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
      activityName: activityName,
      award: award,
      type: _firstActivityClaimText([
        award?.type,
        payload['type'],
        payload['award_type'],
        payload['awardType'],
        payload['reward_type'],
        payload['rewardType'],
      ]),
      predictionType: _firstActivityClaimText([
        award?.predictionType,
        payload['prediction_type'],
        payload['predictionType'],
        payload['prediction'],
      ]),
      amount: amount > 0 ? amount : (award?.amount ?? 0),
      status: ActivityClaimStatus.fromApi(statusValue),
      statusRaw: statusValue.toLowerCase(),
      payoutMethod: payoutMethod,
      payoutLedgerId: _firstActivityClaimText([
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
      bankName: (bank['bank_name'] ??
              bank['bankName'] ??
              bank['bank'] ??
              bank['display_name'] ??
              bank['displayName'] ??
              bank['bank_display_name'] ??
              bank['bankDisplayName'] ??
              bank['name'] ??
              bank['display'] ??
              payload['bank_name'] ??
              payload['bankName'] ??
              payload['payout_bank_name'] ??
              payload['payoutBankName'] ??
              bankTransferPayout['bank_name'] ??
              bankTransferPayout['bankName'] ??
              bankTransferPayout['payout_bank_name'] ??
              bankTransferPayout['payoutBankName'] ??
              '')
          .toString(),
      bankAccountNumber: (bank['account_number'] ??
              bank['accountNumber'] ??
              bank['account_no'] ??
              bank['accountNo'] ??
              bank['bank_account_no'] ??
              bank['bankAccountNo'] ??
              bank['bank_deposit_number'] ??
              bank['bankDepositNumber'] ??
              bank['bank_deposit_no'] ??
              bank['bankDepositNo'] ??
              bank['number'] ??
              payload['bank_account_number'] ??
              payload['bankAccountNumber'] ??
              payload['account_number'] ??
              payload['accountNumber'] ??
              payload['account_no'] ??
              payload['accountNo'] ??
              payload['bank_account_no'] ??
              payload['bankAccountNo'] ??
              payload['bank_deposit_number'] ??
              payload['bankDepositNumber'] ??
              payload['bank_deposit_no'] ??
              payload['bankDepositNo'] ??
              bankTransferPayout['bank_account_number'] ??
              bankTransferPayout['bankAccountNumber'] ??
              bankTransferPayout['account_number'] ??
              bankTransferPayout['accountNumber'] ??
              '')
          .toString(),
      walletName: (wallet['name'] ??
              wallet['display_name'] ??
              wallet['displayName'] ??
              wallet['wallet_name'] ??
              wallet['walletName'] ??
              wallet['label'] ??
              payload['wallet_name'] ??
              payload['walletName'] ??
              payload['payout_wallet_name'] ??
              payload['payoutWalletName'] ??
              walletCreditPayout['wallet_name'] ??
              walletCreditPayout['walletName'] ??
              walletCreditPayout['payout_wallet_name'] ??
              walletCreditPayout['payoutWalletName'] ??
              '')
          .toString(),
      submittedAt: payload['submitted_at'] ??
          payload['submittedAt'] ??
          payload['requested_at'] ??
          payload['requestedAt'] ??
          payload['claimed_at'] ??
          payload['claimedAt'],
      reviewedAt: payload['reviewed_at'] ?? payload['reviewedAt'],
      paidAt: payload['paid_at'] ??
          payload['paidAt'] ??
          payload['transferred_at'] ??
          payload['transferredAt'] ??
          payload['payout_at'] ??
          payload['payoutAt'] ??
          payout['paid_at'] ??
          payout['paidAt'] ??
          payout['transferred_at'] ??
          payout['transferredAt'] ??
          payout['payout_at'] ??
          payout['payoutAt'] ??
          bankTransferPayout['paid_at'] ??
          bankTransferPayout['paidAt'] ??
          bankTransferPayout['transferred_at'] ??
          bankTransferPayout['transferredAt'] ??
          bankTransferPayout['payout_at'] ??
          bankTransferPayout['payoutAt'] ??
          walletCreditPayout['paid_at'] ??
          walletCreditPayout['paidAt'] ??
          walletCreditPayout['transferred_at'] ??
          walletCreditPayout['transferredAt'] ??
          walletCreditPayout['payout_at'] ??
          walletCreditPayout['payoutAt'],
      createdAt: payload['created_at'] ?? payload['createdAt'],
      customerNote: _firstActivityClaimText([
        payload['customer_note'],
        payload['customerNote'],
      ]),
      adminNote: _firstActivityClaimText([
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
  final String activityName;
  final ActivityClaimAward? award;
  final String type;
  final String predictionType;
  final double amount;
  final ActivityClaimStatus status;
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
  final String customerNote;
  final String adminNote;

  bool get isPaid {
    if (status == ActivityClaimStatus.paid) return true;
    return status == ActivityClaimStatus.approved &&
        (paidAt != null || payoutLedgerId.trim().isNotEmpty);
  }

  bool get isRejected =>
      status == ActivityClaimStatus.rejected ||
      status == ActivityClaimStatus.cancelled;

  String get displayReference => reference.isEmpty ? '#$id' : reference;
}

Map<String, dynamic> _activityClaimItemPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _activityClaimWrapperKeys) {
    final claim = asMap(json[key]);
    if (claim.isEmpty) continue;
    return _mergeActivityClaimWrapper(
      json,
      _activityClaimItemPayload(claim, depth + 1),
    );
  }
  return json;
}

const _activityClaimWrapperKeys = [
  'claim',
  'activity_claim',
  'activityClaim',
  'item',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _activityClaimAwardPayload(Map<String, dynamic> json) {
  for (final key in const [
    'award',
    'activity_award',
    'activityAward',
    'reward',
    'prize',
    'item',
    'resource',
  ]) {
    final award = asMap(json[key]);
    if (award.isEmpty) continue;
    final merged = Map<String, dynamic>.from(json)
      ..remove('award')
      ..remove('activity_award')
      ..remove('activityAward')
      ..remove('reward')
      ..remove('prize')
      ..remove('item')
      ..remove('resource');
    merged.addAll(award);
    return merged;
  }
  return json;
}

Map<String, dynamic> _activityClaimAwardJson(Map<String, dynamic> payload) {
  for (final key in const [
    'award',
    'activity_award',
    'activityAward',
    'reward',
    'prize',
  ]) {
    final award = asMap(payload[key]);
    if (award.isNotEmpty) {
      final merged = Map<String, dynamic>.from(payload)
        ..remove('award')
        ..remove('activity_award')
        ..remove('activityAward')
        ..remove('reward')
        ..remove('prize');
      merged.addAll(award);
      return merged;
    }
  }

  final awardId = _firstActivityClaimText([
    payload['award_id'],
    payload['awardId'],
    payload['activity_award_id'],
    payload['activityAwardId'],
  ]);
  final activityName = _firstActivityClaimText([
    payload['activity_name'],
    payload['activityName'],
    asMap(payload['activity'])['name'],
    asMap(payload['activity'])['title'],
  ]);
  final type = _firstActivityClaimText([
    payload['type'],
    payload['award_type'],
    payload['awardType'],
    payload['reward_type'],
    payload['rewardType'],
  ]);
  final predictionType = _firstActivityClaimText([
    payload['prediction_type'],
    payload['predictionType'],
    payload['prediction'],
  ]);
  final amount = payload['amount'] ??
      payload['claim_amount'] ??
      payload['claimAmount'] ??
      payload['award_amount'] ??
      payload['awardAmount'] ??
      payload['reward_amount'] ??
      payload['rewardAmount'];

  if (awardId.isEmpty &&
      activityName.isEmpty &&
      type.isEmpty &&
      predictionType.isEmpty &&
      amount == null) {
    return const <String, dynamic>{};
  }

  return {
    if (awardId.isNotEmpty) 'id': awardId,
    if (activityName.isNotEmpty) 'activity_name': activityName,
    if (type.isNotEmpty) 'type': type,
    if (predictionType.isNotEmpty) 'prediction_type': predictionType,
    if (amount != null) 'amount': amount,
  };
}

Map<String, dynamic> _mergeActivityClaimWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> claim,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _activityClaimWrapperKeys.contains(key));
  merged.addAll(claim);
  return merged;
}

String _normalizedActivityClaimPayoutMethod(String value) {
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

Map<String, dynamic> _firstActivityClaimMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

class ActivityClaimPage {
  const ActivityClaimPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ActivityClaimPage.fromJson(Map<String, dynamic> json) {
    final payload = _activityClaimPagePayload(json);
    final meta = _activityClaimPageMeta(json, payload);
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : asMapList(
            payload['claims'] ??
                payload['activity_claims'] ??
                payload['activityClaims'] ??
                payload['items'],
          );
    final nextCursor = (meta['next_cursor'] ??
            meta['nextCursor'] ??
            meta['cursor'] ??
            meta['seed'])
        ?.toString();
    return ActivityClaimPage(
      items: items.map(ActivityClaimItem.fromJson).toList(growable: false),
      nextCursor: nextCursor,
      hasMore: _activityClaimPageHasMore(meta['has_more'] ?? meta['hasMore']) &&
          nextCursor != null &&
          nextCursor.isNotEmpty,
    );
  }

  final List<ActivityClaimItem> items;
  final String? nextCursor;
  final bool hasMore;
}

Map<String, dynamic> _activityClaimPagePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _activityClaimPageWrapperKeys) {
    final page = asMap(json[key]);
    if (page.isEmpty) continue;
    return _mergeActivityClaimPageWrapper(
      json,
      _activityClaimPagePayload(page, depth + 1),
    );
  }

  return json;
}

const _activityClaimPageWrapperKeys = [
  'page',
  'claim_page',
  'claimPage',
  'claims_page',
  'claimsPage',
  'activity_claim_page',
  'activityClaimPage',
  'activity_claims_page',
  'activityClaimsPage',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _activityClaimPageMeta(
  Map<String, dynamic> original,
  Map<String, dynamic> payload,
) {
  return {
    ...unwrapMeta(original),
    ...asMap(payload['pagination']),
    ...asMap(payload['meta']),
  };
}

Map<String, dynamic> _mergeActivityClaimPageWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _activityClaimPageWrapperKeys.contains(key));
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

bool _activityClaimPageHasMore(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

String maskActivityBankAccount(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'x xxx9';
  if (digits.length <= 4) return digits;
  return 'x xxx${digits.substring(digits.length - 4)}';
}

String _firstActivityClaimText(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}
