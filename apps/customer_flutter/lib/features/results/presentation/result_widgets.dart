import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/result_models.dart';

class ResultPageBody extends StatelessWidget {
  const ResultPageBody({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomerPageBody(child: child);
  }
}

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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final drawDate = result.drawDateText(localeTag(l10n.locale));
    final summary = result.summary;
    final radius = BorderRadius.circular(featured ? 24 : 18);
    final foreground = featured ? Colors.white : colorScheme.onSurface;
    final mutedForeground = featured
        ? Colors.white.withValues(alpha: 0.82)
        : colorScheme.onSurfaceVariant;
    final pillBackground = featured
        ? Colors.white.withValues(alpha: 0.16)
        : colorScheme.primaryContainer;
    final pillForeground =
        featured ? Colors.white : colorScheme.onPrimaryContainer;

    return DecoratedBox(
      decoration: featured
          ? BoxDecoration(borderRadius: radius)
          : _resultSurfaceDecoration(context, radius: featured ? 24 : 18),
      child: ClipRRect(
        borderRadius: radius,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: link == null ? null : () => context.go(link!),
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: featured
                    ? LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          colorScheme.primary,
                          Color.lerp(
                                colorScheme.primary,
                                colorScheme.secondary,
                                0.52,
                              ) ??
                              colorScheme.primary,
                        ],
                      )
                    : null,
              ),
              child: Stack(
                children: [
                  if (featured) ...[
                    Positioned(
                      right: -34,
                      bottom: -44,
                      child: Container(
                        width: 128,
                        height: 128,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:
                              const Color(0xFFFFD629).withValues(alpha: 0.78),
                        ),
                      ),
                    ),
                    Positioned(
                      left: -58,
                      top: -34,
                      child: Transform.rotate(
                        angle: -0.54,
                        child: Container(
                          width: 260,
                          height: 86,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(44),
                          ),
                        ),
                      ),
                    ),
                  ],
                  Padding(
                    padding: EdgeInsets.all(featured ? 22 : 16),
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
                                          style: theme.textTheme.titleMedium
                                              ?.copyWith(
                                            color: foreground,
                                            fontWeight: FontWeight.w900,
                                          ),
                                        ),
                                      ),
                                      if (result.isUnofficial) ...[
                                        const SizedBox(width: 6),
                                        Icon(
                                          Icons.info_outline,
                                          size: 16,
                                          color: mutedForeground,
                                        ),
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
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style:
                                        theme.textTheme.labelMedium?.copyWith(
                                      color: mutedForeground,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (link != null)
                              Icon(Icons.chevron_right, color: mutedForeground),
                          ],
                        ),
                        if (result.isUnofficial) ...[
                          const SizedBox(height: 12),
                          _UnofficialBadge(featured: featured),
                        ],
                        const SizedBox(height: 18),
                        LayoutBuilder(
                          builder: (context, constraints) {
                            final twoColumns = constraints.maxWidth >= 390;
                            final children = [
                              _ResultNumberBlock(
                                label: l10n.resultRewardTitle('reward_1'),
                                number: summary.first,
                                prominent: true,
                                labelColor: mutedForeground,
                                pillBackground: pillBackground,
                                pillForeground: pillForeground,
                              ),
                              _ResultNumberBlock(
                                label:
                                    l10n.resultRewardTitle('reward_two_digit'),
                                number: summary.last2,
                                prominent: true,
                                labelColor: mutedForeground,
                                pillBackground: pillBackground,
                                pillForeground: pillForeground,
                              ),
                              _ResultNumberBlock(
                                label: l10n
                                    .resultRewardTitle('reward_three_digit_1'),
                                numbers: summary.front3,
                                labelColor: mutedForeground,
                                pillBackground: pillBackground,
                                pillForeground: pillForeground,
                              ),
                              _ResultNumberBlock(
                                label: l10n
                                    .resultRewardTitle('reward_three_digit_2'),
                                numbers: summary.last3,
                                labelColor: mutedForeground,
                                pillBackground: pillBackground,
                                pillForeground: pillForeground,
                              ),
                            ];

                            if (!twoColumns) {
                              return Column(
                                children: [
                                  for (final child in children)
                                    Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 14),
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
                ],
              ),
            ),
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

    return DecoratedBox(
      decoration: _resultSurfaceDecoration(context, radius: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.emoji_events_outlined,
                    color: colorScheme.onPrimaryContainer,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.resultRewardTitle(
                          group.slug,
                          fallback: group.title,
                        ),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        l10n.resultPrizeEach(formatBaht(group.amount)),
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
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
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: Colors.white,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
    boxShadow: [
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
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
    this.pillBackground,
    this.pillForeground,
  });

  final String label;
  final String? number;
  final List<String> numbers;
  final bool prominent;
  final Color? labelColor;
  final Color? pillBackground;
  final Color? pillForeground;

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
                fontWeight: FontWeight.w800,
              ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in displayNumbers)
              _ResultNumberPill(
                number: item,
                prominent: prominent,
                backgroundColor: pillBackground,
                foregroundColor: pillForeground,
              ),
          ],
        ),
      ],
    );
  }
}

class _ResultNumberPill extends StatelessWidget {
  const _ResultNumberPill({
    required this.number,
    this.prominent = false,
    this.backgroundColor,
    this.foregroundColor,
  });

  final String number;
  final bool prominent;
  final Color? backgroundColor;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: prominent ? 14 : 10,
        vertical: prominent ? 8 : 6,
      ),
      decoration: BoxDecoration(
        color:
            backgroundColor ?? Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        number,
        textAlign: TextAlign.center,
        style: TextStyle(
          color: foregroundColor ??
              Theme.of(context).colorScheme.onPrimaryContainer,
          fontSize: prominent ? 24 : 18,
          fontWeight: FontWeight.w900,
          letterSpacing: 0,
        ),
      ),
    );
  }
}

class _UnofficialBadge extends StatelessWidget {
  const _UnofficialBadge({required this.featured});

  final bool featured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: featured
            ? Colors.white.withValues(alpha: 0.16)
            : Colors.amber.withValues(alpha: 0.18),
      ),
      child: Row(
        children: [
          Icon(
            Icons.warning_amber_rounded,
            size: 18,
            color: featured ? Colors.white : null,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              context.l10n.resultUnofficial,
              style: TextStyle(
                color: featured ? Colors.white : null,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
