import 'package:flutter/widgets.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../data/purchase_history_models.dart';

String localizedPurchaseYear(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  final date =
      parseDateTime(order.drawAt) ?? parseDateTime(order.transactionAt);
  final year = date == null
      ? '-'
      : formatLocalizedYear(date, localeTag(context.l10n.locale));
  return context.l10n.purchaseHistoryYear(year);
}

String localizedPurchaseDrawDate(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  final date = parseDateTime(order.drawAt);
  if (date != null) {
    return formatLocalizedShortDate(date, localeTag(context.l10n.locale));
  }
  return normalizeDrawName(order.gameName);
}

String localizedPurchaseTransactionDate(
  BuildContext context,
  PurchaseHistoryOrder order,
) {
  return formatLocalizedDateTime(
    order.transactionAt,
    localeTag(context.l10n.locale),
  );
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

String localizedPurchasePaymentChannel(PurchaseHistoryOrder order) {
  if (order.paymentMethod == 'wallet') return order.walletName;
  if (order.paymentProvider.isNotEmpty) return order.paymentProvider;
  return order.walletName;
}
