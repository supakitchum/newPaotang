import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_line_sdk/flutter_line_sdk.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../tenant/mobile_bootstrap_controller.dart';
import 'auth_repository.dart';

final nativeLineAuthServiceProvider = Provider<NativeLineAuthService>((ref) {
  return NativeLineAuthService(
    loadBootstrap: () => ref.read(mobileBootstrapProvider.future),
    repository: ref.read(authRepositoryProvider),
  );
});

String? _configuredChannelId;
Future<void>? _lineSetup;

class NativeLineLoginCancelled implements Exception {
  const NativeLineLoginCancelled();
}

class NativeLineAuthService {
  NativeLineAuthService({
    required Future<MobileBootstrap> Function() loadBootstrap,
    required AuthRepository repository,
  }) : _loadBootstrap = loadBootstrap,
       _repository = repository;

  final Future<MobileBootstrap> Function() _loadBootstrap;
  final AuthRepository _repository;

  bool get platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.android);

  Future<SocialCallbackResult?> authenticate({
    String purpose = 'login',
    String redirect = '/',
    bool auth = false,
  }) async {
    if (!platformSupported) return null;

    final bootstrap = await _loadBootstrap();
    final config = bootstrap.line;
    if (!config.nativeLoginConfigured) return null;

    await _setup(
      config.nativeChannelId,
      universalLink: config.nativeUniversalLink,
    );

    try {
      final result = await LineSDK.instance.login(
        scopes: const ['profile', 'openid'],
      );
      final accessToken = result.accessToken.value.trim();
      if (accessToken.isEmpty) {
        throw StateError('LINE did not return an access token.');
      }
      return _repository.nativeLineLogin(
        accessToken: accessToken,
        purpose: purpose,
        redirect: redirect,
        auth: auth,
      );
    } on PlatformException catch (error) {
      final code = error.code.toUpperCase();
      final message = (error.message ?? '').toLowerCase();
      if (code.contains('CANCEL') ||
          message.contains('cancelled') ||
          message.contains('canceled')) {
        throw const NativeLineLoginCancelled();
      }
      rethrow;
    }
  }

  Future<void> _setup(String channelId, {required String universalLink}) async {
    final normalizedChannelId = channelId.trim();
    final configured = _configuredChannelId;
    if (configured != null && configured != normalizedChannelId) {
      throw StateError(
        'LINE SDK was already initialized for a different tenant channel.',
      );
    }

    var setup = _lineSetup;
    if (setup == null) {
      _configuredChannelId = normalizedChannelId;
      setup = LineSDK.instance.setup(
        normalizedChannelId,
        universalLink: universalLink.trim().isEmpty
            ? null
            : universalLink.trim(),
      );
      _lineSetup = setup;
    }

    try {
      await setup;
    } catch (_) {
      _configuredChannelId = null;
      _lineSetup = null;
      rethrow;
    }
  }
}
