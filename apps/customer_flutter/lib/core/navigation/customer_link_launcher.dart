import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'web_runtime.dart' as web_runtime;

final customerLinkLauncherProvider = Provider<CustomerLinkLauncher>((ref) {
  return const CustomerLinkLauncher();
});

class CustomerLinkLauncher {
  const CustomerLinkLauncher();

  Future<bool> openSocialLogin(String provider, Uri uri) {
    if (!isSafeSocialLoginUri(uri)) return Future.value(false);
    return openExternal(
      uri,
      preferSameWindowInLine: _isLineProvider(provider),
    );
  }

  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
    if (!isSafeExternalLinkUri(uri)) return false;

    final strategy = chooseLinkLaunchStrategy(
      preferSameWindowInLine: preferSameWindowInLine,
      isWeb: kIsWeb,
      isLineInAppBrowser: web_runtime.isLineInAppBrowser,
    );

    if (strategy == LinkLaunchStrategy.sameWindow) {
      web_runtime.navigateSameWindow(uri.toString());
      return true;
    }

    return launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  bool _isLineProvider(String provider) {
    return isLineSocialProvider(provider);
  }
}

bool isLineSocialProvider(String provider) {
  return const {'line', 'line_login', 'line_oa', 'line_oauth'}
      .contains(provider.trim().toLowerCase());
}

enum LinkLaunchStrategy { sameWindow, externalApplication }

bool isSafeExternalLinkUri(Uri? uri) {
  if (uri == null || !uri.hasScheme) return false;
  final scheme = uri.scheme.trim().toLowerCase();
  if (scheme.isEmpty) return false;
  return !const {'javascript', 'data', 'file'}.contains(scheme);
}

bool isSafeSocialLoginUri(Uri? uri) {
  if (!isSafeExternalLinkUri(uri)) return false;
  return uri!.scheme.trim().toLowerCase() == 'https';
}

Uri? customerPhoneUri(String phone) {
  final sanitized = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (sanitized.isEmpty) return null;
  final normalized = sanitized.startsWith('+')
      ? '+${sanitized.substring(1).replaceAll('+', '')}'
      : sanitized.replaceAll('+', '');
  if (normalized.replaceAll('+', '').isEmpty) return null;
  return Uri(scheme: 'tel', path: normalized);
}

Uri? customerEmailUri(String email) {
  final normalized = email.trim();
  if (normalized.isEmpty || normalized.contains(RegExp(r'\s'))) return null;
  if (!normalized.contains('@')) return null;
  return Uri(scheme: 'mailto', path: normalized);
}

Uri? customerHttpsUri(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null ||
      uri.scheme.toLowerCase() != 'https' ||
      uri.host.trim().isEmpty ||
      uri.userInfo.isNotEmpty) {
    return null;
  }
  return isSafeExternalLinkUri(uri) ? uri : null;
}

String customerExternalLinkLabel(Uri uri) {
  final host = uri.host.trim();
  if (host.isNotEmpty) return host;
  return uri.toString();
}

LinkLaunchStrategy chooseLinkLaunchStrategy({
  required bool preferSameWindowInLine,
  required bool isWeb,
  required bool isLineInAppBrowser,
}) {
  if (preferSameWindowInLine && isWeb && isLineInAppBrowser) {
    return LinkLaunchStrategy.sameWindow;
  }

  return LinkLaunchStrategy.externalApplication;
}
