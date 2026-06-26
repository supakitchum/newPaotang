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
    return openExternal(
      uri,
      preferSameWindowInLine: _isLineProvider(provider),
    );
  }

  Future<bool> openExternal(
    Uri uri, {
    bool preferSameWindowInLine = false,
  }) async {
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
    return provider.trim().toLowerCase() == 'line';
  }
}

enum LinkLaunchStrategy { sameWindow, externalApplication }

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
