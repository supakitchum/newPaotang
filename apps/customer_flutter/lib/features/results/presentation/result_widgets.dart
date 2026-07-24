import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/result_models.dart';
import 'result_visual_tokens.dart';

class ResultPageBody extends StatelessWidget {
  const ResultPageBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomerPageBody(child: child);
  }
}

enum ResultSummaryCardVariant { standard, featured, history }

class ResultSummaryCard extends StatelessWidget {
  const ResultSummaryCard({
    required this.result,
    super.key,
    this.variant = ResultSummaryCardVariant.standard,
    this.link,
  });

  final RewardResultGame result;
  final ResultSummaryCardVariant variant;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final drawDate = result.drawDateText(localeTag(l10n.locale));
    final summary = result.summary;
    final featured = variant == ResultSummaryCardVariant.featured;
    final history = variant == ResultSummaryCardVariant.history;
    final radius = BorderRadius.circular(featured ? 10 : 8);
    final wide = MediaQuery.sizeOf(context).width >= 1024;
    final padding = wide
        ? const EdgeInsets.symmetric(horizontal: 26, vertical: 25)
        : featured
        ? const EdgeInsets.fromLTRB(24, 24, 24, 26)
        : history
        ? const EdgeInsets.fromLTRB(24, 26, 24, 31)
        : const EdgeInsets.symmetric(horizontal: 18, vertical: 20);
    const mutedForeground = resultNuxtMuted;

    final content = ClipRRect(
      borderRadius: radius,
      child: ColoredBox(
        color: resultNuxtSurface,
        child: Padding(
          padding: padding,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (!history)
                _ResultFeaturedHeader(
                  drawDate: drawDate.isEmpty
                      ? l10n.resultPendingDrawDate
                      : drawDate,
                  link: link,
                  boldDate: featured,
                )
              else
                _ResultHistoryHeader(
                  drawDate: drawDate.isEmpty
                      ? l10n.resultPendingDrawDate
                      : drawDate,
                  link: link,
                ),
              if (history)
                Padding(
                  padding: const EdgeInsets.only(bottom: 22),
                  child: Divider(height: 1, color: resultNuxtDivider),
                )
              else
                const SizedBox(height: 16),
              Column(
                children: [
                  _ResultSummaryRow(
                    left: _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_1'),
                      number: summary.first,
                      prominent: true,
                      labelColor: mutedForeground,
                    ),
                    right: _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_two_digit'),
                      number: summary.last2,
                      prominent: true,
                      labelColor: mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _ResultSummaryRow(
                    left: _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_three_digit_1'),
                      numbers: summary.front3,
                      labelColor: mutedForeground,
                    ),
                    right: _ResultNumberBlock(
                      label: l10n.resultRewardTitle('reward_three_digit_2'),
                      numbers: summary.last3,
                      labelColor: mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final card = DecoratedBox(
      decoration: _resultSurfaceDecoration(
        context,
        radius: featured ? 10 : 8,
        border: false,
        shadow: !featured,
        historyShadow: history,
      ),
      child: content,
    );

    if (!result.isUnofficial) return card;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [card, const _UnofficialBadge()],
    );
  }
}

class _ResultFeaturedHeader extends StatelessWidget {
  const _ResultFeaturedHeader({
    required this.drawDate,
    required this.boldDate,
    this.link,
  });

  final String drawDate;
  final bool boldDate;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    return Row(
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
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        color: resultNuxtSectionTitle,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        height: 1.18,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  const _ResultInfoLink(),
                ],
              ),
              const SizedBox(height: 6),
              Text.rich(
                TextSpan(
                  text: '${l10n.resultDrawDate('').trim()} ',
                  children: [
                    TextSpan(
                      text: drawDate,
                      style: TextStyle(
                        fontWeight: boldDate
                            ? FontWeight.w700
                            : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: resultNuxtMuted,
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 1.25,
                ),
              ),
            ],
          ),
        ),
        if (link != null) ...[
          const SizedBox(width: 10),
          _ResultCardChevron(link: link!),
        ],
      ],
    );
  }
}

class _ResultHistoryHeader extends StatelessWidget {
  const _ResultHistoryHeader({required this.drawDate, this.link});

  final String drawDate;
  final String? link;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 74),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.resultDrawDate('').trim(),
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: resultNuxtMuted,
                    fontSize: 16,
                    fontWeight: FontWeight.w400,
                    height: 1.25,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  drawDate,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: resultNuxtInk,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),
              ],
            ),
          ),
          if (link != null) _ResultCardChevron(link: link!),
        ],
      ),
    );
  }
}

class _ResultSummaryRow extends StatelessWidget {
  const _ResultSummaryRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 7, child: left),
        const SizedBox(width: 16),
        Expanded(flex: 5, child: right),
      ],
    );
  }
}

class _ResultCardChevron extends StatelessWidget {
  const _ResultCardChevron({required this.link});

  final String link;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.resultFullTitle,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.push(link),
          child: const Padding(
            padding: EdgeInsets.all(2),
            child: Icon(Icons.chevron_right, size: 30, color: resultNuxtLink),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final besideFirst = group.slug == 'reward_beside_1';
    final barColor =
        Color.lerp(colorScheme.surface, colorScheme.outlineVariant, 0.34) ??
        colorScheme.surfaceContainerHighest;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ColoredBox(
          color: barColor,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    l10n.resultRewardTitle(group.slug, fallback: group.title),
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  l10n.resultPrizeEach(_resultPrizeAmountText(group.amount)),
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(24, besideFirst ? 18 : 14, 24, 22),
          child: _ResultNumberGrid(numbers: group.numbers),
        ),
      ],
    );
  }
}

class ResultDetailHighlight extends StatelessWidget {
  const ResultDetailHighlight({required this.result, super.key});

  final RewardResultGame result;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final summary = result.summary;
    return Column(
      children: [
        _ResultDetailHighlightRow(
          left: _ResultDetailHighlightBlock(
            label: l10n.resultRewardTitle('reward_1'),
            amount: _rewardAmountLabel(context, result, 'reward_1'),
            numbers: [summary.first],
            firstPrize: true,
          ),
          right: _ResultDetailHighlightBlock(
            label: l10n.resultRewardTitle('reward_two_digit'),
            amount: _rewardAmountLabel(context, result, 'reward_two_digit'),
            numbers: [summary.last2],
            firstPrize: true,
          ),
        ),
        const SizedBox(height: 26),
        _ResultDetailHighlightRow(
          left: _ResultDetailHighlightBlock(
            label: l10n.resultRewardTitle('reward_three_digit_1'),
            amount: _rewardAmountLabel(context, result, 'reward_three_digit_1'),
            numbers: summary.front3,
          ),
          right: _ResultDetailHighlightBlock(
            label: l10n.resultRewardTitle('reward_three_digit_2'),
            amount: _rewardAmountLabel(context, result, 'reward_three_digit_2'),
            numbers: summary.last3,
          ),
        ),
      ],
    );
  }
}

class ResultPayoutDock extends StatelessWidget {
  const ResultPayoutDock({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resultNuxtSurface.withValues(alpha: 0.98),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
        boxShadow: [
          BoxShadow(
            color: resultNuxtPayoutShadow,
            blurRadius: 24,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(18, 22, 18, 22 + bottomInset),
        child: Text(
          context.l10n.resultPayoutHint,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: resultNuxtMuted,
            fontSize: 15,
            fontWeight: FontWeight.w500,
            height: 1.45,
          ),
        ),
      ),
    );
  }
}

class _ResultDetailHighlightRow extends StatelessWidget {
  const _ResultDetailHighlightRow({required this.left, required this.right});

  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 125, child: left),
        const SizedBox(width: 33),
        Expanded(flex: 90, child: right),
      ],
    );
  }
}

class _ResultDetailHighlightBlock extends StatelessWidget {
  const _ResultDetailHighlightBlock({
    required this.label,
    required this.amount,
    required this.numbers,
    this.firstPrize = false,
  });

  final String label;
  final String amount;
  final List<String> numbers;
  final bool firstPrize;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 15,
            fontWeight: FontWeight.w700,
            height: 1.25,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          amount,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
            fontSize: 14,
            fontWeight: FontWeight.w500,
            height: 1.35,
          ),
        ),
        SizedBox(height: firstPrize ? 18 : 16),
        _ResultNumberGrid(
          numbers: numbers,
          columns: numbers.length <= 1 ? 1 : 2,
          prominent: firstPrize,
          highlight: true,
          horizontalGap: firstPrize ? 0 : 18,
          rowGap: 8,
        ),
      ],
    );
  }
}

class _ResultNumberGrid extends StatelessWidget {
  const _ResultNumberGrid({
    required this.numbers,
    this.columns,
    this.prominent = false,
    this.highlight = false,
    this.horizontalGap = 18,
    this.rowGap = 14,
  });

  final List<String> numbers;
  final int? columns;
  final bool prominent;
  final bool highlight;
  final double horizontalGap;
  final double rowGap;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final effectiveColumns = columns ?? 4;
        final gapTotal = horizontalGap * (effectiveColumns - 1);
        final itemWidth = ((width - gapTotal) / effectiveColumns)
            .clamp(0.0, width)
            .toDouble();
        return Wrap(
          spacing: horizontalGap,
          runSpacing: rowGap,
          children: [
            for (final number in numbers)
              SizedBox(
                width: itemWidth,
                child: _ResultNumberPill(
                  number: number,
                  fontSize: prominent ? 37 : (highlight ? 22 : 17),
                  fontWeight: prominent || highlight
                      ? FontWeight.w700
                      : FontWeight.w500,
                  lineHeight: prominent || highlight ? 1 : 1.2,
                  color: prominent
                      ? resultNuxtStateText
                      : resultNuxtSmallNumber,
                  align: TextAlign.left,
                ),
              ),
          ],
        );
      },
    );
  }
}

String _rewardAmountLabel(
  BuildContext context,
  RewardResultGame result,
  String slug,
) {
  final amount =
      result.reward(slug)?.amount ??
      (rewardDefinitions[slug]?.amount ?? 0).toDouble();
  return context.l10n.resultPrizeEach(_resultPrizeAmountText(amount));
}

String _resultPrizeAmountText(num amount) {
  final formatted = formatBaht(amount);
  final value = amount.toDouble();
  if (!value.isFinite || (value - value.roundToDouble()).abs() > 0.000001) {
    return formatted;
  }
  return formatted.replaceFirstMapped(
    RegExp(r'([.,]00)(\s*\S+)?$'),
    (match) => match.group(2) ?? '',
  );
}

class ResultInfoCard extends StatelessWidget {
  const ResultInfoCard({
    required this.icon,
    required this.title,
    super.key,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _resultSurfaceDecoration(context, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(icon, color: colorScheme.onPrimaryContainer),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

BoxDecoration _resultSurfaceDecoration(
  BuildContext context, {
  required double radius,
  bool border = true,
  bool shadow = true,
  bool historyShadow = false,
}) {
  return BoxDecoration(
    color: resultNuxtSurface,
    borderRadius: BorderRadius.circular(radius),
    border: border ? Border.all(color: resultNuxtDivider) : null,
    boxShadow: [
      if (shadow)
        BoxShadow(
          color: historyShadow
              ? resultNuxtHistoryCardShadow
              : resultNuxtCardShadow,
          blurRadius: 24,
          offset: historyShadow ? const Offset(0, 13) : const Offset(0, 8),
        ),
    ],
  );
}

class _ResultNumberBlock extends StatelessWidget {
  const _ResultNumberBlock({
    required this.label,
    this.number,
    this.numbers = const [],
    this.prominent = false,
    this.labelColor,
  });

  final String label;
  final String? number;
  final List<String> numbers;
  final bool prominent;
  final Color? labelColor;

  @override
  Widget build(BuildContext context) {
    final displayNumbers = number == null ? numbers : [number!];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            color: labelColor,
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 1.5,
          ),
        ),
        Wrap(
          spacing: prominent ? 8 : 20,
          runSpacing: prominent ? 8 : 2,
          children: [
            for (final item in displayNumbers)
              _ResultNumberPill(
                number: item,
                fontSize: prominent ? 31 : 21,
                fontWeight: FontWeight.w700,
                lineHeight: 1.5,
                color: prominent ? resultNuxtStateText : resultNuxtSmallNumber,
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultInfoLink extends StatelessWidget {
  const _ResultInfoLink();

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: context.l10n.contentRewardTermsTitle,
      child: Semantics(
        button: true,
        label: context.l10n.contentRewardTermsTitle,
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => context.push('/term-reward'),
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Icon(Icons.info_outline, size: 16, color: resultNuxtMuted),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultNumberPill extends StatelessWidget {
  const _ResultNumberPill({
    required this.number,
    required this.fontSize,
    required this.fontWeight,
    required this.lineHeight,
    required this.color,
    this.align = TextAlign.start,
  });

  final String number;
  final double fontSize;
  final FontWeight fontWeight;
  final double lineHeight;
  final Color color;
  final TextAlign align;

  @override
  Widget build(BuildContext context) {
    return Text(
      number,
      textAlign: align,
      style: TextStyle(
        color: color,
        fontSize: fontSize,
        fontWeight: fontWeight,
        height: lineHeight,
        letterSpacing: 0,
        fontFeatures: const [FontFeature.tabularFigures()],
      ),
    );
  }
}

class _UnofficialBadge extends StatelessWidget {
  const _UnofficialBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: resultNuxtUnofficialFill,
        border: Border.all(color: resultNuxtUnofficialBorder),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: resultNuxtUnofficialIcon,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.resultUnofficial,
              style: TextStyle(
                color: resultNuxtUnofficialText,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
