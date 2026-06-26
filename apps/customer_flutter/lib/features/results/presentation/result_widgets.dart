import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/result_models.dart';

class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({
    required this.result,
    super.key,
    this.featured = false,
    this.link,
  });

  final RewardResultGame result;
  final bool featured;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drawDate = result.drawDateText(localeTag(l10n.locale));
    final summary = result.summary;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: link == null ? null : () => context.go(link!),
        child: Padding(
          padding: EdgeInsets.all(featured ? 20 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                l10n.resultTitle,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w900,
                                ),
                              ),
                            ),
                            if (result.isUnofficial) ...[
                              const SizedBox(width: 6),
                              const Icon(Icons.info_outline, size: 16),
                            ],
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          l10n.resultDrawDate(
                            drawDate.isEmpty
                                ? l10n.resultPendingDrawDate
                                : drawDate,
                          ),
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ],
                    ),
                  ),
                  if (link != null) const Icon(Icons.chevron_right),
                ],
              ),
              if (result.isUnofficial) ...[
                const SizedBox(height: 10),
                _UnofficialBadge(),
              ],
              const SizedBox(height: 16),
              LayoutBuilder(
                builder: (context, constraints) {
                  final twoColumns = constraints.maxWidth >= 390;
                  final children = [
                    _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_1'),
                      number: summary.first,
                      prominent: true,
                    ),
                    _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_two_digit'),
                      number: summary.last2,
                      prominent: true,
                    ),
                    _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_three_digit_1'),
                      numbers: summary.front3,
                    ),
                    _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_three_digit_2'),
                      numbers: summary.last3,
                    ),
                  ];

                  if (!twoColumns) {
                    return Column(
                      children: [
                        for (final child in children)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 14),
                            child: child,
                          ),
                      ],
                    );
                  }

                  return Wrap(
                    spacing: 16,
                    runSpacing: 16,
                    children: [
                      for (final child in children)
                        SizedBox(
                          width: (constraints.maxWidth - 16) / 2,
                          child: child,
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class ResultDetailGroupCard extends StatelessWidget {
  const ResultDetailGroupCard({required this.group, super.key});

  final RewardGroup group;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.resultRewardTitle(group.slug, fallback: group.title),
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                ),
                Text(
                  l10n.resultPrizeEach(formatBaht(group.amount)),
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                for (final number in group.numbers)
                  _ResultNumberPill(number: number),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultNumberBlock extends StatelessWidget {
  const _ResultNumberBlock({
    required this.label,
    this.number,
    this.numbers = const [],
    this.prominent = false,
  });

  final String label;
  final String? number;
  final List<String> numbers;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final displayNumbers = number == null ? numbers : [number!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in displayNumbers)
              _ResultNumberPill(number: item, prominent: prominent),
          ],
        ),
      ],
    );
  }
}

class _ResultNumberPill extends StatelessWidget {
  const _ResultNumberPill({required this.number, this.prominent = false});

  final String number;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 14 : 10,
        vertical: prominent ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        number,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: prominent ? 24 : 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 2,
        ),
      ),
    );
  }
}

class _UnofficialBadge extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: Colors.amber.withValues(alpha: 0.18),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text(context.l10n.resultUnofficial)),
        ],
      ),
    );
  }
}
