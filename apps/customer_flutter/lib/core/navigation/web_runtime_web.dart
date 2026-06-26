import 'package:web/web.dart' as web;

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
