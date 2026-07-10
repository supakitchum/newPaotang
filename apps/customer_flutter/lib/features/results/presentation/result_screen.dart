import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/result_repository.dart';
import 'result_visual_tokens.dart';
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
      showBottomNavigation: false,
      fullScreen: true,
      child: Stack(
        children: [
          Positioned.fill(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(currentResultProvider),
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _ResultIndexHero(
                    result: result,
                    onRetry: () => ref.invalidate(currentResultProvider),
                  ),
                  _ResultsHistorySheet(result: result),
                ],
              ),
            ),
          ),
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

class _ResultIndexHero extends StatelessWidget {
  const _ResultIndexHero({
    required this.result,
    required this.onRetry,
  });

  final AsyncValue<RewardResultBundle> result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.paddingOf(context).top;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 386),
      child: CustomerBlueHeroBackdrop(
        primary: resultNuxtHeroPrimary,
        secondary: resultNuxtHeroSecondary,
        child: CustomerPageBody(
          top: topInset + 58,
          bottom: 24,
          mobileHorizontal: 20,
          wideHorizontal: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 42,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Positioned(
                      left: -16,
                      child: IconButton(
                        tooltip: context.l10n.commonBack,
                        onPressed: () => context.go('/'),
                        icon: const Icon(Icons.arrow_back_ios_new),
                        iconSize: 31,
                        color: resultNuxtSurface,
                        style: IconButton.styleFrom(
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
                    Text(
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
                  ],
                ),
              ),
              const SizedBox(height: 24),
              _ResultHeroContent(result: result, onRetry: onRetry),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultHeroContent extends StatelessWidget {
  const _ResultHeroContent({
    required this.result,
    required this.onRetry,
  });

  final AsyncValue<RewardResultBundle> result;
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
            result: selected,
            featured: true,
            link: selected.id.isEmpty
                ? '/result/full'
                : '/result/full?game_id=${selected.id}',
          );
        },
        loading: () => _ResultInlineState(
          loading: true,
          title: context.l10n.resultLoading,
        ),
        error: (_, __) => _ResultInlineState(
          icon: Icons.error_outline,
          title: context.l10n.commonLoadFailed,
          error: true,
          onRetry: onRetry,
        ),
      ),
    );
  }
}

class _ResultsHistorySheet extends StatelessWidget {
  const _ResultsHistorySheet({required this.result});

  final AsyncValue<RewardResultBundle> result;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: resultNuxtHistorySheet,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 540),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomerPageBody(
              top: 27,
              bottom: 138,
              mobileHorizontal: 24,
              wideHorizontal: 24,
              child: result.when(
                data: (bundle) {
                  final history = bundle.history
                      .where((item) => item.hasResolvedResult)
                      .toList(growable: false);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ResultHistoryTitle(
                        label: context.l10n.resultHistoryTitle,
                      ),
                      const SizedBox(height: 24),
                      if (history.isEmpty)
                        const _EmptyHistoryCard()
                      else
                        for (final item in history)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 24),
                            child: ResultSummaryCard(
                              result: item,
                              link: '/result/full?game_id=${item.id}',
                            ),
                          ),
                    ],
                  );
                },
                loading: () => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultHistoryTitle(label: context.l10n.resultHistoryTitle),
                    const SizedBox(height: 24),
                    _ResultMutedMessage(message: context.l10n.resultLoading),
                  ],
                ),
                error: (_, __) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _ResultHistoryTitle(label: context.l10n.resultHistoryTitle),
                    const SizedBox(height: 24),
                    _ResultMutedMessage(message: context.l10n.commonLoadFailed),
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
                CustomerLoadingMark(
                  width: 32,
                  height: 22,
                  semanticLabel: title,
                )
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
            border: Border.all(color: resultNuxtOutlineBorder),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
            child: Text(
              context.l10n.commonRetry,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: resultNuxtOutlineText,
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
