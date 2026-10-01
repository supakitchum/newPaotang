import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/payment/checkout_payment_config.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';

final checkoutPaymentMethodProvider = Provider<String>((ref) {
  return ref.watch(mobileBootstrapProvider).maybeWhen(
        data: (bootstrap) => bootstrap.payment.checkoutPaymentMethod,
        orElse: () => checkoutPaymentMethodWallet,
      );
});

final checkoutPaymentMethodsProvider = Provider<List<String>>((ref) {
  return ref.watch(mobileBootstrapProvider).maybeWhen(
        data: (bootstrap) => bootstrap.payment.checkoutPaymentMethods,
        orElse: () => const [checkoutPaymentMethodWallet],
      );
});

final checkoutPaymentMethodLabelsProvider =
    Provider<Map<String, String>>((ref) {
  return ref.watch(mobileBootstrapProvider).maybeWhen(
        data: (bootstrap) => bootstrap.payment.checkoutPaymentMethodLabels,
        orElse: () => const {},
      );
});
