import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/i18n/customer_localizations.dart';
import '../../core/security/screen_security_service.dart';

class SensitiveScreenGuard extends ConsumerStatefulWidget {
  const SensitiveScreenGuard({
    required this.route,
    required this.child,
    this.enabled = true,
    this.androidFlagSecure,
    this.androidProtectRecentAppPreview,
    this.iosScreenshotPolicy,
    this.iosScreenCaptureOverlay,
    this.iosExitApp,
    this.privacyOverlayTitle,
    this.privacyOverlayDescription,
    this.lockOnCapture = true,
    super.key,
  });

  final String route;
  final Widget child;
  final bool enabled;
  final bool? androidFlagSecure;
  final bool? androidProtectRecentAppPreview;
  final String? iosScreenshotPolicy;
  final bool? iosScreenCaptureOverlay;
  final bool? iosExitApp;
  final String? privacyOverlayTitle;
  final String? privacyOverlayDescription;
  final bool lockOnCapture;

  @override
  ConsumerState<SensitiveScreenGuard> createState() =>
      _SensitiveScreenGuardState();
}

class _SensitiveScreenGuardState extends ConsumerState<SensitiveScreenGuard> {
  late final ScreenSecurityService _screenSecurity;
  StreamSubscription<ScreenSecurityEvent>? _subscription;

  @override
  void initState() {
    super.initState();
    _screenSecurity = ref.read(screenSecurityServiceProvider);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncProtection();
    });
  }

  @override
  void didUpdateWidget(covariant SensitiveScreenGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.route != widget.route ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.androidFlagSecure != widget.androidFlagSecure ||
        oldWidget.androidProtectRecentAppPreview !=
            widget.androidProtectRecentAppPreview ||
        oldWidget.iosScreenshotPolicy != widget.iosScreenshotPolicy ||
        oldWidget.iosScreenCaptureOverlay != widget.iosScreenCaptureOverlay ||
        oldWidget.iosExitApp != widget.iosExitApp ||
        oldWidget.privacyOverlayTitle != widget.privacyOverlayTitle ||
        oldWidget.privacyOverlayDescription !=
            widget.privacyOverlayDescription ||
        oldWidget.lockOnCapture != widget.lockOnCapture) {
      _syncProtection();
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _screenSecurity.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;

  void _syncProtection() {
    if (!widget.enabled) {
      _subscription?.cancel();
      _subscription = null;
      _screenSecurity.disable();
      return;
    }

    _subscription ??= _screenSecurity.events.listen(_handleSecurityEvent);
    final l10n = context.l10n;
    _screenSecurity.enable(
      route: widget.route,
      overlayTitle: _runtimeCopy(
        widget.privacyOverlayTitle,
        l10n.securityCaptureTitle,
      ),
      overlayDescription: _runtimeCopy(
        widget.privacyOverlayDescription,
        l10n.securityCaptureDescription,
      ),
      androidFlagSecure: widget.androidFlagSecure,
      androidProtectRecentAppPreview: widget.androidProtectRecentAppPreview,
      iosScreenshotPolicy: widget.iosScreenshotPolicy,
      iosScreenCaptureOverlay: widget.iosScreenCaptureOverlay,
      iosExitApp: widget.iosExitApp,
    );
  }

  void _handleSecurityEvent(ScreenSecurityEvent event) {
    if (!mounted) return;
    if (!screenSecurityRoutesMatch(event.route, widget.route)) return;
    final route = event.route.isEmpty
        ? normalizeScreenSecurityRoute(widget.route)
        : normalizeScreenSecurityRoute(event.route);
    unawaited(
      ref.read(screenSecurityAuditServiceProvider).record(
            event: event,
            route: route,
          ),
    );
    if (event.event == 'screen_capture_ended') return;
    if (!_shouldLockForSecurityEvent(event)) return;
    ref.read(authControllerProvider).lockForScreenSecurity();
  }

  bool _shouldLockForSecurityEvent(ScreenSecurityEvent event) {
    if (event.event == 'screen_security_exit_requested') return true;
    return widget.lockOnCapture;
  }

  String _runtimeCopy(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}
