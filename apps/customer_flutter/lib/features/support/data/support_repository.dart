import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/i18n/customer_locale_controller.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/network/api_client.dart';
import '../../../core/realtime/customer_realtime_client.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/idempotency_key.dart';
import 'support_models.dart';

final supportRepositoryProvider = Provider<SupportRepository>((ref) {
  return SupportRepository(
    ref.watch(apiClientProvider),
    localeResolver: () => localeTag(ref.read(customerLocaleProvider)),
  );
});

final supportUnreadCountProvider = FutureProvider<int>((ref) async {
  return ref.watch(supportRepositoryProvider).unreadCount();
});

class SupportRepository {
  SupportRepository(this._platform, {required this.localeResolver});

  final ApiClient _platform;
  final String Function() localeResolver;
  _SupportSession? _session;

  Future<SupportBootstrap> bootstrap() async {
    final json = await _get('/customer/bootstrap');
    return SupportBootstrap.fromJson(json);
  }

  Future<List<SupportFaq>> faqs({
    String query = '',
    String categoryId = '',
  }) async {
    final json = await _get(
      '/customer/faqs',
      query: {
        if (query.trim().isNotEmpty) 'q': query.trim(),
        if (categoryId.trim().isNotEmpty) 'category_id': categoryId.trim(),
      },
    );
    return _list(json['data']).map(SupportFaq.fromJson).toList(growable: false);
  }

  Future<int> unreadCount() async {
    final json = await _get('/customer/unread-count');
    return (json['unread_count'] as num?)?.toInt() ?? 0;
  }

  Future<SupportRealtimeBinding?> realtimeBinding(String ticketId) async {
    final session = await _supportSession();
    if (!session.realtimeConfig.configured) return null;
    final channels = <String>{
      ...session.realtimeChannels,
      if (session.channelPrefix.isNotEmpty && ticketId.trim().isNotEmpty)
        '${session.channelPrefix}.ticket.${ticketId.trim()}',
    };
    if (channels.isEmpty) return null;
    return SupportRealtimeBinding(
      client: CustomerRealtimeClient(
        config: session.realtimeConfig,
        api: _platform,
        authorizer: authorizeRealtime,
      ),
      channels: channels,
    );
  }

  Future<Map<String, dynamic>> authorizeRealtime(
    String socketId,
    String channel,
  ) {
    return _post(
      '/customer/realtime/auth',
      data: {'socket_id': socketId, 'channel_name': channel},
    );
  }

  Future<void> submitFaqFeedback(String faqId, {required bool helpful}) async {
    await _post(
      '/customer/faqs/$faqId/feedback',
      data: {'helpful': helpful},
      idempotencyKey: newIdempotencyKey('support-faq-feedback'),
    );
  }

  Future<SupportTicketPage> tickets({
    required bool closed,
    String? cursor,
  }) async {
    final json = await _get(
      '/customer/tickets',
      query: {
        'status': closed ? 'closed' : 'active',
        if (cursor != null && cursor.isNotEmpty) 'cursor': cursor,
      },
    );
    return SupportTicketPage(
      items: _list(
        json['data'],
      ).map(SupportTicket.fromJson).toList(growable: false),
      nextCursor: _nullableString(json['next_cursor']),
    );
  }

  Future<SupportTicket> ticket(String id) async {
    final json = await _get('/customer/tickets/$id');
    return SupportTicket.fromJson(_map(json['ticket']));
  }

  Future<SupportTicket> createTicket({
    required String categoryId,
    required String subject,
    required String message,
    String? referencedTicketId,
    List<XFile> attachments = const [],
    String? idempotencyKey,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      if (categoryId.isNotEmpty) 'category_id': categoryId,
      'subject': subject,
      'message': message,
      if (referencedTicketId?.isNotEmpty == true)
        'referenced_ticket_id': referencedTicketId,
      if (attachments.isNotEmpty)
        'attachments[]': await Future.wait(attachments.map(_multipartFile)),
    });
    final json = await _post(
      '/customer/tickets',
      data: form,
      idempotencyKey: idempotencyKey ?? newIdempotencyKey('support-ticket'),
      onSendProgress: onSendProgress,
    );
    return SupportTicket.fromJson(_map(json['ticket']));
  }

  Future<SupportMessagePage> messages(
    String ticketId, {
    int? beforeSequence,
  }) async {
    final json = await _get(
      '/customer/tickets/$ticketId/messages',
      query: {if (beforeSequence != null) 'before_sequence': beforeSequence},
    );
    return SupportMessagePage(
      items: _list(
        json['data'],
      ).map(SupportMessage.fromJson).toList(growable: false),
      nextBeforeSequence: (json['next_before_sequence'] as num?)?.toInt(),
    );
  }

  Future<SupportMessage> sendMessage(
    String ticketId, {
    required String body,
    List<XFile> attachments = const [],
    String? idempotencyKey,
    ProgressCallback? onSendProgress,
  }) async {
    final form = FormData.fromMap({
      if (body.trim().isNotEmpty) 'body': body.trim(),
      if (attachments.isNotEmpty)
        'attachments[]': await Future.wait(attachments.map(_multipartFile)),
    });
    final json = await _post(
      '/customer/tickets/$ticketId/messages',
      data: form,
      idempotencyKey: idempotencyKey ?? newIdempotencyKey('support-message'),
      onSendProgress: onSendProgress,
    );
    return SupportMessage.fromJson(_map(json['message']));
  }

  Future<void> markRead(String ticketId, int sequence) async {
    await _post(
      '/customer/tickets/$ticketId/read',
      data: {'sequence': sequence},
    );
  }

  Future<SupportTicket> close(
    String ticketId, {
    String reason = '',
    String? idempotencyKey,
  }) async {
    final json = await _post(
      '/customer/tickets/$ticketId/close',
      data: {if (reason.trim().isNotEmpty) 'reason': reason.trim()},
      idempotencyKey: idempotencyKey ?? newIdempotencyKey('support-close'),
    );
    return SupportTicket.fromJson(_map(json['ticket']));
  }

  Future<SupportRating> rate(
    String ticketId, {
    required int stars,
    String comment = '',
    String? idempotencyKey,
  }) async {
    final json = await _post(
      '/customer/tickets/$ticketId/rating',
      data: {
        'stars': stars,
        if (comment.trim().isNotEmpty) 'comment': comment.trim(),
      },
      idempotencyKey: idempotencyKey ?? newIdempotencyKey('support-rating'),
    );
    return SupportRating.fromJson(_map(json['rating']));
  }

  Future<Map<String, dynamic>> _get(
    String path, {
    Map<String, dynamic>? query,
  }) async {
    return _request(
      (dio) => dio.get<Map<String, dynamic>>(
        _path(path),
        queryParameters: query,
        options: Options(headers: _headers()),
      ),
    );
  }

  Future<Map<String, dynamic>> _post(
    String path, {
    Object? data,
    String? idempotencyKey,
    ProgressCallback? onSendProgress,
  }) async {
    final resolvedIdempotencyKey =
        idempotencyKey ?? newIdempotencyKey('support-write');
    return _request(
      (dio) => dio.post<Map<String, dynamic>>(
        _path(path),
        data: data,
        onSendProgress: onSendProgress,
        options: Options(
          headers: {..._headers(), 'Idempotency-Key': resolvedIdempotencyKey},
        ),
      ),
    );
  }

  Future<Map<String, dynamic>> _request(
    Future<Response<Map<String, dynamic>>> Function(Dio dio) call,
  ) async {
    var session = await _supportSession();
    try {
      final response = await call(session.dio);
      return response.data ?? const {};
    } on DioException catch (error) {
      if (error.response?.statusCode != 401) rethrow;
      _session = null;
      session = await _supportSession();
      final response = await call(session.dio);
      return response.data ?? const {};
    }
  }

  Future<_SupportSession> _supportSession() async {
    final current = _session;
    if (current != null &&
        current.expiresAt.isAfter(
          DateTime.now().add(const Duration(seconds: 30)),
        )) {
      return current;
    }
    final response = await _platform.post<Map<String, dynamic>>(
      '/customer/support-session',
    );
    final json = response.data ?? const {};
    final apiUrl = '${json['api_url'] ?? ''}'.trim();
    final token = '${json['token'] ?? ''}'.trim();
    final realtime = _map(json['realtime']);
    final realtimeUrl = '${realtime['url'] ?? ''}'.trim();
    final realtimeKey = '${realtime['key'] ?? ''}'.trim();
    final realtimeChannels = _listOfStrings(realtime['channels']);
    if (apiUrl.isEmpty || token.isEmpty) {
      throw StateError('Support session configuration is incomplete.');
    }
    final dio = Dio(
      BaseOptions(
        baseUrl: apiUrl.endsWith('/') ? apiUrl : '$apiUrl/',
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
      ),
    );
    _session = _SupportSession(
      dio: dio,
      token: token,
      expiresAt:
          DateTime.tryParse('${json['expires_at'] ?? ''}')?.toLocal() ??
          DateTime.now().add(const Duration(minutes: 5)),
      realtimeConfig: MobileRealtimeConfig.fromJson({
        ...realtime,
        'enabled': realtimeUrl.isNotEmpty && realtimeKey.isNotEmpty,
        'client': 'customer-support-flutter',
      }),
      channelPrefix: '${realtime['channel_prefix'] ?? ''}'.trim(),
      realtimeChannels: realtimeChannels,
    );
    return _session!;
  }

  Map<String, String> _headers() {
    return {
      'Authorization': 'Bearer ${_session?.token ?? ''}',
      'Accept': 'application/json',
      'Accept-Language': localeResolver(),
    };
  }

  String _path(String value) =>
      value.startsWith('/') ? value.substring(1) : value;

  Future<MultipartFile> _multipartFile(XFile file) async {
    return MultipartFile.fromBytes(
      await file.readAsBytes(),
      filename: file.name,
    );
  }

  static Map<String, dynamic> _map(Object? value) {
    return value is Map ? Map<String, dynamic>.from(value) : const {};
  }

  static List<Map<String, dynamic>> _list(Object? value) {
    return value is List
        ? value
              .whereType<Map>()
              .map((item) => Map<String, dynamic>.from(item))
              .toList(growable: false)
        : const [];
  }

  static String? _nullableString(Object? value) {
    final text = '$value'.trim();
    return text.isEmpty || text == 'null' ? null : text;
  }

  static Set<String> _listOfStrings(Object? value) {
    return value is List
        ? value
              .map((item) => '$item'.trim())
              .where((item) => item.isNotEmpty)
              .toSet()
        : <String>{};
  }
}

class _SupportSession {
  const _SupportSession({
    required this.dio,
    required this.token,
    required this.expiresAt,
    required this.realtimeConfig,
    required this.channelPrefix,
    required this.realtimeChannels,
  });

  final Dio dio;
  final String token;
  final DateTime expiresAt;
  final MobileRealtimeConfig realtimeConfig;
  final String channelPrefix;
  final Set<String> realtimeChannels;
}

class SupportRealtimeBinding {
  const SupportRealtimeBinding({required this.client, required this.channels});

  final CustomerRealtimeClient client;
  final Set<String> channels;
}
