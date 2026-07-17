import 'package:customer_flutter/core/auth/auth_token_store.dart';
import 'package:customer_flutter/core/config/app_config.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:customer_flutter/core/i18n/customer_translation_repository.dart';
import 'package:customer_flutter/core/network/api_client.dart';
import 'package:dio/dio.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('parseCustomerTranslationMessages reads direct and wrapped bundles', () {
    expect(
      parseCustomerTranslationMessages({
        'locale': 'th-TH',
        'surface': 'customer',
        'messages': {
          'home.title': 'หน้าหลักใหม่',
          'blank': '',
          'numeric': 123,
          'ignored_null': null,
        },
      }),
      {
        'home.title': 'หน้าหลักใหม่',
        'blank': '',
        'numeric': '123',
      },
    );

    expect(
      parseCustomerTranslationMessages({
        'data': {
          'messages': {'auth.login.title': 'เข้าสู่ระบบร้านค้า'},
        },
      }),
      {'auth.login.title': 'เข้าสู่ระบบร้านค้า'},
    );
  });

  test('translation bundle preserves runtime locale catalog and labels', () {
    final bundle = parseCustomerTranslationBundle({
      'data': {
        'locale': 'ja-JP',
        'messages': {'profile.language.title': '表示言語'},
        'available_locales': [
          {
            'locale': 'th-TH',
            'name': 'Thai',
            'native_name': 'ไทย',
            'is_default': true,
            'sort_order': 10,
            'status': 'active',
          },
          {
            'locale': 'ja-JP',
            'name': 'Japanese',
            'nativeName': '日本語',
            'sortOrder': 30,
            'status': 'active',
          },
          {
            'locale': 'fr-FR',
            'name': 'French',
            'native_name': 'Français',
            'status': 'inactive',
          },
        ],
      },
    });

    expect(bundle.locale, 'ja-JP');
    expect(bundle.messages, {'profile.language.title': '表示言語'});
    expect(bundle.availableLocales.map((option) => option.tag), [
      'th-TH',
      'ja-JP',
    ]);
    expect(bundle.availableLocales.last.displayName, '日本語');
  });

  test('translationPreviewTokenFromLocation supports owner preview aliases',
      () {
    expect(
      translationPreviewTokenFromLocation(
        'https://partner.example.com/?preview_token=abc123',
      ),
      'abc123',
    );
    expect(
      translationPreviewTokenFromLocation(
        'https://partner.example.com/?translation_preview=req_123',
      ),
      'req_123',
    );
    expect(translationPreviewTokenFromLocation('/'), '');
  });

  test('customerTranslationRuntimeFetchAllowed avoids test and native stubs',
      () {
    expect(
      customerTranslationRuntimeFetchAllowed('/api/v1', isWeb: true),
      isTrue,
    );
    expect(
      customerTranslationRuntimeFetchAllowed('/api/v1', isWeb: false),
      isFalse,
    );
    expect(
      customerTranslationRuntimeFetchAllowed(
        'https://partner.example.com/api/v1',
        isWeb: false,
      ),
      isFalse,
    );
    expect(
      customerTranslationRuntimeFetchAllowed(
        'https://partner.newpaotang.test/api/v1',
        isWeb: false,
      ),
      isTrue,
    );
  });

  test('CustomerTranslationRepository requests customer runtime bundle',
      () async {
    final api = _CaptureApiClient();
    final repository = CustomerTranslationRepository(api);

    final bundle = await repository.bundle(
      locale: 'en-US',
      previewToken: 'preview_1',
    );

    expect(api.path, '/public/translations');
    expect(api.auth, isFalse);
    expect(api.query, {
      'locale': 'en-US',
      'surface': 'customer',
      'preview_token': 'preview_1',
    });
    expect(bundle.messages, {'home.title': 'Partner Home'});
    expect(bundle.availableLocales.map((option) => option.tag), [
      'th-TH',
      'en-US',
    ]);
  });

  test('RuntimeCustomerLocalizationsDelegate overlays static locale copy',
      () async {
    final localizations = await const RuntimeCustomerLocalizationsDelegate({
      'auth.login.title': 'Partner sign in',
    }).load(const Locale('en', 'US'));

    expect(localizations.loginTitle, 'Partner sign in');
    expect(localizations.loginSubmit, 'Sign in');
  });
}

class _CaptureApiClient extends ApiClient {
  _CaptureApiClient()
      : super(
          const AppConfig(
            apiBaseUrl: 'https://partner.example.test/api/v1',
            defaultLocale: 'th-TH',
          ),
          AuthTokenStore(),
          localeTag: 'th-TH',
        );

  String path = '';
  Map<String, dynamic> query = {};
  bool auth = true;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? query,
    bool auth = true,
  }) async {
    this.path = path;
    this.query = Map<String, dynamic>.from(query ?? {});
    this.auth = auth;

    return Response<T>(
      requestOptions: RequestOptions(path: path),
      data: {
        'locale': 'en-US',
        'surface': 'customer',
        'messages': {'home.title': 'Partner Home'},
        'available_locales': [
          {
            'locale': 'th-TH',
            'name': 'Thai',
            'native_name': 'ไทย',
            'is_default': true,
            'sort_order': 10,
          },
          {
            'locale': 'en-US',
            'name': 'English',
            'native_name': 'English',
            'sort_order': 20,
          },
        ],
      } as T,
    );
  }
}
