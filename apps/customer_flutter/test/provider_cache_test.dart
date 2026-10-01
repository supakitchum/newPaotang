import 'package:customer_flutter/core/utils/provider_cache.dart';
import 'package:customer_flutter/core/auth/auth_controller.dart';
import 'package:customer_flutter/core/auth/auth_repository.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_locale_controller.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('private cache reloads after session and language changes', () async {
    var loads = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      ref.keepForCustomerSession();
      return ++loads;
    });
    final container = ProviderContainer(
      overrides: [
        appConfigProvider.overrideWithValue(
          const AppConfig(
            apiBaseUrl: 'https://siamblend.com/api/v1',
            defaultLocale: 'th-TH',
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    final subscription = container.listen(provider, (_, __) {});
    addTearDown(subscription.close);
    expect(await container.read(provider.future), 1);
    final controller = container.read(authControllerProvider);
    controller.applySession(
      const CustomerSession(
        accessToken: 'first-customer',
        refreshToken: '',
        pinRequired: false,
        pinSetupRequired: false,
        customerId: 'customer-1',
      ),
    );
    expect(await container.read(provider.future), 2);
    controller.applySession(
      const CustomerSession(
        accessToken: 'second-customer',
        refreshToken: '',
        pinRequired: false,
        pinSetupRequired: false,
        customerId: 'customer-2',
      ),
    );
    expect(await container.read(provider.future), 3);
    container.read(customerLocaleProvider.notifier).state = const Locale(
      'en',
      'US',
    );
    expect(await container.read(provider.future), 4);
  });
  test('inactive cache releases data without reopening the provider', () async {
    var disposals = 0;
    final provider = FutureProvider.autoDispose<int>((ref) async {
      ref.keepForCustomerNavigation(duration: const Duration(milliseconds: 20));
      ref.onDispose(() => disposals++);
      return 1;
    });
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final subscription = container.listen(provider, (_, __) {});
    await container.read(provider.future);
    subscription.close();
    await Future<void>.delayed(const Duration(milliseconds: 50));
    expect(disposals, 1);
  });
  test(
    'navigation cache reuses data then expires after its idle window',
    () async {
      var loads = 0;
      final provider = FutureProvider.autoDispose<int>((ref) async {
        ref.keepForCustomerNavigation(
          duration: const Duration(milliseconds: 40),
        );
        return ++loads;
      });
      final container = ProviderContainer();
      addTearDown(container.dispose);

      var subscription = container.listen(provider, (_, __) {});
      expect(await container.read(provider.future), 1);
      subscription.close();
      await Future<void>.delayed(const Duration(milliseconds: 10));

      subscription = container.listen(provider, (_, __) {});
      expect(await container.read(provider.future), 1);
      expect(loads, 1);
      subscription.close();

      await Future<void>.delayed(const Duration(milliseconds: 60));
      subscription = container.listen(provider, (_, __) {});
      expect(await container.read(provider.future), 2);
      expect(loads, 2);
      subscription.close();
    },
  );
}
