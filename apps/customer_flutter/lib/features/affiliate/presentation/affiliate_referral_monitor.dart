import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../monitoring/presentation/public_visit_monitor.dart';
import '../data/affiliate_referral_repository.dart';

final affiliateReferralMonitorEnabledProvider = Provider<bool>((_) => true);

class AffiliateReferralMonitor extends ConsumerStatefulWidget {
  const AffiliateReferralMonitor({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<AffiliateReferralMonitor> createState() =>
      _AffiliateReferralMonitorState();
}

class _AffiliateReferralMonitorState
    extends ConsumerState<AffiliateReferralMonitor> {
  String _lastCapturedLocation = '';

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _captureCurrentLocation();
    });
  }

  @override
  void didUpdateWidget(covariant AffiliateReferralMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routeInformationProvider.removeListener(
      _handleRouteChanged,
    );
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    _lastCapturedLocation = '';
    _captureCurrentLocation();
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _handleRouteChanged() => _captureCurrentLocation();

  void _captureCurrentLocation() {
    if (!mounted || !ref.read(affiliateReferralMonitorEnabledProvider)) return;
    final location = currentPublicVisitLocation(widget.router);
    if (location == _lastCapturedLocation) return;
    _lastCapturedLocation = location;
    unawaited(
      ref.read(affiliateReferralServiceProvider).captureFromLocation(location),
    );
  }
}
