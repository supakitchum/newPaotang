import 'package:customer_flutter/core/auth/auth_error_message.dart';
import 'package:customer_flutter/core/i18n/customer_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const l10n = CustomerLocalizations(Locale('th', 'TH'));

  test('login errors use customer-friendly localized messages', () {
    expect(
      loginErrorMessage(
        const {
          'error': {
            'code': 'customer_account_not_found',
            'message': 'Authentication token is missing.',
          },
        },
        l10n,
        fallback: 'เข้าสู่ระบบไม่สำเร็จ',
      ),
      'ไม่พบบัญชีที่ใช้เบอร์โทรศัพท์นี้ กรุณาตรวจสอบเบอร์หรือสมัครใช้งาน',
    );
    expect(
      loginErrorMessage(
        const {
          'error': {
            'code': 'invalid_login_credentials',
            'message': 'Invalid credentials.',
          },
        },
        l10n,
        fallback: 'เข้าสู่ระบบไม่สำเร็จ',
      ),
      'เบอร์โทรศัพท์หรือรหัสผ่านไม่ถูกต้อง กรุณาลองใหม่',
    );
    expect(
      loginErrorMessage(
        const {
          'error': {
            'code': 'login_otp_challenge_invalid',
            'message': 'The login OTP challenge is invalid or expired.',
          },
        },
        l10n,
        fallback: 'ยืนยัน OTP ไม่สำเร็จ',
      ),
      'คำขอยืนยัน OTP หมดอายุ กรุณาขอรหัส OTP ใหม่',
    );
  });

  test('login errors hide unclassified technical token messages', () {
    expect(
      loginErrorMessage(
        const {
          'error': {
            'code': 'legacy_auth_failure',
            'message': 'Access token is missing or invalid.',
          },
        },
        l10n,
        fallback: 'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่',
      ),
      'เข้าสู่ระบบไม่สำเร็จ กรุณาลองใหม่',
    );
  });
}
