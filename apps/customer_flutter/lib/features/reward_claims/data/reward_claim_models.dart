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
    return switch (value?.toString().toLowerCase()) {
      'submitted' || 'under_review' || 'pending' => RewardClaimStatus.submitted,
      'approved' => RewardClaimStatus.approved,
      'paid' || 'paid_out' => RewardClaimStatus.paid,
      'rejected' => RewardClaimStatus.rejected,
      'cancelled' || 'canceled' => RewardClaimStatus.cancelled,
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
    return RewardClaimPrize(
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

class RewardClaimTicket {
  const RewardClaimTicket({
    required this.id,
    required this.number,
    required this.gameName,
    required this.drawAt,
  });

  factory RewardClaimTicket.fromJson(Map<String, dynamic> json) {
    final game = asMap(json['game']);
    return RewardClaimTicket(
      id: json['id']?.toString() ?? '',
      number: (json['full_number'] ?? json['number'] ?? json['lottery_number'])
              ?.toString() ??
          '',
      gameName: game['name']?.toString() ?? '',
      drawAt: game['draw_at'] ?? json['draw_at'],
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
    final customer = asMap(json['customer']);
    final ticketJson = asMap(json['ticket']);
    final bank = asMap(json['bank_account'] ?? json['payout_bank_account']);
    final wallet = asMap(json['payout_wallet']);
    final prizes = asMapList(json['prizes'])
        .map(RewardClaimPrize.fromJson)
        .toList(growable: false);
    final prizeType = json['prize_type']?.toString() ??
        (prizes.isEmpty ? '' : prizes.first.prizeType);
    final prizeAmount = prizes.fold<double>(
      0,
      (total, prize) => total + prize.amount,
    );

    return RewardClaimItem(
      id: json['id']?.toString() ?? '',
      reference: json['reference']?.toString() ?? '',
      customerName: (customer['name'] ??
              customer['full_name'] ??
              customer['display_name'] ??
              '')
          .toString(),
      ticket:
          ticketJson.isEmpty ? null : RewardClaimTicket.fromJson(ticketJson),
      prizes: prizes,
      prizeType: prizeType,
      prizeAmount: prizeAmount > 0
          ? prizeAmount
          : moneyToDisplayNumber(json['prize_amount']),
      status: RewardClaimStatus.fromApi(json['status']),
      statusRaw: json['status']?.toString().toLowerCase() ?? '',
      payoutMethod: json['payout_method']?.toString() ?? '',
      bankName: (bank['bank_name'] ?? bank['bank'] ?? '').toString(),
      bankAccountNumber: (bank['account_number'] ??
              bank['account_no'] ??
              bank['bank_account_no'] ??
              bank['bank_deposit_number'] ??
              '')
          .toString(),
      walletName: (wallet['name'] ?? 'G-Wallet').toString(),
      submittedAt: json['submitted_at'],
      reviewedAt: json['reviewed_at'],
      paidAt: json['paid_at'],
      createdAt: json['created_at'],
      adminNote: json['admin_note']?.toString() ?? '',
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
        (paidAt != null || payoutMethod == 'bank_transfer');
  }

  bool get isRejected =>
      status == RewardClaimStatus.rejected ||
      status == RewardClaimStatus.cancelled;

  bool get isPending => !isPaid && !isRejected;

  String get displayReference => reference.isEmpty ? '#$id' : reference;
}

class RewardClaimPage {
  const RewardClaimPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory RewardClaimPage.fromJson(Map<String, dynamic> json) {
    final meta = asMap(json['meta']);
    return RewardClaimPage(
      items: unwrapDataList(json)
          .map(RewardClaimItem.fromJson)
          .toList(growable: false),
      nextCursor: meta['next_cursor']?.toString(),
      hasMore: meta['has_more'] == true && meta['next_cursor'] != null,
    );
  }

  final List<RewardClaimItem> items;
  final String? nextCursor;
  final bool hasMore;
}

String maskBankAccount(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return 'x xxx9';
  if (digits.length <= 4) return digits;
  return 'x xxx${digits.substring(digits.length - 4)}';
}
