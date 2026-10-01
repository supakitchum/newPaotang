import 'package:customer_flutter/core/navigation/customer_redirect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('safe customer redirect accepts app paths with query strings', () {
    expect(safeCustomerRedirect('/checkout?from=cart'), '/checkout?from=cart');
    expect(
      customerLoginRouteForRedirect('/checkout?from=cart'),
      '/login?redirect=%2Fcheckout%3Ffrom%3Dcart',
    );
    expect(
      customerPinRouteForRedirect('/tickets/view?id=ticket_123'),
      '/pin?redirect=%2Ftickets%2Fview%3Fid%3Dticket_123',
    );
    expect(
      customerLoginOtpRouteForRedirect('/checkout?from=cart'),
      '/login/otp?redirect=%2Fcheckout%3Ffrom%3Dcart',
    );
  });

  test('safe customer redirect rejects external and auth-loop targets', () {
    for (final redirect in [
      '',
      'checkout',
      'https://partner.example.com/checkout',
      '//partner.example.com/checkout',
      '/login',
      '/login/otp',
      '/register',
      '/forgot-password',
      '/reset-password',
      '/pin',
      '/line/callback?code=abc',
      '/line/link-phone?token=abc',
      '/social',
      '/social/google/callback?code=abc',
      '/social/google/link-phone?token=abc',
    ]) {
      expect(safeCustomerRedirect(redirect), '/', reason: redirect);
    }
  });
}
