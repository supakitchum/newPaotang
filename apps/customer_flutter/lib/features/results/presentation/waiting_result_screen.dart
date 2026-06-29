import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/result_models.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

class WaitingResultScreen extends ConsumerWidget {
  const WaitingResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(currentResultProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final l10n = context.l10n;
    final live = bootstrap?.live;

    return AppShell(
      title: l10n.waitingResultTitle,
      currentPath: '/tickets',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(currentResultProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ResultPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _WaitingResultStatusCard(result: result),
                  const SizedBox(height: 12),
                  AsyncStateView(
                    value: result,
                    loadingText: l10n.resultLoading,
                    data: (bundle) {
                      final selected = bundle.selectedResult;
                      if (selected == null) {
                        return const _WaitingResultPlaceholder();
                      }
                      return ResultSummaryCard(
                        result: selected,
                        featured: true,
                        link: '/result/full',
                      );
                    },
                    empty: const _WaitingResultPlaceholder(),
                  ),
                  const SizedBox(height: 12),
                  _WaitingResultLiveCard(live: live),
                  const SizedBox(height: 12),
                  _WaitingResultActions(
                    onTickets: () => context.go('/tickets'),
                    onResult: () => context.go('/result'),
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

class _WaitingResultStatusCard extends StatelessWidget {
  const _WaitingResultStatusCard({required this.result});

  final AsyncValue<RewardResultBundle> result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Card(
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.hourglass_bottom,
                color: colorScheme.onPrimaryContainer,
                size: 34,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              l10n.waitingResultSaleClosed,
              style: theme.textTheme.labelLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            AsyncStateView(
              value: result,
              loadingText: l10n.resultLoading,
              data: (bundle) {
                final selected = bundle.selectedResult;
                final title = selected?.hasResolvedResult == true
                    ? l10n.waitingResultResolved
                    : l10n.waitingResultPending;
                return Text(
                  title,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
                  textAlign: TextAlign.center,
                );
              },
              empty: Text(
                l10n.waitingResultPending,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaitingResultPlaceholder extends StatelessWidget {
  const _WaitingResultPlaceholder();

  @override
  Widget build(BuildContext context) {
    return ResultSummaryCard(
      result: RewardResultGame(
        id: '',
        name: context.l10n.resultPendingDrawDate,
        status: '',
        resultStatus: '',
        officialStatus: '',
        completionPercent: 0,
        drawAt: null,
        rewards: const [],
      ),
      featured: true,
      link: '/result/full',
    );
  }
}

class _WaitingResultLiveCard extends ConsumerWidget {
  const _WaitingResultLiveCard({required this.live});

  final MobileLiveConfig? live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final uri = live?.launchUri;
    final hasLive = live?.configured == true && uri != null;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.play_circle_outline,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l10n.waitingResultLiveTitle,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: hasLive
                    ? Theme.of(context).colorScheme.primaryContainer
                    : Theme.of(context).colorScheme.surfaceContainerHighest,
              ),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: hasLive
                        ? FilledButton.icon(
                            onPressed: () async {
                              final opened = await ref
                                  .read(customerLinkLauncherProvider)
                                  .openExternal(uri);
                              if (!opened && context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      l10n.waitingResultLiveOpenFailed,
                                    ),
                                  ),
                                );
                              }
                            },
                            icon: const Icon(Icons.open_in_new),
                            label: Text(l10n.waitingResultLiveOpen),
                          )
                        : Text(
                            l10n.waitingResultLiveEmpty,
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w700,
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

class _WaitingResultActions extends StatelessWidget {
  const _WaitingResultActions({
    required this.onTickets,
    required this.onResult,
  });

  final VoidCallback onTickets;
  final VoidCallback onResult;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final stacked = constraints.maxWidth < 420;
            final buttons = [
              FilledButton.icon(
                onPressed: onTickets,
                icon: const Icon(Icons.confirmation_number_outlined),
                label: Text(l10n.waitingResultMyTickets),
              ),
              OutlinedButton.icon(
                onPressed: onResult,
                icon: const Icon(Icons.emoji_events_outlined),
                label: Text(l10n.waitingResultCheckResult),
              ),
            ];

            if (stacked) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final button in buttons)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: button,
                    ),
                ],
              );
            }

            return Row(
              children: [
                for (var index = 0; index < buttons.length; index += 1) ...[
                  if (index > 0) const SizedBox(width: 12),
                  Expanded(child: buttons[index]),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}
