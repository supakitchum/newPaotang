import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_errors.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/provider_cache.dart';
import 'result_models.dart';

final resultRepositoryProvider = Provider<ResultRepository>((ref) {
  return ResultRepository(ref.watch(apiClientProvider));
});

final currentResultProvider = FutureProvider.autoDispose<RewardResultBundle>((
  ref,
) async {
  ref.keepForCustomerNavigation();
  return ref.watch(resultRepositoryProvider).current();
});

final resultDetailProvider = FutureProvider.autoDispose
    .family<RewardResultBundle, String?>((ref, id) {
      ref.keepForCustomerNavigation();
      return ref.watch(resultRepositoryProvider).current(gameId: id);
    });

final legacyResultProvider = FutureProvider.autoDispose<RewardResultBundle>((
  ref,
) async {
  ref.keepForCustomerNavigation();
  return ref.watch(resultRepositoryProvider).legacy();
});

final publishedResultDetailProvider = FutureProvider.autoDispose
    .family<RewardResultBundle, String?>((ref, id) {
      ref.keepForCustomerNavigation();
      return ref.watch(resultRepositoryProvider).published(gameId: id);
    });

class ResultRepository {
  const ResultRepository(this._api);

  final ApiClient _api;

  Future<CurrentGame?> currentGame() async {
    try {
      return await _loadCurrentGame();
    } catch (error) {
      if (_isOperationalResultError(error)) rethrow;
      return null;
    }
  }

  Future<RewardResultGame?> latest({String? gameId, bool live = true}) async {
    try {
      return await _loadResult(gameId: gameId, live: live);
    } catch (error) {
      if (_isMissingResultError(error)) return null;
      rethrow;
    }
  }

  Future<RewardResultBundle> current({String? gameId}) async {
    final game = await _currentGameForResults();
    final requestedGameId = gameId?.trim() ?? '';
    final targetGameId = requestedGameId.isNotEmpty
        ? requestedGameId
        : game?.id.trim();
    final live = await _attemptResult(gameId: targetGameId, live: true);
    final published = live.value == null
        ? await _attemptResult(gameId: targetGameId, live: false)
        : const _ResultAttempt();
    final selected = live.value ?? published.value;
    final primaryError = published.error ?? live.error;
    if (selected == null && primaryError != null) throw primaryError;

    final effectiveSelected = selected ?? game?.toPendingRewardGame();
    final history = await _publishedHistory(
      excludeGameId: effectiveSelected?.id ?? targetGameId,
    );

    return RewardResultBundle(
      currentGame: game,
      selectedResult: effectiveSelected,
      history: history,
    );
  }

  Future<RewardResultBundle> legacy() async {
    final live = await _attemptResult(live: true);
    final published = live.value == null
        ? await _attemptResult(live: false)
        : const _ResultAttempt();
    final selected = live.value ?? published.value;
    final error = published.error ?? live.error;
    if (selected == null && error != null) throw error;

    final history = await _publishedHistory(excludeGameId: selected?.id);

    return RewardResultBundle(
      currentGame: null,
      selectedResult: selected,
      history: history,
    );
  }

  Future<RewardResultBundle> published({String? gameId}) async {
    final result = await latest(gameId: gameId, live: false);
    return RewardResultBundle(
      currentGame: null,
      selectedResult: result,
      history: const [],
    );
  }

  Future<CurrentGame?> _currentGameForResults() async {
    try {
      return await _loadCurrentGame();
    } catch (error) {
      if (_isMissingResultError(error)) return null;
      rethrow;
    }
  }

  Future<CurrentGame> _loadCurrentGame() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/public/games/current',
      auth: false,
    );
    return CurrentGame.fromJson(unwrapPayload(response.data));
  }

  Future<RewardResultGame> _loadResult({
    String? gameId,
    required bool live,
  }) async {
    final normalizedGameId = gameId?.trim() ?? '';
    final encodedGameId = Uri.encodeComponent(normalizedGameId);
    final endpoint = live
        ? (normalizedGameId.isEmpty
              ? '/public/results/live/latest'
              : '/public/results/live/$encodedGameId')
        : (normalizedGameId.isEmpty
              ? '/public/results/latest'
              : '/public/results/$encodedGameId');
    final response = await _api.get<Map<String, dynamic>>(
      endpoint,
      auth: false,
    );
    return RewardResultGame.fromPublicSummary(unwrapPayload(response.data));
  }

  Future<List<RewardResultGame>> _publishedHistory({
    String? excludeGameId,
    int limit = 3,
  }) async {
    final normalizedExcludeGameId = excludeGameId?.trim() ?? '';
    try {
      final response = await _api.get<Map<String, dynamic>>(
        '/public/results/history',
        query: {
          'limit': limit,
          if (normalizedExcludeGameId.isNotEmpty)
            'exclude_game_id': normalizedExcludeGameId,
        },
        auth: false,
      );
      return unwrapDataList(response.data)
          .map(RewardResultGame.fromPublicSummary)
          .where((result) => result.id != normalizedExcludeGameId)
          .take(limit)
          .toList(growable: false);
    } catch (error) {
      if (_isOperationalResultError(error)) rethrow;
    }

    final fallback = await _attemptResult(live: false);
    final result = fallback.value;
    if (result == null || result.id == normalizedExcludeGameId) {
      return const [];
    }
    return [result];
  }

  Future<_ResultAttempt> _attemptResult({
    String? gameId,
    required bool live,
  }) async {
    try {
      return _ResultAttempt(
        value: await _loadResult(gameId: gameId, live: live),
      );
    } catch (error) {
      if (_isMissingResultError(error)) return const _ResultAttempt();
      if (_isOperationalResultError(error)) rethrow;
      return _ResultAttempt(error: error);
    }
  }
}

bool _isMissingResultError(Object error) {
  return ApiErrorInfo.fromObject(error).statusCode == 404;
}

bool _isOperationalResultError(Object error) {
  return ApiErrorInfo.fromObject(error).operationalRedirectPath != null;
}

class _ResultAttempt {
  const _ResultAttempt({this.value, this.error});

  final RewardResultGame? value;
  final Object? error;
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
