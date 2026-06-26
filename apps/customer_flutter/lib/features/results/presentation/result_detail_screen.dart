import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/result_models.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({this.gameId, super.key});

  final String? gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultDetailProvider(gameId));
    final l10n = context.l10n;

    return AppShell(
      title: l10n.resultFullTitle,
      currentPath: '/result',
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          AsyncStateView(
            value: result,
            loadingText: l10n.resultLoading,
            data: (bundle) {
              final selected = bundle.selectedResult;
              if (selected == null) return const _NoResultDetail();
              final drawDate = selected.drawDateText(localeTag(l10n.locale));

              final highlightSlugs = {
                'reward_1',
                'reward_two_digit',
                'reward_three_digit_1',
                'reward_three_digit_2',
              };
              final detailGroups = selected.groups
                  .where((group) => !highlightSlugs.contains(group.slug))
                  .where(
                    (group) => group.numbers.any(isDisplayableRewardNumber),
                  )
                  .toList(growable: false);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.resultDrawDate(
                      drawDate.isEmpty ? l10n.resultPendingDrawDate : drawDate,
                    ),
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w900),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  ResultSummaryCard(result: selected, featured: true),
                  const SizedBox(height: 12),
                  if (detailGroups.isEmpty)
                    const _NoAdditionalPrizeCard()
                  else
                    for (final group in detailGroups)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ResultDetailGroupCard(group: group),
                      ),
                  const SizedBox(height: 12),
                  const _PayoutHintCard(),
                ],
              );
            },
            empty: const _NoResultDetail(),
          ),
        ],
      ),
    );
  }
}

class _NoResultDetail extends StatelessWidget {
  const _NoResultDetail();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Text(context.l10n.resultNoLatest, textAlign: TextAlign.center),
      ),
    );
  }
}

class _NoAdditionalPrizeCard extends StatelessWidget {
  const _NoAdditionalPrizeCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.info_outline)),
        title: Text(context.l10n.resultNoAdditional),
      ),
    );
  }
}

class _PayoutHintCard extends StatelessWidget {
  const _PayoutHintCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Text(
          context.l10n.resultPayoutHint,
          textAlign: TextAlign.center,
        ),
      ),
    );
  }
}
