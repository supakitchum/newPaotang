import 'dart:math';

String newIdempotencyKey(
  String prefix, {
  Random Function()? secureRandomFactory,
}) {
  final random = _idempotencyRandomHex(secureRandomFactory);
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$random';
}

String _idempotencyRandomHex(Random Function()? secureRandomFactory) {
  try {
    final secureRandom = (secureRandomFactory ?? Random.secure)();
    return _randomHex(secureRandom);
  } catch (_) {
    final fallback = Random();
    final timePart = DateTime.now().microsecondsSinceEpoch.toRadixString(16);
    final randomPart = _randomHex(fallback);
    return '$timePart$randomPart';
  }
}

String _randomHex(Random random) {
  final parts = List.generate(
    4,
    (_) => random.nextInt(0x10000).toRadixString(16).padLeft(4, '0'),
  );
  return parts.join();
}
