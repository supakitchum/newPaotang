import 'package:flutter_riverpod/flutter_riverpod.dart';

/// OAuth codes must stay in memory while the customer unlocks the app.
/// Putting this route in the PIN redirect URL would expose the code and state.
final pendingSocialCallbackProvider = StateProvider<PendingSocialCallback?>(
  (ref) => null,
);

class PendingSocialCallback {
  PendingSocialCallback(this.location) : receivedAt = DateTime.now();

  final String location;
  final DateTime receivedAt;

  bool get isExpired =>
      DateTime.now().difference(receivedAt) >= const Duration(minutes: 10);
}

bool isSocialCallbackPath(String path) {
  if (path == '/line/callback') return true;
  final parts = Uri(path: path).pathSegments;
  return parts.length == 3 &&
      parts.first == 'social' &&
      parts[1].isNotEmpty &&
      parts.last == 'callback';
}
