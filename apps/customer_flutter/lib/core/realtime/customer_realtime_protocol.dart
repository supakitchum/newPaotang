import 'dart:convert' as convert;

import '../tenant/mobile_bootstrap_controller.dart';

class CustomerRealtimeProtocol {
  const CustomerRealtimeProtocol._();

  static Uri socketUri(MobileRealtimeConfig config) {
    return buildRealtimeSocketUri(
      baseUrl: config.url,
      key: config.key,
      protocol: config.protocol,
      client: config.client,
    );
  }
}

Uri buildRealtimeSocketUri({
  required String baseUrl,
  required String key,
  int protocol = 7,
  String client = 'customer-flutter',
}) {
  final trimmed = baseUrl.trim();
  if (trimmed.isEmpty) {
    throw ArgumentError.value(baseUrl, 'baseUrl', 'Realtime URL is required.');
  }
  final trimmedKey = key.trim();
  if (trimmedKey.isEmpty) {
    throw ArgumentError.value(key, 'key', 'Realtime app key is required.');
  }

  final encodedKey = Uri.encodeComponent(trimmedKey);
  final normalizedBase = trimmed
      .replaceFirst(RegExp('^http:', caseSensitive: false), 'ws:')
      .replaceFirst(RegExp('^https:', caseSensitive: false), 'wss:')
      .trim();
  final withAppPath = _realtimeSocketUrlWithAppPath(
    normalizedBase,
    encodedKey,
  );
  final separator = withAppPath.contains('?') ? '&' : '?';
  final hasProtocol =
      RegExp(r'(^|[?&])protocol=', caseSensitive: false).hasMatch(withAppPath);

  return Uri.parse(
    hasProtocol
        ? withAppPath
        : '$withAppPath${separator}protocol=$protocol&client=${Uri.encodeQueryComponent(client)}&version=1.0&flash=false',
  );
}

String _realtimeSocketUrlWithAppPath(String baseUrl, String encodedKey) {
  final queryIndex = baseUrl.indexOf('?');
  final basePath = queryIndex == -1
      ? baseUrl.replaceFirst(RegExp(r'/+$'), '')
      : baseUrl.substring(0, queryIndex).replaceFirst(RegExp(r'/+$'), '');
  final query = queryIndex == -1 ? '' : baseUrl.substring(queryIndex);
  final appPath = RegExp(r'/app(?:/([^/?#]+))?$', caseSensitive: false)
      .firstMatch(basePath);
  if (appPath != null) {
    final existingKey = appPath.group(1)?.trim() ?? '';
    return existingKey.isEmpty
        ? '$basePath/$encodedKey$query'
        : '$basePath$query';
  }
  return '$basePath/app/$encodedKey$query';
}

CustomerRealtimeMessage parseRealtimeMessage(Object? raw) {
  if (raw is CustomerRealtimeMessage) return raw;
  if (raw is Map) {
    return CustomerRealtimeMessage.fromJson(Map<String, dynamic>.from(raw));
  }
  if (raw is String) {
    try {
      final decoded = jsonDecodeAsMap(raw);
      return CustomerRealtimeMessage.fromJson(decoded);
    } catch (_) {
      return const CustomerRealtimeMessage.empty();
    }
  }
  return const CustomerRealtimeMessage.empty();
}

Map<String, dynamic> parseRealtimeData(Object? raw) {
  if (raw == null || raw == '') return const {};
  if (raw is Map) return Map<String, dynamic>.from(raw);
  if (raw is String) {
    try {
      return jsonDecodeAsMap(raw);
    } catch (_) {
      return {'value': raw};
    }
  }
  return {'value': raw};
}

Map<String, dynamic> normalizeRealtimePayload(Map<String, dynamic> payload) {
  final normalized = Map<String, dynamic>.from(payload);

  void mergeWrappedPayload(Object? value, int depth) {
    if (depth > 3) return;
    final nested = _realtimePayloadMapFromValue(value);
    if (nested == null) return;

    for (final entry in nested.entries) {
      if (_isBlankRealtimePayloadValue(normalized[entry.key])) {
        normalized[entry.key] = entry.value;
      }
    }

    for (final key in _realtimePayloadWrapperKeys) {
      mergeWrappedPayload(nested[key], depth + 1);
    }
  }

  for (final key in _realtimePayloadWrapperKeys) {
    mergeWrappedPayload(payload[key], 0);
  }

  return normalized;
}

Map<String, dynamic>? _realtimePayloadMapFromValue(Object? value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  if (value is String) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('{')) return null;
    try {
      return jsonDecodeAsMap(trimmed);
    } catch (_) {
      return null;
    }
  }
  return null;
}

bool _isBlankRealtimePayloadValue(Object? value) {
  return value == null || (value is String && value.trim().isEmpty);
}

Map<String, dynamic> jsonDecodeAsMap(String raw) {
  final decoded = _jsonDecode(raw);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {'value': decoded};
}

Object? _jsonDecode(String raw) {
  return convert.jsonDecode(raw);
}

String normalizeRealtimeEventName(String eventName) {
  final normalized = eventName.trim().replaceFirst(RegExp(r'^\.+'), '');
  if (normalized.isEmpty) return '';

  final className = normalized.split('\\').last;
  final compactKey =
      className.replaceAll(RegExp(r'[^A-Za-z0-9]+'), '').toLowerCase();
  return _canonicalRealtimeEvents[compactKey] ?? normalized;
}

String normalizeRealtimeEventNameWithPayload({
  required String eventName,
  required Map<String, dynamic> payload,
}) {
  final normalized = normalizeRealtimeEventName(eventName);
  if (_isCanonicalRealtimeEvent(normalized)) return normalized;

  final payloadEventName = _payloadRealtimeEventName(payload);
  if (payloadEventName.isEmpty) return normalized;

  return normalizeRealtimeEventName(payloadEventName);
}

bool _isCanonicalRealtimeEvent(String eventName) {
  return _canonicalRealtimeEvents.containsValue(eventName);
}

String _payloadRealtimeEventName(Map<String, dynamic> payload) {
  for (final key in _directRealtimeEventNameKeys) {
    final eventName = _realtimeEventScalarText(payload[key]);
    if (eventName.isNotEmpty) return eventName;
  }
  final providerEventName = _providerPayloadRealtimeEventName(payload);
  if (providerEventName.isNotEmpty) return providerEventName;
  for (final key in _realtimePayloadWrapperKeys) {
    final nested = _payloadRealtimeEventNameFromValue(payload[key], depth: 0);
    if (nested.isNotEmpty) return nested;
  }
  return '';
}

String _providerPayloadRealtimeEventName(Map<String, dynamic> payload) {
  for (final key in _providerRealtimeEventNameKeys) {
    final eventName = _realtimeEventScalarText(payload[key]);
    if (eventName.isNotEmpty &&
        _isCanonicalRealtimeEvent(normalizeRealtimeEventName(eventName))) {
      return eventName;
    }
  }
  return '';
}

String _payloadRealtimeEventNameFromValue(
  Object? value, {
  required int depth,
}) {
  if (depth > 2) return '';
  if (value is Map) {
    return _payloadRealtimeEventNameFromMap(
      Map<String, dynamic>.from(value),
      depth: depth + 1,
    );
  }
  if (value is String) {
    final trimmed = value.trim();
    if (!trimmed.startsWith('{')) return '';
    try {
      return _payloadRealtimeEventNameFromMap(
        jsonDecodeAsMap(trimmed),
        depth: depth + 1,
      );
    } catch (_) {
      return '';
    }
  }
  return '';
}

String _payloadRealtimeEventNameFromMap(
  Map<String, dynamic> payload, {
  required int depth,
}) {
  for (final key in _directRealtimeEventNameKeys) {
    final eventName = _realtimeEventScalarText(payload[key]);
    if (eventName.isNotEmpty) return eventName;
  }
  final providerEventName = _providerPayloadRealtimeEventName(payload);
  if (providerEventName.isNotEmpty) return providerEventName;
  for (final key in _realtimePayloadWrapperKeys) {
    final nested = _payloadRealtimeEventNameFromValue(
      payload[key],
      depth: depth,
    );
    if (nested.isNotEmpty) return nested;
  }
  return '';
}

String _realtimeEventScalarText(Object? value, {int depth = 0}) {
  if (value == null || depth > 4) return '';
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('{')) {
      final nested = _realtimePayloadMapFromValue(trimmed);
      if (nested == null) return trimmed;
      return _realtimeEventScalarText(nested, depth: depth + 1);
    }
    return trimmed;
  }

  final nested = _realtimePayloadMapFromValue(value);
  if (nested == null) return '';
  for (final key in _realtimeScalarWrapperKeys) {
    final scalar = _realtimeEventScalarText(nested[key], depth: depth + 1);
    if (scalar.isNotEmpty) return scalar;
  }
  for (final key in _directRealtimeEventNameKeys) {
    final scalar = _realtimeEventScalarText(nested[key], depth: depth + 1);
    if (scalar.isNotEmpty) return scalar;
  }
  for (final key in _providerRealtimeEventNameKeys) {
    final scalar = _realtimeEventScalarText(nested[key], depth: depth + 1);
    if (scalar.isNotEmpty) return scalar;
  }
  return '';
}

const List<String> _realtimeScalarWrapperKeys = [
  'value',
  'code',
  'key',
  'text',
  'label',
  'raw',
  'rawValue',
  'raw_value',
  'string',
  'stringValue',
  'string_value',
];

const List<String> _directRealtimeEventNameKeys = [
  'event_type',
  'eventType',
  'event_key',
  'eventKey',
  'event_code',
  'eventCode',
  'event_name',
  'eventName',
  'event_label',
  'eventLabel',
  'event_text',
  'eventText',
  'raw_event',
  'rawEvent',
  'event_class',
  'eventClass',
  'event_class_name',
  'eventClassName',
  'event_classname',
  'eventClassname',
  'event_fqcn',
  'eventFqcn',
  'eventFQCN',
  'broadcast_as',
  'broadcastAs',
  'broadcast_event',
  'broadcastEvent',
  'broadcast_name',
  'broadcastName',
  'domain_event',
  'domainEvent',
  'domain_event_name',
  'domainEventName',
  'message_name',
  'messageName',
  'notification_name',
  'notificationName',
];

const List<String> _providerRealtimeEventNameKeys = [
  'event',
  'type',
  'name',
  'topic',
  'action',
  'kind',
  'class',
  'class_name',
  'className',
  'subject',
  'notification_type',
  'notificationType',
  'notification',
  'message_type',
  'messageType',
  'messageName',
  'routing_key',
  'routingKey',
];

const List<String> _realtimePayloadWrapperKeys = [
  'data',
  'data_json',
  'dataJson',
  'event_data',
  'eventData',
  'event_envelope',
  'eventEnvelope',
  'event_message',
  'eventMessage',
  'event_json',
  'eventJson',
  'event',
  'payload',
  'payload_json',
  'payloadJson',
  'payloadJSON',
  'payload_data',
  'payloadData',
  'payload_envelope',
  'payloadEnvelope',
  'result',
  'result_json',
  'resultJson',
  'resource',
  'resource_json',
  'resourceJson',
  'resource_data',
  'resourceData',
  'envelope',
  'envelope_json',
  'envelopeJson',
  'message_envelope',
  'messageEnvelope',
  'data_envelope',
  'dataEnvelope',
  'record_envelope',
  'recordEnvelope',
  'outbox',
  'outbox_message',
  'outboxMessage',
  'broadcast',
  'broadcast_message',
  'broadcastMessage',
  'domain_event_payload',
  'domainEventPayload',
  'domain_event',
  'domainEvent',
  'notification',
  'notification_json',
  'notificationJson',
  'notification_data',
  'notificationData',
  'message',
  'message_json',
  'messageJson',
  'message_data',
  'messageData',
  'message_payload',
  'messagePayload',
  'body',
  'body_json',
  'bodyJson',
  'meta',
  'metadata',
  'context',
  'details',
  'detail',
  'object',
  'model',
  'record',
  'row',
  'item',
  'attributes',
  'event_payload',
  'event_payload_json',
  'eventPayload',
  'eventPayloadJson',
  'eventPayloadJSON',
];

const List<String> _realtimeMessageEventKeys = [
  'event',
  'event_name',
  'eventName',
  'event_type',
  'eventType',
  'event_key',
  'eventKey',
  'event_code',
  'eventCode',
  'type',
  'name',
  'message_name',
  'messageName',
  'event_label',
  'eventLabel',
  'event_text',
  'eventText',
  'raw_event',
  'rawEvent',
  'notification_name',
  'notificationName',
  'broadcast_as',
  'broadcastAs',
  'broadcast_event',
  'broadcastEvent',
  'domain_event_name',
  'domainEventName',
  'routing_key',
  'routingKey',
];

const List<String> _realtimeMessageChannelKeys = [
  'channel',
  'channel_name',
  'channelName',
  'channel_key',
  'channelKey',
  'channel_info',
  'channelInfo',
  'channel_context',
  'channelContext',
  'subscription_channel',
  'subscriptionChannel',
  'subscription_name',
  'subscriptionName',
  'subscription_info',
  'subscriptionInfo',
  'subscription_context',
  'subscriptionContext',
  'subscription',
  'stream',
  'room',
  'private_channel',
  'privateChannel',
  'presence_channel',
  'presenceChannel',
];

const List<String> _realtimeMessageDataKeys = [
  'data',
  'data_json',
  'dataJson',
  'dataJSON',
  'event_data',
  'eventData',
  'event_envelope',
  'eventEnvelope',
  'event_message',
  'eventMessage',
  'event_json',
  'eventJson',
  'payload',
  'payload_json',
  'payloadJson',
  'payloadJSON',
  'payload_data',
  'payloadData',
  'payload_envelope',
  'payloadEnvelope',
  'resource',
  'resource_json',
  'resourceJson',
  'resource_data',
  'resourceData',
  'result',
  'result_json',
  'resultJson',
  'message_payload',
  'messagePayload',
  'message_data',
  'messageData',
  'message_json',
  'messageJson',
  'notification_data',
  'notificationData',
  'notification_json',
  'notificationJson',
  'envelope',
  'envelope_json',
  'envelopeJson',
  'message_envelope',
  'messageEnvelope',
  'data_envelope',
  'dataEnvelope',
  'record_envelope',
  'recordEnvelope',
  'outbox',
  'outbox_message',
  'outboxMessage',
  'broadcast',
  'broadcast_message',
  'broadcastMessage',
  'domain_event_payload',
  'domainEventPayload',
  'domain_event',
  'domainEvent',
  'body',
  'body_json',
  'bodyJson',
  'meta',
  'metadata',
  'context',
  'details',
  'detail',
  'object',
  'model',
  'record',
  'row',
  'item',
  'attributes',
  'event_payload',
  'event_payload_json',
  'eventPayload',
  'eventPayloadJson',
  'eventPayloadJSON',
];

const Map<String, String> _canonicalRealtimeEvents = {
  'stockupdated': 'stock.availability.updated',
  'stockallocatedv1': 'stock.availability.updated',
  'stockavailabilityupdated': 'stock.availability.updated',
  'stockremainingupdated': 'stock.availability.updated',
  'stocksoldv1': 'stock.availability.updated',
  'stockunavailablev1': 'stock.availability.updated',
  'lotterystockupdated': 'stock.availability.updated',
  'lotterystockavailabilityupdated': 'stock.availability.updated',
  'lotterysoldout': 'stock.availability.updated',
  'stockpricechanged': 'stock.price.updated',
  'stockpriceupdated': 'stock.price.updated',
  'salepriceupdated': 'stock.price.updated',
  'lotterypriceupdated': 'stock.price.updated',
  'lotterysalepriceupdated': 'stock.price.updated',
  'cartupdated': 'cart.updated',
  'customercartupdated': 'cart.updated',
  'cartreservationupdated': 'cart.updated',
  'reservationupdated': 'cart.updated',
  'cartreservationreleased': 'cart.updated',
  'cartreservationexpired': 'cart.updated',
  'reservationreleased': 'cart.updated',
  'reservationreleasedv1': 'cart.updated',
  'reservationexpired': 'cart.updated',
  'reservationexpiredv1': 'cart.updated',
  'ordercreated': 'order.updated',
  'orderupdated': 'order.updated',
  'orderpaid': 'order.updated',
  'orderpaidv1': 'order.updated',
  'customerorderupdated': 'order.updated',
  'customerorderpaid': 'order.updated',
  'ticketcreated': 'tickets.updated',
  'ticketupdated': 'tickets.updated',
  'ticketsupdated': 'tickets.updated',
  'customerticketcreated': 'tickets.updated',
  'customerticketupdated': 'tickets.updated',
  'customerticketsupdated': 'tickets.updated',
  'topupcreated': 'topup.updated',
  'topuppaid': 'topup.updated',
  'topupupdated': 'topup.updated',
  'topupstatusupdated': 'topup.updated',
  'topuprequestupdated': 'topup.updated',
  'customertopupupdated': 'topup.updated',
  'customertopupstatusupdated': 'topup.updated',
  'walletupdated': 'topup.updated',
  'walletupdatedv1': 'topup.updated',
  'walletbalanceupdated': 'topup.updated',
  'walletbalancechanged': 'topup.updated',
  'walletledgerupdated': 'topup.updated',
  'walletledgercreated': 'topup.updated',
  'walletledgerentryupdated': 'topup.updated',
  'walletledgerentrycreated': 'topup.updated',
  'wallettransactionupdated': 'topup.updated',
  'wallettransactioncreated': 'topup.updated',
  'wallettransactionsupdated': 'topup.updated',
  'customerwalletupdated': 'topup.updated',
  'customerwalletbalanceupdated': 'topup.updated',
  'customerwalletledgerupdated': 'topup.updated',
  'customerwalletledgerentryupdated': 'topup.updated',
  'customerwalletledgerentrycreated': 'topup.updated',
  'customerwallettransactionupdated': 'topup.updated',
  'customerwallettransactioncreated': 'topup.updated',
  'siteconfigchanged': 'site-config.updated',
  'siteconfigupdated': 'site-config.updated',
  'tenantsiteconfigupdated': 'site-config.updated',
  'maintenancechangedv1': 'site-config.updated',
  'maintenanceupdated': 'site-config.updated',
  'mobilebootstrapupdated': 'site-config.updated',
  'tenantsettingsupdated': 'site-config.updated',
  'rewardclaimcreated': 'reward.claim.updated',
  'rewardclaimupdated': 'reward.claim.updated',
  'rewardclaimstatusupdated': 'reward.claim.updated',
  'rewardclaimapproved': 'reward.claim.updated',
  'rewardclaimrejected': 'reward.claim.updated',
  'rewardclaimfailed': 'reward.claim.updated',
  'rewardclaimcancelled': 'reward.claim.updated',
  'rewardclaimpaid': 'reward.claim.updated',
  'customerrewardclaimupdated': 'reward.claim.updated',
  'customerrewardclaimstatusupdated': 'reward.claim.updated',
  'customerrewardclaimapproved': 'reward.claim.updated',
  'customerrewardclaimrejected': 'reward.claim.updated',
  'customerrewardclaimfailed': 'reward.claim.updated',
  'customerrewardclaimcancelled': 'reward.claim.updated',
  'customerrewardclaimpaid': 'reward.claim.updated',
  'activityclaimcreated': 'activity.claim.updated',
  'activityclaimupdated': 'activity.claim.updated',
  'activityclaimstatusupdated': 'activity.claim.updated',
  'activityclaimapproved': 'activity.claim.updated',
  'activityclaimrejected': 'activity.claim.updated',
  'activityclaimfailed': 'activity.claim.updated',
  'activityclaimcancelled': 'activity.claim.updated',
  'activityclaimpaid': 'activity.claim.updated',
  'customeractivityclaimupdated': 'activity.claim.updated',
  'customeractivityclaimstatusupdated': 'activity.claim.updated',
  'customeractivityclaimapproved': 'activity.claim.updated',
  'customeractivityclaimrejected': 'activity.claim.updated',
  'customeractivityclaimfailed': 'activity.claim.updated',
  'customeractivityclaimcancelled': 'activity.claim.updated',
  'customeractivityclaimpaid': 'activity.claim.updated',
  'rewardresultpublished': 'reward.result.live.updated',
  'rewardresultliveupdated': 'reward.result.live.updated',
  'rewardresultupdated': 'reward.result.live.updated',
  'rewardresultdrawn': 'reward.result.live.updated',
  'rewardresultfinalized': 'reward.result.live.updated',
  'rewardpublishedv1': 'reward.result.live.updated',
  'resultpublished': 'reward.result.live.updated',
  'resultliveupdated': 'reward.result.live.updated',
  'resultupdated': 'reward.result.live.updated',
  'resultdrawn': 'reward.result.live.updated',
  'resultfinalized': 'reward.result.live.updated',
};

bool isAuthorizedRealtimeChannel(String channel) {
  final normalized = channel.trim();
  return normalized.startsWith('private-') ||
      normalized.startsWith('presence-');
}

String stockAvailabilityChannel({
  required String tenantId,
  required String gameId,
}) {
  return 'customer.tenant.$tenantId.stock.game.$gameId';
}

String salePriceChannel({required String tenantId}) {
  return 'customer.tenant.$tenantId.sale-price';
}

String siteConfigChannel({required String tenantId}) {
  return 'customer.tenant.$tenantId.site-config';
}

String customerTopupChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.topups';
}

String customerWalletChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.wallet';
}

String customerCartChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.cart';
}

String customerOrdersChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.orders';
}

String customerTicketsChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.tickets';
}

String customerRewardClaimChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.reward-claims';
}

String customerActivityClaimChannel({
  required String tenantId,
  required String customerId,
}) {
  return 'private-customer.tenant.$tenantId.customer.$customerId.activity-claims';
}

String customerPresenceChannel({required String tenantId}) {
  return 'presence-customer.tenant.$tenantId.customers';
}

String publicLatestResultChannel() {
  return 'public.results.latest';
}

String publicGameResultChannel({required String gameId}) {
  return 'public.results.game.$gameId';
}

class CustomerRealtimeMessage {
  const CustomerRealtimeMessage({
    required this.event,
    required this.channel,
    required this.data,
  });

  const CustomerRealtimeMessage.empty()
      : event = '',
        channel = '',
        data = const {};

  factory CustomerRealtimeMessage.fromJson(Map<String, dynamic> json) {
    final data = _realtimeMessageData(json);
    return CustomerRealtimeMessage(
      event: _realtimeMessageEvent(json, data),
      channel: _realtimeMessageChannel(json),
      data: data,
    );
  }

  final String event;
  final String channel;
  final Object? data;

  String get normalizedEvent => normalizeRealtimeEventName(event);

  Map<String, dynamic> get dataMap =>
      normalizeRealtimePayload(parseRealtimeData(data));
}

String _realtimeMessageEvent(Map<String, dynamic> json, Object? data) {
  final eventName = _firstRealtimeMessageText(json, _realtimeMessageEventKeys);
  if (eventName.isNotEmpty) return eventName;

  return _payloadRealtimeEventNameFromValue(data, depth: 0);
}

String _realtimeMessageChannel(Map<String, dynamic> json) {
  return _firstRealtimeMessageText(json, _realtimeMessageChannelKeys);
}

Object? _realtimeMessageData(Map<String, dynamic> json) {
  for (final key in _realtimeMessageDataKeys) {
    if (!json.containsKey(key)) continue;
    final value = json[key];
    if (_hasRealtimeMessageData(value)) {
      return _mergeRealtimeMessageData(json, value);
    }
  }

  return json;
}

Map<String, dynamic> _mergeRealtimeMessageData(
  Map<String, dynamic> json,
  Object? data,
) {
  final merged = Map<String, dynamic>.from(json);
  final dataMap = parseRealtimeData(data);
  for (final entry in dataMap.entries) {
    if (_isBlankRealtimePayloadValue(entry.value)) continue;
    merged[entry.key] = entry.value;
  }
  return merged;
}

bool _hasRealtimeMessageData(Object? value) {
  if (value == null) return false;
  if (value is String) return value.trim().isNotEmpty;
  if (value is Map) return value.isNotEmpty;
  if (value is Iterable) return value.isNotEmpty;
  return true;
}

String _firstRealtimeMessageText(
  Map<String, dynamic> json,
  List<String> keys,
) {
  for (final key in keys) {
    final text = _realtimeMessageTextFromValue(json[key], keys: keys);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _realtimeMessageTextFromValue(
  Object? value, {
  required List<String> keys,
  int depth = 0,
}) {
  if (value == null || depth > 4) return '';
  if (value is String) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    if (trimmed.startsWith('{')) {
      final nested = _realtimePayloadMapFromValue(trimmed);
      if (nested == null) return trimmed;
      return _realtimeMessageTextFromValue(
        nested,
        keys: keys,
        depth: depth + 1,
      );
    }
    return trimmed;
  }
  if (value is num || value is bool) return value.toString();

  final nested = _realtimePayloadMapFromValue(value);
  if (nested == null) return '';
  for (final key in _realtimeScalarWrapperKeys) {
    final text = _realtimeMessageTextFromValue(
      nested[key],
      keys: keys,
      depth: depth + 1,
    );
    if (text.isNotEmpty) return text;
  }
  for (final key in keys) {
    final text = _realtimeMessageTextFromValue(
      nested[key],
      keys: keys,
      depth: depth + 1,
    );
    if (text.isNotEmpty) return text;
  }
  return '';
}
