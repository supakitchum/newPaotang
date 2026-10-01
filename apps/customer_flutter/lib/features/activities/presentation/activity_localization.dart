import '../../../core/i18n/customer_localizations.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/utils/formatters.dart';
import '../data/activity_models.dart';

String activityDisplayName(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  final name = activity.name.trim();
  return name.isEmpty ? l10n.activityFallbackName : name;
}

String activityConditionText(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  final configured = activity.conditionText.trim();
  if (configured.isNotEmpty) return configured;

  final ticketThreshold = activity.config.thresholdTickets > 0
      ? activity.config.thresholdTickets
      : activity.cashbackProgress.minTicketCount > 0
          ? activity.cashbackProgress.minTicketCount
          : activity.config.minTicketCount;
  if (ticketThreshold > 0) {
    return l10n.activityConditionMinTickets(ticketThreshold);
  }

  final minPurchaseAmount = activity.cashbackProgress.minPurchaseAmount > 0
      ? activity.cashbackProgress.minPurchaseAmount
      : activity.config.minPurchaseAmount;
  if (minPurchaseAmount > 0) {
    return l10n.activityConditionMinBaht(
      formatBaht(minPurchaseAmount),
    );
  }

  return l10n.activityConditionFallback;
}

String activityMetaText(CustomerLocalizations l10n, ActivityItem activity) {
  if (activity.isCashback) {
    final estimate = activity.estimatedCashbackAmount > 0
        ? activity.estimatedCashbackAmount
        : activity.cashbackProgress.potentialAmount > 0
            ? activity.cashbackProgress.potentialAmount
            : activity.config.fixedAmount;
    return estimate > 0
        ? l10n.activityMetaCashbackEstimate(formatBaht(estimate))
        : l10n.activityMetaCashbackPending;
  }

  if (activityEntryClosed(activity)) return l10n.activityMetaEntryClosed;
  if (activity.rights.remainingCount > 0) {
    return l10n.activityMetaRights(activity.rights.remainingCount);
  }

  return l10n.activityMetaRemainingNumbers(activity.remainingNumbers);
}

String activityGameLabel(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  final label = activity.gameName.trim();
  return label.isEmpty ? l10n.activityDetailGameFallback : label;
}

String activityResultTimeText(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  final resultAt = parseDateTime(activity.resultAt);
  if (resultAt == null) return l10n.activityCashbackResultTimeFallback;

  final formatted = formatLocalizedDateTime(resultAt, localeTag(l10n.locale));
  return l10n.activityResultTimeValue(formatted);
}

bool activityEntryClosed(ActivityItem activity, {DateTime? now}) {
  if (!activity.isLuckyBoard) return false;
  if (activity.rights.entryClosed) return true;

  final deadline = parseDateTime(activity.rights.entryDeadlineAt);
  if (deadline == null) return false;
  final current = now ?? DateTime.now();
  return !current.isBefore(deadline);
}

String activityEntryDeadlineText(
  CustomerLocalizations l10n,
  ActivityItem activity,
) {
  if (activityEntryClosed(activity)) return l10n.activityDetailEntryClosed;

  final deadline = activity.rights.entryDeadlineAt;
  if (deadline == null) return l10n.activityMetaDeadlineFallback;

  return l10n.activityMetaDeadline(
    formatLocalizedDateTime(deadline, localeTag(l10n.locale)),
  );
}

String activityAwardTitle(
  CustomerLocalizations l10n,
  ActivityAwardItem award,
) {
  if (award.isCashback) return l10n.activityClaimRewardCashback;
  return l10n.activityPredictionLabel(award.predictionType);
}
