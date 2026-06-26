String lotterySearchPath({
  String number = '',
  List<String> digits = const [],
  String storeId = '',
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
  if (normalizedStoreId.isNotEmpty) query['store_id'] = normalizedStoreId;

  return Uri(
    path: '/buy/search',
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

String safeLotteryBackPath(String value, {String fallback = '/buy'}) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return fallback;
  final uri = Uri.tryParse(trimmed);
  if (uri == null || uri.hasScheme || uri.host.isNotEmpty) return fallback;
  if (uri.path != '/buy' && !uri.path.startsWith('/buy/')) return fallback;
  return uri.toString();
}

String _digitsOnly(String value, {required int maxLength}) {
  final digits = value.replaceAll(RegExp(r'\D'), '');
  if (digits.length <= maxLength) return digits;
  return digits.substring(0, maxLength);
}
