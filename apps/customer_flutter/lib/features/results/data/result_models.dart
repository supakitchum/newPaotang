import '../../../core/utils/api_payload.dart';
import '../../../core/utils/formatters.dart';

const rewardOrder = [
  'reward_1',
  'reward_two_digit',
  'reward_three_digit_1',
  'reward_three_digit_2',
  'reward_beside_1',
  'reward_2',
  'reward_3',
  'reward_4',
  'reward_5',
];

const rewardDefinitions = <String, ({int count, int digits, int amount})>{
  'reward_1': (count: 1, digits: 6, amount: 6000000),
  'reward_2': (count: 5, digits: 6, amount: 200000),
  'reward_3': (count: 10, digits: 6, amount: 80000),
  'reward_4': (count: 50, digits: 6, amount: 40000),
  'reward_5': (count: 100, digits: 6, amount: 20000),
  'reward_beside_1': (count: 2, digits: 6, amount: 100000),
  'reward_three_digit_1': (count: 2, digits: 3, amount: 4000),
  'reward_three_digit_2': (count: 2, digits: 3, amount: 4000),
  'reward_two_digit': (count: 1, digits: 2, amount: 2000),
};

class CurrentGame {
  const CurrentGame({
    required this.id,
    required this.name,
    required this.status,
    required this.drawAt,
    this.saleStartAt,
    this.saleCloseAt,
    this.serverTime,
  });

  factory CurrentGame.fromJson(Map<String, dynamic> json) {
    final payload = _currentGamePayload(json);
    return CurrentGame(
      id: _firstResultText([
        payload['id'],
        payload['game_id'],
        payload['gameId'],
      ]),
      name: _firstResultText([
        payload['name'],
        payload['game_name'],
        payload['gameName'],
        payload['draw_label'],
        payload['drawLabel'],
      ]),
      status: _firstResultText([
        payload['status'],
        payload['game_status'],
        payload['gameStatus'],
        payload['status_code'],
        payload['statusCode'],
      ]),
      drawAt: _firstResultValue([
        payload['draw_at'],
        payload['drawAt'],
        payload['draw_date'],
        payload['drawDate'],
      ]),
      saleStartAt: _firstResultValue([
        payload['sale_start_at'],
        payload['sales_start_at'],
        payload['saleStartAt'],
        payload['salesStartAt'],
        payload['start_at'],
        payload['startAt'],
      ]),
      saleCloseAt: _firstResultValue([
        payload['sale_close_at'],
        payload['sales_close_at'],
        payload['saleCloseAt'],
        payload['salesCloseAt'],
        payload['close_at'],
        payload['closeAt'],
        payload['end_at'],
        payload['endAt'],
        payload['sale_end_at'],
        payload['saleEndAt'],
        payload['sales_end_at'],
        payload['salesEndAt'],
      ]),
      serverTime: _firstResultValue([
        payload['server_time'],
        payload['serverTime'],
        payload['current_time'],
        payload['currentTime'],
        payload['now'],
      ]),
    );
  }

  final String id;
  final String name;
  final String status;
  final Object? drawAt;
  final Object? saleStartAt;
  final Object? saleCloseAt;
  final Object? serverTime;

  RewardResultGame toPendingRewardGame() {
    return RewardResultGame(
      id: id,
      name: name,
      status: status,
      resultStatus: '',
      officialStatus: '',
      completionPercent: 0,
      drawAt: drawAt,
      rewards: const [],
    );
  }
}

Map<String, dynamic> _currentGamePayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 4) return json;

  for (final key in const [
    'game',
    'current_game',
    'currentGame',
    'resource',
    'data',
    'result',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    return _mergeCurrentGameWrapper(
      json,
      _currentGamePayload(nested, depth + 1),
    );
  }

  return json;
}

Map<String, dynamic> _mergeCurrentGameWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper)
    ..remove('game')
    ..remove('current_game')
    ..remove('currentGame')
    ..remove('resource')
    ..remove('data')
    ..remove('result');
  merged.addAll(nested);
  return merged;
}

class RewardResultGame {
  const RewardResultGame({
    required this.id,
    required this.name,
    required this.status,
    required this.resultStatus,
    required this.officialStatus,
    required this.completionPercent,
    required this.drawAt,
    required this.rewards,
  });

  factory RewardResultGame.fromPublicSummary(Map<String, dynamic> json) {
    final payload = _rewardResultPayload(json);
    final game = _firstResultMap([
      payload['game'],
      payload['current_game'],
      payload['currentGame'],
      payload['reward_game'],
      payload['rewardGame'],
      payload['lottery_game'],
      payload['lotteryGame'],
    ]);
    final grouped = <String, RewardValue>{};
    for (final prize in _rewardPrizeRows(payload)) {
      final slug = rewardTypeToSlug(
        _firstResultValue([
          prize['prize_type'],
          prize['prizeType'],
          prize['reward_type'],
          prize['rewardType'],
          prize['type'],
          prize['slug'],
          prize['code'],
        ]),
      );
      if (slug.isEmpty) continue;
      final existing = grouped[slug] ??
          RewardValue(
            slug: slug,
            title: _firstResultText([
              prize['name'],
              prize['title'],
              prize['label'],
              prize['prize_name'],
              prize['prizeName'],
            ]),
            amount: moneyToDisplayNumber(
              _firstPresentResultValue([
                prize['amount'],
                prize['reward'],
                prize['prize_amount'],
                prize['prizeAmount'],
                prize['reward_amount'],
                prize['rewardAmount'],
              ]),
              fallback: (rewardDefinitions[slug]?.amount ?? 0).toDouble(),
            ),
            numbers: const [],
          );
      grouped[slug] = existing.copyWith(
        numbers: [
          ...existing.numbers,
          ..._rewardPrizeNumbers(prize),
        ],
      );
    }

    final resultStatus = _firstResultText([
      payload['status'],
      payload['result_status'],
      payload['resultStatus'],
      payload['presentation_status'],
      payload['presentationStatus'],
    ]).toLowerCase();
    final officialStatus = _firstResultText([
      payload['official_status'],
      payload['officialStatus'],
      payload['publication_status'],
      payload['publicationStatus'],
      resultStatus,
    ]).toLowerCase();
    final isPublished =
        officialStatus == 'published' || resultStatus == 'published';
    final completionText = _firstResultText([
      payload['completion_percent'],
      payload['completionPercent'],
      payload['progress_percent'],
      payload['progressPercent'],
      payload['completion'],
      payload['progress'],
      0,
    ]).replaceAll('%', '');

    return RewardResultGame(
      id: _firstResultText([
        payload['game_id'],
        payload['gameId'],
        payload['id'],
        game['id'],
        game['game_id'],
        game['gameId'],
      ]),
      name: _firstResultText([
        payload['game_name'],
        payload['gameName'],
        payload['draw_label'],
        payload['drawLabel'],
        payload['name'],
        game['name'],
        game['game_name'],
        game['gameName'],
        game['draw_label'],
        game['drawLabel'],
      ]),
      status: isPublished ? 'published' : resultStatus,
      resultStatus: resultStatus,
      officialStatus: officialStatus,
      completionPercent: double.tryParse(completionText) ?? 0,
      drawAt: _firstResultValue([
        payload['draw_at'],
        payload['drawAt'],
        payload['draw_date'],
        payload['drawDate'],
        game['draw_at'],
        game['drawAt'],
        game['draw_date'],
        game['drawDate'],
      ]),
      rewards: grouped.values.toList(growable: false),
    );
  }

  final String id;
  final String name;
  final String status;
  final String resultStatus;
  final String officialStatus;
  final double completionPercent;
  final Object? drawAt;
  final List<RewardValue> rewards;

  bool get isPublished {
    if (officialStatus.isNotEmpty) return officialStatus == 'published';
    return status == 'published' || status == '2';
  }

  bool get isUnofficial => id.isNotEmpty && hasResolvedResult && !isPublished;

  RewardValue? reward(String slug) {
    for (final reward in rewards) {
      if (reward.slug == slug) return reward;
    }
    return null;
  }

  List<String> displayNumbers(String slug, {bool fillMissing = true}) {
    final definition = rewardDefinitions[slug];
    final numbers = (reward(slug)?.numbers ?? const <String>[]).map((number) {
      return displayRewardNumber(number, slug);
    }).toList();

    if (fillMissing && definition != null) {
      while (numbers.length < definition.count) {
        numbers.add(rewardPlaceholder(slug));
      }
    }

    return numbers;
  }

  RewardSummary get summary {
    return RewardSummary(
      first: displayNumbers('reward_1').firstOrNull ?? '-',
      front3: displayNumbers('reward_three_digit_1'),
      last2: displayNumbers('reward_two_digit').firstOrNull ?? '-',
      last3: displayNumbers('reward_three_digit_2'),
    );
  }

  bool get hasResolvedResult {
    final values = [
      summary.first,
      summary.last2,
      ...summary.front3,
      ...summary.last3,
    ];
    return values.any(isResolvedRewardNumber);
  }

  List<RewardGroup> get groups {
    return rewardOrder
        .map(
          (slug) => RewardGroup(
            slug: slug,
            title: reward(slug)?.title ?? '',
            amount: reward(slug)?.amount ??
                (rewardDefinitions[slug]?.amount ?? 0).toDouble(),
            numbers: displayNumbers(slug),
          ),
        )
        .where((group) => group.numbers.isNotEmpty)
        .toList(growable: false);
  }

  String drawDateText(String localeTag) {
    final parsed = parseDateTime(drawAt);
    if (parsed != null) return formatLocalizedDateTime(parsed, localeTag);
    return name;
  }
}

class RewardValue {
  const RewardValue({
    required this.slug,
    required this.title,
    required this.amount,
    required this.numbers,
  });

  final String slug;
  final String title;
  final double amount;
  final List<String> numbers;

  RewardValue copyWith({List<String>? numbers}) {
    return RewardValue(
      slug: slug,
      title: title,
      amount: amount,
      numbers: numbers ?? this.numbers,
    );
  }
}

class RewardSummary {
  const RewardSummary({
    required this.first,
    required this.front3,
    required this.last2,
    required this.last3,
  });

  final String first;
  final List<String> front3;
  final String last2;
  final List<String> last3;
}

class RewardGroup {
  const RewardGroup({
    required this.slug,
    required this.title,
    required this.amount,
    required this.numbers,
  });

  final String slug;
  final String title;
  final double amount;
  final List<String> numbers;
}

String rewardTypeToSlug(Object? value) {
  final normalized =
      _resultScalarText(value).toLowerCase().replaceAll(RegExp(r'[\s-]+'), '_');
  return switch (normalized) {
    'first' || 'first_prize' || 'reward_1' => 'reward_1',
    'two_digit' ||
    'last_2' ||
    'last2' ||
    'back2' ||
    'back_2' ||
    'reward_two_digit' =>
      'reward_two_digit',
    'front3' ||
    'front_3' ||
    'front_three' ||
    'reward_three_digit_1' =>
      'reward_three_digit_1',
    'back3' ||
    'back_3' ||
    'last3' ||
    'last_3' ||
    'back_three' ||
    'reward_three_digit_2' =>
      'reward_three_digit_2',
    'beside_first' ||
    'near_first_prize' ||
    'reward_beside_1' =>
      'reward_beside_1',
    'second' || 'second_prize' || 'reward_2' => 'reward_2',
    'third' || 'third_prize' || 'reward_3' => 'reward_3',
    'fourth' || 'fourth_prize' || 'reward_4' => 'reward_4',
    'fifth' || 'fifth_prize' || 'reward_5' => 'reward_5',
    _ => normalized,
  };
}

String rewardPlaceholder(String slug) {
  final digits = rewardDefinitions[slug]?.digits ?? 6;
  return 'x' * digits;
}

Map<String, dynamic> _rewardResultPayload(
  Map<String, dynamic> json, [
  int depth = 0,
]) {
  if (depth >= 6) return json;

  for (final key in const [
    'reward_result',
    'rewardResult',
    'result_summary',
    'resultSummary',
    'reward_summary',
    'rewardSummary',
    'summary',
    'result',
    'resource',
    'data',
  ]) {
    final nested = asMap(json[key]);
    if (nested.isEmpty) continue;
    return _mergeRewardResultWrapper(
      json,
      _rewardResultPayload(nested, depth + 1),
    );
  }

  return json;
}

Map<String, dynamic> _mergeRewardResultWrapper(
  Map<String, dynamic> wrapper,
  Map<String, dynamic> nested,
) {
  final merged = Map<String, dynamic>.from(wrapper);
  for (final key in const [
    'reward_result',
    'rewardResult',
    'result_summary',
    'resultSummary',
    'reward_summary',
    'rewardSummary',
    'summary',
    'result',
    'resource',
    'data',
  ]) {
    merged.remove(key);
  }
  merged.addAll(nested);
  return merged;
}

List<Map<String, dynamic>> _rewardPrizeRows(
  Map<String, dynamic> payload, [
  int depth = 0,
]) {
  for (final key in const [
    'prizes',
    'rewards',
    'reward_items',
    'rewardItems',
    'prize_items',
    'prizeItems',
    'items',
    'rows',
  ]) {
    final rows = asMapList(payload[key]);
    if (rows.isNotEmpty) return rows;
  }
  if (depth >= 5) return const [];

  for (final key in const [
    'reward_result',
    'rewardResult',
    'result',
    'resource',
    'data',
  ]) {
    final nested = asMap(payload[key]);
    if (nested.isEmpty) continue;
    final rows = _rewardPrizeRows(nested, depth + 1);
    if (rows.isNotEmpty) return rows;
  }
  return const [];
}

List<String> _rewardPrizeNumbers(Map<String, dynamic> prize) {
  for (final key in const [
    'prize_numbers',
    'prizeNumbers',
    'winning_numbers',
    'winningNumbers',
    'numbers',
    'values',
  ]) {
    final values = prize[key];
    if (values is! Iterable || values is String) continue;
    final numbers = values
        .map(_resultScalarText)
        .where((number) => number.isNotEmpty)
        .toList(growable: false);
    if (numbers.isNotEmpty) return numbers;
  }

  final number = _firstResultText([
    prize['prize_number'],
    prize['prizeNumber'],
    prize['winning_number'],
    prize['winningNumber'],
    prize['number'],
    prize['value'],
  ]);
  return number.isEmpty ? const [] : [number];
}

Map<String, dynamic> _firstResultMap(Iterable<Object?> values) {
  for (final value in values) {
    final map = asMap(value);
    if (map.isNotEmpty) return map;
  }
  return const <String, dynamic>{};
}

String _firstResultText(Iterable<Object?> values) {
  for (final value in values) {
    final text = _resultScalarText(value);
    if (text.isNotEmpty) return text;
  }
  return '';
}

Object? _firstResultValue(Iterable<Object?> values) {
  for (final value in values) {
    final scalar = _resultScalarValue(value);
    if (scalar != null && _resultScalarText(scalar).isNotEmpty) return scalar;
  }
  return null;
}

Object? _firstPresentResultValue(Iterable<Object?> values) {
  for (final value in values) {
    if (value == null) continue;
    if (value is String && value.trim().isEmpty) continue;
    return value;
  }
  return null;
}

String _resultScalarText(Object? value, [int depth = 0]) {
  final scalar = _resultScalarValue(value, depth);
  if (scalar == null) return '';
  final text = scalar.toString().trim();
  if (text.isEmpty ||
      text.toLowerCase() == 'null' ||
      text.toLowerCase() == 'undefined') {
    return '';
  }
  return text;
}

Object? _resultScalarValue(Object? value, [int depth = 0]) {
  if (value == null || depth > 5) return null;
  if (value is Map) {
    for (final key in const [
      'value',
      'raw_value',
      'rawValue',
      'number',
      'amount',
      'percent',
      'percentage',
      'date',
      'datetime',
      'timestamp',
      'iso',
      'code',
      'key',
      'id',
      'uuid',
      'name',
      'label',
      'text',
    ]) {
      final nested = _resultScalarValue(value[key], depth + 1);
      if (nested != null && _resultScalarText(nested, depth + 1).isNotEmpty) {
        return nested;
      }
    }
    return null;
  }
  if (value is Iterable && value is! String) {
    for (final item in value) {
      final nested = _resultScalarValue(item, depth + 1);
      if (nested != null && _resultScalarText(nested, depth + 1).isNotEmpty) {
        return nested;
      }
    }
    return null;
  }
  return value;
}

bool isDisplayableRewardNumber(Object? number) {
  final value = number?.toString().trim() ?? '';
  return value.isNotEmpty && value != '-' && !value.startsWith('pending_');
}

bool isResolvedRewardNumber(Object? number) {
  final value = number?.toString().trim() ?? '';
  return isDisplayableRewardNumber(value) &&
      !RegExp(r'^x+$', caseSensitive: false).hasMatch(value);
}

String displayRewardNumber(Object? value, String slug) {
  final normalized = value?.toString().trim() ?? '';
  if (!isDisplayableRewardNumber(normalized) ||
      RegExp(r'^x+$', caseSensitive: false).hasMatch(normalized)) {
    return rewardPlaceholder(slug);
  }
  return normalized;
}
