import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_back_navigation.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/result_repository.dart';
import 'result_visual_tokens.dart';
import 'result_widgets.dart';

class ResultScreen extends ConsumerWidget {
  const ResultScreen({super.key, this.routePath = '/result'});

  final String routePath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final indexPath = resultIndexPathFor(routePath);
    final resultProvider = indexPath == '/results'
        ? legacyResultProvider
        : currentResultProvider;
    listenForCustomerOperationalError<RewardResultBundle>(
      ref: ref,
      context: context,
      provider: resultProvider,
    );
    final result = ref.watch(resultProvider);
    final showUnofficialDock =
        result.valueOrNull?.selectedResult?.isUnofficial == true;

    return AppShell(
      title: l10n.resultTitle,
      currentPath: indexPath,
      showBottomNavigation: false,
      fullScreen: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: ColoredBox(
              color: resultHeroPrimary(context),
              child: Column(
                children: [
                  KeyedSubtree(
                    key: const ValueKey('result-fixed-header'),
                    child: _ResultIndexHero(
                      result: result,
                      indexPath: indexPath,
                      onRetry: () => ref.invalidate(resultProvider),
                    ),
                  ),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        return CustomerContentViewportScope(
                          minHeight: constraints.maxHeight,
                          child: ClipRRect(
                            key: const ValueKey('result-content-region'),
                            borderRadius: const BorderRadius.vertical(
                              top: Radius.circular(12),
                            ),
                            child: ListView(
                              key: const ValueKey('result-content-scroll'),
                              padding: EdgeInsets.zero,
                              physics: const AlwaysScrollableScrollPhysics(),
                              children: [
                                _ResultsHistorySheet(
                                  result: result,
                                  indexPath: indexPath,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showUnofficialDock)
            const Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: ResultUnofficialDock(),
            ),
        ],
      ),
    );
  }
}

class _ResultIndexHero extends StatelessWidget {
  const _ResultIndexHero({
    required this.result,
    required this.indexPath,
    required this.onRetry,
  });

  final AsyncValue<RewardResultBundle> result;
  final String indexPath;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    final topPadding = topInset + 14 < 58 ? 58.0 : topInset + 14;
    return CustomerBlueHeroBackdrop(
      primary: resultHeroPrimary(context),
      secondary: resultHeroSecondary(context),
      child: CustomerPageBody(
        top: topPadding,
        bottom: 12,
        mobileHorizontal: 20,
        wideHorizontal: 24,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 42,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned(
                    top: 2,
                    left: -16,
                    child: IconButton(
                      key: const ValueKey('result-back-button'),
                      tooltip: context.l10n.commonBack,
                      onPressed: () =>
                          navigateCustomerBack(context, fallbackPath: '/'),
                      icon: const Icon(Icons.arrow_back_ios_new),
                      iconSize: 31,
                      color: resultNuxtSurface,
                      style:
                          IconButton.styleFrom(
                            fixedSize: const Size.square(42),
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            backgroundColor: Colors.transparent,
                            foregroundColor: resultNuxtSurface,
                            padding: EdgeInsets.zero,
                            shape: const CircleBorder(),
                          ).copyWith(
                            overlayColor: const WidgetStatePropertyAll(
                              Colors.transparent,
                            ),
                          ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 54),
                    child: Text(
                      context.l10n.resultTitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: resultNuxtSurface,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        height: 1.12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            _ResultHeroContent(
              result: result,
              indexPath: indexPath,
              onRetry: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _ResultHeroContent extends StatelessWidget {
  const _ResultHeroContent({
    required this.result,
    required this.indexPath,
    required this.onRetry,
  });

  final AsyncValue<RewardResultBundle> result;
  final String indexPath;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: result.when(
        data: (bundle) {
          final selected = bundle.selectedResult;
          if (selected == null) {
            return _ResultInlineState(
              icon: Icons.hourglass_empty,
              title: context.l10n.resultNoLatest,
            );
          }
          return ResultSummaryCard(
            key: const ValueKey('result-featured-card'),
            result: selected,
            variant: ResultSummaryCardVariant.featured,
            link: resultFullPathFor(indexPath, selected.id),
            showUnofficialBadge: false,
          );
        },
        loading: () => _ResultInlineState(
          loading: true,
          title: context.l10n.resultLoading,
        ),
        error: (error, __) => _ResultInlineState(
          icon: Icons.error_outline,
          title: customerErrorMessage(error, context.l10n.commonLoadFailed),
          error: true,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class _ResultsHistorySheet extends StatelessWidget {
  const _ResultsHistorySheet({required this.result, required this.indexPath});

  final AsyncValue<RewardResultBundle> result;
  final String indexPath;

  @override
  Widget build(BuildContext context) {
    final showUnofficialDock =
        result.valueOrNull?.selectedResult?.isUnofficial == true;
    return DecoratedBox(
      key: const ValueKey('result-history-sheet'),
      decoration: BoxDecoration(
        color: resultNuxtHistorySheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerPageBody(
            top: 14,
            bottom: showUnofficialDock ? 104 : 36,
            mobileHorizontal: 24,
            wideHorizontal: 24,
            minViewportHeight: true,
            child: result.when(
              data: (bundle) {
                final history = bundle.history
                    .where((item) => item.hasResolvedResult)
                    .take(3)
                    .toList(growable: false);
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultHistoryTitle(label: context.l10n.resultHistoryTitle),
                    const SizedBox(height: 16),
                    if (history.isEmpty)
                      const _EmptyHistoryCard()
                    else
                      for (final item in history)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: ResultSummaryCard(
                            result: item,
                            variant: ResultSummaryCardVariant.history,
                            link: resultFullPathFor(indexPath, item.id),
                            showUnofficialBadge: false,
                          ),
                        ),
                  ],
                );
              },
              loading: () => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResultHistoryTitle(label: context.l10n.resultHistoryTitle),
                  const SizedBox(height: 16),
                  _ResultMutedMessage(message: context.l10n.resultLoading),
                ],
              ),
              error: (error, __) => Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _ResultHistoryTitle(label: context.l10n.resultHistoryTitle),
                  const SizedBox(height: 16),
                  _ResultMutedMessage(
                    message: customerErrorMessage(
                      error,
                      context.l10n.commonLoadFailed,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

String resultIndexPathFor(String routePath) {
  return routePath.startsWith('/results') ? '/results' : '/result';
}

String resultFullPathFor(String indexPath, String? gameId) {
  final normalizedIndex = resultIndexPathFor(indexPath);
  final path = normalizedIndex == '/results' ? '/results/full' : '/result/full';
  final id = gameId?.trim() ?? '';
  if (normalizedIndex == '/results' || id.isEmpty) return path;
  return Uri(path: path, queryParameters: {'game_id': id}).toString();
}

class _ResultHistoryTitle extends StatelessWidget {
  const _ResultHistoryTitle({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
        color: resultNuxtSectionTitle,
        fontSize: 20,
        fontWeight: FontWeight.w700,
        height: 1.25,
      ),
    );
  }
}

class _ResultInlineState extends StatelessWidget {
  const _ResultInlineState({
    required this.title,
    this.icon,
    this.loading = false,
    this.error = false,
    this.onRetry,
  });

  final String title;
  final IconData? icon;
  final bool loading;
  final bool error;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final foreground = error ? resultNuxtError : resultNuxtStateText;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resultNuxtSurface,
        borderRadius: BorderRadius.circular(10),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 181),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (loading)
                CustomerLoadingMark(width: 32, height: 22, semanticLabel: title)
              else
                Icon(icon ?? Icons.info_outline, color: foreground, size: 32),
              const SizedBox(height: 10),
              Text(
                title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: foreground,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  height: 1.4,
                ),
              ),
              if (onRetry != null) ...[
                const SizedBox(height: 14),
                _ResultRetryPill(onPressed: onRetry!),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultMutedMessage extends StatelessWidget {
  const _ResultMutedMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
          color: resultNuxtMuted,
          fontWeight: FontWeight.w400,
        ),
      ),
    );
  }
}

class _EmptyHistoryCard extends StatelessWidget {
  const _EmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return _ResultMutedMessage(message: context.l10n.resultNoHistory);
  }
}

class _ResultRetryPill extends StatelessWidget {
  const _ResultRetryPill({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: resultOutlineBorder(context)),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            child: Text(
              context.l10n.commonRetry,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: resultOutlineText(context),
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
