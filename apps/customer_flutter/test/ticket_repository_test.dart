import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/tickets/data/ticket_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('currentAll loads every current ticket page by cursor', () async {
    final api = _TicketPaginationApiClient([
      {
        'data': [
          {'id': 'ticket_1', 'number': '111111'},
          {'id': 'ticket_2', 'number': '222222'},
        ],
        'meta': {
          'next_cursor': 'cursor_2',
          'has_more': true,
          'total': 3,
        },
      },
      {
        'data': [
          {'id': 'ticket_3', 'number': '333333'},
        ],
        'meta': {
          'next_cursor': null,
          'has_more': false,
          'total': 3,
        },
      },
    ]);
    final repository = TicketRepository(api);

    final tickets = await repository.currentAll(limit: 2);

    expect(tickets.map((ticket) => ticket.id), [
      'ticket_1',
      'ticket_2',
      'ticket_3',
    ]);
    expect(api.paths, ['/customer/tickets', '/customer/tickets']);
    expect(api.queries.first['limit'], 2);
    expect(api.queries.first.containsKey('cursor'), isFalse);
    expect(api.queries.last['cursor'], 'cursor_2');
  });

  test('detail and claim parsers keep wrapper context from repository',
      () async {
    final api = _TicketEnvelopeApiClient();
    final repository = TicketRepository(api);

    final ticket = await repository.detail('ticket_envelope');
    final status = await repository.rewardStatus('ticket_envelope');
    final submission = await repository.createRewardClaim(
      ticketId: 'ticket_envelope',
      payoutMethod: 'wallet_credit',
      pinAssertionToken: 'assertion-token',
    );

    expect(api.paths, [
      '/customer/tickets/ticket_envelope',
      '/customer/tickets/ticket_envelope/reward-status',
      '/customer/reward-claims',
    ]);
    expect(ticket.id, 'ticket_envelope');
    expect(ticket.number, '123456');
    expect(ticket.rewardStatus.claimStatus, 'claim_paid');
    expect(ticket.rewardClaimId, 'rcl_outer_context');
    expect(ticket.prizeAmount, 4000);
    expect(status.claimStatus, 'claim_approved');
    expect(status.rewardClaimId, 'rcl_status_context');
    expect(status.adminNote, 'อนุมัติจาก repository wrapper');
    expect(submission.id, 'rcl_submission_context');
    expect(submission.createdAt, '2026-07-01T12:34:00+07:00');
    expect(api.payload['pin_assertion_token'], 'assertion-token');
  });

  test('createRewardClaim sends PIN confirmation when provided', () async {
    final api = _TicketApiClient();
    final repository = TicketRepository(api);

    await repository.createRewardClaim(
      ticketId: 'ticket_1',
      payoutMethod: 'bank_transfer',
      pin: '123456',
      bankAccount: {'bank_code': 'kbank'},
    );

    expect(api.path, '/customer/reward-claims');
    expect(api.payload['ticket_id'], 'ticket_1');
    expect(api.payload['payout_method'], 'bank_transfer');
    expect(api.payload['pin'], '123456');
    expect(api.payload.containsKey('pin_assertion_token'), isFalse);
    expect(api.payload['bank_account'], {'bank_code': 'kbank'});
  });

  test('createRewardClaim can use biometric assertion token instead of PIN',
      () async {
    final api = _TicketApiClient();
    final repository = TicketRepository(api);

    await repository.createRewardClaim(
      ticketId: 'ticket_1',
      payoutMethod: 'wallet_credit',
      pinAssertionToken: 'assertion-token',
    );

    expect(api.payload.containsKey('pin'), isFalse);
    expect(api.payload['pin_assertion_token'], 'assertion-token');
  });
}

class _TicketPaginationApiClient extends ApiClient {
  _TicketPaginationApiClient(this._responses)
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final List<Map<String, dynamic>> _responses;
  final paths = <String>[];
  final queries = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);
    queries.add(Map<String, dynamic>.from(query ?? const {}));
    final index = paths.length - 1;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _responses[index] as T,
    );
  }
}

class _TicketEnvelopeApiClient extends ApiClient {
  _TicketEnvelopeApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  final paths = <String>[];
  Map<String, dynamic> payload = {};

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    paths.add(path);

    final data = path.endsWith('/reward-status')
        ? {
            'adminNote': 'อนุมัติจาก repository wrapper',
            'data': {
              'resource': {
                'rewardStatus': {
                  'claimStatus': 'claim_approved',
                  'claimId': 'rcl_status_context',
                  'rewardAmount': {'amount': 200000, 'currency': 'THB'},
                },
              },
            },
          }
        : {
            'rewardStatus': {
              'claimStatus': 'claim_paid',
              'rewardClaimId': 'rcl_outer_context',
              'prizes': [
                {
                  'rewardType': 'front3',
                  'rewardNumber': '123',
                  'rewardAmount': {'amount': 400000, 'currency': 'THB'},
                },
              ],
            },
            'data': {
              'resource': {
                'customerTicket': {
                  'ticketId': 'ticket_envelope',
                  'fullNumber': '123456',
                },
              },
            },
          };

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
    );
  }

  @override
  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    paths.add(path);
    payload = Map<String, dynamic>.from(data! as Map);

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'submittedAt': '2026-07-01T12:34:00+07:00',
        'result': {
          'submission': {
            'claimId': 'rcl_submission_context',
            'status': 'submitted',
          },
        },
      } as T,
    );
  }
}

class _TicketApiClient extends ApiClient {
  _TicketApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  String path = '';
  Map<String, dynamic> payload = {};

  @override
  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    this.path = path;
    payload = Map<String, dynamic>.from(data! as Map);

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'data': {
          'id': 'claim_1',
          'status': 'submitted',
          'submitted_at': '2026-06-26T10:00:00+07:00',
        },
      } as T,
    );
  }
}
