import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final publicVisitIdStoreProvider = Provider<PublicVisitIdStore>((ref) {
  return PublicVisitIdStore();
});

class PublicVisitIdStore {
  PublicVisitIdStore({
    FlutterSecureStorage? storage,
    String Function(String prefix)? idFactory,
  })  : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            ),
        _idFactory = idFactory ?? _randomId;

  final FlutterSecureStorage _storage;
  final String Function(String prefix) _idFactory;
  final Map<String, String> _memoryVisitorIds = {};
  final Map<String, String> _sessionIds = {};

  Future<String> visitorId(String hostScope) async {
    final scope = normalizePublicVisitHostScope(hostScope);
    final key = 'public_visitor_$scope';
    final memory = _memoryVisitorIds[key];
    if (memory != null && memory.isNotEmpty) return memory;

    try {
      final existing = await _storage.read(key: key);
      if (existing != null && existing.isNotEmpty) {
        _memoryVisitorIds[key] = existing;
        return existing;
      }

      final next = _idFactory('pv');
      await _storage.write(key: key, value: next);
      _memoryVisitorIds[key] = next;
      return next;
    } catch (_) {
      return _memoryVisitorIds.putIfAbsent(key, () => _idFactory('pv'));
    }
  }

  String sessionId(String hostScope) {
    final scope = normalizePublicVisitHostScope(hostScope);
    return _sessionIds.putIfAbsent(
      'public_visit_session_$scope',
      () => _idFactory('pvs'),
    );
  }
}

String normalizePublicVisitHostScope(String value) {
  final normalized = value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[^a-z0-9:_\-.]'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^[_\-.]+|[_\-.]+$'), '');
  return normalized.isEmpty ? 'default' : normalized;
}

String _randomId(String prefix) {
  final now = DateTime.now().microsecondsSinceEpoch;
  final random = Random.secure().nextInt(1 << 32).toRadixString(36);
  return '${prefix}_${now}_$random';
}
