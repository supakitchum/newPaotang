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
}
