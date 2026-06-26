import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import 'ticket_models.dart';

final ticketRepositoryProvider = Provider<TicketRepository>((ref) {
  return TicketRepository(ref.watch(apiClientProvider));
});

final currentTicketsProvider = FutureProvider<List<CustomerTicket>>((
  ref,
) async {
  return ref
      .watch(ticketRepositoryProvider)
      .current()
      .then((page) => page.items);
});

final ticketDetailProvider =
    FutureProvider.autoDispose.family<CustomerTicket, String>((ref, id) async {
  return ref.watch(ticketRepositoryProvider).detail(id);
});

class TicketRepository {
  const TicketRepository(this._api);

  final ApiClient _api;

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
    return CustomerTicket.fromJson(unwrapPayload(response.data));
  }

  Future<TicketRewardStatus> rewardStatus(String id) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/tickets/$id/reward-status',
    );
    return TicketRewardStatus.fromJson(unwrapPayload(response.data));
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
        if (pin.isNotEmpty) 'pin': pin,
        if (pinAssertionToken.isNotEmpty)
          'pin_assertion_token': pinAssertionToken,
        if (bankAccount != null) 'bank_account': bankAccount,
      },
    );
    return RewardClaimSubmission.fromJson(unwrapPayload(response.data));
  }
}
