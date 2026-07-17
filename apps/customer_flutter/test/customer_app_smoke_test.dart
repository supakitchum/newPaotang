import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'support/customer_app_smoke_harness.dart';

void main() {
  testWidgets('CustomerApp smoke boots with runtime config and route guards', (
    tester,
  ) async {
    await runCustomerAppSmokeHarness(tester, platformKey: 'web');
  });

  testWidgets('CustomerApp applies runtime API theme after bootstrap', (
    tester,
  ) async {
    await runCustomerAppSmokeHarness(
      tester,
      platformKey: 'web',
      bootstrapPayload: const {
        'tenant_id': 'tenant_theme',
        'site': {
          'display_name':
              'Partner With A Very Long Display Name For App Store Builds',
          'locale': 'en-US',
        },
        'theme': {
          'primary_color': '#0055AA',
          'secondary_color': '#10B981',
          'background_color': '#F8FAFC',
          'text_color': '#111827',
        },
        'mobile': {
          'auth_providers': [
            {'provider': 'line', 'enabled': true},
            {'provider': 'google', 'enabled': true},
            {'provider': 'apple', 'enabled': true},
          ],
          'screen_security': {
            'web': {
              'sensitive_screen_mode': 'limited',
              'watermark_enabled': true,
            },
          },
        },
      },
      expectedPrimaryColor: const Color(0xFF0055AA),
      expectedScaffoldBackgroundColor: const Color(0xFFF8FAFC),
      expectedFontFamily: 'Kanit',
    );
  });

  testWidgets('CustomerApp applies camelCase runtime API theme', (
    tester,
  ) async {
    await runCustomerAppSmokeHarness(
      tester,
      platformKey: 'web',
      bootstrapPayload: const {
        'tenant_id': 'tenant_theme_camel',
        'siteConfig': {'displayName': 'Partner Camel Theme', 'locale': 'en-US'},
        'mobileConfig': {
          'themeConfig': {
            'primaryColor': '#224488',
            'secondaryColor': '#0EA5E9',
            'backgroundColor': '#F9FAFB',
            'textColor': '#172033',
            'fontFamily': 'Inter',
          },
          'screenSecurity': {
            'web': {'sensitiveScreenMode': 'limited', 'watermarkEnabled': true},
          },
        },
      },
      expectedPrimaryColor: const Color(0xFF224488),
      expectedScaffoldBackgroundColor: const Color(0xFFF9FAFB),
      expectedFontFamily: 'Inter',
    );
  });
}
