import '../../../core/utils/formatters.dart';

class ActivityItem {
  const ActivityItem({
    required this.id,
    required this.name,
    required this.slug,
    required this.type,
    required this.imageUrl,
    required this.conditionText,
    required this.remainingNumbers,
    required this.hasRight,
    required this.estimatedCashbackAmount,
    this.rights = ActivityRights.empty,
    this.entries = const [],
    this.numberBoard = ActivityNumberBoard.empty,
    this.config = ActivityConfig.empty,
    this.cashbackProgress = ActivityCashbackProgress.empty,
    this.resultSummary,
  });

  factory ActivityItem.fromJson(
    Map<String, dynamic> json, {
    String Function(String value) resolveAssetUrl = _identity,
  }) {
    final type = json['type']?.toString() ?? '';
    final board = ActivityNumberBoard.fromJson(json['number_board']);
    final rights = ActivityRights.fromJson(json['rights']);
    final progress = ActivityCashbackProgress.fromJson(
      json['cashback_progress'],
    );
    final config = ActivityConfig.fromJson(json['config']);
    final imageUrl = (json['image_thumb'] ??
                json['image_thumb_url'] ??
                json['cover'] ??
                json['cover_url'] ??
                json['image'] ??
                json['image_full_url'])
            ?.toString() ??
        '';

    return ActivityItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      slug: json['slug']?.toString() ?? '',
      type: type,
      imageUrl: resolveAssetUrl(imageUrl),
      conditionText: _conditionText(json),
      remainingNumbers: board.remainingCount,
      hasRight: rights.remainingCount > 0 ||
          rights.earnedCount > 0 ||
          progress.isEligible ||
          json['award'] is Map,
      estimatedCashbackAmount: progress.estimatedAmount,
      rights: rights,
      entries: asActivityEntries(json['entries']),
      numberBoard: board,
      config: config,
      cashbackProgress: progress,
      resultSummary: ActivityResultSummary.tryFromJson(
        json['result_summary'],
      ),
    );
  }

  final String id;
  final String name;
  final String slug;
  final String type;
  final String imageUrl;
  final String conditionText;
  final int remainingNumbers;
  final bool hasRight;
  final double estimatedCashbackAmount;
  final ActivityRights rights;
  final List<ActivityEntry> entries;
  final ActivityNumberBoard numberBoard;
  final ActivityConfig config;
  final ActivityCashbackProgress cashbackProgress;
  final ActivityResultSummary? resultSummary;

  bool get isCashback => type == 'cashback';
  bool get isLuckyBoard => type == 'lucky_board';

  static String _conditionText(Map<String, dynamic> json) {
    final description = (json['description'] ?? json['summary'])?.toString();
    if (description != null && description.trim().isNotEmpty) {
      return description.trim();
    }
    return '';
  }
}

class ActivityRights {
  const ActivityRights({
    required this.earnedCount,
    required this.usedCount,
    required this.remainingCount,
    required this.ticketCount,
    required this.availableTicketCount,
    required this.consumedTicketCount,
    required this.qualifyingOrderCount,
    required this.eligibilityRule,
    required this.thresholdTickets,
    required this.entryDeadlineAt,
    required this.entryClosed,
  });

  factory ActivityRights.fromJson(Object? value) {
    final json = _asMap(value);
    return ActivityRights(
      earnedCount: _intValue(json['earned_count'] ?? json['earned']),
      usedCount: _intValue(json['used_count'] ?? json['used']),
      remainingCount: _intValue(json['remaining_count'] ?? json['remaining']),
      ticketCount: _intValue(json['ticket_count']),
      availableTicketCount: _intValue(json['available_ticket_count']),
      consumedTicketCount: _intValue(json['consumed_ticket_count']),
      qualifyingOrderCount: _intValue(json['qualifying_order_count']),
      eligibilityRule: json['eligibility_rule']?.toString() ?? '',
      thresholdTickets: _intValue(json['threshold_tickets']),
      entryDeadlineAt: json['entry_deadline_at'],
      entryClosed: json['entry_closed'] == true,
    );
  }

  static const empty = ActivityRights(
    earnedCount: 0,
    usedCount: 0,
    remainingCount: 0,
    ticketCount: 0,
    availableTicketCount: 0,
    consumedTicketCount: 0,
    qualifyingOrderCount: 0,
    eligibilityRule: '',
    thresholdTickets: 0,
    entryDeadlineAt: null,
    entryClosed: false,
  );

  final int earnedCount;
  final int usedCount;
  final int remainingCount;
  final int ticketCount;
  final int availableTicketCount;
  final int consumedTicketCount;
  final int qualifyingOrderCount;
  final String eligibilityRule;
  final int thresholdTickets;
  final Object? entryDeadlineAt;
  final bool entryClosed;
}

class ActivityNumberBoard {
  const ActivityNumberBoard({
    required this.predictionType,
    required this.digits,
    required this.totalCount,
    required this.reservedCount,
    required this.remainingCount,
    required this.reservedNumbers,
  });

  factory ActivityNumberBoard.fromJson(Object? value) {
    final json = _asMap(value);
    final predictionType = json['prediction_type']?.toString() ?? '';
    final digits = _intValue(json['digits']);
    final total = _intValue(json['total_count']);
    final reserved = _stringList(json['reserved_numbers']);
    final reservedCount = _intValue(json['reserved_count']);
    final remaining = _intValue(json['remaining_count']);
    final hasRemaining = json.containsKey('remaining_count');
    final reservedTotal = reservedCount > 0 ? reservedCount : reserved.length;
    return ActivityNumberBoard(
      predictionType: predictionType,
      digits:
          digits > 0 ? digits : (predictionType == 'first_prize_last3' ? 3 : 2),
      totalCount: total > 0 ? total : 0,
      reservedCount: reservedTotal,
      remainingCount: hasRemaining
          ? remaining
          : (total > 0 ? total - reservedTotal : 0).clamp(0, total),
      reservedNumbers: reserved.toSet(),
    );
  }

  static const empty = ActivityNumberBoard(
    predictionType: '',
    digits: 2,
    totalCount: 0,
    reservedCount: 0,
    remainingCount: 0,
    reservedNumbers: {},
  );

  final String predictionType;
  final int digits;
  final int totalCount;
  final int reservedCount;
  final int remainingCount;
  final Set<String> reservedNumbers;

  bool get isReady => predictionType.isNotEmpty && totalCount > 0;
  bool get entryClosed => remainingCount <= 0 && totalCount > 0;

  String numberAt(int index) => index.toString().padLeft(digits, '0');
  bool isReserved(String number) => reservedNumbers.contains(number);
}

class ActivityConfig {
  const ActivityConfig({
    required this.predictionType,
    required this.eligibilityRule,
    required this.thresholdTickets,
  });

  factory ActivityConfig.fromJson(Object? value) {
    final json = _asMap(value);
    return ActivityConfig(
      predictionType: json['prediction_type']?.toString() ?? '',
      eligibilityRule: json['eligibility_rule']?.toString() ?? '',
      thresholdTickets: _intValue(json['threshold_tickets']),
    );
  }

  static const empty = ActivityConfig(
    predictionType: '',
    eligibilityRule: '',
    thresholdTickets: 0,
  );

  final String predictionType;
  final String eligibilityRule;
  final int thresholdTickets;
}

class ActivityCashbackProgress {
  const ActivityCashbackProgress({
    required this.ticketCount,
    required this.purchaseAmount,
    required this.minimumType,
    required this.minTicketCount,
    required this.minPurchaseAmount,
    required this.isEligible,
    required this.estimatedAmount,
    required this.potentialAmount,
  });

  factory ActivityCashbackProgress.fromJson(Object? value) {
    final json = _asMap(value);
    return ActivityCashbackProgress(
      ticketCount: _intValue(json['ticket_count']),
      purchaseAmount: moneyToDisplayNumber(json['purchase_amount']),
      minimumType: json['minimum_type']?.toString() ?? '',
      minTicketCount: _intValue(json['min_ticket_count']),
      minPurchaseAmount: moneyToDisplayNumber(json['min_purchase_amount']),
      isEligible: json['eligible_by_purchase'] == true ||
          json['is_eligible'] == true ||
          json['eligible'] == true,
      estimatedAmount: moneyToDisplayNumber(json['estimated_amount']),
      potentialAmount: moneyToDisplayNumber(json['potential_amount']),
    );
  }

  static const empty = ActivityCashbackProgress(
    ticketCount: 0,
    purchaseAmount: 0,
    minimumType: '',
    minTicketCount: 0,
    minPurchaseAmount: 0,
    isEligible: false,
    estimatedAmount: 0,
    potentialAmount: 0,
  );

  final int ticketCount;
  final double purchaseAmount;
  final String minimumType;
  final int minTicketCount;
  final double minPurchaseAmount;
  final bool isEligible;
  final double estimatedAmount;
  final double potentialAmount;
}

class ActivityEntry {
  const ActivityEntry({
    required this.id,
    required this.predictionType,
    required this.selectedNumber,
    required this.status,
    required this.createdAt,
  });

  factory ActivityEntry.fromJson(Map<String, dynamic> json) {
    return ActivityEntry(
      id: json['id']?.toString() ?? '',
      predictionType: json['prediction_type']?.toString() ?? '',
      selectedNumber: json['selected_number']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      createdAt: json['created_at'],
    );
  }

  final String id;
  final String predictionType;
  final String selectedNumber;
  final String status;
  final Object? createdAt;

  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';
}

class ActivityAwardItem {
  const ActivityAwardItem({
    required this.id,
    required this.activityId,
    required this.activityName,
    required this.type,
    required this.predictionType,
    required this.amount,
    required this.status,
    required this.claimId,
    required this.calculatedAt,
  });

  factory ActivityAwardItem.fromJson(Map<String, dynamic> json) {
    final claim = _asMap(json['claim']);
    return ActivityAwardItem(
      id: json['id']?.toString() ?? '',
      activityId: json['activity_id']?.toString() ?? '',
      activityName: json['activity_name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      predictionType: json['prediction_type']?.toString() ?? '',
      amount: moneyToDisplayNumber(json['amount']),
      status: json['status']?.toString().toLowerCase() ?? '',
      claimId: claim['id']?.toString() ?? '',
      calculatedAt: json['calculated_at'],
    );
  }

  final String id;
  final String activityId;
  final String activityName;
  final String type;
  final String predictionType;
  final double amount;
  final String status;
  final String claimId;
  final Object? calculatedAt;

  bool get isClaimable => status == 'claimable';
  bool get hasClaim => claimId.isNotEmpty || status == 'claimed';
  bool get isCashback => type == 'cashback';
}

class ActivityAwardPage {
  const ActivityAwardPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ActivityAwardPage.fromJson(Map<String, dynamic> json) {
    final meta = _asMap(json['meta']);
    return ActivityAwardPage(
      items: _asMapList(json['data'])
          .map(ActivityAwardItem.fromJson)
          .toList(growable: false),
      nextCursor: meta['next_cursor']?.toString(),
      hasMore: meta['has_more'] == true && meta['next_cursor'] != null,
    );
  }

  final List<ActivityAwardItem> items;
  final String? nextCursor;
  final bool hasMore;
}

class ActivityResultSummary {
  const ActivityResultSummary({
    required this.status,
    required this.predictionType,
    required this.winningNumber,
    required this.winnerCount,
    required this.awardTotal,
    required this.customerStatus,
    required this.customerWinningNumbers,
    required this.customerAwardAmount,
  });

  static ActivityResultSummary? tryFromJson(Object? value) {
    final json = _asMap(value);
    if (json.isEmpty) return null;
    final customer = _asMap(json['customer']);
    return ActivityResultSummary(
      status: json['status']?.toString() ?? '',
      predictionType: json['prediction_type']?.toString() ?? '',
      winningNumber: json['winning_number']?.toString() ?? '',
      winnerCount: _intValue(json['winner_count']),
      awardTotal: moneyToDisplayNumber(json['award_total']),
      customerStatus: customer['status']?.toString() ?? '',
      customerWinningNumbers: _stringList(customer['winning_numbers']),
      customerAwardAmount: moneyToDisplayNumber(customer['award_amount']),
    );
  }

  final String status;
  final String predictionType;
  final String winningNumber;
  final int winnerCount;
  final double awardTotal;
  final String customerStatus;
  final List<String> customerWinningNumbers;
  final double customerAwardAmount;

  bool get isAnnounced => status == 'announced' && winningNumber.isNotEmpty;
  bool get customerWon => customerStatus == 'won';
  bool get customerLost => customerStatus == 'lost';
}

List<ActivityEntry> asActivityEntries(Object? value) {
  return _asMapList(value).map(ActivityEntry.fromJson).toList(growable: false);
}

String _identity(String value) => value;

Map<String, dynamic> _asMap(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(Object? value) {
  if (value is! List) return const [];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
