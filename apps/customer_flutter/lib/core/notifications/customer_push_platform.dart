import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerPushPlatformProvider = Provider<CustomerPushPlatform>((_) {
  return CustomerPushPlatform.disabled();
});

@pragma('vm:entry-point')
Future<void> customerFirebaseMessagingBackgroundHandler(
  RemoteMessage message,
) async {
  try {
    if (Firebase.apps.isEmpty) await Firebase.initializeApp();
  } catch (_) {
    // The server inbox remains authoritative when native configuration is absent.
  }
}

class CustomerPushMessage {
  const CustomerPushMessage({
    required this.notificationId,
    required this.actionKey,
    required this.actionEntityId,
    required this.title,
    required this.body,
  });

  final String notificationId;
  final String actionKey;
  final String actionEntityId;
  final String title;
  final String body;

  factory CustomerPushMessage.fromRemoteMessage(RemoteMessage message) {
    return CustomerPushMessage.fromMap(
      message.data,
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
    );
  }

  factory CustomerPushMessage.fromMap(
    Map<String, dynamic> value, {
    String title = '',
    String body = '',
  }) {
    return CustomerPushMessage(
      notificationId: _pushText(value, const [
        'notification_id',
        'notificationId',
      ]),
      actionKey: _pushText(value, const ['action_key', 'actionKey']),
      actionEntityId: _pushText(value, const [
        'action_entity_id',
        'actionEntityId',
      ]),
      title: title.trim().isNotEmpty
          ? title.trim()
          : _pushText(value, const ['title']),
      body: body.trim().isNotEmpty
          ? body.trim()
          : _pushText(value, const ['body', 'message']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'notification_id': notificationId,
      'action_key': actionKey,
      'action_entity_id': actionEntityId,
      'title': title,
      'body': body,
    };
  }
}

class CustomerPushPlatform {
  CustomerPushPlatform._({
    required this.available,
    FirebaseMessaging? messaging,
    FlutterLocalNotificationsPlugin? localNotifications,
    CustomerPushMessage? initialTap,
    Stream<String>? tokenRefresh,
    Future<NotificationSettings?> Function()? requestPermission,
    Future<NotificationSettings?> Function()? notificationSettings,
    Future<String?> Function()? token,
    Future<void> Function()? deleteToken,
  }) : _messaging = messaging,
       _localNotifications = localNotifications,
       _initialTap = initialTap,
       _tokenRefresh = tokenRefresh ?? const Stream<String>.empty(),
       _requestPermission = requestPermission,
       _notificationSettings = notificationSettings,
       _token = token,
       _deleteToken = deleteToken;

  factory CustomerPushPlatform.disabled() {
    return CustomerPushPlatform._(available: false);
  }

  @visibleForTesting
  factory CustomerPushPlatform.test({
    bool available = true,
    Stream<CustomerPushMessage>? foregroundMessages,
    Stream<CustomerPushMessage>? notificationTaps,
    Stream<String>? tokenRefresh,
    CustomerPushMessage? initialTap,
    Future<NotificationSettings?> Function()? requestPermission,
    Future<NotificationSettings?> Function()? notificationSettings,
    Future<String?> Function()? token,
    Future<void> Function()? deleteToken,
  }) {
    final platform = CustomerPushPlatform._(
      available: available,
      initialTap: initialTap,
      tokenRefresh: tokenRefresh,
      requestPermission: requestPermission,
      notificationSettings: notificationSettings,
      token: token,
      deleteToken: deleteToken,
    );
    if (foregroundMessages != null) {
      platform._subscriptions.add(
        foregroundMessages.listen(platform._foregroundMessages.add),
      );
    }
    if (notificationTaps != null) {
      platform._subscriptions.add(
        notificationTaps.listen(platform._notificationTaps.add),
      );
    }
    return platform;
  }

  static const channelId = 'customer_updates';

  final bool available;
  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin? _localNotifications;
  final Stream<String> _tokenRefresh;
  final Future<NotificationSettings?> Function()? _requestPermission;
  final Future<NotificationSettings?> Function()? _notificationSettings;
  final Future<String?> Function()? _token;
  final Future<void> Function()? _deleteToken;
  final _foregroundMessages = StreamController<CustomerPushMessage>.broadcast();
  final _notificationTaps = StreamController<CustomerPushMessage>.broadcast();
  final List<StreamSubscription<Object?>> _subscriptions = [];
  CustomerPushMessage? _initialTap;

  Stream<CustomerPushMessage> get foregroundMessages =>
      _foregroundMessages.stream;
  Stream<CustomerPushMessage> get notificationTaps => _notificationTaps.stream;
  Stream<String> get tokenRefresh =>
      _messaging?.onTokenRefresh ?? _tokenRefresh;

  CustomerPushMessage? takeInitialTap() {
    final value = _initialTap;
    _initialTap = null;
    return value;
  }

  static Future<CustomerPushPlatform> initialize() async {
    if (!_nativePushPlatform) return CustomerPushPlatform.disabled();

    try {
      FirebaseMessaging.onBackgroundMessage(
        customerFirebaseMessagingBackgroundHandler,
      );
      if (Firebase.apps.isEmpty) await Firebase.initializeApp();

      final messaging = FirebaseMessaging.instance;
      final localNotifications = FlutterLocalNotificationsPlugin();
      const androidSettings = AndroidInitializationSettings(
        'ic_stat_customer_notification',
      );
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      final platform = CustomerPushPlatform._(
        available: true,
        messaging: messaging,
        localNotifications: localNotifications,
      );
      await localNotifications.initialize(
        settings: settings,
        onDidReceiveNotificationResponse: platform._onLocalNotificationTap,
      );
      await platform._createAndroidChannel();
      await messaging.setForegroundNotificationPresentationOptions(
        alert: false,
        badge: false,
        sound: false,
      );

      final localLaunch = await localNotifications
          .getNotificationAppLaunchDetails();
      if (localLaunch?.didNotificationLaunchApp ?? false) {
        platform._initialTap = _pushMessageFromPayload(
          localLaunch?.notificationResponse?.payload,
        );
      }
      final remoteLaunch = await messaging.getInitialMessage();
      if (remoteLaunch != null) {
        platform._initialTap = CustomerPushMessage.fromRemoteMessage(
          remoteLaunch,
        );
      }

      platform._subscriptions.add(
        FirebaseMessaging.onMessage.listen(platform._onForegroundMessage),
      );
      platform._subscriptions.add(
        FirebaseMessaging.onMessageOpenedApp.listen(
          platform._onRemoteNotificationTap,
        ),
      );
      return platform;
    } catch (_) {
      return CustomerPushPlatform.disabled();
    }
  }

  Future<NotificationSettings?> requestPermission() async {
    if (_requestPermission != null) return _requestPermission();
    final messaging = _messaging;
    if (!available || messaging == null) return null;
    return messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );
  }

  Future<NotificationSettings?> notificationSettings() async {
    if (_notificationSettings != null) return _notificationSettings();
    final messaging = _messaging;
    if (!available || messaging == null) return null;
    return messaging.getNotificationSettings();
  }

  Future<String?> token() async {
    if (_token != null) return _token();
    final messaging = _messaging;
    if (!available || messaging == null) return null;
    return messaging.getToken();
  }

  Future<void> deleteToken() async {
    if (_deleteToken != null) return _deleteToken();
    final messaging = _messaging;
    if (!available || messaging == null) return;
    await messaging.deleteToken();
  }

  Future<void> dispose() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _foregroundMessages.close();
    await _notificationTaps.close();
  }

  Future<void> _createAndroidChannel() async {
    final plugin = _localNotifications
        ?.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (plugin == null) return;
    final thai = PlatformDispatcher.instance.locale.languageCode == 'th';
    await plugin.createNotificationChannel(
      AndroidNotificationChannel(
        channelId,
        thai ? 'การแจ้งเตือนลูกค้า' : 'Customer updates',
        description: thai
            ? 'ข่าวสารและสถานะรายการของคุณ'
            : 'News and updates about your transactions',
        importance: Importance.high,
      ),
    );
  }

  Future<void> _onForegroundMessage(RemoteMessage message) async {
    final push = CustomerPushMessage.fromRemoteMessage(message);
    _foregroundMessages.add(push);
    if (push.title.isEmpty && push.body.isEmpty) return;

    const details = NotificationDetails(
      android: AndroidNotificationDetails(
        channelId,
        'Customer updates',
        channelDescription: 'News and updates about your transactions',
        importance: Importance.high,
        priority: Priority.high,
        icon: 'ic_stat_customer_notification',
      ),
      iOS: DarwinNotificationDetails(
        presentAlert: true,
        presentBadge: true,
        presentSound: true,
      ),
    );
    await _localNotifications?.show(
      id: push.notificationId.hashCode & 0x7fffffff,
      title: push.title,
      body: push.body,
      notificationDetails: details,
      payload: jsonEncode(push.toMap()),
    );
  }

  void _onRemoteNotificationTap(RemoteMessage message) {
    _notificationTaps.add(CustomerPushMessage.fromRemoteMessage(message));
  }

  void _onLocalNotificationTap(NotificationResponse response) {
    final message = _pushMessageFromPayload(response.payload);
    if (message != null) _notificationTaps.add(message);
  }
}

bool get _nativePushPlatform {
  if (kIsWeb) return false;
  return defaultTargetPlatform == TargetPlatform.android ||
      defaultTargetPlatform == TargetPlatform.iOS;
}

CustomerPushMessage? _pushMessageFromPayload(String? payload) {
  final value = payload?.trim() ?? '';
  if (value.isEmpty) return null;
  try {
    final decoded = jsonDecode(value);
    if (decoded is Map) {
      return CustomerPushMessage.fromMap(Map<String, dynamic>.from(decoded));
    }
  } catch (_) {
    return null;
  }
  return null;
}

String _pushText(Map<String, dynamic> value, List<String> keys) {
  for (final key in keys) {
    final text = value[key]?.toString().trim() ?? '';
    if (text.isNotEmpty && text.toLowerCase() != 'null') return text;
  }
  return '';
}
