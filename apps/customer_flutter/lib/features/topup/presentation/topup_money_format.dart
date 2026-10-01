import '../../../core/i18n/customer_localizations.dart';

String formatTopupBaht(CustomerLocalizations l10n, num value) {
  final amount = formatTopupAmount(l10n, value);
  final unit = l10n.topupBahtSuffix.trim();
  return unit.isEmpty ? amount : '$amount $unit';
}

String formatTopupAmount(CustomerLocalizations l10n, num value) {
  final formatted = l10n.formatBaht(value);
  final unit = l10n.topupBahtSuffix.trim();
  final amount = unit.isEmpty
      ? formatted.trim()
      : formatted
          .replaceFirst(RegExp('\\s*${RegExp.escape(unit)}\$'), '')
          .trim();
  final numericValue = value.toDouble();
  return numericValue.isFinite &&
          (numericValue - numericValue.roundToDouble()).abs() <= 0.000001
      ? amount.replaceFirst(RegExp(r'[\.,]00$'), '')
      : amount;
}
