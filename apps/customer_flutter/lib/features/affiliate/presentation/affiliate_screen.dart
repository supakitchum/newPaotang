import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/affiliate_models.dart';
import '../data/affiliate_repository.dart';

class AffiliateScreen extends ConsumerStatefulWidget {
  const AffiliateScreen({super.key});

  @override
  ConsumerState<AffiliateScreen> createState() => _AffiliateScreenState();
}

class _AffiliateScreenState extends ConsumerState<AffiliateScreen> {
  AffiliateOverview _overview = AffiliateOverview.empty();
  AffiliateTab _tab = AffiliateTab.overview;
  String _pin = '';
  String _pinError = '';
  bool _pinVerified = false;
  bool _verifyingPin = false;
  bool _loading = false;
  bool _submitting = false;
  String _loadError = '';

  final _storeNameController = TextEditingController();
  final _payoutAmountController = TextEditingController();
  String _payoutMethod = 'bank_transfer';

  @override
  void dispose() {
    _storeNameController.dispose();
    _payoutAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final biometricEnabled = bootstrap.maybeWhen(
      data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
      orElse: () => false,
    );

    if (!_pinVerified) {
      return AppShell(
        title: l10n.affiliateTitle,
        currentPath: '/affiliate',
        sensitive: true,
        actions: [
          IconButton(
            tooltip: l10n.affiliateBackTooltip,
            onPressed: _verifyingPin ? null : () => context.go('/profile'),
            icon: const Icon(Icons.close),
          ),
        ],
        child: _AffiliatePinGate(
          pin: _pin,
          error: _pinError,
          verifying: _verifyingPin,
          onDigit: _appendPinDigit,
          onBackspace: _removePinDigit,
          biometricEnabled: biometricEnabled,
          onBiometric: _verifyWithBiometric,
        ),
      );
    }

    return AppShell(
      title: l10n.affiliateTitle,
      currentPath: '/affiliate',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.affiliateRefreshTooltip,
          onPressed: _loading ? null : _refresh,
          icon: const Icon(Icons.refresh),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            _AffiliateHero(overview: _overview),
            const SizedBox(height: 12),
            if (_loading)
              const _AffiliateLoadingCard()
            else if (_loadError.isNotEmpty)
              _AffiliateErrorCard(message: _loadError, onRetry: _refresh)
            else if (!_overview.isAffiliate)
              _AffiliateRegisterCard(
                controller: _storeNameController,
                submitting: _submitting,
                onSubmit: _register,
              )
            else ...[
              _AffiliateStatsGrid(stats: _overview.stats),
              const SizedBox(height: 12),
              _AffiliateTabBar(
                activeTab: _tab,
                onChanged: (tab) => setState(() => _tab = tab),
              ),
              const SizedBox(height: 12),
              switch (_tab) {
                AffiliateTab.overview => _AffiliateOverviewTab(
                    overview: _overview,
                    onCopy: _copyReferralLink,
                  ),
                AffiliateTab.withdraw => _AffiliateWithdrawTab(
                    overview: _overview,
                    amountController: _payoutAmountController,
                    payoutMethod: _payoutMethod,
                    submitting: _submitting,
                    onMethodChanged: (value) {
                      setState(() => _payoutMethod = value);
                    },
                    onSubmit: _createPayout,
                  ),
                AffiliateTab.commissions => _AffiliateCommissionsTab(
                    commissions: _overview.commissions,
                  ),
                AffiliateTab.payouts => _AffiliatePayoutsTab(
                    payouts: _overview.payouts,
                  ),
              },
            ],
          ],
        ),
      ),
    );
  }

  void _appendPinDigit(String digit) {
    if (_pin.length >= 6 || _verifyingPin) return;
    setState(() {
      _pin += digit;
      _pinError = '';
    });
    if (_pin.length == 6) _verifyPin();
  }

  void _removePinDigit() {
    if (_pin.isEmpty || _verifyingPin) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = '';
    });
  }

  Future<void> _verifyPin() async {
    setState(() {
      _verifyingPin = true;
      _pinError = '';
    });
    try {
      await ref.read(authControllerProvider).verifyPin(_pin);
      if (!mounted) return;
      setState(() {
        _pinVerified = true;
        _pin = '';
      });
      await _refresh();
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _pinError = _pinErrorText(error);
      });
    } finally {
      if (mounted) setState(() => _verifyingPin = false);
    }
  }

  Future<void> _verifyWithBiometric() async {
    if (_verifyingPin) return;
    setState(() {
      _verifyingPin = true;
      _pin = '';
      _pinError = '';
    });
    try {
      final unlocked =
          await ref.read(authControllerProvider).unlockWithBiometric(
                localizedReason: context.l10n.pinBiometricReason,
              );
      if (!mounted) return;
      if (!unlocked) {
        setState(() => _pinError = context.l10n.pinBiometricUnavailable);
        return;
      }
      setState(() => _pinVerified = true);
      await _refresh();
    } catch (_) {
      if (!mounted) return;
      setState(() => _pinError = context.l10n.pinBiometricFailed);
    } finally {
      if (mounted) setState(() => _verifyingPin = false);
    }
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = '';
    });
    try {
      final overview = await ref.read(affiliateRepositoryProvider).overview();
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _hydratePayoutDefaults(overview);
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = context.l10n.affiliateLoadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _register() async {
    final name = _storeNameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliateStoreNameRequired)),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final overview =
          await ref.read(affiliateRepositoryProvider).register(name: name);
      if (!mounted) return;
      setState(() {
        _overview = overview;
        _hydratePayoutDefaults(overview);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliateRegisterSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliateRegisterFailed)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createPayout() async {
    final amount = double.tryParse(_payoutAmountController.text.trim()) ?? 0;
    final minimum = _overview.payoutPolicy.minimumPayout;
    if (amount < minimum) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text(context.l10n.affiliateWithdrawMinimum(formatBaht(minimum))),
        ),
      );
      return;
    }
    if (amount > _overview.stats.availableBalance) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliateWithdrawExceeds)),
      );
      return;
    }
    if (_payoutMethod == 'bank_transfer' && !_overview.bankAccount.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliateBankRequired)),
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(affiliateRepositoryProvider).createPayout(
            amount: amount,
            payoutMethod: _payoutMethod,
            bankAccount: _payoutMethod == 'bank_transfer'
                ? _overview.bankAccount.toJson()
                : null,
          );
      _payoutAmountController.clear();
      await _refresh();
      if (!mounted) return;
      setState(() => _tab = AffiliateTab.payouts);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliatePayoutSuccess)),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.affiliatePayoutFailed)),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _copyReferralLink() async {
    final link = _overview.referralUrl;
    if (link.isEmpty) return;
    await Clipboard.setData(ClipboardData(text: link));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.affiliateLinkCopied)),
    );
  }

  void _hydratePayoutDefaults(AffiliateOverview overview) {
    if (overview.bankAccount.isComplete) _payoutMethod = 'bank_transfer';
  }

  String _pinErrorText(Object error) {
    final value = error.toString();
    final l10n = context.l10n;
    if (value.contains('pin_invalid')) {
      return l10n.affiliatePinInvalid;
    }
    if (value.contains('pin_locked')) {
      return l10n.affiliatePinLocked;
    }
    if (value.contains('pin_setup_required')) {
      return l10n.affiliatePinSetupRequired;
    }
    return l10n.affiliatePinFailed;
  }
}

class _AffiliatePinGate extends StatelessWidget {
  const _AffiliatePinGate({
    required this.pin,
    required this.error,
    required this.verifying,
    required this.onDigit,
    required this.onBackspace,
    required this.biometricEnabled,
    required this.onBiometric,
  });

  final String pin;
  final String error;
  final bool verifying;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool biometricEnabled;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.share,
          size: 56,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 14),
        Text(
          l10n.affiliatePinTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.affiliatePinSubtitle,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          '${'●' * pin.length}${'○' * (6 - pin.length)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (verifying) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        if (biometricEnabled) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: verifying ? null : onBiometric,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(l10n.pinUseBiometric),
          ),
        ],
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final key in keys)
              if (key.isEmpty)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: FilledButton.tonal(
                    onPressed: verifying
                        ? null
                        : key == 'back'
                            ? onBackspace
                            : () => onDigit(key),
                    child: key == 'back'
                        ? const Icon(Icons.backspace_outlined)
                        : Text(key),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _AffiliateHero extends StatelessWidget {
  const _AffiliateHero({required this.overview});

  final AffiliateOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = overview.isAffiliate && overview.storeName.isNotEmpty
        ? overview.storeName
        : l10n.affiliateHeroFallbackTitle;
    return Card(
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              child: const Icon(Icons.share),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.affiliateHeroSubtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateRegisterCard extends StatelessWidget {
  const _AffiliateRegisterCard({
    required this.controller,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.affiliateRegisterTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 8),
            Text(l10n.affiliateRegisterDescription),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              maxLength: 80,
              decoration: InputDecoration(
                labelText: l10n.affiliateRegisterStoreLabel,
                hintText: l10n.affiliateRegisterStoreHint,
                prefixIcon: const Icon(Icons.storefront),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.person_add_alt_1),
              label: Text(l10n.affiliateRegisterButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateStatsGrid extends StatelessWidget {
  const _AffiliateStatsGrid({required this.stats});

  final AffiliateStats stats;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final items = [
      (
        l10n.affiliateStatTitle('available'),
        formatBaht(stats.availableBalance),
        l10n.affiliateStatSubtitle('available'),
      ),
      (
        l10n.affiliateStatTitle('approved'),
        formatBaht(stats.approvedCommission),
        l10n.affiliateStatSubtitle('approved'),
      ),
      (
        l10n.affiliateStatTitle('pending'),
        formatBaht(stats.pendingCommission),
        l10n.affiliateStatSubtitle('pending'),
      ),
      (
        l10n.affiliateStatTitle('converted'),
        stats.convertedCount.toString(),
        l10n.affiliateStatSubtitle('converted'),
      ),
      (
        l10n.affiliateStatTitle('visitors'),
        stats.visitorCount.toString(),
        l10n.affiliateStatSubtitle('visitors'),
      ),
      (
        l10n.affiliateStatTitle('registered'),
        stats.registeredCount.toString(),
        l10n.affiliateStatSubtitle('registered'),
      ),
    ];

    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width >= 560 ? 3 : 2,
      childAspectRatio: 1.55,
      crossAxisSpacing: 8,
      mainAxisSpacing: 8,
      children: [
        for (final item in items)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(item.$1),
                  const SizedBox(height: 6),
                  Text(
                    item.$2,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  Text(item.$3),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _AffiliateTabBar extends StatelessWidget {
  const _AffiliateTabBar({
    required this.activeTab,
    required this.onChanged,
  });

  final AffiliateTab activeTab;
  final ValueChanged<AffiliateTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SegmentedButton<AffiliateTab>(
      selected: {activeTab},
      onSelectionChanged: (selected) => onChanged(selected.first),
      segments: [
        ButtonSegment(
          value: AffiliateTab.overview,
          label: Text(l10n.affiliateTabLabel('overview')),
          icon: const Icon(Icons.grid_view),
        ),
        ButtonSegment(
          value: AffiliateTab.withdraw,
          label: Text(l10n.affiliateTabLabel('withdraw')),
          icon: const Icon(Icons.account_balance),
        ),
        ButtonSegment(
          value: AffiliateTab.commissions,
          label: Text(l10n.affiliateTabLabel('commissions')),
          icon: const Icon(Icons.payments),
        ),
        ButtonSegment(
          value: AffiliateTab.payouts,
          label: Text(l10n.affiliateTabLabel('payouts')),
          icon: const Icon(Icons.history),
        ),
      ],
    );
  }
}

class _AffiliateOverviewTab extends StatelessWidget {
  const _AffiliateOverviewTab({
    required this.overview,
    required this.onCopy,
  });

  final AffiliateOverview overview;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bank = overview.bankAccount;
    return Column(
      children: [
        Card(
          child: ListTile(
            title: Text(
              l10n.affiliateReferralTitle,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: Text(
              overview.referralUrl.isEmpty
                  ? l10n.affiliateReferralEmpty
                  : overview.referralUrl,
            ),
            trailing: IconButton(
              tooltip: l10n.affiliateReferralCopyTooltip,
              onPressed: overview.referralUrl.isEmpty ? null : onCopy,
              icon: const Icon(Icons.copy),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.account_balance)),
            title: Text(
              l10n.affiliateBankTitle,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            subtitle: bank.isComplete
                ? Text(
                    '${bank.bankName}\n${bank.accountName} • ${bank.maskedNumber}',
                  )
                : Text(l10n.affiliateBankEmpty),
            trailing: TextButton(
              onPressed: () =>
                  context.go('/profile/reward-bank?redirect=/affiliate'),
              child: Text(l10n.affiliateEdit),
            ),
          ),
        ),
      ],
    );
  }
}

class _AffiliateWithdrawTab extends StatelessWidget {
  const _AffiliateWithdrawTab({
    required this.overview,
    required this.amountController,
    required this.payoutMethod,
    required this.submitting,
    required this.onMethodChanged,
    required this.onSubmit,
  });

  final AffiliateOverview overview;
  final TextEditingController amountController;
  final String payoutMethod;
  final bool submitting;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bank = overview.bankAccount;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.affiliateWithdrawTitle,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.affiliateWithdrawMinimum(
                formatBaht(overview.payoutPolicy.minimumPayout),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: amountController,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: l10n.affiliateWithdrawAmountLabel,
                prefixIcon: const Icon(Icons.payments_outlined),
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: payoutMethod,
              decoration: InputDecoration(
                labelText: l10n.affiliateWithdrawMethodLabel,
              ),
              items: [
                DropdownMenuItem(
                  value: 'bank_transfer',
                  child: Text(l10n.affiliateWithdrawBankTransfer),
                ),
                DropdownMenuItem(
                  value: 'wallet_credit',
                  child: Text(l10n.affiliateWithdrawWalletCredit),
                ),
              ],
              onChanged: (value) {
                if (value != null) onMethodChanged(value);
              },
            ),
            const SizedBox(height: 12),
            if (payoutMethod == 'bank_transfer')
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                ),
                child: bank.isComplete
                    ? Text(
                        '${bank.bankName}\n${bank.accountName} • ${bank.maskedNumber}',
                      )
                    : Text(l10n.affiliateWithdrawBankMissing),
              ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: submitting ? null : onSubmit,
              icon: submitting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              label: Text(l10n.affiliateWithdrawSubmit),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateCommissionsTab extends StatelessWidget {
  const _AffiliateCommissionsTab({required this.commissions});

  final List<AffiliateCommission> commissions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (commissions.isEmpty) {
      return _AffiliateEmptyCard(message: l10n.affiliateCommissionsEmpty);
    }
    return Column(
      children: [
        for (final row in commissions)
          Card(
            child: ListTile(
              title: Text(row.orderId.isEmpty ? row.id : row.orderId),
              subtitle: Text(
                '${l10n.affiliateStatusLabel(row.status)} • '
                '${formatLocalizedDateTime(row.calculatedAt ?? row.createdAt, localeTag(l10n.locale))}',
              ),
              trailing: Text(
                formatBaht(row.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );
  }
}

class _AffiliatePayoutsTab extends StatelessWidget {
  const _AffiliatePayoutsTab({required this.payouts});

  final List<AffiliatePayout> payouts;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (payouts.isEmpty) {
      return _AffiliateEmptyCard(message: l10n.affiliatePayoutsEmpty);
    }
    return Column(
      children: [
        for (final row in payouts)
          Card(
            child: ListTile(
              title: Text(l10n.affiliatePayoutMethodLabel(row.payoutMethod)),
              subtitle: Text(
                '${l10n.affiliateStatusLabel(row.status)} • '
                '${formatLocalizedDateTime(row.createdAt, localeTag(l10n.locale))}',
              ),
              trailing: Text(
                formatBaht(row.amount),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ),
      ],
    );
  }
}

class _AffiliateLoadingCard extends StatelessWidget {
  const _AffiliateLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AffiliateErrorCard extends StatelessWidget {
  const _AffiliateErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateEmptyCard extends StatelessWidget {
  const _AffiliateEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(child: Text(message)),
      ),
    );
  }
}

enum AffiliateTab { overview, withdraw, commissions, payouts }
