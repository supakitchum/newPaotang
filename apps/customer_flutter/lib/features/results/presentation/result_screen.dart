import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(currentResultProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.resultTitle,
      currentPath: '/result',
      child: RefreshIndicator(
        onRefresh: () async => ref.invalidate(currentResultProvider),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            ResultPageBody(
              child: AsyncStateView(
                value: result,
                loadingText: l10n.resultLoading,
                data: (bundle) {
                  final selected = bundle.selectedResult;
                  if (selected == null) return const _NoResultCard();

                  final history = bundle.history
                      .where((item) => item.hasResolvedResult)
                      .toList(growable: false);

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ResultSummaryCard(
                        result: selected,
                        featured: true,
                        link: selected.id.isEmpty
                            ? '/result/full'
                            : '/result/full?game_id=${selected.id}',
                      ),
                      const SizedBox(height: 20),
                      Text(
                        l10n.resultHistoryTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 10),
                      if (history.isEmpty)
                        const _EmptyHistoryCard()
                      else
                        for (final item in history)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: ResultSummaryCard(
                              result: item,
                              link: '/result/full?game_id=${item.id}',
                            ),
                          ),
                      const SizedBox(height: 14),
                      const _PayoutHintCard(),
                    ],
                  );
                },
                empty: const _NoResultCard(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoResultCard extends StatelessWidget {
  const _NoResultCard();

  @override
  Widget build(BuildContext context) {
    return ResultInfoCard(
      icon: Icons.hourglass_empty,
      title: context.l10n.resultNoLatest,
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return ResultInfoCard(
      icon: Icons.history,
      title: context.l10n.resultNoHistory,
    );
  }
}

class _PayoutHintCard extends StatelessWidget {
  const _PayoutHintCard();

  @override
  Widget build(BuildContext context) {
    return ResultInfoCard(
      icon: Icons.payments_outlined,
      title: context.l10n.resultPayoutHint,
    );
  }
}
