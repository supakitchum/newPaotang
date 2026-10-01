import '../../../core/utils/api_payload.dart';

class CustomerNotificationAction {
  const CustomerNotificationAction({required this.key, this.entityId = ''});

  final String key;
  final String entityId;

  factory CustomerNotificationAction.fromJson(Object? value) {
    final json = asMap(value);
    return CustomerNotificationAction(
      key: _notificationText(json, const ['key', 'action_key', 'actionKey']),
      entityId: _notificationText(json, const [
        'entity_id',
        'entityId',
        'action_entity_id',
        'actionEntityId',
      ]),
    );
  }
}

class CustomerNotificationItem {
  const CustomerNotificationItem({
    required this.id,
    required this.category,
    required this.eventKey,
    required this.title,
    required this.body,
    required this.iconKey,
    required this.action,
    required this.isRead,
    required this.createdAt,
    this.readAt,
    this.subjectType = '',
    this.subjectId = '',
    this.imageUrl = '',
    this.imageThumbUrl = '',
  });

  final String id;
  final String category;
  final String eventKey;
  final String title;
  final String body;
  final String iconKey;
  final CustomerNotificationAction action;
  final bool isRead;
  final DateTime? readAt;
  final DateTime? createdAt;
  final String subjectType;
  final String subjectId;
  final String imageUrl;
  final String imageThumbUrl;

  CustomerNotificationItem copyWith({
    bool? isRead,
    DateTime? readAt,
    bool clearReadAt = false,
  }) {
    return CustomerNotificationItem(
      id: id,
      category: category,
      eventKey: eventKey,
      title: title,
      body: body,
      iconKey: iconKey,
      action: action,
      isRead: isRead ?? this.isRead,
      readAt: clearReadAt ? null : (readAt ?? this.readAt),
      createdAt: createdAt,
      subjectType: subjectType,
      subjectId: subjectId,
      imageUrl: imageUrl,
      imageThumbUrl: imageThumbUrl,
    );
  }

  factory CustomerNotificationItem.fromJson(Object? value) {
    final json = unwrapPayload(value);
    final subject = asMap(json['subject']);
    return CustomerNotificationItem(
      id: _notificationText(json, const [
        'id',
        'notification_id',
        'notificationId',
      ]),
      category: _notificationText(json, const ['category']),
      eventKey: _notificationText(json, const [
        'event_key',
        'eventKey',
        'type',
      ]),
      title: _notificationText(json, const ['title']),
      body: _notificationText(json, const ['body', 'message', 'summary']),
      iconKey: _notificationText(json, const ['icon_key', 'iconKey', 'icon']),
      action: CustomerNotificationAction.fromJson(json['action']),
      isRead: _notificationBool(json, const ['is_read', 'isRead', 'read']),
      readAt: _notificationDate(
        _notificationValue(json, const ['read_at', 'readAt']),
      ),
      createdAt: _notificationDate(
        _notificationValue(json, const [
          'created_at',
          'createdAt',
          'published_at',
          'publishedAt',
        ]),
      ),
      subjectType: _notificationText(subject, const [
        'type',
        'subject_type',
        'subjectType',
      ]),
      subjectId: _notificationText(subject, const [
        'id',
        'subject_id',
        'subjectId',
      ]),
      imageUrl: _notificationText(json, const ['image_url', 'imageUrl']),
      imageThumbUrl: _notificationText(json, const [
        'image_thumb_url',
        'imageThumbUrl',
        'image_url',
        'imageUrl',
      ]),
    );
  }
}

class CustomerNotificationPage {
  const CustomerNotificationPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
    required this.unreadCount,
  });

  final List<CustomerNotificationItem> items;
  final String nextCursor;
  final bool hasMore;
  final int unreadCount;

  factory CustomerNotificationPage.fromJson(Object? value) {
    final payload = asMap(value);
    final meta = unwrapMeta(payload);
    return CustomerNotificationPage(
      items: unwrapDataList(payload)
          .map(CustomerNotificationItem.fromJson)
          .where((item) => item.id.isNotEmpty)
          .toList(growable: false),
      nextCursor: _notificationText(meta, const [
        'next_cursor',
        'nextCursor',
        'cursor',
      ]),
      hasMore: _notificationBool(meta, const ['has_more', 'hasMore', 'more']),
      unreadCount: _notificationInt(meta, const [
        'unread_count',
        'unreadCount',
      ]),
    );
  }
}

Object? _notificationValue(Map<String, dynamic> json, List<String> keys) {
  for (final key in keys) {
    if (json.containsKey(key)) return json[key];
  }
  return null;
}

String _notificationText(Map<String, dynamic> json, List<String> keys) {
  final value = _notificationValue(json, keys);
  final text = value?.toString().trim() ?? '';
  return text.toLowerCase() == 'null' ? '' : text;
}

int _notificationInt(Map<String, dynamic> json, List<String> keys) {
  final value = _notificationValue(json, keys);
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _notificationBool(Map<String, dynamic> json, List<String> keys) {
  final value = _notificationValue(json, keys);
  if (value is bool) return value;
  if (value is num) return value != 0;
  return const {
    '1',
    'true',
    'yes',
    'read',
  }.contains(value?.toString().trim().toLowerCase());
}

DateTime? _notificationDate(Object? value) {
  if (value is DateTime) return value.toLocal();
  final text = value?.toString().trim() ?? '';
  if (text.isEmpty) return null;
  return DateTime.tryParse(text)?.toLocal();
}
