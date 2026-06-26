import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

enum TopupChannel {
  qr('qr'),
  creditCard('credit_card'),
  bankTransfer('bank_transfer');

  const TopupChannel(this.apiValue);

  final String apiValue;

  static TopupChannel? tryFromApi(String value) {
    return switch (value.trim().toLowerCase()) {
      'qr' || 'qr_code' || 'qrcode' => TopupChannel.qr,
      'credit' ||
      'credit_card' ||
      'credit_qr' ||
      'credit_qrcode' ||
      'credit_qr_code' =>
        TopupChannel.creditCard,
      'bank' || 'bank_transfer' || 'transfer' => TopupChannel.bankTransfer,
      _ => null,
    };
  }

  static TopupChannel fromApi(String value) {
    return tryFromApi(value) ?? TopupChannel.qr;
  }
}

enum TopupStatus {
  pendingPayment,
  pendingReview,
  approved,
  rejected,
  cancelled,
  expired,
  unknown;

  static TopupStatus fromApi(Object? value) {
    return switch (value?.toString()) {
      'pending_payment' || 'processing' => TopupStatus.pendingPayment,
      'pending_review' || 'pending' => TopupStatus.pendingReview,
      'approved' ||
      'paid' ||
      'completed' ||
      'succeeded' =>
        TopupStatus.approved,
      'rejected' || 'failed' => TopupStatus.rejected,
      'cancelled' || 'canceled' => TopupStatus.cancelled,
      'expired' => TopupStatus.expired,
      _ => TopupStatus.unknown,
    };
  }

  bool get isTerminal {
    return switch (this) {
      TopupStatus.approved ||
      TopupStatus.rejected ||
      TopupStatus.cancelled ||
      TopupStatus.expired =>
        true,
      _ => false,
    };
  }
}

class TopupPaymentMethod {
  const TopupPaymentMethod({
    required this.key,
    required this.label,
    required this.enabled,
    required this.description,
  });

  factory TopupPaymentMethod.fromJson(Map<String, dynamic> json) {
    final channel = TopupChannel.tryFromApi(
      (json['key'] ?? json['channel'] ?? json['type'])?.toString() ?? '',
    );

    return TopupPaymentMethod(
      key: channel?.apiValue ?? json['key']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      enabled: json['enabled'] != false,
      description: json['description']?.toString() ?? '',
    );
  }

  final String key;
  final String label;
  final bool enabled;
  final String description;
}

class TopupBankAccount {
  const TopupBankAccount({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
  });

  factory TopupBankAccount.fromJson(Map<String, dynamic> json) {
    final bank = asMap(json['bank']);
    return TopupBankAccount(
      bankName: (bank['name'] ?? json['bank_name'] ?? json['bank_label'])
              ?.toString() ??
          '',
      accountName: json['bank_deposit_name']?.toString() ?? '',
      accountNumber: json['bank_deposit_number']?.toString() ?? '',
    );
  }

  final String bankName;
  final String accountName;
  final String accountNumber;

  bool get isConfigured => accountNumber.isNotEmpty || accountName.isNotEmpty;
}

class TopupRequestItem {
  const TopupRequestItem({
    required this.id,
    required this.amount,
    required this.bonusAmount,
    required this.status,
    required this.channel,
    required this.provider,
    required this.transferAt,
    required this.createdAt,
    required this.slipUrl,
    required this.slipThumbUrl,
    required this.qrCode,
    required this.redirectUrl,
    required this.message,
  });

  factory TopupRequestItem.fromJson(Map<String, dynamic> json) {
    final payment = asMap(json['payment']);
    return TopupRequestItem(
      id: json['id']?.toString() ?? '',
      amount: moneyToDisplayNumber(json['amount']),
      bonusAmount: moneyToDisplayNumber(json['bonus_amount']),
      status: TopupStatus.fromApi(
        json['presentation_status'] ?? json['status_raw'] ?? json['status'],
      ),
      channel: TopupChannel.fromApi(json['channel']?.toString() ?? ''),
      provider: json['provider']?.toString() ?? '',
      transferAt: json['transfer_at'],
      createdAt: json['created_at'],
      slipUrl: json['slip_url']?.toString() ?? '',
      slipThumbUrl: json['slip_thumb_url']?.toString() ?? '',
      qrCode: (json['qr_code'] ?? payment['qr_code'])?.toString() ?? '',
      redirectUrl:
          (json['redirect_url'] ?? payment['redirect_url'])?.toString() ?? '',
      message: (json['message'] ?? payment['message'])?.toString() ?? '',
    );
  }

  final String id;
  final double amount;
  final double bonusAmount;
  final TopupStatus status;
  final TopupChannel channel;
  final String provider;
  final Object? transferAt;
  final Object? createdAt;
  final String slipUrl;
  final String slipThumbUrl;
  final String qrCode;
  final String redirectUrl;
  final String message;

  bool get needsSlip =>
      !status.isTerminal &&
      (channel == TopupChannel.bankTransfer || qrCode.isNotEmpty);
}

class TopupOverview {
  const TopupOverview({
    required this.bank,
    required this.paymentMethods,
    required this.enabledPaymentMethods,
    required this.waiting,
    required this.histories,
    required this.currentPage,
    required this.lastPage,
  });

  factory TopupOverview.fromJson(Map<String, dynamic> json) {
    final meta = asMap(json['meta']);
    final enabled = json['enabled_payment_methods'] is List
        ? (json['enabled_payment_methods'] as List)
            .map((value) => value.toString())
            .toSet()
        : <String>{};
    final paymentMethods = asMapList(json['payment_methods'])
        .map(TopupPaymentMethod.fromJson)
        .toList(growable: false);

    return TopupOverview(
      bank: TopupBankAccount.fromJson(asMap(json['bank'])),
      paymentMethods: _normalizePaymentMethods(paymentMethods, enabled),
      enabledPaymentMethods: enabled,
      waiting: json['waiting'] is Map
          ? TopupRequestItem.fromJson(asMap(json['waiting']))
          : null,
      histories: asMapList(json['histories'])
          .map(TopupRequestItem.fromJson)
          .toList(growable: false),
      currentPage: int.tryParse(meta['current_page']?.toString() ?? '') ?? 1,
      lastPage: int.tryParse(meta['last_page']?.toString() ?? '') ?? 1,
    );
  }

  final TopupBankAccount bank;
  final List<TopupPaymentMethod> paymentMethods;
  final Set<String> enabledPaymentMethods;
  final TopupRequestItem? waiting;
  final List<TopupRequestItem> histories;
  final int currentPage;
  final int lastPage;

  TopupChannel? get firstEnabledChannel {
    for (final channel in TopupChannel.values) {
      if (isChannelEnabled(channel)) return channel;
    }
    return null;
  }

  bool isChannelEnabled(TopupChannel channel) {
    if (enabledPaymentMethods.isNotEmpty) {
      return enabledPaymentMethods.contains(channel.apiValue);
    }

    for (final method in paymentMethods) {
      if (method.key == channel.apiValue) return method.enabled;
    }
    return paymentMethods.isEmpty;
  }

  static List<TopupPaymentMethod> _normalizePaymentMethods(
    List<TopupPaymentMethod> methods,
    Set<String> enabledMethods,
  ) {
    if (methods.isEmpty && enabledMethods.isEmpty) {
      return const [];
    }

    final byKey = <String, TopupPaymentMethod>{};
    for (final method in methods) {
      final channel = TopupChannel.tryFromApi(method.key);
      if (channel == null) continue;
      byKey[channel.apiValue] = TopupPaymentMethod(
        key: channel.apiValue,
        label: method.label,
        enabled: enabledMethods.isNotEmpty
            ? enabledMethods.contains(channel.apiValue)
            : method.enabled,
        description: method.description,
      );
    }

    return [
      for (final channel in TopupChannel.values)
        byKey[channel.apiValue] ??
            TopupPaymentMethod(
              key: channel.apiValue,
              label: '',
              enabled: enabledMethods.isNotEmpty
                  ? enabledMethods.contains(channel.apiValue)
                  : false,
              description: '',
            ),
    ];
  }
}
