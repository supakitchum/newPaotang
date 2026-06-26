import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_locale_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(customerProfileSettingsProvider);
    final l10n = context.l10n;

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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          profile.when(
            data: (data) => _ProfileIdentityCard(profile: data),
            loading: () => const _ProfileLoadingCard(),
            error: (_, __) => _ProfileErrorCard(
              onRetry: () => ref.invalidate(customerProfileSettingsProvider),
            ),
          ),
          const SizedBox(height: 12),
          const _ProfileLanguageCard(),
          const SizedBox(height: 12),
          _ProfileSectionTitle(label: l10n.profileSectionHistory),
          _ProfileMenuItem(
            icon: Icons.account_balance_wallet_outlined,
            title: l10n.customerRouteTitle('my_wallet'),
            path: '/my-wallet',
          ),
          _ProfileMenuItem(
            icon: Icons.receipt_long_outlined,
            title: l10n.profilePurchaseHistory,
            path: '/purchase-history',
          ),
          _ProfileMenuItem(
            icon: Icons.emoji_events_outlined,
            title: l10n.customerRouteTitle('reward_claims'),
            path: '/reward-claims',
          ),
          _ProfileMenuItem(
            icon: Icons.card_giftcard_outlined,
            title: l10n.customerRouteTitle('activity_claims'),
            path: '/activity-claims',
          ),
          _ProfileMenuItem(
            icon: Icons.local_activity_outlined,
            title: l10n.customerRouteTitle('activities'),
            path: '/activities',
            badge: l10n.profileBadgeNew,
          ),
          _ProfileMenuItem(
            icon: Icons.handshake_outlined,
            title: l10n.customerRouteTitle('affiliate'),
            path: '/affiliate',
          ),
          const SizedBox(height: 8),
          _ProfileSectionTitle(label: l10n.profileSectionRewardSettings),
          _ProfileMenuItem(
            icon: Icons.account_balance_outlined,
            title: l10n.profileRewardBank,
            path: '/profile/reward-bank',
          ),
          _ProfileMenuItem(
            icon: Icons.auto_awesome_outlined,
            title: l10n.profileAutoReward,
            path: '/profile/auto-reward',
            badge: l10n.profileBadgeRecommended,
          ),
          _ProfileMenuItem(
            icon: Icons.notifications_active_outlined,
            title: l10n.profileLineNotifications,
            path: '/profile/line-notifications',
          ),
          _ProfileMenuItem(
            icon: Icons.face_retouching_natural,
            title: l10n.profileBiometrics,
            path: '/profile/biometrics',
          ),
          const SizedBox(height: 8),
          _ProfileSectionTitle(label: l10n.profileSectionAbout),
          _ProfileMenuItem(
            icon: Icons.campaign_outlined,
            title: l10n.profileNewsAll,
            path: '/news',
          ),
          _ProfileMenuItem(
            icon: Icons.description_outlined,
            title: l10n.profileTerms,
            path: '/terms',
          ),
          _ProfileMenuItem(
            icon: Icons.school_outlined,
            title: l10n.customerRouteTitle('lottery_knowledge'),
            path: '/lottery-knowledge',
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: () async {
              await ref.read(authControllerProvider).logout();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
            label: Text(l10n.profileLogout),
          ),
        ],
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

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeLocale = ref.watch(customerLocaleProvider);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 360;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.profileLanguageTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  l10n.profileLanguageSubtitle,
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
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
      ),
    );
  }

  Future<void> _setLocale(Locale locale) async {
    final tag = localeTag(locale);
    if (_saving || localeTag(ref.read(customerLocaleProvider)) == tag) return;

    setCustomerLocale(ref, locale);
    setState(() => _saving = true);
    try {
      await ref
          .read(profileSettingsRepositoryProvider)
          .savePreferredLocale(tag);
      ref.invalidate(customerProfileSettingsProvider);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.profileLanguageSaveFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
          foregroundColor:
              active ? Colors.white : Theme.of(context).colorScheme.primary,
          disabledForegroundColor: Colors.grey.shade500,
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
      padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
      child: Text(
        label,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Colors.grey.shade700,
              fontWeight: FontWeight.w900,
            ),
      ),
    );
  }
}

class _ProfileIdentityCard extends StatefulWidget {
  const _ProfileIdentityCard({required this.profile});

  final CustomerProfileSettings profile;

  @override
  State<_ProfileIdentityCard> createState() => _ProfileIdentityCardState();
}

class _ProfileIdentityCardState extends State<_ProfileIdentityCard> {
  bool _copied = false;

  @override
  Widget build(BuildContext context) {
    final profile = widget.profile;
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CircleAvatar(
              radius: 32,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Icons.person_outline,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    profile.name.trim().isEmpty
                        ? l10n.profileCustomerAccount
                        : profile.name,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _ProfileInfoChip(
                        icon: Icons.badge_outlined,
                        label: l10n.profileMemberCode(
                          profile.customerNo.isEmpty ? '-' : profile.customerNo,
                        ),
                      ),
                      if (profile.phone.isNotEmpty)
                        _ProfileInfoChip(
                          icon: Icons.phone_android_outlined,
                          label: profile.phone,
                        ),
                    ],
                  ),
                ],
              ),
            ),
            if (profile.customerNo.isNotEmpty) ...[
              const SizedBox(width: 8),
              IconButton.filledTonal(
                onPressed: _copyMemberCode,
                tooltip: l10n.profileCopyMemberCode,
                icon: Icon(_copied ? Icons.check : Icons.copy),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _copyMemberCode() async {
    await Clipboard.setData(ClipboardData(text: widget.profile.customerNo));
    if (!mounted) return;
    setState(() => _copied = true);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(context.l10n.profileCopiedMemberCode)),
    );
    Future<void>.delayed(const Duration(milliseconds: 1600), () {
      if (mounted) setState(() => _copied = false);
    });
  }
}

class _ProfileInfoChip extends StatelessWidget {
  const _ProfileInfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16),
          const SizedBox(width: 6),
          Text(label, style: Theme.of(context).textTheme.labelMedium),
        ],
      ),
    );
  }
}

class _ProfileLoadingCard extends StatelessWidget {
  const _ProfileLoadingCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Row(
          children: [
            const CircularProgressIndicator(),
            const SizedBox(width: 14),
            Expanded(child: Text(context.l10n.profileLoading)),
          ],
        ),
      ),
    );
  }
}

class _ProfileErrorCard extends StatelessWidget {
  const _ProfileErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.profileLoadFailed,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 6),
            Text(context.l10n.profileRefreshAgain),
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

class _ProfileMenuItem extends StatelessWidget {
  const _ProfileMenuItem({
    required this.icon,
    required this.title,
    required this.path,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String path;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Row(
            children: [
              Expanded(child: Text(title)),
              if (badge != null && badge!.trim().isNotEmpty) ...[
                const SizedBox(width: 8),
                _ProfileMenuBadge(label: badge!.trim()),
              ],
            ],
          ),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(path),
        ),
      ),
    );
  }
}

class _ProfileMenuBadge extends StatelessWidget {
  const _ProfileMenuBadge({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: Theme.of(context).colorScheme.primary,
                fontWeight: FontWeight.w900,
              ),
        ),
      ),
    );
  }
}
