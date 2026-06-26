import 'package:intl/intl.dart';

final _thaiMoney = NumberFormat.currency(
  locale: 'th_TH',
  symbol: '',
  decimalDigits: 2,
);

double moneyToDisplayNumber(Object? value, {double fallback = 0}) {
  if (value is num) {
    return value.isFinite ? value.toDouble() : fallback;
  }

  if (value is String) {
    final parsed = double.tryParse(value);
    return parsed ?? fallback;
  }

  if (value is Map && value.containsKey('amount')) {
    final amount = moneyToDisplayNumber(value['amount'], fallback: fallback);
    return amount / 100;
  }

  return fallback;
}

String formatBaht(num value) {
  final localeTag = _currentMoneyLocaleTag();
  return formatBahtForLocale(
    value,
    localeTag: localeTag,
    unit: _bahtUnitForLocale(localeTag),
  );
}

String formatBahtForLocale(
  num value, {
  required String localeTag,
  required String unit,
}) {
  final formatter = localeTag == 'th-TH'
      ? _thaiMoney
      : NumberFormat.currency(
          locale: _intlLocale(localeTag),
          symbol: '',
          decimalDigits: 2,
        );
  final amount = formatter.format(value).trim();
  final suffix = unit.trim();
  return suffix.isEmpty ? amount : '$amount $suffix';
}

String formatSignedBaht(num value) {
  final sign = value > 0
      ? '+'
      : value < 0
          ? '-'
          : '';
  return '$sign${formatBaht(value.abs())}';
}

String formatSignedBahtForLocale(
  num value, {
  required String localeTag,
  required String unit,
}) {
  final sign = value > 0
      ? '+'
      : value < 0
          ? '-'
          : '';
  return '$sign${formatBahtForLocale(
    value.abs(),
    localeTag: localeTag,
    unit: unit,
  )}';
}

DateTime? parseDateTime(Object? value) {
  if (value == null) return null;
  if (value is num) {
    final milliseconds = value < 1000000000000 ? value * 1000 : value;
    return DateTime.fromMillisecondsSinceEpoch(milliseconds.toInt()).toLocal();
  }
  final parsed = DateTime.tryParse(value.toString());
  return parsed?.toLocal();
}

String formatLocalizedDateTime(Object? value, String localeTag) {
  final date = parseDateTime(value);
  if (date == null) return '-';
  return DateFormat('d MMM y HH:mm', _intlLocale(localeTag)).format(date);
}

String formatLocalizedShortDate(DateTime date, String localeTag) {
  return DateFormat('d MMM y', _intlLocale(localeTag)).format(date);
}

String formatLocalizedYear(DateTime date, String localeTag) {
  return DateFormat('y', _intlLocale(localeTag)).format(date);
}

String _intlLocale(String localeTag) => localeTag.replaceAll('-', '_');

String _currentMoneyLocaleTag() {
  final locale = Intl.defaultLocale?.trim();
  if (locale == null || locale.isEmpty) return 'th-TH';
  final normalized = locale.replaceAll('_', '-');
  return normalized.toLowerCase().startsWith('en') ? 'en-US' : 'th-TH';
}

String _bahtUnitForLocale(String localeTag) {
  return localeTag.toLowerCase().startsWith('en') ? 'THB' : 'บาท';
}
