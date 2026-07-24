import 'package:customer_flutter/core/utils/provider_cache.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
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
