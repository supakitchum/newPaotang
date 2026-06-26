import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final screenSecurityServiceProvider = Provider<ScreenSecurityService>(
  (_) => ScreenSecurityService(),
);

class ScreenSecurityEvent {
  const ScreenSecurityEvent({
    required this.event,
    required this.route,
    this.reason,
  });

  final String event;
  final String route;
  final String? reason;
}

class ScreenSecurityService {
  ScreenSecurityService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel =
      MethodChannel('customer_flutter/screen_security');
  final _events = StreamController<ScreenSecurityEvent>.broadcast();

  Stream<ScreenSecurityEvent> get events => _events.stream;

  Future<void> enable({required String route}) async {
    await _invoke('enable', {'route': route});
  }

  Future<void> disable() async {
    await _invoke('disable');
  }

  Future<void> reportSecurityEvent({
    required String event,
    required String route,
    String? reason,
  }) async {
    await _invoke('reportSecurityEvent', {
      'event': event,
      'route': route,
      'reason': reason,
    });
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Web/iOS fallback is intentionally non-fatal while native hooks are added per platform.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'securityEvent') return;
    final arguments = call.arguments;
    if (arguments is! Map) return;
    _events.add(
      ScreenSecurityEvent(
        event: arguments['event']?.toString() ?? 'screen_capture',
        route: arguments['route']?.toString() ?? '',
        reason: arguments['reason']?.toString(),
      ),
    );
  }
}
