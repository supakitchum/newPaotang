Map<String, dynamic> asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

Map<String, dynamic> unwrapPayload(Object? value) {
  final payload = asMap(value);
  final data = payload['data'];
  if (data is Map) return Map<String, dynamic>.from(data);
  final result = payload['result'];
  if (result is Map) return Map<String, dynamic>.from(result);
  final resource = payload['resource'];
  if (resource is Map) return Map<String, dynamic>.from(resource);
  return payload;
}

List<Map<String, dynamic>> unwrapDataList(Object? value) {
  final payload = asMap(value);
  if (payload['data'] is List) return asMapList(payload['data']);
  if (payload['result'] is List) return asMapList(payload['result']);
  if (payload['data'] is Map) {
    final data = asMap(payload['data']);
    if (data['data'] is List) return asMapList(data['data']);
    if (data['result'] is List) return asMapList(data['result']);
  }
  return const [];
}
