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
  return _formatLocalizedDateTimeValue(date, localeTag);
}

String formatBangkokLocalizedDateTime(Object? value, String localeTag) {
  final date = _bangkokDateTime(value);
  if (date == null) return '-';
  return _formatLocalizedDateTimeValue(date, localeTag);
}

String formatBangkokLocalizedDateTimeWithSeconds(
  Object? value,
  String localeTag,
) {
  final date = _bangkokDateTime(value);
  if (date == null) return '-';
  return _formatLocalizedDateTimeValue(
    date,
    localeTag,
    includeSeconds: true,
  );
}

String formatBangkokLocalizedShortDate(Object? value, String localeTag) {
  final date = _bangkokDateTime(value);
  if (date == null) return '-';
  return formatLocalizedShortDate(date, localeTag);
}

String formatBangkokLocalizedYear(Object? value, String localeTag) {
  final date = _bangkokDateTime(value);
  if (date == null) return '-';
  return formatLocalizedYear(date, localeTag);
}

String formatLotteryDrawDateText({
  required Object? name,
  required Object? drawAt,
  required String localeTag,
}) {
  final nameText = _formatDrawDateName(name);
  if (nameText != null) return nameText;

  final date = parseDateTime(drawAt);
  if (date == null) return '-';
  return formatLocalizedShortDate(date, localeTag);
}

String formatLocalizedShortDate(DateTime date, String localeTag) {
  if (_isThaiLocale(localeTag)) {
    final dayMonth = DateFormat('d MMM', _intlLocale(localeTag)).format(date);
    return '$dayMonth ${date.year + 543}';
  }
  return DateFormat('d MMM y', _intlLocale(localeTag)).format(date);
}

String formatLocalizedYear(DateTime date, String localeTag) {
  if (_isThaiLocale(localeTag)) return '${date.year + 543}';
  return DateFormat('y', _intlLocale(localeTag)).format(date);
}

String _intlLocale(String localeTag) => localeTag.replaceAll('-', '_');

bool _isThaiLocale(String localeTag) =>
    localeTag.trim().toLowerCase().startsWith('th');

DateTime? _bangkokDateTime(Object? value) {
  final date = parseDateTime(value);
  return date?.toUtc().add(const Duration(hours: 7));
}

String _formatLocalizedDateTimeValue(
  DateTime date,
  String localeTag, {
  bool includeSeconds = false,
}) {
  if (!_isThaiLocale(localeTag)) {
    final pattern = includeSeconds ? 'd MMM y HH:mm:ss' : 'd MMM y HH:mm';
    return DateFormat(pattern, _intlLocale(localeTag)).format(date);
  }
  final shortDate = formatLocalizedShortDate(date, localeTag);
  final timePattern = includeSeconds ? 'HH:mm:ss' : 'HH:mm';
  final time = DateFormat(timePattern, _intlLocale(localeTag)).format(date);
  return '$shortDate $time';
}

String _currentMoneyLocaleTag() {
  final locale = Intl.defaultLocale?.trim();
  if (locale == null || locale.isEmpty) return 'th-TH';
  final normalized = locale.replaceAll('_', '-');
  return normalized.toLowerCase().startsWith('en') ? 'en-US' : 'th-TH';
}

String _bahtUnitForLocale(String localeTag) {
  return localeTag.toLowerCase().startsWith('en') ? 'THB' : 'บาท';
}

String? _formatDrawDateName(Object? value) {
  if (value is! String) return null;

  var normalized = value.trim().replaceAll(RegExp(r'\s+'), ' ');
  if (normalized.isEmpty) return null;

  final parsed = DateTime.tryParse(normalized);
  if (parsed != null) {
    return formatLocalizedShortDate(parsed.toLocal(), 'th-TH');
  }

  normalized = normalized.replaceFirst(RegExp(r'^งวด(?:วันที่)?\s*'), '');
  for (final entry in _thaiFullMonthNames.entries) {
    normalized = normalized.replaceAll(entry.key, entry.value);
  }
  return normalized;
}

const _thaiFullMonthNames = {
  'มกราคม': 'ม.ค.',
  'กุมภาพันธ์': 'ก.พ.',
  'มีนาคม': 'มี.ค.',
  'เมษายน': 'เม.ย.',
  'พฤษภาคม': 'พ.ค.',
  'มิถุนายน': 'มิ.ย.',
  'กรกฎาคม': 'ก.ค.',
  'สิงหาคม': 'ส.ค.',
  'กันยายน': 'ก.ย.',
  'ตุลาคม': 'ต.ค.',
  'พฤศจิกายน': 'พ.ย.',
  'ธันวาคม': 'ธ.ค.',
};
