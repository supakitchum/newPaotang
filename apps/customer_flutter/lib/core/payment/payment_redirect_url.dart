String firstPaymentRedirectUrl(Iterable<Object?> values) {
  for (final value in values) {
    final url = _paymentRedirectUrlFrom(value);
    if (url.isNotEmpty) return url;
  }
  return '';
}

String _paymentRedirectUrlFrom(Object? value, [int depth = 0]) {
  if (value == null || depth > 5) return '';

  final direct = _directPaymentRedirectText(value);
  if (direct.isNotEmpty) return direct;

  if (value is Iterable) {
    for (final item in value) {
      if (!_looksLikePaymentRedirectLink(item)) continue;
      final url = _paymentRedirectUrlFrom(item, depth + 1);
      if (url.isNotEmpty) return url;
    }
    for (final item in value) {
      if (_looksLikePaymentRedirectLink(item)) continue;
      final url = _directPaymentRedirectText(item);
      if (url.isNotEmpty) return url;
    }
    return '';
  }

  if (value is! Map) return '';

  for (final key in _paymentRedirectUrlKeys) {
    if (!value.containsKey(key)) continue;
    final url = _paymentRedirectUrlFrom(value[key], depth + 1);
    if (url.isNotEmpty) return url;
  }

  for (final key in _paymentRedirectContainerKeys) {
    if (!value.containsKey(key)) continue;
    final url = _paymentRedirectUrlFrom(value[key], depth + 1);
    if (url.isNotEmpty) return url;
  }

  return '';
}

String _directPaymentRedirectText(Object? value) {
  if (value is Uri) return value.toString().trim();
  if (value is String) return value.trim();
  return '';
}

bool _looksLikePaymentRedirectLink(Object? value) {
  if (value is! Map) return false;
  for (final key in const ['rel', 'name', 'type', 'kind', 'action']) {
    final normalized = _normalizePaymentRedirectToken(value[key]);
    if (normalized.isEmpty) continue;
    if (_paymentRedirectLinkTokens.contains(normalized)) return true;
  }
  return false;
}

String _normalizePaymentRedirectToken(Object? value) {
  return value?.toString().trim().toLowerCase().replaceAll(
            RegExp(r'[^a-z0-9]+'),
            '_',
          ) ??
      '';
}

const _paymentRedirectUrlKeys = [
  'redirect_url',
  'redirectUrl',
  'redirect_uri',
  'redirectUri',
  'payment_url',
  'paymentUrl',
  'payment_uri',
  'paymentUri',
  'checkout_url',
  'checkoutUrl',
  'checkout_uri',
  'checkoutUri',
  'authorization_url',
  'authorizationUrl',
  'approval_url',
  'approvalUrl',
  'approve_url',
  'approveUrl',
  'payment_link',
  'paymentLink',
  'checkout_link',
  'checkoutLink',
  'web_url',
  'webUrl',
  'mobile_url',
  'mobileUrl',
  'deep_link',
  'deepLink',
  'url',
  'uri',
  'href',
  'link',
];

const _paymentRedirectContainerKeys = [
  'payment',
  'pay',
  'checkout',
  'authorization',
  'authorize',
  'approval',
  'approve',
  'paymentInfo',
  'payment_info',
  'paymentSession',
  'payment_session',
  'checkoutSession',
  'checkout_session',
  'session',
  'providerPayload',
  'provider_payload',
  'gateway',
  'gatewayResponse',
  'gateway_response',
  'redirect',
  'redirectTo',
  'redirect_to',
  'redirectToUrl',
  'redirect_to_url',
  'nextAction',
  'next_action',
  'action',
  'actions',
  'links',
  'data',
  'resource',
  'result',
];

const _paymentRedirectLinkTokens = {
  'pay',
  'payment',
  'checkout',
  'redirect',
  'authorization',
  'authorize',
  'approval',
  'approve',
  'external',
  'provider',
  'session',
};
