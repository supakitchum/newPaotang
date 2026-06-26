import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final customerPresenceControllerProvider =
    ChangeNotifierProvider<CustomerPresenceController>((_) {
  return CustomerPresenceController();
});

class CustomerPresenceController extends ChangeNotifier {
  int _onlineCount = 0;

  int get onlineCount => _onlineCount;

  void setOnlineCount(int value) {
    final normalized = value < 0 ? 0 : value;
    if (_onlineCount == normalized) return;
    _onlineCount = normalized;
    notifyListeners();
  }
}
