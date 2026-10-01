import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';

final publicVisitRepositoryProvider = Provider<PublicVisitRepository>((ref) {
  return PublicVisitRepository(ref.watch(apiClientProvider));
});

class PublicVisitRepository {
  const PublicVisitRepository(this._api);

  final ApiClient _api;

  Future<void> track(PublicVisitPayload payload) async {
    await _api.post<Map<String, dynamic>>(
      '/public/monitor/visit',
      data: payload.toJson(),
    );
  }
}

class PublicVisitPayload {
  const PublicVisitPayload({
    required this.visitorId,
    required this.sessionId,
    required this.source,
    required this.path,
    this.channel,
    this.referrer,
    this.screen,
    this.timezone,
    this.routeName,
  });

  final String visitorId;
  final String sessionId;
  final String source;
  final String path;
  final String? channel;
  final String? referrer;
  final String? screen;
  final String? timezone;
  final String? routeName;

  Map<String, dynamic> toJson() {
    return {
      'visitor_id': visitorId,
      'session_id': sessionId,
      'source': source,
      if (channel != null && channel!.isNotEmpty) 'channel': channel,
      'path': path,
      if (referrer != null && referrer!.isNotEmpty) 'referrer': referrer,
      if (screen != null && screen!.isNotEmpty) 'screen': screen,
      if (timezone != null && timezone!.isNotEmpty) 'timezone': timezone,
      if (routeName != null && routeName!.isNotEmpty) 'route_name': routeName,
    };
  }
}
