import 'dart:math';

String newIdempotencyKey(String prefix) {
  final random = Random.secure().nextInt(1 << 32).toRadixString(16);
  return '${prefix}_${DateTime.now().microsecondsSinceEpoch}_$random';
}
