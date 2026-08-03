import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_token_store.dart';
import 'customer_passkey_repository.dart';
import '../security/biometric_auth_service.dart';
import '../utils/api_errors.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
    biometricAuth: ref.watch(biometricAuthServiceProvider),
    passkeys: ref.watch(customerPasskeyRepositoryProvider),
  );
});

final authSessionStartupProvider = FutureProvider<void>((ref) async {
  await ref.read(authControllerProvider).restoreSession();
});

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required AuthTokenStore tokenStore,
    required BiometricAuthService biometricAuth,
    CustomerPasskeyRepository? passkeys,
  }) : _authRepository = authRepository,
       _tokenStore = tokenStore,
       _biometricAuth = biometricAuth,
       _passkeys = passkeys {
    isAuthenticated = _tokenStore.hasSessionCredential;
    pinRequired = isAuthenticated;
  }

  final AuthRepository _authRepository;
  final AuthTokenStore _tokenStore;
  final BiometricAuthService _biometricAuth;
  final CustomerPasskeyRepository? _passkeys;

  bool isAuthenticated = false;
  bool pinRequired = false;
  bool pinSetupRequired = false;
  bool isSecurityLocked = false;
  String preferredLocale = '';
  String startupRedirectPath = '';
  Future<void>? _sessionRestoreInFlight;
  final Set<Future<void> Function()> _beforeLogoutHooks = {};

  VoidCallback registerBeforeLogoutHook(Future<void> Function() hook) {
    _beforeLogoutHooks.add(hook);
    return () => _beforeLogoutHooks.remove(hook);
  }

  Future<void> restoreSession() {
    final pending = _sessionRestoreInFlight;
    if (pending != null) return pending;
    final future = _restoreSessionNow();
    _sessionRestoreInFlight = future;
    return future;
  }

  Future<void> _restoreSessionNow() async {
    if (!_tokenStore.hasSessionCredential) {
      return;
    }

    try {
      if (!_tokenStore.hasAccessToken) {
        final session = await _authRepository.refresh();
        isAuthenticated = session.accessToken.isNotEmpty;
        pinRequired = isAuthenticated;
        pinSetupRequired = session.pinSetupRequired;
        preferredLocale = session.preferredLocale;
      }

      final identity = await _authRepository.currentIdentity();
      isAuthenticated = _tokenStore.hasAccessToken;
      pinSetupRequired = identity.pinSetupRequired || !identity.hasPin;
      // Nuxt keeps the PIN unlock in sessionStorage. A fresh Flutter process
      // likewise starts locked even if the backend session was PIN-verified.
      pinRequired = isAuthenticated;
      preferredLocale = identity.preferredLocale;
      startupRedirectPath = '';
      notifyListeners();
    } catch (error) {
      final info = ApiErrorInfo.fromObject(error);
      if (info.isAuthenticationExpired ||
          info.isCustomerSessionReplaced ||
          info.isCustomerSuspended) {
        await _authRepository.clearLocalSession();
        _setGuestSession(
          redirectPath: info.isCustomerSuspended
              ? info.customerSuspendedPath
              : '',
        );
        return;
      }

      // Network and server failures must not discard a refreshable session.
      isAuthenticated = _tokenStore.hasSessionCredential;
      pinRequired = isAuthenticated;
      notifyListeners();
    }
  }

  void _setGuestSession({String redirectPath = ''}) {
    isAuthenticated = false;
    pinRequired = false;
    pinSetupRequired = false;
    isSecurityLocked = false;
    preferredLocale = '';
    startupRedirectPath = redirectPath;
    notifyListeners();
  }

  Future<void> loginWithPassword(String username, String password) async {
    final session = await _authRepository.login(
      username: username,
      password: password,
    );
    isAuthenticated = session.accessToken.isNotEmpty;
    pinRequired = session.pinRequired;
    pinSetupRequired = session.pinSetupRequired;
    preferredLocale = session.preferredLocale;
    startupRedirectPath = '';
    notifyListeners();
  }

  Future<LoginOtpChallenge> requestLoginOtp(String phone) {
    return _authRepository.requestLoginOtp(phone: phone);
  }

  Future<void> loginWithPasskey() async {
    final passkeys = _passkeys;
    if (passkeys == null) {
      throw StateError('Passkey login is unavailable.');
    }
    final session = await passkeys.login();
    applySession(session);
  }

  Future<void> verifyLoginOtp({
    required String challengeToken,
    required String otp,
  }) async {
    final session = await _authRepository.verifyLoginOtp(
      challengeToken: challengeToken,
      otp: otp,
    );
    applySession(session);
  }

  Future<void> register({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String passwordConfirmation,
    String? otpVerificationToken,
  }) async {
    final session = await _authRepository.register(
      firstName: firstName,
      lastName: lastName,
      phone: phone,
      password: password,
      passwordConfirmation: passwordConfirmation,
      otpVerificationToken: otpVerificationToken,
    );
    isAuthenticated = session.accessToken.isNotEmpty;
    pinRequired = session.pinRequired;
    pinSetupRequired = session.pinSetupRequired;
    preferredLocale = session.preferredLocale;
    startupRedirectPath = '';
    notifyListeners();
  }

  void applySession(CustomerSession session) {
    isAuthenticated = session.accessToken.isNotEmpty;
    pinRequired = session.pinRequired;
    pinSetupRequired = session.pinSetupRequired;
    isSecurityLocked = false;
    preferredLocale = session.preferredLocale;
    startupRedirectPath = '';
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      for (final hook in List<Future<void> Function()>.of(_beforeLogoutHooks)) {
        try {
          await hook();
        } catch (_) {
          // Push-device cleanup must not prevent an explicit customer logout.
        }
      }
      await _authRepository.logout();
    } catch (_) {
      // Local logout must still succeed when the server rejects an expired
      // token or the network is unavailable.
    } finally {
      _setGuestSession();
    }
  }

  Future<void> forceSessionReplaced() async {
    await _authRepository.clearLocalSession();
    _setGuestSession();
  }

  Future<void> verifyPin(String pin) async {
    final status = await _authRepository.verifyPin(pin);
    isAuthenticated = isAuthenticated || _tokenStore.hasAccessToken;
    pinRequired = status.pinRequired;
    pinSetupRequired = status.pinSetupRequired;
    isSecurityLocked = false;
    notifyListeners();
  }

  Future<void> setupPin({
    required String pin,
    required String pinConfirmation,
  }) async {
    final status = await _authRepository.setupPin(
      pin: pin,
      pinConfirmation: pinConfirmation,
    );
    pinRequired = status.pinRequired;
    pinSetupRequired = status.pinSetupRequired;
    notifyListeners();
  }

  Future<void> confirmPinResetWithOtp({
    required String otpVerificationToken,
    required String pin,
    required String pinConfirmation,
  }) async {
    await _authRepository.confirmPinResetWithOtp(
      otpVerificationToken: otpVerificationToken,
      pin: pin,
      pinConfirmation: pinConfirmation,
    );
    pinRequired = false;
    pinSetupRequired = false;
    isSecurityLocked = false;
    notifyListeners();
  }

  Future<PinStatus> syncPinStatus() async {
    final status = await _authRepository.pinStatus();
    pinRequired = status.pinRequired;
    pinSetupRequired = status.pinSetupRequired;
    notifyListeners();
    return status;
  }

  Future<bool> unlockWithBiometric({required String localizedReason}) async {
    final assertion = await _biometricAuth.requestPinAssertion(
      localizedReason: localizedReason,
    );
    if (assertion == null) return false;
    await _authRepository.verifyPinAssertion(assertion);
    pinRequired = false;
    pinSetupRequired = false;
    notifyListeners();
    return true;
  }

  Future<bool> canUnlockWithBiometric() {
    return _biometricAuth.canUnlockCurrentDevice();
  }

  void lockForScreenSecurity() {
    isSecurityLocked = true;
    pinRequired = true;
    pinSetupRequired = false;
    notifyListeners();
  }

  void lockForAppLifecycle() {
    if (!isAuthenticated || pinRequired) return;
    pinRequired = true;
    notifyListeners();
  }

  void dismissSecurityLock() {
    isSecurityLocked = false;
    notifyListeners();
  }
}
