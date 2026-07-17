import '../../../core/payment/payment_redirect_url.dart';
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
      'qr' ||
      'qr_code' ||
      'qrcode' ||
      'promptpay' ||
      'prompt_pay' ||
      'thai_qr' ||
      'thaiqr' =>
        TopupChannel.qr,
      'credit' ||
      'credit_card' ||
      'credit_qr' ||
      'credit_qrcode' ||
      'credit_qr_code' ||
      'creditcard' ||
      'card_qr' ||
      'cardqr' =>
        TopupChannel.creditCard,
      'bank' ||
      'bank_transfer' ||
      'banktransfer' ||
      'transfer' ||
      'manual' ||
      'manual_transfer' ||
      'bank_deposit' ||
      'transfer_slip' =>
        TopupChannel.bankTransfer,
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
    return switch (value?.toString().trim().toLowerCase()) {
      '1' => TopupStatus.approved,
      '2' => TopupStatus.pendingReview,
      '0' => TopupStatus.rejected,
      'pending_payment' ||
      'pendingpayment' ||
      'pending-payment' ||
      'processing' =>
        TopupStatus.pendingPayment,
      'pending_review' ||
      'pendingreview' ||
      'pending-review' ||
      'pending' =>
        TopupStatus.pendingReview,
      'approved' ||
      'paid' ||
      'completed' ||
      'complete' ||
      'success' ||
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
    this.minimumAmount,
    this.iconUrl = '',
  });

  factory TopupPaymentMethod.fromJson(Map<String, dynamic> json) {
    final rawKey = _firstTopupText([
      json['key'],
      json['channel'],
      json['type'],
      json['value'],
      json['method'],
      json['payment_method'],
      json['paymentMethod'],
      json['provider'],
      json['code'],
      json['slug'],
    ]);
    final channel = TopupChannel.tryFromApi(rawKey);
    final meta = {
      ...asMap(json['metadata']),
      ...asMap(json['meta']),
      ...asMap(json['config']),
    };

    return TopupPaymentMethod(
      key: channel?.apiValue ?? rawKey,
      label: _firstTopupText([
        json['label'],
        json['title'],
        json['name'],
        json['display_name'],
        json['displayName'],
      ]),
      enabled: _topupMethodEnabled(json),
      description: _firstTopupText([
        json['description'],
        json['subtitle'],
        json['details'],
        json['note'],
      ]),
      iconUrl: _firstTopupText([
        json['icon_url'],
        json['iconUrl'],
        json['logo_url'],
        json['logoUrl'],
        json['image_url'],
        json['imageUrl'],
        json['asset_url'],
        json['assetUrl'],
        meta['icon_url'],
        meta['iconUrl'],
        meta['logo_url'],
        meta['logoUrl'],
        meta['image_url'],
        meta['imageUrl'],
        meta['asset_url'],
        meta['assetUrl'],
      ]),
      minimumAmount: _optionalTopupMoney([
        json['minimum_amount'],
        json['minimumAmount'],
        json['min_amount'],
        json['minAmount'],
        json['minimum_topup_amount'],
        json['minimumTopupAmount'],
        json['min_topup_amount'],
        json['minTopupAmount'],
        json['amount_min'],
        json['amountMin'],
        json['minimum'],
        meta['minimum_amount'],
        meta['minimumAmount'],
        meta['min_amount'],
        meta['minAmount'],
        meta['minimum_topup_amount'],
        meta['minimumTopupAmount'],
        meta['min_topup_amount'],
        meta['minTopupAmount'],
        meta['amount_min'],
        meta['amountMin'],
        meta['minimum'],
      ]),
    );
  }

  final String key;
  final String label;
  final bool enabled;
  final String description;
  final double? minimumAmount;
  final String iconUrl;
}

class TopupBankAccount {
  const TopupBankAccount({
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.iconUrl = '',
  });

  factory TopupBankAccount.fromJson(Map<String, dynamic> json) {
    final bankPayload = json['bank'];
    final bank = asMap(bankPayload);
    return TopupBankAccount(
      bankName: _firstTopupText([
        bank['name'],
        bank['bank_name'],
        bank['bankName'],
        bank['label'],
        bank['display_name'],
        bank['displayName'],
        json['bank_name'],
        json['bankName'],
        json['bank_label'],
        json['bankLabel'],
        if (bankPayload is! Map) bankPayload,
      ]),
      accountName: _firstTopupText([
        json['bank_deposit_name'],
        json['bankDepositName'],
        json['account_name'],
        json['accountName'],
        json['bank_account_name'],
        json['bankAccountName'],
      ]),
      accountNumber: _firstTopupText([
        json['bank_deposit_number'],
        json['bankDepositNumber'],
        json['bank_deposit_no'],
        json['bankDepositNo'],
        json['account_number'],
        json['accountNumber'],
        json['account_no'],
        json['accountNo'],
        json['bank_account_number'],
        json['bankAccountNumber'],
        json['bank_account_no'],
        json['bankAccountNo'],
      ]),
      iconUrl: _firstTopupText([
        bank['icon_url'],
        bank['iconUrl'],
        bank['logo_url'],
        bank['logoUrl'],
        bank['image_url'],
        bank['imageUrl'],
        json['bank_icon_url'],
        json['bankIconUrl'],
        json['bank_logo_url'],
        json['bankLogoUrl'],
        json['icon_url'],
        json['iconUrl'],
        json['logo_url'],
        json['logoUrl'],
      ]),
    );
  }

  final String bankName;
  final String accountName;
  final String accountNumber;
  final String iconUrl;

  bool get hasDisplayValue {
    return bankName.isNotEmpty ||
        accountName.isNotEmpty ||
        accountNumber.isNotEmpty;
  }

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
    final payload = _topupItemPayload(json);
    final payment = asMap(payload['payment']);
    final slip = payload['slip'];
    final slipMap = asMap(slip);
    final slipUrl = payload['slip_url'] ??
        payload['slipUrl'] ??
        payload['slip_full_url'] ??
        payload['slipFullUrl'] ??
        payload['slip_file_url'] ??
        payload['slipFileUrl'] ??
        slipMap['url'] ??
        slipMap['full_url'] ??
        slipMap['fullUrl'] ??
        slipMap['file_url'] ??
        slipMap['fileUrl'] ??
        slipMap['image_url'] ??
        slipMap['imageUrl'] ??
        (slip is String ? slip : null);
    return TopupRequestItem(
      id: _firstTopupText([
        payload['id'],
        payload['topup_id'],
        payload['topupId'],
        payload['deposit_id'],
        payload['depositId'],
        payload['request_id'],
        payload['requestId'],
      ]),
      amount: moneyToDisplayNumber(
        payload['amount'] ??
            payload['topup_amount'] ??
            payload['topupAmount'] ??
            payload['deposit_amount'] ??
            payload['depositAmount'] ??
            payload['total_amount'] ??
            payload['totalAmount'],
      ),
      bonusAmount: moneyToDisplayNumber(
        payload['bonus_amount'] ??
            payload['bonusAmount'] ??
            payload['promotion_amount'] ??
            payload['promotionAmount'],
      ),
      status: TopupStatus.fromApi(
        payload['presentation_status'] ??
            payload['presentationStatus'] ??
            payload['status_raw'] ??
            payload['statusRaw'] ??
            payload['payment_status'] ??
            payload['paymentStatus'] ??
            payload['status'] ??
            payment['status'],
      ),
      channel: TopupChannel.fromApi(
        _firstTopupText([
          payload['channel'],
          payload['payment_method'],
          payload['paymentMethod'],
          payload['payment_channel'],
          payload['paymentChannel'],
          payload['method'],
          payment['channel'],
          payment['payment_method'],
          payment['paymentMethod'],
          payment['method'],
        ]),
      ),
      provider: _firstTopupText([
        payload['provider'],
        payment['provider'],
        payment['provider_name'],
        payment['providerName'],
      ]),
      transferAt: payload['transfer_at'] ??
          payload['transferAt'] ??
          payload['transferred_at'] ??
          payload['transferredAt'],
      createdAt: payload['created_at'] ??
          payload['createdAt'] ??
          payload['requested_at'] ??
          payload['requestedAt'],
      slipUrl: slipUrl?.toString() ?? '',
      slipThumbUrl: (payload['slip_thumb_url'] ??
                  payload['slipThumbUrl'] ??
                  payload['slip_thumbnail_url'] ??
                  payload['slipThumbnailUrl'] ??
                  slipMap['thumb_url'] ??
                  slipMap['thumbUrl'] ??
                  slipMap['thumbnail_url'] ??
                  slipMap['thumbnailUrl'] ??
                  slipMap['url'])
              ?.toString() ??
          '',
      qrCode: _firstTopupText([
        payload['qr_code'],
        payload['qrCode'],
        payload['qr'],
        payment['qr_code'],
        payment['qrCode'],
        payment['qr'],
      ]),
      redirectUrl: firstPaymentRedirectUrl([
        payload['redirect_url'],
        payload['redirectUrl'],
        payload['redirect_uri'],
        payload['redirectUri'],
        payload['payment_url'],
        payload['paymentUrl'],
        payload['checkout_url'],
        payload['checkoutUrl'],
        payload['payment_link'],
        payload['paymentLink'],
        payload['checkout_link'],
        payload['checkoutLink'],
        payment['redirect_url'],
        payment['redirectUrl'],
        payment['redirect_uri'],
        payment['redirectUri'],
        payment['payment_url'],
        payment['paymentUrl'],
        payment['checkout_url'],
        payment['checkoutUrl'],
        payment['payment_link'],
        payment['paymentLink'],
        payment['checkout_link'],
        payment['checkoutLink'],
        payment['url'],
        payload,
        payment,
      ]),
      message: _firstTopupText([
        payload['message'],
        payload['payment_message'],
        payload['paymentMessage'],
        payload['instruction'],
        payload['instructions'],
        payment['message'],
        payment['payment_message'],
        payment['paymentMessage'],
        payment['instruction'],
        payment['instructions'],
      ]),
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

  Uri? get redirectUri {
    final uri = Uri.tryParse(redirectUrl.trim());
    if (uri == null || !uri.hasScheme) return null;
    final scheme = uri.scheme.toLowerCase();
    if (scheme == 'javascript' || scheme == 'data' || scheme == 'file') {
      return null;
    }
    return uri;
  }

  bool get needsSlip =>
      !status.isTerminal &&
      (channel == TopupChannel.bankTransfer ||
          channel == TopupChannel.qr ||
          channel == TopupChannel.creditCard);
}

Map<String, dynamic> _topupItemPayload(Map<String, dynamic> json) {
  for (final key in const [
    'deposit',
    'topup',
    'request',
    'item',
    'result',
    'data',
    'resource',
  ]) {
    final payload = asMap(json[key]);
    if (payload.isEmpty) continue;
    final merged = Map<String, dynamic>.from(json)
      ..remove('deposit')
      ..remove('topup')
      ..remove('request')
      ..remove('item')
      ..remove('result')
      ..remove('data')
      ..remove('resource');
    merged.addAll(_topupItemPayload(payload));
    return merged;
  }
  return json;
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
    this.banks = const [],
    this.walletName = '',
  });

  factory TopupOverview.fromJson(Map<String, dynamic> json) {
    final payload = _topupOverviewPayload(json);
    final payment = _mergeTopupMaps([
      payload['payment'],
      payload['paymentConfig'],
      payload['payments'],
      payload['paymentsConfig'],
      payload['topupPayment'],
      payload['topupPaymentConfig'],
      payload['topup_payment'],
      payload['topup_payment_config'],
    ]);
    final meta = {
      ...asMap(payload['pagination']),
      ...asMap(payload['meta']),
      ...unwrapMeta(json),
    };
    final enabled = _normalizeEnabledPaymentMethods(
      payload['enabled_payment_methods'] ??
          payload['enabledPaymentMethods'] ??
          payload['enabled_methods'] ??
          payload['enabledMethods'] ??
          payment['enabled_payment_methods'] ??
          payment['enabledPaymentMethods'] ??
          payment['enabled_methods'] ??
          payment['enabledMethods'],
    );
    final paymentMethods = _topupPaymentMethodRows(
      payload['payment_methods'] ??
          payload['paymentMethods'] ??
          payload['methods'] ??
          payload['channels'] ??
          payment['payment_methods'] ??
          payment['paymentMethods'] ??
          payment['methods'] ??
          payment['channels'],
    ).map(TopupPaymentMethod.fromJson).toList(growable: false);
    final histories = asMapList(
      payload['histories'] ??
          payload['history'] ??
          payload['topups'] ??
          payload['items'],
    );
    final waitingPayload = _waitingTopupPayload(
      payload['waiting'] ??
          payload['waitingTopup'] ??
          payload['waiting_topups'] ??
          payload['waitingTopups'] ??
          payload['pending'] ??
          payload['pendingTopup'] ??
          payload['pending_topups'] ??
          payload['pendingTopups'] ??
          payload['pending_requests'] ??
          payload['pendingRequests'],
    );
    final bank = TopupBankAccount.fromJson(
      asMap(
        payload['bank'] ??
            payload['website_bank'] ??
            payload['websiteBank'] ??
            payload['bank_account'] ??
            payload['bankAccount'],
      ),
    );
    final wallet = asMap(
      payload['wallet'] ??
          payload['primary_wallet'] ??
          payload['primaryWallet'] ??
          payload['customer_wallet'] ??
          payload['customerWallet'],
    );
    final banks = _topupBankRows(
      payload['banks'] ??
          payload['website_banks'] ??
          payload['websiteBanks'] ??
          payload['bank_accounts'] ??
          payload['bankAccounts'] ??
          payload['receiving_banks'] ??
          payload['receivingBanks'] ??
          payment['banks'] ??
          payment['website_banks'] ??
          payment['websiteBanks'] ??
          payment['bank_accounts'] ??
          payment['bankAccounts'] ??
          payment['receiving_banks'] ??
          payment['receivingBanks'],
    )
        .map(TopupBankAccount.fromJson)
        .where((bank) => bank.hasDisplayValue)
        .toList(growable: false);

    return TopupOverview(
      bank: bank,
      banks: banks.isNotEmpty
          ? banks
          : bank.hasDisplayValue
              ? [bank]
              : const [],
      paymentMethods: _normalizePaymentMethods(paymentMethods, enabled),
      enabledPaymentMethods: enabled,
      waiting: waitingPayload == null
          ? null
          : TopupRequestItem.fromJson(waitingPayload),
      histories: histories.map(TopupRequestItem.fromJson).toList(
            growable: false,
          ),
      currentPage: int.tryParse(
            (meta['current_page'] ?? meta['currentPage'] ?? meta['page'])
                    ?.toString() ??
                '',
          ) ??
          1,
      lastPage: int.tryParse(
            (meta['last_page'] ??
                        meta['lastPage'] ??
                        meta['total_page'] ??
                        meta['totalPage'] ??
                        meta['total_pages'] ??
                        meta['totalPages'])
                    ?.toString() ??
                '',
          ) ??
          1,
      walletName: _firstTopupText([
        wallet['name'],
        wallet['display_name'],
        wallet['displayName'],
        wallet['wallet_name'],
        wallet['walletName'],
        payload['wallet_name'],
        payload['walletName'],
      ]),
    );
  }

  final TopupBankAccount bank;
  final List<TopupBankAccount> banks;
  final List<TopupPaymentMethod> paymentMethods;
  final Set<String> enabledPaymentMethods;
  final TopupRequestItem? waiting;
  final List<TopupRequestItem> histories;
  final int currentPage;
  final int lastPage;
  final String walletName;

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

  TopupPaymentMethod? methodForChannel(TopupChannel channel) {
    for (final method in paymentMethods) {
      if (method.key == channel.apiValue) return method;
    }
    return null;
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
        minimumAmount: method.minimumAmount,
        iconUrl: method.iconUrl,
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

Map<String, dynamic> _mergeTopupMaps(Iterable<Object?> values) {
  final merged = <String, dynamic>{};
  for (final value in values) {
    final map = asMap(value);
    if (map.isEmpty) continue;
    merged.addAll(map);
  }
  return merged;
}

Map<String, dynamic>? _waitingTopupPayload(Object? value) {
  final map = asMap(value);
  if (map.isNotEmpty) return map;

  final rows = asMapList(value);
  if (rows.isEmpty) return null;

  Map<String, dynamic>? fallback;
  for (final row in rows) {
    final payload = _topupItemPayload(row);
    if (payload.isEmpty) continue;
    fallback ??= payload;
    if (!TopupRequestItem.fromJson(payload).status.isTerminal) {
      return payload;
    }
  }

  return fallback;
}

Map<String, dynamic> _topupOverviewPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _topupOverviewWrapperKeys) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    return _mergeTopupOverviewWrapper(
      json,
      _topupOverviewPayload(nested, depth + 1),
    );
  }

  return json;
}

const _topupOverviewWrapperKeys = [
  'overview',
  'topup_overview',
  'topupOverview',
  'page',
  'topup_page',
  'topupPage',
  'topups_page',
  'topupsPage',
  'topup_history_page',
  'topupHistoryPage',
  'deposit_page',
  'depositPage',
  'deposits_page',
  'depositsPage',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _mergeTopupOverviewWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _topupOverviewWrapperKeys.contains(key));
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

Set<String> _normalizeEnabledPaymentMethods(Object? value) {
  if (value is Map) {
    final enabled = <String>{};
    final map = Map<String, dynamic>.from(value);
    for (final entry in map.entries) {
      final row = asMap(entry.value);
      final channel = TopupChannel.tryFromApi(
        _firstTopupText([
          row['key'],
          row['channel'],
          row['value'],
          row['method'],
          row['payment_method'],
          row['paymentMethod'],
          entry.key,
        ]),
      );
      if (channel == null) continue;

      final disabled = row.isEmpty ? false : _topupMethodDisabled(row);
      final active = row.isEmpty
          ? _topupBool(entry.value, fallback: true)
          : _topupMethodActive(row);
      if (!disabled && active) enabled.add(channel.apiValue);
    }
    return enabled;
  }

  if (value is! List) return <String>{};
  return value
      .map((entry) {
        if (entry is Map) {
          final row = Map<String, dynamic>.from(entry);
          final enabled = _topupMethodActive(row);
          final disabled = _topupMethodDisabled(row);
          if (!enabled || disabled) return null;
          return TopupChannel.tryFromApi(
            (row['key'] ??
                        row['channel'] ??
                        row['value'] ??
                        row['method'] ??
                        row['payment_method'] ??
                        row['paymentMethod'])
                    ?.toString() ??
                '',
          )?.apiValue;
        }
        return TopupChannel.tryFromApi(entry.toString())?.apiValue;
      })
      .whereType<String>()
      .toSet();
}

List<Map<String, dynamic>> _topupPaymentMethodRows(Object? value) {
  if (value is List) {
    return value
        .map((entry) {
          if (entry is Map) return Map<String, dynamic>.from(entry);
          final key = entry.toString().trim();
          if (key.isEmpty) return null;
          return <String, dynamic>{'key': key, 'enabled': true};
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  final rows = asMapList(value);
  if (rows.isNotEmpty || value is List) return rows;

  final map = asMap(value);
  if (map.isEmpty) return const [];

  return map.entries.map((entry) {
    final row = asMap(entry.value);
    if (row.isEmpty) {
      return <String, dynamic>{
        'key': entry.key,
        'enabled': entry.value,
      };
    }
    return <String, dynamic>{'key': entry.key, ...row};
  }).toList(growable: false);
}

List<Map<String, dynamic>> _topupBankRows(Object? value) {
  if (value is List) {
    return value
        .map((entry) {
          if (entry is Map) return Map<String, dynamic>.from(entry);
          final label = entry.toString().trim();
          if (label.isEmpty) return null;
          return <String, dynamic>{'bank_label': label};
        })
        .whereType<Map<String, dynamic>>()
        .toList(growable: false);
  }

  final rows = asMapList(value);
  if (rows.isNotEmpty || value is List) return rows;

  final map = asMap(value);
  if (map.isEmpty) return const [];

  final looksLikeSingleBank = _firstTopupText([
        map['bank_name'],
        map['bankName'],
        map['bank_label'],
        map['bankLabel'],
        map['account_name'],
        map['accountName'],
        map['account_number'],
        map['accountNumber'],
        map['bank_deposit_number'],
        map['bankDepositNumber'],
      ]).isNotEmpty ||
      asMap(map['bank']).isNotEmpty;
  if (looksLikeSingleBank) return [map];

  return map.entries
      .map((entry) {
        final row = asMap(entry.value);
        if (row.isEmpty) {
          final label = entry.value?.toString().trim() ?? '';
          if (label.isEmpty) return null;
          return <String, dynamic>{'bank_label': label};
        }
        return <String, dynamic>{'bank_label': entry.key, ...row};
      })
      .whereType<Map<String, dynamic>>()
      .toList(growable: false);
}

double? _optionalTopupMoney(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return moneyToDisplayNumber(value);
  }
  return null;
}

String _firstTopupText(Iterable<Object?> values) {
  for (final value in values) {
    final text = value?.toString().trim() ?? '';
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _topupMethodEnabled(Map<String, dynamic> json) {
  if (_topupMethodDisabled(json)) return false;
  return _topupMethodActive(json);
}

bool _topupMethodDisabled(Map<String, dynamic> json) {
  return _topupBool(
    json['disabled'] ??
        json['is_disabled'] ??
        json['isDisabled'] ??
        json['hidden'] ??
        json['is_hidden'] ??
        json['isHidden'] ??
        json['unsupported'] ??
        json['is_unsupported'] ??
        json['isUnsupported'],
    fallback: false,
  );
}

bool _topupMethodActive(Map<String, dynamic> json) {
  final supported = json['supported'] ??
      json['is_supported'] ??
      json['isSupported'] ??
      json['allowed'] ??
      json['is_allowed'] ??
      json['isAllowed'] ??
      json['visible'] ??
      json['is_visible'] ??
      json['isVisible'];
  if (supported != null && !_topupBool(supported, fallback: true)) {
    return false;
  }
  return _topupBool(
    json['enabled'] ??
        json['is_enabled'] ??
        json['isEnabled'] ??
        json['active'] ??
        json['is_active'] ??
        json['isActive'] ??
        json['available'] ??
        json['is_available'] ??
        json['isAvailable'] ??
        json['configured'] ??
        json['is_configured'] ??
        json['isConfigured'] ??
        json['status'],
    fallback: true,
  );
}

bool _topupBool(Object? value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (const {
    '1',
    'true',
    'yes',
    'y',
    'on',
    'enabled',
    'active',
    'ready',
    'available',
    'configured',
    'supported',
    'allowed',
    'visible',
  }.contains(normalized)) {
    return true;
  }
  if (const {
    '0',
    'false',
    'no',
    'n',
    'off',
    'disabled',
    'inactive',
    'unavailable',
    'hidden',
    'maintenance',
    'blocked',
    'unsupported',
    'not_supported',
    'not-supported',
    'denied',
    'not_allowed',
    'not-allowed',
  }.contains(normalized)) {
    return false;
  }
  return fallback;
}
