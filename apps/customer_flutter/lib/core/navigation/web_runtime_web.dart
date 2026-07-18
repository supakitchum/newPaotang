import 'dart:js_interop';

import 'package:web/web.dart' as web;

@JS('customerApplyPwaIdentity')
external void _applyCustomerPwaIdentity(JSString appName, JSString iconUrl);

bool get isLineInAppBrowser {
  final userAgent = web.window.navigator.userAgent.toLowerCase();
  return userAgent.contains(' line/') ||
      userAgent.startsWith('line/') ||
      userAgent.contains(' line ');
}

void navigateSameWindow(String url) {
  web.window.location.assign(url);
}

String get currentWebHost => web.window.location.host;

String get currentWebReferrer => web.document.referrer;

String get currentWebHref => web.window.location.href;

void syncWebSystemChromeColor(int argbColor) {
  final cssColor =
      '#${(argbColor & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
  for (final selector in const [
    'meta[name="theme-color"]',
    'meta[name="msapplication-TileColor"]',
  ]) {
    web.document.querySelector(selector)?.setAttribute('content', cssColor);
  }
  final bodyStyle = web.document.body?.style;
  bodyStyle?.setProperty('--customer-theme-color', cssColor);
  bodyStyle?.backgroundColor = cssColor;
}

void syncWebPwaIdentity({required String appName, String iconUrl = ''}) {
  final normalizedName = appName.trim();
  if (normalizedName.isEmpty) return;

  _applyCustomerPwaIdentity(normalizedName.toJS, iconUrl.trim().toJS);
}
