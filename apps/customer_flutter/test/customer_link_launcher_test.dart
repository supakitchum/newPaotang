import 'package:customer_flutter/core/navigation/customer_link_launcher.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('LINE links in web LINE browser use same-window navigation', () {
    final strategy = chooseLinkLaunchStrategy(
      preferSameWindowInLine: true,
      isWeb: true,
      isLineInAppBrowser: true,
    );

    expect(strategy, LinkLaunchStrategy.sameWindow);
  });

  test('non-LINE browser web links keep external launch behavior', () {
    final strategy = chooseLinkLaunchStrategy(
      preferSameWindowInLine: true,
      isWeb: true,
      isLineInAppBrowser: false,
    );

    expect(strategy, LinkLaunchStrategy.externalApplication);
  });

  test('native app links keep external launch behavior', () {
    final strategy = chooseLinkLaunchStrategy(
      preferSameWindowInLine: true,
      isWeb: false,
      isLineInAppBrowser: true,
    );

    expect(strategy, LinkLaunchStrategy.externalApplication);
  });

  test('links without LINE preference keep external launch behavior', () {
    final strategy = chooseLinkLaunchStrategy(
      preferSameWindowInLine: false,
      isWeb: true,
      isLineInAppBrowser: true,
    );

    expect(strategy, LinkLaunchStrategy.externalApplication);
  });

  test('external URI guard rejects empty and unsafe schemes', () {
    expect(isSafeExternalLinkUri(Uri.tryParse('')), isFalse);
    expect(isSafeExternalLinkUri(Uri.tryParse('/login')), isFalse);
    expect(isSafeExternalLinkUri(Uri.tryParse('javascript:alert(1)')), isFalse);
    expect(
      isSafeExternalLinkUri(Uri.tryParse('data:text/plain,hello')),
      isFalse,
    );
    expect(isSafeExternalLinkUri(Uri.tryParse('file:///tmp/token')), isFalse);
    expect(
      isSafeExternalLinkUri(Uri.parse('https://access.line.me/oauth2/v2.1')),
      isTrue,
    );
    expect(isSafeExternalLinkUri(Uri.parse('line://app/123')), isTrue);
  });

  test('social login URI guard only accepts HTTPS OAuth launch URLs', () {
    expect(
      isSafeSocialLoginUri(Uri.parse('https://access.line.me/oauth2/v2.1')),
      isTrue,
    );
    expect(
      isSafeSocialLoginUri(Uri.parse('https://accounts.google.com/o/oauth2')),
      isTrue,
    );
    expect(
      isSafeSocialLoginUri(Uri.parse('http://accounts.example.test')),
      isFalse,
    );
    expect(isSafeSocialLoginUri(Uri.parse('line://app/123')), isFalse);
    expect(isSafeSocialLoginUri(Uri.parse('intent://oauth')), isFalse);
  });

  test('LINE social provider aliases use LINE launch behavior', () {
    expect(isLineSocialProvider('line'), isTrue);
    expect(isLineSocialProvider('line_login'), isTrue);
    expect(isLineSocialProvider('line_oa'), isTrue);
    expect(isLineSocialProvider('line_oauth'), isTrue);
    expect(isLineSocialProvider('google'), isFalse);
    expect(isLineSocialProvider('apple_id'), isFalse);
  });
}
