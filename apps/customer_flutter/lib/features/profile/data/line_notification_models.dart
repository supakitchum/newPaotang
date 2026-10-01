import '../../../core/utils/api_payload.dart';

class LineNotificationSettings {
  const LineNotificationSettings({
    required this.lineAvailable,
    required this.botBasicId,
    required this.botDisplayName,
    required this.addFriendUrl,
    required this.liffId,
    this.identity,
  });

  factory LineNotificationSettings.fromJson(Map<String, dynamic> json) {
    final payload = _lineSettingsPayload(json);
    final bot = _firstLineMap([
      payload['bot'],
      payload['line_oa'],
      payload['lineOa'],
      payload['official_account'],
      payload['officialAccount'],
    ]);
    final liff = _firstLineMap([
      payload['liff'],
      payload['line_liff'],
      payload['lineLiff'],
    ]);
    final identity = _firstLineMap([
      payload['identity'],
      payload['line_identity'],
      payload['lineIdentity'],
      payload['connected_identity'],
      payload['connectedIdentity'],
      payload['account'],
    ]);
    return LineNotificationSettings(
      lineAvailable: _lineBool(
        payload['line_available'] ??
            payload['lineAvailable'] ??
            payload['available'] ??
            payload['enabled'] ??
            payload['status'],
      ),
      botBasicId: _firstLineText([
        payload['bot_basic_id'],
        payload['botBasicId'],
        bot['basic_id'],
        bot['basicId'],
        bot['id'],
      ]),
      botDisplayName: _firstLineText([
        payload['bot_display_name'],
        payload['botDisplayName'],
        bot['display_name'],
        bot['displayName'],
        bot['name'],
      ]),
      addFriendUrl: _firstLineText([
        payload['add_friend_url'],
        payload['addFriendUrl'],
        payload['friend_url'],
        payload['friendUrl'],
        bot['add_friend_url'],
        bot['addFriendUrl'],
        bot['friend_url'],
        bot['friendUrl'],
      ]),
      liffId: _firstLineText([
        payload['liff_id'],
        payload['liffId'],
        liff['id'],
        liff['liff_id'],
        liff['liffId'],
      ]),
      identity: identity.isEmpty ? null : LineIdentity.fromJson(identity),
    );
  }

  final bool lineAvailable;
  final String botBasicId;
  final String botDisplayName;
  final String addFriendUrl;
  final String liffId;
  final LineIdentity? identity;

  bool get isConnected => identity != null;
}

class LineIdentity {
  const LineIdentity({
    required this.id,
    required this.displayName,
    required this.pictureUrl,
    required this.friendFlag,
    required this.notificationEnabled,
  });

  factory LineIdentity.fromJson(Map<String, dynamic> json) {
    final payload = _lineIdentityPayload(json);
    return LineIdentity(
      id: _firstLineText([
        payload['id'],
        payload['identity_id'],
        payload['identityId'],
        payload['line_user_id'],
        payload['lineUserId'],
        payload['user_id'],
        payload['userId'],
      ]),
      displayName: _firstLineText([
        payload['display_name'],
        payload['displayName'],
        payload['customer_name'],
        payload['customerName'],
        payload['name'],
      ]),
      pictureUrl: _firstLineText([
        payload['picture_url'],
        payload['pictureUrl'],
        payload['avatar_url'],
        payload['avatarUrl'],
        payload['profile_image_url'],
        payload['profileImageUrl'],
      ]),
      friendFlag: _lineBool(
        payload['friend_flag'] ??
            payload['friendFlag'] ??
            payload['is_friend'] ??
            payload['isFriend'] ??
            payload['friend_status'] ??
            payload['friendStatus'],
      ),
      notificationEnabled: _lineBool(
        payload['notification_enabled'] ??
            payload['notificationEnabled'] ??
            payload['notifications_enabled'] ??
            payload['notificationsEnabled'] ??
            payload['notify'] ??
            payload['notification_status'] ??
            payload['notificationStatus'],
      ),
    );
  }

  final String id;
  final String displayName;
  final String pictureUrl;
  final bool friendFlag;
  final bool notificationEnabled;
}

Map<String, dynamic> _lineSettingsPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (json.isEmpty || depth >= 5) return json;
  const signals = {
    'line_available',
    'lineAvailable',
    'bot_basic_id',
    'botBasicId',
    'bot',
    'lineOa',
    'identity',
    'lineIdentity',
  };
  if (signals.any(json.containsKey)) return json;
  for (final key in const [
    'data',
    'result',
    'resource',
    'payload',
    'settings',
    'line_notification_settings',
    'lineNotificationSettings',
    'line_notifications',
    'lineNotifications',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    final resolved = _lineSettingsPayload(nested, depth + 1);
    if (signals.any(resolved.containsKey)) return resolved;
  }
  return json;
}

Map<String, dynamic> _lineIdentityPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (json.isEmpty || depth >= 4) return json;
  for (final key in const [
    'identity',
    'line_identity',
    'lineIdentity',
    'account',
    'profile',
    'data',
    'result',
    'resource',
    'payload',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isNotEmpty) return _lineIdentityPayload(nested, depth + 1);
  }
  return json;
}

Map<String, dynamic> _firstLineMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

String _firstLineText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _lineScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _lineScalarText(Object? value, [int depth = 0]) {
  if (value == null || depth >= 4) return '';
  if (value is String) return value.trim();
  if (value is num || value is bool) return value.toString();
  final map = asMap(value);
  if (map.isEmpty) return '';
  for (final key in const [
    'value',
    'url',
    'href',
    'id',
    'code',
    'name',
    'label',
    'rawValue',
  ]) {
    final text = _lineScalarText(map[key], depth + 1);
    if (text.isNotEmpty) return text;
  }
  return '';
}

bool _lineBool(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'on',
    'active',
    'enabled',
    'available',
    'connected',
    'friend',
    'added',
  }.contains(_lineScalarText(value).toLowerCase());
}
