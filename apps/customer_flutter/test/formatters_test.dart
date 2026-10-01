import 'package:customer_flutter/core/utils/formatters.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

void main() {
  setUpAll(() async {
    await initializeDateFormatting('th_TH');
  });

  test('Thai localized dates use Buddhist Era years', () {
    final date = DateTime(2026, 7, 16, 7, 54, 16);

    expect(formatLocalizedYear(date, 'th-TH'), '2569');
    expect(formatLocalizedShortDate(date, 'th-TH'), contains('2569'));
    expect(formatLocalizedDateTime(date, 'th-TH'), contains('2569'));
  });

  test('Bangkok purchase timestamps preserve seconds and Buddhist year', () {
    final formatted = formatBangkokLocalizedDateTimeWithSeconds(
      '2026-07-16T00:54:16Z',
      'th-TH',
    );

    expect(formatted, contains('2569'));
    expect(formatted, endsWith('07:54:16'));
  });

  test('English localized dates keep Gregorian years', () {
    final date = DateTime(2026, 7, 16, 7, 54, 16);

    expect(formatLocalizedYear(date, 'en-US'), '2026');
    expect(formatLocalizedDateTime(date, 'en-US'), contains('2026'));
  });
}
