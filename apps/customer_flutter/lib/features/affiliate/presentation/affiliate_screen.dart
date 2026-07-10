import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../profile/data/profile_settings_models.dart';
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
  bool _commissionsLoaded = false;
  bool _commissionsLoading = false;
  bool _commissionsHasMore = false;
  bool _payoutsLoaded = false;
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

  final _pinFocusNode = FocusNode(debugLabel: 'affiliate-pin-keypad');
  final _storeNameController = TextEditingController();
  final _payoutAmountController = TextEditingController();
  String _payoutMethod = 'bank_transfer';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _pinFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _pinFocusNode.dispose();
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
    final brand = bootstrap.maybeWhen(
      data: (data) => data.siteName.trim(),
      orElse: () => '',
    );

    if (!_pinVerified) {
      return Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        body: KeyboardListener(
          focusNode: _pinFocusNode,
          autofocus: true,
          onKeyEvent: _handleAffiliatePinKeyEvent,
          child: SafeArea(
            child: _AffiliatePinGate(
              brand: brand.isEmpty ? l10n.affiliateTitle : brand,
              pin: _pin,
              error: _pinError,
              verifying: _verifyingPin,
              onDigit: _appendPinDigit,
              onBackspace: _removePinDigit,
              onBack: () => context.go('/profile'),
              biometricEnabled: biometricEnabled,
              onBiometric: _verifyWithBiometric,
            ),
          ),
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
          children: [
            _AffiliateHero(overview: _overview),
            _AffiliateSheet(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_noticeMessage.isNotEmpty) ...[
                    _AffiliateInlineNotice(
                      message: _noticeMessage,
                      success: _noticeSuccess,
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
                      submitting: _submitting,
                      onSubmit: _register,
                    )
                  else ...[
                    _AffiliateStoreSummary(overview: _overview),
                    const SizedBox(height: 12),
                    _AffiliateStatsGrid(stats: _overview.stats),
                    const SizedBox(height: 12),
                    _AffiliateTabBar(
                      activeTab: _tab,
                      onChanged: _changeTab,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _appendPinDigit(String digit) {
    if (_pin.length >= 6 || _verifyingPin || !RegExp(r'^\d$').hasMatch(digit)) {
      return;
    }
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

  void _handleAffiliatePinKeyEvent(KeyEvent event) {
    if (event is! KeyDownEvent || _verifyingPin) return;
    final value = event.character ?? event.logicalKey.keyLabel;
    if (RegExp(r'^\d$').hasMatch(value)) {
      _appendPinDigit(value);
      return;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace) {
      _removePinDigit();
    }
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
                localizedReason: mobileBiometricPromptReason(
                  ref.read(mobileBootstrapProvider).valueOrNull,
                  purpose: 'pin_unlock',
                  fallback: context.l10n.pinBiometricReason,
                ),
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
      _noticeMessage = '';
    });
    try {
      final overview = await ref.read(affiliateRepositoryProvider).overview();
      if (!mounted) return;
      setState(() => _applyOverview(overview));
      if (_tab == AffiliateTab.commissions) {
        await _loadCommissions(reset: true);
      } else if (_tab == AffiliateTab.payouts) {
        await _loadPayouts(reset: true);
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _loadError = context.l10n.affiliateLoadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _changeTab(AffiliateTab tab) {
    setState(() => _tab = tab);
    if (tab == AffiliateTab.commissions && !_commissionsLoaded) {
      _loadCommissions(reset: true);
    } else if (tab == AffiliateTab.payouts && !_payoutsLoaded) {
      _loadPayouts(reset: true);
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
      final page = await ref.read(affiliateRepositoryProvider).commissions(
            cursor: reset ? '' : _commissionsCursor,
          );
      if (!mounted) return;
      setState(() {
        _commissions = reset ? page.items : [..._commissions, ...page.items];
        _commissionsCursor = page.nextCursor;
        _commissionsHasMore = page.hasMore;
        _commissionsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _commissionsLoaded = true;
        _commissionsError = context.l10n.affiliateLoadFailed;
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
      final page = await ref.read(affiliateRepositoryProvider).payouts(
            cursor: reset ? '' : _payoutsCursor,
          );
      if (!mounted) return;
      setState(() {
        _payouts = reset ? page.items : [..._payouts, ...page.items];
        _payoutsCursor = page.nextCursor;
        _payoutsHasMore = page.hasMore;
        _payoutsLoaded = true;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _payoutsLoaded = true;
        _payoutsError = context.l10n.affiliateLoadFailed;
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
      final overview =
          await ref.read(affiliateRepositoryProvider).register(name: name);
      if (!mounted) return;
      setState(() => _applyOverview(overview));
      _showNotice(context.l10n.affiliateRegisterSuccess, success: true);
    } catch (_) {
      if (!mounted) return;
      _showNotice(context.l10n.affiliateRegisterFailed);
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
      await _loadPayouts(reset: true);
      if (!mounted) return;
      _showNotice(context.l10n.affiliatePayoutSuccess, success: true);
    } catch (_) {
      if (!mounted) return;
      _showNotice(context.l10n.affiliatePayoutFailed);
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

  void _hydratePayoutDefaults(AffiliateOverview overview) {
    if (overview.bankAccount.isComplete) _payoutMethod = 'bank_transfer';
  }

  void _applyOverview(AffiliateOverview overview) {
    _overview = overview;
    _hydratePayoutDefaults(overview);
    _commissions = overview.commissions;
    _commissionsCursor = '';
    _commissionsHasMore = false;
    _commissionsLoaded = false;
    _commissionsError = '';
    _payouts = overview.payouts;
    _payoutsCursor = '';
    _payoutsHasMore = false;
    _payoutsLoaded = false;
    _payoutsError = '';
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
    required this.brand,
    required this.pin,
    required this.error,
    required this.verifying,
    required this.onDigit,
    required this.onBackspace,
    required this.onBack,
    required this.biometricEnabled,
    required this.onBiometric,
  });

  final String brand;
  final String pin;
  final String error;
  final bool verifying;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBack;
  final bool biometricEnabled;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return LayoutBuilder(
      builder: (context, constraints) {
        final compact = constraints.maxHeight < 660;
        final horizontal = constraints.maxWidth <= 360 ? 22.0 : 28.0;
        return Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
          child: Column(
            children: [
              _AffiliatePinTopBar(
                brand: brand,
                disabled: verifying,
                onBack: onBack,
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: _AffiliatePinMainContent(
                      title: l10n.affiliatePinTitle,
                      subtitle: verifying
                          ? l10n.pinVerifying
                          : l10n.affiliatePinSubtitle,
                      error: error,
                      pinLength: pin.length,
                      verifying: verifying,
                      compact: compact,
                      showBiometric: biometricEnabled,
                      onBiometric: onBiometric,
                    ),
                  ),
                ),
              ),
              _AffiliatePinKeypad(
                onDigit: onDigit,
                onBackspace: onBackspace,
                enabled: !verifying,
                compact: compact,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AffiliateInlineNotice extends StatelessWidget {
  const _AffiliateInlineNotice({
    required this.message,
    this.success = false,
  });

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

class _AffiliatePinTopBar extends StatelessWidget {
  const _AffiliatePinTopBar({
    required this.brand,
    required this.disabled,
    required this.onBack,
  });

  final String brand;
  final bool disabled;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: IconButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                tooltip: context.l10n.commonBack,
                onPressed: disabled ? null : onBack,
                icon: const Icon(Icons.chevron_left, size: 30),
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                brand,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                      height: 1,
                    ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }
}

class _AffiliatePinMainContent extends StatelessWidget {
  const _AffiliatePinMainContent({
    required this.title,
    required this.subtitle,
    required this.error,
    required this.pinLength,
    required this.verifying,
    required this.compact,
    required this.showBiometric,
    required this.onBiometric,
  });

  final String title;
  final String subtitle;
  final String error;
  final int pinLength;
  final bool verifying;
  final bool compact;
  final bool showBiometric;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: colorScheme.onSurface,
                fontSize: compact ? 26 : 30,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontSize: compact ? 17 : 20,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
        ),
        SizedBox(height: compact ? 20 : 30),
        _AffiliatePinIndicator(length: pinLength, hasError: error.isNotEmpty),
        AnimatedOpacity(
          opacity: error.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: BoxConstraints(
              minHeight: compact ? 22 : 30,
              maxWidth: 260,
            ),
            alignment: Alignment.center,
            margin: EdgeInsets.only(top: compact ? 10 : 14),
            child: Text(
              error.isEmpty ? ' ' : error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.error,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
        ),
        if (verifying) ...[
          const SizedBox(height: 10),
          CustomerLoadingMark(
            width: 96,
            height: 18,
            color: Theme.of(context).colorScheme.primary,
            trackColor:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.14),
          ),
        ],
        if (showBiometric) ...[
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: verifying ? null : onBiometric,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(context.l10n.pinUseBiometric),
          ),
        ],
      ],
    );
  }
}

class _AffiliatePinIndicator extends StatelessWidget {
  const _AffiliatePinIndicator({required this.length, required this.hasError});

  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < 6; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: hasError
                  ? colorScheme.error.withValues(alpha: 0.32)
                  : index < length
                      ? colorScheme.onSurface
                      : colorScheme.outlineVariant,
            ),
          ),
          if (index < 5) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _AffiliatePinKeypad extends StatelessWidget {
  const _AffiliatePinKeypad({
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
    this.compact = false,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: compact ? 17 : 24,
        crossAxisSpacing: compact ? 24 : 30,
        childAspectRatio: compact ? 1.5 : 1.75,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final key in keys)
            if (key.isEmpty)
              const SizedBox.shrink()
            else
              Semantics(
                button: true,
                label: key == 'back' ? context.l10n.commonBack : key,
                child: TextButton(
                  onPressed: !enabled
                      ? null
                      : key == 'back'
                          ? onBackspace
                          : () => onDigit(key),
                  style: TextButton.styleFrom(
                    foregroundColor: key == 'back'
                        ? colorScheme.onSurfaceVariant
                        : colorScheme.onSurface,
                    disabledForegroundColor:
                        colorScheme.onSurface.withValues(alpha: 0.42),
                    minimumSize: Size(54, compact ? 36 : 43),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                  child: key == 'back'
                      ? const Icon(Icons.backspace_outlined, size: 20)
                      : Text(key),
                ),
              ),
        ],
      ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            AppTheme.heroGradientEnd(colorScheme.primary),
          ],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 920),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 82),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.share,
                    color: colorScheme.primary,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.affiliateHeroSubtitle,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w800,
                              height: 1.28,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontSize: 22,
                                  fontWeight: FontWeight.w900,
                                  height: 1.28,
                                ),
                      ),
                    ],
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

class _AffiliateSheet extends StatelessWidget {
  const _AffiliateSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ColoredBox(
      color: colorScheme.surfaceContainerLowest,
      child: Transform.translate(
        offset: const Offset(0, -58),
        child: CustomerPageBody(
          maxWidth: 920,
          top: 0,
          bottom: 132,
          mobileHorizontal: 16,
          wideHorizontal: 16,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: child,
            ),
          ),
        ),
      ),
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
    required this.submitting,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool submitting;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return _AffiliateSurface(
      padding: const EdgeInsets.all(22),
      child: Padding(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color:
                    Theme.of(context).colorScheme.primaryContainer.withValues(
                          alpha: 0.58,
                        ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Icon(
                Icons.person_add_alt_1,
                color: Theme.of(context).colorScheme.primary,
                size: 34,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              l10n.affiliateRegisterTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
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
            FilledButton(
              style: _affiliatePrimaryPillStyle(context),
              onPressed: submitting ? null : onSubmit,
              child: Text(
                submitting
                    ? context.l10n.commonLoadingData
                    : l10n.affiliateRegisterButton,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
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

    final colorScheme = Theme.of(context).colorScheme;
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: MediaQuery.sizeOf(context).width >= 560 ? 3 : 2,
      childAspectRatio: 1.55,
      crossAxisSpacing: 10,
      mainAxisSpacing: 10,
      children: [
        for (final item in items)
          DecoratedBox(
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
    final primary = Theme.of(context).colorScheme.primary;
    final tabs = [
      (
        AffiliateTab.overview,
        l10n.affiliateTabLabel('overview'),
        Icons.grid_view
      ),
      (
        AffiliateTab.withdraw,
        l10n.affiliateTabLabel('withdraw'),
        Icons.account_balance_outlined
      ),
      (
        AffiliateTab.commissions,
        l10n.affiliateTabLabel('commissions'),
        Icons.payments_outlined
      ),
      (AffiliateTab.payouts, l10n.affiliateTabLabel('payouts'), Icons.history),
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: Row(
          children: [
            for (final tab in tabs)
              Expanded(
                child: _AffiliateTabButton(
                  label: tab.$2,
                  icon: tab.$3,
                  selected: activeTab == tab.$1,
                  onTap: () => onChanged(tab.$1),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AffiliateTabButton extends StatelessWidget {
  const _AffiliateTabButton({
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
    return Material(
      color: selected ? colorScheme.surface : Colors.transparent,
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        borderRadius: BorderRadius.circular(13),
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(13),
            boxShadow: selected
                ? [
                    BoxShadow(
                      color: primary.withValues(alpha: 0.16),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ]
                : null,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: color, size: 17),
              const SizedBox(height: 3),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: color,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
              ),
            ],
          ),
        ),
      ),
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
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
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
                _AffiliateLinkBox(
                  link: overview.referralUrl,
                  tooltip: l10n.affiliateReferralCopyTooltip,
                  onCopy: onCopy,
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _AffiliateBankSummary(
          bank: bank,
          onEdit: () => context.go('/profile/reward-bank?redirect=/affiliate'),
        ),
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
            trailing: TextButton(
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(40, 32),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: onEdit,
              child: Text(
                l10n.affiliateEdit,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
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
                    child: Text(l10n.affiliateBankRequired),
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
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
            ),
          ),
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
    return Container(
      constraints: const BoxConstraints(maxWidth: 176),
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
              child: Material(
                color: colorScheme.primary,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: onCopy,
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
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.16),
        ),
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
    return Text(
      message,
      style: _affiliateMutedTextStyle(context),
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateBankSummary(
          bank: bank,
          withdrawMode: true,
          onEdit: () => context.go('/profile/reward-bank?redirect=/affiliate'),
        ),
        const SizedBox(height: 12),
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
                if (payoutMethod == 'bank_transfer') ...[
                  const SizedBox(height: 12),
                  _AffiliateBankPreview(bank: bank),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  style: _affiliatePrimaryPillStyle(context),
                  onPressed: submitting ? null : onSubmit,
                  child: Text(
                    submitting
                        ? context.l10n.commonLoadingData
                        : l10n.affiliateWithdrawSubmit,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
    if (commissions.isEmpty) {
      return _AffiliateEmptyCard(message: l10n.affiliateCommissionsEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateListSurface(
          children: [
            for (var index = 0; index < commissions.length; index++)
              _AffiliateHistoryRow(
                title: commissions[index].orderId.isEmpty
                    ? commissions[index].id
                    : commissions[index].orderId,
                subtitle:
                    '${l10n.affiliateStatusLabel(commissions[index].status)} • '
                    '${formatLocalizedDateTime(commissions[index].calculatedAt ?? commissions[index].createdAt, localeTag(l10n.locale))}',
                amount: formatBaht(commissions[index].amount),
                showDivider: index < commissions.length - 1,
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
    if (payouts.isEmpty) {
      return _AffiliateEmptyCard(message: l10n.affiliatePayoutsEmpty);
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AffiliateListSurface(
          children: [
            for (var index = 0; index < payouts.length; index++)
              _AffiliateHistoryRow(
                title: l10n.affiliatePayoutMethodLabel(
                  payouts[index].payoutMethod,
                ),
                subtitle:
                    '${l10n.affiliateStatusLabel(payouts[index].status)} • '
                    '${formatLocalizedDateTime(payouts[index].createdAt, localeTag(l10n.locale))}',
                amount: formatBaht(payouts[index].amount),
                showDivider: index < payouts.length - 1,
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
  const _AffiliateListSurface({required this.children});

  final List<Widget> children;

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
      child: Column(children: children),
    );
  }
}

class _AffiliateHistoryRow extends StatelessWidget {
  const _AffiliateHistoryRow({
    required this.title,
    required this.subtitle,
    required this.amount,
    required this.showDivider,
  });

  final String title;
  final String subtitle;
  final String amount;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(bottom: BorderSide(color: colorScheme.outlineVariant))
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: _affiliateMutedTextStyle(context),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Text(
              amount,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
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
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.error,
            ),
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
          Icon(
            Icons.error_outline,
            color: Theme.of(context).colorScheme.error,
          ),
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

class _AffiliateEmptyCard extends StatelessWidget {
  const _AffiliateEmptyCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return _AffiliateSurface(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Center(
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: _affiliateMutedTextStyle(context),
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

ButtonStyle _affiliatePrimaryPillStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(48),
    padding: const EdgeInsets.symmetric(horizontal: 18),
    shape: const StadiumBorder(),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
  );
}

ButtonStyle _affiliateSecondaryPillStyle(BuildContext context) {
  return OutlinedButton.styleFrom(
    minimumSize: const Size(160, 44),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    shape: const StadiumBorder(),
    side: BorderSide(color: Theme.of(context).colorScheme.primary),
    textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w900,
        ),
  );
}

enum AffiliateTab { overview, withdraw, commissions, payouts }
