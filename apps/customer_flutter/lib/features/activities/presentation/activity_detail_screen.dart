import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../activity_claims/data/activity_claim_models.dart';
import '../../activity_claims/data/activity_claim_repository.dart';
import '../../profile/data/profile_settings_models.dart';
import '../../profile/data/profile_settings_repository.dart';
import '../../reward_claims/presentation/claim_realtime_monitor.dart';
import '../data/activity_models.dart';
import '../data/activity_repository.dart';
import 'activity_error_message.dart';
import 'activity_localization.dart';
import 'activity_visual_tokens.dart';

Color _activityDetailPrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

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
    if (activityDetailRequiresPin(auth)) {
      final redirectPath = activityDetailPinRedirectPath(
        GoRouterState.of(context).uri,
      );
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go(redirectPath);
      });
      return const SizedBox.shrink();
    }

    final request = ActivityDetailRequest(
      slug: slug,
      authenticated:
          auth.isAuthenticated && !auth.pinRequired && !auth.pinSetupRequired,
    );
    final detailProvider = activityDetailProvider(request);
    listenForCustomerOperationalError<ActivityItem>(
      ref: ref,
      context: context,
      provider: detailProvider,
    );
    final activity = ref.watch(detailProvider);

    return AppShell(
      title: context.l10n.activityDetailTitle,
      currentPath: '/activities',
      backPath: backPath,
      showBottomNavigation: true,
      heroMinHeight: _ActivityDetailPageList.heroMinHeight,
      heroSheetOverlap: _ActivityDetailPageList.sheetOverlap,
      heroContent: const SizedBox.shrink(),
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

bool activityDetailRequiresPin(AuthController auth) {
  return auth.isAuthenticated && (auth.pinRequired || auth.pinSetupRequired);
}

String activityDetailPinRedirectPath(Uri currentUri) {
  return Uri(
    path: '/pin',
    queryParameters: {'redirect': currentUri.toString()},
  ).toString();
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
  String _activityNoticeMessage = '';
  bool _activityNoticeIsError = false;

  ActivityItem get activity => widget.activity;

  @override
  Widget build(BuildContext context) {
    ref.listen<int>(activityClaimRealtimeTickProvider, (previous, next) {
      if (previous == null || previous == next) return;
      ref.invalidate(activityDetailProvider(widget.request));
      if (activity.id.isNotEmpty) {
        ref.invalidate(activityAwardListProvider(activity.id));
      }
    });
    final resultAnnounced = activity.resultSummary?.isAnnounced == true;
    final resultHasArrived =
        resultAnnounced || _activityResultHasArrived(activity);
    final canLoadAwards =
        widget.authenticated && activity.id.isNotEmpty && resultHasArrived;
    final awardsProvider =
        canLoadAwards ? activityAwardListProvider(activity.id) : null;
    if (awardsProvider != null) {
      listenForCustomerOperationalError<List<ActivityAwardItem>>(
        ref: ref,
        context: context,
        provider: awardsProvider,
      );
    }
    final awards = awardsProvider == null
        ? const AsyncValue<List<ActivityAwardItem>>.data([])
        : ref.watch(awardsProvider);

    return _ActivityDetailPageList(
      children: [
        _ActivityHeroCard(activity: activity),
        const SizedBox(height: 14),
        if (_activityNoticeMessage.isNotEmpty) ...[
          _ActivityNoticePanel(
            message: _activityNoticeMessage,
            isError: _activityNoticeIsError,
          ),
          const SizedBox(height: 14),
        ],
        awards.when(
          data: (items) => _ActivityAwardStatusPanel(
            activity: activity,
            awards: items,
            authenticated: widget.authenticated,
            resultAnnounced: resultHasArrived,
            onClaim: _startClaim,
          ),
          loading: () => _ActivityAwardStatusPanel(
            activity: activity,
            awards: const [],
            authenticated: widget.authenticated,
            resultAnnounced: resultHasArrived,
            loading: true,
            onClaim: _startClaim,
          ),
          error: (_, __) => _ActivityAwardStatusPanel(
            activity: activity,
            awards: const [],
            authenticated: widget.authenticated,
            resultAnnounced: resultHasArrived,
            onClaim: _startClaim,
          ),
        ),
        if (activity.isCashback) ...[
          awards.when(
            data: (items) => _CashbackPanel(
              activity: activity,
              claimableAward: items
                  .where((award) => award.isCashback)
                  .where((award) => award.isClaimable)
                  .firstOrNull,
              onManualClaim: _startCashbackManualClaim,
              onAutoReward: _goAutoReward,
            ),
            loading: () => _CashbackPanel(
              activity: activity,
              onManualClaim: _startCashbackManualClaim,
              onAutoReward: _goAutoReward,
            ),
            error: (_, __) => _CashbackPanel(
              activity: activity,
              onManualClaim: _startCashbackManualClaim,
              onAutoReward: _goAutoReward,
            ),
          ),
        ] else if (activity.isLuckyBoard)
          _LuckyBoardPanel(
            activity: activity,
            authenticated: widget.authenticated,
            submitting: _submittingEntry,
            onSelect: _confirmNumber,
            onLogin: () {
              final redirect = Uri.encodeComponent(
                GoRouterState.of(context).uri.toString(),
              );
              context.go('/login?redirect=$redirect');
            },
          ),
      ],
    );
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
    setState(() {
      _submittingEntry = true;
      _activityNoticeMessage = '';
    });
    try {
      await ref.read(activityRepositoryProvider).createEntry(
            activityId: activity.id,
            predictionType: activity.numberBoard.predictionType,
            selectedNumber: number,
          );
      if (!mounted) return;
      _setActivityNotice(
        context.l10n.activitySubmitEntrySuccess,
        isError: false,
      );
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
      _setActivityNotice(message);
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
      backgroundColor: Colors.transparent,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.46),
      elevation: 0,
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

  Future<void> _startCashbackManualClaim(ActivityAwardItem? award) async {
    final redirect =
        Uri.encodeComponent(GoRouterState.of(context).uri.toString());
    if (!widget.authenticated) {
      context.go('/login?redirect=$redirect');
      return;
    }
    if (award == null) {
      _setActivityNotice(context.l10n.activityCashbackClaimNotReadyMessage);
      return;
    }
    await _startClaim(award);
  }

  void _goAutoReward() {
    final redirect =
        Uri.encodeComponent(GoRouterState.of(context).uri.toString());
    if (!widget.authenticated) {
      context.go('/login?redirect=$redirect');
      return;
    }
    context.go('/profile/auto-reward?redirect=$redirect');
  }

  String _errorCode(Object error) {
    return ApiErrorInfo.fromObject(error).code;
  }

  void _setActivityNotice(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _activityNoticeMessage = message;
      _activityNoticeIsError = isError;
    });
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
                      child: CustomerGradientButton.text(
                        onPressed: () => Navigator.of(context).pop(true),
                        height: 40,
                        fontSize: 14,
                        shadow: false,
                        label: l10n.activityConfirmNumberSubmit,
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

bool _activityResultHasArrived(ActivityItem activity, {DateTime? now}) {
  final resultAt = parseDateTime(activity.resultAt);
  if (resultAt == null) return false;
  return !(now ?? DateTime.now()).isBefore(resultAt);
}

class _ActivityDetailPageList extends StatelessWidget {
  const _ActivityDetailPageList({required this.children});

  static const heroMinHeight = customerReferenceCompactHeroHeight;
  static const sheetOverlap = 0.0;
  static const _bottomPadding = 112.0;

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.zero,
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        _ActivityDetailContentSheet(
          child: CustomerPageBody(
            top: 6,
            bottom: _bottomPadding,
            mobileHorizontal: 16,
            wideHorizontal: 16,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: children,
            ),
          ),
        ),
      ],
    );
  }
}

class _ActivityDetailContentSheet extends StatelessWidget {
  const _ActivityDetailContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 620),
        child: child,
      ),
    );
  }
}

class _ActivityDetailSurface extends StatelessWidget {
  const _ActivityDetailSurface({
    required this.child,
    this.borderColor,
    this.background,
    this.shadow = true,
  });

  final Widget child;
  final Color? borderColor;
  final Color? background;
  final bool shadow;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background ?? colorScheme.surface,
        border: Border.all(
          color:
              borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.70),
        ),
        borderRadius: BorderRadius.circular(18),
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.10),
                  blurRadius: 30,
                  offset: const Offset(0, 14),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: child,
      ),
    );
  }
}

class _ActivityNoticePanel extends StatelessWidget {
  const _ActivityNoticePanel({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError
        ? activityErrorForeground(colorScheme)
        : activitySuccessForeground(colorScheme);
    final border = isError
        ? activityErrorBorder(colorScheme)
        : colorScheme.primary.withValues(alpha: 0.24);
    final background = isError
        ? activityErrorTint(colorScheme)
        : activitySuccessTint(colorScheme);
    return _ActivityDetailSurface(
      shadow: false,
      background: background,
      borderColor: border,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: foreground,
              size: 21,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityHeroCard extends StatelessWidget {
  const _ActivityHeroCard({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final entryClosed = activityEntryClosed(activity);
    final colorScheme = Theme.of(context).colorScheme;
    final imageUrl = activity.detailImageUrl;
    return _ActivityDetailSurface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (imageUrl.isNotEmpty)
            ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 420),
              child: Image.network(
                imageUrl,
                width: double.infinity,
                fit: BoxFit.cover,
                frameBuilder: (
                  context,
                  child,
                  frame,
                  wasSynchronouslyLoaded,
                ) {
                  if (wasSynchronouslyLoaded || frame != null) return child;
                  return const ActivityImageLoadingFrame();
                },
                errorBuilder: (_, __, ___) => AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ActivityImageFallback(
                    isCashback: activity.isCashback,
                    iconSize: 52,
                  ),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _ActivityTypePill(
                  label: l10n.activityTypeLabel(activity.type),
                ),
                const SizedBox(height: 10),
                Text(
                  activityDisplayName(l10n, activity),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 10),
                Text(
                  activityConditionText(l10n, activity),
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        height: 1.55,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                const SizedBox(height: 12),
                _ActivityInfoRow(
                  icon: Icons.calendar_month_outlined,
                  label: activityGameLabel(l10n, activity),
                ),
                const SizedBox(height: 8),
                _ActivityInfoRow(
                  icon: Icons.schedule_rounded,
                  label: l10n.activityDetailResultTime(
                    activityResultTimeText(l10n, activity),
                  ),
                ),
                if (activity.isLuckyBoard) ...[
                  const SizedBox(height: 8),
                  _ActivityInfoRow(
                    icon: Icons.hourglass_bottom_rounded,
                    label: activityEntryDeadlineText(l10n, activity),
                    danger: entryClosed,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityTypePill extends StatelessWidget {
  const _ActivityTypePill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.primary,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _ActivityInfoRow extends StatelessWidget {
  const _ActivityInfoRow({
    required this.icon,
    required this.label,
    this.danger = false,
  });

  final IconData icon;
  final String label;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color =
        danger ? activityErrorForeground(colorScheme) : colorScheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _PanelHeading extends StatelessWidget {
  const _PanelHeading({
    required this.title,
    this.trailing,
  });

  final String title;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
          ),
        ),
        if (trailing != null) ...[
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              trailing!,
              textAlign: TextAlign.right,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                    height: 1.35,
                  ),
            ),
          ),
        ],
      ],
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
    final numberColor = won
        ? activitySuccessForeground(colorScheme)
        : lost
            ? activityWarningForeground(colorScheme)
            : colorScheme.primary;
    final winningNumbers = summary.winningNumbers.isEmpty
        ? [summary.winningNumber].where((number) => number.isNotEmpty).toList()
        : summary.winningNumbers;
    return _ActivityDetailSurface(
      shadow: false,
      borderColor: won
          ? colorScheme.primary.withValues(alpha: 0.24)
          : lost
              ? activityWarningBorder(colorScheme)
              : colorScheme.primary.withValues(alpha: 0.20),
      background: won
          ? activitySuccessTint(colorScheme)
          : lost
              ? activityWarningTint(colorScheme)
              : colorScheme.primary.withValues(alpha: 0.03),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    l10n.activityResultTitle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: colorScheme.primary,
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                const SizedBox(width: 10),
                Flexible(
                  child: Text(
                    won
                        ? l10n.activityResultCustomerWon(
                            formatBaht(summary.customerAwardAmount),
                          )
                        : lost
                            ? l10n.activityResultCustomerLost
                            : l10n.activityResultWinnerCount(
                                summary.winnerCount,
                              ),
                    textAlign: TextAlign.right,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 17,
                          fontWeight: FontWeight.w900,
                          height: 1.25,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final number in winningNumbers)
                  _ActivityResultNumberPill(
                    number: number,
                    color: numberColor,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              l10n.activityResultWinningNumber(
                l10n.activityPredictionLabel(summary.predictionType),
              ),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                    height: 1.45,
                  ),
            ),
            if (summary.customerWinningNumbers.isNotEmpty) ...[
              const SizedBox(height: 14),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface.withValues(alpha: 0.74),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: colorScheme.primary.withValues(alpha: 0.22),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          l10n.activityResultCustomerWinningNumbers,
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    color: colorScheme.onSurfaceVariant,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          summary.customerWinningNumbers.join(', '),
                          textAlign: TextAlign.right,
                          style:
                              Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: activitySuccessForeground(
                                      colorScheme,
                                    ),
                                    fontSize: 16,
                                    fontWeight: FontWeight.w900,
                                  ),
                        ),
                      ),
                    ],
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

class _ActivityResultNumberPill extends StatelessWidget {
  const _ActivityResultNumberPill({
    required this.number,
    required this.color,
  });

  final String number;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minWidth: 92,
          minHeight: 52,
        ),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Text(
            number,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 26,
                  fontWeight: FontWeight.w900,
                  color: color,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _LuckyBoardPanel extends StatelessWidget {
  const _LuckyBoardPanel({
    required this.activity,
    required this.authenticated,
    required this.submitting,
    required this.onSelect,
    required this.onLogin,
  });

  final ActivityItem activity;
  final bool authenticated;
  final bool submitting;
  final ValueChanged<String> onSelect;
  final VoidCallback onLogin;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final rights = activity.rights;
    final closed = activityEntryClosed(activity);
    final selectedEntries = _activeBoardEntries(activity).toList();
    final summary = closed
        ? l10n.activityLuckyPanelClosedSummary(activity.remainingNumbers)
        : l10n.activityLuckyPanelOpenSummary(
            rights.remainingCount,
            activity.remainingNumbers,
          );

    return _ActivityDetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeading(
              title: l10n.activityLuckyPanelTitle,
              trailing: summary,
            ),
            const SizedBox(height: 16),
            _LuckyRightsGrid(
              metrics: [
                MapEntry(
                  l10n.activityLuckyRightsEarned,
                  rights.earnedCount.toString(),
                ),
                MapEntry(
                  l10n.activityLuckyRightsUsed,
                  rights.usedCount.toString(),
                ),
                MapEntry(
                  l10n.activityLuckyTicketCount,
                  rights.ticketCount.toString(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            _ActivityEntryDeadlineBanner(
              closed: closed,
              title: closed
                  ? l10n.activityLuckyDeadlineClosedTitle
                  : l10n.activityLuckyDeadlineOpenTitle,
              detail: activityEntryDeadlineText(l10n, activity),
            ),
            if (activity.resultSummary?.isAnnounced == true) ...[
              const SizedBox(height: 16),
              _ActivityResultCard(summary: activity.resultSummary!),
            ],
            if (selectedEntries.isNotEmpty) ...[
              const SizedBox(height: 16),
              _SelectedNumbersPanel(activity: activity),
            ],
            if (activity.numberBoard.isReady) ...[
              const SizedBox(height: 16),
              _NumberBoardCard(
                activity: activity,
                submitting: submitting,
                enabled: authenticated,
                onSelect: onSelect,
              ),
            ],
            if (closed) ...[
              const SizedBox(height: 16),
              _ActivityParticipationNote(
                message: l10n.activityLuckyClosedNote,
                danger: true,
              ),
            ] else if (!authenticated) ...[
              const SizedBox(height: 16),
              _ActivityLoginLink(
                label: l10n.activityLuckyLoginLink,
                onPressed: onLogin,
              ),
            ] else if (rights.remainingCount < 1) ...[
              const SizedBox(height: 16),
              _ActivityParticipationNote(
                message: l10n.activityNumberBoardNoRights,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LuckyRightsGrid extends StatelessWidget {
  const _LuckyRightsGrid({required this.metrics});

  final List<MapEntry<String, String>> metrics;

  @override
  Widget build(BuildContext context) {
    final children = [
      for (final metric in metrics)
        _RightsMetric(label: metric.key, value: metric.value),
    ];
    if (MediaQuery.sizeOf(context).width <= 380) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            children[index],
            if (index != children.length - 1) const SizedBox(height: 10),
          ],
        ],
      );
    }
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var index = 0; index < children.length; index++) ...[
            Expanded(child: children[index]),
            if (index != children.length - 1) const SizedBox(width: 10),
          ],
        ],
      ),
    );
  }
}

class _ActivityEntryDeadlineBanner extends StatelessWidget {
  const _ActivityEntryDeadlineBanner({
    required this.closed,
    required this.title,
    required this.detail,
  });

  final bool closed;
  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final background =
        closed ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7ED);
    final border = closed ? const Color(0xFFFECACA) : const Color(0xFFFED7AA);
    final foreground =
        closed ? const Color(0xFFB42318) : const Color(0xFFC2410C);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: background,
        border: Border.all(color: border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.78),
                shape: BoxShape.circle,
              ),
              child: SizedBox(
                width: 38,
                height: 38,
                child: Icon(
                  closed ? Icons.access_time_filled : Icons.hourglass_top,
                  color: foreground,
                  size: 18,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: foreground,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    detail,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: foreground,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityParticipationNote extends StatelessWidget {
  const _ActivityParticipationNote({
    required this.message,
    this.danger = false,
  });

  final String message;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: danger ? const Color(0xFFFEF2F2) : const Color(0xFFFFF7E6),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color:
                    danger ? const Color(0xFFB42318) : const Color(0xFFB76B00),
                fontSize: 13,
                fontWeight: FontWeight.w900,
                height: 1.45,
              ),
        ),
      ),
    );
  }
}

class _ActivityLoginLink extends StatelessWidget {
  const _ActivityLoginLink({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: activityBrandActionFill(colorScheme),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onPressed,
        splashFactory: NoSplash.splashFactory,
        overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          child: Text(
            label,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: activityBrandActionForeground(colorScheme),
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.45,
                ),
          ),
        ),
      ),
    );
  }
}

class _ActivityAwardStatusPanel extends StatelessWidget {
  const _ActivityAwardStatusPanel({
    required this.activity,
    required this.awards,
    required this.authenticated,
    required this.resultAnnounced,
    required this.onClaim,
    this.loading = false,
  });

  final ActivityItem activity;
  final List<ActivityAwardItem> awards;
  final bool authenticated;
  final bool resultAnnounced;
  final ValueChanged<ActivityAwardItem> onClaim;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    if (!loading && awards.isEmpty && !resultAnnounced) {
      return const SizedBox.shrink();
    }

    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final variant = _awardStatusVariant();
    final colors = _awardStatusColors(variant, colorScheme);
    final icon = _awardStatusIcon(variant);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _ActivityDetailSurface(
        borderColor: colors.border,
        child: Stack(
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: colors.strip),
                ),
                child: const SizedBox(height: 5),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _PanelHeading(
                    title: l10n.activityAwardStatusTitle,
                    trailing: _awardCountText(l10n),
                  ),
                  const SizedBox(height: 12),
                  if (awards.isEmpty || loading)
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colors.background,
                        border: Border.all(color: colors.border),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(13),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            DecoratedBox(
                              decoration: BoxDecoration(
                                color: colors.iconBackground,
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: SizedBox(
                                width: 46,
                                height: 46,
                                child: Icon(icon, color: colors.iconForeground),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    loading
                                        ? l10n.activityAwardStatusPendingTitle
                                        : _emptyTitle(l10n),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(
                                          color: colorScheme.onSurface,
                                          fontWeight: FontWeight.w900,
                                          height: 1.25,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    loading
                                        ? l10n.activityAwardStatusPendingMessage
                                        : _emptyMessage(l10n),
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall
                                        ?.copyWith(
                                          color: colorScheme.onSurfaceVariant,
                                          fontWeight: FontWeight.w800,
                                          height: 1.45,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    for (final award in awards) ...[
                      _AwardRow(award: award, onClaim: onClaim),
                      if (award != awards.last) const SizedBox(height: 10),
                    ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _awardCountText(CustomerLocalizations l10n) {
    if (awards.isNotEmpty) return l10n.activityAwardStatusCount(awards.length);
    if (!authenticated) return l10n.activityAwardStatusLoginCount;
    if (loading || !resultAnnounced) {
      return l10n.activityAwardStatusPendingCount;
    }
    final status = activity.resultSummary?.customerStatus ?? '';
    if (status == 'not_joined') return l10n.activityAwardStatusNotJoinedCount;
    return l10n.activityAwardStatusNoRewardCount;
  }

  String _emptyTitle(CustomerLocalizations l10n) {
    if (!authenticated) return l10n.activityAwardStatusLoginTitle;
    final status = activity.resultSummary?.customerStatus ?? '';
    if (activity.isLuckyBoard && activity.resultSummary?.customerLost == true) {
      return l10n.activityAwardStatusMissedTitle;
    }
    if (status == 'not_joined') return l10n.activityAwardStatusNotJoinedTitle;
    if (!resultAnnounced) return l10n.activityAwardStatusPendingTitle;
    return l10n.activityAwardStatusNoRewardTitle;
  }

  String _emptyMessage(CustomerLocalizations l10n) {
    if (!authenticated) return l10n.activityAwardStatusLoginMessage;
    final status = activity.resultSummary?.customerStatus ?? '';
    if (activity.isLuckyBoard && activity.resultSummary?.customerLost == true) {
      return l10n.activityAwardStatusMissedMessage;
    }
    if (status == 'not_joined') return l10n.activityAwardStatusNotJoinedMessage;
    if (!resultAnnounced) return l10n.activityAwardStatusPendingMessage;
    return l10n.activityAwardStatusNoRewardMessage;
  }

  String _awardStatusVariant() {
    if (awards.any((award) => award.isClaimable)) return 'claimable';
    if (awards.any((award) => award.hasClaim)) return 'paid';
    if (awards.isNotEmpty) return 'awarded';
    if (!authenticated || !resultAnnounced || loading) return 'pending';
    if (activity.isLuckyBoard &&
        (activity.resultSummary?.customerLost == true ||
            activity.resultSummary?.customerStatus == 'not_joined')) {
      return 'missed';
    }
    return 'missed';
  }
}

({
  Color background,
  Color border,
  Color iconBackground,
  Color iconForeground,
  List<Color> strip
}) _awardStatusColors(String variant, ColorScheme colorScheme) {
  return switch (variant) {
    'claimable' || 'paid' || 'awarded' => (
        background: activitySuccessTint(colorScheme),
        border: colorScheme.primary.withValues(alpha: 0.24),
        iconBackground: activitySuccessTint(colorScheme),
        iconForeground: activitySuccessForeground(colorScheme),
        strip: [
          colorScheme.primary,
          Color.lerp(colorScheme.primary, colorScheme.secondary, 0.34) ??
              colorScheme.primary,
        ],
      ),
    'missed' => (
        background: activityErrorTint(colorScheme),
        border: activityErrorBorder(colorScheme),
        iconBackground: activityErrorTint(colorScheme),
        iconForeground: activityErrorForeground(colorScheme),
        strip: [
          colorScheme.error,
          Color.lerp(colorScheme.error, colorScheme.surface, 0.44) ??
              colorScheme.error,
        ],
      ),
    _ => (
        background: activityWarningTint(colorScheme),
        border: activityWarningBorder(colorScheme),
        iconBackground: activityWarningTint(colorScheme),
        iconForeground: activityWarningForeground(colorScheme),
        strip: [
          colorScheme.tertiary,
          Color.lerp(colorScheme.tertiary, colorScheme.surface, 0.44) ??
              colorScheme.tertiary,
        ],
      ),
  };
}

IconData _awardStatusIcon(String variant) {
  return switch (variant) {
    'claimable' => Icons.paid_outlined,
    'paid' => Icons.check_circle_outline,
    'awarded' => Icons.emoji_events_outlined,
    'missed' => Icons.cancel_outlined,
    _ => Icons.hourglass_bottom_rounded,
  };
}

class _AwardRow extends StatelessWidget {
  const _AwardRow({
    required this.award,
    required this.onClaim,
  });

  final ActivityAwardItem award;
  final ValueChanged<ActivityAwardItem> onClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primary.withValues(alpha: 0.03),
            colorScheme.surface,
          ],
        ),
        border: Border.all(
          color: colorScheme.primary.withValues(alpha: 0.12),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final narrow = constraints.maxWidth < 420;
            final copy = Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: const SizedBox(
                    width: 46,
                    height: 46,
                    child: Icon(Icons.card_giftcard),
                  ),
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

            final action = CustomerGradientButton.text(
              onPressed: () => onClaim(award),
              height: 42,
              fontSize: 14,
              horizontalPadding: 14,
              shadow: false,
              label: l10n.activityAwardClaimButton,
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
                SizedBox(width: 104, child: action),
              ],
            );
          },
        ),
      ),
    );
  }

  String _awardStatusText(BuildContext context, ActivityAwardItem award) {
    final l10n = context.l10n;
    if (award.isClaimable) return l10n.activityAwardReady;
    if (award.isPaid) return l10n.activityClaimStatusPaid;
    if (award.isApproved) return l10n.activityClaimStatusApproved;
    if (award.isRejected) return l10n.activityClaimStatusRejected;
    if (award.isCancelled) return l10n.activityClaimStatusCancelled;
    if (award.isSubmitted) return l10n.activityClaimStatusSubmitted;
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
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          activityAwardTitle(l10n, award),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 6),
        DecoratedBox(
          decoration: BoxDecoration(
            color: activitySuccessTint(colorScheme),
            border: Border.all(
              color: colorScheme.primary.withValues(alpha: 0.24),
            ),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Text(
              formatBaht(award.amount),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: activitySuccessForeground(colorScheme),
                    fontWeight: FontWeight.w900,
                    height: 1.05,
                  ),
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          status,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
        ),
      ],
    );
  }
}

String _cashbackMinimumText(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  final progress = activity.cashbackProgress;
  final minimumType = progress.minimumType.isNotEmpty
      ? progress.minimumType
      : activity.config.minimumType;
  if (minimumType == 'amount') {
    final amount = progress.minPurchaseAmount > 0
        ? progress.minPurchaseAmount
        : activity.config.minPurchaseAmount;
    return amount > 0 ? formatBaht(amount) : l10n.activityCashbackNoMinimum;
  }
  final ticketCount = progress.minTicketCount > 0
      ? progress.minTicketCount
      : activity.config.minTicketCount;
  return ticketCount > 0
      ? l10n.activityCashbackTickets(ticketCount)
      : l10n.activityCashbackNoMinimum;
}

String _cashbackRewardText(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  if (activity.estimatedCashbackAmount > 0) {
    return l10n.activityMetaCashbackEstimate(
      formatBaht(activity.estimatedCashbackAmount),
    );
  }
  if (activity.cashbackProgress.potentialAmount > 0) {
    return l10n.activityMetaCashbackEstimate(
      formatBaht(activity.cashbackProgress.potentialAmount),
    );
  }
  if (activity.config.fixedAmount > 0) {
    return l10n.activityMetaCashbackEstimate(
      formatBaht(activity.config.fixedAmount),
    );
  }
  return l10n.activityCashbackRewardFallback;
}

class _CashbackPanel extends StatelessWidget {
  const _CashbackPanel({
    required this.activity,
    required this.onManualClaim,
    required this.onAutoReward,
    this.claimableAward,
  });

  final ActivityItem activity;
  final ActivityAwardItem? claimableAward;
  final ValueChanged<ActivityAwardItem?> onManualClaim;
  final VoidCallback onAutoReward;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final progress = activity.cashbackProgress;
    final resultTime = activityResultTimeText(l10n, activity);
    final minimum = _cashbackMinimumText(l10n, activity);
    final rewardText = _cashbackRewardText(l10n, activity);
    final eligible = progress.isEligible;
    final displayEstimatedAmount = progress.estimatedAmount > 0
        ? progress.estimatedAmount
        : activity.estimatedCashbackAmount > 0
            ? activity.estimatedCashbackAmount
            : activity.config.fixedAmount > 0
                ? activity.config.fixedAmount
                : progress.potentialAmount;

    return _ActivityDetailSurface(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PanelHeading(
              title: l10n.activityCashbackPanelTitle,
              trailing: eligible
                  ? l10n.activityCashbackProgressEligible
                  : l10n.activityCashbackProgressPending,
            ),
            const SizedBox(height: 16),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.10),
                    colorScheme.primary.withValues(alpha: 0.03),
                  ],
                ),
                border: Border.all(
                  color: colorScheme.primary.withValues(alpha: 0.18),
                ),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      rewardText,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      eligible
                          ? l10n.activityCashbackEligibleTitle
                          : l10n.activityCashbackPendingTitle,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
                          ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      eligible
                          ? l10n.activityCashbackEligibleDescription(resultTime)
                          : l10n.activityCashbackPendingDescription(
                              minimum,
                              resultTime,
                            ),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            height: 1.45,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    colorScheme.primary,
                    colorScheme.primary.withValues(alpha: 0.9),
                  ],
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: colorScheme.primary.withValues(alpha: 0.18),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.activityCashbackExpectedLabel,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                            color:
                                colorScheme.onPrimary.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w800,
                          ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      formatBaht(displayEstimatedAmount),
                      style:
                          Theme.of(context).textTheme.headlineMedium?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w900,
                                height: 1.05,
                              ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      l10n.activityCashbackExpectedHint(resultTime),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color:
                                colorScheme.onPrimary.withValues(alpha: 0.82),
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final children = [
                  _CashbackMetric(
                    label: l10n.activityCashbackPurchaseAmount,
                    value: formatBaht(progress.purchaseAmount),
                  ),
                  _CashbackMetric(
                    label: l10n.activityCashbackTicketCount,
                    value: l10n.activityCashbackTickets(progress.ticketCount),
                  ),
                  _CashbackMetric(
                    label: l10n.activityCashbackMinimum,
                    value: minimum,
                  ),
                ];

                return GridView.count(
                  crossAxisCount: compact ? 1 : 3,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  childAspectRatio: compact ? 4.6 : 1.22,
                  children: children,
                );
              },
            ),
            const SizedBox(height: 12),
            _CashbackDetailList(
              rows: [
                MapEntry(l10n.activityCashbackDetailRewardType, rewardText),
                MapEntry(
                  l10n.activityCashbackDetailMainCondition,
                  activityConditionText(l10n, activity),
                ),
                MapEntry(
                  l10n.activityCashbackDetailCalculationTime,
                  resultTime,
                ),
                MapEntry(
                  l10n.activityCashbackDetailPayout,
                  l10n.activityCashbackDetailPayoutValue,
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxWidth < 420;
                final children = [
                  _CashbackActionButton(
                    icon: Icons.touch_app_outlined,
                    title: l10n.activityCashbackManualClaimTitle,
                    subtitle: claimableAward == null
                        ? l10n.activityCashbackManualClaimPending
                        : l10n.activityCashbackManualClaimReady,
                    onPressed: () => onManualClaim(claimableAward),
                  ),
                  _CashbackActionButton(
                    icon: Icons.bolt_outlined,
                    title: l10n.activityCashbackAutoRewardTitle,
                    subtitle: l10n.activityCashbackAutoRewardSubtitle,
                    onPressed: onAutoReward,
                  ),
                ];

                if (compact) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      children.first,
                      const SizedBox(height: 10),
                      children.last,
                    ],
                  );
                }

                return Row(
                  children: [
                    Expanded(child: children.first),
                    const SizedBox(width: 10),
                    Expanded(child: children.last),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _CashbackMetric extends StatelessWidget {
  const _CashbackMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              value,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CashbackDetailList extends StatelessWidget {
  const _CashbackDetailList({required this.rows});

  final List<MapEntry<String, String>> rows;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.78),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Column(
          children: [
            for (final row in rows) ...[
              _CashbackDetailRow(label: row.key, value: row.value),
              if (row != rows.last)
                Divider(
                  height: 1,
                  color: colorScheme.outlineVariant.withValues(alpha: 0.62),
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CashbackDetailRow extends StatelessWidget {
  const _CashbackDetailRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 108,
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                    height: 1.45,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CashbackActionButton extends StatelessWidget {
  const _CashbackActionButton({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Row(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(icon, color: colorScheme.primary, size: 20),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.36),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SelectedNumbersPanel extends StatelessWidget {
  const _SelectedNumbersPanel({required this.activity});

  final ActivityItem activity;

  @override
  Widget build(BuildContext context) {
    final entries = _activeBoardEntries(activity).toList(growable: false);
    if (entries.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return _ActivityDetailSurface(
      borderColor: colorScheme.primary.withValues(alpha: 0.20),
      background: colorScheme.primary.withValues(alpha: 0.03),
      shadow: false,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l10n.activitySelectedNumbersTitle,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colorScheme.primary,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.surface,
                    border: Border.all(
                      color: colorScheme.primary.withValues(alpha: 0.22),
                    ),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                    child: Text(
                      l10n.activitySelectedNumbersCount(entries.length),
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in entries)
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: colorScheme.surface,
                      border: Border.all(
                        color: colorScheme.primary.withValues(alpha: 0.42),
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      child: Text(
                        entry.selectedNumber,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.primary,
                              fontWeight: FontWeight.w900,
                              height: 1,
                            ),
                      ),
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
    this.enabled = true,
  });

  final ActivityItem activity;
  final bool submitting;
  final bool enabled;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final board = activity.numberBoard;
    if (!board.isReady) return const SizedBox.shrink();

    final selected = _selectedBoardNumbers(activity);
    final canSelect = enabled &&
        !submitting &&
        !activity.rights.entryClosed &&
        activity.rights.remainingCount > 0;

    return _ActivityDetailSurface(
      shadow: false,
      borderColor: colorScheme.outlineVariant.withValues(alpha: 0.78),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.activityNumberBoardTitle(
                          l10n.activityPredictionLabel(board.predictionType),
                        ),
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              color: colorScheme.onSurface,
                              fontWeight: FontWeight.w900,
                            ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        l10n.activityNumberBoardSummary(
                          board.digits == 3 ? '000-999' : '00-99',
                          board.remainingCount.toString(),
                          board.totalCount.toString(),
                        ),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              fontWeight: FontWeight.w800,
                              height: 1.35,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.primary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Text(
                      activity.rights.entryClosed
                          ? l10n.activityNumberBoardEntryClosedHint
                          : l10n.activityNumberBoardReservedHint,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: colorScheme.primary,
                            fontWeight: FontWeight.w900,
                            height: 1,
                          ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = _numberBoardColumns(
                  width: MediaQuery.sizeOf(context).width,
                  digits: board.digits,
                );
                final tileHeight = _numberBoardTileHeight(
                  width: width,
                  columns: crossAxisCount,
                );

                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
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
  final compact = width <= 380;
  if (digits == 3) {
    return compact ? 3 : 4;
  }
  return compact ? 4 : 5;
}

double _numberBoardTileHeight({
  required double width,
  required int columns,
}) {
  const gap = 8.0;
  final cellWidth = (width - (gap * (columns - 1))) / columns;
  final aspectHeight = cellWidth * 0.72;
  if (aspectHeight < 42) return 42;
  if (aspectHeight > 54) return 54;
  return aspectHeight;
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
            ? activityErrorTint(colorScheme)
            : colorScheme.surfaceContainerHighest.withValues(alpha: 0.36);
    final foreground = selected
        ? colorScheme.onPrimary
        : reserved
            ? activityErrorForeground(colorScheme)
            : colorScheme.onSurface;
    final border = reserved
        ? activityErrorBorder(colorScheme)
        : colorScheme.outlineVariant.withValues(alpha: 0.82);

    return Material(
      color: background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: border),
      ),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            Center(
              child: Text(
                number,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: foreground,
                    ),
              ),
            ),
            if (reserved)
              Positioned(
                right: 4,
                top: 4,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: activityErrorForeground(colorScheme),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 5,
                      vertical: 3,
                    ),
                    child: Text(
                      context.l10n.activityNumberBoardReservedShort,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onError,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

Iterable<ActivityEntry> _activeBoardEntries(ActivityItem activity) {
  final predictionType = activity.numberBoard.predictionType;
  if (predictionType.isEmpty) return const [];
  return activity.entries
      .where((entry) => entry.predictionType == predictionType)
      .where((entry) => !entry.isCancelled)
      .where((entry) => entry.selectedNumber.isNotEmpty);
}

Set<String> _selectedBoardNumbers(ActivityItem activity) {
  return _activeBoardEntries(activity)
      .map((entry) => entry.selectedNumber)
      .toSet();
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
    final colorScheme = Theme.of(context).colorScheme;
    final bottom = MediaQuery.of(context).viewInsets.bottom;
    final height = MediaQuery.sizeOf(context).height;
    final maxHeight = (height - bottom - 12).clamp(240.0, height).toDouble();
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final biometricEnabled = bootstrap.maybeWhen(
      data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
      orElse: () => false,
    );
    final reviewerName = bootstrap.maybeWhen(
      data: (data) => data.siteName.trim(),
      orElse: () => '',
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(12, 12, 12, bottom + 12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 390, maxHeight: maxHeight),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              boxShadow: [
                BoxShadow(
                  color: colorScheme.shadow.withValues(alpha: 0.22),
                  blurRadius: 48,
                  offset: const Offset(0, 24),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Material(
                color: colorScheme.surface,
                child: Padding(
                  padding: const EdgeInsets.all(14),
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
                            onDigit: (digit) =>
                                _appendPinDigit(digit, settings),
                            onBackspace: _removePinDigit,
                            onBiometric: () =>
                                _submitWithBiometric(settings.bankAccount),
                          )
                        : _ClaimSelectPanel(
                            award: widget.award,
                            method: _method,
                            bankAccount: settings.bankAccount,
                            walletId: settings.walletId,
                            walletName: settings.walletName,
                            reviewerName: reviewerName,
                            returnPath: widget.returnPath,
                            error: _error,
                            submitting: _submitting,
                            onCancel: () => Navigator.of(context).pop(),
                            onMethodChanged: (method) => setState(() {
                              _method = method;
                              _error = '';
                            }),
                            onContinue: () =>
                                _continueToPin(settings.bankAccount),
                          ),
                    loading: () => _ClaimProfileLoadingPanel(
                      eyebrow: l10n.activityClaimSheetEyebrow,
                      title: l10n.activityClaimSheetTitle,
                      message: l10n.activityClaimProfileLoading,
                    ),
                    error: (_, __) => _ClaimProfileErrorPanel(
                      eyebrow: l10n.activityClaimSheetEyebrow,
                      title: l10n.activityClaimSheetTitle,
                      message: l10n.activityClaimProfileLoadFailed,
                      onRetry: () =>
                          ref.invalidate(customerProfileSettingsProvider),
                    ),
                  ),
                ),
              ),
            ),
          ),
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
      final pinSetupRequiredMessage =
          context.l10n.activityClaimPinSetupRequired;
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
                : code == 'pin_setup_required' || code == 'pin_required'
                    ? pinSetupRequiredMessage
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
                localizedReason: mobileBiometricPromptReason(
                  ref.read(mobileBootstrapProvider).valueOrNull,
                  purpose: 'activity_claim',
                  fallback: context.l10n.pinBiometricReason,
                ),
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

class _ClaimProfileLoadingPanel extends StatelessWidget {
  const _ClaimProfileLoadingPanel({
    required this.eyebrow,
    required this.title,
    required this.message,
  });

  final String eyebrow;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('activity-claim-profile-loading'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              eyebrow,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(height: 6),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                    fontWeight: FontWeight.w900,
                  ),
            ),
          ),
          const SizedBox(height: 22),
          const ActivityLoadingMark(
            icon: Icons.account_balance_wallet_outlined,
            size: 52,
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                  height: 1.4,
                ),
          ),
          const SizedBox(height: 12),
          const ActivityProgressLine(width: 138),
        ],
      ),
    );
  }
}

class _ClaimProfileErrorPanel extends StatelessWidget {
  const _ClaimProfileErrorPanel({
    required this.eyebrow,
    required this.title,
    required this.message,
    required this.onRetry,
  });

  final String eyebrow;
  final String title;
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      key: const Key('activity-claim-profile-error'),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            eyebrow,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 16),
          _ClaimErrorMessage(message: message),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.center,
            child: OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(132, 44),
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.36),
                ),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              child: Text(context.l10n.commonRetry),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimSelectPanel extends StatelessWidget {
  const _ClaimSelectPanel({
    required this.award,
    required this.method,
    required this.bankAccount,
    required this.walletId,
    required this.walletName,
    required this.reviewerName,
    required this.returnPath,
    required this.error,
    required this.submitting,
    required this.onCancel,
    required this.onMethodChanged,
    required this.onContinue,
  });

  final ActivityAwardItem award;
  final ActivityClaimPayoutMethod method;
  final RewardBankAccount bankAccount;
  final String walletId;
  final String walletName;
  final String reviewerName;
  final String returnPath;
  final String error;
  final bool submitting;
  final VoidCallback onCancel;
  final ValueChanged<ActivityClaimPayoutMethod> onMethodChanged;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  l10n.activityClaimSheetEyebrow,
                  style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w900,
                      ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                tooltip: l10n.commonCancel,
                onPressed: submitting ? null : onCancel,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(34),
                  minimumSize: const Size.square(34),
                  maximumSize: const Size.square(34),
                  padding: EdgeInsets.zero,
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.72),
                  foregroundColor: colorScheme.onSurfaceVariant,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.close, size: 18),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            l10n.activityClaimSheetTitle,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w900,
                ),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  colorScheme.primary,
                  Color.lerp(
                        colorScheme.primary,
                        colorScheme.secondary,
                        0.36,
                      ) ??
                      colorScheme.primary,
                ],
              ),
              borderRadius: BorderRadius.circular(18),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.activityClaimAvailableAmount,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimary.withValues(alpha: 0.82),
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatBaht(award.amount),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                          color: colorScheme.onPrimary,
                          height: 1.05,
                        ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          _PayoutOptionTile(
            method: ActivityClaimPayoutMethod.walletCredit,
            selected: method == ActivityClaimPayoutMethod.walletCredit,
            title: _activityClaimWalletOptionTitle(
              l10n,
              walletId,
              walletName,
            ),
            subtitle: l10n.activityClaimWalletSubtitle(reviewerName),
            icon: Icons.account_balance_wallet,
            onTap: onMethodChanged,
          ),
          const SizedBox(height: 6),
          _PayoutOptionTile(
            method: ActivityClaimPayoutMethod.bankTransfer,
            selected: method == ActivityClaimPayoutMethod.bankTransfer,
            title: bankAccount.isComplete
                ? _activityClaimBankOptionTitle(l10n, bankAccount)
                : l10n.activityClaimBankTitle,
            subtitle: bankAccount.isComplete
                ? l10n.activityClaimBankReady
                : l10n.activityClaimBankMissing,
            icon: Icons.account_balance,
            disabled: !bankAccount.isComplete,
            onTap: onMethodChanged,
          ),
          if (method == ActivityClaimPayoutMethod.bankTransfer &&
              bankAccount.isComplete) ...[
            const SizedBox(height: 6),
            _ClaimBankPreview(bankAccount: bankAccount),
          ],
          if (!bankAccount.isComplete) ...[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => context.go(
                  _profileRewardBankRedirectPath(returnPath),
                ),
                style: TextButton.styleFrom(
                  backgroundColor: colorScheme.primary.withValues(alpha: 0.10),
                  foregroundColor: colorScheme.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                child: Text(l10n.activityClaimSetupBank),
              ),
            ),
          ],
          if (error.isNotEmpty) ...[
            const SizedBox(height: 8),
            _ClaimErrorMessage(message: error),
          ],
          const SizedBox(height: 2),
          _ClaimActionButtons(
            submitting: submitting,
            onCancel: onCancel,
            onContinue: onContinue,
          ),
        ],
      ),
    );
  }
}

class _ClaimErrorMessage extends StatelessWidget {
  const _ClaimErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: activityErrorTint(colorScheme),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: activityErrorForeground(colorScheme),
                fontSize: 13,
                fontWeight: FontWeight.w800,
                height: 1.45,
              ),
        ),
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

String _activityClaimWalletOptionTitle(
  CustomerLocalizations l10n,
  String walletId,
  String walletName,
) {
  final suffix = _activityClaimWalletSuffix(walletId);
  if (suffix.isEmpty) return l10n.activityClaimWalletTitleFor(walletName);
  return l10n.activityClaimWalletAccountTitle(
    suffix,
    walletName: walletName,
  );
}

String _activityClaimWalletSuffix(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  final suffix =
      digits.length <= 3 ? digits : digits.substring(digits.length - 3);
  return suffix.padLeft(3, '0');
}

String _activityClaimBankOptionTitle(
  CustomerLocalizations l10n,
  RewardBankAccount bankAccount,
) {
  final bankName = bankAccount.bankName.trim();
  if (bankName.isEmpty) return l10n.activityClaimBankTitle;
  return l10n.claimBankOptionTitle(
    bankName,
    _activityClaimAccountLast4(bankAccount.accountNumber),
  );
}

String _activityClaimAccountLast4(String value) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '----';
  return digits.length <= 4 ? digits : digits.substring(digits.length - 4);
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
    final iconBackground = method == ActivityClaimPayoutMethod.walletCredit
        ? _activityDetailPrimaryTint(colorScheme)
        : activityInfoTint(colorScheme);
    final iconForeground = method == ActivityClaimPayoutMethod.walletCredit
        ? colorScheme.primary
        : activityInfoForeground(colorScheme);

    return Material(
      color: selected
          ? colorScheme.primary.withValues(alpha: 0.08)
          : colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: borderColor, width: selected ? 1.3 : 1),
      ),
      child: InkWell(
        onTap: disabled ? null : () => onTap(method),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(12),
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
                            fontSize: 15,
                            fontWeight: FontWeight.w900,
                            height: 1.25,
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
                            fontWeight: FontWeight.w800,
                            height: 1.35,
                          ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 42,
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: disabled
                      ? colorScheme.surfaceContainerHighest
                      : iconBackground,
                ),
                child: Icon(
                  icon,
                  color:
                      disabled ? colorScheme.onSurfaceVariant : iconForeground,
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
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final accountName = bankAccount.accountName.trim().isEmpty
        ? l10n.activityClaimBankRecipientFallback
        : bankAccount.accountName.trim();
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.34),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(alpha: 0.82),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.credit_card_outlined,
              color: Theme.of(context).colorScheme.primary,
              size: 21,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  bankAccount.bankName,
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: colorScheme.onSurface,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        height: 1.25,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$accountName · ${bankAccount.maskedNumber}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        height: 1.35,
                      ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ClaimActionButtons extends StatelessWidget {
  const _ClaimActionButtons({
    required this.submitting,
    required this.onCancel,
    required this.onContinue,
  });

  final bool submitting;
  final VoidCallback onCancel;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final cancel = OutlinedButton(
      onPressed: submitting ? null : onCancel,
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(42),
        foregroundColor: colorScheme.primary,
        side: BorderSide(color: colorScheme.primary.withValues(alpha: 0.42)),
        shape: const StadiumBorder(),
        textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w900,
            ),
      ),
      child: Text(context.l10n.commonCancel),
    );
    final next = CustomerGradientButton.text(
      onPressed: submitting ? null : onContinue,
      height: 42,
      fontSize: 14,
      shadow: false,
      label: context.l10n.commonNext,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= 300) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cancel,
              const SizedBox(height: 10),
              next,
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: cancel),
            const SizedBox(width: 10),
            Expanded(child: next),
          ],
        );
      },
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
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              IconButton(
                onPressed: submitting ? null : onBack,
                style: IconButton.styleFrom(
                  fixedSize: const Size.square(38),
                  minimumSize: const Size.square(38),
                  maximumSize: const Size.square(38),
                  padding: EdgeInsets.zero,
                  backgroundColor: colorScheme.surfaceContainerHighest
                      .withValues(alpha: 0.72),
                  foregroundColor: colorScheme.onSurfaceVariant,
                  shape: const CircleBorder(),
                ),
                icon: const Icon(Icons.arrow_back_ios_new, size: 17),
                tooltip: context.l10n.commonBack,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            color: colorScheme.onSurface,
                            fontWeight: FontWeight.w900,
                          ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                            fontWeight: FontWeight.w700,
                            height: 1.35,
                          ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 46),
            ],
          ),
          const SizedBox(height: 20),
          _PinDots(count: pin.length),
          const SizedBox(height: 8),
          Text(
            context.l10n.activityClaimPinProgress(pin.length),
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w800,
                ),
          ),
          if (error.isNotEmpty) ...[
            const SizedBox(height: 12),
            _ClaimErrorMessage(message: error),
          ],
          const SizedBox(height: 18),
          if (biometricEnabled) ...[
            OutlinedButton.icon(
              onPressed: submitting ? null : onBiometric,
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
                foregroundColor: colorScheme.primary,
                side: BorderSide(
                  color: colorScheme.primary.withValues(alpha: 0.32),
                ),
                shape: const StadiumBorder(),
                textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
              icon: const Icon(Icons.face_retouching_natural),
              label: Text(context.l10n.activityClaimBiometricButton),
            ),
            const SizedBox(height: 14),
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

class _PinDots extends StatelessWidget {
  const _PinDots({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var index = 0; index < 6; index += 1)
          Container(
            width: 12,
            height: 12,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: index < count
                  ? colorScheme.primary
                  : colorScheme.outlineVariant,
            ),
          ),
      ],
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
    final colorScheme = Theme.of(context).colorScheme;
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      childAspectRatio: 1.62,
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
              style: TextButton.styleFrom(
                foregroundColor: colorScheme.onSurface,
                disabledForegroundColor:
                    colorScheme.onSurfaceVariant.withValues(alpha: 0.58),
                shape: const CircleBorder(),
                textStyle: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
              ),
              child: key == 'back'
                  ? const Icon(Icons.backspace_outlined, size: 23)
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
    final colorScheme = Theme.of(context).colorScheme;
    return _ActivityDetailPageList(
      children: [
        _ActivityDetailSurface(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 34),
            child: missing
                ? Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        l10n.activityMissingTitle,
                        textAlign: TextAlign.center,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        l10n.activityMissingMessage,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                              height: 1.45,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      const SizedBox(height: 18),
                      _ActivityPrimaryPill(
                        label: l10n.activityMissingBackToActivities,
                        onPressed: () => context.go('/activities'),
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
                              ? colorScheme.error
                              : colorScheme.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
          ),
        ),
      ],
    );
  }
}

class _ActivityPrimaryPill extends StatelessWidget {
  const _ActivityPrimaryPill({
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final radius = BorderRadius.circular(999);
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 220, minHeight: 47),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          gradient: LinearGradient(
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.38) ??
                  colorScheme.primary,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: colorScheme.primary.withValues(alpha: 0.22),
              blurRadius: 22,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: radius,
            onTap: onPressed,
            child: SizedBox(
              height: 47,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Center(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                          color: colorScheme.onPrimary,
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull {
    final iterator = this.iterator;
    if (!iterator.moveNext()) return null;
    return iterator.current;
  }
}
