import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  setUp(() {
    FlutterSecureStorage.setMockInitialValues({});
  });

  test('migrates an existing unscoped session without logging out', () async {
    FlutterSecureStorage.setMockInitialValues({
      'customer_access_token': 'legacy-access',
      'customer_refresh_token': 'legacy-refresh',
      'customer_id': 'legacy-customer',
    });
    const storage = FlutterSecureStorage();
    final store = AuthTokenStore(storageScope: 'Partner.Example.com:443');

    await store.restore();

    expect(store.accessToken, 'legacy-access');
    expect(store.refreshToken, 'legacy-refresh');
    expect(store.customerId, 'legacy-customer');
    expect(
      await storage.read(
        key: 'customer_access_token_partner.example.com',
      ),
      'legacy-access',
    );
    expect(
      await storage.read(
        key: 'customer_refresh_token_partner.example.com',
      ),
      'legacy-refresh',
    );
    expect(await storage.read(key: 'customer_access_token'), isNull);
    expect(await storage.read(key: 'customer_refresh_token'), isNull);
  });

  test('keeps customer sessions isolated by tenant host', () async {
    final first = AuthTokenStore(storageScope: 'first.example.com');
    await first.save(
      accessToken: 'first-access',
      refreshToken: 'first-refresh',
      customerId: 'first-customer',
    );
    final second = AuthTokenStore(storageScope: 'second.example.com');
    await second.save(
      accessToken: 'second-access',
      refreshToken: 'second-refresh',
      customerId: 'second-customer',
    );

    final restoredFirst = AuthTokenStore(storageScope: 'first.example.com');
    final restoredSecond = AuthTokenStore(storageScope: 'second.example.com');
    await restoredFirst.restore();
    await restoredSecond.restore();

    expect(restoredFirst.accessToken, 'first-access');
    expect(restoredFirst.refreshToken, 'first-refresh');
    expect(restoredFirst.customerId, 'first-customer');
    expect(restoredSecond.accessToken, 'second-access');
    expect(restoredSecond.refreshToken, 'second-refresh');
    expect(restoredSecond.customerId, 'second-customer');

    await restoredFirst.clear();
    final firstAfterLogout = AuthTokenStore(
      storageScope: 'first.example.com',
    );
    final secondAfterFirstLogout = AuthTokenStore(
      storageScope: 'second.example.com',
    );
    await firstAfterLogout.restore();
    await secondAfterFirstLogout.restore();

    expect(firstAfterLogout.hasSessionCredential, isFalse);
    expect(secondAfterFirstLogout.accessToken, 'second-access');
    expect(secondAfterFirstLogout.refreshToken, 'second-refresh');
  });
}
