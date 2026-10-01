import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/i18n/customer_localizations.dart';
import 'customer_gradient_button.dart';

class SecurityLockScreen extends ConsumerWidget {
  const SecurityLockScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.visibility_off_rounded, size: 64),
                const SizedBox(height: 20),
                Text(
                  l10n.securityCaptureTitle,
                  style: Theme.of(context).textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.securityCaptureDescription,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 240,
                  child: CustomerGradientButton.text(
                    onPressed: () =>
                        ref.read(authControllerProvider).dismissSecurityLock(),
                    height: 48,
                    fontSize: 15,
                    shadow: false,
                    label: l10n.securityUnlockAgain,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
