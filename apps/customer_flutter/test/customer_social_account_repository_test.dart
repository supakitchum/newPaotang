import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/auth/customer_social_account_repository.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'social account management lists and unlinks normalized providers',
    () async {
      final api = _SocialAccountApiClient();
      final repository = CustomerSocialAccountRepository(api: api);

      final accounts = await repository.list();
      final afterUnlink = await repository.unlink('google_oauth2');

      expect(api.requests, [
        'GET /customer/auth/social/accounts',
        'DELETE /customer/auth/social/accounts/google',
      ]);
      expect(accounts, hasLength(4));
      expect(accounts[1].provider, 'google');
      expect(accounts[1].linked, isTrue);
      expect(accounts[1].displayName, 'Ada Google');
      expect(afterUnlink[1].provider, 'google');
      expect(afterUnlink[1].linked, isFalse);
    },
  );
}

class _SocialAccountApiClient extends ApiClient {
  _SocialAccountApiClient()
    : super(
        const AppConfig(
          apiBaseUrl: 'https://api.example.test/api/v1',
          defaultLocale: 'th-TH',
        ),
        AuthTokenStore(),
        localeTag: 'th-TH',
      );

  final requests = <String>[];

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    requests.add('GET $path');
    expect(auth, isTrue);
    return _response<T>(path, _accounts(googleLinked: true));
  }

  @override
  Future<Response<T>> deleteWithHeaders<T>(
    String path, {
    Object? data,
    bool auth = true,
    Map<String, String> headers = const {},
  }) async {
    requests.add('DELETE $path');
    expect(auth, isTrue);
    return _response<T>(path, _accounts(googleLinked: false));
  }

  Map<String, dynamic> _accounts({required bool googleLinked}) {
    return {
      'data': {
        'resource': {
          'social_accounts': [
            {'provider': 'line', 'linked': false},
            {
              'provider_name': 'google_oauth2',
              'is_linked': googleLinked,
              'displayName': googleLinked ? 'Ada Google' : '',
              'email': googleLinked ? 'ada@example.test' : '',
            },
            {'provider': 'apple', 'linked': false},
            {'provider': 'facebook', 'linked': false},
          ],
        },
      },
    };
  }

  Response<T> _response<T>(String path, Map<String, dynamic> data) {
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: data as T,
    );
  }
}
