import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../config/app_config.dart';
import 'app_locale.dart';

final customerLocaleProvider = StateProvider<Locale>((ref) {
  final config = ref.watch(appConfigProvider);
  return parseCustomerLocale(config.defaultLocale);
});

final customerLocaleOverriddenProvider = StateProvider<bool>((_) => false);

void syncCustomerLocaleFromBootstrap(WidgetRef ref, Locale locale) {
  if (ref.read(customerLocaleOverriddenProvider)) return;
  final current = ref.read(customerLocaleProvider);
  if (localeTag(current) == localeTag(locale)) return;
  ref.read(customerLocaleProvider.notifier).state = locale;
}

void setCustomerLocale(WidgetRef ref, Locale locale) {
  ref.read(customerLocaleOverriddenProvider.notifier).state = true;
  ref.read(customerLocaleProvider.notifier).state = locale;
}
