const checkoutPaymentMethodWallet = 'wallet';
const checkoutPaymentMethodExternalPayment = 'external_payment';

const supportedCheckoutPaymentMethods = <String>{
  checkoutPaymentMethodWallet,
  checkoutPaymentMethodExternalPayment,
};

String normalizeCheckoutPaymentMethod(Object? value) {
  final method = value?.toString().trim();
  if (method == null || method.isEmpty) return checkoutPaymentMethodWallet;
  return supportedCheckoutPaymentMethods.contains(method)
      ? method
      : checkoutPaymentMethodWallet;
}

List<String> normalizeCheckoutPaymentMethods(Object? value) {
  final rawMethods = value is Iterable
      ? value
      : value == null
          ? const <Object?>[]
          : <Object?>[value];
  final methods = rawMethods
      .map((method) => method?.toString().trim() ?? '')
      .where(supportedCheckoutPaymentMethods.contains)
      .toSet()
      .toList(growable: false);
  return methods.isEmpty ? const [checkoutPaymentMethodWallet] : methods;
}
