import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_error_message.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_fixed_header_layout.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../affiliate/data/affiliate_models.dart';
import '../../affiliate/data/affiliate_repository.dart';
import '../data/line_notification_repository.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

const double _profileHeroBaseHeight = 150;

double _profileHeroHeightFor(BuildContext context) {
  final topInset = MediaQuery.paddingOf(context).top;
  final requiredHeight = topInset + 104;
  return requiredHeight > _profileHeroBaseHeight
      ? requiredHeight
      : _profileHeroBaseHeight;
}

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _checkingLineAvailability = false;

  Future<void> _openLineNotifications() async {
    if (_checkingLineAvailability) return;
    final l10n = context.l10n;
    setState(() => _checkingLineAvailability = true);
    try {
      final settings = await ref.refresh(
        lineNotificationSettingsProvider.future,
      );
      if (!mounted) return;
      if (!settings.lineAvailable) {
        _showLineAlert(
          title: l10n.profileLineStoreUnavailableTitle,
          message: l10n.profileLineStoreUnavailableMessage,
          variant: AppAlertVariant.warning,
        );
        return;
      }
      context.go('/profile/line-notifications');
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      _showLineAlert(
        title: l10n.profileLineLoadFailed,
        message: authErrorMessage(error, l10n.profileLineLoadFailed),
        variant: AppAlertVariant.error,
      );
    } finally {
      if (mounted) setState(() => _checkingLineAvailability = false);
    }
  }

  void _showLineAlert({
    required String title,
    required String message,
    required AppAlertVariant variant,
  }) {
    ref
        .read(appAlertControllerProvider.notifier)
        .show(
          title: title,
          message: message,
          button: context.l10n.profileLineAlertAcknowledge,
          variant: variant,
        );
  }

  @override
  Widget build(BuildContext context) {
    final profile = ref.watch(customerProfileSettingsProvider);
    final affiliateOverview = ref.watch(affiliateOverviewProvider).valueOrNull;
    final affiliateTier =
        affiliateOverview != null &&
            affiliateOverview.isAffiliate &&
            affiliateOverview.tier.code.isNotEmpty
        ? affiliateOverview.tier
        : null;
    ref.listen<AsyncValue<CustomerProfileSettings>>(
      customerProfileSettingsProvider,
      (previous, next) {
        final error = next.error;
        if (error == null || identical(previous?.error, error)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          handleCustomerOperationalError(
            ref: ref,
            context: context,
            error: error,
          );
        });
      },
    );
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final l10n = context.l10n;
    final heroHeight = _profileHeroHeightFor(context);
    bool routeEnabled(String path) {
      return mobileCustomerRouteAllowed(bootstrap, path);
    }

    final historyItems = [
      if (routeEnabled('/my-wallet'))
        _ProfileMenuItem(
          title: l10n.customerRouteTitle('my_wallet'),
          path: '/my-wallet',
        ),
      if (routeEnabled('/purchase-history'))
        _ProfileMenuItem(
          title: l10n.profilePurchaseHistory,
          path: '/purchase-history',
        ),
      if (routeEnabled('/reward-claims'))
        _ProfileMenuItem(
          title: l10n.rewardClaimsHeaderTitle,
          path: '/reward-claims',
        ),
      if (routeEnabled('/activity-claims'))
        _ProfileMenuItem(
          title: l10n.customerRouteTitle('activity_claims'),
          path: '/activity-claims',
        ),
      if (routeEnabled('/activities'))
        _ProfileMenuItem(
          title: l10n.customerRouteTitle('activities'),
          path: '/activities',
          badge: l10n.profileBadgeNew,
        ),
      if (routeEnabled('/affiliate'))
        _ProfileMenuItem(
          title: l10n.customerRouteTitle('affiliate'),
          path: '/affiliate',
        ),
    ];
    final rewardSettingItems = [
      if (routeEnabled('/profile/reward-bank'))
        _ProfileMenuItem(
          title: l10n.profileRewardBankMenu,
          path: '/profile/reward-bank',
        ),
      if (routeEnabled('/profile/auto-reward'))
        _ProfileMenuItem(
          title: l10n.profileAutoReward,
          path: '/profile/auto-reward',
          badge: l10n.profileBadgeRecommended,
        ),
      if (routeEnabled('/profile/line-notifications'))
        _ProfileMenuItem(
          title: l10n.profileLineNotifications,
          path: '/profile/line-notifications',
          enabled: !_checkingLineAvailability,
          loading: _checkingLineAvailability,
          onTap: _openLineNotifications,
        ),
    ];
    final aboutItems = [
      _ProfileMenuItem(
        title: l10n.profileLanguageTitle,
        path: '/profile/language',
      ),
      if (routeEnabled('/news'))
        _ProfileMenuItem(title: l10n.profileNewsAll, path: '/news'),
      _ProfileMenuItem(title: l10n.profileTerms, path: '/terms'),
      _ProfileMenuItem(
        title: l10n.customerRouteTitle('lottery_knowledge'),
        path: '/lottery-knowledge',
      ),
      if (routeEnabled('/support'))
        _ProfileMenuItem(title: l10n.support('home.title'), path: '/support'),
    ];
    final serviceItems = [
      if (routeEnabled('/profile/biometrics'))
        _ProfileMenuItem(
          title: l10n.profileBiometrics,
          path: '/profile/biometrics',
        ),
      if (routeEnabled('/privacy'))
        _ProfileMenuItem(title: l10n.profilePrivacyPolicy, path: '/privacy'),
      if (routeEnabled('/profile/account-deletion'))
        _ProfileMenuItem(
          title: l10n.profileAccountDeletion,
          path: '/profile/account-deletion',
        ),
    ];
    return AppShell(
      title: l10n.profileTitle,
      currentPath: '/profile',
      sensitive: true,
      showBottomNavigation: true,
      fullScreen: true,
      child: CustomerFixedHeaderLayout(
        headerKey: const ValueKey('profile-fixed-header'),
        contentRegionKey: const ValueKey('profile-content-region'),
        headerHeight: heroHeight,
        contentTopRadius: customerContentSheetTopRadius,
        contentBackdropColor: Theme.of(context).colorScheme.primary,
        header: _ProfileHero(
          profile: profile,
          affiliateTier: affiliateTier,
          onRetry: () => ref.invalidate(customerProfileSettingsProvider),
        ),
        content: ListView(
          key: const ValueKey('profile-content-scroll'),
          padding: EdgeInsets.zero,
          children: [
            _ProfileContentSheet(
              child: CustomerPageBody(
                top: 16,
                bottom: 120,
                mobileHorizontal: 18,
                minViewportHeight: true,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (historyItems.isNotEmpty) ...[
                      _ProfileSectionTitle(label: l10n.profileSectionHistory),
                      _ProfileMenuGroup(children: historyItems),
                      const SizedBox(height: 24),
                    ],
                    if (rewardSettingItems.isNotEmpty) ...[
                      _ProfileSectionTitle(
                        label: l10n.profileSectionRewardSettings,
                      ),
                      _ProfileMenuGroup(children: rewardSettingItems),
                      const SizedBox(height: 24),
                    ],
                    _ProfileSectionTitle(label: l10n.profileSectionAbout),
                    _ProfileMenuGroup(children: aboutItems),
                    if (serviceItems.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _ProfileSectionTitle(label: l10n.profileSectionServices),
                      _ProfileMenuGroup(children: serviceItems),
                    ],
                    const SizedBox(height: 24),
                    _ProfileLogoutButton(
                      onPressed: () async {
                        await ref.read(authControllerProvider).logout();
                        if (context.mounted) context.go('/login');
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileHero extends StatelessWidget {
  const _ProfileHero({
    required this.profile,
    required this.affiliateTier,
    required this.onRetry,
  });

  final AsyncValue<CustomerProfileSettings> profile;
  final AffiliateTier? affiliateTier;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final horizontal = switch (viewportWidth) {
      >= 1280 => 40.0,
      >= 1024 => 32.0,
      >= 768 => 24.0,
      _ => 14.0,
    };
    final topPadding = topInset + 10 > 54 ? topInset + 10 : 54.0;
    return SizedBox.expand(
      child: CustomerBlueHeroBackdrop(
        primary: colorScheme.primary,
        secondary: colorScheme.secondary,
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, topPadding, horizontal, 0),
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: customerContentMaxWidthFor(context),
              ),
              child: SizedBox(
                width: double.infinity,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    profile.when(
                      data: (data) => _ProfileIdentityHeader(
                        profile: data,
                        affiliateTier: affiliateTier,
                      ),
                      loading: () => const _ProfileHeroLoading(),
                      error: (_, __) => _ProfileHeroError(onRetry: onRetry),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ProfileContentSheet extends StatelessWidget {
  const _ProfileContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('profile-content-sheet'),
      decoration: BoxDecoration(color: colorScheme.surface),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: child,
      ),
    );
  }
}

class _ProfileSectionTitle extends StatelessWidget {
  const _ProfileSectionTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 0, 0, 16),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
          fontSize: 16,
          fontWeight: FontWeight.w500,
          height: 1.25,
        ),
      ),
    );
  }
}

class _ProfileIdentityHeader extends StatefulWidget {
  const _ProfileIdentityHeader({
    required this.profile,
    required this.affiliateTier,
  });

  final CustomerProfileSettings profile;
  final AffiliateTier? affiliateTier;

  @override
  State<_ProfileIdentityHeader> createState() => _ProfileIdentityHeaderState();
}

class _ProfileIdentityHeaderState extends State<_ProfileIdentityHeader> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colorScheme.onPrimary,
          ),
          child: Icon(
            Icons.person,
            color: colorScheme.primary.withValues(alpha: 0.42),
            size: 32,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Text(
                      profile.name.trim().isEmpty
                          ? l10n.profileCustomerAccount
                          : profile.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            color: colorScheme.onPrimary,
                            fontSize: 24,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                    ),
                  ),
                  if (widget.affiliateTier case final tier?) ...[
                    const SizedBox(width: 8),
                    _ProfileAffiliateTierBadge(tier: tier),
                  ],
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      l10n.profileMemberCode(
                        profile.customerNo.isEmpty ? '-' : profile.customerNo,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: colorScheme.onPrimary.withValues(alpha: 0.92),
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (profile.customerNo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    SizedBox.square(
                      dimension: 30,
                      child: IconButton(
                        style:
                            IconButton.styleFrom(
                              backgroundColor: colorScheme.onPrimary.withValues(
                                alpha: 0.18,
                              ),
                              foregroundColor: colorScheme.onPrimary,
                              side: BorderSide(
                                color: colorScheme.onPrimary.withValues(
                                  alpha: 0.28,
                                ),
                              ),
                              padding: EdgeInsets.zero,
                            ).copyWith(
                              overlayColor: const WidgetStatePropertyAll(
                                Colors.transparent,
                              ),
                            ),
                        onPressed: _copyMemberCode,
                        tooltip: l10n.profileCopyMemberCode,
                        iconSize: 15,
                        icon: Icon(_copied ? Icons.check : Icons.copy),
                      ),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _copyMemberCode() async {
    await Clipboard.setData(ClipboardData(text: widget.profile.customerNo));
    if (!mounted) return;
    setState(() => _copied = true);
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}

class _ProfileAffiliateTierBadge extends StatelessWidget {
  const _ProfileAffiliateTierBadge({required this.tier});

  final AffiliateTier tier;

  @override
  Widget build(BuildContext context) {
    final normalizedCode = tier.code.trim().toLowerCase();
    final color = _profileAffiliateTierColor(context, normalizedCode);
    final label = tier.name.trim().isNotEmpty
        ? tier.name.trim()
        : _profileAffiliateTierFallbackLabel(normalizedCode);
    return Container(
      key: ValueKey('profile-affiliate-tier-$normalizedCode'),
      constraints: const BoxConstraints(maxWidth: 104),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 5),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Color _profileAffiliateTierColor(BuildContext context, String code) {
  return switch (code) {
    'bronze' => const Color(0xFFA85D33),
    'silver' => const Color(0xFF637383),
    'gold' => const Color(0xFF8A6200),
    'platinum' => const Color(0xFF526E82),
    'diamond' => const Color(0xFF087FF0),
    _ => Theme.of(context).colorScheme.primary,
  };
}

String _profileAffiliateTierFallbackLabel(String code) {
  if (code.isEmpty) return '-';
  return '${code[0].toUpperCase()}${code.substring(1)}';
}

class _ProfileHeroLoading extends StatelessWidget {
  const _ProfileHeroLoading();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        CustomerLoadingMark(
          width: 36,
          height: 22,
          color: colorScheme.onPrimary,
          trackColor: colorScheme.onPrimary.withValues(alpha: 0.24),
          semanticLabel: context.l10n.commonLoadingData,
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            context.l10n.profileLoading,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: colorScheme.onPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

class _ProfileHeroError extends StatelessWidget {
  const _ProfileHeroError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(
          Icons.error_outline_rounded,
          color: colorScheme.onPrimary,
          size: 30,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.profileLoadFailed,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                l10n.profileRefreshAgain,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: colorScheme.onPrimary.withValues(alpha: 0.88),
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onRetry,
          tooltip: l10n.commonRetry,
          color: colorScheme.onPrimary,
          style: IconButton.styleFrom(
            minimumSize: const Size.square(42),
            maximumSize: const Size.square(42),
            side: BorderSide(
              color: colorScheme.onPrimary.withValues(alpha: 0.42),
            ),
          ),
          icon: const Icon(Icons.refresh_rounded, size: 22),
        ),
      ],
    );
  }
}

class _ProfileMenuGroup extends StatelessWidget {
  const _ProfileMenuGroup({required this.children});

  final List<_ProfileMenuItem> children;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.surface),
      child: Column(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            Divider(
              height: 1,
              color: colorScheme.outlineVariant.withValues(alpha: 0.78),
            ),
          ],
        ],
      ),
    );
  }
}

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.title,
    required this.path,
    this.badge,
    this.enabled = true,
    this.loading = false,
    this.onTap,
  });

  final String title;
  final String path;
  final String? badge;
  final bool enabled;
  final bool loading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final badgeText = badge?.trim() ?? '';
    final targetPath = path.trim();
    final action =
        onTap ?? (targetPath.isEmpty ? null : () => context.go(targetPath));
    final canActivate = enabled && action != null;
    final colorScheme = Theme.of(context).colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        height: 1.25,
                      ),
                    ),
                  ),
                  if (badgeText.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    _ProfileMenuBadge(label: badgeText),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            if (loading)
              CustomerLoadingMark(
                width: 24,
                height: 18,
                color: colorScheme.primary,
                trackColor: colorScheme.primary.withValues(alpha: 0.18),
              )
            else
              Icon(
                Icons.chevron_right,
                size: 30,
                color: canActivate
                    ? colorScheme.onSurfaceVariant
                    : colorScheme.onSurfaceVariant.withValues(alpha: 0.42),
              ),
          ],
        ),
      ),
    );

    if (!canActivate) return row;

    return Semantics(
      button: true,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: action,
          child: row,
        ),
      ),
    );
  }
}

class _ProfileLogoutButton extends StatelessWidget {
  const _ProfileLogoutButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: _profileFlatButtonStyle(
        OutlinedButton.styleFrom(
          minimumSize: const Size.fromHeight(52),
          foregroundColor: colorScheme.error,
          side: BorderSide(color: colorScheme.error.withValues(alpha: 0.32)),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
      ),
      icon: const Icon(Icons.logout),
      label: Text(context.l10n.profileLogout),
    );
  }
}

ButtonStyle _profileFlatButtonStyle(ButtonStyle style) {
  return style.copyWith(
    overlayColor: const WidgetStatePropertyAll(Colors.transparent),
  );
}

class _ProfileMenuBadge extends StatelessWidget {
  const _ProfileMenuBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(
          colorScheme.primaryContainer,
          colorScheme.surface,
          0.16,
        ),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: colorScheme.primary,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
        ),
      ),
    );
  }
}
