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
    return CurrentGame(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      drawAt: json['draw_at'],
      saleStartAt: json['sale_start_at'] ?? json['sales_start_at'],
      saleCloseAt: json['sale_close_at'] ??
          json['sales_close_at'] ??
          json['close_at'] ??
          json['end_at'] ??
          json['sale_end_at'] ??
          json['sales_end_at'],
      serverTime: json['server_time'],
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
    final grouped = <String, RewardValue>{};
    for (final prize in asMapList(json['prizes'])) {
      final slug = rewardTypeToSlug(prize['prize_type'] ?? prize['slug']);
      final existing = grouped[slug] ??
          RewardValue(
            slug: slug,
            title: prize['name']?.toString() ?? '',
            amount: moneyToDisplayNumber(
              prize['amount'] ?? prize['reward'],
              fallback: (rewardDefinitions[slug]?.amount ?? 0).toDouble(),
            ),
            numbers: const [],
          );
      final number = (prize['prize_number'] ?? prize['number'])?.toString();
      grouped[slug] = existing.copyWith(
        numbers: [
          ...existing.numbers,
          if (number != null && number.trim().isNotEmpty) number.trim(),
        ],
      );
    }

    final resultStatus = json['status']?.toString().toLowerCase() ?? '';
    final officialStatus =
        (json['official_status'] ?? resultStatus).toString().toLowerCase();
    final isPublished =
        officialStatus == 'published' || resultStatus == 'published';

    return RewardResultGame(
      id: json['game_id']?.toString() ?? json['id']?.toString() ?? '',
      name: (json['game_name'] ?? json['draw_label'] ?? json['name'])
              ?.toString() ??
          '',
      status: isPublished ? 'published' : resultStatus,
      resultStatus: resultStatus,
      officialStatus: officialStatus,
      completionPercent:
          double.tryParse((json['completion_percent'] ?? 0).toString()) ?? 0,
      drawAt: json['draw_at'],
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
  return switch (value?.toString()) {
    'first' || 'first_prize' || 'reward_1' => 'reward_1',
    'two_digit' ||
    'last2' ||
    'back2' ||
    'reward_two_digit' =>
      'reward_two_digit',
    'front3' || 'reward_three_digit_1' => 'reward_three_digit_1',
    'back3' || 'last3' || 'reward_three_digit_2' => 'reward_three_digit_2',
    'beside_first' ||
    'near_first_prize' ||
    'reward_beside_1' =>
      'reward_beside_1',
    'second_prize' => 'reward_2',
    'third_prize' => 'reward_3',
    'fourth_prize' => 'reward_4',
    'fifth_prize' => 'reward_5',
    final raw? => raw,
    _ => '',
  };
}

String rewardPlaceholder(String slug) {
  final digits = rewardDefinitions[slug]?.digits ?? 6;
  return 'x' * digits;
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
