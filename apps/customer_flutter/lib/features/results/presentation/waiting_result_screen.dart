import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/result_models.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

class WaitingResultScreen extends ConsumerStatefulWidget {
  const WaitingResultScreen({
    super.key,
    this.showSaleClosedNotice = false,
  });

  final bool showSaleClosedNotice;

  @override
  ConsumerState<WaitingResultScreen> createState() =>
      _WaitingResultScreenState();
}

class _WaitingResultScreenState extends ConsumerState<WaitingResultScreen> {
  bool _saleClosedNoticeConsumed = false;

  @override
  void initState() {
    super.initState();
    _scheduleSaleClosedNotice();
  }

  @override
  void didUpdateWidget(covariant WaitingResultScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.showSaleClosedNotice && widget.showSaleClosedNotice) {
      _saleClosedNoticeConsumed = false;
      _scheduleSaleClosedNotice();
    }
  }

  @override
  Widget build(BuildContext context) {
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
                  _WaitingResultStatusCard(
                    result: result,
                    productLabel: bootstrap?.lotteryProductLabel ?? '',
                  ),
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

  void _scheduleSaleClosedNotice() {
    if (!widget.showSaleClosedNotice || _saleClosedNoticeConsumed) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _saleClosedNoticeConsumed) return;
      _saleClosedNoticeConsumed = true;
      ref.read(appAlertControllerProvider.notifier).show(
            title: context.l10n.waitingResultSaleClosed,
            message: context.l10n.saleClosureAlertMessage,
            variant: AppAlertVariant.warning,
          );
      context.go('/waiting-result');
    });
  }
}

class _WaitingResultStatusCard extends StatelessWidget {
  const _WaitingResultStatusCard({
    required this.result,
    required this.productLabel,
  });

  final AsyncValue<RewardResultBundle> result;
  final String productLabel;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return DecoratedBox(
      decoration: _waitingResultSurfaceDecoration(context, radius: 18),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircleAvatar(
                  radius: 22,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Icon(
                    Icons.storefront_outlined,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                if (productLabel.trim().isNotEmpty) ...[
                  Container(
                    width: 1,
                    height: 34,
                    margin: const EdgeInsets.symmetric(horizontal: 14),
                    color: colorScheme.outlineVariant,
                  ),
                  Text(
                    productLabel.trim(),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 18),
            CircleAvatar(
              radius: 34,
              backgroundColor: colorScheme.secondaryContainer,
              child: Icon(
                Icons.hourglass_bottom,
                color: colorScheme.onSecondaryContainer,
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

class _WaitingResultLiveCard extends ConsumerStatefulWidget {
  const _WaitingResultLiveCard({required this.live});

  final MobileLiveConfig? live;

  @override
  ConsumerState<_WaitingResultLiveCard> createState() =>
      _WaitingResultLiveCardState();
}

class _WaitingResultLiveCardState
    extends ConsumerState<_WaitingResultLiveCard> {
  String _noticeMessage = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final uri = widget.live?.launchUri;
    final hasLive = widget.live?.configured == true && uri != null;

    return DecoratedBox(
      decoration: _waitingResultSurfaceDecoration(context, radius: 16),
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
                              setState(() => _noticeMessage = '');
                              final opened = await ref
                                  .read(customerLinkLauncherProvider)
                                  .openExternal(uri);
                              if (!opened && context.mounted) {
                                setState(() {
                                  _noticeMessage =
                                      l10n.waitingResultLiveOpenFailed;
                                });
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
            if (_noticeMessage.isNotEmpty) ...[
              const SizedBox(height: 12),
              _WaitingResultInlineNotice(message: _noticeMessage),
            ],
          ],
        ),
      ),
    );
  }
}

class _WaitingResultInlineNotice extends StatelessWidget {
  const _WaitingResultInlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.18)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
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
    return DecoratedBox(
      decoration: _waitingResultSurfaceDecoration(context, radius: 16),
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

BoxDecoration _waitingResultSurfaceDecoration(
  BuildContext context, {
  required double radius,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return BoxDecoration(
    color: colorScheme.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: colorScheme.outlineVariant),
    boxShadow: [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.08),
        blurRadius: 24,
        offset: const Offset(0, 10),
      ),
    ],
  );
}
