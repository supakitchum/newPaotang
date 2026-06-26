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
}
