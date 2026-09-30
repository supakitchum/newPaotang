import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_controller.dart';
import '../i18n/customer_locale_controller.dart';

const customerNavigationCacheDuration = Duration(minutes: 3);

extension CustomerProviderCache<State> on Ref<State> {
  void keepForCustomerSession({
    Duration duration = customerNavigationCacheDuration,
  }) {
    keepForCustomerNavigation(duration: duration);
    watch(authControllerProvider);
    watch(customerLocaleProvider);
  }

  void keepForCustomerNavigation({
    Duration duration = customerNavigationCacheDuration,
  }) {
    final link = keepAlive();
    Timer? expiryTimer;
    onCancel(() {
      expiryTimer?.cancel();
      expiryTimer = Timer(duration, link.close);
    });
    onResume(() {
      expiryTimer?.cancel();
    });
    onDispose(() => expiryTimer?.cancel());
  }
}
