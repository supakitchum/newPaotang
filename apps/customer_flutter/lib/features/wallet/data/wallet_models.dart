import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class CustomerWallet {
  const CustomerWallet({
    required this.id,
    required this.name,
    required this.type,
    required this.balance,
    this.isPrimary = false,
  });

  factory CustomerWallet.fromJson(Map<String, dynamic> json) {
    final payload = _walletPayload(json);
    final type = _firstWalletText([
      payload['type'],
      payload['wallet_type'],
      payload['walletType'],
      payload['kind'],
    ]);
    return CustomerWallet(
      id: _firstWalletText([
        payload['id'],
        payload['wallet_id'],
        payload['walletId'],
        payload['primary_wallet_id'],
        payload['primaryWalletId'],
      ]),
      name: _firstWalletText(
        [
          payload['name'],
          payload['display_name'],
          payload['displayName'],
          payload['wallet_name'],
          payload['walletName'],
        ],
      ),
      type: type,
      balance: _firstWalletAmount(
            [
              payload['balance'],
              payload['available_balance'],
              payload['availableBalance'],
              payload['current_balance'],
              payload['currentBalance'],
              payload['wallet_balance'],
              payload['walletBalance'],
              payload['amount'],
            ],
          ) ??
          0,
      isPrimary: _walletBool([
        payload['is_primary'],
        payload['isPrimary'],
        payload['primary'],
        payload['is_default'],
        payload['isDefault'],
        payload['default'],
      ]),
    );
  }

  final String id;
  final String name;
  final String type;
  final double balance;
  final bool isPrimary;
}

class WalletLedgerEntry {
  const WalletLedgerEntry({
    required this.id,
    required this.entryType,
    required this.referenceType,
    required this.referenceId,
    required this.reason,
    required this.amount,
    required this.balanceAfter,
    required this.createdAt,
  });

  factory WalletLedgerEntry.fromJson(Map<String, dynamic> json) {
    final payload = _walletLedgerPayload(json);
    final entryType = _firstWalletText([
      payload['entry_type'],
      payload['entryType'],
      payload['type'],
      payload['transaction_type'],
      payload['transactionType'],
      payload['direction'],
      payload['flow'],
      payload['flow_type'],
      payload['flowType'],
    ]);
    final referenceType = _firstWalletText([
      payload['reference_type'],
      payload['referenceType'],
      payload['ref_type'],
      payload['refType'],
      payload['source_type'],
      payload['sourceType'],
    ]);
    final amountSource = _walletLedgerAmountSource(payload);
    final amount = _walletSignedAmount(
      amountSource.amount,
      entryType: entryType,
      referenceType: referenceType,
      directionHint: amountSource.direction,
      debitFlag: _walletBool([
        payload['is_debit'],
        payload['isDebit'],
        payload['debit'],
        payload['outflow'],
        payload['is_outflow'],
        payload['isOutflow'],
      ]),
      creditFlag: _walletBool([
        payload['is_credit'],
        payload['isCredit'],
        payload['credit'],
        payload['inflow'],
        payload['is_inflow'],
        payload['isInflow'],
      ]),
    );
    return WalletLedgerEntry(
      id: _firstWalletText([
        payload['id'],
        payload['ledger_id'],
        payload['ledgerId'],
        payload['transaction_id'],
        payload['transactionId'],
        payload['wallet_transaction_id'],
        payload['walletTransactionId'],
      ]),
      entryType: entryType,
      referenceType: referenceType,
      referenceId: _firstWalletText([
        payload['reference_id'],
        payload['referenceId'],
        payload['ref_id'],
        payload['refId'],
        payload['order_id'],
        payload['orderId'],
        payload['topup_id'],
        payload['topupId'],
        payload['claim_id'],
        payload['claimId'],
        payload['transaction_ref'],
        payload['transactionRef'],
        payload['transaction_reference'],
        payload['transactionReference'],
      ]),
      reason: _firstWalletText([
        payload['reason'],
        payload['description'],
        payload['title'],
        payload['note'],
        payload['memo'],
      ]),
      amount: amount,
      balanceAfter: _firstWalletAmount(
            [
              payload['balance_after'],
              payload['balanceAfter'],
              payload['running_balance'],
              payload['runningBalance'],
              payload['current_balance'],
              payload['currentBalance'],
              payload['balance'],
            ],
          ) ??
          0,
      createdAt: _firstWalletValue([
        payload['created_at'],
        payload['createdAt'],
        payload['posted_at'],
        payload['postedAt'],
        payload['transaction_at'],
        payload['transactionAt'],
        payload['date'],
      ]),
    );
  }

  final String id;
  final String entryType;
  final String referenceType;
  final String referenceId;
  final String reason;
  final double amount;
  final double balanceAfter;
  final Object? createdAt;

  bool get isCredit => amount > 0;
  bool get isDebit => amount < 0;
}

enum WalletLedgerDirection { all, incoming, outgoing }

class WalletLedgerPage {
  const WalletLedgerPage({
    required this.entries,
    this.nextCursor = '',
    this.hasMore = false,
  });

  final List<WalletLedgerEntry> entries;
  final String nextCursor;
  final bool hasMore;
}

class WalletSummary {
  const WalletSummary({
    required this.wallets,
    required this.ledger,
    this.ledgerLoadFailed = false,
    this.ledgerErrorMessage = '',
    this.ledgerNextCursor = '',
    this.ledgerHasMore = false,
    this.customerNo = '',
  });

  final List<CustomerWallet> wallets;
  final List<WalletLedgerEntry> ledger;
  final bool ledgerLoadFailed;
  final String ledgerErrorMessage;
  final String ledgerNextCursor;
  final bool ledgerHasMore;
  final String customerNo;

  CustomerWallet? get primaryWallet {
    for (final wallet in wallets) {
      final type = wallet.type.trim().toLowerCase();
      if (wallet.isPrimary || type == '1' || type == 'primary') return wallet;
    }
    return wallets.isEmpty ? null : wallets.first;
  }

  double get balance => primaryWallet?.balance ?? 0;
}

Map<String, dynamic> _walletPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _walletWrapperKeys) {
    final wallet = asMap(json[key]);
    if (wallet.isEmpty) continue;
    final merged = Map<String, dynamic>.from(json)
      ..removeWhere((key, _) => _walletWrapperKeys.contains(key));
    merged.addAll(_walletPayload(wallet, depth + 1));
    return merged;
  }
  return json;
}

const _walletWrapperKeys = [
  'wallet',
  'customer_wallet',
  'customerWallet',
  'primary_wallet',
  'primaryWallet',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _walletLedgerPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  final payload = _walletLedgerContextPayload(json);
  if (depth >= 4) return payload;

  for (final key in _walletLedgerWrapperKeys) {
    final entry = asMap(payload[key]);
    if (entry.isEmpty) continue;
    final merged = Map<String, dynamic>.from(payload)
      ..removeWhere((key, _) => _walletLedgerWrapperKeys.contains(key));
    merged.addAll(_walletLedgerPayload(entry, depth + 1));
    return merged;
  }
  return payload;
}

const _walletLedgerWrapperKeys = [
  'ledger',
  'entry',
  'transaction',
  'wallet_transaction',
  'walletTransaction',
  'wallet_ledger',
  'walletLedger',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _walletLedgerContextPayload(Map<String, dynamic> json) {
  final payload = Map<String, dynamic>.from(json);

  for (final key in const [
    'metadata',
    'meta',
    'details',
    'detail',
    'attributes',
    'extra',
    'context',
  ]) {
    _copyWalletLedgerGenericContext(payload, asMap(json[key]));
  }

  for (final key in const ['reference', 'ref', 'source']) {
    _copyWalletLedgerReferenceContext(payload, asMap(json[key]));
  }

  for (final key in const [
    'order',
    'topup',
    'deposit',
    'reward_claim',
    'rewardClaim',
    'activity_claim',
    'activityClaim',
    'refund',
    'reversal',
  ]) {
    _copyWalletLedgerNamedReferenceContext(payload, key, asMap(json[key]));
  }

  return payload;
}

void _copyWalletLedgerGenericContext(
  Map<String, dynamic> payload,
  Map<String, dynamic> context,
) {
  if (context.isEmpty) return;
  for (final key in _walletLedgerGenericContextKeys) {
    if (context.containsKey(key)) payload.putIfAbsent(key, () => context[key]);
  }

  for (final key in const ['reference', 'ref', 'source']) {
    _copyWalletLedgerReferenceContext(payload, asMap(context[key]));
  }
  for (final key in const [
    'order',
    'topup',
    'deposit',
    'reward_claim',
    'rewardClaim',
    'activity_claim',
    'activityClaim',
    'refund',
    'reversal',
  ]) {
    _copyWalletLedgerNamedReferenceContext(payload, key, asMap(context[key]));
  }
}

const _walletLedgerGenericContextKeys = [
  'entry_type',
  'entryType',
  'transaction_type',
  'transactionType',
  'direction',
  'flow',
  'flow_type',
  'flowType',
  'reference_type',
  'referenceType',
  'ref_type',
  'refType',
  'source_type',
  'sourceType',
  'reference_id',
  'referenceId',
  'ref_id',
  'refId',
  'order_id',
  'orderId',
  'topup_id',
  'topupId',
  'claim_id',
  'claimId',
  'transaction_ref',
  'transactionRef',
  'transaction_reference',
  'transactionReference',
  'reason',
  'description',
  'title',
  'note',
  'memo',
  'signed_amount',
  'signedAmount',
  'amount_signed',
  'amountSigned',
  'net_amount',
  'netAmount',
  'debit_amount',
  'debitAmount',
  'outflow_amount',
  'outflowAmount',
  'withdraw_amount',
  'withdrawAmount',
  'payment_amount',
  'paymentAmount',
  'credit_amount',
  'creditAmount',
  'inflow_amount',
  'inflowAmount',
  'deposit_amount',
  'depositAmount',
  'amount',
  'transaction_amount',
  'transactionAmount',
  'display_amount',
  'displayAmount',
  'value',
  'gross_amount',
  'grossAmount',
  'paid_amount',
  'paidAmount',
  'money',
  'balance_after',
  'balanceAfter',
  'running_balance',
  'runningBalance',
  'current_balance',
  'currentBalance',
  'balance',
  'created_at',
  'createdAt',
  'posted_at',
  'postedAt',
  'transaction_at',
  'transactionAt',
  'date',
  'is_debit',
  'isDebit',
  'debit',
  'outflow',
  'is_outflow',
  'isOutflow',
  'is_credit',
  'isCredit',
  'credit',
  'inflow',
  'is_inflow',
  'isInflow',
];

void _copyWalletLedgerReferenceContext(
  Map<String, dynamic> payload,
  Map<String, dynamic> reference,
) {
  if (reference.isEmpty) return;
  _putWalletLedgerIfMissing(payload, 'reference_type', [
    reference['reference_type'],
    reference['referenceType'],
    reference['ref_type'],
    reference['refType'],
    reference['source_type'],
    reference['sourceType'],
    reference['type'],
    reference['kind'],
  ]);
  _putWalletLedgerIfMissing(payload, 'reference_id', [
    reference['reference_id'],
    reference['referenceId'],
    reference['ref_id'],
    reference['refId'],
    reference['id'],
    reference['uuid'],
    reference['code'],
    reference['number'],
  ]);
  _putWalletLedgerIfMissing(payload, 'reason', [
    reference['reason'],
    reference['description'],
    reference['title'],
    reference['note'],
    reference['memo'],
  ]);
}

void _copyWalletLedgerNamedReferenceContext(
  Map<String, dynamic> payload,
  String key,
  Map<String, dynamic> reference,
) {
  if (reference.isEmpty) return;
  _putWalletLedgerIfMissing(payload, 'reference_type', [
    reference['reference_type'],
    reference['referenceType'],
    reference['type'],
    _walletReferenceTypeFromContextKey(key),
  ]);
  _putWalletLedgerIfMissing(payload, 'reference_id', [
    reference['reference_id'],
    reference['referenceId'],
    reference['id'],
    reference['uuid'],
    reference['code'],
    reference['number'],
  ]);
  _putWalletLedgerIfMissing(payload, 'reason', [
    reference['reason'],
    reference['description'],
    reference['title'],
    reference['note'],
    reference['memo'],
  ]);
}

String _walletReferenceTypeFromContextKey(String key) {
  switch (key) {
    case 'rewardClaim':
      return 'reward_claim';
    case 'activityClaim':
      return 'activity_claim';
    case 'deposit':
      return 'topup';
    default:
      return key;
  }
}

void _putWalletLedgerIfMissing(
  Map<String, dynamic> payload,
  String key,
  Iterable<Object?> values,
) {
  if (_firstWalletText([payload[key]]).isNotEmpty) return;
  for (final value in values) {
    final text = _walletScalarText(value);
    if (text.isNotEmpty) {
      payload[key] = value;
      return;
    }
  }
}

String _firstWalletText(Iterable<Object?> values, {String fallback = ''}) {
  for (final value in values) {
    final text = _walletScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return fallback;
}

Object? _firstWalletValue(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    final text = _walletScalarText(value);
    if (text.isNotEmpty) return text;
    if (value is! Map && value is! List) return value;
  }
  return null;
}

String _walletScalarText(Object? value, [int depth = 0]) {
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
    'type',
    'kind',
    'status',
    'state',
    'direction',
    'flow',
    'method',
    'channel',
    'reference_type',
    'referenceType',
    'ref_type',
    'refType',
    'source_type',
    'sourceType',
    'reference_id',
    'referenceId',
    'ref_id',
    'refId',
    'transaction_id',
    'transactionId',
    'ledger_id',
    'ledgerId',
    'wallet_id',
    'walletId',
    'name',
    'label',
    'title',
    'display_name',
    'displayName',
    'description',
    'reason',
    'note',
    'memo',
    'date',
    'created_at',
    'createdAt',
    'posted_at',
    'postedAt',
    'transaction_at',
    'transactionAt',
  ]) {
    if (!map.containsKey(key)) continue;
    final text = _walletScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }

  if (map.length == 1) {
    final entry = map.entries.single;
    final key = entry.key.toString().trim();
    final value = entry.value;
    final text = value is String || value is num || value is bool
        ? value.toString().trim().toLowerCase()
        : '';
    final truthy = value == true ||
        (value is num && value != 0) ||
        const {
          '1',
          'true',
          'yes',
          'y',
          'on',
          'active',
          'enabled',
          'available',
          'allowed',
          'supported',
          'primary',
          'default',
        }.contains(text);
    if (key.isNotEmpty && truthy) return key;
  }

  return '';
}

enum _WalletLedgerAmountDirection { debit, credit, signed, unknown }

class _WalletLedgerAmountSource {
  const _WalletLedgerAmountSource(this.amount, this.direction);

  final double amount;
  final _WalletLedgerAmountDirection direction;
}

_WalletLedgerAmountSource _walletLedgerAmountSource(
  Map<String, dynamic> payload,
) {
  final signed = _firstWalletAmount([
    payload['signed_amount'],
    payload['signedAmount'],
    payload['amount_signed'],
    payload['amountSigned'],
    payload['net_amount'],
    payload['netAmount'],
  ]);
  if (signed != null) {
    return _WalletLedgerAmountSource(
      signed,
      _WalletLedgerAmountDirection.signed,
    );
  }

  final debit = _firstWalletAmount([
    payload['debit_amount'],
    payload['debitAmount'],
    payload['outflow_amount'],
    payload['outflowAmount'],
    payload['withdraw_amount'],
    payload['withdrawAmount'],
    payload['payment_amount'],
    payload['paymentAmount'],
  ]);
  if (debit != null) {
    return _WalletLedgerAmountSource(
      debit,
      _WalletLedgerAmountDirection.debit,
    );
  }

  final credit = _firstWalletAmount([
    payload['credit_amount'],
    payload['creditAmount'],
    payload['inflow_amount'],
    payload['inflowAmount'],
    payload['deposit_amount'],
    payload['depositAmount'],
  ]);
  if (credit != null) {
    return _WalletLedgerAmountSource(
      credit,
      _WalletLedgerAmountDirection.credit,
    );
  }

  return _WalletLedgerAmountSource(
    _firstWalletAmount([
          payload['amount'],
          payload['transaction_amount'],
          payload['transactionAmount'],
          payload['display_amount'],
          payload['displayAmount'],
          payload['value'],
          payload['gross_amount'],
          payload['grossAmount'],
          payload['paid_amount'],
          payload['paidAmount'],
          payload['money'],
        ]) ??
        0,
    _WalletLedgerAmountDirection.unknown,
  );
}

double? _firstWalletAmount(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    final amount = _walletMoneyToDisplay(value);
    if (amount != null) return amount;
  }
  return null;
}

double? _walletMoneyToDisplay(Object? value, [int depth = 0]) {
  if (value == null) return null;
  if (value is String && value.trim().isEmpty) return null;
  if (value is num || value is String) return moneyToDisplayNumber(value);
  if (depth >= 3) return null;

  final map = asMap(value);
  if (map.isEmpty) return null;
  if (map.containsKey('amount')) return moneyToDisplayNumber(map);

  for (final key in const [
    'value',
    'balance',
    'available_balance',
    'availableBalance',
    'current_balance',
    'currentBalance',
    'wallet_balance',
    'walletBalance',
    'transaction_amount',
    'transactionAmount',
    'display_amount',
    'displayAmount',
    'gross_amount',
    'grossAmount',
    'paid_amount',
    'paidAmount',
    'money',
  ]) {
    if (!map.containsKey(key)) continue;
    final amount = _walletMoneyToDisplay(map[key], depth + 1);
    if (amount != null) return amount;
  }

  return null;
}

double _walletSignedAmount(
  double amount, {
  String entryType = '',
  String referenceType = '',
  _WalletLedgerAmountDirection directionHint =
      _WalletLedgerAmountDirection.unknown,
  bool debitFlag = false,
  bool creditFlag = false,
}) {
  if (directionHint == _WalletLedgerAmountDirection.signed) return amount;
  if (directionHint == _WalletLedgerAmountDirection.debit) {
    return -amount.abs();
  }
  if (directionHint == _WalletLedgerAmountDirection.credit) {
    return amount.abs();
  }

  final normalizedEntry = _walletLedgerToken(entryType);
  final normalizedReference = _walletLedgerToken(referenceType);
  final entryCompact = _walletLedgerCompactToken(entryType);
  final referenceCompact = _walletLedgerCompactToken(referenceType);
  final debitContext = debitFlag ||
      const {
        'debit',
        'withdraw',
        'withdrawal',
        'payment',
        'pay',
        'paid',
        'hold',
        'charge',
        'spend',
        'out',
        'outflow',
      }.contains(normalizedEntry) ||
      normalizedEntry.contains('debit') ||
      normalizedEntry.contains('withdraw') ||
      normalizedEntry.contains('outflow') ||
      entryCompact.contains('cashout') ||
      entryCompact.contains('walletdebit') ||
      entryCompact.contains('outflow') ||
      const {
        'order',
        'checkout',
        'purchase',
        'payment',
        'reservation',
      }.contains(normalizedReference) ||
      normalizedReference.contains('order') ||
      normalizedReference.contains('checkout') ||
      normalizedReference.contains('purchase') ||
      referenceCompact.contains('orderpurchase');
  final creditContext = creditFlag ||
      const {
        'credit',
        'deposit',
        'topup',
        'reversal',
        'refund',
        'reward',
        'in',
        'inflow',
      }.contains(normalizedEntry) ||
      normalizedEntry.contains('credit') ||
      normalizedEntry.contains('deposit') ||
      normalizedEntry.contains('topup') ||
      normalizedEntry.contains('inflow') ||
      entryCompact.contains('walletcredit') ||
      entryCompact.contains('cashin') ||
      entryCompact.contains('inflow') ||
      normalizedReference.contains('topup') ||
      normalizedReference.contains('reward') ||
      normalizedReference.contains('refund') ||
      normalizedReference.contains('reversal') ||
      referenceCompact.contains('rewardclaim') ||
      referenceCompact.contains('activityclaim') ||
      referenceCompact.contains('orderrefund') ||
      referenceCompact.contains('ordercancel');

  if (amount > 0 && debitContext && !creditContext) {
    return -amount;
  }
  if (amount < 0 && creditContext && !debitContext) {
    return amount.abs();
  }
  return amount;
}

String _walletLedgerToken(String value) {
  return value
      .trim()
      .replaceAllMapped(
        RegExp(r'([a-z0-9])([A-Z])'),
        (match) => '${match.group(1)}_${match.group(2)}',
      )
      .replaceAll(RegExp(r'[\s\-.]+'), '_')
      .toLowerCase();
}

String _walletLedgerCompactToken(String value) {
  return value.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toLowerCase();
}

bool _walletBool(Iterable<Object?> values) {
  for (final value in values) {
    if (value is bool) return value;
    final text = _walletScalarText(value).toLowerCase();
    if (text.isEmpty) continue;
    if (const {
      '1',
      'true',
      'yes',
      'y',
      'on',
      'active',
      'enabled',
      'available',
      'allowed',
      'supported',
      'primary',
      'default',
    }.contains(text)) {
      return true;
    }
    if (const {
      '0',
      'false',
      'no',
      'n',
      'off',
      'inactive',
      'disabled',
      'unavailable',
      'blocked',
      'unsupported',
    }.contains(text)) {
      return false;
    }
  }
  return false;
}
