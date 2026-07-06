import 'package:customer_flutter/app/customer_routes.dart';
import 'package:customer_flutter/app/router.dart';
import 'package:customer_flutter/core/navigation/customer_redirect.dart';
import 'package:customer_flutter/core/tenant/mobile_bootstrap_controller.dart';
import 'package:customer_flutter/core/tenant/mobile_runtime_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('unauthenticated customer can open public routes', () {
    expect(
      customerRedirectPath(
        path: '/',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
      ),
      isNull,
    );
    expect(
      customerRedirectPath(
        path: '/news/demo',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
      ),
      isNull,
    );
  });

  test('unauthenticated redirect policy matches every registered route', () {
    for (final route in customerFeatureRoutes) {
      final path = _samplePath(route.path);
      final redirect = customerRedirectPath(
        path: path,
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
      );

      if (route.path == '/maintenance') {
        expect(redirect, '/', reason: '$path exits inactive maintenance mode');
      } else if (route.public) {
        expect(redirect, isNull, reason: '$path should be public');
      } else {
        expect(
          redirect,
          customerLoginRouteForRedirect(path),
          reason: '$path should require login',
        );
      }
    }
  });

  test('PIN redirect policy matches every registered route after login', () {
    for (final route in customerFeatureRoutes) {
      final path = _samplePath(route.path);
      final redirect = customerRedirectPath(
        path: path,
        isAuthenticated: true,
        pinRequired: true,
        isSecurityLocked: false,
      );

      if (_pinBypassPaths.contains(route.path)) {
        expect(redirect, isNull, reason: '$path should bypass PIN');
      } else if (route.path == '/maintenance') {
        expect(redirect, '/', reason: '$path exits inactive maintenance mode');
      } else {
        expect(
          redirect,
          customerPinRouteForRedirect(path),
          reason: '$path should require PIN',
        );
      }
    }
  });

  test('unauthenticated customer is redirected from protected routes', () {
    expect(
      customerRedirectPath(
        path: '/tickets',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
      ),
      '/login?redirect=%2Ftickets',
    );
  });

  test('authenticated customer must verify PIN before home or public content',
      () {
    for (final path in ['/', '/news', '/activities', '/result']) {
      expect(
        customerRedirectPath(
          path: path,
          isAuthenticated: true,
          pinRequired: true,
          isSecurityLocked: false,
        ),
        customerPinRouteForRedirect(path),
        reason: '$path should require PIN after login',
      );
    }
  });

  test('authenticated customer can open inline PIN routes after login', () {
    expect(
      customerRedirectPath(
        path: '/affiliate',
        isAuthenticated: true,
        pinRequired: true,
        pinSetupRequired: false,
        isSecurityLocked: false,
      ),
      isNull,
    );
    expect(
      customerRedirectPath(
        path: '/affiliate',
        isAuthenticated: true,
        pinRequired: true,
        pinSetupRequired: true,
        isSecurityLocked: false,
      ),
      '/pin?redirect=%2Faffiliate',
    );
  });

  test('PIN guard allows only security and operational bypass routes', () {
    for (final path in [
      '/pin',
      '/security-lock',
      '/account-suspended',
    ]) {
      expect(
        customerRedirectPath(
          path: path,
          isAuthenticated: true,
          pinRequired: true,
          isSecurityLocked: false,
        ),
        isNull,
        reason: '$path should bypass PIN redirect',
      );
    }
  });

  test('maintenance mode redirects every route to maintenance page', () {
    for (final path in ['/', '/login', '/pin', '/tickets', '/security-lock']) {
      expect(
        customerRedirectPath(
          path: path,
          isAuthenticated: true,
          pinRequired: true,
          isSecurityLocked: true,
          maintenanceActive: true,
        ),
        '/maintenance',
        reason: '$path should be closed while tenant maintenance is active',
      );
    }

    expect(
      customerRedirectPath(
        path: '/maintenance',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
        maintenanceActive: true,
      ),
      isNull,
    );
  });

  test('maintenance page exits when tenant maintenance is inactive', () {
    expect(
      customerRedirectPath(
        path: '/maintenance',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
      ),
      '/',
    );
  });

  test('maintenance config follows Nuxt route policy modes and patterns', () {
    final fullSite = MaintenanceConfig.fromJson({
      'active': true,
      'mode': 'full_site',
      'allowed_routes': [
        {'deepLink': 'https://shop.example.test/#/news*'},
      ],
    });
    expect(
      customerRedirectPath(
        path: '/news/notice',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: fullSite,
      ),
      isNull,
    );
    expect(
      customerRedirectPath(
        path: '/tickets',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: fullSite,
      ),
      '/maintenance',
    );

    final checkoutOnly = MaintenanceConfig.fromJson({
      'active': true,
      'mode': 'checkout_payment_only',
    });
    expect(
      customerRedirectPath(
        path:
            'route=https%3A%2F%2Fshop.example.test%2Fcheckout%2Fpending%3Forder_id%3Dord_1',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: checkoutOnly,
      ),
      '/maintenance',
    );
    expect(
      customerRedirectPath(
        path: '/checkout/pending',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: checkoutOnly,
      ),
      '/maintenance',
    );
    expect(
      customerRedirectPath(
        path: '/my-wallet',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: checkoutOnly,
      ),
      isNull,
    );

    final readOnly = MaintenanceConfig.fromJson({
      'active': true,
      'mode': 'read_only',
      'blocked_route_patterns': [
        {'hashRoute': '#/profile/reward-bank*'},
      ],
    });
    expect(
      customerRedirectPath(
        path: '/checkout',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: readOnly,
      ),
      isNull,
    );
    expect(
      customerRedirectPath(
        path: '/profile/reward-bank/edit',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        maintenance: readOnly,
      ),
      '/maintenance',
    );
  });

  test('runtime feature flags redirect disabled customer routes', () {
    final bootstrap = MobileBootstrap.fromJson({
      'featureFlags': {
        'wallet': false,
        'nativeBiometricUnlock': false,
        'news': false,
      },
    });

    expect(
      customerRedirectPath(
        path: '/topup/history',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        bootstrap: bootstrap,
      ),
      '/profile',
    );
    expect(
      customerRedirectPath(
        path: '/profile/biometrics',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        bootstrap: bootstrap,
      ),
      '/profile',
    );
    expect(
      customerRedirectPath(
        path: '/news/announcement',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
        bootstrap: bootstrap,
      ),
      '/',
    );
  });

  test('runtime feature flags normalize URL and deep-link route wrappers', () {
    final bootstrap = MobileBootstrap.fromJson({
      'featureFlags': {
        'wallet': false,
        'tickets': false,
        'news': false,
      },
    });

    expect(
      mobileCustomerRouteAllowed(
        bootstrap,
        'https://shop.example.test/#/my-wallet?tab=summary',
      ),
      isFalse,
    );
    expect(
      mobileCustomerDisabledRouteRedirect(
        bootstrap,
        'customer://runtime-policy?returnUrl=https%3A%2F%2Fshop.example.test%2Ftopup%2Fhistory%3Ftab%3D1',
      ),
      '/profile',
    );
    expect(
      mobileCustomerDisabledRouteRedirect(
        bootstrap,
        'https%3A%2F%2Fshop.example.test%2Ftickets%2Fticket_7%3Ftab%3Dimage',
      ),
      '/profile',
    );
    expect(
      customerRedirectPath(
        path: 'route=%2Fnews%2Fannouncement%3Ftab%3D1',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
        bootstrap: bootstrap,
      ),
      '/',
    );
  });

  test('screen security lock takes precedence over PIN guard', () {
    expect(
      customerRedirectPath(
        path: '/pin',
        isAuthenticated: true,
        pinRequired: true,
        isSecurityLocked: true,
      ),
      '/security-lock',
    );
  });

  test('authenticated customer is redirected away from guest-only auth routes',
      () {
    for (final path in [
      '/login',
      '/register',
      '/forgot-password',
      '/reset-password',
    ]) {
      expect(
        customerRedirectPath(
          path: path,
          isAuthenticated: true,
          pinRequired: false,
          isSecurityLocked: false,
        ),
        '/',
        reason: '$path should not be visible after login',
      );
    }
  });

  test('authenticated guest-only routes honor safe redirect targets', () {
    expect(
      customerRedirectPath(
        path: '/login',
        isAuthenticated: true,
        pinRequired: false,
        isSecurityLocked: false,
        guestRedirectPath: '/tickets',
      ),
      '/tickets',
    );

    for (final redirect in [
      'https://example.com/tickets',
      '//example.com/tickets',
      '/login',
      '/register',
    ]) {
      expect(
        customerRedirectPath(
          path: '/login',
          isAuthenticated: true,
          pinRequired: false,
          isSecurityLocked: false,
          guestRedirectPath: redirect,
        ),
        '/',
        reason: '$redirect should not be accepted as guest redirect',
      );
    }
  });

  test('authenticated guest-only routes still require PIN first', () {
    expect(
      customerRedirectPath(
        path: '/login',
        isAuthenticated: true,
        pinRequired: true,
        isSecurityLocked: false,
        guestRedirectPath: '/tickets',
      ),
      '/pin?redirect=%2Ftickets',
    );
  });

  test('auth and PIN redirects preserve safe query targets', () {
    expect(
      customerRedirectPath(
        path: '/checkout',
        requestedLocation: '/checkout?from=cart',
        isAuthenticated: false,
        pinRequired: false,
        isSecurityLocked: false,
      ),
      '/login?redirect=%2Fcheckout%3Ffrom%3Dcart',
    );

    expect(
      customerRedirectPath(
        path: '/checkout',
        requestedLocation: '/checkout?from=cart',
        isAuthenticated: true,
        pinRequired: true,
        isSecurityLocked: false,
      ),
      '/pin?redirect=%2Fcheckout%3Ffrom%3Dcart',
    );
  });
}

const _pinBypassPaths = {
  '/pin',
  '/security-lock',
  '/account-suspended',
  '/affiliate',
};

String _samplePath(String pattern) {
  return pattern
      .replaceAll(':provider', 'line')
      .replaceAll(':ticketId', 'ticket_123')
      .replaceAll(':claimId', 'claim_123')
      .replaceAll(':orderId', 'order_123')
      .replaceAll(':slug', 'announcement');
}
