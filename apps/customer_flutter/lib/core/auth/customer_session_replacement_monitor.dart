import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_alert.dart';
import '../i18n/customer_localizations.dart';
import 'auth_controller.dart';
import 'auth_token_store.dart';
import 'customer_session_replacement_controller.dart';

class CustomerSessionReplacementMonitor extends ConsumerStatefulWidget {
  const CustomerSessionReplacementMonitor({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<CustomerSessionReplacementMonitor> createState() =>
      _CustomerSessionReplacementMonitorState();
}

class _CustomerSessionReplacementMonitorState
    extends ConsumerState<CustomerSessionReplacementMonitor> {
  int _handledSequence = 0;

  @override
  Widget build(BuildContext context) {
    ref.listen<CustomerSessionReplacementState>(
      customerSessionReplacementControllerProvider,
      (_, next) {
        if (!next.pending || next.sequence == _handledSequence) return;
        _handledSequence = next.sequence;
        _handleReplacement(next);
      },
    );
    return widget.child;
  }

  Future<void> _handleReplacement(
    CustomerSessionReplacementState replacement,
  ) async {
    final currentSessionId =
        ref.read(authTokenStoreProvider).sessionId?.trim() ?? '';
    if (replacement.replacementSessionId.isNotEmpty &&
        replacement.replacementSessionId == currentSessionId) {
      ref
          .read(customerSessionReplacementControllerProvider.notifier)
          .acknowledge();
      return;
    }

    final l10n = context.l10n;
    await ref.read(authControllerProvider).forceSessionReplaced();
    if (!mounted) return;

    ref
        .read(appAlertControllerProvider.notifier)
        .show(
          title: l10n.authSessionReplacedTitle,
          message: l10n.authSessionReplacedMessage,
          button: l10n.authSessionReplacedButton,
          variant: AppAlertVariant.warning,
        );
    ref
        .read(customerSessionReplacementControllerProvider.notifier)
        .acknowledge();
  }
}
