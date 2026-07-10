import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

Color _autoRewardSurfaceTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.08) ??
    colorScheme.surface;

Color _autoRewardPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _autoRewardWarningTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiaryContainer, colorScheme.surface, 0.18) ??
    colorScheme.tertiaryContainer.withValues(alpha: 0.82);

Color _autoRewardSuccessTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiaryContainer, colorScheme.surface, 0.36) ??
    colorScheme.tertiaryContainer.withValues(alpha: 0.64);

class AutoRewardScreen extends ConsumerStatefulWidget {
  const AutoRewardScreen({super.key});

  @override
  ConsumerState<AutoRewardScreen> createState() => _AutoRewardScreenState();
}

class _AutoRewardScreenState extends ConsumerState<AutoRewardScreen> {
  bool _showIntro = true;
  String _payoutType = 'wallet';
  String _hydratedProfileId = '';
  String _noticeMessage = '';
  bool _noticeIsError = true;
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(customerProfileSettingsProvider);
    final reviewerName = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => data.siteName.trim(),
          orElse: () => '',
        );
    return profile.when(
      data: (data) {
        _hydrate(data);
        return _showIntro
            ? _AutoRewardIntro(
                reviewerName: reviewerName,
                onStart: () => setState(() {
                  _showIntro = false;
                  _noticeMessage = '';
                }),
                onBack: () => context.go('/profile'),
              )
            : _AutoRewardSelect(
                profile: data,
                reviewerName: reviewerName,
                payoutType: _payoutType,
                noticeMessage: _noticeMessage,
                noticeIsError: _noticeIsError,
                saving: _saving,
                onInfo: () => setState(() => _showIntro = true),
                onChanged: _selectPayoutType,
                onSave: () => _startSave(data),
              );
      },
      loading: () => const _AutoRewardLoading(),
      error: (error, __) => _AutoRewardError(
        message: authErrorMessage(
          error,
          l10n.profileAutoRewardLoadFailed,
        ),
        onRetry: () => ref.invalidate(customerProfileSettingsProvider),
      ),
    );
  }

  void _hydrate(CustomerProfileSettings profile) {
    if (_hydratedProfileId == profile.id) return;
    _hydratedProfileId = profile.id;
    _payoutType =
        profile.autoReward.isBankTransfer ? 'bank_transfer' : 'wallet';
    _showIntro = !profile.autoReward.enabled;
  }

  void _selectPayoutType(String type, CustomerProfileSettings profile) {
    setState(() {
      _payoutType = type;
      if (type == 'bank_transfer' && !profile.bankAccount.isComplete) {
        _noticeMessage = context.l10n.profileAutoRewardSaveBankFirst;
        _noticeIsError = true;
      } else {
        _noticeMessage = '';
      }
    });
  }

  void _startSave(CustomerProfileSettings profile) {
    final l10n = context.l10n;
    if (_payoutType == 'bank_transfer' && !profile.bankAccount.isComplete) {
      setState(() {
        _noticeMessage = l10n.profileAutoRewardAddBankFirst;
        _noticeIsError = true;
      });
      context.go('/profile/reward-bank?redirect=/profile/auto-reward');
      return;
    }

    _save();
  }

  Future<void> _save() async {
    final l10n = context.l10n;
    final failedMessage = l10n.profileAutoRewardSaveFailed;
    setState(() {
      _saving = true;
      _noticeMessage = '';
    });
    try {
      await ref.read(profileSettingsRepositoryProvider).saveAutoReward(
            enabled: true,
            payoutMethod: _payoutType,
          );
      ref.invalidate(customerProfileSettingsProvider);
      if (!mounted) return;
      context.go('/profile');
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _noticeMessage = authErrorMessage(error, failedMessage);
        _noticeIsError = true;
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AutoRewardIntro extends StatelessWidget {
  const _AutoRewardIntro({
    required this.reviewerName,
    required this.onStart,
    required this.onBack,
  });

  final String reviewerName;
  final VoidCallback onStart;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final benefits = [
      l10n.profileAutoRewardBenefitConvenient,
      l10n.profileAutoRewardBenefitEasy,
      l10n.profileAutoRewardBenefitFast(reviewerName),
    ];
    final conditions = [
      l10n.profileAutoRewardConditionAutoClaim,
      l10n.profileAutoRewardConditionFee,
      l10n.profileAutoRewardConditionChangeBefore,
      l10n.profileAutoRewardConditionNoRetroactive,
    ];
    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _AutoRewardVisual(onBack: onBack),
                  _AutoRewardIntroSheet(
                    title: l10n.profileAutoReward,
                    subtitle: l10n.profileAutoRewardIntroSubtitle,
                    benefits: benefits,
                    conditions: conditions,
                  ),
                ],
              ),
            ),
            _AutoRewardFooter(
              child: FilledButton(
                onPressed: onStart,
                child: Text(l10n.profileAutoRewardStartButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AutoRewardVisual extends StatelessWidget {
  const _AutoRewardVisual({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final top = AppTheme.heroGradientEnd(colorScheme.primary);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            top,
            Color.lerp(top, colorScheme.surface, 0.62) ?? top,
            colorScheme.surface,
          ],
          stops: const [0, 0.58, 1],
        ),
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: SizedBox(
            height: 256,
            child: Stack(
              clipBehavior: Clip.none,
              children: [
                Positioned(
                  left: 20,
                  top: 28,
                  child: IconButton(
                    tooltip: l10n.commonBack,
                    onPressed: onBack,
                    color: colorScheme.primary,
                    iconSize: 34,
                    icon: const Icon(Icons.chevron_left),
                    style: IconButton.styleFrom(
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      minimumSize: const Size.square(44),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                ),
                Positioned(
                  left: 104,
                  top: 18,
                  child: Transform.rotate(
                    angle: -0.14,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            Color.lerp(
                                  colorScheme.secondary,
                                  colorScheme.surface,
                                  0.2,
                                ) ??
                                colorScheme.secondary,
                            colorScheme.primary,
                          ],
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: colorScheme.primary.withValues(alpha: 0.28),
                            blurRadius: 48,
                            offset: const Offset(0, 22),
                          ),
                        ],
                      ),
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(22, 54, 22, 22),
                        child: SizedBox(
                          width: 60,
                          height: 96,
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: const [
                              _AutoRewardPhoneLine(),
                              _AutoRewardPhoneLine(),
                              _AutoRewardPhoneLine(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 182,
                  top: 36,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(
                        color: colorScheme.tertiary,
                        width: 4,
                      ),
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: colorScheme.shadow.withValues(alpha: 0.13),
                          blurRadius: 32,
                          offset: const Offset(0, 14),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(18, 10, 18, 10),
                      child: Stack(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(top: 18),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  l10n.profileAutoRewardVisualCreditAmount,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 32,
                                    fontWeight: FontWeight.w900,
                                    height: 1,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  l10n.profileAutoRewardVisualCreditCurrency,
                                  style: TextStyle(
                                    color: colorScheme.onSurface,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Positioned(
                            top: 0,
                            child: Text(
                              l10n.profileAutoRewardVisualCreditLabel,
                              style: TextStyle(
                                color: colorScheme.onSurface,
                                fontSize: 13,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 58,
                  top: 96,
                  child: Transform.rotate(
                    angle: -0.31,
                    child: _FloatingVisualIcon(
                      icon: Icons.monetization_on,
                      color: colorScheme.tertiary,
                      size: 42,
                    ),
                  ),
                ),
                Positioned(
                  right: 58,
                  top: 154,
                  child: Transform.rotate(
                    angle: 0.31,
                    child: _FloatingVisualIcon(
                      icon: Icons.monetization_on,
                      color: colorScheme.tertiary,
                      size: 42,
                    ),
                  ),
                ),
                Positioned(
                  left: 50,
                  top: 36,
                  child: Transform.rotate(
                    angle: 0.30,
                    child: _FloatingVisualIcon(
                      icon: Icons.receipt_long,
                      color: colorScheme.onPrimary.withValues(alpha: 0.62),
                      size: 44,
                    ),
                  ),
                ),
                Positioned(
                  right: 42,
                  top: 112,
                  child: Transform.rotate(
                    angle: -0.24,
                    child: _FloatingVisualIcon(
                      icon: Icons.receipt_long,
                      color: colorScheme.onPrimary.withValues(alpha: 0.62),
                      size: 44,
                    ),
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

class _AutoRewardPhoneLine extends StatelessWidget {
  const _AutoRewardPhoneLine();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.onPrimary.withValues(alpha: 0.32),
        borderRadius: BorderRadius.circular(999),
      ),
      child: const SizedBox(height: 12, width: double.infinity),
    );
  }
}

class _FloatingVisualIcon extends StatelessWidget {
  const _FloatingVisualIcon({
    required this.icon,
    required this.color,
    required this.size,
  });

  final IconData icon;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Icon(
      icon,
      color: color,
      size: size,
      shadows: [
        Shadow(
          color: colorScheme.shadow.withValues(alpha: 0.16),
          blurRadius: 8,
          offset: const Offset(0, 5),
        ),
      ],
    );
  }
}

class _AutoRewardIntroSheet extends StatelessWidget {
  const _AutoRewardIntroSheet({
    required this.title,
    required this.subtitle,
    required this.benefits,
    required this.conditions,
  });

  final String title;
  final String subtitle;
  final List<String> benefits;
  final List<String> conditions;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Transform.translate(
      offset: const Offset(0, -12),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(36)),
        ),
        child: CustomerPageBody(
          top: 28,
          bottom: 18,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontWeight: FontWeight.w900,
                    ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: colorScheme.onSurfaceVariant,
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 34),
              for (final item in benefits) _BenefitRow(text: item),
              const SizedBox(height: 18),
              Text(
                context.l10n.profileAutoRewardConditionsTitle,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: _autoRewardSurfaceTint(colorScheme),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final item in conditions) _BulletText(item),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoRewardLoading extends StatelessWidget {
  const _AutoRewardLoading();

  @override
  Widget build(BuildContext context) {
    return AppShell(
      title: context.l10n.profileAutoReward,
      currentPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      child: Center(
        child: CustomerLoadingMark(
          width: 46,
          height: 28,
          semanticLabel: context.l10n.commonLoadingData,
        ),
      ),
    );
  }
}

class _AutoRewardError extends StatelessWidget {
  const _AutoRewardError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return AppShell(
      title: context.l10n.profileAutoReward,
      currentPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      child: ListView(
        padding: EdgeInsets.zero,
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CustomerPageBody(
            child: DecoratedBox(
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
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                            fontWeight: FontWeight.w800,
                            height: 1.45,
                          ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        shape: const StadiumBorder(),
                        minimumSize: const Size(132, 42),
                        textStyle: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      onPressed: onRetry,
                      child: Text(context.l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoRewardSelect extends StatelessWidget {
  const _AutoRewardSelect({
    required this.profile,
    required this.reviewerName,
    required this.payoutType,
    required this.noticeMessage,
    required this.noticeIsError,
    required this.saving,
    required this.onInfo,
    required this.onChanged,
    required this.onSave,
  });

  final CustomerProfileSettings profile;
  final String reviewerName;
  final String payoutType;
  final String noticeMessage;
  final bool noticeIsError;
  final bool saving;
  final VoidCallback onInfo;
  final void Function(String, CustomerProfileSettings) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.profileAutoReward,
      currentPath: '/profile',
      sensitive: true,
      fullScreen: true,
      showBottomNavigation: false,
      child: Column(
        children: [
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _AutoRewardSelectHero(
                  onBack: () => context.go('/profile'),
                  onInfo: onInfo,
                ),
                _AutoRewardSelectSheet(
                  child: CustomerPageBody(
                    top: 28,
                    bottom: 24,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          l10n.profileAutoRewardSelectTitle,
                          style: Theme.of(context)
                              .textTheme
                              .titleLarge
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w900,
                                height: 1.28,
                              ),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          l10n.profileAutoRewardSelectSubtitle(reviewerName),
                          style: TextStyle(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 24),
                        if (noticeMessage.isNotEmpty) ...[
                          _AutoRewardNotice(
                            message: noticeMessage,
                            isError: noticeIsError,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _PayoutOption(
                          selected: payoutType == 'wallet',
                          icon: Icons.account_balance_wallet_outlined,
                          title: l10n.profileAutoRewardWalletTitle,
                          subtitle: maskWalletId(profile.walletId),
                          helper: l10n.profileAutoRewardWalletSubtitle,
                          onTap: () => onChanged('wallet', profile),
                        ),
                        const SizedBox(height: 16),
                        _PayoutOption(
                          selected: payoutType == 'bank_transfer',
                          icon: Icons.account_balance_outlined,
                          title: _bankTitle(profile.bankAccount, l10n),
                          subtitle: profile.bankAccount.isComplete
                              ? '${profile.bankAccount.accountName} · ${profile.bankAccount.maskedNumber}'
                              : l10n.profileAutoRewardBankMissingSubtitle,
                          helper: profile.bankAccount.isComplete
                              ? ''
                              : l10n.profileAutoRewardBankMissingHelper,
                          onTap: () => onChanged('bank_transfer', profile),
                          warning: !profile.bankAccount.isComplete,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          _AutoRewardFooter(
            child: FilledButton(
              onPressed: saving ? null : onSave,
              child: saving
                  ? Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox.square(
                          dimension: 16,
                          child: CustomerLoadingMark(
                            width: 18,
                            height: 14,
                            color: Theme.of(context).colorScheme.onPrimary,
                            trackColor: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.24),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(l10n.commonNext),
                      ],
                    )
                  : Text(l10n.commonNext),
            ),
          ),
        ],
      ),
    );
  }

  String _bankTitle(
    RewardBankAccount account,
    CustomerLocalizations l10n,
  ) {
    if (!account.isComplete) return l10n.profileAutoRewardBankTitle;
    final bank = account.bankName.trim();
    return bank.isEmpty ? l10n.profileAutoRewardBankTitle : bank;
  }
}

class _AutoRewardSelectHero extends StatelessWidget {
  const _AutoRewardSelectHero({
    required this.onBack,
    required this.onInfo,
  });

  final VoidCallback onBack;
  final VoidCallback onInfo;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
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
          constraints: const BoxConstraints(maxWidth: 640),
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, topInset + 58, 20, 34),
            child: _AutoRewardHeroTitleRow(
              title: l10n.profileAutoReward,
              onBack: onBack,
              onInfo: onInfo,
              infoTooltip: l10n.profileAutoRewardInfoTooltip,
            ),
          ),
        ),
      ),
    );
  }
}

class _AutoRewardHeroTitleRow extends StatelessWidget {
  const _AutoRewardHeroTitleRow({
    required this.title,
    required this.onBack,
    required this.onInfo,
    required this.infoTooltip,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback onInfo;
  final String infoTooltip;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 31),
              color: colorScheme.onPrimary,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.transparent,
                foregroundColor: colorScheme.onPrimary,
                shape: const CircleBorder(),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 54),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
            ),
          ),
          Positioned(
            right: 0,
            child: IconButton(
              tooltip: infoTooltip,
              onPressed: onInfo,
              icon: const Icon(Icons.info_outline, size: 27),
              color: colorScheme.onPrimary,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.transparent,
                foregroundColor: colorScheme.onPrimary,
                shape: const CircleBorder(),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AutoRewardSelectSheet extends StatelessWidget {
  const _AutoRewardSelectSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.primary),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: Transform.translate(
          offset: const Offset(0, -34),
          child: child,
        ),
      ),
    );
  }
}

class _AutoRewardNotice extends StatelessWidget {
  const _AutoRewardNotice({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError ? colorScheme.error : colorScheme.tertiary;
    final background = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.50)
        : _autoRewardSuccessTint(colorScheme);
    final border = isError
        ? colorScheme.error.withValues(alpha: 0.22)
        : colorScheme.tertiary.withValues(alpha: 0.22);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
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

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.helper = '',
    this.warning = false,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String helper;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final activeColor = colorScheme.primary;
    final accentColor = warning
        ? colorScheme.onTertiaryContainer
        : selected
            ? activeColor
            : colorScheme.onSurfaceVariant;
    return Material(
      color: selected
          ? Color.lerp(activeColor, colorScheme.surface, 0.92)
          : colorScheme.surface,
      borderRadius: BorderRadius.circular(14),
      clipBehavior: Clip.antiAlias,
      child: Ink(
        decoration: BoxDecoration(
          border: Border.all(
            color: selected ? activeColor : colorScheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: colorScheme.shadow.withValues(alpha: 0.04),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
                child: Row(
                  children: [
                    _AutoRewardRadio(
                      selected: selected,
                      color: activeColor,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onSurface,
                              fontSize: 20,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            subtitle,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 2,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 15,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 14),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: warning
                            ? null
                            : LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: selected
                                    ? [
                                        Color.lerp(
                                              activeColor,
                                              colorScheme.surface,
                                              0.08,
                                            ) ??
                                            activeColor,
                                        activeColor,
                                      ]
                                    : [
                                        _autoRewardPrimaryTint(colorScheme),
                                        _autoRewardPrimaryTint(colorScheme),
                                      ],
                              ),
                        color: warning
                            ? _autoRewardWarningTint(colorScheme)
                            : null,
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: SizedBox.square(
                        dimension: 54,
                        child: Center(
                          child: Icon(
                            icon,
                            color: warning
                                ? colorScheme.onTertiaryContainer
                                : selected
                                    ? colorScheme.onPrimary
                                    : activeColor,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              if (helper.isNotEmpty)
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: warning
                        ? _autoRewardWarningTint(colorScheme)
                        : _autoRewardPrimaryTint(colorScheme),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(22, 11, 22, 11),
                    child: Text(
                      helper,
                      style: TextStyle(
                        color: accentColor,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1.35,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AutoRewardRadio extends StatelessWidget {
  const _AutoRewardRadio({
    required this.selected,
    required this.color,
  });

  final bool selected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: selected ? color : Colors.transparent,
        border: Border.all(
          color:
              selected ? color : Theme.of(context).colorScheme.outlineVariant,
          width: 2,
        ),
        shape: BoxShape.circle,
      ),
      child: SizedBox.square(
        dimension: 34,
        child: Icon(
          Icons.check,
          color: selected
              ? Theme.of(context).colorScheme.onPrimary
              : Colors.transparent,
          size: 22,
        ),
      ),
    );
  }
}

class _AutoRewardFooter extends StatelessWidget {
  const _AutoRewardFooter({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 18,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 10, 16, 16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 920),
            child: SizedBox(width: double.infinity, child: child),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}
