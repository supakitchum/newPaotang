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
import 'affiliate_referral_share_service.dart';

class AffiliateScreen extends ConsumerStatefulWidget {
  const AffiliateScreen({
    super.key,
    this.tab = AffiliateTab.overview,
    this.showPayoutSuccess = false,
    this.showPayoutHistory = false,
  });

  final AffiliateTab tab;
  final bool showPayoutSuccess;
  final bool showPayoutHistory;

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
                  submitting: _submitting,
                  onRequestStoreName: _requestStoreName,
                ),
                AffiliateTab.campaigns => _AffiliateRankingsTab(
                  campaigns: _overview.campaigns,
                  currentTier: _overview.tier,
                ),
                AffiliateTab.referral => _AffiliateReferralTab(
                  overview: _overview,
                  onCopy: _copyReferralLink,
                  onShare: _shareReferralLink,
                ),
                AffiliateTab.withdraw => _AffiliateWithdrawHistoryTab(
                  overview: _overview,
                  amountController: _payoutAmountController,
                  payoutMethod: _payoutMethod,
                  submitting: _submitting,
                  canSubmit: _canRequestPayout,
                  payouts: _payouts,
                  payoutsLoading: _payoutsLoading,
                  payoutsError: _payoutsError,
                  payoutsHasMore: _payoutsHasMore,
                  initialHistory: widget.showPayoutHistory,
                  onMethodChanged: (value) {
                    setState(() => _payoutMethod = value);
                  },
                  onSubmit: _createPayout,
                  onPayoutsRetry: () => _loadPayouts(reset: true),
                  onPayoutsLoadMore: () => _loadPayouts(),
                ),
                AffiliateTab.commissions => _AffiliateCommissionsTab(
                  commissions: _commissions,
                  loading: _commissionsLoading,
                  error: _commissionsError,
                  hasMore: _commissionsHasMore,
                  onRetry: () => _loadCommissions(reset: true),
                  onLoadMore: () => _loadCommissions(),
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
      } else if (widget.tab == AffiliateTab.withdraw) {
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

  Future<void> _requestStoreName() async {
    if (_submitting || !_overview.storeNameState.canRequestChange) return;
    final controller = TextEditingController(
      text: _overview.storeNameState.pendingName.isNotEmpty
          ? _overview.storeNameState.pendingName
          : _overview.storeName,
    );
    final name = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          20,
          20,
          MediaQuery.viewInsetsOf(sheetContext).bottom + 20,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              context.l10n.affiliateStoreNameChangeTitle,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              autofocus: true,
              textInputAction: TextInputAction.done,
              decoration: _affiliateInputDecoration(
                context,
                hintText: context.l10n.affiliateRegisterStoreHint,
              ),
              onSubmitted: (value) {
                final trimmed = value.trim();
                if (trimmed.isNotEmpty) Navigator.of(sheetContext).pop(trimmed);
              },
            ),
            const SizedBox(height: 18),
            CustomerGradientButton.text(
              label: context.l10n.affiliateStoreNameChangeSubmit,
              onPressed: () {
                final trimmed = controller.text.trim();
                if (trimmed.isNotEmpty) Navigator.of(sheetContext).pop(trimmed);
              },
            ),
          ],
        ),
      ),
    );
    controller.dispose();
    if (!mounted || name == null || name.trim().isEmpty) return;

    setState(() => _submitting = true);
    try {
      await ref
          .read(affiliateRepositoryProvider)
          .requestStoreName(name: name.trim());
      await _refresh();
      if (mounted) {
        _showNotice(
          context.l10n.affiliateStoreNameChangeSuccess,
          success: true,
        );
      }
    } catch (error) {
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (mounted) {
        _showNotice(
          customerErrorMessage(error, context.l10n.affiliateRegisterFailed),
        );
      }
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
      context.go('/affiliate/withdraw?history=1&created=1');
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

  Future<void> _shareReferralLink(BuildContext shareContext) async {
    final link = _overview.referralUrl;
    if (link.isEmpty) return;
    final l10n = context.l10n;
    try {
      await ref
          .read(affiliateReferralShareServiceProvider)
          .share(
            text: '${l10n.affiliateReferralDescription}\n$link',
            subject: l10n.affiliateReferralTitle,
            sharePositionOrigin: _affiliateSharePositionOrigin(shareContext),
          );
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: link));
      if (!mounted) return;
      _showNotice(l10n.affiliateLinkCopied, success: true);
    }
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

class _AffiliateIdentityPanel extends StatelessWidget {
  const _AffiliateIdentityPanel({
    required this.overview,
    required this.submitting,
    required this.onRequestStoreName,
  });

  final AffiliateOverview overview;
  final bool submitting;
  final VoidCallback onRequestStoreName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final storeName = overview.storeName.isEmpty
        ? l10n.affiliateHeroFallbackTitle
        : overview.storeName;
    final colorScheme = Theme.of(context).colorScheme;
    final storeState = overview.storeNameState;
    final statusLabel = switch (storeState.status) {
      'approved' => l10n.affiliateStoreNameApproved,
      'rejected' => l10n.affiliateStoreNameRejected,
      _ => l10n.affiliateStoreNamePending,
    };
    final statusColor = switch (storeState.status) {
      'approved' => colorScheme.primary,
      'rejected' => colorScheme.error,
      _ => colorScheme.tertiary,
    };
    final tier = overview.tier;
    final tierName = tier.name.isEmpty ? 'Bronze' : tier.name;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateMemberCard(
          storeName: storeName,
          memberCode: overview.referralCode,
          tier: tier,
          tierName: tierName,
          statusLabel: statusLabel,
          statusIcon: storeState.status == 'approved'
              ? Icons.verified_rounded
              : storeState.status == 'rejected'
              ? Icons.error_outline_rounded
              : Icons.schedule_rounded,
        ),
        if (storeState.canRequestChange || storeState.adminNote.isNotEmpty) ...[
          const SizedBox(height: 8),
          _AffiliateMemberActionLine(
            note: storeState.adminNote,
            noteColor: statusColor,
            actionLabel: storeState.canRequestChange
                ? l10n.affiliateStoreNameChangeAction
                : '',
            submitting: submitting,
            onAction: onRequestStoreName,
          ),
        ],
      ],
    );
  }
}

class _AffiliateMemberCard extends StatelessWidget {
  const _AffiliateMemberCard({
    required this.storeName,
    required this.memberCode,
    required this.tier,
    required this.tierName,
    required this.statusLabel,
    required this.statusIcon,
  });

  final String storeName;
  final String memberCode;
  final AffiliateTier tier;
  final String tierName;
  final String statusLabel;
  final IconData statusIcon;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cardColors = _affiliateTierCardGradient(context, tier.code);
    return Container(
      key: const ValueKey('affiliate-member-card'),
      constraints: const BoxConstraints(minHeight: 218),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: cardColors,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
        boxShadow: [
          BoxShadow(
            color: cardColors.first.withValues(alpha: 0.24),
            blurRadius: 22,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            const Positioned.fill(child: _AffiliateMemberCardPattern()),
            Padding(
              padding: const EdgeInsets.fromLTRB(17, 15, 15, 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          l10n.affiliateMemberLabel.toUpperCase(),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(
                                color: Colors.white.withValues(alpha: 0.82),
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0,
                              ),
                        ),
                      ),
                      Text(
                        memberCode,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.72),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    height: 112,
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                storeName,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: Colors.white,
                                      fontSize: 20,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 5),
                              Text(
                                l10n.affiliateMemberTier(tierName),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: Colors.white.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontSize: 15,
                                      fontWeight: FontWeight.w800,
                                    ),
                              ),
                              const SizedBox(height: 8),
                              _AffiliateMemberStatus(
                                label: statusLabel,
                                icon: statusIcon,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        _AffiliateTierBadgeImage(code: tier.code, size: 108),
                      ],
                    ),
                  ),
                  const SizedBox(height: 9),
                  Container(
                    padding: const EdgeInsets.only(top: 10),
                    decoration: BoxDecoration(
                      border: Border(
                        top: BorderSide(
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: _AffiliateMemberMetric(
                            label: l10n.affiliateMemberCommissionLabel,
                            value: l10n.formatBaht(tier.commissionPerTicket),
                          ),
                        ),
                        Container(
                          width: 1,
                          height: 30,
                          color: Colors.white.withValues(alpha: 0.18),
                        ),
                        Expanded(
                          child: _AffiliateMemberMetric(
                            label: l10n.affiliateMemberMinimumPayoutLabel,
                            value: l10n.formatBaht(tier.minimumPayout),
                            alignEnd: true,
                          ),
                        ),
                      ],
                    ),
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

class _AffiliateMemberCardPattern extends StatelessWidget {
  const _AffiliateMemberCardPattern();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(painter: _AffiliateMemberCardPatternPainter());
  }
}

class _AffiliateMemberCardPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.055)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 18;
    for (
      var offset = -size.height.toDouble();
      offset < size.width + size.height;
      offset += 64
    ) {
      canvas.drawLine(
        Offset(offset, size.height),
        Offset(offset + size.height, 0),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AffiliateTierBadgeImage extends StatelessWidget {
  const _AffiliateTierBadgeImage({required this.code, required this.size});

  final String code;
  final double size;

  @override
  Widget build(BuildContext context) {
    final normalized = _affiliateTierAssetCode(code);
    return SizedBox.square(
      dimension: size,
      child: Image.asset(
        'assets/images/affiliate/tiers/$normalized.png',
        key: ValueKey('affiliate-tier-badge-$normalized'),
        fit: BoxFit.contain,
        filterQuality: FilterQuality.high,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.workspace_premium,
          color: Colors.white,
          size: size * 0.62,
        ),
      ),
    );
  }
}

class _AffiliateMemberStatus extends StatelessWidget {
  const _AffiliateMemberStatus({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: Colors.white, size: 13),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateMemberMetric extends StatelessWidget {
  const _AffiliateMemberMetric({
    required this.label,
    required this.value,
    this.alignEnd = false,
  });

  final String label;
  final String value;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: alignEnd
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: Colors.white,
            fontSize: 14,
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _AffiliateMemberActionLine extends StatelessWidget {
  const _AffiliateMemberActionLine({
    required this.note,
    required this.noteColor,
    required this.actionLabel,
    required this.submitting,
    required this.onAction,
  });

  final String note;
  final Color noteColor;
  final String actionLabel;
  final bool submitting;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        if (note.isNotEmpty)
          Expanded(
            child: Text(
              note,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: noteColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          )
        else
          const Spacer(),
        if (actionLabel.isNotEmpty)
          TextButton.icon(
            onPressed: submitting ? null : onAction,
            icon: const Icon(Icons.edit_outlined, size: 17),
            label: Text(actionLabel),
          ),
      ],
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
    return _AffiliateSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.affiliatePerformanceTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth >= 720
                  ? 6
                  : constraints.maxWidth < 330
                  ? 2
                  : 3;
              const spacing = 8.0;
              final width =
                  (constraints.maxWidth - (spacing * (columns - 1))) / columns;
              return Wrap(
                spacing: spacing,
                runSpacing: spacing,
                children: [
                  for (final item in items)
                    SizedBox(
                      width: width,
                      height: 86,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: colorScheme.primary.withValues(alpha: 0.045),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 9,
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                item.$1,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                    ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.$2,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium
                                    ?.copyWith(
                                      color: colorScheme.primary,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w900,
                                      height: 1.15,
                                    ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                item.$3,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.labelSmall
                                    ?.copyWith(
                                      color: colorScheme.onSurfaceVariant,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
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
        AffiliateTab.campaigns,
        l10n.affiliateTabLabel('rankings'),
        Icons.leaderboard_outlined,
      ),
      (
        AffiliateTab.referral,
        l10n.affiliateTabLabel('referral'),
        Icons.link_rounded,
      ),
      (
        AffiliateTab.commissions,
        l10n.affiliateTabLabel('commissions'),
        Icons.payments_outlined,
      ),
      (
        AffiliateTab.withdraw,
        l10n.affiliateTabLabel('withdraw'),
        Icons.account_balance_outlined,
      ),
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
      child: MediaQuery.removePadding(
        context: context,
        removeBottom: true,
        child: SizedBox(
          height: 82,
          child: Row(
            children: [
              for (final tab in tabs)
                Expanded(
                  child: _AffiliateNavigationButton(
                    label: tab.$2,
                    icon: tab.$3,
                    selected: activeTab == tab.$1,
                    prominent: tab.$1 == AffiliateTab.referral,
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
    this.prominent = false,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final bool prominent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final colorScheme = Theme.of(context).colorScheme;
    final color = selected ? primary : colorScheme.onSurfaceVariant;
    if (prominent) {
      final accent =
          Color.lerp(primary, colorScheme.secondary, 0.32) ?? primary;
      return Semantics(
        button: true,
        selected: selected,
        label: label,
        child: Transform.translate(
          offset: const Offset(0, -15),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(32),
              splashFactory: NoSplash.splashFactory,
              overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              child: SizedBox(
                height: 92,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    AnimatedContainer(
                      key: const ValueKey(
                        'affiliate-referral-navigation-circle',
                      ),
                      duration: const Duration(milliseconds: 160),
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [primary, accent],
                        ),
                        border: Border.all(
                          color: colorScheme.surface,
                          width: 4,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: primary.withValues(
                              alpha: selected ? 0.32 : 0.22,
                            ),
                            blurRadius: 18,
                            offset: const Offset(0, 7),
                          ),
                        ],
                      ),
                      child: Icon(icon, color: colorScheme.onPrimary, size: 26),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: primary,
                        fontSize: 11,
                        fontWeight: selected
                            ? FontWeight.w900
                            : FontWeight.w800,
                        height: 1,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
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
            height: 82,
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
  const _AffiliateOverviewTab({
    required this.overview,
    required this.submitting,
    required this.onRequestStoreName,
  });

  final AffiliateOverview overview;
  final bool submitting;
  final VoidCallback onRequestStoreName;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateIdentityPanel(
          overview: overview,
          submitting: submitting,
          onRequestStoreName: onRequestStoreName,
        ),
        const SizedBox(height: 12),
        _AffiliateStatsGrid(stats: overview.stats),
      ],
    );
  }
}

class _AffiliateRankingsTab extends StatelessWidget {
  const _AffiliateRankingsTab({
    required this.campaigns,
    required this.currentTier,
  });

  final List<AffiliateTierCampaign> campaigns;
  final AffiliateTier currentTier;

  @override
  Widget build(BuildContext context) {
    final campaign = _affiliateRankingCampaign(campaigns);
    if (campaign == null) {
      return _AffiliateSurface(
        child: _AffiliateRankingEmptyState(
          message: context.l10n.affiliateRankingsEmpty,
        ),
      );
    }
    final entries = _affiliateAllLeaderboardRows(campaign);
    final groups = _affiliateLeaderboardTierGroups(campaign, entries);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateRankingCampaignSummary(
          campaign: campaign,
          currentTier: currentTier,
        ),
        const SizedBox(height: 12),
        if (entries.isEmpty)
          _AffiliateSurface(
            child: _AffiliateRankingEmptyState(
              message: context.l10n.affiliateRankingsNoScores,
            ),
          )
        else ...[
          _AffiliateRankingPodium(entries: entries.take(3).toList()),
          const SizedBox(height: 18),
          for (var index = 0; index < groups.length; index++) ...[
            if (index > 0) const SizedBox(height: 18),
            _AffiliateTierRankingSection(group: groups[index]),
          ],
        ],
      ],
    );
  }
}

class _AffiliateRankingCampaignSummary extends StatelessWidget {
  const _AffiliateRankingCampaignSummary({
    required this.campaign,
    required this.currentTier,
  });

  final AffiliateTierCampaign campaign;
  final AffiliateTier currentTier;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final statusColor = _affiliateCampaignStatusColor(context, campaign.status);
    final period = _affiliateCampaignPeriod(context, campaign);
    final progress = campaign.progress;
    return _AffiliateSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(13),
                ),
                child: Icon(
                  Icons.emoji_events_rounded,
                  color: statusColor,
                  size: 25,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      campaign.status == 'active'
                          ? l10n.affiliateRankingsActiveCampaign
                          : l10n.affiliateRankingsLatestResult,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: statusColor,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      campaign.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 11),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _AffiliateCompactBadge(
                label: campaign.isFixedThreshold
                    ? l10n.affiliateCampaignTypeFixed
                    : l10n.affiliateCampaignTypeRanking,
                color: colorScheme.onSurfaceVariant,
              ),
              _AffiliateCompactBadge(
                label: l10n.affiliateCampaignStatus(campaign.status),
                color: statusColor,
              ),
              _AffiliateCompactBadge(
                label: l10n.affiliateCampaignCurrentTier(currentTier.name),
                color: _affiliateTierColor(context, currentTier.code),
              ),
            ],
          ),
          if (period.isNotEmpty) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(
                  Icons.calendar_today_outlined,
                  size: 15,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(period, style: _affiliateMutedTextStyle(context)),
                ),
              ],
            ),
          ],
          if (progress != null) ...[
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _AffiliateCampaignMetric(
                    label: l10n.affiliateCampaignTablePoints,
                    value: '${progress.ticketCount}',
                  ),
                ),
                if (progress.rank > 0)
                  Expanded(
                    child: _AffiliateCampaignMetric(
                      label: l10n.affiliateCampaignCurrentRankLabel,
                      value: '#${progress.rank}',
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _AffiliateRankingPodium extends StatelessWidget {
  const _AffiliateRankingPodium({required this.entries});

  final List<AffiliateTierLeaderboardEntry> entries;

  @override
  Widget build(BuildContext context) {
    AffiliateTierLeaderboardEntry? entryAt(int rank) {
      for (final entry in entries) {
        if (entry.rank == rank) return entry;
      }
      return null;
    }

    return _AffiliateSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            context.l10n.affiliateRankingsPodiumTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 190,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: _AffiliatePodiumPlace(rank: 2, entry: entryAt(2)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _AffiliatePodiumPlace(rank: 1, entry: entryAt(1)),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: _AffiliatePodiumPlace(rank: 3, entry: entryAt(3)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AffiliatePodiumPlace extends StatelessWidget {
  const _AffiliatePodiumPlace({required this.rank, required this.entry});

  final int rank;
  final AffiliateTierLeaderboardEntry? entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = switch (rank) {
      1 => const Color(0xFFC68B00),
      2 => const Color(0xFF667085),
      _ => const Color(0xFFA86132),
    };
    final pedestalHeight = switch (rank) {
      1 => 80.0,
      2 => 61.0,
      _ => 48.0,
    };
    final name = entry == null
        ? '-'
        : entry!.affiliateName.isNotEmpty
        ? entry!.affiliateName
        : entry!.affiliateCode;
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Container(
          width: rank == 1 ? 42 : 36,
          height: rank == 1 ? 42 : 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.13),
            shape: BoxShape.circle,
            border: Border.all(color: color.withValues(alpha: 0.32)),
          ),
          child: Icon(Icons.emoji_events_rounded, color: color, size: 20),
        ),
        const SizedBox(height: 6),
        SizedBox(
          height: 38,
          child: Text(
            name,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: colorScheme.onSurface,
              fontWeight: FontWeight.w900,
              height: 1.15,
            ),
          ),
        ),
        Text(
          context.l10n.affiliateRankingsPoints(entry?.ticketCount ?? 0),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        Container(
          key: ValueKey('affiliate-ranking-podium-$rank'),
          height: pedestalHeight,
          width: double.infinity,
          alignment: Alignment.topCenter,
          padding: const EdgeInsets.only(top: 10),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(10)),
            border: Border.all(color: color.withValues(alpha: 0.22)),
          ),
          child: Text(
            '$rank',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: color,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ],
    );
  }
}

class _AffiliateTierRankingSection extends StatelessWidget {
  const _AffiliateTierRankingSection({required this.group});

  final _AffiliateLeaderboardTierGroup group;

  @override
  Widget build(BuildContext context) {
    final tier = group.tier;
    final color = tier == null
        ? Theme.of(context).colorScheme.onSurfaceVariant
        : _affiliateTierColor(context, tier.code);
    final label = tier == null
        ? context.l10n.affiliateRankingsUnqualified
        : context.l10n.affiliateRankingsTierGroup(tier.name);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (tier != null) ...[
              _AffiliateTierBadgeImage(code: tier.code, size: 32),
              const SizedBox(width: 7),
            ],
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            _AffiliateCountBadge(count: group.entries.length),
          ],
        ),
        const SizedBox(height: 8),
        _AffiliateLeaderboardTable(
          entries: group.entries,
          scoreLabel: context.l10n.affiliateCampaignTablePoints,
        ),
      ],
    );
  }
}

class _AffiliateRankingEmptyState extends StatelessWidget {
  const _AffiliateRankingEmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: colorScheme.primary.withValues(alpha: 0.08),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.leaderboard_outlined, color: colorScheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(message, style: _affiliateMutedTextStyle(context)),
        ),
      ],
    );
  }
}

class _AffiliateCountBadge extends StatelessWidget {
  const _AffiliateCountBadge({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      constraints: const BoxConstraints(minWidth: 28),
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        '$count',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: colorScheme.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _AffiliateCompactBadge extends StatelessWidget {
  const _AffiliateCompactBadge({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: color,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
    );
  }
}

class _AffiliateCampaignMetric extends StatelessWidget {
  const _AffiliateCampaignMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: colorScheme.onSurface,
            fontSize: 18,
            fontWeight: FontWeight.w900,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _AffiliateLeaderboardTable extends StatelessWidget {
  const _AffiliateLeaderboardTable({required this.entries, this.scoreLabel});

  final List<AffiliateTierLeaderboardEntry> entries;
  final String? scoreLabel;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('affiliate-campaign-leaderboard-table'),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border.all(color: colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(10),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Column(
          children: [
            Container(
              color: colorScheme.surfaceContainerHighest.withValues(
                alpha: 0.72,
              ),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 44,
                    child: Text(
                      l10n.affiliateCampaignTableRank,
                      style: _affiliateLeaderboardHeaderStyle(context),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l10n.affiliateCampaignTableMember,
                      style: _affiliateLeaderboardHeaderStyle(context),
                    ),
                  ),
                  Text(
                    scoreLabel ?? l10n.affiliateCampaignTableTickets,
                    style: _affiliateLeaderboardHeaderStyle(context),
                  ),
                ],
              ),
            ),
            for (var index = 0; index < entries.length; index++) ...[
              if (index > 0)
                Divider(height: 1, color: colorScheme.outlineVariant),
              _AffiliateLeaderboardRow(entry: entries[index]),
            ],
          ],
        ),
      ),
    );
  }
}

class _AffiliateLeaderboardRow extends StatelessWidget {
  const _AffiliateLeaderboardRow({required this.entry});

  final AffiliateTierLeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      color: entry.isCurrentAffiliate
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surface,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      child: Row(
        children: [
          SizedBox(
            width: 44,
            child: Align(
              alignment: Alignment.centerLeft,
              child: _AffiliateRankMark(rank: entry.rank),
            ),
          ),
          Expanded(
            child: Text(
              entry.isCurrentAffiliate
                  ? context.l10n.affiliateCampaignCurrentMember(
                      entry.affiliateName.isEmpty
                          ? entry.affiliateCode
                          : entry.affiliateName,
                    )
                  : entry.affiliateName.isEmpty
                  ? entry.affiliateCode
                  : entry.affiliateName,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: entry.isCurrentAffiliate
                    ? FontWeight.w900
                    : FontWeight.w700,
              ),
            ),
          ),
          Text(
            '${entry.ticketCount}',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: entry.isCurrentAffiliate
                  ? colorScheme.primary
                  : colorScheme.onSurface,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _AffiliateRankMark extends StatelessWidget {
  const _AffiliateRankMark({required this.rank});

  final int rank;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final medalColor = switch (rank) {
      1 => const Color(0xFFC68B00),
      2 => const Color(0xFF667085),
      3 => const Color(0xFFA86132),
      _ => colorScheme.onSurfaceVariant,
    };
    return Container(
      width: rank <= 3 ? 38 : 30,
      height: 30,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: medalColor.withValues(alpha: rank <= 3 ? 0.13 : 0.07),
        shape: BoxShape.circle,
      ),
      child: rank <= 3
          ? Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.emoji_events_rounded, color: medalColor, size: 13),
                const SizedBox(width: 1),
                Text(
                  '$rank',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: medalColor,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            )
          : Text(
              '$rank',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: medalColor,
                fontWeight: FontWeight.w900,
              ),
            ),
    );
  }
}

TextStyle? _affiliateLeaderboardHeaderStyle(BuildContext context) {
  return Theme.of(context).textTheme.labelSmall?.copyWith(
    color: Theme.of(context).colorScheme.onSurfaceVariant,
    fontWeight: FontWeight.w800,
  );
}

class _AffiliateReferralTab extends StatelessWidget {
  const _AffiliateReferralTab({
    required this.overview,
    required this.onCopy,
    required this.onShare,
  });

  final AffiliateOverview overview;
  final VoidCallback onCopy;
  final ValueChanged<BuildContext> onShare;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AffiliateSurface(
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
              onShare: onShare,
            ),
        ],
      ),
    );
  }
}

class _AffiliateReferralContent extends StatelessWidget {
  const _AffiliateReferralContent({
    required this.link,
    required this.copyTooltip,
    required this.onCopy,
    required this.onShare,
  });

  final String link;
  final String copyTooltip;
  final VoidCallback onCopy;
  final ValueChanged<BuildContext> onShare;

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
        final linkActions = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            linkBox,
            const SizedBox(height: 12),
            Builder(
              builder: (shareContext) {
                return SizedBox(
                  key: const ValueKey('affiliate-referral-share-action'),
                  width: double.infinity,
                  child: CustomerGradientButton(
                    height: 46,
                    shadow: false,
                    onPressed: () => onShare(shareContext),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.ios_share_rounded,
                          color: colorScheme.onPrimary,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.affiliateReferralShareAction),
                      ],
                    ),
                  ),
                );
              },
            ),
          ],
        );
        if (constraints.maxWidth < 520) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(child: qr),
              const SizedBox(height: 16),
              linkActions,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(width: 210, child: qr),
            const SizedBox(width: 20),
            Expanded(child: linkActions),
          ],
        );
      },
    );
  }
}

Rect? _affiliateSharePositionOrigin(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  return renderObject.localToGlobal(Offset.zero) & renderObject.size;
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

class _AffiliateWithdrawHistoryTab extends StatefulWidget {
  const _AffiliateWithdrawHistoryTab({
    required this.overview,
    required this.amountController,
    required this.payoutMethod,
    required this.submitting,
    required this.canSubmit,
    required this.payouts,
    required this.payoutsLoading,
    required this.payoutsError,
    required this.payoutsHasMore,
    required this.initialHistory,
    required this.onMethodChanged,
    required this.onSubmit,
    required this.onPayoutsRetry,
    required this.onPayoutsLoadMore,
  });

  final AffiliateOverview overview;
  final TextEditingController amountController;
  final String payoutMethod;
  final bool submitting;
  final bool canSubmit;
  final List<AffiliatePayout> payouts;
  final bool payoutsLoading;
  final String payoutsError;
  final bool payoutsHasMore;
  final bool initialHistory;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback onSubmit;
  final VoidCallback onPayoutsRetry;
  final VoidCallback onPayoutsLoadMore;

  @override
  State<_AffiliateWithdrawHistoryTab> createState() =>
      _AffiliateWithdrawHistoryTabState();
}

class _AffiliateWithdrawHistoryTabState
    extends State<_AffiliateWithdrawHistoryTab> {
  late bool _showHistory;

  @override
  void initState() {
    super.initState();
    _showHistory = widget.initialHistory;
  }

  @override
  void didUpdateWidget(covariant _AffiliateWithdrawHistoryTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialHistory != widget.initialHistory) {
      _showHistory = widget.initialHistory;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateWithdrawSegmentedControl(
          showHistory: _showHistory,
          onChanged: (showHistory) {
            if (_showHistory == showHistory) return;
            setState(() => _showHistory = showHistory);
          },
        ),
        const SizedBox(height: 12),
        if (_showHistory)
          _AffiliatePayoutsTab(
            key: const ValueKey('affiliate-withdraw-history-content'),
            payouts: widget.payouts,
            loading: widget.payoutsLoading,
            error: widget.payoutsError,
            hasMore: widget.payoutsHasMore,
            onRetry: widget.onPayoutsRetry,
            onLoadMore: widget.onPayoutsLoadMore,
          )
        else
          _AffiliateWithdrawTab(
            key: const ValueKey('affiliate-withdraw-form-content'),
            overview: widget.overview,
            amountController: widget.amountController,
            payoutMethod: widget.payoutMethod,
            submitting: widget.submitting,
            canSubmit: widget.canSubmit,
            onMethodChanged: widget.onMethodChanged,
            onSubmit: widget.onSubmit,
          ),
      ],
    );
  }
}

class _AffiliateWithdrawSegmentedControl extends StatelessWidget {
  const _AffiliateWithdrawSegmentedControl({
    required this.showHistory,
    required this.onChanged,
  });

  final bool showHistory;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('affiliate-withdraw-segmented-control'),
      height: 46,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.72),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AffiliateWithdrawSegment(
              label: context.l10n.affiliateTabLabel('withdraw'),
              selected: !showHistory,
              onTap: () => onChanged(false),
            ),
          ),
          Expanded(
            child: _AffiliateWithdrawSegment(
              label: context.l10n.affiliateTabLabel('payouts'),
              selected: showHistory,
              onTap: () => onChanged(true),
            ),
          ),
        ],
      ),
    );
  }
}

class _AffiliateWithdrawSegment extends StatelessWidget {
  const _AffiliateWithdrawSegment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        child: Center(
          child: Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: selected
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }
}

class _AffiliateWithdrawTab extends StatelessWidget {
  const _AffiliateWithdrawTab({
    super.key,
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
              context.push('/profile/reward-bank?redirect=/affiliate/withdraw'),
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
    super.key,
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

Color _affiliateTierColor(BuildContext context, String code) {
  return switch (code.trim().toLowerCase()) {
    'bronze' => const Color(0xFFA86132),
    'silver' => const Color(0xFF667085),
    'gold' => const Color(0xFFC68B00),
    'platinum' => const Color(0xFF4D6B82),
    'diamond' => Theme.of(context).colorScheme.primary,
    _ => Theme.of(context).colorScheme.primary,
  };
}

List<Color> _affiliateTierCardGradient(BuildContext context, String code) {
  return switch (code.trim().toLowerCase()) {
    'bronze' => const [Color(0xFFA85D33), Color(0xFF60301F)],
    'silver' => const [Color(0xFF637383), Color(0xFF35414E)],
    'gold' => const [Color(0xFF9C7000), Color(0xFF584000)],
    'platinum' => const [Color(0xFF526E82), Color(0xFF293F51)],
    'diamond' => const [Color(0xFF087FF0), Color(0xFF004FAD)],
    _ => [
      Theme.of(context).colorScheme.primary,
      Color.lerp(Theme.of(context).colorScheme.primary, Colors.black, 0.34) ??
          Theme.of(context).colorScheme.primary,
    ],
  };
}

AffiliateTierCampaign? _affiliateRankingCampaign(
  List<AffiliateTierCampaign> campaigns,
) {
  final active = campaigns
      .where((campaign) => campaign.status == 'active')
      .toList(growable: false);
  if (active.isNotEmpty) {
    return _affiliateLatestCampaign(active);
  }
  final completed = campaigns
      .where((campaign) => campaign.status == 'completed')
      .toList(growable: false);
  return completed.isEmpty ? null : _affiliateLatestCampaign(completed);
}

AffiliateTierCampaign _affiliateLatestCampaign(
  List<AffiliateTierCampaign> campaigns,
) {
  final ordered = [...campaigns]
    ..sort((left, right) {
      final leftDate =
          parseDateTime(left.endsAt) ??
          parseDateTime(left.startsAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      final rightDate =
          parseDateTime(right.endsAt) ??
          parseDateTime(right.startsAt) ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return rightDate.compareTo(leftDate);
    });
  return ordered.first;
}

List<AffiliateTierLeaderboardEntry> _affiliateAllLeaderboardRows(
  AffiliateTierCampaign campaign,
) {
  return [...campaign.leaderboard]
    ..sort((left, right) => left.rank.compareTo(right.rank));
}

List<_AffiliateLeaderboardTierGroup> _affiliateLeaderboardTierGroups(
  AffiliateTierCampaign campaign,
  List<AffiliateTierLeaderboardEntry> entries,
) {
  final groups = <String, _AffiliateLeaderboardTierGroup>{};
  for (final entry in entries) {
    final tier = _affiliateLeaderboardTier(campaign, entry);
    final key = tier?.code.trim().toLowerCase() ?? '';
    final group = groups.putIfAbsent(
      key,
      () => _AffiliateLeaderboardTierGroup(tier: tier, entries: []),
    );
    group.entries.add(entry);
  }
  final ordered = groups.values.toList(growable: false);
  ordered.sort((left, right) {
    final leftRank = _affiliateTierOrder(left.tier);
    final rightRank = _affiliateTierOrder(right.tier);
    return rightRank.compareTo(leftRank);
  });
  return ordered;
}

AffiliateTier? _affiliateLeaderboardTier(
  AffiliateTierCampaign campaign,
  AffiliateTierLeaderboardEntry entry,
) {
  AffiliateTier? selected;
  if (campaign.isFixedThreshold) {
    for (final rule in _affiliateSortedRules(campaign)) {
      if (entry.ticketCount >= rule.minimumTicketCount) {
        selected = rule.targetTier;
      }
    }
    return selected;
  }
  for (final rule in _affiliateSortedRules(campaign)) {
    if (entry.rank >= rule.rankFrom && entry.rank <= rule.rankTo) {
      return rule.targetTier;
    }
  }
  return null;
}

int _affiliateTierOrder(AffiliateTier? tier) {
  if (tier == null) return 0;
  if (tier.rank > 0) return tier.rank;
  return switch (tier.code.trim().toLowerCase()) {
    'bronze' => 1,
    'silver' => 2,
    'gold' => 3,
    'platinum' => 4,
    'diamond' => 5,
    _ => 0,
  };
}

Color _affiliateCampaignStatusColor(BuildContext context, String status) {
  final colorScheme = Theme.of(context).colorScheme;
  return switch (status) {
    'active' => colorScheme.primary,
    'scheduled' => colorScheme.secondary,
    'processing' => colorScheme.tertiary,
    'completed' => const Color(0xFF16845B),
    'cancelled' => colorScheme.error,
    _ => colorScheme.onSurfaceVariant,
  };
}

String _affiliateCampaignPeriod(
  BuildContext context,
  AffiliateTierCampaign campaign,
) {
  final start = parseDateTime(campaign.startsAt);
  final end = parseDateTime(campaign.endsAt);
  if (start == null || end == null) return '';
  final locale = localeTag(context.l10n.locale);
  return context.l10n.affiliateCampaignPeriod(
    formatLocalizedShortDate(start, locale),
    formatLocalizedShortDate(end, locale),
  );
}

List<AffiliateTierCampaignRule> _affiliateSortedRules(
  AffiliateTierCampaign campaign,
) {
  return [...campaign.rules]..sort((left, right) {
    if (campaign.isFixedThreshold) {
      return left.minimumTicketCount.compareTo(right.minimumTicketCount);
    }
    return left.rankFrom.compareTo(right.rankFrom);
  });
}

class _AffiliateLeaderboardTierGroup {
  _AffiliateLeaderboardTierGroup({required this.tier, required this.entries});

  final AffiliateTier? tier;
  final List<AffiliateTierLeaderboardEntry> entries;
}

String _affiliateTierAssetCode(String code) {
  final normalized = code.trim().toLowerCase();
  return const {
        'bronze',
        'silver',
        'gold',
        'platinum',
        'diamond',
      }.contains(normalized)
      ? normalized
      : 'bronze';
}

enum AffiliateTab { overview, campaigns, referral, withdraw, commissions }

String affiliatePathForTab(AffiliateTab tab) {
  return switch (tab) {
    AffiliateTab.overview => '/affiliate',
    AffiliateTab.campaigns => '/affiliate/rankings',
    AffiliateTab.referral => '/affiliate/referral',
    AffiliateTab.withdraw => '/affiliate/withdraw',
    AffiliateTab.commissions => '/affiliate/commissions',
  };
}

String _affiliatePageTitle(CustomerLocalizations l10n, AffiliateTab tab) {
  return switch (tab) {
    AffiliateTab.overview => l10n.affiliateTitle,
    AffiliateTab.campaigns => l10n.affiliateRankingsTitle,
    AffiliateTab.referral => l10n.affiliateReferralTitle,
    AffiliateTab.withdraw => l10n.affiliateWithdrawTitle,
    AffiliateTab.commissions => l10n.affiliateCommissionsTitle,
  };
}
