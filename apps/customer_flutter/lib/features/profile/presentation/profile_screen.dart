import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_locale_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

Color _profilePrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _profileSoftSurface(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.08) ??
    colorScheme.surface;

Color _profileSoftOutline(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.outlineVariant, colorScheme.primary, 0.16) ??
    colorScheme.outlineVariant;

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileSettingsProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final l10n = context.l10n;
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
          title: l10n.customerRouteTitle('reward_claims'),
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
          title: l10n.profileRewardBank,
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
        ),
      if (routeEnabled('/profile/biometrics'))
        _ProfileMenuItem(
          title: l10n.profileBiometrics,
          path: '/profile/biometrics',
        ),
    ];
    final aboutItems = [
      if (routeEnabled('/news'))
        _ProfileMenuItem(
          title: l10n.profileNewsAll,
          path: '/news',
        ),
      _ProfileMenuItem(
        title: l10n.profileTerms,
        path: '/terms',
      ),
      _ProfileMenuItem(
        title: l10n.customerRouteTitle('lottery_knowledge'),
        path: '/lottery-knowledge',
      ),
      _ProfileMenuItem(
        title: l10n.profileHowToContact,
        path: '',
      ),
      _ProfileMenuItem(
        title: l10n.profilePrivacyPolicy,
        path: '/privacy',
      ),
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
      actions: [
        IconButton(
          onPressed: () => ref.invalidate(customerProfileSettingsProvider),
          icon: const Icon(Icons.refresh),
          tooltip: l10n.profileRefreshTooltip,
        ),
      ],
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(customerProfileSettingsProvider),
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _ProfileHero(
              profile: profile,
              onRetry: () => ref.invalidate(customerProfileSettingsProvider),
            ),
            _ProfileContentSheet(
              child: CustomerPageBody(
                top: 24,
                bottom: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _ProfileLanguageCard(),
                    const SizedBox(height: 10),
                    if (historyItems.isNotEmpty) ...[
                      _ProfileSectionTitle(label: l10n.profileSectionHistory),
                      _ProfileMenuGroup(children: historyItems),
                      const SizedBox(height: 8),
                    ],
                    if (rewardSettingItems.isNotEmpty) ...[
                      _ProfileSectionTitle(
                        label: l10n.profileSectionRewardSettings,
                      ),
                      _ProfileMenuGroup(children: rewardSettingItems),
                      const SizedBox(height: 8),
                    ],
                    _ProfileSectionTitle(label: l10n.profileSectionAbout),
                    _ProfileMenuGroup(children: aboutItems),
                    const SizedBox(height: 16),
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
    required this.onRetry,
  });

  final AsyncValue<CustomerProfileSettings> profile;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 720 ? 28.0 : 18.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 38, horizontal, 34),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 132),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: profile.when(
                      data: (data) => _ProfileIdentityHeader(profile: data),
                      loading: () => const _ProfileHeroLoading(),
                      error: (_, __) => _ProfileHeroError(onRetry: onRetry),
                    ),
                  ),
                ),
              ),
            ),
          );
        },
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
      decoration: BoxDecoration(color: colorScheme.primary),
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

class _ProfileLanguageCard extends ConsumerStatefulWidget {
  const _ProfileLanguageCard();

  @override
  ConsumerState<_ProfileLanguageCard> createState() =>
      _ProfileLanguageCardState();
}

class _ProfileLanguageCardState extends ConsumerState<_ProfileLanguageCard> {
  bool _saving = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeLocale = ref.watch(customerLocaleProvider);
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _profileSoftSurface(colorScheme),
        border: Border.all(color: _profileSoftOutline(colorScheme)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final narrow = constraints.maxWidth < 360;
                final copy = Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.profileLanguageTitle,
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: colorScheme.onSurface,
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      l10n.profileLanguageSubtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                    ),
                  ],
                );
                final switcher = _LanguageSegmentedControl(
                  activeLocale: activeLocale,
                  saving: _saving,
                  onSelected: _setLocale,
                );

                if (narrow) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      copy,
                      const SizedBox(height: 14),
                      switcher,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: copy),
                    const SizedBox(width: 16),
                    switcher,
                  ],
                );
              },
            ),
            if (_errorMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProfileInlineNotice(message: _errorMessage),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _setLocale(Locale locale) async {
    final tag = localeTag(locale);
    if (_saving || localeTag(ref.read(customerLocaleProvider)) == tag) return;

    setCustomerLocale(ref, locale);
    setState(() {
      _saving = true;
      _errorMessage = '';
    });
    try {
      await ref
          .read(profileSettingsRepositoryProvider)
          .savePreferredLocale(tag);
      ref.invalidate(customerProfileSettingsProvider);
    } catch (_) {
      if (mounted) {
        setState(() {
          _errorMessage = context.l10n.profileLanguageSaveFailed;
        });
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _ProfileInlineNotice extends StatelessWidget {
  const _ProfileInlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
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

class _LanguageSegmentedControl extends StatelessWidget {
  const _LanguageSegmentedControl({
    required this.activeLocale,
    required this.saving,
    required this.onSelected,
  });

  final Locale activeLocale;
  final bool saving;
  final ValueChanged<Locale> onSelected;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Semantics(
      label: l10n.commonLanguage,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer.withAlpha(110),
          borderRadius: BorderRadius.circular(999),
        ),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _LanguageButton(
                label: l10n.commonThai,
                active: localeTag(activeLocale) == 'th-TH',
                enabled: !saving,
                onPressed: () => onSelected(const Locale('th', 'TH')),
              ),
              _LanguageButton(
                label: l10n.commonEnglish,
                active: localeTag(activeLocale) == 'en-US',
                enabled: !saving,
                onPressed: () => onSelected(const Locale('en', 'US')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LanguageButton extends StatelessWidget {
  const _LanguageButton({
    required this.label,
    required this.active,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool active;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
      child: TextButton(
        onPressed: enabled ? onPressed : null,
        style: TextButton.styleFrom(
          backgroundColor: active
              ? Theme.of(context).colorScheme.primary
              : Colors.transparent,
          foregroundColor: active
              ? Theme.of(context).colorScheme.onPrimary
              : Theme.of(context).colorScheme.primary,
          disabledForegroundColor:
              Theme.of(context).colorScheme.onSurfaceVariant,
          minimumSize: const Size(72, 36),
          shape: const StadiumBorder(),
          textStyle: const TextStyle(fontWeight: FontWeight.w900),
        ),
        child: Text(label),
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
      padding: const EdgeInsets.fromLTRB(0, 8, 0, 12),
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
  const _ProfileIdentityHeader({required this.profile});

  final CustomerProfileSettings profile;

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
          width: 66,
          height: 66,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _profilePrimaryTint(colorScheme),
          ),
          child: Icon(
            Icons.person,
            color: colorScheme.primary.withValues(alpha: 0.42),
            size: 36,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                profile.name.trim().isEmpty
                    ? l10n.profileCustomerAccount
                    : profile.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: colorScheme.onPrimary,
                      fontWeight: FontWeight.w900,
                      height: 1.18,
                    ),
              ),
              const SizedBox(height: 8),
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
                            color:
                                colorScheme.onPrimary.withValues(alpha: 0.92),
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
                        style: IconButton.styleFrom(
                          backgroundColor:
                              colorScheme.onPrimary.withValues(alpha: 0.18),
                          foregroundColor: colorScheme.onPrimary,
                          side: BorderSide(
                            color:
                                colorScheme.onPrimary.withValues(alpha: 0.28),
                          ),
                          padding: EdgeInsets.zero,
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.profileLoadFailed,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.profileRefreshAgain,
          style: TextStyle(
            color: colorScheme.onPrimary.withValues(alpha: 0.88),
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onRetry,
          style: OutlinedButton.styleFrom(
            foregroundColor: colorScheme.onPrimary,
            side: BorderSide(
              color: colorScheme.onPrimary.withValues(alpha: 0.42),
            ),
          ),
          icon: const Icon(Icons.refresh),
          label: Text(l10n.commonRetry),
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
            if (index < children.length - 1)
              Divider(height: 1, color: colorScheme.outlineVariant),
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
  });

  final String title;
  final String path;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final badgeText = badge?.trim() ?? '';
    final targetPath = path.trim();
    final enabled = targetPath.isNotEmpty;
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: enabled ? () => context.go(targetPath) : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 72),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: enabled
                              ? colorScheme.onSurface
                              : colorScheme.onSurfaceVariant,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                  ),
                ),
                if (badgeText.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Flexible(child: _ProfileMenuBadge(label: badgeText)),
                ],
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right,
                  size: 30,
                  color: colorScheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
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
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(52),
        foregroundColor: colorScheme.error,
        side: BorderSide(color: colorScheme.error.withValues(alpha: 0.32)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        textStyle: const TextStyle(fontWeight: FontWeight.w900),
      ),
      icon: const Icon(Icons.logout),
      label: Text(context.l10n.profileLogout),
    );
  }
}

class _ProfileMenuBadge extends StatelessWidget {
  const _ProfileMenuBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _profilePrimaryTint(colorScheme),
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
