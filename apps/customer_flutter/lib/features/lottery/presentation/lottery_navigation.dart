String lotterySearchPath({
  String number = '',
  List<String> digits = const [],
  String storeId = '',
  String storeName = '',
}) {
  final query = <String, String>{};
  final normalizedNumber = _digitsOnly(number, maxLength: 6);
  if (normalizedNumber.isNotEmpty) {
    query['number'] = normalizedNumber;
  } else {
    for (var index = 0; index < 6; index++) {
      final value = index >= digits.length
          ? ''
          : _digitsOnly(digits[index], maxLength: 1);
      if (value.isNotEmpty) query['d${index + 1}'] = value;
    }
  }

  final normalizedStoreId = storeId.trim();
  if (normalizedStoreId.isNotEmpty) {
    query['store_id'] = normalizedStoreId;
    final normalizedStoreName = storeName.trim();
    if (normalizedStoreName.isNotEmpty) {
      query['store_name'] = normalizedStoreName;
    }
  }

  return Uri(
    path: '/buy/search',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

String lotteryStorePath({
  required String storeId,
  String storeName = '',
  String gameId = '',
}) {
  final query = <String, String>{};
  final normalizedStoreId = storeId.trim();
  final normalizedStoreName = storeName.trim();
  final normalizedGameId = gameId.trim();
  if (normalizedStoreId.isNotEmpty) query['store_id'] = normalizedStoreId;
  if (normalizedStoreName.isNotEmpty) query['store_name'] = normalizedStoreName;
  if (normalizedGameId.isNotEmpty) query['game_id'] = normalizedGameId;
  return Uri(
    path: '/stores/lotteries',
    queryParameters: query.isEmpty ? null : query,
  ).toString();
}

String lotteryMorePath({
  required String number,
  String storeId = '',
  String backPath = '',
}) {
  final query = <String, String>{
    'number': _digitsOnly(number, maxLength: 6),
  };
  final normalizedStoreId = storeId.trim();
  if (normalizedStoreId.isNotEmpty) query['store_id'] = normalizedStoreId;
  final normalizedBackPath = safeLotteryBackPath(backPath, fallback: '');
  if (normalizedBackPath.isNotEmpty) query['back'] = normalizedBackPath;

  return Uri(path: '/buy/more', queryParameters: query).toString();
}

bool isExactLotterySearch({
  String number = '',
  List<String> digits = const [],
}) {
  final normalizedNumber = _digitsOnly(number, maxLength: 6);
  if (normalizedNumber.length == 6) return true;
  if (normalizedNumber.isNotEmpty) return false;

  final normalizedDigits = List.generate(6, (index) {
    if (index >= digits.length) return '';
    return _digitsOnly(digits[index], maxLength: 1);
  });
  return normalizedDigits.every((digit) => digit.isNotEmpty);
}

bool shouldPopLotteryMoreBack({
  required bool canPop,
  required String explicitBackPath,
}) {
  if (!canPop) return false;
  return explicitBackPath.trim().isNotEmpty;
}

String safeLotteryBackPath(String value, {String fallback = '/buy'}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return fallback;
  final safeLotteryPath = uri.path == '/buy' ||
      uri.path.startsWith('/buy/') ||
      uri.path == '/stores/lotteries';
  if (!safeLotteryPath) return fallback;
  return uri.toString();
}

String _digitsOnly(String value, {required int maxLength}) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= maxLength) return digits;
  return digits.substring(0, maxLength);
}
