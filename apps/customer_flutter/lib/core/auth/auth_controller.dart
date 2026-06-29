import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'auth_repository.dart';
import 'auth_token_store.dart';
import '../security/biometric_auth_service.dart';

final authControllerProvider = ChangeNotifierProvider<AuthController>((ref) {
  return AuthController(
    authRepository: ref.watch(authRepositoryProvider),
    tokenStore: ref.watch(authTokenStoreProvider),
    biometricAuth: ref.watch(biometricAuthServiceProvider),
  );
});

class AuthController extends ChangeNotifier {
  AuthController({
    required AuthRepository authRepository,
    required AuthTokenStore tokenStore,
    required BiometricAuthService biometricAuth,
  })  : _authRepository = authRepository,
        _tokenStore = tokenStore,
        _biometricAuth = biometricAuth {
    isAuthenticated = _tokenStore.hasAccessToken;
    pinRequired = isAuthenticated;
  }

  final AuthRepository _authRepository;
  final AuthTokenStore _tokenStore;
  final BiometricAuthService _biometricAuth;

  bool isAuthenticated = false;
  bool pinRequired = false;
  bool pinSetupRequired = false;
  bool isSecurityLocked = false;

  Future<void> loginWithPassword(String username, String password) async {
    final session = await _authRepository.login(
      username: username,
      password: password,
    );
    isAuthenticated = session.accessToken.isNotEmpty;
    pinRequired = session.pinRequired;
    pinSetupRequired = session.pinSetupRequired;
    notifyListeners();
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
    notifyListeners();
  }

  void applySession(CustomerSession session) {
    isAuthenticated = session.accessToken.isNotEmpty;
    pinRequired = session.pinRequired;
    pinSetupRequired = session.pinSetupRequired;
    isSecurityLocked = false;
    notifyListeners();
  }

  Future<void> logout() async {
    try {
      await _authRepository.logout();
    } catch (_) {
      // Local logout must still succeed when the server rejects an expired
      // token or the network is unavailable.
    } finally {
      isAuthenticated = false;
      pinRequired = false;
      pinSetupRequired = false;
      isSecurityLocked = false;
      notifyListeners();
    }
  }

  Future<void> verifyPin(String pin) async {
    await _authRepository.verifyPin(pin);
    pinRequired = false;
    pinSetupRequired = false;
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
