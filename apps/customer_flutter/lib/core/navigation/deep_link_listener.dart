import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../config/app_config.dart';
import '../tenant/mobile_bootstrap_controller.dart';
import 'customer_deep_link.dart';

class CustomerDeepLinkListener extends ConsumerStatefulWidget {
  const CustomerDeepLinkListener({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CustomerDeepLinkListener> createState() =>
      _CustomerDeepLinkListenerState();
}

class _CustomerDeepLinkListenerState
    extends ConsumerState<CustomerDeepLinkListener> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _subscription;
  String? _lastHandled;
  Uri? _pendingHttpsUri;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) {
      unawaited(_handleInitialLink());
      _subscription = _appLinks.uriLinkStream.listen(_handleUri);
    }
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AsyncValue<MobileBootstrap>>(mobileBootstrapProvider, (_, next) {
      if (!next.hasValue) return;
      final pending = _pendingHttpsUri;
      if (pending == null) return;
      _pendingHttpsUri = null;
      _handleUri(pending, deferUntilBootstrap: false);
    });
    return widget.child;
  }

  Future<void> _handleInitialLink() async {
    try {
      final uri = await _appLinks.getInitialLink();
      if (uri != null) _handleUri(uri);
    } catch (_) {
      // Deep links are optional; a malformed platform event must not block app start.
    }
  }

  void _handleUri(Uri uri, {bool deferUntilBootstrap = true}) {
    final config = ref.read(appConfigProvider);
    final bootstrap = ref.read(mobileBootstrapProvider);
    final runtime = bootstrap.valueOrNull;
    final allowedHosts = customerDeepLinkAllowedHosts(
      tenantHost: config.normalizedTenantHost,
      apiBaseUrl: config.apiBaseUrl,
      runtimeTenantHost: runtime?.tenantHost ?? '',
      runtimeCanonicalUrl: runtime?.canonicalUrl ?? '',
    );
    final isHttpsLink = uri.scheme == 'http' || uri.scheme == 'https';
    if (isHttpsLink && allowedHosts.isEmpty) {
      if (deferUntilBootstrap && bootstrap.isLoading) {
        _pendingHttpsUri = uri;
      }
      return;
    }
    final target = customerDeepLinkPath(
      uri,
      allowedHosts: allowedHosts,
    );
    if (target == null) {
      if (deferUntilBootstrap && isHttpsLink && bootstrap.isLoading) {
        _pendingHttpsUri = uri;
      }
      return;
    }
    if (target == _lastHandled || !mounted) return;

    _pendingHttpsUri = null;
    _lastHandled = target;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.go(target);
    });
  }
}
