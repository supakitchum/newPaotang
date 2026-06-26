import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../results/data/result_models.dart';
import '../../results/data/result_repository.dart';

const saleClosedNoticeQuery = 'sale_closed';
const waitingResultPath = '/waiting-result';

class SaleClosureGuard extends ConsumerStatefulWidget {
  const SaleClosureGuard({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<SaleClosureGuard> createState() => _SaleClosureGuardState();
}

class _SaleClosureGuardState extends ConsumerState<SaleClosureGuard> {
  Timer? _timer;
  CurrentGame? _currentGame;
  bool _loading = false;
  bool _saleClosedAlertShown = false;

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleRouteChanged());
  }

  @override
  void didUpdateWidget(covariant SaleClosureGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routeInformationProvider.removeListener(
      _handleRouteChanged,
    );
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    _currentGame = null;
    _handleRouteChanged();
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _handleRouteChanged() {
    final location =
        widget.router.routeInformationProvider.value.uri.toString();
    final path = Uri.tryParse(location)?.path ?? location;
    if (!saleClosureShouldWatchPath(path)) {
      _timer?.cancel();
      _timer = null;
      return;
    }

    _timer ??= Timer.periodic(
      const Duration(seconds: 1),
      (_) => _checkSaleClosure(),
    );
    _checkSaleClosure();
  }

  Future<void> _checkSaleClosure() async {
    if (!mounted || _loading) return;
    final location =
        widget.router.routeInformationProvider.value.uri.toString();
    final path = Uri.tryParse(location)?.path ?? location;
    if (!saleClosureShouldWatchPath(path)) return;

    if (_currentGame == null) {
      _loading = true;
      try {
        _currentGame = await ref.read(resultRepositoryProvider).currentGame();
      } finally {
        _loading = false;
      }
      if (!mounted) return;
    }

    final redirect = saleClosureRedirectPath(
      path: path,
      gameStatus: _currentGame?.status ?? '',
      saleCloseAt: _currentGame?.saleCloseAt,
      now: DateTime.now(),
    );
    if (redirect == null) {
      _saleClosedAlertShown = false;
      return;
    }
    if (!_saleClosedAlertShown) {
      _saleClosedAlertShown = true;
      ref.read(appAlertControllerProvider.notifier).show(
            title: context.l10n.waitingResultSaleClosed,
            message: context.l10n.saleClosureAlertMessage,
            variant: AppAlertVariant.warning,
          );
    }
    if (location == redirect) return;
    widget.router.go(redirect);
  }
}

bool saleClosureShouldWatchPath(String path) {
  return path == '/buy' ||
      path.startsWith('/buy/') ||
      path == '/cart' ||
      path == '/checkout';
}

String? saleClosureRedirectPath({
  required String path,
  required String gameStatus,
  required Object? saleCloseAt,
  required DateTime now,
}) {
  if (!saleClosureShouldWatchPath(path)) return null;
  if (path == waitingResultPath) return null;

  final status = gameStatus.trim().toLowerCase();
  final saleClose = parseDateTime(saleCloseAt);
  final saleClosedByTime = saleClose != null && !now.isBefore(saleClose);
  final saleClosedByStatus = {
    'closed',
    'drawing',
    'result_checking',
    'result_verified',
    'result_published',
    'published',
  }.contains(status);

  if (!saleClosedByTime && !saleClosedByStatus) return null;
  return '$waitingResultPath?$saleClosedNoticeQuery=1';
}
