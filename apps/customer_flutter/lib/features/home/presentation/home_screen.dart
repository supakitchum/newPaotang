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
import '../../../features/lottery/presentation/lottery_digit_input_row.dart';
import '../../../features/lottery/presentation/lottery_navigation.dart';
import '../../../features/news/data/news_models.dart';
import '../../../features/news/data/news_repository.dart';
import '../../../features/news/presentation/news_card.dart';
import '../../../features/results/data/result_models.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../features/results/presentation/result_widgets.dart';
import '../../../features/wallet/data/wallet_repository.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_section_header.dart';
import '../../../shared/widgets/customer_wallet_card.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final wallet =
        auth.isAuthenticated ? ref.watch(walletSummaryProvider) : null;
    final activities = ref.watch(activityListProvider);
    final news = ref.watch(newsListProvider);
    final result = ref.watch(currentResultProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.homeTitle,
      currentPath: '/',
      sensitive: true,
      child: _HomePageList(
        children: [
          _HomeLotteryHero(value: result),
          const SizedBox(height: 16),
          const _HomeQuickActionPanel(),
          const SizedBox(height: 16),
          if (wallet == null) ...[
            const _HomeGuestPanel(),
          ] else ...[
            AsyncStateView(
              value: wallet,
              data: (summary) => CustomerWalletBalanceCard(
                balance: summary.balance,
                title: l10n.commonWalletBalance,
                onOpenWallet: () => context.go('/my-wallet'),
                actions: _walletCardActions(context),
              ),
              empty: CustomerWalletBalanceCard(
                balance: 0,
                title: l10n.commonWalletBalance,
                onOpenWallet: () => context.go('/my-wallet'),
                actions: _walletCardActions(context),
              ),
            ),
          ],
          const SizedBox(height: 18),
          _ActivitiesRail(value: activities),
          const SizedBox(height: 18),
          _HomeResultSection(value: result),
          _NewsRail(value: news),
        ],
      ),
    );
  }
}

class _HomePageList extends StatelessWidget {
  const _HomePageList({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      children: [
        CustomerPageBody(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: children,
          ),
        ),
      ],
    );
  }
}

class _HomeLotteryHero extends StatefulWidget {
  const _HomeLotteryHero({required this.value});

  final AsyncValue<RewardResultBundle> value;

  @override
  State<_HomeLotteryHero> createState() => _HomeLotteryHeroState();
}

class _HomeLotteryHeroState extends State<_HomeLotteryHero> {
  final _digits = List.generate(6, (_) => TextEditingController());

  @override
  void dispose() {
    for (final controller in _digits) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final currentGame = widget.value.maybeWhen(
      data: (bundle) => bundle.currentGame,
      orElse: () => null,
    );
    final drawText = _drawText(context, currentGame);

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.48) ??
                colorScheme.primary,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.20),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: Stack(
          children: [
            Positioned(
              right: -28,
              bottom: -36,
              child: Container(
                width: 124,
                height: 124,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFFFD629).withValues(alpha: 0.88),
                ),
              ),
            ),
            Positioned(
              left: -54,
              top: -28,
              child: Transform.rotate(
                angle: -0.55,
                child: Container(
                  width: 260,
                  height: 92,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.07),
                    borderRadius: BorderRadius.circular(50),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 22),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final compact = constraints.maxWidth < 430;
                      final copy = Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.lotteryBuyTitle,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            l10n.lotterySearchHeroTitle,
                            style: theme.textTheme.titleMedium?.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            drawText,
                            maxLines: compact ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelLarge?.copyWith(
                              color: Colors.white.withValues(alpha: 0.90),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      );
                      final action = FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: colorScheme.primary,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: _goSearch,
                        icon: const Icon(Icons.search, size: 18),
                        label: Text(l10n.lotterySearchButton),
                      );

                      if (compact) {
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            copy,
                            const SizedBox(height: 12),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: action,
                            ),
                          ],
                        );
                      }

                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(child: copy),
                          const SizedBox(width: 12),
                          action,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 22),
                  LotteryDigitInputRow(
                    controllers: _digits,
                    onSubmitted: _goSearch,
                    style: LotteryDigitInputStyle(
                      borderRadius: 12,
                      spacing: 8,
                      fillColor: Colors.white,
                      hintColor: colorScheme.onSurface.withValues(alpha: 0.20),
                      focusedBorderColor: const Color(0xFFFFD629),
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

  String _drawText(BuildContext context, CurrentGame? game) {
    final l10n = context.l10n;
    if (game == null) return l10n.countdownCurrentDrawFallback;

    final parsed = parseDateTime(game.drawAt);
    if (parsed != null) {
      return l10n.resultDrawDate(
        formatLocalizedDateTime(parsed, localeTag(l10n.locale)),
      );
    }

    if (game.name.trim().isNotEmpty) return game.name.trim();
    return l10n.countdownCurrentDrawFallback;
  }

  void _goSearch() {
    context.go(
      lotterySearchPath(
        digits: _digits.map((controller) => controller.text).toList(),
      ),
    );
  }
}

class _HomeQuickActionPanel extends StatelessWidget {
  const _HomeQuickActionPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.phone_iphone,
                label: l10n.homeBuyLotteryTitle,
                path: '/buy',
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _HomeQuickAction(
                icon: Icons.qr_code_scanner,
                label: l10n.homeScanLotteryTitle,
                path: '/stores',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeQuickAction extends StatelessWidget {
  const _HomeQuickAction({
    required this.icon,
    required this.label,
    required this.path,
  });

  final IconData icon;
  final String label;
  final String path;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => context.go(path),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 28,
              child: Icon(icon),
            ),
            const SizedBox(height: 10),
            Text(
              label,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeGuestPanel extends StatelessWidget {
  const _HomeGuestPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 390;
            final copy = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.homeGuestTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 6),
                Text(
                  l10n.homeGuestSubtitle,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            );
            final actions = Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: compact ? WrapAlignment.start : WrapAlignment.end,
              children: [
                FilledButton(
                  onPressed: () => context.go('/login'),
                  child: Text(l10n.loginTitle),
                ),
                OutlinedButton(
                  onPressed: () => context.go('/register'),
                  child: Text(l10n.registerTitle),
                ),
              ],
            );

            if (compact) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  copy,
                  const SizedBox(height: 14),
                  actions,
                ],
              );
            }

            return Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(child: copy),
                const SizedBox(width: 14),
                actions,
              ],
            );
          },
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
            CustomerSectionHeader(
              title: context.l10n.homeActivities,
              actionLabel: context.l10n.commonViewAll,
              onAction: () => context.go('/activities'),
            ),
            const SizedBox(height: 10),
            LayoutBuilder(
              builder: (context, constraints) {
                final cardWidth = _activityCardWidth(constraints.maxWidth);
                return SizedBox(
                  height: constraints.maxWidth < 380 ? 148 : 158,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    primary: false,
                    padding: EdgeInsets.zero,
                    itemCount: items.length.clamp(0, 8),
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final activity = items[index];
                      return _ActivityCard(
                        activity: activity,
                        width: cardWidth,
                      );
                    },
                  ),
                );
              },
            ),
          ],
        );
      },
      orElse: () => const SizedBox.shrink(),
    );
  }

  double _activityCardWidth(double availableWidth) {
    if (availableWidth < 380) {
      return (availableWidth * 0.88).clamp(248.0, 310.0).toDouble();
    }
    if (availableWidth < 720) return 300;
    return ((availableWidth - 24) / 3).clamp(268.0, 320.0).toDouble();
  }
}

class _ActivityCard extends StatelessWidget {
  const _ActivityCard({required this.activity, required this.width});

  final ActivityItem activity;
  final double width;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SizedBox(
      width: width,
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: activity.slug.isEmpty
              ? null
              : () => context.go('/activities/${activity.slug}'),
          child: Row(
            children: [
              Container(
                width: width < 280 ? 92 : 106,
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

class _HomeResultSection extends StatelessWidget {
  const _HomeResultSection({required this.value});

  final AsyncValue<RewardResultBundle> value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: value.when(
        loading: () => Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Row(
              children: [
                const SizedBox.square(
                  dimension: 22,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                const SizedBox(width: 12),
                Expanded(child: Text(context.l10n.resultLoading)),
              ],
            ),
          ),
        ),
        error: (_, __) => _FeatureLinkCard(
          icon: Icons.emoji_events_outlined,
          title: context.l10n.homeResultsTitle,
          subtitle: context.l10n.homeResultsSubtitle,
          path: '/result',
        ),
        data: (bundle) {
          final selected = bundle.selectedResult;
          if (selected == null) {
            return _FeatureLinkCard(
              icon: Icons.emoji_events_outlined,
              title: context.l10n.homeResultsTitle,
              subtitle: context.l10n.homeResultsSubtitle,
              path: '/result',
            );
          }

          return ResultSummaryCard(
            result: selected,
            link: selected.id.isEmpty
                ? '/result/full'
                : '/result/full?game_id=${selected.id}',
          );
        },
      ),
    );
  }
}

class _NewsRail extends StatelessWidget {
  const _NewsRail({required this.value});

  final AsyncValue<List<NewsItem>> value;

  @override
  Widget build(BuildContext context) {
    return value.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => _FeatureLinkCard(
        icon: Icons.campaign_outlined,
        title: context.l10n.homeNewsTitle,
        subtitle: context.l10n.homeNewsSubtitle,
        path: '/news',
      ),
      data: (items) {
        final l10n = context.l10n;
        if (items.isEmpty) {
          return _FeatureLinkCard(
            icon: Icons.campaign_outlined,
            title: l10n.homeNewsTitle,
            subtitle: l10n.homeNewsSubtitle,
            path: '/news',
          );
        }
        return Padding(
          padding: const EdgeInsets.only(top: 4, bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CustomerSectionHeader(
                title: l10n.homeNews,
                actionLabel: l10n.commonViewAll,
                onAction: () => context.go('/news'),
              ),
              const SizedBox(height: 10),
              for (final item in items.take(3))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: NewsSideCard(
                    item: item,
                    imageWidth: 96,
                    imageHeight: 118,
                    showCategory: false,
                  ),
                ),
            ],
          ),
        );
      },
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

List<CustomerWalletCardAction> _walletCardActions(BuildContext context) {
  final l10n = context.l10n;
  return [
    CustomerWalletCardAction(
      icon: Icons.add,
      label: l10n.homeActionTopup,
      onTap: () => context.go('/topup'),
    ),
    CustomerWalletCardAction(
      icon: Icons.confirmation_number_outlined,
      label: l10n.homeActionTickets,
      onTap: () => context.go('/tickets'),
    ),
    CustomerWalletCardAction(
      icon: Icons.payments_outlined,
      label: l10n.homeActionClaim,
      onTap: () => context.go('/reward-claims'),
    ),
    CustomerWalletCardAction(
      icon: Icons.history,
      label: l10n.homeActionHistory,
      onTap: () => context.go('/my-wallet'),
    ),
  ];
}
