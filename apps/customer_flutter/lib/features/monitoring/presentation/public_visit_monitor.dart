import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/config/app_config.dart';
import '../../../core/navigation/web_runtime.dart';
import '../../../core/tenant/customer_tenant_host.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../data/public_visit_id_store.dart';
import '../data/public_visit_repository.dart';

final publicVisitMonitorEnabledProvider = Provider<bool>((_) => true);
final publicVisitHeartbeatIntervalProvider = Provider<Duration>(
  (_) => const Duration(minutes: 1),
);
final publicVisitRouteThrottleProvider = Provider<Duration>(
  (_) => const Duration(seconds: 10),
);

class PublicVisitMonitor extends ConsumerStatefulWidget {
  const PublicVisitMonitor({
    required this.router,
    required this.child,
    super.key,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<PublicVisitMonitor> createState() => _PublicVisitMonitorState();
}

class _PublicVisitMonitorState extends ConsumerState<PublicVisitMonitor> {
  Timer? _timer;
  DateTime? _lastTrackedAt;
  String _lastTrackedPath = '';
  bool _tracking = false;

  @override
  void initState() {
    super.initState();
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !ref.read(publicVisitMonitorEnabledProvider)) return;
      _track(force: true);
      _startHeartbeat();
    });
  }

  @override
  void didUpdateWidget(covariant PublicVisitMonitor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.router == widget.router) return;
    oldWidget.router.routeInformationProvider.removeListener(
      _handleRouteChanged,
    );
    widget.router.routeInformationProvider.addListener(_handleRouteChanged);
    _lastTrackedPath = '';
    _track(force: true);
  }

  @override
  void dispose() {
    widget.router.routeInformationProvider.removeListener(_handleRouteChanged);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _startHeartbeat() {
    _timer?.cancel();
    _timer = Timer.periodic(
      ref.read(publicVisitHeartbeatIntervalProvider),
      (_) => _track(force: true),
    );
  }

  void _handleRouteChanged() {
    if (!ref.read(publicVisitMonitorEnabledProvider)) return;
    _track();
  }

  Future<void> _track({bool force = false}) async {
    if (!mounted || _tracking) return;
    final location = currentPublicVisitLocation(widget.router);
    final now = DateTime.now();
    final throttle = ref.read(publicVisitRouteThrottleProvider);
    if (!force &&
        location == _lastTrackedPath &&
        _lastTrackedAt != null &&
        now.difference(_lastTrackedAt!) < throttle) {
      return;
    }

    _tracking = true;
    _lastTrackedAt = now;
    _lastTrackedPath = location;
    try {
      final media = MediaQuery.maybeOf(context);
      final screen = media == null
          ? null
          : '${media.size.width.round()}x${media.size.height.round()}';
      final bootstrap = ref.read(mobileBootstrapProvider).valueOrNull;
      final hostScope = publicVisitHostScope(
        ref.read(appConfigProvider),
        runtimeTenantHost: bootstrap?.tenantHost ?? '',
        runtimeCanonicalUrl: bootstrap?.canonicalUrl ?? '',
      );
      final idStore = ref.read(publicVisitIdStoreProvider);
      final visitorId = await idStore.visitorId(hostScope);
      final sessionId = idStore.sessionId(hostScope);

      await ref.read(publicVisitRepositoryProvider).track(
            PublicVisitPayload(
              visitorId: visitorId,
              sessionId: sessionId,
              source: publicVisitTrafficSource(location, currentWebReferrer),
              channel: publicVisitTrafficChannel(location),
              path: location,
              referrer: currentWebReferrer.isEmpty ? null : currentWebReferrer,
              screen: screen,
              timezone: now.timeZoneName,
              routeName: publicVisitRouteName(location),
            ),
          );
    } catch (_) {
      // Visit tracking must never interrupt customer journeys.
    } finally {
      _tracking = false;
    }
  }
}

String currentPublicVisitLocation(GoRouter router) {
  return router.routeInformationProvider.value.uri.toString();
}

String publicVisitTrafficSource(String location, String referrer) {
  final uri = Uri.tryParse(location);
  final explicit = _firstQuery(uri, ['utm_source', 'source']);
  if (explicit.isNotEmpty) return _normalizeSource(explicit);

  if (_firstQuery(uri, ['ref', 'ref_code', 'affiliate']).isNotEmpty) {
    return 'affiliate';
  }

  if (referrer.trim().isEmpty) return 'direct';
  final referrerUri = Uri.tryParse(referrer);
  final host = referrerUri?.host.toLowerCase() ?? '';
  if (host.contains('line.me') || host.contains('lin.ee')) return 'line';
  if (host.contains('facebook.com') || host.contains('fb.com')) {
    return 'facebook';
  }
  if (host.contains('google.')) return 'google';
  if (host.contains('tiktok.')) return 'tiktok';
  if (host.contains('instagram.')) return 'instagram';
  return 'referral';
}

String? publicVisitTrafficChannel(String location) {
  final uri = Uri.tryParse(location);
  final value = _firstQuery(uri, ['utm_medium', 'utm_campaign', 'ref']);
  return value.isEmpty ? null : value;
}

String publicVisitRouteName(String location) {
  final uri = Uri.tryParse(location);
  final path = uri?.path ?? location;
  if (path == '/' || path.trim().isEmpty) return 'home';
  return path
      .replaceAll(RegExp(r'^/+'), '')
      .replaceAll(RegExp(r'[^a-zA-Z0-9]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_|_$'), '')
      .toLowerCase();
}

String publicVisitHostScope(
  AppConfig config, {
  String runtimeTenantHost = '',
  String runtimeCanonicalUrl = '',
  String? webHost,
}) {
  final host = resolveCustomerTenantHost(
    currentHost: webHost ?? currentWebHost,
    configuredTenantHost: config.normalizedTenantHost,
    runtimeTenantHost: runtimeTenantHost,
    runtimeCanonicalUrl: runtimeCanonicalUrl,
    apiBaseUrl: config.apiBaseUrl,
  );
  return host.isEmpty ? 'default' : host;
}

String _firstQuery(Uri? uri, List<String> keys) {
  if (uri == null) return '';
  for (final key in keys) {
    final value = uri.queryParameters[key]?.trim() ?? '';
    if (value.isNotEmpty) return value;
  }
  return '';
}

String _normalizeSource(String value) {
  return value
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9:_\-.]'), '')
      .substringSafe(0, 64);
}

extension _SafeSubstring on String {
  String substringSafe(int start, int end) {
    if (isEmpty || start >= length) return '';
    return substring(start, end > length ? length : end);
  }
}
