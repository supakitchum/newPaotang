import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../tenant/customer_tenant_host.dart';
import '../utils/idempotency_key.dart';

final customerPushInstallationStoreProvider =
    Provider<CustomerPushInstallationStore>((ref) {
      return CustomerPushInstallationStore(
        storageScope: ref.watch(apiClientProvider).currentTenantHost,
      );
    });

class CustomerPushInstallationStore {
  CustomerPushInstallationStore({
    String storageScope = '',
    FlutterSecureStorage? storage,
  }) : _scope = customerTenantStorageScope(storageScope),
       _storage = storage ?? const FlutterSecureStorage();

  static const _installationKey = 'customer_push_installation_id';
  static const _installationSecretKey = 'customer_push_installation_secret';
  static const _permissionRequestedKey = 'customer_push_permission_requested';

  final String _scope;
  final FlutterSecureStorage _storage;
  String? _installationId;
  String? _installationSecret;
  bool? _permissionRequested;

  Future<String> installationId() async {
    final cached = _installationId?.trim() ?? '';
    if (cached.isNotEmpty) return cached;

    try {
      final stored =
          (await _storage.read(key: _key(_installationKey)))?.trim() ?? '';
      if (stored.isNotEmpty) {
        _installationId = stored;
        return stored;
      }
    } catch (_) {
      // A generated in-memory installation still lets the current session work.
    }

    final generated = newIdempotencyKey('install');
    _installationId = generated;
    try {
      await _storage.write(key: _key(_installationKey), value: generated);
    } catch (_) {}
    return generated;
  }

  Future<String> installationSecret() async {
    final cached = _installationSecret?.trim() ?? '';
    if (cached.isNotEmpty) return cached;

    try {
      final stored =
          (await _storage.read(key: _key(_installationSecretKey)))?.trim() ??
          '';
      if (stored.isNotEmpty) {
        _installationSecret = stored;
        return stored;
      }
    } catch (_) {
      // The in-memory credential still protects this process when storage fails.
    }

    final generated = newIdempotencyKey('push_secret');
    _installationSecret = generated;
    try {
      await _storage.write(key: _key(_installationSecretKey), value: generated);
    } catch (_) {}
    return generated;
  }

  Future<bool> permissionRequested() async {
    final cached = _permissionRequested;
    if (cached != null) return cached;
    try {
      final value = await _storage.read(key: _key(_permissionRequestedKey));
      _permissionRequested = value == '1' || value == 'true';
    } catch (_) {
      _permissionRequested = false;
    }
    return _permissionRequested ?? false;
  }

  Future<void> markPermissionRequested() async {
    _permissionRequested = true;
    try {
      await _storage.write(key: _key(_permissionRequestedKey), value: '1');
    } catch (_) {}
  }

  String _key(String value) => _scope.isEmpty ? value : '${_scope}_$value';
}
