import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
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
    final response = await _api.get<Map<String, dynamic>>('/customer/wallet');
    return unwrapDataList(
      response.data,
    ).map(CustomerWallet.fromJson).toList(growable: false);
  }

  Future<List<WalletLedgerEntry>> ledger({int limit = 12}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/wallet/ledger',
      query: {'limit': limit, 'sort_by': 'created_at', 'sort_dir': 'desc'},
    );
    return unwrapDataList(
      response.data,
    ).map(WalletLedgerEntry.fromJson).toList(growable: false);
  }

  Future<WalletSummary> summary() async {
    final walletList = await wallets();
    var ledgerLoadFailed = false;
    var ledgerEntries = <WalletLedgerEntry>[];
    try {
      ledgerEntries = await ledger();
    } catch (_) {
      ledgerLoadFailed = true;
    }

    return WalletSummary(
      wallets: walletList,
      ledger: ledgerEntries,
      ledgerLoadFailed: ledgerLoadFailed,
    );
  }
}
