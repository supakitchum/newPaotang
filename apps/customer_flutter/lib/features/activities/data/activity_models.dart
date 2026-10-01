import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

class ActivityListPage {
  const ActivityListPage({
    required this.items,
    required this.meta,
  });

  factory ActivityListPage.fromJson(
    Map<String, dynamic> json, {
    String Function(String value) resolveAssetUrl = _identity,
  }) {
    final payload = _activityPagePayload(json);
    final meta = _activityPageMeta(json, payload);
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : _asMapList(
            payload['activities'] ??
                payload['activityItems'] ??
                payload['items'] ??
                payload['list'],
          );
    return ActivityListPage(
      items: items
          .map(
            (row) =>
                ActivityItem.fromJson(row, resolveAssetUrl: resolveAssetUrl),
          )
          .toList(growable: false),
      meta: ActivityListMeta.fromJson(meta),
    );
  }

  final List<ActivityItem> items;
  final ActivityListMeta meta;
}

class ActivityListMeta {
  const ActivityListMeta({
    required this.hasHistory,
    required this.hasMore,
    required this.nextCursor,
    required this.selectedGameId,
    required this.games,
  });

  factory ActivityListMeta.fromJson(Object? value) {
    final json = _asMap(value);
    final nextCursor =
        (json['next_cursor'] ?? json['nextCursor'] ?? json['cursor'])
            ?.toString();
    return ActivityListMeta(
      hasHistory: _boolValue(json['has_history'] ?? json['hasHistory']),
      hasMore: _boolValue(json['has_more'] ?? json['hasMore']) &&
          nextCursor != null &&
          nextCursor.isNotEmpty,
      nextCursor: nextCursor,
      selectedGameId:
          (json['selected_game_id'] ?? json['selectedGameId'])?.toString() ??
              '',
      games: _asMapList(
        json['games'] ?? json['game_options'] ?? json['gameOptions'],
      ).map(ActivityGameOption.fromJson).toList(growable: false),
    );
  }

  static const empty = ActivityListMeta(
    hasHistory: false,
    hasMore: false,
    nextCursor: null,
    selectedGameId: '',
    games: [],
  );

  final bool hasHistory;
  final bool hasMore;
  final String? nextCursor;
  final String selectedGameId;
  final List<ActivityGameOption> games;
}

class ActivityGameOption {
  const ActivityGameOption({
    required this.id,
    required this.label,
  });

  factory ActivityGameOption.fromJson(Map<String, dynamic> json) {
    final id =
        (json['id'] ?? json['game_id'] ?? json['gameId'])?.toString() ?? '';
    final rawLabel = (json['label'] ??
            json['name'] ??
            json['code'] ??
            json['draw_label'] ??
            json['drawLabel'] ??
            json['draw_date'] ??
            json['drawDate'] ??
            id)
        ?.toString()
        .trim();
    return ActivityGameOption(
      id: id,
      label: rawLabel == null || rawLabel.isEmpty ? id : rawLabel,
    );
  }

  final String id;
  final String label;
}

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
    this.imageFullUrl = '',
    this.gameName = '',
    this.rights = ActivityRights.empty,
    this.entries = const [],
    this.numberBoard = ActivityNumberBoard.empty,
    this.config = ActivityConfig.empty,
    this.cashbackProgress = ActivityCashbackProgress.empty,
    this.resultSummary,
    this.resultAt,
  });

  factory ActivityItem.fromJson(
    Map<String, dynamic> json, {
    String Function(String value) resolveAssetUrl = _identity,
  }) {
    final payload = _activityItemPayload(json);
    final type =
        (payload['type'] ?? payload['activity_type'] ?? payload['activityType'])
                ?.toString() ??
            '';
    final config = ActivityConfig.fromJson(payload['config']);
    final board = ActivityNumberBoard.fromJson(
      payload['number_board'] ?? payload['numberBoard'],
      preferredPredictionTypes: config.enabledPredictionTypes,
    );
    final rightsPayload = Map<String, dynamic>.from(payload)
      ..addAll(_asMap(payload['rights']));
    final rights = ActivityRights.fromJson(rightsPayload);
    final progress = ActivityCashbackProgress.fromJson(
      payload['cashback_progress'] ?? payload['cashbackProgress'],
    );
    final game = _asMap(payload['game']);
    final imageThumbUrl = _firstActivityAssetText([
      payload['image_thumb'],
      payload['imageThumb'],
      payload['image_thumb_url'],
      payload['imageThumbUrl'],
      payload['cover'],
      payload['cover_url'],
      payload['coverUrl'],
    ]);
    final imageFullUrl = _firstActivityAssetText([
      payload['image'],
      payload['image_full'],
      payload['imageFull'],
      payload['image_full_url'],
      payload['imageFullUrl'],
    ]);
    final listImageUrl =
        imageThumbUrl.isNotEmpty ? imageThumbUrl : imageFullUrl;
    final detailImageUrl =
        imageFullUrl.isNotEmpty ? imageFullUrl : listImageUrl;

    return ActivityItem(
      id: (payload['id'] ?? payload['activity_id'] ?? payload['activityId'])
              ?.toString() ??
          '',
      name: (payload['name'] ?? payload['title'])?.toString() ?? '',
      slug: payload['slug']?.toString() ?? '',
      type: type,
      imageUrl: _resolveActivityAsset(listImageUrl, resolveAssetUrl),
      imageFullUrl: _resolveActivityAsset(detailImageUrl, resolveAssetUrl),
      conditionText: _conditionText(payload),
      remainingNumbers: board.remainingCount,
      hasRight: rights.remainingCount > 0 ||
          rights.earnedCount > 0 ||
          progress.isEligible ||
          payload['award'] is Map ||
          payload['activity_award'] is Map ||
          payload['activityAward'] is Map,
      estimatedCashbackAmount: progress.estimatedAmount,
      gameName: (game['name'] ??
                  game['label'] ??
                  game['draw_label'] ??
                  game['drawLabel'] ??
                  payload['game_name'] ??
                  payload['gameName'] ??
                  payload['draw_label'] ??
                  payload['drawLabel'])
              ?.toString()
              .trim() ??
          '',
      rights: rights,
      entries:
          asActivityEntries(payload['entries'] ?? payload['activityEntries']),
      numberBoard: board,
      config: config,
      cashbackProgress: progress,
      resultSummary: ActivityResultSummary.tryFromJson(
        payload['result_summary'] ?? payload['resultSummary'],
      ),
      resultAt: payload['result_at'] ?? payload['resultAt'],
    );
  }

  final String id;
  final String name;
  final String slug;
  final String type;
  final String imageUrl;
  final String imageFullUrl;
  final String conditionText;
  final int remainingNumbers;
  final bool hasRight;
  final double estimatedCashbackAmount;
  final String gameName;
  final ActivityRights rights;
  final List<ActivityEntry> entries;
  final ActivityNumberBoard numberBoard;
  final ActivityConfig config;
  final ActivityCashbackProgress cashbackProgress;
  final ActivityResultSummary? resultSummary;
  final Object? resultAt;

  bool get isCashback => type == 'cashback';
  bool get isLuckyBoard => type == 'lucky_board';
  String get detailImageUrl =>
      imageFullUrl.trim().isNotEmpty ? imageFullUrl : imageUrl;

  static String _conditionText(Map<String, dynamic> json) {
    final description = (json['description'] ??
            json['summary'] ??
            json['condition_text'] ??
            json['conditionText'])
        ?.toString();
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
      earnedCount: _intValue(
        json['earned_count'] ??
            json['earnedCount'] ??
            json['earned_rights'] ??
            json['earnedRights'] ??
            json['earned'],
      ),
      usedCount: _intValue(
        json['used_count'] ??
            json['usedCount'] ??
            json['used_rights'] ??
            json['usedRights'] ??
            json['used'],
      ),
      remainingCount: _intValue(
        json['remaining_count'] ??
            json['remainingCount'] ??
            json['remaining_rights'] ??
            json['remainingRights'] ??
            json['remaining'],
      ),
      ticketCount: _intValue(json['ticket_count'] ?? json['ticketCount']),
      availableTicketCount: _intValue(
        json['available_ticket_count'] ?? json['availableTicketCount'],
      ),
      consumedTicketCount: _intValue(
        json['consumed_ticket_count'] ?? json['consumedTicketCount'],
      ),
      qualifyingOrderCount: _intValue(
        json['qualifying_order_count'] ?? json['qualifyingOrderCount'],
      ),
      eligibilityRule:
          (json['eligibility_rule'] ?? json['eligibilityRule'])?.toString() ??
              '',
      thresholdTickets:
          _intValue(json['threshold_tickets'] ?? json['thresholdTickets']),
      entryDeadlineAt: json['entry_deadline_at'] ?? json['entryDeadlineAt'],
      entryClosed: _boolValue(json['entry_closed'] ?? json['entryClosed']),
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

  factory ActivityNumberBoard.fromJson(
    Object? value, {
    Iterable<String> preferredPredictionTypes = const [],
  }) {
    final json = _asMap(value);
    return ActivityNumberBoard.fromPayload(
      json,
      preferredPredictionTypes: preferredPredictionTypes,
    );
  }

  factory ActivityNumberBoard.fromPayload(
    Map<String, dynamic> json, {
    Iterable<String> preferredPredictionTypes = const [],
  }) {
    final selected = _selectActivityNumberBoardPayload(
      json,
      preferredPredictionTypes,
    );
    final payload = selected.payload;
    final predictionType = (payload['prediction_type'] ??
                payload['predictionType'] ??
                selected.predictionType)
            ?.toString() ??
        '';
    final digits = _intValue(json['digits']);
    final payloadDigits = _intValue(payload['digits']);
    final total = _intValue(payload['total_count'] ?? payload['totalCount']);
    final reserved =
        _stringList(payload['reserved_numbers'] ?? payload['reservedNumbers']);
    final reservedCount =
        _intValue(payload['reserved_count'] ?? payload['reservedCount']);
    final remaining =
        _intValue(payload['remaining_count'] ?? payload['remainingCount']);
    final hasRemaining = payload.containsKey('remaining_count') ||
        payload.containsKey('remainingCount');
    final reservedTotal = reservedCount > 0 ? reservedCount : reserved.length;
    final boardDigits = payloadDigits > 0
        ? payloadDigits
        : digits > 0
            ? digits
            : _activityPredictionDigits(predictionType);
    return ActivityNumberBoard(
      predictionType: predictionType,
      digits: boardDigits,
      totalCount: total > 0 ? total : 0,
      reservedCount: reservedTotal,
      remainingCount: hasRemaining
          ? remaining
          : (total > 0 ? total - reservedTotal : 0).clamp(0, total),
      reservedNumbers: reserved
          .map((number) => _activityNumberText(number, boardDigits))
          .where((number) => number.isNotEmpty)
          .toSet(),
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

const _activityPredictionTypeOrder = [
  'first_prize_last2',
  'first_prize_last3',
  'last2',
];

({Map<String, dynamic> payload, String predictionType})
    _selectActivityNumberBoardPayload(
  Map<String, dynamic> json,
  Iterable<String> preferredPredictionTypes,
) {
  final types = _asMap(
    json['types'] ?? json['prediction_types'] ?? json['predictionTypes'],
  );
  if (types.isEmpty) return (payload: json, predictionType: '');

  final preferred = [
    ...preferredPredictionTypes.map((type) => type.trim()).where(
          (type) => type.isNotEmpty,
        ),
    ..._activityPredictionTypeOrder,
  ];
  final seen = <String>{};
  for (final predictionType in preferred) {
    if (!seen.add(predictionType)) continue;
    final typedBoard = _asMap(types[predictionType]);
    if (typedBoard.isNotEmpty) {
      return (payload: typedBoard, predictionType: predictionType);
    }
  }

  for (final entry in types.entries) {
    final typedBoard = _asMap(entry.value);
    if (typedBoard.isNotEmpty) {
      return (payload: typedBoard, predictionType: entry.key.toString());
    }
  }

  return (payload: json, predictionType: '');
}

class ActivityConfig {
  const ActivityConfig({
    required this.predictionType,
    required this.eligibilityRule,
    required this.thresholdTickets,
    required this.cashbackType,
    required this.cashbackPercentBps,
    required this.fixedAmount,
    required this.minimumType,
    required this.minTicketCount,
    required this.minPurchaseAmount,
    this.enabledPredictionTypes = const [],
  });

  factory ActivityConfig.fromJson(Object? value) {
    final json = _asMap(value);
    final predictionType =
        (json['prediction_type'] ?? json['predictionType'])?.toString() ?? '';
    return ActivityConfig(
      predictionType: predictionType,
      eligibilityRule:
          (json['eligibility_rule'] ?? json['eligibilityRule'])?.toString() ??
              '',
      thresholdTickets:
          _intValue(json['threshold_tickets'] ?? json['thresholdTickets']),
      cashbackType:
          (json['cashback_type'] ?? json['cashbackType'])?.toString() ?? '',
      cashbackPercentBps: _intValue(
        json['cashback_percent_bps'] ?? json['cashbackPercentBps'],
      ),
      fixedAmount: moneyToDisplayNumber(
        json['fixed_amount'] ?? json['fixedAmount'],
      ),
      minimumType:
          (json['minimum_type'] ?? json['minimumType'])?.toString() ?? '',
      minTicketCount:
          _intValue(json['min_ticket_count'] ?? json['minTicketCount']),
      minPurchaseAmount: moneyToDisplayNumber(
        json['min_purchase_amount'] ?? json['minPurchaseAmount'],
      ),
      enabledPredictionTypes: _enabledActivityPredictionTypes(
        json['prediction_types'] ?? json['predictionTypes'],
        fallbackPredictionType: predictionType,
      ),
    );
  }

  static const empty = ActivityConfig(
    predictionType: '',
    eligibilityRule: '',
    thresholdTickets: 0,
    cashbackType: '',
    cashbackPercentBps: 0,
    fixedAmount: 0,
    minimumType: '',
    minTicketCount: 0,
    minPurchaseAmount: 0,
  );

  final String predictionType;
  final String eligibilityRule;
  final int thresholdTickets;
  final String cashbackType;
  final int cashbackPercentBps;
  final double fixedAmount;
  final String minimumType;
  final int minTicketCount;
  final double minPurchaseAmount;
  final List<String> enabledPredictionTypes;
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
      ticketCount: _intValue(json['ticket_count'] ?? json['ticketCount']),
      purchaseAmount: moneyToDisplayNumber(
        json['purchase_amount'] ?? json['purchaseAmount'],
      ),
      minimumType:
          (json['minimum_type'] ?? json['minimumType'])?.toString() ?? '',
      minTicketCount:
          _intValue(json['min_ticket_count'] ?? json['minTicketCount']),
      minPurchaseAmount: moneyToDisplayNumber(
        json['min_purchase_amount'] ?? json['minPurchaseAmount'],
      ),
      isEligible: _boolValue(
        json['eligible_by_purchase'] ??
            json['eligibleByPurchase'] ??
            json['is_eligible'] ??
            json['isEligible'] ??
            json['eligible'],
      ),
      estimatedAmount: moneyToDisplayNumber(
        json['estimated_amount'] ?? json['estimatedAmount'],
      ),
      potentialAmount: moneyToDisplayNumber(
        json['potential_amount'] ?? json['potentialAmount'],
      ),
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
    final payload = _activityEntryPayload(json);
    final predictionType =
        (payload['prediction_type'] ?? payload['predictionType'])?.toString() ??
            '';
    return ActivityEntry(
      id: (payload['id'] ?? payload['entry_id'] ?? payload['entryId'])
              ?.toString() ??
          '',
      predictionType: predictionType,
      selectedNumber: _activityNumberText(
        payload['selected_number'] ?? payload['selectedNumber'],
        _activityPredictionDigits(predictionType),
      ),
      status: payload['status']?.toString() ?? '',
      createdAt: payload['created_at'] ?? payload['createdAt'],
    );
  }

  final String id;
  final String predictionType;
  final String selectedNumber;
  final String status;
  final Object? createdAt;

  bool get isWon => status == 'won';
  bool get isLost => status == 'lost';
  bool get isCancelled {
    final normalized = status.trim().toLowerCase().replaceAll('-', '_');
    return normalized == 'cancelled' || normalized == 'canceled';
  }
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
    final payload = _activityAwardPayload(json);
    final claim = _asMap(payload['claim']);
    return ActivityAwardItem(
      id: (payload['id'] ?? payload['award_id'] ?? payload['awardId'])
              ?.toString() ??
          '',
      activityId:
          (payload['activity_id'] ?? payload['activityId'])?.toString() ?? '',
      activityName:
          (payload['activity_name'] ?? payload['activityName'])?.toString() ??
              '',
      type: (payload['type'] ??
                  payload['award_type'] ??
                  payload['awardType'] ??
                  payload['reward_type'] ??
                  payload['rewardType'])
              ?.toString() ??
          '',
      predictionType: (payload['prediction_type'] ?? payload['predictionType'])
              ?.toString() ??
          '',
      amount: moneyToDisplayNumber(
        payload['amount'] ??
            payload['award_amount'] ??
            payload['awardAmount'] ??
            payload['reward_amount'] ??
            payload['rewardAmount'],
      ),
      status: _activityAwardStatus(payload),
      claimId: (claim['id'] ??
                  claim['claim_id'] ??
                  claim['claimId'] ??
                  payload['claim_id'] ??
                  payload['claimId'])
              ?.toString() ??
          '',
      calculatedAt: payload['calculated_at'] ?? payload['calculatedAt'],
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
  bool get isSubmitted => status == 'claimed' || status == 'submitted';
  bool get isApproved => status == 'approved';
  bool get isPaid => status == 'paid';
  bool get isRejected => status == 'rejected';
  bool get isCancelled => status == 'cancelled';
  bool get hasClaim =>
      claimId.isNotEmpty || isSubmitted || isApproved || isPaid;
  bool get isCashback => type == 'cashback';
}

String _activityAwardStatus(Map<String, dynamic> payload) {
  final claim = _asMap(payload['claim']);
  final raw = (payload['status'] ??
              payload['claim_status'] ??
              payload['claimStatus'] ??
              payload['presentation_status'] ??
              payload['presentationStatus'] ??
              claim['status'] ??
              claim['claim_status'] ??
              claim['claimStatus'] ??
              claim['presentation_status'] ??
              claim['presentationStatus'])
          ?.toString()
          .trim()
          .toLowerCase()
          .replaceAll('-', '_') ??
      '';
  if (_activityAwardHasPaidEvidence(payload, claim) &&
      (raw.isEmpty ||
          raw == 'approved' ||
          raw == 'claim_approved' ||
          raw == 'pending_transfer' ||
          raw == 'transfer_pending' ||
          raw == 'waiting_transfer')) {
    return 'paid';
  }
  if (raw.isEmpty) {
    final claimable = _boolValue(
      payload['claimable'] ??
          payload['is_claimable'] ??
          payload['isClaimable'] ??
          payload['can_claim'] ??
          payload['canClaim'],
    );
    return claimable ? 'claimable' : '';
  }

  return switch (raw) {
    'claimable' ||
    'claim_ready' ||
    'ready_to_claim' ||
    'ready_for_claim' =>
      'claimable',
    'claimed' ||
    'claim_submitted' ||
    'submitted' ||
    'claim_pending' ||
    'pending_review' ||
    'in_review' ||
    'under_review' =>
      'submitted',
    'claim_approved' ||
    'approved' ||
    'pending_transfer' ||
    'transfer_pending' ||
    'waiting_transfer' =>
      'approved',
    'claim_paid' ||
    'paid' ||
    'paid_out' ||
    'transferred' ||
    'transfer_completed' ||
    'payout_completed' ||
    'payment_completed' ||
    'completed' ||
    'complete' ||
    'success' =>
      'paid',
    'claim_rejected' || 'rejected' || 'declined' || 'failed' => 'rejected',
    'claim_cancelled' ||
    'claim_canceled' ||
    'cancelled' ||
    'canceled' =>
      'cancelled',
    _ => raw,
  };
}

bool _activityAwardHasPaidEvidence(
  Map<String, dynamic> payload,
  Map<String, dynamic> claim,
) {
  return _hasValue(payload['paid_at']) ||
      _hasValue(payload['paidAt']) ||
      _hasValue(payload['transferred_at']) ||
      _hasValue(payload['transferredAt']) ||
      _hasValue(payload['payout_ledger_id']) ||
      _hasValue(payload['payoutLedgerId']) ||
      _hasValue(claim['paid_at']) ||
      _hasValue(claim['paidAt']) ||
      _hasValue(claim['transferred_at']) ||
      _hasValue(claim['transferredAt']) ||
      _hasValue(claim['payout_ledger_id']) ||
      _hasValue(claim['payoutLedgerId']);
}

bool _hasValue(Object? value) => value?.toString().trim().isNotEmpty ?? false;

class ActivityAwardPage {
  const ActivityAwardPage({
    required this.items,
    required this.nextCursor,
    required this.hasMore,
  });

  factory ActivityAwardPage.fromJson(Map<String, dynamic> json) {
    final payload = _activityPagePayload(json);
    final meta = _activityPageMeta(json, payload);
    final rows = unwrapDataList(json);
    final items = rows.isNotEmpty
        ? rows
        : _asMapList(
            payload['awards'] ??
                payload['activity_awards'] ??
                payload['activityAwards'] ??
                payload['items'],
          );
    final nextCursor =
        (meta['next_cursor'] ?? meta['nextCursor'] ?? meta['cursor'])
            ?.toString();
    return ActivityAwardPage(
      items: items.map(ActivityAwardItem.fromJson).toList(growable: false),
      nextCursor: nextCursor,
      hasMore: _boolValue(meta['has_more'] ?? meta['hasMore']) &&
          nextCursor != null &&
          nextCursor.isNotEmpty,
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
    required this.winningNumbers,
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
    final predictionType =
        (json['prediction_type'] ?? json['predictionType'])?.toString() ?? '';
    final digits = _activityPredictionDigits(predictionType);
    final winningNumbers = _activityNumberList(
      json['winning_numbers'] ??
          json['winningNumbers'] ??
          json['winning_number'] ??
          json['winningNumber'],
      digits,
    );
    return ActivityResultSummary(
      status: _normalizedActivityStatus(json['status']),
      predictionType: predictionType,
      winningNumber: winningNumbers.isEmpty ? '' : winningNumbers.first,
      winningNumbers: winningNumbers,
      winnerCount: _intValue(json['winner_count'] ?? json['winnerCount']),
      awardTotal:
          moneyToDisplayNumber(json['award_total'] ?? json['awardTotal']),
      customerStatus: _normalizedActivityStatus(customer['status']),
      customerWinningNumbers: _activityNumberList(
        customer['winning_numbers'] ?? customer['winningNumbers'],
        digits,
      ),
      customerAwardAmount: moneyToDisplayNumber(
        customer['award_amount'] ?? customer['awardAmount'],
      ),
    );
  }

  final String status;
  final String predictionType;
  final String winningNumber;
  final List<String> winningNumbers;
  final int winnerCount;
  final double awardTotal;
  final String customerStatus;
  final List<String> customerWinningNumbers;
  final double customerAwardAmount;

  bool get isAnnounced => status == 'announced' && winningNumbers.isNotEmpty;
  bool get customerWon => customerStatus == 'won';
  bool get customerLost => customerStatus == 'lost';
}

List<ActivityEntry> asActivityEntries(Object? value) {
  return _asMapList(value).map(ActivityEntry.fromJson).toList(growable: false);
}

Map<String, dynamic> _activityItemPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in const [
    'activity',
    'item',
    'resource',
    'data',
    'result',
  ]) {
    final activity = _asMap(json[key]);
    if (activity.isEmpty) continue;
    return _mergeActivityWrapper(
      json,
      _activityItemPayload(activity, depth + 1),
    );
  }
  return json;
}

Map<String, dynamic> _activityEntryPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in const [
    'entry',
    'activity_entry',
    'activityEntry',
    'item',
    'resource',
    'data',
    'result',
  ]) {
    final entry = _asMap(json[key]);
    if (entry.isEmpty) continue;
    return _mergeActivityWrapper(json, _activityEntryPayload(entry, depth + 1));
  }
  return json;
}

Map<String, dynamic> _activityAwardPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in const [
    'award',
    'activity_award',
    'activityAward',
    'item',
    'resource',
    'data',
    'result',
  ]) {
    final award = _asMap(json[key]);
    if (award.isEmpty) continue;
    return _mergeActivityWrapper(json, _activityAwardPayload(award, depth + 1));
  }
  return json;
}

Map<String, dynamic> _activityPagePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in _activityPageWrapperKeys) {
    final page = _asMap(json[key]);
    if (page.isEmpty) continue;
    return _mergeActivityPageWrapper(
      json,
      _activityPagePayload(page, depth + 1),
    );
  }

  return json;
}

const _activityPageWrapperKeys = [
  'page',
  'activity_page',
  'activityPage',
  'activities_page',
  'activitiesPage',
  'activity_items_page',
  'activityItemsPage',
  'activity_list_page',
  'activityListPage',
  'award_page',
  'awardPage',
  'awards_page',
  'awardsPage',
  'activity_award_page',
  'activityAwardPage',
  'activity_awards_page',
  'activityAwardsPage',
  'resource',
  'data',
  'result',
];

Map<String, dynamic> _activityPageMeta(
  Map<String, dynamic> original,
  Map<String, dynamic> payload,
) {
  return {
    ...unwrapMeta(original),
    ..._asMap(payload['pagination']),
    ..._asMap(payload['meta']),
  };
}

Map<String, dynamic> _mergeActivityPageWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..removeWhere((key, _) => _activityPageWrapperKeys.contains(key));
  final wrapperMeta = _asMap(merged['meta']);
  final nestedMeta = _asMap(nested['meta']);
  final wrapperPagination = _asMap(merged['pagination']);
  final nestedPagination = _asMap(nested['pagination']);

  merged.addAll(nested);

  if (wrapperMeta.isNotEmpty || nestedMeta.isNotEmpty) {
    merged['meta'] = {...wrapperMeta, ...nestedMeta};
  }
  if (wrapperPagination.isNotEmpty || nestedPagination.isNotEmpty) {
    merged['pagination'] = {...wrapperPagination, ...nestedPagination};
  }

  return merged;
}

Map<String, dynamic> _mergeActivityWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..remove('activity')
    ..remove('entry')
    ..remove('activity_entry')
    ..remove('activityEntry')
    ..remove('award')
    ..remove('activity_award')
    ..remove('activityAward')
    ..remove('item')
    ..remove('resource')
    ..remove('data')
    ..remove('result');
  merged.addAll(nested);
  return merged;
}

String _identity(String value) => value;

String _resolveActivityAsset(
  String value,
  String Function(String value) resolveAssetUrl,
) {
  final normalized = value.trim();
  return normalized.isEmpty ? '' : resolveAssetUrl(normalized);
}

String _firstActivityAssetText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _activityAssetText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

String _activityAssetText(Object? value, [int depth = 0]) {
  if (value == null || depth > 3) return '';
  if (value is String) return value.trim();
  if (value is Uri) return value.toString().trim();
  if (value is Map) {
    final payload = Map<String, dynamic>.from(value);
    for (final key in const [
      'public_url',
      'publicUrl',
      'asset_url',
      'assetUrl',
      'image_url',
      'imageUrl',
      'url',
      'src',
      'path',
      'value',
    ]) {
      final text = _activityAssetText(payload[key], depth + 1);
      if (text.isNotEmpty) return text;
    }
  }
  return '';
}

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

List<String> _enabledActivityPredictionTypes(
  Object? value, {
  String fallbackPredictionType = '',
}) {
  final fallback = fallbackPredictionType.trim();
  if (value == null) {
    return [
      if (fallback.isNotEmpty) fallback,
      ..._activityPredictionTypeOrder.where((type) => type != fallback),
    ];
  }

  if (value is List) {
    final values = value
        .map((item) => item?.toString().trim() ?? '')
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (values.isNotEmpty) return values;
  }

  if (value is String) {
    final values = value
        .split(',')
        .map((item) => item.trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
    if (values.isNotEmpty) return values;
  }

  final json = _asMap(value);
  if (json.isNotEmpty) {
    final enabled = <String>[];
    for (final predictionType in _activityPredictionTypeOrder) {
      if (_activityPredictionTypeEnabled(json[predictionType])) {
        enabled.add(predictionType);
      }
    }
    for (final entry in json.entries) {
      final predictionType = entry.key.trim();
      if (predictionType.isEmpty ||
          enabled.contains(predictionType) ||
          !_activityPredictionTypeEnabled(entry.value)) {
        continue;
      }
      enabled.add(predictionType);
    }
    if (enabled.isNotEmpty) return enabled;
  }

  return _activityPredictionTypeOrder;
}

bool _activityPredictionTypeEnabled(Object? value) {
  if (value == null) return true;
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value.toString().trim().toLowerCase();
  return normalized != 'false' &&
      normalized != '0' &&
      normalized != 'no' &&
      normalized != 'disabled' &&
      normalized != 'off';
}

int _activityPredictionDigits(String predictionType) {
  return predictionType == 'first_prize_last3' ? 3 : 2;
}

String _activityNumberText(Object? value, int digits) {
  final number = value?.toString().replaceAll(RegExp(r'\D'), '') ?? '';
  if (number.isEmpty) return '';
  if (digits <= 0) return number;
  return number.padLeft(digits, '0');
}

List<String> _activityNumberList(Object? value, int digits) {
  final values = value is List ? value : [value];
  return values
      .map((item) => _activityNumberText(item, digits))
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}

String _normalizedActivityStatus(Object? value) {
  return value?.toString().trim().toLowerCase().replaceAll('-', '_') ?? '';
}

int _intValue(Object? value) {
  if (value is int) return value;
  if (value is num) return value.round();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

bool _boolValue(Object? value) {
  if (value is bool) return value;
  if (value is num) return value != 0;
  final normalized = value?.toString().trim().toLowerCase() ?? '';
  return normalized == 'true' || normalized == '1' || normalized == 'yes';
}

List<String> _stringList(Object? value) {
  if (value is! List) return const [];
  return value
      .map((item) => item?.toString() ?? '')
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
