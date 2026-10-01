import 'package:flutter/widgets.dart';

class CustomerLocaleOption {
  const CustomerLocaleOption({
    required this.locale,
    required this.name,
    required this.nativeName,
    this.isDefault = false,
    this.sortOrder = 100,
  });

  final Locale locale;
  final String name;
  final String nativeName;
  final bool isDefault;
  final int sortOrder;

  String get tag => localeTag(locale);

  String get displayName {
    final native = nativeName.trim();
    if (native.isNotEmpty) return native;
    final fallback = name.trim();
    return fallback.isNotEmpty ? fallback : tag;
  }
}

const supportedCustomerLocales = <Locale>[
  Locale('th', 'TH'),
  Locale('en', 'US'),
];

const fallbackCustomerLocaleOptions = <CustomerLocaleOption>[
  CustomerLocaleOption(
    locale: Locale('th', 'TH'),
    name: 'Thai',
    nativeName: 'ไทย',
    isDefault: true,
    sortOrder: 10,
  ),
  CustomerLocaleOption(
    locale: Locale('en', 'US'),
    name: 'English',
    nativeName: 'English',
    sortOrder: 20,
  ),
];

const fallbackCustomerLocale = Locale('th', 'TH');

Locale parseCustomerLocale(String? value, {Locale? fallback}) {
  return tryParseCustomerLocale(value) ?? fallback ?? fallbackCustomerLocale;
}

Locale? tryParseCustomerLocale(String? value) {
  final normalized = _normalizeLocaleTag(value);
  if (normalized == null) return null;

  final parts = normalized.split('-');
  return Locale(parts.first, parts.length > 1 ? parts[1] : null);
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

List<CustomerLocaleOption> effectiveCustomerLocaleOptions(
  Iterable<CustomerLocaleOption> runtimeOptions,
) {
  final unique = <String, CustomerLocaleOption>{};
  for (final option in runtimeOptions) {
    final parsed = tryParseCustomerLocale(option.tag);
    if (parsed == null) continue;
    final normalized = CustomerLocaleOption(
      locale: parsed,
      name: option.name,
      nativeName: option.nativeName,
      isDefault: option.isDefault,
      sortOrder: option.sortOrder,
    );
    unique.putIfAbsent(normalized.tag, () => normalized);
  }

  if (unique.isEmpty) return fallbackCustomerLocaleOptions;
  final options = unique.values.toList();
  options.sort((left, right) {
    final order = left.sortOrder.compareTo(right.sortOrder);
    return order != 0 ? order : left.tag.compareTo(right.tag);
  });
  return List<CustomerLocaleOption>.unmodifiable(options);
}

List<Locale> customerAppSupportedLocales(
  Iterable<CustomerLocaleOption> options, {
  Locale? activeLocale,
}) {
  final locales = <String, Locale>{
    for (final option in effectiveCustomerLocaleOptions(options))
      option.tag: option.locale,
  };
  final active = tryParseCustomerLocale(
    activeLocale == null ? null : localeTag(activeLocale),
  );
  if (active != null) {
    locales.putIfAbsent(localeTag(active), () => active);
  }
  return List<Locale>.unmodifiable(locales.values);
}

String? _normalizeLocaleTag(String? value) {
  final trimmed = value?.trim();
  if (trimmed == null || trimmed.isEmpty) {
    return null;
  }

  final normalized = trimmed.replaceAll('_', '-').toLowerCase();
  if (normalized == 'th' || normalized == 'th-th') return 'th-TH';
  if (normalized == 'en' || normalized == 'en-us' || normalized == 'en-gb') {
    return 'en-US';
  }
  if (!RegExp(r'^[a-z]{2}(?:-[a-z]{2})?$').hasMatch(normalized)) {
    return null;
  }

  final parts = normalized.split('-');
  return parts.length == 1
      ? parts.first
      : '${parts.first}-${parts[1].toUpperCase()}';
}
