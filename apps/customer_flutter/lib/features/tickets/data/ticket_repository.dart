import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_controller.dart';
import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import '../../../core/utils/provider_cache.dart';
import '../../results/data/result_models.dart';
import '../../results/data/result_repository.dart';
import 'ticket_models.dart';

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref.watch(apiClientProvider));
});

final currentTicketsProvider = FutureProvider.autoDispose<List<CustomerTicket>>(
  (ref) async {
    ref.keepForCustomerNavigation();
    final auth = ref.watch(authControllerProvider);
    if (!auth.isAuthenticated || auth.pinRequired || auth.pinSetupRequired) {
      return const [];
    }
    return ref.watch(ticketRepositoryProvider).currentAll();
  },
);

final currentTicketGameProvider = FutureProvider.autoDispose<CurrentGame?>((
  ref,
) async {
  ref.keepForCustomerNavigation();
  final auth = ref.watch(authControllerProvider);
  if (!auth.isAuthenticated || auth.pinRequired || auth.pinSetupRequired) {
    return null;
  }
  return ref.watch(resultRepositoryProvider).currentGame();
});

final ticketDetailProvider = FutureProvider.autoDispose
    .family<CustomerTicket, String>((ref, id) async {
      ref.keepForCustomerNavigation();
      return ref.watch(ticketRepositoryProvider).detail(id);
    });

class TicketRepository {
  const TicketRepository(this._api);

  final ApiClient _api;

  static const int defaultPageLimit = 50;
  static const int maxAutoPages = 20;

  Future<TicketPage> current({int limit = 20, String? cursor}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/tickets',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return TicketPage.fromJson(asMap(response.data));
  }

  Future<List<CustomerTicket>> currentAll({
    int limit = defaultPageLimit,
    int maxPages = maxAutoPages,
  }) async {
    final items = <CustomerTicket>[];
    String? cursor;

    for (var pageNumber = 0; pageNumber < maxPages; pageNumber++) {
      final page = await current(limit: limit, cursor: cursor);
      items.addAll(page.items);

      final nextCursor = page.nextCursor?.trim() ?? '';
      if (!page.hasMore || nextCursor.isEmpty || nextCursor == cursor) {
        break;
      }
      cursor = nextCursor;
    }

    return items;
  }

  Future<TicketPage> history({
    int limit = 20,
    String? cursor,
    String? gameId,
  }) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/tickets/history',
      query: {
        'limit': limit,
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
        if (gameId != null && gameId.isNotEmpty) 'game_id': gameId,
      },
    );
    return TicketPage.fromJson(asMap(response.data));
  }

  Future<CustomerTicket> detail(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/tickets/$id',
    );
    return CustomerTicket.fromJson(asMap(response.data));
  }

  Future<TicketRewardStatus> rewardStatus(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/tickets/$id/reward-status',
    );
    return TicketRewardStatus.fromJson(asMap(response.data));
  }

  Future<RewardClaimSubmission> createRewardClaim({
    required String ticketId,
    required String payoutMethod,
    String pin = '',
    String pinAssertionToken = '',
    Map<String, dynamic>? bankAccount,
  }) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/reward-claims',
      headers: {'Idempotency-Key': newIdempotencyKey('reward_claim')},
      data: {
        'ticket_id': ticketId,
        'payout_method': payoutMethod,
        if (pinAssertionToken.isNotEmpty)
          'pin_assertion_token': pinAssertionToken
        else if (pin.isNotEmpty)
          'pin': pin,
        if (bankAccount != null) 'bank_account': bankAccount,
      },
    );
    return RewardClaimSubmission.fromJson(asMap(response.data));
  }
}
