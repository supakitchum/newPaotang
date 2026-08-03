import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/customer_social_account_repository.dart';
import '../../../core/auth/native_line_auth_service.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_alert.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../auth/presentation/line_auth_screens.dart';

class SocialAccountsScreen extends ConsumerStatefulWidget {
  const SocialAccountsScreen({super.key});

  @override
  ConsumerState<SocialAccountsScreen> createState() =>
      _SocialAccountsScreenState();
}

class _SocialAccountsScreenState extends ConsumerState<SocialAccountsScreen> {
  String _busyProvider = '';

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(customerSocialAccountsProvider);
    final runtimeProviders =
        ref.watch(mobileBootstrapProvider).valueOrNull?.authProviders ??
        const <SocialAuthProvider>[];
    final l10n = context.l10n;

    return AppShell(
      title: l10n.socialAccountsTitle,
      currentPath: '/profile/social-accounts',
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
        child: accounts.when(
          loading: () => Center(
            child: CustomerLoadingMark(semanticLabel: l10n.commonLoadingData),
          ),
          error: (error, _) => _SocialAccountsError(
            message: authErrorMessage(error, l10n.socialAccountsLoadFailed),
            onRetry: () => ref.invalidate(customerSocialAccountsProvider),
          ),
          data: (items) => RefreshIndicator(
            onRefresh: () async {
              ref.invalidate(customerSocialAccountsProvider);
              await ref.read(customerSocialAccountsProvider.future);
            },
            child: ListView(
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
                      _SocialAccountsIntroduction(
                        connectedCount: items
                            .where((account) => account.linked)
                            .length,
                      ),
                      const SizedBox(height: 18),
                      for (var index = 0; index < items.length; index++) ...[
                        _SocialAccountRow(
                          account: items[index],
                          runtimeProvider: _runtimeProvider(
                            runtimeProviders,
                            items[index].provider,
                          ),
                          busy: _busyProvider == items[index].provider,
                          onConnect: () => _connect(items[index].provider),
                          onUnlink: () => _confirmUnlink(items[index]),
                        ),
                        if (index < items.length - 1)
                          const SizedBox(height: 10),
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

  Future<void> _connect(String provider) async {
    if (_busyProvider.isNotEmpty) return;
    setState(() => _busyProvider = provider);
    try {
      if (normalizeSocialAuthProvider(provider) == 'line') {
        final nativeResult = await ref
            .read(nativeLineAuthServiceProvider)
            .authenticate(
              purpose: 'link',
              redirect: '/profile/social-accounts',
              auth: true,
            );
        if (!mounted) return;
        if (nativeResult != null) {
          ref.invalidate(customerSocialAccountsProvider);
          final completed = await completeSocialAuthentication(
            context: context,
            ref: ref,
            result: nativeResult,
            fallbackRedirect: '/profile/social-accounts',
          );
          if (!mounted || completed) return;
          throw StateError(
            nativeResult.message.isEmpty
                ? 'LINE account could not be connected.'
                : nativeResult.message,
          );
        }
      }

      final url = await ref
          .read(authRepositoryProvider)
          .socialLoginUrl(
            provider,
            redirect: '/profile/social-accounts',
            callbackUsesAuth: true,
          );
      final uri = Uri.tryParse(url);
      if (!isSafeSocialLoginUri(uri)) {
        throw StateError('Social login URL is unavailable.');
      }
      final opened = await ref
          .read(customerLinkLauncherProvider)
          .openSocialLogin(provider, uri!);
      if (!opened) throw StateError('Social login could not be opened.');
    } on NativeLineLoginCancelled {
      return;
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
      _showError(
        authErrorMessage(error, context.l10n.socialAccountsLinkFailed),
      );
    } finally {
      if (mounted) setState(() => _busyProvider = '');
    }
  }

  Future<void> _confirmUnlink(CustomerSocialAccount account) async {
    if (_busyProvider.isNotEmpty) return;
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      useSafeArea: true,
      showDragHandle: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              sheetContext.l10n.socialAccountsUnlinkTitle(
                _providerLabel(account.provider),
              ),
              style: Theme.of(
                sheetContext,
              ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              sheetContext.l10n.socialAccountsUnlinkDescription,
              style: Theme.of(sheetContext).textTheme.bodyMedium?.copyWith(
                color: Theme.of(sheetContext).colorScheme.onSurfaceVariant,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => Navigator.of(sheetContext).pop(true),
              child: Text(sheetContext.l10n.socialAccountsUnlinkConfirm),
            ),
            TextButton(
              onPressed: () => Navigator.of(sheetContext).pop(false),
              child: Text(sheetContext.l10n.commonCancel),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busyProvider = account.provider);
    try {
      await ref
          .read(customerSocialAccountRepositoryProvider)
          .unlink(account.provider);
      ref.invalidate(customerSocialAccountsProvider);
      if (!mounted) return;
      ref
          .read(appAlertControllerProvider.notifier)
          .show(
            title: context.l10n.socialAccountsUnlinkedTitle,
            message: context.l10n.socialAccountsUnlinkedMessage,
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
      _showError(
        authErrorMessage(error, context.l10n.socialAccountsUnlinkFailed),
      );
    } finally {
      if (mounted) setState(() => _busyProvider = '');
    }
  }

  void _showError(String message) {
    ref
        .read(appAlertControllerProvider.notifier)
        .show(
          title: context.l10n.socialAccountsErrorTitle,
          message: message,
          button: context.l10n.appAlertDefaultButton,
          variant: AppAlertVariant.error,
        );
  }
}

class _SocialAccountsIntroduction extends StatelessWidget {
  const _SocialAccountsIntroduction({required this.connectedCount});

  final int connectedCount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.link_rounded, color: colorScheme.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.socialAccountsConnectedCount(connectedCount),
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    context.l10n.socialAccountsDescription,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SocialAccountRow extends StatelessWidget {
  const _SocialAccountRow({
    required this.account,
    required this.runtimeProvider,
    required this.busy,
    required this.onConnect,
    required this.onUnlink,
  });

  final CustomerSocialAccount account;
  final SocialAuthProvider? runtimeProvider;
  final bool busy;
  final VoidCallback onConnect;
  final VoidCallback onUnlink;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final providerColor = runtimeProvider?.brandColor ?? colorScheme.primary;
    final label = runtimeProvider?.label.trim().isNotEmpty == true
        ? runtimeProvider!.label
        : _providerLabel(account.provider);
    final available = runtimeProvider?.enabled ?? false;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            _SocialAccountAvatar(account: account, color: providerColor),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    account.linked
                        ? (account.displayName.isNotEmpty
                              ? account.displayName
                              : context.l10n.socialAccountsConnected)
                        : available
                        ? context.l10n.socialAccountsNotConnected
                        : context.l10n.socialAccountsUnavailable,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: account.linked
                          ? colorScheme.primary
                          : colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (busy)
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            else if (account.linked)
              TextButton(
                onPressed: onUnlink,
                child: Text(context.l10n.socialAccountsUnlink),
              )
            else
              OutlinedButton(
                onPressed: available ? onConnect : null,
                child: Text(context.l10n.socialAccountsConnect),
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialAccountAvatar extends StatelessWidget {
  const _SocialAccountAvatar({required this.account, required this.color});

  final CustomerSocialAccount account;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final fallback = Icon(
      _providerIcon(account.provider),
      color: color,
      size: 25,
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: color.withValues(alpha: 0.10),
        child: SizedBox.square(
          dimension: 46,
          child: account.pictureUrl.isEmpty
              ? fallback
              : Image.network(
                  account.pictureUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}

class _SocialAccountsError extends StatelessWidget {
  const _SocialAccountsError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        CustomerPageBody(
          top: 24,
          bottom: 120,
          mobileHorizontal: 18,
          minViewportHeight: true,
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_outlined, size: 42),
                const SizedBox(height: 12),
                Text(message, textAlign: TextAlign.center),
                const SizedBox(height: 16),
                OutlinedButton(
                  onPressed: onRetry,
                  child: Text(context.l10n.commonRetry),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

SocialAuthProvider? _runtimeProvider(
  List<SocialAuthProvider> providers,
  String provider,
) {
  for (final candidate in providers) {
    if (candidate.provider == provider) return candidate;
  }
  return null;
}

String _providerLabel(String provider) {
  return switch (normalizeSocialAuthProvider(provider)) {
    'google' => 'Google',
    'apple' => 'Apple ID',
    'facebook' => 'Facebook',
    'line' => 'LINE',
    final value => value,
  };
}

IconData _providerIcon(String provider) {
  return switch (normalizeSocialAuthProvider(provider)) {
    'apple' => Icons.apple,
    'facebook' => Icons.facebook,
    'google' => Icons.mail_outline,
    _ => Icons.chat_bubble_outline,
  };
}
