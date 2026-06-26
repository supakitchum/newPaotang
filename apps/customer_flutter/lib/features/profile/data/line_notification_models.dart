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
    return LineNotificationSettings(
      lineAvailable: json['line_available'] == true,
      botBasicId: json['bot_basic_id']?.toString() ?? '',
      botDisplayName: json['bot_display_name']?.toString() ?? '',
      addFriendUrl: json['add_friend_url']?.toString() ?? '',
      liffId: (json['liff_id'] ?? asMap(json['liff'])['id'])?.toString() ?? '',
      identity: json['identity'] is Map
          ? LineIdentity.fromJson(asMap(json['identity']))
          : null,
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
    return LineIdentity(
      id: json['id']?.toString() ?? '',
      displayName:
          (json['display_name'] ?? json['customer_name'])?.toString() ?? '',
      pictureUrl: json['picture_url']?.toString() ?? '',
      friendFlag: json['friend_flag'] == true,
      notificationEnabled: json['notification_enabled'] == true,
    );
  }

  final String id;
  final String displayName;
  final String pictureUrl;
  final bool friendFlag;
  final bool notificationEnabled;
}
