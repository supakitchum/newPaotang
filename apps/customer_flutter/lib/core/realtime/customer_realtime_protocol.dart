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
      .replaceFirst(RegExp(r'/$'), '');
  final withAppPath = normalizedBase.contains('/app/')
      ? normalizedBase
      : '$normalizedBase/app/$encodedKey';
  final separator = withAppPath.contains('?') ? '&' : '?';
  final hasProtocol =
      RegExp(r'(^|[?&])protocol=', caseSensitive: false).hasMatch(withAppPath);

  return Uri.parse(
    hasProtocol
        ? withAppPath
        : '$withAppPath${separator}protocol=$protocol&client=${Uri.encodeQueryComponent(client)}&version=1.0&flash=false',
  );
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

Map<String, dynamic> jsonDecodeAsMap(String raw) {
  final decoded = _jsonDecode(raw);
  if (decoded is Map) return Map<String, dynamic>.from(decoded);
  return {'value': decoded};
}

Object? _jsonDecode(String raw) {
  return convert.jsonDecode(raw);
}

String normalizeRealtimeEventName(String eventName) {
  return eventName.trim().replaceFirst(RegExp(r'^\.'), '');
}

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
    return CustomerRealtimeMessage(
      event: json['event']?.toString() ?? '',
      channel: json['channel']?.toString() ?? '',
      data: json['data'],
    );
  }

  final String event;
  final String channel;
  final Object? data;

  String get normalizedEvent => normalizeRealtimeEventName(event);

  Map<String, dynamic> get dataMap => parseRealtimeData(data);
}
