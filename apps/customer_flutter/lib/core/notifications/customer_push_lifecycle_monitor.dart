import 'dart:async';
import 'dart:developer' as developer;

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
import '../auth/customer_session_replacement_controller.dart';
import '../i18n/app_locale.dart';
import '../i18n/customer_locale_controller.dart';
import 'customer_push_device_context.dart';
import 'customer_push_installation_store.dart';
import 'customer_push_platform.dart';

final customerPushRegistrationClockProvider = Provider<DateTime Function()>(
  (_) => DateTime.now,
);

final customerPushDiagnosticsProvider = Provider<CustomerPushDiagnostics>(
  (_) => const CustomerPushDiagnostics(),
);

class CustomerPushDiagnostics {
  const CustomerPushDiagnostics();

  void registrationFailure(String stage, Object error) {
    developer.log(
      'stage=$stage error_type=${error.runtimeType}',
      name: 'customer_push.registration',
    );
  }
}

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
    extends ConsumerState<CustomerPushLifecycleMonitor>
    with WidgetsBindingObserver {
  final List<StreamSubscription<Object?>> _subscriptions = [];
  Future<void> _syncQueue = Future<void>.value();
  VoidCallback? _removeLogoutHook;
  CustomerPushMessage? _pendingTap;
  String _registeredSignature = '';
  DateTime? _registeredAt;
  DateTime? _lastReconciledAt;
  Timer? _retryTimer;
  int _retryAttempt = 0;
  bool _syncing = false;
  bool _flushingTap = false;
  bool _loggingOut = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final platform = ref.read(customerPushPlatformProvider);
    _subscriptions.add(
      platform.foregroundMessages.listen(_handleForegroundMessage),
    );
    _subscriptions.add(platform.notificationTaps.listen(_handleTap));
    _subscriptions.add(platform.tokenRefresh.listen(_handleTokenRefresh));
    _removeLogoutHook = ref
        .read(authControllerProvider)
        .registerBeforeLogoutHook(_detachForLogout);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final initialTap = platform.takeInitialTap();
      if (initialTap != null) _handleTap(initialTap);
      _scheduleSync();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _retryTimer?.cancel();
    _removeLogoutHook?.call();
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;

    // Reconcile server state because realtime events can be missed while the
    // process is suspended, even when no notification was tapped.
    ref.invalidate(customerNotificationUnreadCountProvider);
    ref.read(customerNotificationRealtimeTickProvider.notifier).state++;
    _scheduleSync();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<AuthController>(authControllerProvider, (_, auth) {
      if (!auth.isAuthenticated) {
        _loggingOut = false;
        _registeredSignature = '';
        _registeredAt = null;
        _lastReconciledAt = null;
        _clearRetry();
      }
      WidgetsBinding.instance.addPostFrameCallback((_) => _scheduleSync());
    });
    ref.listen<Locale>(customerLocaleProvider, (_, __) {
      _registeredSignature = '';
      _registeredAt = null;
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
    if (!platform.available || (auth.isAuthenticated && !_isUnlocked(auth))) {
      return;
    }
    final anonymous = !auth.isAuthenticated;

    _syncing = true;
    var stage = 'permission';
    try {
      await _flushPendingTap();
      final store = ref.read(customerPushInstallationStoreProvider);
      NotificationSettings? settings;
      final permissionRequested = await store.permissionRequested();
      if (permissionRequested) {
        settings = await platform.notificationSettings();
      }
      if (!permissionRequested ||
          settings?.authorizationStatus == AuthorizationStatus.notDetermined) {
        settings = await platform.requestPermission();
        await store.markPermissionRequested();
      }
      if (!_pushAuthorized(settings)) {
        _clearRetry();
        return;
      }

      final installationId = await store.installationId();
      final now = ref.read(customerPushRegistrationClockProvider)().toUtc();
      CustomerPushDeviceStatus? serverStatus;
      if (!anonymous && _shouldReconcile(now)) {
        stage = 'status';
        serverStatus = await ref
            .read(customerNotificationRepositoryProvider)
            .deviceStatus(installationId);
      }

      String token;
      if (serverStatus?.needsTokenRotation ?? false) {
        stage = 'token_rotation';
        token = await _rotateToken(platform);
        _registeredSignature = '';
        _registeredAt = null;
      } else {
        stage = 'token';
        token = (await platform.token())?.trim() ?? '';
        if (token.isEmpty) {
          throw const _CustomerPushRegistrationFailure('token_unavailable');
        }
      }

      stage = 'registration';
      await _registerToken(
        token,
        force: serverStatus != null && !serverStatus.registered,
        installationId: installationId,
        anonymous: anonymous,
      );
      if (serverStatus != null) _lastReconciledAt = now;
      _clearRetry();
    } catch (error) {
      // Inbox and realtime remain usable when native registration is unavailable.
      _scheduleRetry(stage, error);
    } finally {
      _syncing = false;
    }
  }

  Future<void> _registerToken(
    String token, {
    bool force = false,
    String? installationId,
    bool? anonymous,
  }) async {
    if (_loggingOut || token.trim().isEmpty) return;
    final auth = ref.read(authControllerProvider);
    if (auth.isAuthenticated && !_isUnlocked(auth)) return;
    final registerAnonymously = anonymous ?? !auth.isAuthenticated;

    final store = ref.read(customerPushInstallationStoreProvider);
    final resolvedInstallationId =
        installationId ?? await store.installationId();
    final installationSecret = await store.installationSecret();
    final locale = localeTag(ref.read(customerLocaleProvider));
    final platform = switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => '',
    };
    if (platform.isEmpty) return;

    final deviceContext = await ref
        .read(customerPushDeviceContextLoaderProvider)
        .load();
    final signature =
        '$resolvedInstallationId|$installationSecret|${registerAnonymously ? 'anonymous' : 'customer'}|$platform|$locale|${deviceContext.registrationSignature}|${token.trim()}';
    final now = ref.read(customerPushRegistrationClockProvider)().toUtc();
    final registeredAt = _registeredAt;
    final registrationAge = registeredAt == null
        ? null
        : now.difference(registeredAt);
    if (!force &&
        _registeredSignature == signature &&
        registrationAge != null &&
        !registrationAge.isNegative &&
        registrationAge < const Duration(days: 1)) {
      return;
    }
    final repository = ref.read(customerNotificationRepositoryProvider);
    if (registerAnonymously) {
      await repository.registerAnonymousInstallation(
        installationId: resolvedInstallationId,
        installationSecret: installationSecret,
        platform: platform,
        fcmToken: token.trim(),
        locale: locale,
        appVersion: deviceContext.appVersion,
        deviceName: deviceContext.deviceName,
        metadata: deviceContext.metadata,
      );
    } else {
      await repository.registerDevice(
        installationId: resolvedInstallationId,
        installationSecret: installationSecret,
        platform: platform,
        fcmToken: token.trim(),
        locale: locale,
        appVersion: deviceContext.appVersion,
        deviceName: deviceContext.deviceName,
        metadata: deviceContext.metadata,
      );
    }
    _registeredSignature = signature;
    _registeredAt = now;
  }

  void _handleTokenRefresh(String token) {
    _syncQueue = _syncQueue.then((_) async {
      if (mounted) await _registerTokenSafely(token);
    });
  }

  Future<void> _registerTokenSafely(String token) async {
    try {
      await _registerToken(token);
      _clearRetry();
    } catch (error) {
      // A resume/auth sync retries the current token without crashing the app.
      _scheduleRetry('token_refresh_registration', error);
    }
  }

  bool _shouldReconcile(DateTime now) {
    final checkedAt = _lastReconciledAt;
    if (checkedAt == null) return true;
    final age = now.difference(checkedAt);
    return age.isNegative || age >= const Duration(minutes: 15);
  }

  Future<String> _rotateToken(CustomerPushPlatform platform) async {
    String previousToken = '';
    try {
      previousToken = (await platform.token())?.trim() ?? '';
    } catch (_) {
      // Deleting the invalid installation token does not require reading it first.
    }

    await platform.deleteToken();
    for (final delay in const [
      Duration.zero,
      Duration(milliseconds: 250),
      Duration(milliseconds: 750),
      Duration(milliseconds: 1500),
    ]) {
      if (delay > Duration.zero) await Future<void>.delayed(delay);
      final refreshed = (await platform.token())?.trim() ?? '';
      if (refreshed.isNotEmpty && refreshed != previousToken) return refreshed;
    }

    throw const _CustomerPushRegistrationFailure('token_rotation_pending');
  }

  void _scheduleRetry(String stage, Object error) {
    ref.read(customerPushDiagnosticsProvider).registrationFailure(stage, error);
    if (!mounted || _loggingOut || _retryTimer?.isActive == true) return;
    const delays = [
      Duration(seconds: 15),
      Duration(minutes: 1),
      Duration(minutes: 5),
      Duration(minutes: 15),
    ];
    final index = _retryAttempt < delays.length
        ? _retryAttempt
        : delays.length - 1;
    final delay = delays[index];
    if (_retryAttempt < delays.length - 1) _retryAttempt++;
    _retryTimer = Timer(delay, () {
      _retryTimer = null;
      if (mounted && !_loggingOut) _scheduleSync();
    });
  }

  void _clearRetry() {
    _retryTimer?.cancel();
    _retryTimer = null;
    _retryAttempt = 0;
  }

  void _handleForegroundMessage(CustomerPushMessage message) {
    if (!mounted) return;
    ref.invalidate(customerNotificationUnreadCountProvider);
    ref.read(customerNotificationRealtimeTickProvider.notifier).state++;
    if (_isSessionReplacementPush(message)) {
      ref
          .read(customerSessionReplacementControllerProvider.notifier)
          .notify(replacementSessionId: message.replacementSessionId);
    }
  }

  void _handleTap(CustomerPushMessage message) {
    if (!mounted) return;
    if (_isSessionReplacementPush(message)) {
      _pendingTap = null;
      ref
          .read(customerSessionReplacementControllerProvider.notifier)
          .notify(replacementSessionId: message.replacementSessionId);
      return;
    }
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
    if (_flushingTap) return;
    final message = _pendingTap;
    if (message == null || !_isUnlocked(ref.read(authControllerProvider))) {
      return;
    }

    _flushingTap = true;
    try {
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
      if (identical(_pendingTap, message)) _pendingTap = null;
      ref.invalidate(customerNotificationUnreadCountProvider);
      widget.router.go(route);
    } finally {
      _flushingTap = false;
      if (mounted && _pendingTap != null && !identical(_pendingTap, message)) {
        unawaited(_flushPendingTap());
      }
    }
  }

  Future<void> _detachForLogout() async {
    final platform = ref.read(customerPushPlatformProvider);
    _loggingOut = true;
    _pendingTap = null;
    _registeredSignature = '';
    _registeredAt = null;
    _lastReconciledAt = null;
    _clearRetry();
    try {
      await _syncQueue;
    } catch (_) {
      // Registration failures remain contained before the final revoke.
    }
    if (!platform.available) return;
    try {
      final installationId = await ref
          .read(customerPushInstallationStoreProvider)
          .installationId();
      await ref
          .read(customerNotificationRepositoryProvider)
          .detachDevice(installationId);
    } catch (_) {
      // Explicit logout remains available if ownership cannot detach offline.
    }
  }
}

class _CustomerPushRegistrationFailure implements Exception {
  const _CustomerPushRegistrationFailure(this.code);

  final String code;
}

bool _isSessionReplacementPush(CustomerPushMessage message) {
  return message.eventKey.trim().toLowerCase() == 'account.session.replaced';
}

bool _isUnlocked(AuthController auth) {
  return auth.isAuthenticated && !auth.pinRequired && !auth.pinSetupRequired;
}

bool _pushAuthorized(NotificationSettings? settings) {
  final status = settings?.authorizationStatus;
  return status == AuthorizationStatus.authorized ||
      status == AuthorizationStatus.provisional;
}
