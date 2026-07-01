import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../results/data/result_models.dart';
import '../../results/data/result_repository.dart';
import '../data/lottery_models.dart';
import '../data/lottery_repository.dart';

const saleClosedNoticeQuery = 'sale_closed';
const waitingResultPath = '/waiting-result';
const resultPath = '/result';
const countdownPath = '/countdown';

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
  DateTime? _currentGameFetchedAt;
  bool? _hasActiveCart;
  String? _lastWatchedLocation;
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
    _currentGameFetchedAt = null;
    _hasActiveCart = null;
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
      _lastWatchedLocation = null;
      _hasActiveCart = null;
      return;
    }
    if (_lastWatchedLocation != location) {
      _lastWatchedLocation = location;
      _hasActiveCart = null;
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
        _currentGameFetchedAt = DateTime.now();
      } finally {
        _loading = false;
      }
      if (!mounted) return;
    }

    final now = saleClosureNow(
      gameServerTime: _currentGame?.serverTime,
      gameFetchedAt: _currentGameFetchedAt,
      fallbackNow: DateTime.now(),
    );
    final saleClosed = saleClosureIsClosed(
      gameStatus: _currentGame?.status ?? '',
      saleCloseAt: _currentGame?.saleCloseAt,
      now: now,
    );
    if (saleClosed && _hasActiveCart == null) {
      _hasActiveCart = await _loadHasActiveCart();
      if (!mounted) return;
    }

    final redirect = saleClosureRedirectPath(
      path: path,
      gameStatus: _currentGame?.status ?? '',
      saleStartAt: _currentGame?.saleStartAt,
      saleCloseAt: _currentGame?.saleCloseAt,
      now: now,
      hasActiveCart: _hasActiveCart ?? false,
    );
    if (redirect == null) {
      _saleClosedAlertShown = false;
      return;
    }
    final shouldShowNotice = saleClosureShouldShowClosedNotice(redirect);
    if (shouldShowNotice && !_saleClosedAlertShown) {
      _saleClosedAlertShown = true;
      ref.read(appAlertControllerProvider.notifier).show(
            title: context.l10n.waitingResultSaleClosed,
            message: context.l10n.saleClosureAlertMessage,
            variant: AppAlertVariant.warning,
          );
    } else if (!shouldShowNotice) {
      _saleClosedAlertShown = false;
    }
    if (location == redirect) return;
    widget.router.go(redirect);
  }

  Future<bool> _loadHasActiveCart() async {
    try {
      final cart = await ref.read(lotteryRepositoryProvider).cart();
      return saleClosureCartHasActiveReservations(cart);
    } catch (_) {
      return false;
    }
  }
}

bool saleClosureShouldWatchPath(String path) {
  return _saleClosureBrowsingPath(path) ||
      path == '/cart' ||
      path == '/checkout';
}

bool saleClosureShouldShowClosedNotice(String redirect) {
  final uri = Uri.tryParse(redirect);
  if (uri == null) return false;
  return uri.path == waitingResultPath &&
      uri.queryParameters[saleClosedNoticeQuery] == '1';
}

bool saleClosureCartHasActiveReservations(
  LotteryCart cart, {
  DateTime? localNow,
}) {
  if (cart.items.isEmpty) return false;
  final anchor = localNow ?? DateTime.now();
  for (final reservation in cart.reservations) {
    if (reservation.status != 'active' || reservation.items.isEmpty) continue;
    if (!_saleClosureReservationHasDeadline(reservation)) continue;
    if (!_saleClosureReservationDeadlineExpired(
      reservation,
      localNow: anchor,
      fallbackServerTime: cart.serverTime,
    )) {
      return true;
    }
  }
  return false;
}

String? saleClosureRedirectPath({
  required String path,
  required String gameStatus,
  required Object? saleCloseAt,
  required DateTime now,
  Object? saleStartAt,
  bool hasActiveCart = false,
}) {
  if (!saleClosureShouldWatchPath(path)) return null;
  if (path == waitingResultPath) return null;

  if (saleClosureIsPublished(gameStatus)) {
    return path == '/' ? null : resultPath;
  }

  if (saleClosureIsNotStarted(
    gameStatus: gameStatus,
    saleStartAt: saleStartAt,
    now: now,
  )) {
    return countdownPath;
  }

  if (!saleClosureIsClosed(
    gameStatus: gameStatus,
    saleCloseAt: saleCloseAt,
    now: now,
  )) {
    return null;
  }

  if (path == '/cart' || path == '/checkout') {
    return hasActiveCart ? null : '$waitingResultPath?$saleClosedNoticeQuery=1';
  }

  if (_saleClosureBrowsingPath(path)) {
    return hasActiveCart
        ? '/cart'
        : '$waitingResultPath?$saleClosedNoticeQuery=1';
  }

  return '$waitingResultPath?$saleClosedNoticeQuery=1';
}

bool _saleClosureBrowsingPath(String path) {
  return path == '/' ||
      path == '/search' ||
      path == '/buy' ||
      path.startsWith('/buy/') ||
      path == '/stores' ||
      path.startsWith('/stores/');
}

bool saleClosureIsClosed({
  required String gameStatus,
  required Object? saleCloseAt,
  required DateTime now,
}) {
  final status = gameStatus.trim().toLowerCase();
  final saleClose = parseDateTime(saleCloseAt);
  final saleClosedByTime = saleClose != null && !now.isBefore(saleClose);
  final saleClosedByStatus =
      _waitingResultStatuses.contains(status) || saleClosureIsPublished(status);

  return saleClosedByTime || saleClosedByStatus;
}

bool saleClosureIsNotStarted({
  required String gameStatus,
  required Object? saleStartAt,
  required DateTime now,
}) {
  final status = gameStatus.trim().toLowerCase();
  final saleStart = parseDateTime(saleStartAt);
  return _openSaleStatuses.contains(status) &&
      saleStart != null &&
      now.isBefore(saleStart);
}

bool saleClosureIsPublished(String gameStatus) {
  return _publishedResultStatuses.contains(gameStatus.trim().toLowerCase());
}

DateTime saleClosureNow({
  required Object? gameServerTime,
  required DateTime? gameFetchedAt,
  required DateTime fallbackNow,
}) {
  final serverTime = parseDateTime(gameServerTime);
  if (serverTime == null || gameFetchedAt == null) return fallbackNow;
  final elapsed = fallbackNow.difference(gameFetchedAt);
  return elapsed.isNegative ? serverTime : serverTime.add(elapsed);
}

bool _saleClosureReservationDeadlineExpired(
  LotteryReservation reservation, {
  required DateTime localNow,
  Object? fallbackServerTime,
}) {
  final serverNow = localNow.add(
    _saleClosureReservationServerTimeOffset(
      reservation.serverTime ?? fallbackServerTime,
      localNow: localNow,
    ),
  );
  return _saleClosureReservationRemainingDuration(
        reservation,
        now: serverNow,
      ).inSeconds <=
      0;
}

Duration _saleClosureReservationServerTimeOffset(
  Object? serverTime, {
  required DateTime localNow,
}) {
  final serverNow = parseDateTime(serverTime);
  if (serverNow == null) return Duration.zero;
  return serverNow.difference(localNow);
}

Duration _saleClosureReservationRemainingDuration(
  LotteryReservation reservation, {
  required DateTime now,
}) {
  final expiresAt = parseDateTime(reservation.expiresAt);
  if (expiresAt != null) {
    final remaining = expiresAt.difference(now);
    return remaining.isNegative ? Duration.zero : remaining;
  }
  if (reservation.expiresInSeconds > 0) {
    return Duration(seconds: reservation.expiresInSeconds);
  }
  return Duration.zero;
}

bool _saleClosureReservationHasDeadline(LotteryReservation reservation) {
  return parseDateTime(reservation.expiresAt) != null ||
      reservation.expiresInSeconds > 0;
}

const _openSaleStatuses = {
  'open',
  'active',
  'selling',
  'sale',
  '1',
};

const _waitingResultStatuses = {
  'closed',
  'drawing',
  'result_recorded',
  'result_checking',
  'result_verified',
  'reward_recorded',
  'reward_checking',
  'reward_verified',
  '3',
};

const _publishedResultStatuses = {
  'reward_published',
  'result_published',
  'published',
  'archived',
  '2',
};
