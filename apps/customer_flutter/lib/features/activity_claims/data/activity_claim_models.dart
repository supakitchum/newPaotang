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
    return switch (value?.toString().toLowerCase()) {
      'submitted' ||
      'under_review' ||
      'pending' =>
        ActivityClaimStatus.submitted,
      'approved' => ActivityClaimStatus.approved,
      'paid' || 'paid_out' => ActivityClaimStatus.paid,
      'rejected' => ActivityClaimStatus.rejected,
      'cancelled' || 'canceled' => ActivityClaimStatus.cancelled,
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
    return ActivityClaimAward(
      id: json['id']?.toString() ?? '',
      activityName: json['activity_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      predictionType: json['prediction_type']?.toString() ?? '',
      amount: moneyToDisplayNumber(json['amount']),
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
    final customer = asMap(json['customer']);
    final bank = asMap(
      json['bank_account'] ?? json['payout_bank_account'] ?? json['bank'],
    );
    final wallet = asMap(json['payout_wallet'] ?? json['wallet']);
    final awardJson = asMap(json['award']);
    final award =
        awardJson.isEmpty ? null : ActivityClaimAward.fromJson(awardJson);
    final activityName = (json['activity_name'] ??
            award?.activityName ??
            awardJson['activity_name'] ??
            '')
        .toString();
    final amount = moneyToDisplayNumber(
      json['claim_amount'] ?? json['amount'] ?? awardJson['amount'],
    );

    return ActivityClaimItem(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      customerName: (customer['name'] ??
              customer['full_name'] ??
              customer['display_name'] ??
              '')
          .toString(),
      activityName: activityName,
      award: award,
      type: (award?.type ?? json['type'] ?? '').toString(),
      predictionType:
          (award?.predictionType ?? json['prediction_type'] ?? '').toString(),
      amount: amount > 0 ? amount : (award?.amount ?? 0),
      status: ActivityClaimStatus.fromApi(json['status']),
      statusRaw: json['status']?.toString().toLowerCase() ?? '',
      payoutMethod: json['payout_method']?.toString() ?? '',
      payoutLedgerId: json['payout_ledger_id']?.toString() ?? '',
      bankName: (bank['bank_name'] ??
              bank['bank'] ??
              json['bank_name'] ??
              json['payout_bank_name'] ??
              '')
          .toString(),
      bankAccountNumber: (bank['account_number'] ??
              bank['account_no'] ??
              bank['bank_account_no'] ??
              bank['bank_deposit_number'] ??
              json['bank_account_number'] ??
              json['account_number'] ??
              json['account_no'] ??
              json['bank_account_no'] ??
              json['bank_deposit_number'] ??
              '')
          .toString(),
      walletName:
          (wallet['name'] ?? json['wallet_name'] ?? 'G-Wallet').toString(),
      submittedAt: json['submitted_at'],
      reviewedAt: json['reviewed_at'],
      paidAt: json['paid_at'],
      createdAt: json['created_at'],
      customerNote: json['customer_note']?.toString() ?? '',
      adminNote: json['admin_note']?.toString() ?? '',
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

class ActivityClaimPage {
  const ActivityClaimPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ActivityClaimPage.fromJson(Map<String, dynamic> json) {
    final meta = unwrapMeta(json);
    return ActivityClaimPage(
      items: unwrapDataList(json)
          .map(ActivityClaimItem.fromJson)
          .toList(growable: false),
      nextCursor: meta['next_cursor']?.toString(),
      hasMore: meta['has_more'] == true && meta['next_cursor'] != null,
    );
  }

  final List<ActivityClaimItem> items;
  final String? nextCursor;
  final bool hasMore;
}

String maskActivityBankAccount(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'x xxx9';
  if (digits.length <= 4) return digits;
  return 'x xxx${digits.substring(digits.length - 4)}';
}
