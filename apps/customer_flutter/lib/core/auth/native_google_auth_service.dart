import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_sign_in/google_sign_in.dart';

import 'auth_repository.dart';
import '../tenant/mobile_bootstrap_controller.dart';

final nativeGooglePromptCoordinatorProvider =
    Provider<NativeGooglePromptCoordinator>(
      (ref) => NativeGooglePromptCoordinator(),
    );

final nativeGoogleAuthServiceProvider = Provider<NativeGoogleAuthService>((
  ref,
) {
  return NativeGoogleAuthService(
    repository: ref.read(authRepositoryProvider),
    promptCoordinator: ref.read(nativeGooglePromptCoordinatorProvider),
    serverClientIdLoader: () async {
      final bootstrap = await ref.read(mobileBootstrapProvider.future);
      for (final provider in bootstrap.authProviders) {
        if (provider.provider == 'google') return provider.nativeClientId;
      }
      return '';
    },
  );
});

class NativeGooglePromptCoordinator {
  bool _active = false;

  bool get isActive => _active;

  Future<T> whileActive<T>(Future<T> Function() action) async {
    _active = true;
    try {
      return await action();
    } finally {
      _active = false;
    }
  }
}

class NativeGoogleLoginCancelled implements Exception {
  const NativeGoogleLoginCancelled();
}

typedef NativeGoogleCredentialLoader = Future<String> Function(String clientId);

class NativeGoogleAuthService {
  NativeGoogleAuthService({
    required AuthRepository repository,
    required Future<String> Function() serverClientIdLoader,
    required NativeGooglePromptCoordinator promptCoordinator,
    NativeGoogleCredentialLoader? loadCredential,
  }) : _repository = repository,
       _serverClientIdLoader = serverClientIdLoader,
       _promptCoordinator = promptCoordinator {
    _credentialLoader = loadCredential ?? _loadNativeCredential;
  }

  final AuthRepository _repository;
  final Future<String> Function() _serverClientIdLoader;
  final NativeGooglePromptCoordinator _promptCoordinator;
  late final NativeGoogleCredentialLoader _credentialLoader;
  Future<void>? _initialization;
  String? _initializedClientId;

  bool get platformSupported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  Future<SocialCallbackResult?> authenticate({
    String purpose = 'login',
    String redirect = '/',
    bool auth = false,
  }) async {
    if (!platformSupported) return null;

    final clientId = (await _serverClientIdLoader()).trim();
    if (clientId.isEmpty) {
      throw StateError('Google native sign-in is not configured.');
    }

    try {
      final identityToken = await _promptCoordinator.whileActive(
        () => _credentialLoader(clientId),
      );
      if (identityToken.trim().isEmpty) {
        throw StateError('Google did not return an identity token.');
      }
      return _repository.nativeGoogleLogin(
        identityToken: identityToken,
        purpose: purpose,
        redirect: redirect,
        auth: auth,
      );
    } on GoogleSignInException catch (error) {
      if (error.code == GoogleSignInExceptionCode.canceled) {
        throw const NativeGoogleLoginCancelled();
      }
      rethrow;
    }
  }

  Future<String> _loadNativeCredential(String clientId) async {
    if (_initializedClientId != null && _initializedClientId != clientId) {
      throw StateError('Google native sign-in client changed.');
    }
    _initializedClientId = clientId;
    await (_initialization ??= GoogleSignIn.instance.initialize(
      serverClientId: clientId,
    ));
    // The app supports connecting a different Google account to a phone login.
    // Clear the SDK's previous selection before showing the account picker.
    await GoogleSignIn.instance.signOut();
    final account = await GoogleSignIn.instance.authenticate();
    return account.authentication.idToken ?? '';
  }
}
