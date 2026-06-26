import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/security/screen_security_service.dart';

class SensitiveScreenGuard extends ConsumerStatefulWidget {
  const SensitiveScreenGuard({
    required this.route,
    required this.child,
    this.enabled = true,
    super.key,
  });

  final String route;
  final Widget child;
  final bool enabled;

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
        oldWidget.enabled != widget.enabled) {
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
    _screenSecurity.enable(route: widget.route);
  }

  void _handleSecurityEvent(ScreenSecurityEvent event) {
    if (!mounted) return;
    if (event.event == 'screen_capture_ended') return;
    if (event.route.isNotEmpty && event.route != widget.route) return;
    ref.read(authControllerProvider).lockForScreenSecurity();
  }
}
