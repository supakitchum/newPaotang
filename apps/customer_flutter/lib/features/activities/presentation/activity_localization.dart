import '../../../core/i18n/customer_localizations.dart';
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
      : activity.cashbackProgress.minTicketCount;
  if (ticketThreshold > 0) {
    return l10n.activityConditionMinTickets(ticketThreshold);
  }

  if (activity.cashbackProgress.minPurchaseAmount > 0) {
    return l10n.activityConditionMinBaht(
      formatBaht(activity.cashbackProgress.minPurchaseAmount),
    );
  }

  return l10n.activityConditionFallback;
}

String activityMetaText(CustomerLocalizations l10n, ActivityItem activity) {
  if (activity.isCashback) {
    return activity.estimatedCashbackAmount > 0
        ? l10n.activityMetaCashbackEstimate(
            formatBaht(activity.estimatedCashbackAmount),
          )
        : l10n.activityMetaCashbackPending;
  }

  if (activity.rights.entryClosed) return l10n.activityMetaEntryClosed;
  if (activity.rights.remainingCount > 0) {
    return l10n.activityMetaRights(activity.rights.remainingCount);
  }

  return l10n.activityMetaRemainingNumbers(activity.remainingNumbers);
}

String activityAwardTitle(
  CustomerLocalizations l10n,
  ActivityAwardItem award,
) {
  if (award.isCashback) return l10n.activityClaimRewardCashback;
  return l10n.activityPredictionLabel(award.predictionType);
}
