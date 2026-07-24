import 'package:flutter_riverpod/flutter_riverpod.dart';

const customerNavigationCacheDuration = Duration(minutes: 3);

extension CustomerProviderCache<State> on Ref<State> {
  void keepForCustomerNavigation({
    Duration duration = customerNavigationCacheDuration,
  }) {
    final link = keepAlive();
    DateTime? inactiveSince;
    onCancel(() => inactiveSince = DateTime.now());
    onResume(() {
      final idleSince = inactiveSince;
      inactiveSince = null;
      if (idleSince == null ||
          DateTime.now().difference(idleSince) < duration) {
        return;
      }
      link.close();
      invalidateSelf();
    });
  }
}
