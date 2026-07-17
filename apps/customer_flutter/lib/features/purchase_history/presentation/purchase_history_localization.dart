import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/purchase_history_models.dart';

String localizedPurchaseYear(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  final drawAt = order.drawAt?.toString().trim() ?? '';
  final value = drawAt.isNotEmpty ? order.drawAt : order.transactionAt;
  final year = formatBangkokLocalizedYear(
    value,
    localeTag(context.l10n.locale),
  );
  return context.l10n.purchaseHistoryYear(year);
}

String localizedPurchaseDrawDate(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  if (parseDateTime(order.drawAt) != null) {
    return formatBangkokLocalizedShortDate(
      order.drawAt,
      localeTag(context.l10n.locale),
    );
  }
  return normalizeDrawName(order.gameName);
}

String localizedPurchaseTransactionDate(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  return formatBangkokLocalizedDateTimeWithSeconds(
    order.transactionAt,
    localeTag(context.l10n.locale),
  );
}

String localizedPurchaseMoneyAmount(BuildContext context, num value) {
  final locale = localeTag(context.l10n.locale).replaceAll('-', '_');
  final formatter = NumberFormat.decimalPattern(locale)
    ..minimumFractionDigits = value % 1 == 0 ? 0 : 2
    ..maximumFractionDigits = 2;
  return formatter.format(value);
}

String localizedPurchaseStoreName(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  final storeName = order.storeName.trim();
  return storeName.isEmpty
      ? context.l10n.purchaseHistoryStoreFallback
      : storeName;
}

String localizedPurchasePaymentChannel(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  if (order.paymentMethod == 'wallet') {
    return order.walletName.isEmpty
        ? context.l10n.purchaseHistoryWalletFallback
        : order.walletName;
  }
  if (order.paymentProvider.isNotEmpty) return order.paymentProvider;
  return order.walletName.isEmpty
      ? context.l10n.purchaseHistoryWalletFallback
      : order.walletName;
}
