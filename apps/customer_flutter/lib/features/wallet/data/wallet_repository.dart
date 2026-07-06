import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/api_payload.dart';
import 'wallet_models.dart';

final walletRepositoryProvider = Provider<WalletRepository>((ref) {
  return WalletRepository(ref.watch(apiClientProvider));
});

final walletSummaryProvider = FutureProvider<WalletSummary>((ref) async {
  return ref.watch(walletRepositoryProvider).summary();
});

class WalletRepository {
  const WalletRepository(this._api);

  final ApiClient _api;

  Future<List<CustomerWallet>> wallets() async {
    return (await _walletsPayload()).wallets;
  }

  Future<List<WalletLedgerEntry>> ledger({int limit = 12}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/wallet/ledger',
      query: {'limit': limit, 'sort_by': 'created_at', 'sort_dir': 'desc'},
    );
    return _walletLedgerRows(
      response.data,
    ).map(WalletLedgerEntry.fromJson).toList(growable: false);
  }

  Future<WalletSummary> summary() async {
    final walletPayload = await _walletsPayload();
    var ledgerLoadFailed = false;
    var ledgerErrorMessage = '';
    var ledgerEntries = <WalletLedgerEntry>[];
    try {
      ledgerEntries = await ledger();
    } catch (error) {
      ledgerLoadFailed = true;
      ledgerErrorMessage = _walletApiErrorMessage(error);
    }

    return WalletSummary(
      wallets: walletPayload.wallets,
      ledger: ledgerEntries,
      ledgerLoadFailed: ledgerLoadFailed,
      ledgerErrorMessage: ledgerErrorMessage,
      customerNo: walletPayload.customerNo,
    );
  }

  Future<_WalletsPayload> _walletsPayload() async {
    final response = await _api.get<Map<String, dynamic>>('/customer/wallet');
    return _WalletsPayload(
      wallets: _walletRows(
        response.data,
      ).map(CustomerWallet.fromJson).toList(growable: false),
      customerNo: _walletCustomerNo(response.data),
    );
  }

  String _walletApiErrorMessage(Object error) {
    final message = ApiErrorInfo.fromObject(error).message.trim();
    if (message.isEmpty) return '';
    if (error is DioException || error is Map) return message;
    return '';
  }
}

class _WalletsPayload {
  const _WalletsPayload({
    required this.wallets,
    required this.customerNo,
  });

  final List<CustomerWallet> wallets;
  final String customerNo;
}

List<Map<String, dynamic>> _walletRows(Object? value, [int depth = 0]) {
  final rows = unwrapDataList(value);
  if (rows.isNotEmpty || value is List) return rows;
  if (depth >= 4) return const <Map<String, dynamic>>[];

  final payload = unwrapPayload(value);
  for (final key in const [
    'wallets',
    'customer_wallets',
    'customerWallets',
    'items',
  ]) {
    final wallets = asMapList(payload[key]);
    if (wallets.isNotEmpty || payload[key] is List) return wallets;
  }

  for (final key in const [
    'page',
    'wallet_page',
    'walletPage',
    'wallets_page',
    'walletsPage',
    'customer_wallet_page',
    'customerWalletPage',
  ]) {
    final nestedRows = _walletRows(payload[key], depth + 1);
    if (nestedRows.isNotEmpty || payload[key] is List) return nestedRows;
  }

  for (final key in const ['data', 'result', 'resource']) {
    final nestedRows = _walletRows(payload[key], depth + 1);
    if (nestedRows.isNotEmpty || payload[key] is List) return nestedRows;
  }

  final single = asMap(
    payload['wallet'] ??
        payload['primary_wallet'] ??
        payload['primaryWallet'] ??
        payload['customer_wallet'] ??
        payload['customerWallet'],
  );
  if (single.isNotEmpty) return [single];

  if (_looksLikeWalletRow(payload)) return [payload];

  return const <Map<String, dynamic>>[];
}

List<Map<String, dynamic>> _walletLedgerRows(Object? value, [int depth = 0]) {
  final rows = unwrapDataList(value);
  if (rows.isNotEmpty || value is List) return rows;
  if (depth >= 4) return const <Map<String, dynamic>>[];

  final payload = unwrapPayload(value);
  for (final key in const [
    'entries',
    'ledger',
    'ledger_entries',
    'ledgerEntries',
    'transactions',
    'history',
    'histories',
    'records',
    'rows',
    'wallet_ledger',
    'walletLedger',
    'wallet_transactions',
    'walletTransactions',
    'items',
  ]) {
    final entries = asMapList(payload[key]);
    if (entries.isNotEmpty || payload[key] is List) return entries;
  }

  for (final key in const [
    'page',
    'ledger_page',
    'ledgerPage',
    'wallet_ledger_page',
    'walletLedgerPage',
    'transactions_page',
    'transactionsPage',
    'transaction_page',
    'transactionPage',
    'wallet_transaction_page',
    'walletTransactionPage',
    'wallet_transactions_page',
    'walletTransactionsPage',
    'history_page',
    'historyPage',
  ]) {
    final nestedRows = _walletLedgerRows(payload[key], depth + 1);
    if (nestedRows.isNotEmpty || payload[key] is List) return nestedRows;
  }

  for (final key in const ['data', 'result', 'resource']) {
    final nestedRows = _walletLedgerRows(payload[key], depth + 1);
    if (nestedRows.isNotEmpty || payload[key] is List) return nestedRows;
  }

  final single = asMap(
    payload['ledger'] ??
        payload['entry'] ??
        payload['transaction'] ??
        payload['wallet_transaction'] ??
        payload['walletTransaction'] ??
        payload['wallet_ledger'] ??
        payload['walletLedger'],
  );
  if (single.isNotEmpty) return [single];

  if (_looksLikeWalletLedgerRow(payload)) return [payload];

  return const <Map<String, dynamic>>[];
}

bool _looksLikeWalletRow(Map<String, dynamic> payload) {
  for (final key in const [
    'id',
    'wallet_id',
    'walletId',
    'primary_wallet_id',
    'primaryWalletId',
    'balance',
    'available_balance',
    'availableBalance',
    'current_balance',
    'currentBalance',
    'wallet_balance',
    'walletBalance',
  ]) {
    if (payload.containsKey(key)) return true;
  }
  return false;
}

bool _looksLikeWalletLedgerRow(Map<String, dynamic> payload) {
  for (final key in const [
    'id',
    'ledger_id',
    'ledgerId',
    'transaction_id',
    'transactionId',
    'wallet_transaction_id',
    'walletTransactionId',
    'entry_type',
    'entryType',
    'transaction_type',
    'transactionType',
    'reference_type',
    'referenceType',
    'amount',
    'transaction_amount',
    'transactionAmount',
    'balance_after',
    'balanceAfter',
  ]) {
    if (payload.containsKey(key)) return true;
  }
  return false;
}

String _walletCustomerNo(Object? value, [int depth = 0]) {
  final payload = asMap(value);
  final data = asMap(payload['data']);
  final result = asMap(payload['result']);
  final resource = asMap(payload['resource']);
  final candidates = [
    payload['customer_no'],
    payload['customerNo'],
    payload['member_no'],
    payload['memberNo'],
    data['customer_no'],
    data['customerNo'],
    data['member_no'],
    data['memberNo'],
    result['customer_no'],
    result['customerNo'],
    result['member_no'],
    result['memberNo'],
    resource['customer_no'],
    resource['customerNo'],
    resource['member_no'],
    resource['memberNo'],
    asMap(payload['customer'])['customer_no'],
    asMap(payload['customer'])['customerNo'],
    asMap(payload['customer'])['member_no'],
    asMap(payload['customer'])['memberNo'],
    asMap(payload['customer'])['id'],
    asMap(data['customer'])['customer_no'],
    asMap(data['customer'])['customerNo'],
    asMap(data['customer'])['member_no'],
    asMap(data['customer'])['memberNo'],
    asMap(data['customer'])['id'],
    asMap(result['customer'])['customer_no'],
    asMap(result['customer'])['customerNo'],
    asMap(result['customer'])['member_no'],
    asMap(result['customer'])['memberNo'],
    asMap(result['customer'])['id'],
    asMap(resource['customer'])['customer_no'],
    asMap(resource['customer'])['customerNo'],
    asMap(resource['customer'])['member_no'],
    asMap(resource['customer'])['memberNo'],
    asMap(resource['customer'])['id'],
    asMap(payload['user'])['customer_no'],
    asMap(payload['user'])['customerNo'],
    asMap(payload['user'])['member_no'],
    asMap(payload['user'])['memberNo'],
    asMap(payload['user'])['id'],
    asMap(data['user'])['customer_no'],
    asMap(data['user'])['customerNo'],
    asMap(data['user'])['member_no'],
    asMap(data['user'])['memberNo'],
    asMap(data['user'])['id'],
    asMap(result['user'])['customer_no'],
    asMap(result['user'])['customerNo'],
    asMap(result['user'])['member_no'],
    asMap(result['user'])['memberNo'],
    asMap(result['user'])['id'],
    asMap(resource['user'])['customer_no'],
    asMap(resource['user'])['customerNo'],
    asMap(resource['user'])['member_no'],
    asMap(resource['user'])['memberNo'],
    asMap(resource['user'])['id'],
  ];
  for (final candidate in candidates) {
    final text = _walletPayloadText(candidate);
    if (text.isNotEmpty) return text;
  }

  if (depth < 4) {
    for (final key in const ['data', 'result', 'resource']) {
      final text = _walletCustomerNo(payload[key], depth + 1);
      if (text.isNotEmpty) return text;
    }
  }

  return '';
}

String _walletPayloadText(Object? value, [int depth = 0]) {
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
    'customer_no',
    'customerNo',
    'member_no',
    'memberNo',
    'number',
    'label',
    'name',
  ]) {
    if (!map.containsKey(key)) continue;
    final text = _walletPayloadText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }
  return '';
}
