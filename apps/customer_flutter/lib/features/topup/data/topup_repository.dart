import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/network/api_client.dart';
import '../../../core/utils/api_payload.dart';
import '../../../core/utils/idempotency_key.dart';
import 'topup_models.dart';

final topupRepositoryProvider = Provider<TopupRepository>((ref) {
  return TopupRepository(ref.watch(apiClientProvider));
});

final topupOverviewProvider = FutureProvider.autoDispose<TopupOverview>((
  ref,
) async {
  return ref.watch(topupRepositoryProvider).overview();
});

final topupHistoryProvider =
    FutureProvider.autoDispose.family<TopupOverview, int>((ref, page) async {
  return ref.watch(topupRepositoryProvider).overview(page: page, perPage: 8);
});

class TopupRepository {
  const TopupRepository(this._api);

  final ApiClient _api;

  Future<TopupOverview> overview({int page = 1, int perPage = 20}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/customer/topups',
      query: {'page': page, 'per_page': perPage},
    );
    return TopupOverview.fromJson(unwrapPayload(response.data));
  }

  Future<TopupRequestItem> create({
    required TopupChannel channel,
    required double amount,
    DateTime? transferAt,
    TopupSlipUpload? slip,
  }) async {
    final headers = {'Idempotency-Key': newIdempotencyKey('customer_topup')};
    if (slip != null) {
      final response = await _api.postMultipart<Map<String, dynamic>>(
        '/customer/topups',
        headers: headers,
        data: FormData.fromMap({
          'channel': channel.apiValue,
          'amount': _amountToMinor(amount),
          if (transferAt != null) 'transfer_at': transferAt.toIso8601String(),
          'slip': MultipartFile.fromBytes(
            slip.bytes,
            filename: slip.filename,
          ),
        }),
      );
      return TopupRequestItem.fromJson(unwrapPayload(response.data));
    }

    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/topups',
      headers: headers,
      data: {
        'channel': channel.apiValue,
        'amount': _amountToMinor(amount),
        if (transferAt != null) 'transfer_at': transferAt.toIso8601String(),
      },
    );
    return TopupRequestItem.fromJson(unwrapPayload(response.data));
  }

  Future<TopupRequestItem> createCredit({required double amount}) async {
    final response = await _api.postWithHeaders<Map<String, dynamic>>(
      '/customer/topups/credit',
      headers: {'Idempotency-Key': newIdempotencyKey('customer_credit_topup')},
      data: {'amount': _amountToMinor(amount)},
    );
    return TopupRequestItem.fromJson(unwrapPayload(response.data));
  }

  Future<TopupRequestItem> cancel(String id) async {
    final response = await _api.deleteWithHeaders<Map<String, dynamic>>(
      '/customer/topups/$id',
      headers: {'Idempotency-Key': newIdempotencyKey('customer_topup_cancel')},
    );
    return TopupRequestItem.fromJson(unwrapPayload(response.data));
  }

  Future<TopupRequestItem> uploadSlip({
    required String id,
    required TopupSlipUpload slip,
    DateTime? transferAt,
  }) async {
    final response = await _api.postMultipart<Map<String, dynamic>>(
      '/customer/topups/$id/slip',
      headers: {'Idempotency-Key': newIdempotencyKey('customer_topup_slip')},
      data: FormData.fromMap({
        'slip': MultipartFile.fromBytes(
          slip.bytes,
          filename: slip.filename,
        ),
        if (transferAt != null) 'transfer_at': transferAt.toIso8601String(),
      }),
    );
    return TopupRequestItem.fromJson(unwrapPayload(response.data));
  }

  int _amountToMinor(double amount) => (amount * 100).round();
}

class TopupSlipUpload {
  const TopupSlipUpload({required this.filename, required this.bytes});

  final String filename;
  final Uint8List bytes;

  int get sizeInBytes => bytes.lengthInBytes;
}
