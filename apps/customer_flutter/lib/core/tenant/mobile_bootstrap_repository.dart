import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';

final mobileBootstrapRepositoryProvider = Provider<MobileBootstrapRepository>((
  ref,
) {
  return MobileBootstrapRepository(ref.watch(apiClientProvider));
});

class MobileBootstrapRepository {
  const MobileBootstrapRepository(this._api);

  final ApiClient _api;

  Future<Map<String, dynamic>> load() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/mobile/bootstrap',
      auth: false,
    );

    return Map<String, dynamic>.from(response.data?['data'] ?? {});
  }
}
