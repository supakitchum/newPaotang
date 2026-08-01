import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:passkeys/types.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/customer_passkey_repository.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';

class PasskeysScreen extends ConsumerStatefulWidget {
  const PasskeysScreen({super.key});

  @override
  ConsumerState<PasskeysScreen> createState() => _PasskeysScreenState();
}

class _PasskeysScreenState extends ConsumerState<PasskeysScreen> {
  bool _registering = false;
  String _revokingId = '';

  @override
  Widget build(BuildContext context) {
    final collection = ref.watch(customerPasskeysProvider);
    final availability = ref.watch(customerPasskeyAvailabilityProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.passkeyManagementTitle,
      currentPath: '/profile/passkeys',
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: true,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(customerPasskeysProvider);
            await ref.read(customerPasskeysProvider.future);
          },
          child: collection.when(
            loading: () => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                SizedBox(
                  height: MediaQuery.sizeOf(context).height * 0.56,
                  child: Center(
                    child: CustomerLoadingMark(
                      semanticLabel: l10n.commonLoadingData,
                    ),
                  ),
                ),
              ],
            ),
            error: (error, _) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                CustomerPageBody(
                  top: 22,
                  bottom: 120,
                  mobileHorizontal: 18,
                  minViewportHeight: true,
                  child: _PasskeyErrorState(
                    message: authErrorMessage(error, l10n.passkeyLoadFailed),
                    onRetry: () => ref.invalidate(customerPasskeysProvider),
                  ),
                ),
              ],
            ),
            data: (data) => ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              children: [
                CustomerPageBody(
                  top: 16,
                  bottom: 124,
                  mobileHorizontal: 18,
                  minViewportHeight: true,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _PasskeyIntroduction(relyingPartyId: data.relyingPartyId),
                      const SizedBox(height: 20),
                      if (data.items.isEmpty)
                        const _PasskeyEmptyState()
                      else
                        for (
                          var index = 0;
                          index < data.items.length;
                          index++
                        ) ...[
                          _PasskeyRow(
                            passkey: data.items[index],
                            revoking: _revokingId == data.items[index].id,
                            onRevoke: data.items[index].isActive
                                ? () => _confirmRevoke(data.items[index])
                                : null,
                          ),
                          if (index < data.items.length - 1)
                            const SizedBox(height: 10),
                        ],
                      const SizedBox(height: 24),
                      _PasskeyAddButton(
                        loading: _registering,
                        enabled:
                            data.canRegister &&
                            (availability.valueOrNull ?? false) &&
                            !_registering &&
                            _revokingId.isEmpty,
                        onPressed: _beginRegistration,
                      ),
                      if (!data.enabled) ...[
                        const SizedBox(height: 12),
                        _PasskeyInlineNotice(
                          text: l10n.passkeyDisabledByProvider,
                        ),
                      ] else if (!data.canRegister &&
                          data.items.where((item) => item.isActive).length >=
                              data.maxPasskeys) ...[
                        const SizedBox(height: 12),
                        _PasskeyInlineNotice(
                          text: l10n.passkeyLimitReached(data.maxPasskeys),
                        ),
                      ] else if (availability.hasValue &&
                          !(availability.valueOrNull ?? false)) ...[
                        const SizedBox(height: 12),
                        _PasskeyInlineNotice(text: l10n.passkeyUnsupported),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _beginRegistration() async {
    if (_registering || _revokingId.isNotEmpty) return;
    final name = await _requestPasskeyName();
    if (!mounted || name == null) return;

    setState(() => _registering = true);
    try {
      await ref.read(customerPasskeyRepositoryProvider).register(name: name);
      ref.invalidate(customerPasskeysProvider);
      if (!mounted) return;
      ref
          .read(appAlertControllerProvider.notifier)
          .show(
            title: context.l10n.passkeyAddedTitle,
            message: context.l10n.passkeyAddedMessage,
            button: context.l10n.appAlertDefaultButton,
            variant: AppAlertVariant.info,
          );
    } on PasskeyAuthCancelledException {
      // The customer can safely leave the native registration sheet.
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      _showError(_passkeyFailureMessage(error, context.l10n));
    } finally {
      if (mounted) setState(() => _registering = false);
    }
  }

  Future<String?> _requestPasskeyName() async {
    final controller = TextEditingController(
      text: context.l10n.passkeyDefaultName,
    );
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        return Padding(
          padding: EdgeInsets.fromLTRB(
            20,
            0,
            20,
            18 + MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(sheetContext).height * 0.9,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.passkeyNameTitle,
                    style: Theme.of(sheetContext).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.passkeyNameDescription,
                    style: Theme.of(sheetContext).textTheme.bodyMedium
                        ?.copyWith(
                          color: Theme.of(
                            sheetContext,
                          ).colorScheme.onSurfaceVariant,
                        ),
                  ),
                  const SizedBox(height: 18),
                  TextField(
                    controller: controller,
                    autofocus: true,
                    maxLength: 120,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) =>
                        _submitName(sheetContext, controller.text),
                    decoration: InputDecoration(
                      labelText: l10n.passkeyNameLabel,
                      prefixIcon: const Icon(Icons.key_rounded),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FilledButton(
                    onPressed: () => _submitName(sheetContext, controller.text),
                    child: Text(l10n.passkeyContinue),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
    controller.dispose();
    return result;
  }

  void _submitName(BuildContext sheetContext, String value) {
    final normalized = value.trim();
    if (normalized.isEmpty) return;
    Navigator.of(sheetContext).pop(normalized);
  }

  Future<void> _confirmRevoke(CustomerPasskey passkey) async {
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) {
        final l10n = sheetContext.l10n;
        final colorScheme = Theme.of(sheetContext).colorScheme;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.passkeyRevokeTitle,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                l10n.passkeyRevokeMessage(passkey.name),
                style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () => Navigator.of(sheetContext).pop(true),
                style: FilledButton.styleFrom(
                  backgroundColor: colorScheme.error,
                  foregroundColor: colorScheme.onError,
                ),
                child: Text(l10n.passkeyRevokeConfirm),
              ),
              TextButton(
                onPressed: () => Navigator.of(sheetContext).pop(false),
                child: Text(l10n.commonCancel),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true || !mounted) return;

    setState(() => _revokingId = passkey.id);
    try {
      await ref.read(customerPasskeyRepositoryProvider).revoke(passkey.id);
      ref.invalidate(customerPasskeysProvider);
      if (!mounted) return;
      ref
          .read(appAlertControllerProvider.notifier)
          .show(
            title: context.l10n.passkeyRevokedTitle,
            message: context.l10n.passkeyRevokedMessage,
            button: context.l10n.appAlertDefaultButton,
            variant: AppAlertVariant.info,
          );
    } catch (error) {
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      _showError(authErrorMessage(error, context.l10n.passkeyRevokeFailed));
    } finally {
      if (mounted) setState(() => _revokingId = '');
    }
  }

  void _showError(String message) {
    ref
        .read(appAlertControllerProvider.notifier)
        .show(
          title: context.l10n.passkeyErrorTitle,
          message: message,
          button: context.l10n.appAlertDefaultButton,
          variant: AppAlertVariant.error,
        );
  }
}

class _PasskeyIntroduction extends StatelessWidget {
  const _PasskeyIntroduction({required this.relyingPartyId});

  final String relyingPartyId;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 48,
          height: 48,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.key_rounded, color: colorScheme.onPrimaryContainer),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                context.l10n.passkeyManagementSubtitle,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 4),
              Text(
                context.l10n.passkeyManagementDescription,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                  height: 1.45,
                ),
              ),
              if (relyingPartyId.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text(
                  relyingPartyId,
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PasskeyRow extends StatelessWidget {
  const _PasskeyRow({
    required this.passkey,
    required this.revoking,
    required this.onRevoke,
  });

  final CustomerPasskey passkey;
  final bool revoking;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final locale = localeTag(l10n.locale);
    final lastUsed = passkey.lastUsedAt == null
        ? l10n.passkeyNeverUsed
        : formatLocalizedDateTime(passkey.lastUsedAt, locale);
    final registered = passkey.registeredAt == null
        ? '-'
        : formatLocalizedDateTime(passkey.registeredAt, locale);
    final title = passkey.name.isEmpty ? l10n.passkeyDefaultName : passkey.name;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: colorScheme.outlineVariant.withValues(alpha: 0.8),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 14, 10, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              passkey.isActive ? Icons.key_rounded : Icons.key_off_rounded,
              color: passkey.isActive
                  ? colorScheme.primary
                  : colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          title,
                          style: Theme.of(context).textTheme.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                      ),
                      _PasskeyStatusBadge(active: passkey.isActive),
                    ],
                  ),
                  if (passkey.authenticator.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      passkey.authenticator,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  Text(
                    '${l10n.passkeyRegisteredAt}: $registered',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${l10n.passkeyLastUsedAt}: $lastUsed',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (passkey.isActive)
              IconButton(
                onPressed: revoking ? null : onRevoke,
                tooltip: l10n.passkeyRevokeConfirm,
                icon: revoking
                    ? CustomerLoadingMark(
                        width: 22,
                        height: 18,
                        color: colorScheme.error,
                        semanticLabel: l10n.commonLoadingData,
                      )
                    : Icon(
                        Icons.delete_outline_rounded,
                        color: colorScheme.error,
                      ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PasskeyStatusBadge extends StatelessWidget {
  const _PasskeyStatusBadge({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final color = active ? const Color(0xFF087F5B) : colorScheme.outline;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        active
            ? context.l10n.passkeyStatusActive
            : context.l10n.passkeyStatusRevoked,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PasskeyEmptyState extends StatelessWidget {
  const _PasskeyEmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(Icons.key_off_rounded, size: 44, color: colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            context.l10n.passkeyEmptyTitle,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 5),
          Text(
            context.l10n.passkeyEmptyDescription,
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _PasskeyAddButton extends StatelessWidget {
  const _PasskeyAddButton({
    required this.loading,
    required this.enabled,
    required this.onPressed,
  });

  final bool loading;
  final bool enabled;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: FilledButton.icon(
        onPressed: enabled ? onPressed : null,
        icon: loading
            ? CustomerLoadingMark(
                width: 22,
                height: 17,
                color: Theme.of(context).colorScheme.onPrimary,
                semanticLabel: context.l10n.commonLoadingData,
              )
            : const Icon(Icons.add_rounded),
        label: Text(
          loading ? context.l10n.passkeyAdding : context.l10n.passkeyAdd,
        ),
      ),
    );
  }
}

class _PasskeyInlineNotice extends StatelessWidget {
  const _PasskeyInlineNotice({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          Icons.info_outline_rounded,
          size: 18,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

class _PasskeyErrorState extends StatelessWidget {
  const _PasskeyErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: Text(context.l10n.commonRetry),
          ),
        ],
      ),
    );
  }
}

String _passkeyFailureMessage(Object error, CustomerLocalizations l10n) {
  return switch (error) {
    ExcludeCredentialsCanNotBeRegisteredException() =>
      l10n.passkeyAlreadyExists,
    DomainNotAssociatedException() => l10n.passkeyDomainNotAssociated,
    DeviceNotSupportedException() ||
    PasskeyUnsupportedException() => l10n.passkeyUnsupported,
    MissingGoogleSignInException() ||
    SyncAccountNotAvailableException() => l10n.passkeyAccountUnavailable,
    TimeoutException() => l10n.passkeyTimeout,
    _ => authErrorMessage(error, l10n.passkeyAddFailed),
  };
}
