import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/activities/data/activity_models.dart';
import '../../../features/activities/data/activity_repository.dart';
import '../../../features/activities/presentation/activity_localization.dart';
import '../../../features/news/data/news_models.dart';
import '../../../features/news/data/news_repository.dart';
import '../../../features/wallet/data/wallet_models.dart';
import '../../../features/wallet/data/wallet_repository.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final wallet = auth.isAuthenticated
        ? ref.watch(walletSummaryProvider)
        : const AsyncValue.data(WalletSummary(wallets: [], ledger: []));
    final activities = ref.watch(activityListProvider);
    final news = ref.watch(newsListProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.homeTitle,
      currentPath: '/',
      sensitive: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: wallet,
            data: (summary) => _WalletSummaryCard(balance: summary.balance),
            empty: const _WalletSummaryCard(balance: 0),
          ),
          const SizedBox(height: 16),
          const _HomeActionGrid(),
          const SizedBox(height: 16),
          _ActivitiesRail(value: activities),
          const SizedBox(height: 16),
          _FeatureLinkCard(
            icon: Icons.confirmation_number_outlined,
            title: l10n.homeBuyLotteryTitle,
            subtitle: l10n.homeBuyLotterySubtitle,
            path: '/buy',
          ),
          _FeatureLinkCard(
            icon: Icons.emoji_events_outlined,
            title: l10n.homeResultsTitle,
            subtitle: l10n.homeResultsSubtitle,
            path: '/result',
          ),
          _NewsRail(value: news),
          _FeatureLinkCard(
            icon: Icons.campaign_outlined,
            title: l10n.homeNewsTitle,
            subtitle: l10n.homeNewsSubtitle,
            path: '/news',
          ),
        ],
      ),
    );
  }
}

class _WalletSummaryCard extends StatelessWidget {
  const _WalletSummaryCard({required this.balance});

  final double balance;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.go('/my-wallet'),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.account_balance_wallet_outlined,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    context.l10n.commonWalletBalance,
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                formatBaht(balance),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActivitiesRail extends StatelessWidget {
  const _ActivitiesRail({required this.value});

  final AsyncValue<List<ActivityItem>> value;

  @override
  Widget build(BuildContext context) {
    return value.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SectionHeading(
              title: context.l10n.homeActivities,
              actionLabel: context.l10n.commonViewAll,
              onAction: () => context.go('/activities'),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 154,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: items.length.clamp(0, 8),
                separatorBuilder: (_, __) => const SizedBox(width: 12),
                itemBuilder: (context, index) {
                  final activity = items[index];
                  return _ActivityCard(activity: activity);
                },
              ),
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: 260,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: activity.slug.isEmpty
              ? null
              : () => context.go('/activities/${activity.slug}'),
          child: Row(
            children: [
              Container(
                width: 96,
                color: Theme.of(context).colorScheme.primaryContainer,
                child: activity.imageUrl.isEmpty
                    ? Icon(
                        Icons.stars_rounded,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      )
                    : Image.network(activity.imageUrl, fit: BoxFit.cover),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        l10n.activityTypeLabel(activity.type),
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        activityDisplayName(l10n, activity),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        activityMetaText(l10n, activity),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.labelSmall,
                      ),
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

class _NewsRail extends StatelessWidget {
  const _NewsRail({required this.value});

  final AsyncValue<List<NewsItem>> value;

  @override
  Widget build(BuildContext context) {
    return value.maybeWhen(
      data: (items) {
        if (items.isEmpty) return const SizedBox.shrink();
        final l10n = context.l10n;
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionHeading(
                title: l10n.homeNews,
                actionLabel: l10n.commonViewAll,
                onAction: () => context.go('/news'),
              ),
              const SizedBox(height: 10),
              for (final item in items.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Card(
                    child: ListTile(
                      leading: const Icon(Icons.campaign_outlined),
                      title: Text(
                        item.title.isEmpty
                            ? l10n.newsFallbackTitle
                            : item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(
                        formatLocalizedDateTime(
                          item.publishedAt,
                          localeTag(l10n.locale),
                        ),
                        maxLines: 1,
                      ),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: item.slug.isEmpty
                          ? null
                          : () => context.go('/news/${item.slug}'),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
        ),
        TextButton(onPressed: onAction, child: Text(actionLabel)),
      ],
    );
  }
}

class _HomeActionGrid extends StatelessWidget {
  const _HomeActionGrid();

  static const _actions = [
    _HomeAction(label: _HomeActionLabel.topup, icon: Icons.add, path: '/topup'),
    _HomeAction(
      label: _HomeActionLabel.tickets,
      icon: Icons.confirmation_number_outlined,
      path: '/tickets',
    ),
    _HomeAction(
      label: _HomeActionLabel.claim,
      icon: Icons.payments_outlined,
      path: '/reward-claims',
    ),
    _HomeAction(
      label: _HomeActionLabel.history,
      icon: Icons.history,
      path: '/my-wallet',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            for (final action in _actions)
              Expanded(
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () => context.go(action.path),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircleAvatar(child: Icon(action.icon)),
                        const SizedBox(height: 8),
                        Text(
                          action.labelText(l10n),
                          style: Theme.of(context).textTheme.labelMedium,
                          textAlign: TextAlign.center,
                        ),
                      ],
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

class _FeatureLinkCard extends StatelessWidget {
  const _FeatureLinkCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.path,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String path;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Card(
        child: ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.go(path),
        ),
      ),
    );
  }
}

enum _HomeActionLabel { topup, tickets, claim, history }

class _HomeAction {
  const _HomeAction({
    required this.label,
    required this.icon,
    required this.path,
  });

  final _HomeActionLabel label;
  final IconData icon;
  final String path;

  String labelText(CustomerLocalizations l10n) {
    return switch (label) {
      _HomeActionLabel.topup => l10n.homeActionTopup,
      _HomeActionLabel.tickets => l10n.homeActionTickets,
      _HomeActionLabel.claim => l10n.homeActionClaim,
      _HomeActionLabel.history => l10n.homeActionHistory,
    };
  }
}
