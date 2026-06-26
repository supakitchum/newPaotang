import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import 'result_models.dart';

final resultRepositoryProvider = Provider<ResultRepository>((ref) {
  return ResultRepository(ref.watch(apiClientProvider));
});

final currentResultProvider = FutureProvider.autoDispose<RewardResultBundle>((
  ref,
) async {
  return ref.watch(resultRepositoryProvider).current();
});

final resultDetailProvider =
    FutureProvider.autoDispose.family<RewardResultBundle, String?>((ref, id) {
  return ref.watch(resultRepositoryProvider).current(gameId: id);
});

class ResultRepository {
  const ResultRepository(this._api);

  final ApiClient _api;

  Future<CurrentGame?> currentGame() async {
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/public/games/current',
        auth: false,
      );
      return CurrentGame.fromJson(unwrapPayload(response.data));
    } catch (_) {
      return null;
    }
  }

  Future<RewardResultGame?> latest({String? gameId, bool live = true}) async {
    final endpoint = live
        ? (gameId == null || gameId.isEmpty
            ? '/public/results/live/latest'
            : '/public/results/live/$gameId')
        : (gameId == null || gameId.isEmpty
            ? '/public/results/latest'
            : '/public/results/$gameId');

    try {
      final response = await _api.get<Map<String, dynamic>>(
        endpoint,
        auth: false,
      );
      return RewardResultGame.fromPublicSummary(unwrapPayload(response.data));
    } catch (_) {
      return null;
    }
  }

  Future<RewardResultBundle> current({String? gameId}) async {
    final game = await currentGame();
    final targetGameId =
        (gameId != null && gameId.isNotEmpty) ? gameId : game?.id;
    final live = await latest(gameId: targetGameId, live: true);
    final published = live ?? await latest(gameId: targetGameId, live: false);
    final latestPublished = targetGameId == null || targetGameId.isEmpty
        ? null
        : await latest(live: false);

    return RewardResultBundle(
      currentGame: game,
      selectedResult: published ?? game?.toPendingRewardGame(),
      history: [
        if (latestPublished != null &&
            latestPublished.id.isNotEmpty &&
            latestPublished.id != (published?.id ?? targetGameId))
          latestPublished,
      ],
    );
  }
}

class RewardResultBundle {
  const RewardResultBundle({
    required this.currentGame,
    required this.selectedResult,
    required this.history,
  });

  final CurrentGame? currentGame;
  final RewardResultGame? selectedResult;
  final List<RewardResultGame> history;
}
