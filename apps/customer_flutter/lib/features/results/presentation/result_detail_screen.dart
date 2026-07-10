import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/result_models.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

class ResultDetailScreen extends ConsumerWidget {
  const ResultDetailScreen({this.gameId, super.key});

  final String? gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final result = ref.watch(resultDetailProvider(gameId));
    final title = _resultDetailHeroTitle(context, result.valueOrNull);

    return AppShell(
      title: title,
      currentPath: '/result',
      backPath: '/result',
      showBottomNavigation: false,
      heroMinHeight: 121,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.zero,
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                _ResultFullSheet(result: result),
              ],
            ),
          ),
          if (result.hasValue)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ResultPayoutDock(),
            ),
        ],
      ),
    );
  }
}

class _ResultFullSheet extends StatelessWidget {
  const _ResultFullSheet({required this.result});

  final AsyncValue<RewardResultBundle> result;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: (MediaQuery.sizeOf(context).height - 105).clamp(
            520.0,
            double.infinity,
          ),
        ),
        child: result.when(
          data: (bundle) {
            final selected = bundle.selectedResult;
            if (selected == null) {
              return const _ResultDetailState.noResult();
            }
            final drawDate = _resultDrawDateText(context, selected);
            final waiting = _isWaitingResult(selected);
            final highlightSlugs = {
              'reward_1',
              'reward_two_digit',
              'reward_three_digit_1',
              'reward_three_digit_2',
            };
            final detailGroups = selected.groups
                .where((group) => !highlightSlugs.contains(group.slug))
                .where((group) => group.numbers.any(isResolvedRewardNumber))
                .toList(growable: false);

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                CustomerPageBody(
                  top: 22,
                  bottom: 138,
                  mobileHorizontal: 0,
                  wideHorizontal: 0,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (selected.isUnofficial)
                        const Padding(
                          padding: EdgeInsets.fromLTRB(24, 0, 24, 14),
                          child: _ResultUnofficialNotice(),
                        ),
                      if (waiting)
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 18, 24, 22),
                          child: _ResultDetailState.waiting(drawDate),
                        )
                      else ...[
                        Padding(
                          padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
                          child: ResultDetailHighlight(result: selected),
                        ),
                        if (detailGroups.isEmpty)
                          const Padding(
                            padding: EdgeInsets.fromLTRB(24, 0, 24, 22),
                            child: _NoAdditionalPrizeCard(),
                          )
                        else
                          for (final group in detailGroups)
                            ResultDetailGroupCard(group: group),
                      ],
                    ],
                  ),
                ),
              ],
            );
          },
          loading: () => _ResultDetailState.loading(context.l10n.resultLoading),
          error: (_, __) => _ResultDetailState.error(
            context.l10n.commonLoadFailed,
          ),
        ),
      ),
    );
  }
}

class _ResultDetailState extends StatelessWidget {
  const _ResultDetailState({
    required this.title,
    this.icon,
    this.subtitle,
    this.loading = false,
    this.error = false,
    this.minHeight = 420,
  });

  const _ResultDetailState.noResult()
      : title = '',
        subtitle = null,
        icon = Icons.hourglass_empty,
        loading = false,
        error = false,
        minHeight = 420;

  factory _ResultDetailState.loading(String title) {
    return _ResultDetailState(
      title: title,
      icon: Icons.hourglass_empty,
      loading: true,
    );
  }

  factory _ResultDetailState.error(String title) {
    return _ResultDetailState(
      title: title,
      icon: Icons.error_outline,
      error: true,
    );
  }

  factory _ResultDetailState.waiting(String drawDate) {
    return _ResultDetailState(
      title: '',
      subtitle: drawDate,
      icon: Icons.hourglass_empty,
    );
  }

  factory _ResultDetailState.compact(String title, {String? subtitle}) {
    return _ResultDetailState(
      title: title,
      subtitle: subtitle,
      minHeight: 180,
    );
  }

  final String title;
  final String? subtitle;
  final IconData? icon;
  final bool loading;
  final bool error;
  final double minHeight;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final effectiveTitle = title.isEmpty
        ? (subtitle == null ? l10n.resultNoLatest : l10n.resultWaitingTitle)
        : title;
    final foreground = error ? colorScheme.error : colorScheme.onSurface;
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: minHeight),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 36),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (loading)
              CustomerLoadingMark(
                width: 42,
                height: 28,
                semanticLabel: effectiveTitle,
              )
            else if (icon != null)
              Icon(icon, color: foreground, size: 42),
            if (loading || icon != null) const SizedBox(height: 16),
            Text(
              effectiveTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: foreground,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 1.25,
                  ),
            ),
            if (loading) ...[
              const SizedBox(height: 8),
              Text(
                subtitle ?? l10n.commonLoadingData,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      height: 1.45,
                    ),
              ),
            ] else if (subtitle != null && subtitle!.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 16,
                      height: 1.45,
                    ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ResultUnofficialNotice extends StatelessWidget {
  const _ResultUnofficialNotice();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background =
        Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.82) ??
            colorScheme.surface;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: colorScheme.tertiary.withValues(alpha: 0.34)),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.tertiary,
              size: 18,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                context.l10n.resultUnofficial,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onTertiaryContainer,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _NoAdditionalPrizeCard extends StatelessWidget {
  const _NoAdditionalPrizeCard();

  @override
  Widget build(BuildContext context) {
    return _ResultDetailState.compact(context.l10n.resultNoAdditional);
  }
}

String _resultDrawDateText(BuildContext context, RewardResultGame result) {
  final l10n = context.l10n;
  final drawDate = result.drawDateText(localeTag(l10n.locale));
  return drawDate.isEmpty ? l10n.resultPendingDrawDate : drawDate;
}

String _resultDetailHeroTitle(
  BuildContext context,
  RewardResultBundle? bundle,
) {
  final selected = bundle?.selectedResult;
  if (selected == null) return context.l10n.resultTitle;
  final drawDate = _resultDrawDateText(context, selected);
  return context.l10n.resultFullHeader(drawDate);
}

bool _isWaitingResult(RewardResultGame result) {
  return !result.hasResolvedResult && !result.isPublished;
}
