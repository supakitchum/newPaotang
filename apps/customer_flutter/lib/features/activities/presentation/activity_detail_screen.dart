import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../activity_claims/data/activity_claim_models.dart';
import '../../activity_claims/data/activity_claim_repository.dart';
import '../../profile/data/profile_settings_models.dart';
import '../../profile/data/profile_settings_repository.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';
import 'activity_error_message.dart';
import 'activity_localization.dart';

class ActivityDetailScreen extends ConsumerWidget {
  const ActivityDetailScreen({
    required this.slug,
    super.key,
    this.backPath = '/activities',
  });

  final String slug;
  final String backPath;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authControllerProvider);
    final request = ActivityDetailRequest(
      slug: slug,
      authenticated: auth.isAuthenticated && !auth.pinRequired,
    );
    final activity = ref.watch(activityDetailProvider(request));

    return AppShell(
      title: context.l10n.activityDetailTitle,
      currentPath: '/activities',
      backPath: backPath,
      child: activity.when(
        data: (item) {
          if (item.id.isEmpty) {
            return const _ActivityDetailStateView(missing: true);
          }
          return _ActivityDetailBody(
            activity: item,
            request: request,
            authenticated: request.authenticated,
          );
        },
        loading: () => const _ActivityDetailStateView(),
        error: (error, __) => _ActivityDetailStateView(
          error: true,
          message: activityErrorMessage(
            error,
            context.l10n.activityDetailLoadFailed,
          ),
        ),
      ),
    );
  }
}

String activityDetailBackPath({
  required String from,
  required String gameId,
}) {
  if (from != 'history') return '/activities';

  final trimmedGameId = gameId.trim();
  return Uri(
    path: '/activities/history',
    queryParameters: trimmedGameId.isEmpty ? null : {'game_id': trimmedGameId},
  ).toString();
}

class _ActivityDetailBody extends ConsumerStatefulWidget {
  const _ActivityDetailBody({
    required this.activity,
    required this.request,
    required this.authenticated,
  });

  final ActivityItem activity;
  final ActivityDetailRequest request;
  final bool authenticated;

  @override
  ConsumerState<_ActivityDetailBody> createState() =>
      _ActivityDetailBodyState();
}

class _ActivityDetailBodyState extends ConsumerState<_ActivityDetailBody> {
  bool _submittingEntry = false;

  ActivityItem get activity => widget.activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final resultAnnounced = activity.resultSummary?.isAnnounced == true;
    final awards = !resultAnnounced || activity.id.isEmpty
        ? const AsyncValue<List<ActivityAwardItem>>.data([])
        : ref.watch(activityAwardListProvider(activity.id));

    return RefreshIndicator(
      onRefresh: _refresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          CustomerPageBody(
            maxWidth: 640,
            top: 12,
            mobileHorizontal: 10,
            wideHorizontal: 10,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (activity.imageUrl.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: AspectRatio(
                      aspectRatio: 16 / 9,
                      child:
                          Image.network(activity.imageUrl, fit: BoxFit.cover),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Chip(label: Text(l10n.activityTypeLabel(activity.type))),
                    if (activity.hasRight)
                      Chip(
                        label: Text(l10n.activityDetailHasRight),
                        backgroundColor:
                            Theme.of(context).colorScheme.primaryContainer,
                      ),
                    if (activity.rights.entryClosed)
                      Chip(
                        label: Text(l10n.activityDetailEntryClosed),
                        backgroundColor:
                            Theme.of(context).colorScheme.errorContainer,
                      ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  activityDisplayName(l10n, activity),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                if (activity.resultSummary?.isAnnounced == true) ...[
                  _ActivityResultCard(summary: activity.resultSummary!),
                  const SizedBox(height: 12),
                ],
                _ActivityStatusCard(activity: activity),
                const SizedBox(height: 12),
                if (resultAnnounced)
                  awards.when(
                    data: (items) => _ActivityAwardsSection(
                      awards: items,
                      onClaim: _startClaim,
                    ),
                    loading: () => const SizedBox.shrink(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                _ConditionCard(activity: activity),
                if (activity.isLuckyBoard) ...[
                  const SizedBox(height: 12),
                  if (widget.authenticated) ...[
                    _RightsCard(activity: activity),
                    const SizedBox(height: 12),
                    _SelectedNumbersPanel(entries: activity.entries),
                    const SizedBox(height: 12),
                    _NumberBoardCard(
                      activity: activity,
                      submitting: _submittingEntry,
                      onSelect: _confirmNumber,
                    ),
                  ] else
                    _LoginToJoinCard(slug: widget.request.slug),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _refresh() async {
    ref.invalidate(activityDetailProvider(widget.request));
    if (activity.id.isNotEmpty) {
      ref.invalidate(activityAwardListProvider(activity.id));
    }
    await Future<void>.delayed(const Duration(milliseconds: 120));
  }

  Future<void> _confirmNumber(String number) async {
    final l10n = context.l10n;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => _NumberConfirmDialog(
        number: number,
        message: l10n.activityConfirmNumberMessage(
          number,
          l10n.activityPredictionLabel(activity.numberBoard.predictionType),
        ),
      ),
    );

    if (confirmed == true) {
      await _submitEntry(number);
    }
  }

  Future<void> _submitEntry(String number) async {
    if (_submittingEntry || activity.id.isEmpty) return;
    setState(() => _submittingEntry = true);
    try {
      await ref.read(activityRepositoryProvider).createEntry(
            activityId: activity.id,
            predictionType: activity.numberBoard.predictionType,
            selectedNumber: number,
          );
      if (!mounted) return;
      _showSnack(context.l10n.activitySubmitEntrySuccess);
      ref.invalidate(activityDetailProvider(widget.request));
    } catch (error) {
      if (!mounted) return;
      final code = _errorCode(error);
      final message = code == 'activity_entry_closed'
          ? context.l10n.activitySubmitEntryClosed
          : activityErrorMessage(
              error,
              context.l10n.activitySubmitEntryFailed,
            );
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      _showSnack(message);
    } finally {
      if (mounted) setState(() => _submittingEntry = false);
    }
  }

  Future<void> _startClaim(ActivityAwardItem award) async {
    final returnPath = GoRouterState.of(context).uri.toString();
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) => _ActivityClaimSheet(
        award: award,
        returnPath: returnPath,
        onClaimed: (claimId) {
          ref.invalidate(activityAwardListProvider(activity.id));
          if (claimId.isNotEmpty) {
            context.go('/activity-claims/$claimId');
          }
        },
      ),
    );
  }

  String _errorCode(Object error) {
    return ApiErrorInfo.fromObject(error).code;
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _NumberConfirmDialog extends StatelessWidget {
  const _NumberConfirmDialog({
    required this.number,
    required this.message,
  });

  final String number;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  l10n.activityConfirmNumberEyebrow,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.activityConfirmNumberTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 16),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primaryContainer.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      number,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.displaySmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.45,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.activityConfirmNumberSubmit),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            top: 8,
            child: IconButton(
              tooltip: l10n.commonCancel,
              onPressed: () => Navigator.of(context).pop(false),
              icon: const Icon(Icons.close),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityStatusCard extends StatelessWidget {
  const _ActivityStatusCard({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final title = activity.isCashback
        ? l10n.activityStatusCashbackTitle
        : l10n.activityStatusNumberTitle;
    final value = activity.isCashback
        ? (activity.estimatedCashbackAmount > 0
            ? formatBaht(activity.estimatedCashbackAmount)
            : l10n.activityStatusCalculating)
        : l10n.activityStatusRemainingNumbers(activity.remainingNumbers);
    final subtitle = activity.isCashback
        ? l10n.activityStatusCashbackSubtitle
        : activity.rights.entryClosed
            ? l10n.activityStatusBoardClosed
            : l10n.activityStatusBoardAvailable;

    return Card(
      margin: EdgeInsets.zero,
      color: colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onPrimaryContainer,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityResultCard extends StatelessWidget {
  const _ActivityResultCard({required this.summary});

  final ActivityResultSummary summary;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final won = summary.customerWon;
    final lost = summary.customerLost;
    return Card(
      margin: EdgeInsets.zero,
      color: won
          ? const Color(0xFFE8F8EF)
          : lost
              ? colorScheme.errorContainer
              : null,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activityResultTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              summary.winningNumber,
              style: Theme.of(context).textTheme.displaySmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    color: won ? const Color(0xFF087443) : colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            Text(
              l10n.activityResultWinningNumber(
                l10n.activityPredictionLabel(summary.predictionType),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              won
                  ? l10n.activityResultCustomerWon(
                      formatBaht(summary.customerAwardAmount),
                    )
                  : lost
                      ? l10n.activityResultCustomerLost
                      : l10n.activityResultWinnerCount(summary.winnerCount),
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityAwardsSection extends StatelessWidget {
  const _ActivityAwardsSection({
    required this.awards,
    required this.onClaim,
  });

  final List<ActivityAwardItem> awards;
  final ValueChanged<ActivityAwardItem> onClaim;

  @override
  Widget build(BuildContext context) {
    if (awards.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        children: [
          for (final award in awards)
            Card(
              margin: EdgeInsets.zero,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final narrow = constraints.maxWidth < 420;
                    final copy = Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        CircleAvatar(
                          backgroundColor:
                              Theme.of(context).colorScheme.primaryContainer,
                          child: const Icon(Icons.card_giftcard),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: _AwardCopy(
                            award: award,
                            status: _awardStatusText(context, award),
                          ),
                        ),
                      ],
                    );
                    if (!award.isClaimable) return copy;

                    final action = FilledButton(
                      onPressed: () => onClaim(award),
                      child: Text(l10n.activityAwardClaimButton),
                    );
                    if (narrow) {
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          copy,
                          const SizedBox(height: 14),
                          action,
                        ],
                      );
                    }

                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(child: copy),
                        const SizedBox(width: 12),
                        action,
                      ],
                    );
                  },
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _awardStatusText(BuildContext context, ActivityAwardItem award) {
    final l10n = context.l10n;
    if (award.isClaimable) return l10n.activityAwardReady;
    if (award.hasClaim) return l10n.activityAwardClaimed;
    return l10n.activityAwardProcessing;
  }
}

class _AwardCopy extends StatelessWidget {
  const _AwardCopy({required this.award, required this.status});

  final ActivityAwardItem award;
  final String status;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activityAwardTitle(l10n, award),
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 4),
        Text(
          formatBaht(award.amount),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
                color: const Color(0xFF087443),
              ),
        ),
        const SizedBox(height: 4),
        Text(status),
      ],
    );
  }
}

class _ConditionCard extends StatelessWidget {
  const _ConditionCard({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activityConditionTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 10),
            Text(
              activityConditionText(l10n, activity),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RightsCard extends StatelessWidget {
  const _RightsCard({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rights = activity.rights;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activityRightsTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RightsMetric(
                    label: l10n.activityRightsEarned,
                    value: rights.earnedCount.toString(),
                  ),
                ),
                Expanded(
                  child: _RightsMetric(
                    label: l10n.activityRightsUsed,
                    value: rights.usedCount.toString(),
                  ),
                ),
                Expanded(
                  child: _RightsMetric(
                    label: l10n.activityRightsRemaining,
                    value: rights.remainingCount.toString(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              l10n.activityRightsTicketSummary(
                rights.ticketCount,
                rights.consumedTicketCount,
              ),
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            if (rights.entryDeadlineAt != null) ...[
              const SizedBox(height: 6),
              Text(
                l10n.activityRightsDeadline(
                  formatLocalizedDateTime(
                    rights.entryDeadlineAt,
                    localeTag(l10n.locale),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RightsMetric extends StatelessWidget {
  const _RightsMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Text(
          value,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
      ],
    );
  }
}

class _SelectedNumbersPanel extends StatelessWidget {
  const _SelectedNumbersPanel({required this.entries});

  final List<ActivityEntry> entries;

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activitySelectedNumbersTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in entries)
                  Chip(
                    label: Text(
                      entry.selectedNumber,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NumberBoardCard extends StatelessWidget {
  const _NumberBoardCard({
    required this.activity,
    required this.submitting,
    required this.onSelect,
  });

  final ActivityItem activity;
  final bool submitting;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final board = activity.numberBoard;
    if (!board.isReady) return const SizedBox.shrink();

    final selected = activity.entries
        .map((entry) => entry.selectedNumber)
        .where((number) => number.isNotEmpty)
        .toSet();
    final canSelect = !submitting &&
        !activity.rights.entryClosed &&
        activity.rights.remainingCount > 0;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.activityNumberBoardTitle(
                l10n.activityPredictionLabel(board.predictionType),
              ),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              l10n.activityNumberBoardSummary(
                board.digits == 3 ? '000-999' : '00-99',
                board.remainingCount.toString(),
                board.totalCount.toString(),
              ),
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              canSelect
                  ? l10n.activityNumberBoardCanSelect
                  : activity.rights.entryClosed
                      ? l10n.activityNumberBoardClosed
                      : l10n.activityNumberBoardNoRights,
            ),
            const SizedBox(height: 6),
            Text(
              activity.rights.entryClosed
                  ? l10n.activityNumberBoardEntryClosedHint
                  : l10n.activityNumberBoardReservedHint,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w800,
                  ),
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = _numberBoardColumns(
                  width: width,
                  digits: board.digits,
                );
                final rows = (board.totalCount / crossAxisCount).ceil();
                final visibleRows = board.digits == 3 ? 8 : 10;
                final tileHeight = board.digits == 3 ? 34.0 : 38.0;
                final maxHeight =
                    (tileHeight * visibleRows) + (8 * (visibleRows - 1));
                final contentHeight = (tileHeight * rows) + (8 * (rows - 1));
                final height = contentHeight < maxHeight
                    ? contentHeight.clamp(tileHeight, maxHeight)
                    : maxHeight;

                return SizedBox(
                  height: height,
                  child: GridView.builder(
                    itemCount: board.totalCount,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: crossAxisCount,
                      mainAxisSpacing: 8,
                      crossAxisSpacing: 8,
                      mainAxisExtent: tileHeight,
                    ),
                    itemBuilder: (context, index) {
                      final number = board.numberAt(index);
                      final isMine = selected.contains(number);
                      final isReserved = board.isReserved(number) && !isMine;
                      return _NumberTile(
                        number: number,
                        selected: isMine,
                        reserved: isReserved,
                        enabled: canSelect && !isReserved && !isMine,
                        onTap: () => onSelect(number),
                      );
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

int _numberBoardColumns({required double width, required int digits}) {
  if (digits == 3) {
    if (width >= 760) return 10;
    if (width >= 560) return 8;
    if (width >= 420) return 6;
    return 5;
  }
  if (width >= 760) return 12;
  if (width >= 560) return 10;
  if (width >= 420) return 8;
  return 6;
}

class _NumberTile extends StatelessWidget {
  const _NumberTile({
    required this.number,
    required this.selected,
    required this.reserved,
    required this.enabled,
    required this.onTap,
  });

  final String number;
  final bool selected;
  final bool reserved;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final background = selected
        ? colorScheme.primary
        : reserved
            ? colorScheme.errorContainer
            : colorScheme.surfaceContainerHighest;
    final foreground = selected
        ? colorScheme.onPrimary
        : reserved
            ? colorScheme.onErrorContainer
            : colorScheme.onSurface;

    return Material(
      color: background,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            number,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w900,
                  color: foreground,
                ),
          ),
        ),
      ),
    );
  }
}

class _LoginToJoinCard extends StatelessWidget {
  const _LoginToJoinCard({required this.slug});

  final String slug;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 36),
            const SizedBox(height: 10),
            Text(
              l10n.activityLoginToJoinTitle,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: () => context.go('/login?redirect=/activities/$slug'),
              child: Text(l10n.activityLoginToJoinButton),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityClaimSheet extends ConsumerStatefulWidget {
  const _ActivityClaimSheet({
    required this.award,
    required this.returnPath,
    required this.onClaimed,
  });

  final ActivityAwardItem award;
  final String returnPath;
  final ValueChanged<String> onClaimed;

  @override
  ConsumerState<_ActivityClaimSheet> createState() =>
      _ActivityClaimSheetState();
}

class _ActivityClaimSheetState extends ConsumerState<_ActivityClaimSheet> {
  ActivityClaimPayoutMethod _method = ActivityClaimPayoutMethod.walletCredit;
  bool _pinStep = false;
  bool _submitting = false;
  String _pin = '';
  String _error = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(customerProfileSettingsProvider);
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final biometricEnabled = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
          orElse: () => false,
        );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: profile.when(
        data: (settings) => _pinStep
            ? _PinConfirmPanel(
                title: l10n.activityClaimPinTitle,
                subtitle: l10n.activityClaimPinSubtitle,
                pin: _pin,
                error: _error,
                submitting: _submitting,
                biometricEnabled: biometricEnabled,
                onBack: () => setState(() {
                  _pinStep = false;
                  _pin = '';
                  _error = '';
                }),
                onDigit: (digit) => _appendPinDigit(digit, settings),
                onBackspace: _removePinDigit,
                onBiometric: () => _submitWithBiometric(settings.bankAccount),
              )
            : _ClaimSelectPanel(
                award: widget.award,
                method: _method,
                bankAccount: settings.bankAccount,
                returnPath: widget.returnPath,
                error: _error,
                submitting: _submitting,
                onMethodChanged: (method) => setState(() {
                  _method = method;
                  _error = '';
                }),
                onContinue: () => _continueToPin(settings.bankAccount),
              ),
        loading: () => const SizedBox(
          height: 180,
          child: Center(child: CircularProgressIndicator()),
        ),
        error: (_, __) => Padding(
          padding: const EdgeInsets.all(20),
          child: Text(l10n.activityClaimProfileLoadFailed),
        ),
      ),
    );
  }

  void _continueToPin(RewardBankAccount bankAccount) {
    if (_method == ActivityClaimPayoutMethod.bankTransfer &&
        !bankAccount.isComplete) {
      setState(() => _error = context.l10n.activityClaimBankRequired);
      return;
    }
    setState(() {
      _pinStep = true;
      _pin = '';
      _error = '';
    });
  }

  Future<void> _appendPinDigit(
    String digit,
    CustomerProfileSettings settings,
  ) async {
    if (_submitting || _pin.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) {
      return;
    }
    setState(() {
      _error = '';
      _pin += digit;
    });
    if (_pin.length == 6) await _submit(settings.bankAccount);
  }

  void _removePinDigit() {
    if (_submitting || _pin.isEmpty) return;
    setState(() {
      _error = '';
      _pin = _pin.substring(0, _pin.length - 1);
    });
  }

  Future<void> _submit(
    RewardBankAccount bankAccount, {
    String pinAssertionToken = '',
  }) async {
    setState(() => _submitting = true);
    try {
      final claim = await ref.read(activityClaimRepositoryProvider).create(
            awardId: widget.award.id,
            payoutMethod: _method,
            pin: pinAssertionToken.isEmpty ? _pin : '',
            pinAssertionToken: pinAssertionToken,
            bankAccount: bankAccount,
          );
      if (!mounted) return;
      Navigator.of(context).pop();
      widget.onClaimed(claim.id);
    } catch (error) {
      if (!mounted) return;
      final code = _errorCode(error);
      final pinInvalidMessage = context.l10n.activityClaimPinInvalid;
      final pinLockedMessage = context.l10n.activityClaimPinLocked;
      final failedMessage = context.l10n.activityClaimSubmitFailed;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _pin = '';
        _error = code == 'pin_invalid'
            ? pinInvalidMessage
            : code == 'pin_locked'
                ? pinLockedMessage
                : activityErrorMessage(error, failedMessage);
      });
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitWithBiometric(RewardBankAccount bankAccount) async {
    if (_submitting) return;
    setState(() {
      _pin = '';
      _error = '';
    });
    try {
      final token =
          await ref.read(biometricAuthServiceProvider).requestPinAssertion(
                purpose: 'activity_claim',
                localizedReason: context.l10n.pinBiometricReason,
              );
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(() => _error = context.l10n.activityClaimBiometricUnavailable);
        return;
      }
      await _submit(bankAccount, pinAssertionToken: token);
    } catch (error) {
      if (!mounted) return;
      final failedMessage = context.l10n.activityClaimBiometricFailed;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
        handlePinRedirect: false,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() => _error = failedMessage);
    }
  }

  String _errorCode(Object error) {
    return ApiErrorInfo.fromObject(error).code;
  }
}

class _ClaimSelectPanel extends StatelessWidget {
  const _ClaimSelectPanel({
    required this.award,
    required this.method,
    required this.bankAccount,
    required this.returnPath,
    required this.error,
    required this.submitting,
    required this.onMethodChanged,
    required this.onContinue,
  });

  final ActivityAwardItem award;
  final ActivityClaimPayoutMethod method;
  final RewardBankAccount bankAccount;
  final String returnPath;
  final String error;
  final bool submitting;
  final ValueChanged<ActivityClaimPayoutMethod> onMethodChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Theme.of(context).dividerColor,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Text(
            l10n.activityClaimSheetEyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            l10n.activityClaimSheetTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          Card(
            color: Theme.of(context).colorScheme.primaryContainer,
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l10n.activityClaimAvailableAmount),
                  const SizedBox(height: 6),
                  Text(
                    formatBaht(award.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          _PayoutOptionTile(
            method: ActivityClaimPayoutMethod.walletCredit,
            selected: method == ActivityClaimPayoutMethod.walletCredit,
            title: l10n.activityClaimWalletTitle,
            subtitle: l10n.activityClaimWalletSubtitle,
            icon: Icons.account_balance_wallet,
            onTap: onMethodChanged,
          ),
          const SizedBox(height: 8),
          _PayoutOptionTile(
            method: ActivityClaimPayoutMethod.bankTransfer,
            selected: method == ActivityClaimPayoutMethod.bankTransfer,
            title: l10n.activityClaimBankTitle,
            subtitle: bankAccount.isComplete
                ? '${bankAccount.bankName} ${bankAccount.maskedNumber}'
                : l10n.activityClaimBankMissing,
            icon: Icons.account_balance,
            disabled: !bankAccount.isComplete,
            onTap: onMethodChanged,
          ),
          if (method == ActivityClaimPayoutMethod.bankTransfer &&
              bankAccount.isComplete) ...[
            const SizedBox(height: 8),
            _ClaimBankPreview(bankAccount: bankAccount),
          ],
          if (!bankAccount.isComplete) ...[
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => context.go(
                _profileRewardBankRedirectPath(returnPath),
              ),
              icon: const Icon(Icons.edit),
              label: Text(l10n.activityClaimSetupBank),
            ),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      submitting ? null : () => Navigator.of(context).pop(),
                  child: Text(l10n.commonCancel),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: submitting ? null : onContinue,
                  child: Text(l10n.commonNext),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _profileRewardBankRedirectPath(String returnPath) {
  final trimmed = returnPath.trim();
  final safeReturn = trimmed.startsWith('/') && !trimmed.startsWith('//')
      ? trimmed
      : '/activities';
  return Uri(
    path: '/profile/reward-bank',
    queryParameters: {'redirect': safeReturn},
  ).toString();
}

class _PayoutOptionTile extends StatelessWidget {
  const _PayoutOptionTile({
    required this.method,
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  final ActivityClaimPayoutMethod method;
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final ValueChanged<ActivityClaimPayoutMethod> onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final borderColor = selected
        ? colorScheme.primary
        : colorScheme.outlineVariant.withValues(alpha: 0.9);
    final foreground = disabled
        ? colorScheme.onSurfaceVariant.withValues(alpha: 0.58)
        : colorScheme.onSurface;

    return Material(
      color: selected
          ? colorScheme.primaryContainer.withValues(alpha: 0.42)
          : colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: borderColor, width: selected ? 1.4 : 1),
      ),
      child: InkWell(
        onTap: disabled ? null : () => onTap(method),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Container(
                width: 20,
                height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: selected ? colorScheme.primary : colorScheme.outline,
                    width: 2,
                  ),
                ),
                child: selected
                    ? Center(
                        child: Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: colorScheme.primary,
                          ),
                        ),
                      )
                    : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: disabled
                                ? colorScheme.onSurfaceVariant
                                    .withValues(alpha: 0.58)
                                : colorScheme.onSurfaceVariant,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 38,
                height: 38,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: disabled
                      ? colorScheme.surfaceContainerHighest
                      : colorScheme.primaryContainer,
                ),
                child: Icon(
                  icon,
                  color: disabled
                      ? colorScheme.onSurfaceVariant
                      : colorScheme.primary,
                  size: 21,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ClaimBankPreview extends StatelessWidget {
  const _ClaimBankPreview({required this.bankAccount});

  final RewardBankAccount bankAccount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          const Icon(Icons.credit_card_outlined),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bankAccount.bankName,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 2),
                Text(
                  '${bankAccount.accountName} · ${bankAccount.maskedNumber}',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PinConfirmPanel extends StatelessWidget {
  const _PinConfirmPanel({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.error,
    required this.submitting,
    required this.biometricEnabled,
    required this.onBack,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final String title;
  final String subtitle;
  final String pin;
  final String error;
  final bool submitting;
  final bool biometricEnabled;
  final VoidCallback onBack;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: submitting ? null : onBack,
                icon: const Icon(Icons.arrow_back),
                tooltip: context.l10n.commonBack,
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            List.generate(6, (index) => index < pin.length ? '●' : '○')
                .join(' '),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  letterSpacing: 0,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            context.l10n.activityClaimPinProgress(pin.length),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              error,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          if (biometricEnabled) ...[
            OutlinedButton.icon(
              onPressed: submitting ? null : onBiometric,
              icon: const Icon(Icons.face_retouching_natural),
              label: Text(context.l10n.activityClaimBiometricButton),
            ),
            const SizedBox(height: 12),
          ],
          _PinKeypad(
            enabled: !submitting,
            onDigit: onDigit,
            onBackspace: onBackspace,
          ),
        ],
      ),
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.enabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.8,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        for (final key in keys)
          if (key.isEmpty)
            const SizedBox.shrink()
          else
            TextButton(
              onPressed: !enabled
                  ? null
                  : key == 'back'
                      ? onBackspace
                      : () => onDigit(key),
              child: key == 'back'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(key),
            ),
      ],
    );
  }
}

class _ActivityDetailStateView extends StatelessWidget {
  const _ActivityDetailStateView({
    this.error = false,
    this.missing = false,
    this.message = '',
  });

  final bool error;
  final bool missing;
  final String message;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        CustomerPageBody(
          maxWidth: 640,
          top: 12,
          mobileHorizontal: 10,
          wideHorizontal: 10,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(14, 54, 14, 24),
            child: Center(
              child: missing
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          l10n.activityMissingTitle,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          l10n.activityMissingMessage,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onSurfaceVariant,
                                    height: 1.45,
                                  ),
                        ),
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: () => context.go('/activities'),
                          child: Text(l10n.activityMissingBackToActivities),
                        ),
                      ],
                    )
                  : Text(
                      error
                          ? (message.trim().isEmpty
                              ? l10n.activityDetailLoadFailed
                              : message.trim())
                          : l10n.activityDetailLoading,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: error
                                ? Theme.of(context).colorScheme.error
                                : Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
