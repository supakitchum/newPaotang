import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

class WaitingResultScreen extends ConsumerWidget {
  const WaitingResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(currentResultProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.waitingResultTitle,
      currentPath: '/tickets',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(currentResultProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 34,
                      backgroundColor:
                          Theme.of(context).colorScheme.primaryContainer,
                      child: Icon(
                        Icons.hourglass_bottom,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        size: 34,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      l10n.waitingResultSaleClosed,
                      style: const TextStyle(fontWeight: FontWeight.w800),
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
                          style: Theme.of(context)
                              .textTheme
                              .headlineSmall
                              ?.copyWith(fontWeight: FontWeight.w900),
                          textAlign: TextAlign.center,
                        );
                      },
                      empty: Text(
                        l10n.waitingResultPending,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AsyncStateView(
              value: result,
              loadingText: l10n.resultLoading,
              data: (bundle) {
                final selected = bundle.selectedResult;
                if (selected == null) return const _WaitingResultPlaceholder();
                return ResultSummaryCard(
                  result: selected,
                  featured: true,
                  link: '/result/full',
                );
              },
              empty: const _WaitingResultPlaceholder(),
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  alignment: WrapAlignment.center,
                  children: [
                    FilledButton.icon(
                      onPressed: () => context.go('/tickets'),
                      icon: const Icon(Icons.confirmation_number_outlined),
                      label: Text(l10n.waitingResultMyTickets),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => context.go('/result'),
                      icon: const Icon(Icons.emoji_events_outlined),
                      label: Text(l10n.waitingResultCheckResult),
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

class _WaitingResultPlaceholder extends StatelessWidget {
  const _WaitingResultPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(
          context.l10n.waitingResultPlaceholder,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
