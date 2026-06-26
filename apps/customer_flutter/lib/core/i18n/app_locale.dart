import 'package:flutter/widgets.dart';

const supportedCustomerLocales = <Locale>[
  Locale('th', 'TH'),
  Locale('en', 'US'),
];

const fallbackCustomerLocale = Locale('th', 'TH');

Locale parseCustomerLocale(String? value, {Locale? fallback}) {
  final normalized = _normalizeLocaleTag(value);
  if (normalized == null) {
    return fallback ?? fallbackCustomerLocale;
  }

  return switch (normalized) {
    'th-TH' => const Locale('th', 'TH'),
    'en-US' => const Locale('en', 'US'),
    _ => fallback ?? fallbackCustomerLocale,
  };
}

String localeTag(Locale locale) {
  final countryCode = locale.countryCode;
  if (countryCode == null || countryCode.isEmpty) {
    return locale.languageCode;
  }

  return '${locale.languageCode}-$countryCode';
}

Locale resolveCustomerLocale(
  Locale? deviceLocale,
  Iterable<Locale> supportedLocales,
) {
  if (deviceLocale == null) {
    return fallbackCustomerLocale;
  }

  for (final locale in supportedLocales) {
    if (locale.languageCode == deviceLocale.languageCode &&
        locale.countryCode == deviceLocale.countryCode) {
      return locale;
    }
  }

  for (final locale in supportedLocales) {
    if (locale.languageCode == deviceLocale.languageCode) {
      return locale;
    }
  }

  return fallbackCustomerLocale;
}

String? _normalizeLocaleTag(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final parts = trimmed.replaceAll('_', '-').split('-');
  final language = parts.first.toLowerCase();
  final region = parts.length > 1 ? parts[1].toUpperCase() : null;

  return switch (language) {
    'th' => 'th-TH',
    'en' => 'en-US',
    _ => region == null ? language : '$language-$region',
  };
}
