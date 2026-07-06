const checkoutPaymentMethodWallet = 'wallet';
const checkoutPaymentMethodExternalPayment = 'external_payment';

const supportedCheckoutPaymentMethods = <String>{
  checkoutPaymentMethodWallet,
  checkoutPaymentMethodExternalPayment,
};

String normalizeCheckoutPaymentMethod(Object? value) {
  final method = _canonicalCheckoutPaymentMethod(
    _checkoutPaymentMethodKey(value),
  );
  if (method == null || method.isEmpty) return checkoutPaymentMethodWallet;
  return supportedCheckoutPaymentMethods.contains(method)
      ? method
      : checkoutPaymentMethodWallet;
}

List<String> normalizeCheckoutPaymentMethods(Object? value) {
  final methods = _checkoutPaymentMethodRows(value)
      .where(_checkoutPaymentMethodEnabled)
      .map(
        (method) => _canonicalCheckoutPaymentMethod(
          _checkoutPaymentMethodKey(method),
        ),
      )
      .whereType<String>()
      .where(supportedCheckoutPaymentMethods.contains)
      .toSet()
      .toList(growable: false);
  return methods.isEmpty ? const [checkoutPaymentMethodWallet] : methods;
}

Iterable<Object?> _checkoutPaymentMethodRows(Object? value) sync* {
  if (value == null) return;
  if (value is String || value is num || value is bool) {
    yield value;
    return;
  }
  if (value is Iterable) {
    for (final item in value) {
      yield* _checkoutPaymentMethodRows(item);
    }
    return;
  }
  if (value is Map) {
    final directKey = _checkoutPaymentMethodKey(value);
    if (directKey != null && directKey.isNotEmpty) {
      yield value;
      return;
    }

    for (final nestedKey in const [
      'methods',
      'items',
      'checkout_payment_methods',
      'checkoutPaymentMethods',
      'checkout_methods',
      'checkoutMethods',
      'enabled_checkout_payment_methods',
      'enabledCheckoutPaymentMethods',
      'payment_methods',
      'paymentMethods',
      'enabled_payment_methods',
      'enabledPaymentMethods',
      'enabled_methods',
      'enabledMethods',
    ]) {
      yield* _checkoutPaymentMethodRows(value[nestedKey]);
    }

    for (final entry in value.entries) {
      final key = entry.key.toString().trim();
      if (key.isEmpty ||
          const {
            'methods',
            'items',
            'checkout_payment_methods',
            'checkoutPaymentMethods',
            'checkout_methods',
            'checkoutMethods',
            'enabled_checkout_payment_methods',
            'enabledCheckoutPaymentMethods',
            'payment_methods',
            'paymentMethods',
            'enabled_payment_methods',
            'enabledPaymentMethods',
            'enabled_methods',
            'enabledMethods',
          }.contains(key)) {
        continue;
      }

      final raw = entry.value;
      if (raw is Map) {
        yield {
          ...Map<String, dynamic>.from(raw),
          if (!_hasCheckoutPaymentMethodKey(raw)) 'key': key,
        };
      } else {
        yield {'key': key, 'enabled': raw};
      }
    }
  }
}

String? _checkoutPaymentMethodKey(Object? value) {
  if (value is Map) {
    for (final key in const [
      'key',
      'method',
      'payment_method',
      'paymentMethod',
      'code',
      'provider',
      'slug',
      'name',
    ]) {
      final raw = value[key]?.toString().trim();
      if (raw != null && raw.isNotEmpty) return raw;
    }
    return null;
  }

  return value?.toString().trim();
}

bool _hasCheckoutPaymentMethodKey(Map value) {
  return const [
    'key',
    'method',
    'payment_method',
    'paymentMethod',
    'code',
    'provider',
    'slug',
    'name',
  ].any((key) => value.containsKey(key));
}

String? _canonicalCheckoutPaymentMethod(String? value) {
  final normalized = value?.trim();
  if (normalized == null || normalized.isEmpty) return null;
  final key = normalized
      .replaceAll(RegExp(r'[\s-]+'), '_')
      .replaceAllMapped(RegExp(r'([a-z0-9])([A-Z])'), (match) {
    return '${match.group(1)}_${match.group(2)}';
  }).toLowerCase();
  return switch (key) {
    'g_wallet' || 'gwallet' || 'wallet_balance' => checkoutPaymentMethodWallet,
    'external' ||
    'external_payment_provider' ||
    'external_provider' ||
    'payment_gateway' ||
    'gateway' =>
      checkoutPaymentMethodExternalPayment,
    _ => key,
  };
}

bool _checkoutPaymentMethodEnabled(Object? value) {
  if (value is! Map) return true;
  if (_checkoutPaymentMethodDisabled(value)) return false;
  return _checkoutPaymentMethodActive(value);
}

bool _checkoutPaymentMethodDisabled(Map value) {
  return _checkoutBool(
    value['disabled'] ??
        value['is_disabled'] ??
        value['isDisabled'] ??
        value['hidden'] ??
        value['is_hidden'] ??
        value['isHidden'] ??
        value['unsupported'] ??
        value['is_unsupported'] ??
        value['isUnsupported'],
    fallback: false,
  );
}

bool _checkoutPaymentMethodActive(Map value) {
  final supported = value['supported'] ??
      value['is_supported'] ??
      value['isSupported'] ??
      value['allowed'] ??
      value['is_allowed'] ??
      value['isAllowed'] ??
      value['visible'] ??
      value['is_visible'] ??
      value['isVisible'];
  if (supported != null && !_checkoutBool(supported, fallback: true)) {
    return false;
  }

  return _checkoutBool(
    value['enabled'] ??
        value['is_enabled'] ??
        value['isEnabled'] ??
        value['active'] ??
        value['is_active'] ??
        value['isActive'] ??
        value['available'] ??
        value['is_available'] ??
        value['isAvailable'] ??
        value['ready'] ??
        value['configured'] ??
        value['is_configured'] ??
        value['isConfigured'] ??
        value['status'],
    fallback: true,
  );
}

bool _checkoutBool(Object? value, {required bool fallback}) {
  if (value == null) return fallback;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  if (normalized.isEmpty) return fallback;
  if (const {
    '1',
    'true',
    'yes',
    'y',
    'on',
    'enabled',
    'enable',
    'active',
    'available',
    'ready',
    'configured',
    'supported',
    'allowed',
    'visible',
  }.contains(normalized)) {
    return true;
  }
  if (const {
    '0',
    'false',
    'no',
    'n',
    'off',
    'disabled',
    'disable',
    'inactive',
    'unavailable',
    'hidden',
    'maintenance',
    'blocked',
    'unsupported',
    'not_supported',
    'not-supported',
    'denied',
    'not_allowed',
    'not-allowed',
  }.contains(normalized)) {
    return false;
  }
  return fallback;
}
