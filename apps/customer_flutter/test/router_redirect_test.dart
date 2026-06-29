import 'package:customer_flutter/app/customer_routes.dart';
import 'package:customer_flutter/app/router.dart';
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
        expect(redirect, '/login', reason: '$path should require login');
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
        expect(redirect, '/pin', reason: '$path should require PIN');
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
      '/login',
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
        '/pin',
        reason: '$path should require PIN after login',
      );
    }
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
      '/pin',
    );
  });
}

const _pinBypassPaths = {
  '/pin',
  '/security-lock',
  '/account-suspended',
};

String _samplePath(String pattern) {
  return pattern
      .replaceAll(':provider', 'line')
      .replaceAll(':ticketId', 'ticket_123')
      .replaceAll(':claimId', 'claim_123')
      .replaceAll(':orderId', 'order_123')
      .replaceAll(':slug', 'announcement');
}
