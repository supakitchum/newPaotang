import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'mobile_bootstrap_controller.dart';

final customerPlatformKeyProvider = Provider<String>((_) {
  return currentCustomerPlatformKey();
});

String currentCustomerPlatformKey({
  bool isWeb = kIsWeb,
  TargetPlatform? targetPlatform,
}) {
  if (isWeb) return 'web';
  return switch (targetPlatform ?? defaultTargetPlatform) {
    TargetPlatform.iOS => 'ios',
    TargetPlatform.android => 'android',
    TargetPlatform.macOS => 'macos',
    TargetPlatform.windows => 'windows',
    TargetPlatform.linux => 'linux',
    TargetPlatform.fuchsia => 'fuchsia',
  };
}

bool mobileBiometricAllowedForPlatform(
  MobileBootstrap bootstrap,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  if (platformKey == 'web') return false;
  if (!bootstrap.biometric.enabled) return false;
  if (!bootstrap.featureFlags
      .enabled('native_biometric_unlock', fallback: true)) {
    return false;
  }
  if (bootstrap.biometric.platforms.isEmpty) return true;
  return bootstrap.biometric.supportsPlatform(platformKey);
}

bool mobileNativeScreenSecurityAllowedForPlatform(
  MobileBootstrap bootstrap,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  final iosScreenshotPolicy =
      bootstrap.screenSecurity.iosScreenshotPolicy.trim().toLowerCase();
  final iosScreenshotProtectionEnabled = iosScreenshotPolicy.isNotEmpty &&
      !{'none', 'off', 'disabled'}.contains(iosScreenshotPolicy);
  if (!bootstrap.featureFlags
      .enabled('screen_security_native', fallback: true)) {
    return false;
  }

  return switch (platformKey) {
    'android' => bootstrap.screenSecurity.androidFlagSecure ||
        bootstrap.screenSecurity.androidProtectRecentAppPreview,
    'ios' => bootstrap.screenSecurity.iosScreenCaptureOverlay ||
        iosScreenshotProtectionEnabled,
    _ => false,
  };
}

bool mobileNativeScreenSecurityFallbackForPlatform(String platform) {
  final platformKey = platform.trim().toLowerCase();
  return platformKey == 'android' || platformKey == 'ios';
}

bool mobileWebPrivacyGuardAllowedForPlatform(
  MobileBootstrap bootstrap,
  String platform,
) {
  final platformKey = platform.trim().toLowerCase();
  if (platformKey != 'web') return false;

  final mode =
      bootstrap.screenSecurity.webSensitiveScreenMode.trim().toLowerCase();
  if ({'none', 'off', 'disabled'}.contains(mode)) return false;

  return bootstrap.screenSecurity.webWatermarkEnabled ||
      {'limited', 'strict', 'watermark'}.contains(mode);
}

bool mobileWebPrivacyGuardFallbackForPlatform(String platform) {
  return platform.trim().toLowerCase() == 'web';
}
