import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../profile/data/profile_settings_models.dart';
import '../data/affiliate_models.dart';
import '../data/affiliate_repository.dart';

class AffiliateScreen extends ConsumerStatefulWidget {
  const AffiliateScreen({
    super.key,
    this.tab = AffiliateTab.overview,
    this.showPayoutSuccess = false,
  });

  final AffiliateTab tab;
  final bool showPayoutSuccess;

  @override
  ConsumerState<AffiliateScreen> createState() => _AffiliateScreenState();
}

class _AffiliateScreenState extends ConsumerState<AffiliateScreen> {
  AffiliateOverview _overview = AffiliateOverview.empty();
  bool _loading = true;
  bool _submitting = false;
  bool _commissionsLoading = false;
  bool _commissionsHasMore = false;
  bool _payoutsLoading = false;
  bool _payoutsHasMore = false;
  String _loadError = '';
  String _commissionsCursor = '';
  String _commissionsError = '';
  String _payoutsCursor = '';
  String _payoutsError = '';
  String _noticeMessage = '';
  bool _noticeSuccess = false;
  List<AffiliateCommission> _commissions = const [];
  List<AffiliatePayout> _payouts = const [];

  final _storeNameController = TextEditingController();
  final _payoutAmountController = TextEditingController();
  String _payoutMethod = 'bank_transfer';

  @override
  void initState() {
    super.initState();
    _payoutAmountController.addListener(_handlePayoutAmountChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _refresh();
    });
  }

  @override
  void didUpdateWidget(covariant AffiliateScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tab != widget.tab) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _refresh();
      });
    }
  }

  @override
  void dispose() {
    _payoutAmountController.removeListener(_handlePayoutAmountChanged);
    _storeNameController.dispose();
    _payoutAmountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeTab = _overview.isAffiliate
        ? widget.tab
        : AffiliateTab.overview;
    final noticeMessage = _noticeMessage.isNotEmpty
        ? _noticeMessage
        : widget.showPayoutSuccess
        ? l10n.affiliatePayoutSuccess
        : '';
    final showAffiliateNavigation =
        !_loading && _loadError.isEmpty && _overview.isAffiliate;

    return AppShell(
      title: _affiliatePageTitle(l10n, activeTab),
      currentPath: affiliatePathForTab(activeTab),
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      bottomNavigation: showAffiliateNavigation
          ? _AffiliateNavigationBar(
              activeTab: activeTab,
              onChanged: (tab) => context.go(affiliatePathForTab(tab)),
            )
          : null,
      compactHeader: true,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: _AffiliateSheet(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (noticeMessage.isNotEmpty) ...[
              _AffiliateInlineNotice(
                message: noticeMessage,
                success: _noticeMessage.isEmpty || _noticeSuccess,
              ),
              const SizedBox(height: 12),
            ],
            if (_loading)
              const _AffiliateLoadingCard()
            else if (_loadError.isNotEmpty)
              _AffiliateErrorCard(message: _loadError, onRetry: _refresh)
            else if (!_overview.isAffiliate)
              _AffiliateRegisterCard(
                controller: _storeNameController,
                payoutPolicy: _overview.payoutPolicy,
                submitting: _submitting,
                onSubmit: _register,
              )
            else
              switch (activeTab) {
                AffiliateTab.overview => _AffiliateOverviewTab(
                  overview: _overview,
                  onCopy: _copyReferralLink,
                ),
                AffiliateTab.withdraw => _AffiliateWithdrawTab(
                  overview: _overview,
                  amountController: _payoutAmountController,
                  payoutMethod: _payoutMethod,
                  submitting: _submitting,
                  canSubmit: _canRequestPayout,
                  onMethodChanged: (value) {
                    setState(() => _payoutMethod = value);
                  },
                  onSubmit: _createPayout,
                ),
                AffiliateTab.commissions => _AffiliateCommissionsTab(
                  commissions: _commissions,
                  loading: _commissionsLoading,
                  error: _commissionsError,
                  hasMore: _commissionsHasMore,
                  onRetry: () => _loadCommissions(reset: true),
                  onLoadMore: () => _loadCommissions(),
                ),
                AffiliateTab.payouts => _AffiliatePayoutsTab(
                  payouts: _payouts,
                  loading: _payoutsLoading,
                  error: _payoutsError,
                  hasMore: _payoutsHasMore,
                  onRetry: () => _loadPayouts(reset: true),
                  onLoadMore: () => _loadPayouts(),
                ),
              },
          ],
        ),
      ),
    );
  }

  void _handlePayoutAmountChanged() {
    if (mounted) setState(() {});
  }

  bool get _canRequestPayout {
    final minimum = _overview.payoutPolicy.minimumPayout;
    final amount = double.tryParse(_payoutAmountController.text.trim()) ?? 0;
    if (_submitting ||
        _overview.stats.availableBalance < minimum ||
        amount < minimum) {
      return false;
    }
    return _payoutMethod != 'bank_transfer' || _overview.bankAccount.isComplete;
  }

  Future<void> _refresh() async {
    setState(() {
      _loading = true;
      _loadError = '';
      _noticeMessage = '';
    });
    try {
      final overview = await ref.read(affiliateRepositoryProvider).overview();
      if (!mounted) return;
      setState(() => _applyOverview(overview));
      if (widget.tab == AffiliateTab.commissions) {
        await _loadCommissions(reset: true);
      } else if (widget.tab == AffiliateTab.payouts) {
        await _loadPayouts(reset: true);
      }
    } catch (error) {
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (!mounted) return;
      setState(
        () => _loadError = customerErrorMessage(
          error,
          context.l10n.affiliateLoadFailed,
        ),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _loadCommissions({bool reset = false}) async {
    if (_commissionsLoading) return;
    if (!reset && !_commissionsHasMore) return;

    setState(() {
      _commissionsLoading = true;
      _commissionsError = '';
      if (reset) {
        _commissionsCursor = '';
        _commissionsHasMore = false;
      }
    });

    try {
      final page = await ref
          .read(affiliateRepositoryProvider)
          .commissions(cursor: reset ? '' : _commissionsCursor);
      if (!mounted) return;
      setState(() {
        _commissions = reset ? page.items : [..._commissions, ...page.items];
        _commissionsCursor = page.nextCursor;
        _commissionsHasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (!mounted) return;
      setState(() {
        _commissionsError = customerErrorMessage(
          error,
          context.l10n.affiliateLoadFailed,
        );
      });
    } finally {
      if (mounted) setState(() => _commissionsLoading = false);
    }
  }

  Future<void> _loadPayouts({bool reset = false}) async {
    if (_payoutsLoading) return;
    if (!reset && !_payoutsHasMore) return;

    setState(() {
      _payoutsLoading = true;
      _payoutsError = '';
      if (reset) {
        _payoutsCursor = '';
        _payoutsHasMore = false;
      }
    });

    try {
      final page = await ref
          .read(affiliateRepositoryProvider)
          .payouts(cursor: reset ? '' : _payoutsCursor);
      if (!mounted) return;
      setState(() {
        _payouts = reset ? page.items : [..._payouts, ...page.items];
        _payoutsCursor = page.nextCursor;
        _payoutsHasMore = page.hasMore;
      });
    } catch (error) {
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (!mounted) return;
      setState(() {
        _payoutsError = customerErrorMessage(
          error,
          context.l10n.affiliateLoadFailed,
        );
      });
    } finally {
      if (mounted) setState(() => _payoutsLoading = false);
    }
  }

  Future<void> _register() async {
    final name = _storeNameController.text.trim();
    if (name.isEmpty) {
      _showNotice(context.l10n.affiliateStoreNameRequired);
      return;
    }
    setState(() {
      _submitting = true;
      _noticeMessage = '';
    });
    try {
      final overview = await ref
          .read(affiliateRepositoryProvider)
          .register(name: name);
      if (!mounted) return;
      setState(() => _applyOverview(overview));
      _showNotice(context.l10n.affiliateRegisterSuccess, success: true);
    } catch (error) {
      if (!mounted) return;
      final fallback = context.l10n.affiliateRegisterFailed;
      if (await _handleOperationalError(error)) return;
      if (!mounted) return;
      _showNotice(customerErrorMessage(error, fallback));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _createPayout() async {
    final amount = double.tryParse(_payoutAmountController.text.trim()) ?? 0;
    final minimum = _overview.payoutPolicy.minimumPayout;
    if (amount < minimum) {
      _showNotice(context.l10n.affiliateWithdrawMinimum(formatBaht(minimum)));
      return;
    }
    if (amount > _overview.stats.availableBalance) {
      _showNotice(context.l10n.affiliateWithdrawExceeds);
      return;
    }
    if (_payoutMethod == 'bank_transfer' && !_overview.bankAccount.isComplete) {
      _showNotice(context.l10n.affiliateBankRequired);
      return;
    }

    setState(() {
      _submitting = true;
      _noticeMessage = '';
    });
    try {
      await ref
          .read(affiliateRepositoryProvider)
          .createPayout(
            amount: amount,
            payoutMethod: _payoutMethod,
            bankAccount: _payoutMethod == 'bank_transfer'
                ? _overview.bankAccount.toJson()
                : null,
          );
      _payoutAmountController.clear();
      await _refresh();
      if (!mounted) return;
      context.go('/affiliate/payouts?created=1');
    } catch (error) {
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (!mounted) return;
      _showNotice(
        customerErrorMessage(error, context.l10n.affiliatePayoutFailed),
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
    _showNotice(context.l10n.affiliateLinkCopied, success: true);
  }

  void _showNotice(String message, {bool success = false}) {
    if (!mounted) return;
    setState(() {
      _noticeMessage = message;
      _noticeSuccess = success;
    });
  }

  Future<bool> _handleOperationalError(Object error) {
    return handleCustomerOperationalError(
      ref: ref,
      context: context,
      error: error,
    );
  }

  void _hydratePayoutDefaults(AffiliateOverview overview) {
    if (overview.bankAccount.isComplete) _payoutMethod = 'bank_transfer';
  }

  void _applyOverview(AffiliateOverview overview) {
    _overview = overview;
    _hydratePayoutDefaults(overview);
    _commissions = overview.commissions;
    _commissionsCursor = '';
    _commissionsHasMore = false;
    _commissionsError = '';
    _payouts = overview.payouts;
    _payoutsCursor = '';
    _payoutsHasMore = false;
    _payoutsError = '';
  }
}

class _AffiliateInlineNotice extends StatelessWidget {
  const _AffiliateInlineNotice({required this.message, this.success = false});

  final String message;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = success ? colorScheme.primary : colorScheme.error;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: success
            ? colorScheme.primary.withValues(alpha: 0.08)
            : colorScheme.errorContainer.withValues(alpha: 0.42),
        border: Border.all(
          color: success
              ? colorScheme.primary.withValues(alpha: 0.18)
              : colorScheme.error.withValues(alpha: 0.24),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              success
                  ? Icons.check_circle_outline_rounded
                  : Icons.error_outline_rounded,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateSheet extends StatelessWidget {
  const _AffiliateSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final viewport = MediaQuery.sizeOf(context);
    final wide = viewport.width >= 768;
    final compact = viewport.width <= 360;

    return ListView(
      padding: EdgeInsets.zero,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: CustomerPageBody(
            maxWidth: wide ? 920 : 420,
            top: 16,
            bottom: wide ? 140 : 132,
            mobileHorizontal: compact ? 12 : 16,
            wideHorizontal: 24,
            minViewportHeight: true,
            child: child,
          ),
        ),
      ],
    );
  }
}

class _AffiliateSurface extends StatelessWidget {
  const _AffiliateSurface({
    required this.child,
    this.padding = const EdgeInsets.all(16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.09),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

class _AffiliateStoreSummary extends StatelessWidget {
  const _AffiliateStoreSummary({required this.overview});

  final AffiliateOverview overview;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storeName = overview.storeName.isEmpty
        ? l10n.affiliateHeroFallbackTitle
        : overview.storeName;
    final colorScheme = Theme.of(context).colorScheme;
    return _AffiliateSurface(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primaryContainer.withValues(alpha: 0.58),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.storefront,
              color: Theme.of(context).colorScheme.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.affiliateStoreSummaryLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  storeName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 17,
                    fontWeight: FontWeight.w900,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.affiliateStoreSummaryDescription,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: _affiliateMutedTextStyle(context),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AffiliateRegisterCard extends StatelessWidget {
  const _AffiliateRegisterCard({
    required this.controller,
    required this.payoutPolicy,
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final AffiliatePayoutPolicy payoutPolicy;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 320),
      child: _AffiliateSurface(
        padding: const EdgeInsets.all(22),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Align(
              child: Container(
                width: 72,
                height: 72,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primaryContainer.withValues(alpha: 0.58),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Icon(
                  Icons.person_add_alt_1,
                  color: Theme.of(context).colorScheme.primary,
                  size: 34,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.affiliateRegisterTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 18,
                fontWeight: FontWeight.w900,
                height: 1.25,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.affiliateRegisterDescription,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            _AffiliateRegisterBenefits(policy: payoutPolicy),
            const SizedBox(height: 20),
            _AffiliateFieldLabel(label: l10n.affiliateRegisterStoreLabel),
            const SizedBox(height: 8),
            TextField(
              controller: controller,
              maxLength: 80,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w800,
              ),
              decoration: _affiliateInputDecoration(
                context,
                hintText: l10n.affiliateRegisterStoreHint,
                radius: 14,
              ),
            ),
            const SizedBox(height: 8),
            CustomerGradientButton.text(
              label: submitting
                  ? context.l10n.commonLoadingData
                  : l10n.affiliateRegisterButton,
              onPressed: submitting ? null : onSubmit,
              fontSize: 14,
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateRegisterBenefits extends StatelessWidget {
  const _AffiliateRegisterBenefits({required this.policy});

  final AffiliatePayoutPolicy policy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final benefits = [
      (Icons.payments_outlined, l10n.affiliateRegisterBenefitCommission),
      (Icons.link_rounded, l10n.affiliateRegisterBenefitReferral),
      (
        Icons.account_balance_wallet_outlined,
        l10n.affiliateRegisterBenefitPayout(
          l10n.formatBaht(policy.minimumPayout),
        ),
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.affiliateRegisterBenefitsTitle,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurface,
            fontSize: 15,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 10),
        for (var index = 0; index < benefits.length; index++) ...[
          _AffiliateRegisterBenefitRow(
            icon: benefits[index].$1,
            label: benefits[index].$2,
          ),
          if (index < benefits.length - 1) const SizedBox(height: 10),
        ],
      ],
    );
  }
}

class _AffiliateRegisterBenefitRow extends StatelessWidget {
  const _AffiliateRegisterBenefitRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer.withValues(alpha: 0.58),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: colorScheme.primary, size: 17),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.4,
              ),
            ),
          ),
        ),
      ],
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

    final colorScheme = Theme.of(context).colorScheme;
    final wide = MediaQuery.sizeOf(context).width >= 768;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: wide ? 4 : 2,
        mainAxisExtent: 104,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return DecoratedBox(
          decoration: BoxDecoration(
            color: colorScheme.surface,
            borderRadius: BorderRadius.circular(14),
            boxShadow: [
              BoxShadow(
                color: colorScheme.primary.withValues(alpha: 0.09),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.$1,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  item.$2,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                    height: 1.12,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.$3,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AffiliateNavigationBar extends StatelessWidget {
  const _AffiliateNavigationBar({
    required this.activeTab,
    required this.onChanged,
  });

  final AffiliateTab activeTab;
  final ValueChanged<AffiliateTab> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tabs = [
      (
        AffiliateTab.overview,
        l10n.affiliateTabLabel('overview'),
        Icons.grid_view,
      ),
      (
        AffiliateTab.withdraw,
        l10n.affiliateTabLabel('withdraw'),
        Icons.account_balance_outlined,
      ),
      (
        AffiliateTab.commissions,
        l10n.affiliateTabLabel('commissions'),
        Icons.payments_outlined,
      ),
      (AffiliateTab.payouts, l10n.affiliateTabLabel('payouts'), Icons.history),
    ];
    return DecoratedBox(
      key: const ValueKey('affiliate-navigation-bar'),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.10),
            blurRadius: 24,
            offset: const Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 76,
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _AffiliateNavigationButton(
                    label: tab.$2,
                    icon: tab.$3,
                    selected: activeTab == tab.$1,
                    onTap: () {
                      if (activeTab != tab.$1) onChanged(tab.$1);
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AffiliateNavigationButton extends StatelessWidget {
  const _AffiliateNavigationButton({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? primary : colorScheme.onSurfaceVariant;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: 76,
            margin: const EdgeInsets.symmetric(horizontal: 3, vertical: 6),
            padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
            decoration: BoxDecoration(
              color: selected
                  ? primary.withValues(alpha: 0.09)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: color,
                    fontSize: 12,
                    fontWeight: selected ? FontWeight.w900 : FontWeight.w700,
                    height: 1,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AffiliateOverviewTab extends StatelessWidget {
  const _AffiliateOverviewTab({required this.overview, required this.onCopy});

  final AffiliateOverview overview;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateStoreSummary(overview: overview),
        const SizedBox(height: 12),
        _AffiliateStatsGrid(stats: overview.stats),
        const SizedBox(height: 12),
        _AffiliateSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _AffiliateSectionHead(
                title: l10n.affiliateReferralTitle,
                subtitle: l10n.affiliateReferralDescription,
                trailing: _AffiliateCodePill(label: overview.referralCode),
              ),
              if (overview.referralUrl.isEmpty)
                _AffiliateEmptyLine(message: l10n.affiliateReferralEmpty)
              else
                _AffiliateReferralContent(
                  link: overview.referralUrl,
                  copyTooltip: l10n.affiliateReferralCopyTooltip,
                  onCopy: onCopy,
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AffiliateReferralContent extends StatelessWidget {
  const _AffiliateReferralContent({
    required this.link,
    required this.copyTooltip,
    required this.onCopy,
  });

  final String link;
  final String copyTooltip;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final qr = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: colorScheme.outlineVariant),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: QrImageView(
              key: const ValueKey('affiliate-referral-qr'),
              data: link,
              version: QrVersions.auto,
              size: 156,
              padding: const EdgeInsets.all(6),
              backgroundColor: Colors.white,
              errorCorrectionLevel: QrErrorCorrectLevel.M,
              semanticsLabel: l10n.affiliateReferralQrTitle,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Text(
          l10n.affiliateReferralQrTitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          l10n.affiliateReferralQrDescription,
          textAlign: TextAlign.center,
          style: _affiliateMutedTextStyle(context),
        ),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final linkBox = _AffiliateLinkBox(
          link: link,
          tooltip: copyTooltip,
          onCopy: onCopy,
        );
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: qr),
              const SizedBox(height: 16),
              linkBox,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 210, child: qr),
            const SizedBox(width: 20),
            Expanded(child: linkBox),
          ],
        );
      },
    );
  }
}

class _AffiliateResponsiveStack extends StatelessWidget {
  const _AffiliateResponsiveStack({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.sizeOf(context).width < 768) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(height: 12),
            children[index],
          ],
        ],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < children.length; index++) ...[
          if (index > 0) const SizedBox(width: 12),
          Expanded(child: children[index]),
        ],
      ],
    );
  }
}

class _AffiliateBankSummary extends StatelessWidget {
  const _AffiliateBankSummary({
    required this.bank,
    required this.onEdit,
    this.withdrawMode = false,
  });

  final RewardBankAccount bank;
  final VoidCallback onEdit;
  final bool withdrawMode;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AffiliateSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AffiliateSectionHead(
            title: l10n.affiliateBankTitle,
            subtitle: withdrawMode
                ? l10n.affiliateWithdrawBankDescription
                : l10n.affiliateBankDescription,
            trailing: _AffiliateTextAction(
              label: l10n.affiliateEdit,
              onPressed: onEdit,
            ),
          ),
          if (bank.isComplete)
            _AffiliateBankLine(bank: bank)
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _AffiliateEmptyLine(message: l10n.affiliateBankEmpty),
                if (withdrawMode) ...[
                  const SizedBox(height: 10),
                  OutlinedButton(
                    style: _affiliateSecondaryPillStyle(context),
                    onPressed: onEdit,
                    child: Text(l10n.affiliateBankSetupAction),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _AffiliateSectionHead extends StatelessWidget {
  const _AffiliateSectionHead({
    required this.title,
    required this.subtitle,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width <= 360;
    final heading = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 13,
            height: 1.45,
          ),
        ),
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: narrow
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                heading,
                if (trailing != null) ...[
                  const SizedBox(height: 12),
                  Align(alignment: Alignment.centerLeft, child: trailing),
                ],
              ],
            )
          : Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(child: heading),
                if (trailing != null) ...[
                  const SizedBox(width: 12),
                  Flexible(flex: 0, child: trailing!),
                ],
              ],
            ),
    );
  }
}

class _AffiliateCodePill extends StatelessWidget {
  const _AffiliateCodePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    if (label.trim().isEmpty) return const SizedBox.shrink();
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width <= 360;
    return Container(
      width: narrow ? double.infinity : null,
      constraints: BoxConstraints(maxWidth: narrow ? double.infinity : 176),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w900,
          height: 1.15,
        ),
      ),
    );
  }
}

class _AffiliateLinkBox extends StatelessWidget {
  const _AffiliateLinkBox({
    required this.link,
    required this.tooltip,
    required this.onCopy,
  });

  final String link;
  final String tooltip;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          children: [
            Expanded(
              child: Text(
                link,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: tooltip,
              child: Semantics(
                button: true,
                label: tooltip,
                child: MouseRegion(
                  cursor: SystemMouseCursors.click,
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: onCopy,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.primary,
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox.square(
                        dimension: 38,
                        child: Icon(
                          Icons.copy,
                          color: colorScheme.onPrimary,
                          size: 18,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateBankLine extends StatelessWidget {
  const _AffiliateBankLine({required this.bank});

  final RewardBankAccount bank;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primaryContainer.withValues(alpha: 0.24),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.16)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              bank.bankName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              bank.accountName.isEmpty ? '-' : bank.accountName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _affiliateMutedTextStyle(context),
            ),
            const SizedBox(height: 2),
            Text(
              bank.maskedNumber,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: _affiliateMutedTextStyle(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateEmptyLine extends StatelessWidget {
  const _AffiliateEmptyLine({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Text(message, style: _affiliateMutedTextStyle(context));
  }
}

class _AffiliateWithdrawTab extends StatelessWidget {
  const _AffiliateWithdrawTab({
    required this.overview,
    required this.amountController,
    required this.payoutMethod,
    required this.submitting,
    required this.canSubmit,
    required this.onMethodChanged,
    required this.onSubmit,
  });

  final AffiliateOverview overview;
  final TextEditingController amountController;
  final String payoutMethod;
  final bool submitting;
  final bool canSubmit;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final bank = overview.bankAccount;
    return _AffiliateResponsiveStack(
      children: [
        _AffiliateBankSummary(
          bank: bank,
          withdrawMode: true,
          onEdit: () =>
              context.go('/profile/reward-bank?redirect=/affiliate/withdraw'),
        ),
        _AffiliateSurface(
          child: Padding(
            padding: EdgeInsets.zero,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _AffiliateSectionHead(
                  title: l10n.affiliateWithdrawTitle,
                  subtitle: l10n.affiliateWithdrawDescription,
                ),
                Text(
                  l10n.affiliateWithdrawMinimum(
                    formatBaht(overview.payoutPolicy.minimumPayout),
                  ),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                _AffiliateFieldLabel(
                  label: l10n.affiliateWithdrawAmountLabel,
                  muted: true,
                ),
                const SizedBox(height: 6),
                TextField(
                  controller: amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                  ),
                  decoration: _affiliateInputDecoration(
                    context,
                    hintText: '0.00',
                    radius: 12,
                  ),
                ),
                const SizedBox(height: 10),
                _AffiliateFieldLabel(
                  label: l10n.affiliateWithdrawMethodLabel,
                  muted: true,
                ),
                const SizedBox(height: 6),
                DropdownButtonFormField<String>(
                  initialValue: payoutMethod,
                  isExpanded: true,
                  decoration: _affiliateInputDecoration(context, radius: 12),
                  items: [
                    DropdownMenuItem(
                      value: 'bank_transfer',
                      child: Text(
                        l10n.affiliateWithdrawBankTransfer,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'wallet_credit',
                      child: Text(
                        l10n.affiliateWithdrawWalletCredit,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onMethodChanged(value);
                  },
                ),
                if (payoutMethod == 'bank_transfer') ...[
                  const SizedBox(height: 10),
                  _AffiliateBankPreview(bank: bank),
                ],
                if (overview.stats.availableBalance <
                    overview.payoutPolicy.minimumPayout) ...[
                  const SizedBox(height: 10),
                  _AffiliateFormAlert(
                    message: l10n.affiliateWithdrawMinimum(
                      formatBaht(overview.payoutPolicy.minimumPayout),
                    ),
                  ),
                ] else if (amountController.text.trim().isNotEmpty &&
                    (double.tryParse(amountController.text.trim()) ?? 0) <
                        overview.payoutPolicy.minimumPayout) ...[
                  const SizedBox(height: 10),
                  _AffiliateFormAlert(
                    message: l10n.affiliateWithdrawMinimum(
                      formatBaht(overview.payoutPolicy.minimumPayout),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                CustomerGradientButton.text(
                  label: submitting
                      ? context.l10n.commonLoadingData
                      : l10n.affiliateWithdrawSubmit,
                  onPressed: canSubmit ? onSubmit : null,
                  fontSize: 14,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AffiliateBankPreview extends StatelessWidget {
  const _AffiliateBankPreview({required this.bank});

  final RewardBankAccount bank;

  @override
  Widget build(BuildContext context) {
    final missing = !bank.isComplete;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: missing
            ? colorScheme.errorContainer.withValues(alpha: 0.28)
            : colorScheme.primaryContainer.withValues(alpha: 0.22),
        border: Border.all(
          color: missing
              ? colorScheme.error.withValues(alpha: 0.24)
              : colorScheme.primary.withValues(alpha: 0.14),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(10),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: colorScheme.surface,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.account_balance_outlined,
                color: colorScheme.primary,
                size: 20,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    missing ? context.l10n.affiliateBankEmpty : bank.bankName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    missing
                        ? context.l10n.affiliateWithdrawBankMissing
                        : '${bank.accountName.isEmpty ? '-' : bank.accountName} • ${bank.maskedNumber}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _affiliateMutedTextStyle(context),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateCommissionsTab extends StatelessWidget {
  const _AffiliateCommissionsTab({
    required this.commissions,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
    required this.onLoadMore,
  });

  final List<AffiliateCommission> commissions;
  final bool loading;
  final String error;
  final bool hasMore;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (commissions.isEmpty && loading) {
      return const _AffiliateLoadingCard();
    }
    if (commissions.isEmpty && error.isNotEmpty) {
      return _AffiliateErrorCard(message: error, onRetry: onRetry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateListSurface(
          title: l10n.affiliateCommissionsTitle,
          subtitle: l10n.affiliateCommissionsDescription,
          trailing: _AffiliateTextAction(
            label: l10n.affiliateRefreshTooltip,
            onPressed: loading ? null : onRetry,
          ),
          children: [
            if (commissions.isEmpty)
              _AffiliateEmptyLine(message: l10n.affiliateCommissionsEmpty)
            else
              for (var index = 0; index < commissions.length; index++)
                _AffiliateHistoryRow(
                  title: commissions[index].orderId.isEmpty
                      ? commissions[index].id
                      : commissions[index].orderId,
                  subtitle:
                      '${l10n.affiliateStatusLabel(commissions[index].status)} • '
                      '${formatLocalizedDateTime(commissions[index].calculatedAt ?? commissions[index].createdAt, localeTag(l10n.locale))}',
                  amount: formatBaht(commissions[index].amount),
                ),
          ],
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _AffiliateInlineError(message: error, onRetry: onRetry),
          ),
        if (hasMore || loading) ...[
          const SizedBox(height: 8),
          Align(
            child: OutlinedButton(
              style: _affiliateSecondaryPillStyle(context),
              onPressed: loading ? null : onLoadMore,
              child: Text(
                loading ? l10n.commonLoadingMore : l10n.commonLoadMore,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AffiliatePayoutsTab extends StatelessWidget {
  const _AffiliatePayoutsTab({
    required this.payouts,
    required this.loading,
    required this.error,
    required this.hasMore,
    required this.onRetry,
    required this.onLoadMore,
  });

  final List<AffiliatePayout> payouts;
  final bool loading;
  final String error;
  final bool hasMore;
  final VoidCallback onRetry;
  final VoidCallback onLoadMore;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    if (payouts.isEmpty && loading) {
      return const _AffiliateLoadingCard();
    }
    if (payouts.isEmpty && error.isNotEmpty) {
      return _AffiliateErrorCard(message: error, onRetry: onRetry);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateListSurface(
          title: l10n.affiliatePayoutsTitle,
          subtitle: l10n.affiliatePayoutsDescription,
          children: [
            if (payouts.isEmpty)
              _AffiliateEmptyLine(message: l10n.affiliatePayoutsEmpty)
            else
              for (var index = 0; index < payouts.length; index++)
                _AffiliateHistoryRow(
                  title: l10n.affiliatePayoutMethodLabel(
                    payouts[index].payoutMethod,
                  ),
                  subtitle:
                      '${l10n.affiliateStatusLabel(payouts[index].status)} • '
                      '${formatLocalizedDateTime(payouts[index].createdAt, localeTag(l10n.locale))}',
                  amount: formatBaht(payouts[index].amount),
                ),
          ],
        ),
        if (error.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: _AffiliateInlineError(message: error, onRetry: onRetry),
          ),
        if (hasMore || loading) ...[
          const SizedBox(height: 8),
          Align(
            child: OutlinedButton(
              style: _affiliateSecondaryPillStyle(context),
              onPressed: loading ? null : onLoadMore,
              child: Text(
                loading ? l10n.commonLoadingMore : l10n.commonLoadMore,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _AffiliateListSurface extends StatelessWidget {
  const _AffiliateListSurface({
    required this.title,
    required this.subtitle,
    required this.children,
    this.trailing,
  });

  final String title;
  final String subtitle;
  final List<Widget> children;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return _AffiliateSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _AffiliateSectionHead(
            title: title,
            subtitle: subtitle,
            trailing: trailing,
          ),
          ...children,
        ],
      ),
    );
  }
}

class _AffiliateHistoryRow extends StatelessWidget {
  const _AffiliateHistoryRow({
    required this.title,
    required this.subtitle,
    required this.amount,
  });

  final String title;
  final String subtitle;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width <= 360;
    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurface,
            fontWeight: FontWeight.w900,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: _affiliateMutedTextStyle(context)),
      ],
    );
    final amountText = Text(
      amount,
      textAlign: narrow ? TextAlign.left : TextAlign.right,
      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w900,
      ),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: narrow
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [details, const SizedBox(height: 10), amountText],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 10),
                  amountText,
                ],
              ),
      ),
    );
  }
}

class _AffiliateInlineError extends StatelessWidget {
  const _AffiliateInlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.32),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.24)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: colorScheme.error),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
              ),
            ),
            OutlinedButton(
              style: _affiliateSecondaryPillStyle(context).copyWith(
                minimumSize: WidgetStateProperty.all(const Size(96, 40)),
                padding: WidgetStateProperty.all(
                  const EdgeInsets.symmetric(horizontal: 14),
                ),
              ),
              onPressed: onRetry,
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateLoadingCard extends StatelessWidget {
  const _AffiliateLoadingCard();

  @override
  Widget build(BuildContext context) {
    return _AffiliateSurface(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 22),
      child: Center(
        child: Text(
          context.l10n.commonLoadingData,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
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
    return _AffiliateSurface(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: Theme.of(context).colorScheme.error),
          const SizedBox(height: 8),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton(
            style: _affiliateSecondaryPillStyle(context),
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

class _AffiliateFieldLabel extends StatelessWidget {
  const _AffiliateFieldLabel({required this.label, this.muted = false});

  final String label;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Text(
      label,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: muted ? colorScheme.onSurfaceVariant : colorScheme.onSurface,
        fontSize: 13,
        fontWeight: FontWeight.w900,
      ),
    );
  }
}

class _AffiliateFormAlert extends StatelessWidget {
  const _AffiliateFormAlert({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.34),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.22)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.error,
            fontSize: 12,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _AffiliateTextAction extends StatelessWidget {
  const _AffiliateTextAction({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minWidth: 40, minHeight: 32),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: enabled
                      ? colorScheme.primary
                      : colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

TextStyle? _affiliateMutedTextStyle(BuildContext context) {
  return Theme.of(context).textTheme.bodySmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontSize: 13,
    fontWeight: FontWeight.w700,
    height: 1.35,
  );
}

ButtonStyle _affiliateSecondaryPillStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(160, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: const StadiumBorder(),
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    textStyle: Theme.of(
      context,
    ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w900),
  );
}

InputDecoration _affiliateInputDecoration(
  BuildContext context, {
  String? hintText,
  double radius = 12,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final borderRadius = BorderRadius.circular(radius);
  return InputDecoration(
    hintText: hintText,
    counterText: '',
    isDense: true,
    filled: true,
    fillColor: colorScheme.surfaceContainerLowest,
    constraints: const BoxConstraints(minHeight: 48),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
    hintStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: colorScheme.onSurfaceVariant,
      fontSize: 15,
      fontWeight: FontWeight.w600,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: colorScheme.primary),
    ),
    disabledBorder: OutlineInputBorder(
      borderRadius: borderRadius,
      borderSide: BorderSide(color: colorScheme.outlineVariant),
    ),
  );
}

enum AffiliateTab { overview, withdraw, commissions, payouts }

String affiliatePathForTab(AffiliateTab tab) {
  return switch (tab) {
    AffiliateTab.overview => '/affiliate',
    AffiliateTab.withdraw => '/affiliate/withdraw',
    AffiliateTab.commissions => '/affiliate/commissions',
    AffiliateTab.payouts => '/affiliate/payouts',
  };
}

String _affiliatePageTitle(CustomerLocalizations l10n, AffiliateTab tab) {
  return switch (tab) {
    AffiliateTab.overview => l10n.affiliateTitle,
    AffiliateTab.withdraw => l10n.affiliateWithdrawTitle,
    AffiliateTab.commissions => l10n.affiliateCommissionsTitle,
    AffiliateTab.payouts => l10n.affiliatePayoutsTitle,
  };
}
