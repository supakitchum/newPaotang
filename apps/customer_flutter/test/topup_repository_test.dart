import 'dart:typed_data';

import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:customer_flutter/features/topup/data/topup_models.dart';
import 'package:customer_flutter/features/topup/data/topup_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('create sends JSON when no slip is attached', () async {
    final api = _TopupApiClient();
    final repository = TopupRepository(api);

    final item = await repository.create(channel: TopupChannel.qr, amount: 500);

    expect(api.postPath, '/customer/topups');
    expect(api.postPayload['channel'], 'qr');
    expect(api.postPayload['amount'], 50000);
    expect(api.multipartPath, isEmpty);
    expect(api.postHeaders['Idempotency-Key'], startsWith('customer_topup_'));
    expect(item.id, 'topup_1');
    expect(item.qrCode, 'data:image/png;base64,WRAPPED');
    expect(item.message, 'สแกน QR Code เพื่อชำระเงินรายการนี้');
  });

  test('detail loads a customer topup by id', () async {
    final api = _TopupApiClient();
    final repository = TopupRepository(api);

    final item = await repository.detail('topup_1');

    expect(api.getPath, '/customer/topups/topup_1');
    expect(item.id, 'topup_1');
    expect(item.status, TopupStatus.pendingReview);
    expect(item.qrCode, 'data:image/png;base64,WRAPPED');
  });

  test('QR remaining time follows the absolute provider deadline', () {
    final serverTime = DateTime.now().toUtc();
    final item = TopupRequestItem.fromJson({
      'id': 'topup_active_qr',
      'amount': {'amount': 50000, 'currency': 'THB'},
      'status': 'pending_payment',
      'channel': 'qr',
      'payment_expires_at': serverTime
          .add(const Duration(minutes: 5))
          .toIso8601String(),
      'payment_expires_in_seconds': 0,
      'server_time': serverTime.toIso8601String(),
      'payment': {'qr_code': 'data:image/png;base64,ACTIVE'},
    });

    expect(item.paymentRemainingSeconds, inInclusiveRange(299, 300));
  });

  test('create sends multipart slip for bank transfer request', () async {
    final api = _TopupApiClient();
    final repository = TopupRepository(api);
    final transferAt = DateTime.parse('2026-06-26T10:15:00+07:00');

    await repository.create(
      channel: TopupChannel.bankTransfer,
      amount: 800,
      transferAt: transferAt,
      slip: TopupSlipUpload(
        filename: 'slip.jpg',
        bytes: Uint8List.fromList([1, 2, 3]),
      ),
    );

    final fields = Map<String, String>.fromEntries(api.multipartData!.fields);

    expect(api.multipartPath, '/customer/topups');
    expect(api.postPath, isEmpty);
    expect(fields['channel'], 'bank_transfer');
    expect(fields['amount'], '80000');
    expect(fields['transfer_at'], transferAt.toIso8601String());
    expect(api.multipartData!.files.single.key, 'slip');
    expect(api.multipartData!.files.single.value.filename, 'slip.jpg');
    expect(
      api.multipartHeaders['Idempotency-Key'],
      startsWith('customer_topup_'),
    );
  });

  test(
    'uploadSlip sends multipart slip without implicit transfer time',
    () async {
      final api = _TopupApiClient();
      final repository = TopupRepository(api);

      await repository.uploadSlip(
        id: 'topup_waiting_qr',
        slip: TopupSlipUpload(
          filename: 'qr-slip.webp',
          bytes: Uint8List.fromList([4, 5, 6]),
        ),
      );

      final fields = Map<String, String>.fromEntries(api.multipartData!.fields);

      expect(api.multipartPath, '/customer/topups/topup_waiting_qr/slip');
      expect(fields.containsKey('transfer_at'), isFalse);
      expect(api.multipartData!.files.single.key, 'slip');
      expect(api.multipartData!.files.single.value.filename, 'qr-slip.webp');
      expect(
        api.multipartHeaders['Idempotency-Key'],
        startsWith('customer_topup_slip_'),
      );
    },
  );

  test('uploadSlip forwards explicit transfer time when provided', () async {
    final api = _TopupApiClient();
    final repository = TopupRepository(api);
    final transferAt = DateTime.parse('2026-06-26T12:45:00+07:00');

    await repository.uploadSlip(
      id: 'topup_waiting_qr',
      transferAt: transferAt,
      slip: TopupSlipUpload(
        filename: 'qr-slip.webp',
        bytes: Uint8List.fromList([7, 8, 9]),
      ),
    );

    final fields = Map<String, String>.fromEntries(api.multipartData!.fields);

    expect(fields['transfer_at'], transferAt.toIso8601String());
  });
}

class _TopupApiClient extends ApiClient {
  _TopupApiClient()
    : super(
        const AppConfig(
          apiBaseUrl: 'https://partner.example.test/api/v1',
          defaultLocale: 'th-TH',
        ),
        AuthTokenStore(),
        localeTag: 'th-TH',
      );

  String postPath = '';
  Map<String, dynamic> postPayload = {};
  Map<String, String> postHeaders = {};
  String multipartPath = '';
  FormData? multipartData;
  Map<String, String> multipartHeaders = {};
  String getPath = '';

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    getPath = path;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _topupResponse('qr') as T,
    );
  }

  @override
  Future<Response<T>> postWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    postPath = path;
    postPayload = Map<String, dynamic>.from(data! as Map);
    postHeaders = Map<String, String>.from(headers);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _topupResponse(postPayload['channel']) as T,
    );
  }

  @override
  Future<Response<T>> postMultipart<T>(
    String path, {
    required FormData data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    multipartPath = path;
    multipartData = data;
    multipartHeaders = Map<String, String>.from(headers);
    final fields = Map<String, String>.fromEntries(data.fields);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: _topupResponse(fields['channel']) as T,
    );
  }

  Map<String, dynamic> _topupResponse(Object? channel) {
    return {
      'data': {
        'result': {
          'id': 'topup_1',
          'amount': {'amount': 80000, 'currency': 'THB'},
          'bonus_amount': {'amount': 0, 'currency': 'THB'},
          'status': 'pending_review',
          'channel': channel?.toString() ?? 'qr',
          'provider': '',
          'created_at': '2026-06-26T10:00:00+07:00',
        },
        'qr_code': 'data:image/png;base64,WRAPPED',
        'message': 'สแกน QR Code เพื่อชำระเงินรายการนี้',
      },
    };
  }
}
