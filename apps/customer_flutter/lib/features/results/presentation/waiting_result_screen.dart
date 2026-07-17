import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/tenant_brand_header.dart';
import '../data/result_models.dart';
import '../data/result_repository.dart';
import 'result_widgets.dart';

typedef WaitingResultPlayerBuilder = Widget Function(String videoId);

final waitingResultPlayerBuilderProvider =
    Provider<WaitingResultPlayerBuilder>((ref) {
  return (videoId) => WaitingResultYoutubePlayer(videoId: videoId);
});

class WaitingResultScreen extends ConsumerStatefulWidget {
  const WaitingResultScreen({
    super.key,
    this.showSaleClosedNotice = false,
    this.routePath = '/waiting-result',
  });

  final bool showSaleClosedNotice;
  final String routePath;

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
    listenForCustomerOperationalError<RewardResultBundle>(
      ref: ref,
      context: context,
      provider: currentResultProvider,
    );
    final result = ref.watch(currentResultProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final configuredProduct = bootstrap?.lotteryProductLabel.trim() ?? '';
    final productLabel = configuredProduct.isEmpty
        ? context.l10n.ticketStubSeriesLabel
        : configuredProduct;

    return AppShell(
      title: context.l10n.waitingResultTitle,
      currentPath: '/tickets',
      showBottomNavigation: true,
      fullScreen: true,
      child: _WaitingResultPage(
        result: result,
        productLabel: productLabel,
        live: bootstrap?.live,
        onRetryResult: () => ref.invalidate(currentResultProvider),
        onTickets: () => context.go('/tickets'),
        onResult: () => context.go('/result'),
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
      context.go(widget.routePath);
    });
  }
}

class _WaitingResultPage extends StatelessWidget {
  const _WaitingResultPage({
    required this.result,
    required this.productLabel,
    required this.live,
    required this.onRetryResult,
    required this.onTickets,
    required this.onResult,
  });

  final AsyncValue<RewardResultBundle> result;
  final String productLabel;
  final MobileLiveConfig? live;
  final VoidCallback onRetryResult;
  final VoidCallback onTickets;
  final VoidCallback onResult;

  @override
  Widget build(BuildContext context) {
    return _WaitingResultBackground(
      child: SafeArea(
        bottom: false,
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 76, 20, 120),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: Column(
                        children: [
                          _WaitingResultBrand(productLabel: productLabel),
                          const SizedBox(height: 28),
                          _WaitingResultCopy(result: result),
                          const SizedBox(height: 28),
                          _WaitingResultReward(
                            result: result,
                            onRetry: onRetryResult,
                          ),
                          const SizedBox(height: 28),
                          _WaitingResultLiveCard(live: live),
                          const SizedBox(height: 28),
                          _WaitingResultActions(
                            onTickets: onTickets,
                            onResult: onResult,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _WaitingResultBackground extends StatelessWidget {
  const _WaitingResultBackground({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          stops: [0, 0.42, 1],
          colors: [
            Color(0xFFE8F3FF),
            Color(0xFFF7FBFF),
            Color(0xFFFFF7DD),
          ],
        ),
      ),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xD1FFFFFF), Color(0xF5F5F9FF)],
          ),
        ),
        child: child,
      ),
    );
  }
}

class _WaitingResultBrand extends StatelessWidget {
  const _WaitingResultBrand({required this.productLabel});

  final String productLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const TenantBrandLogo(),
        const SizedBox(width: 14),
        _WaitingResultProductMark(label: productLabel),
      ],
    );
  }
}

class _WaitingResultProductMark extends StatelessWidget {
  const _WaitingResultProductMark({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: AppTheme.primaryLink(colorScheme.primary),
                fontSize: 34,
                fontWeight: FontWeight.w800,
                height: 1,
                letterSpacing: 0,
              ),
        ),
        Transform.translate(
          offset: const Offset(-5, 2),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.tertiary,
              shape: BoxShape.circle,
            ),
            child: const SizedBox.square(dimension: 8),
          ),
        ),
      ],
    );
  }
}

class _WaitingResultCopy extends StatelessWidget {
  const _WaitingResultCopy({required this.result});

  final AsyncValue<RewardResultBundle> result;

  @override
  Widget build(BuildContext context) {
    final viewportWidth = MediaQuery.sizeOf(context).width;
    final primary = Theme.of(context).colorScheme.primary;
    final titleSize = viewportWidth >= 768
        ? 58.0
        : viewportWidth >= 600
            ? 48.0
            : 34.0;
    final resolved = result.valueOrNull != null &&
        waitingResultHasCurrentReward(result.valueOrNull!);

    return Column(
      children: [
        Text(
          context.l10n.waitingResultSaleClosed,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF4B6689),
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
        ),
        const SizedBox(height: 10),
        Text(
          resolved
              ? context.l10n.waitingResultResolved
              : context.l10n.waitingResultPending,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.displaySmall?.copyWith(
                color: AppTheme.primaryOutlineBorder(primary),
                fontSize: titleSize,
                fontWeight: FontWeight.w800,
                height: 1.08,
              ),
        ),
      ],
    );
  }
}

bool waitingResultHasCurrentReward(RewardResultBundle bundle) {
  final reward = bundle.selectedResult;
  if (reward == null || !reward.hasResolvedResult) return false;
  final currentId = bundle.currentGame?.id.trim() ?? '';
  return currentId.isEmpty || reward.id.trim() == currentId;
}

RewardResultGame waitingResultDisplayGame(RewardResultBundle bundle) {
  final reward = bundle.selectedResult;
  final current = bundle.currentGame;
  final currentId = current?.id.trim() ?? '';
  if (reward != null && (currentId.isEmpty || reward.id.trim() == currentId)) {
    return reward;
  }
  return current?.toPendingRewardGame() ??
      const RewardResultGame(
        id: 'pending',
        name: '',
        status: '',
        resultStatus: '',
        officialStatus: '',
        completionPercent: 0,
        drawAt: null,
        rewards: [],
      );
}

class _WaitingResultReward extends StatelessWidget {
  const _WaitingResultReward({required this.result, required this.onRetry});

  final AsyncValue<RewardResultBundle> result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return result.when(
      data: (bundle) => ResultSummaryCard(
        result: waitingResultDisplayGame(bundle),
        variant: ResultSummaryCardVariant.featured,
        link: '/result/full',
      ),
      loading: () => _WaitingResultResultState(
        loading: true,
        message: context.l10n.resultLoading,
      ),
      error: (error, _) => _WaitingResultResultState(
        message: customerErrorMessage(error, context.l10n.commonLoadFailed),
        onRetry: onRetry,
      ),
    );
  }
}

class _WaitingResultResultState extends StatelessWidget {
  const _WaitingResultResultState({
    required this.message,
    this.loading = false,
    this.onRetry,
  });

  final String message;
  final bool loading;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(minHeight: 168),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (loading)
            CustomerLoadingMark(
              width: 34,
              height: 22,
              semanticLabel: message,
            )
          else
            const Icon(
              Icons.error_outline,
              color: Color(0xFFDC3545),
              size: 30,
            ),
          const SizedBox(height: 10),
          Text(
            message,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: const Color(0xFF20385F),
                  fontWeight: FontWeight.w700,
                ),
          ),
          if (onRetry != null) ...[
            const SizedBox(height: 14),
            OutlinedButton(
              onPressed: onRetry,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.primaryOutlineText(primary),
                minimumSize: const Size(0, 44),
                padding: const EdgeInsets.symmetric(horizontal: 24),
                side: BorderSide(
                  color: AppTheme.primaryOutlineBorder(primary),
                ),
                shape: const StadiumBorder(),
                textStyle: const TextStyle(fontWeight: FontWeight.w600),
              ),
              child: Text(context.l10n.commonRetry),
            ),
          ],
        ],
      ),
    );
  }
}

class _WaitingResultLiveCard extends ConsumerWidget {
  const _WaitingResultLiveCard({required this.live});

  final MobileLiveConfig? live;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final videoId = waitingResultYoutubeVideoId(live);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0x1F087FF0)),
        borderRadius: BorderRadius.circular(8),
        boxShadow: const [
          BoxShadow(
            color: Color(0x14213755),
            blurRadius: 24,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.smart_display,
                color: Color(0xFFE62117),
                size: 24,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  context.l10n.waitingResultLiveTitle,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: const Color(0xFF20385F),
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          if (videoId != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: const Color(0xFF10213B),
                child: ref.watch(waitingResultPlayerBuilderProvider)(videoId),
              ),
            )
          else
            Container(
              constraints: const BoxConstraints(minHeight: 124),
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: const Color(0xFFF5F9FF),
                borderRadius: BorderRadius.circular(8),
              ),
              alignment: Alignment.center,
              child: Text(
                context.l10n.waitingResultLiveEmpty,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF4B6689),
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

String? waitingResultYoutubeVideoId(MobileLiveConfig? live) {
  if (live == null) return null;
  for (final raw in [
    live.waitingResultYoutubeEmbedUrl,
    live.waitingResultYoutubeUrl,
  ]) {
    final value = raw.trim();
    if (value.isEmpty) continue;
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(value)) return value;
    final uri = Uri.tryParse(value);
    if (uri == null || !{'http', 'https'}.contains(uri.scheme.toLowerCase())) {
      continue;
    }
    final host = uri.host.toLowerCase();
    final segments = uri.pathSegments.where((part) => part.isNotEmpty).toList();
    String candidate = '';
    if (_isYoutubeHost(host, 'youtu.be')) {
      candidate = segments.isEmpty ? '' : segments.first;
    } else if (_isYoutubeHost(host, 'youtube.com') ||
        _isYoutubeHost(host, 'youtube-nocookie.com')) {
      final route = segments.isEmpty ? '' : segments.first.toLowerCase();
      if (route == 'watch') {
        candidate = uri.queryParameters['v'] ?? '';
      } else if ({'embed', 'live', 'shorts', 'v'}.contains(route) &&
          segments.length > 1) {
        candidate = segments[1];
      }
    }
    if (RegExp(r'^[A-Za-z0-9_-]{11}$').hasMatch(candidate)) return candidate;
  }
  return null;
}

bool _isYoutubeHost(String host, String domain) {
  return host == domain || host.endsWith('.$domain');
}

class WaitingResultYoutubePlayer extends StatefulWidget {
  const WaitingResultYoutubePlayer({required this.videoId, super.key});

  final String videoId;

  @override
  State<WaitingResultYoutubePlayer> createState() =>
      _WaitingResultYoutubePlayerState();
}

class _WaitingResultYoutubePlayerState
    extends State<WaitingResultYoutubePlayer> {
  late YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = _createController();
  }

  @override
  void didUpdateWidget(covariant WaitingResultYoutubePlayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.videoId == widget.videoId) return;
    _controller.close();
    _controller = _createController();
  }

  YoutubePlayerController _createController() {
    return YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      credentialless: true,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
        enableCaption: true,
        playsInline: true,
        privacyEnhancedMode: true,
        strictRelatedVideos: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return YoutubePlayer(
      controller: _controller,
      aspectRatio: 16 / 9,
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
    final primary = Theme.of(context).colorScheme.primary;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 360),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          CustomerGradientButton(
            height: 50,
            fontSize: 16,
            fontWeight: FontWeight.w700,
            onPressed: onTickets,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.confirmation_number_outlined, size: 20),
                const SizedBox(width: 8),
                Text(context.l10n.waitingResultMyTickets),
              ],
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onResult,
            icon: const Icon(Icons.emoji_events_outlined, size: 20),
            label: Text(context.l10n.waitingResultCheckResult),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppTheme.primaryOutlineText(primary),
              minimumSize: const Size.fromHeight(50),
              side: BorderSide(
                color: AppTheme.primaryOutlineBorder(primary),
              ),
              shape: const StadiumBorder(),
              textStyle: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
