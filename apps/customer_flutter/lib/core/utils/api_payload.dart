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
  return _unwrapDataListCandidate(value);
}

Map<String, dynamic> unwrapMeta(Object? value) {
  final payload = asMap(value);
  final directMeta = asMap(payload['meta']);
  if (directMeta.isNotEmpty) return directMeta;

  for (final key in const ['data', 'result', 'resource']) {
    if (!payload.containsKey(key)) continue;
    final nestedMeta = asMap(asMap(payload[key])['meta']);
    if (nestedMeta.isNotEmpty) return nestedMeta;
  }

  return const <String, dynamic>{};
}

List<Map<String, dynamic>> _unwrapDataListCandidate(
  Object? value, [
  int depth = 0,
]) {
  if (value is List) return asMapList(value);
  if (depth >= 4) return const [];

  final payload = asMap(value);
  if (payload.isEmpty) return const [];

  for (final key in const ['data', 'result', 'resource', 'items']) {
    if (!payload.containsKey(key)) continue;
    final rows = _unwrapDataListCandidate(payload[key], depth + 1);
    if (rows.isNotEmpty || payload[key] is List) {
      return rows;
    }
  }

  return const [];
}
