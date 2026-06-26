import 'dart:io';

import 'package:customer_flutter/app/customer_routes.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('customer route registry has unique route paths', () {
    final paths = customerFeatureRoutes.map((route) => route.path).toList();
    expect(paths.toSet(), hasLength(paths.length));
  });

  test('customer route registry has unique localization keys', () {
    final keys = customerFeatureRoutes.map((route) => route.key).toList();
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('customer route registry metadata does not contain localized copy', () {
    final thaiPattern = RegExp(r'[ก-๙]');
    final localizedMetadata = customerFeatureRoutes.where(
      (route) =>
          thaiPattern.hasMatch(route.key) ||
          (route.descriptionKey != null &&
              thaiPattern.hasMatch(route.descriptionKey!)),
    );

    expect(localizedMetadata, isEmpty);
  });

  test('customer route localization keys resolve to display copy', () {
    final l10n = CustomerLocalizations.fallback;
    for (final route in customerFeatureRoutes) {
      expect(
        l10n.customerRouteTitle(route.key),
        isNot('routes.${route.key}.title'),
      );
      if (route.descriptionKey != null) {
        expect(
          l10n.customerRouteDescription(route.descriptionKey!),
          isNot('routes.${route.descriptionKey}.description'),
        );
      }
    }
  });

  test('customer route registry covers core Nuxt customer surfaces', () {
    final paths = customerFeatureRoutes.map((route) => route.path).toSet();

    expect(
      paths,
      containsAll({
        '/',
        '/buy',
        '/cart',
        '/checkout',
        '/tickets',
        '/tickets/history',
        '/my-wallet',
        '/topup',
        '/topup/history',
        '/reward-claims',
        '/activity-claims',
        '/activities',
        '/activities/:slug',
        '/news',
        '/news/:slug',
        '/profile',
        '/profile/biometrics',
        '/purchase-history',
        '/purchase-history/:orderId',
        '/login',
        '/register',
        '/forgot-password',
        '/reset-password',
        '/line/link-phone',
        '/social/:provider/callback',
        '/social/:provider/link-phone',
        '/pin',
        '/maintenance',
      }),
    );
  });

  test('customer route registry covers all existing Nuxt page routes', () {
    final paths = customerFeatureRoutes.map((route) => route.path).toSet();

    const nuxtPageRoutes = {
      '/',
      '/account-suspended',
      '/activities',
      '/activities/:slug',
      '/activities/history',
      '/activity-claims',
      '/activity-claims/:claimId',
      '/affiliate',
      '/buy',
      '/buy/more',
      '/buy/search',
      '/cart',
      '/checkout',
      '/countdown',
      '/forgot-password',
      '/line/callback',
      '/line/link-phone',
      '/social/:provider/callback',
      '/social/:provider/link-phone',
      '/login',
      '/lottery-knowledge',
      '/maintenance',
      '/my-wallet',
      '/news',
      '/news/:slug',
      '/pin',
      '/profile',
      '/profile/auto-reward',
      '/profile/line-notifications',
      '/profile/reward-bank',
      '/purchase-history',
      '/purchase-history/:orderId',
      '/register',
      '/reset-password',
      '/result',
      '/result/full',
      '/results',
      '/results/full',
      '/reward-claims',
      '/reward-claims/:claimId',
      '/stores',
      '/stores/lotteries',
      '/success',
      '/term-reward',
      '/terms',
      '/tickets',
      '/tickets/claim/:ticketId',
      '/tickets/history',
      '/tickets/view',
      '/topup',
      '/topup/history',
      '/waiting-result',
    };

    expect(paths, containsAll(nuxtPageRoutes));
  });

  test('customer route registry stays in sync with Nuxt page files', () {
    final pagesDirectory = Directory('../customer/pages');
    if (!pagesDirectory.existsSync()) {
      return;
    }

    final flutterPaths =
        customerFeatureRoutes.map((route) => route.path).toSet();
    final nuxtPaths = pagesDirectory
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.vue'))
        .map((file) => _nuxtPageRouteForFile(file, pagesDirectory))
        .toSet();

    expect(flutterPaths, containsAll(nuxtPaths));
  });

  test('customer router declares every registered feature route', () {
    final routerSource = File('lib/app/router.dart').readAsStringSync();
    final routerPaths = RegExp(r"GoRoute\(\s*path:\s*'([^']+)'")
        .allMatches(routerSource)
        .map((match) => match.group(1))
        .whereType<String>()
        .toSet();
    final registeredPaths =
        customerFeatureRoutes.map((route) => route.path).toSet();

    expect(routerPaths, containsAll(registeredPaths));
  });

  test('profile screen links to the same core menu flows as Nuxt profile', () {
    final profileSource =
        File('lib/features/profile/presentation/profile_screen.dart')
            .readAsStringSync();

    const expectedProfileLinks = {
      "path: '/my-wallet'",
      "path: '/purchase-history'",
      "path: '/reward-claims'",
      "path: '/activity-claims'",
      "path: '/activities'",
      "path: '/affiliate'",
      "path: '/profile/reward-bank'",
      "path: '/profile/auto-reward'",
      "path: '/profile/line-notifications'",
      "path: '/news'",
      "path: '/terms'",
      "path: '/lottery-knowledge'",
    };

    for (final link in expectedProfileLinks) {
      expect(profileSource, contains(link));
    }
  });

  test('customer route registry includes mobile-only social provider routes',
      () {
    final paths = customerFeatureRoutes.map((route) => route.path).toSet();

    expect(paths, contains('/social/:provider/callback'));
    expect(paths, contains('/social/:provider/link-phone'));
  });

  test('customer router does not include production placeholder fallback', () {
    final routerSource = File('lib/app/router.dart').readAsStringSync();

    expect(routerSource, isNot(contains('FeaturePlaceholderScreen')));
    expect(routerSource, isNot(contains('feature_shell')));
    expect(routerSource, isNot(contains('for (final feature')));
  });

  test(
    'public customer paths include unauthenticated content and auth entry points',
    () {
      expect(publicCustomerPaths, contains('/'));
      expect(publicCustomerPaths, contains('/activities'));
      expect(publicCustomerPaths, contains('/activities/:slug'));
      expect(publicCustomerPaths, contains('/login'));
      expect(publicCustomerPaths, contains('/register'));
      expect(publicCustomerPaths, contains('/news'));
      expect(publicCustomerPaths, contains('/terms'));
      expect(publicCustomerPaths, isNot(contains('/my-wallet')));
      expect(publicCustomerPaths, isNot(contains('/tickets')));
    },
  );

  test('sensitive customer routes are not public routes', () {
    final sensitivePublicRoutes = customerFeatureRoutes
        .where((route) => route.sensitive && route.public)
        .map((route) => route.path)
        .toList();

    expect(sensitivePublicRoutes, isEmpty);
  });

  test('financial, identity, and claim routes are marked sensitive', () {
    final sensitivePaths = customerFeatureRoutes
        .where((route) => route.sensitive)
        .map((route) => route.path)
        .toSet();

    expect(
      sensitivePaths,
      containsAll({
        '/cart',
        '/checkout',
        '/tickets',
        '/tickets/history',
        '/tickets/view',
        '/tickets/claim/:ticketId',
        '/my-wallet',
        '/topup',
        '/topup/history',
        '/reward-claims',
        '/reward-claims/:claimId',
        '/activity-claims',
        '/activity-claims/:claimId',
        '/affiliate',
        '/profile',
        '/profile/auto-reward',
        '/profile/biometrics',
        '/profile/line-notifications',
        '/profile/reward-bank',
        '/purchase-history',
        '/purchase-history/:orderId',
        '/pin',
        '/success',
      }),
    );
  });
}

String _nuxtPageRouteForFile(File file, Directory pagesDirectory) {
  final rootPath = pagesDirectory.absolute.path;
  final filePath = file.absolute.path;
  final relative = filePath
      .substring(rootPath.length + 1)
      .replaceAll(Platform.pathSeparator, '/')
      .replaceAll('.vue', '');
  final parts = relative
      .split('/')
      .where((part) => part.isNotEmpty && part != 'index')
      .map(_nuxtRoutePart)
      .toList(growable: false);

  return parts.isEmpty ? '/' : '/${parts.join('/')}';
}

String _nuxtRoutePart(String part) {
  if (!part.startsWith('[') || !part.endsWith(']')) return part;
  final rawName = part.substring(1, part.length - 1);
  return ':${_camelCaseParam(rawName)}';
}

String _camelCaseParam(String value) {
  final pieces = value.split('_').where((piece) => piece.isNotEmpty).toList();
  if (pieces.isEmpty) return value;
  return pieces.first +
      pieces.skip(1).map((piece) {
        return piece.substring(0, 1).toUpperCase() + piece.substring(1);
      }).join();
}
