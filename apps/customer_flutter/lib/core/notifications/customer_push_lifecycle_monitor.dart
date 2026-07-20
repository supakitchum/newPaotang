import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/notifications/data/customer_notification_models.dart';
import '../../features/notifications/data/customer_notification_repository.dart';
import '../../features/notifications/presentation/customer_notification_navigation.dart';
import '../../features/notifications/presentation/customer_notification_realtime_monitor.dart';
import '../auth/auth_controller.dart';
import '../i18n/app_locale.dart';
import '../i18n/customer_locale_controller.dart';
import 'customer_push_installation_store.dart';
import 'customer_push_platform.dart';

class CustomerPushLifecycleMonitor extends ConsumerStatefulWidget {
  const CustomerPushLifecycleMonitor({
    super.key,
    required this.router,
    required this.child,
  });

  final GoRouter router;
  final Widget child;

  @override
  ConsumerState<CustomerPushLifecycleMonitor> createState() =>
      _CustomerPushLifecycleMonitorState();
}

class _CustomerPushLifecycleMonitorState
    extends ConsumerState<CustomerPushLifecycleMonitor> {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void> _syncQueue = Future<void>.value();
  VoidCallback? _removeLogoutHook;
  CustomerPushMessage? _pendingTap;
  String _registeredSignature = '';
  bool _syncing = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    final platform = ref.read(customerPushPlatformProvider);
    _subscriptions.add(
      platform.foregroundMessages.listen(_handleForegroundMessage),
    );
    _subscriptions.add(platform.notificationTaps.listen(_handleTap));
    _subscriptions.add(platform.tokenRefresh.listen(_handleTokenRefresh));
    _removeLogoutHook = ref
        .read(authControllerProvider)
        .registerBeforeLogoutHook(_revokeForLogout);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialTap = platform.takeInitialTap();
      if (initialTap != null) _handleTap(initialTap);
      _scheduleSync();
    });
  }

  @override
  void dispose() {
    _removeLogoutHook?.call();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthController>(authControllerProvider, (_, __) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
    });
    ref.listen<Locale>(customerLocaleProvider, (_, __) {
      _registeredSignature = '';
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
    });
    return widget.child;
  }

  void _scheduleSync() {
    _syncQueue = _syncQueue.then((_) async {
      if (mounted) await _sync();
    });
  }

  Future<void> _sync() async {
    if (_syncing || _loggingOut) return;
    final platform = ref.read(customerPushPlatformProvider);
    final auth = ref.read(authControllerProvider);
    if (!platform.available || !_isUnlocked(auth)) return;

    _syncing = true;
    try {
      final store = ref.read(customerPushInstallationStoreProvider);
      NotificationSettings? settings;
      if (!await store.permissionRequested()) {
        settings = await platform.requestPermission();
        await store.markPermissionRequested();
      } else {
        settings = await platform.notificationSettings();
      }
      if (!_pushAuthorized(settings)) return;

      final token = (await platform.token())?.trim() ?? '';
      if (token.isNotEmpty) await _registerToken(token);
      await _flushPendingTap();
    } catch (_) {
      // Inbox and realtime remain usable when native registration is unavailable.
    } finally {
      _syncing = false;
    }
  }

  Future<void> _registerToken(String token) async {
    if (_loggingOut || token.trim().isEmpty) return;
    final auth = ref.read(authControllerProvider);
    if (!_isUnlocked(auth)) return;

    final store = ref.read(customerPushInstallationStoreProvider);
    final installationId = await store.installationId();
    final locale = localeTag(ref.read(customerLocaleProvider));
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => '',
    };
    if (platform.isEmpty) return;

    final signature = '$installationId|$platform|$locale|${token.trim()}';
    if (_registeredSignature == signature) return;
    await ref
        .read(customerNotificationRepositoryProvider)
        .registerDevice(
          installationId: installationId,
          platform: platform,
          fcmToken: token.trim(),
          locale: locale,
        );
    _registeredSignature = signature;
  }

  void _handleTokenRefresh(String token) {
    unawaited(_registerToken(token));
  }

  void _handleForegroundMessage(CustomerPushMessage message) {
    if (!mounted) return;
    ref.invalidate(customerNotificationUnreadCountProvider);
    ref.read(customerNotificationRealtimeTickProvider.notifier).state++;
  }

  void _handleTap(CustomerPushMessage message) {
    if (!mounted) return;
    _pendingTap = message;
    ref.invalidate(customerNotificationUnreadCountProvider);
    ref.read(customerNotificationRealtimeTickProvider.notifier).state++;

    final auth = ref.read(authControllerProvider);
    if (_isUnlocked(auth)) {
      unawaited(_flushPendingTap());
      return;
    }

    // Always pass native notification taps through the existing auth/PIN gate.
    widget.router.go('/notifications');
  }

  Future<void> _flushPendingTap() async {
    final message = _pendingTap;
    if (message == null || !_isUnlocked(ref.read(authControllerProvider))) {
      return;
    }

    final route =
        customerNotificationRoute(
          CustomerNotificationAction(
            key: message.actionKey,
            entityId: message.actionEntityId,
          ),
        ) ??
        '/notifications';
    final notificationId = message.notificationId.trim();
    if (notificationId.isNotEmpty) {
      try {
        await ref
            .read(customerNotificationRepositoryProvider)
            .markRead(notificationId);
      } catch (_) {
        // Navigation to the inbox still lets the customer retry the read state.
        if (route != '/notifications') {
          widget.router.go('/notifications');
          return;
        }
      }
    }

    if (!mounted || !_isUnlocked(ref.read(authControllerProvider))) return;
    _pendingTap = null;
    ref.invalidate(customerNotificationUnreadCountProvider);
    widget.router.go(route);
  }

  Future<void> _revokeForLogout() async {
    final platform = ref.read(customerPushPlatformProvider);
    if (!platform.available) return;
    _loggingOut = true;
    _pendingTap = null;
    _registeredSignature = '';
    try {
      final installationId = await ref
          .read(customerPushInstallationStoreProvider)
          .installationId();
      await ref
          .read(customerNotificationRepositoryProvider)
          .revokeDevice(installationId);
    } catch (_) {
      // Explicit logout remains available even if the device revoke is offline.
    } finally {
      _loggingOut = false;
    }
  }
}

bool _isUnlocked(AuthController auth) {
  return auth.isAuthenticated && !auth.pinRequired && !auth.pinSetupRequired;
}

bool _pushAuthorized(NotificationSettings? settings) {
  final status = settings?.authorizationStatus;
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}
