import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';

Color _accountDeletionSurfaceTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.surface, colorScheme.primaryContainer, 0.08) ??
    colorScheme.surface;

Color _accountDeletionSoftOutline(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.outlineVariant, colorScheme.primary, 0.16) ??
    colorScheme.outlineVariant;

Color _accountDeletionWarningTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiaryContainer, colorScheme.surface, 0.18) ??
    colorScheme.tertiaryContainer.withValues(alpha: 0.82);

class AccountDeletionScreen extends ConsumerWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.accountDeletionTitle,
      currentPath: '/profile',
      backPath: '/profile',
      sensitive: true,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const _AccountDeletionHero(),
          _AccountDeletionContentSheet(
            child: CustomerPageBody(
              top: 16,
              bottom: 128,
              mobileHorizontal: 14,
              child: bootstrap.when(
                data: (data) => _AccountDeletionContent(bootstrap: data),
                loading: () => const _AccountDeletionLoadingCard(),
                error: (_, __) => _AccountDeletionContent(
                  bootstrap: MobileBootstrap.fromJson(const {}),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDeletionContent extends ConsumerStatefulWidget {
  const _AccountDeletionContent({required this.bootstrap});

  final MobileBootstrap bootstrap;

  @override
  ConsumerState<_AccountDeletionContent> createState() =>
      _AccountDeletionContentState();
}

class _AccountDeletionContentState
    extends ConsumerState<_AccountDeletionContent> {
  String _noticeMessage = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final requestUri = Uri.tryParse(widget.bootstrap.accountDeletionUrl);
    final supportUri = _supportPhoneUri(widget.bootstrap.supportPhone);
    final supportEmailUri = _supportEmailUri(widget.bootstrap.supportEmail);
    final supportUrlUri = _supportUrlUri(widget.bootstrap.supportUrl);
    final supportPhone = widget.bootstrap.supportPhone.trim();
    final supportEmail = widget.bootstrap.supportEmail.trim();
    final supportUrl = widget.bootstrap.supportUrl.trim();
    final canOpenRequest = isSafeExternalLinkUri(requestUri);
    final canCallSupport = isSafeExternalLinkUri(supportUri);
    final canEmailSupport = !canCallSupport &&
        supportEmail.isNotEmpty &&
        isSafeExternalLinkUri(supportEmailUri);
    final canOpenSupportUrl = !canCallSupport &&
        !canEmailSupport &&
        supportUrl.isNotEmpty &&
        isSafeExternalLinkUri(supportUrlUri);
    final supportLabel = canCallSupport
        ? l10n.accountDeletionContactSupportWithPhone(supportPhone)
        : canEmailSupport
            ? l10n.accountDeletionContactSupportWithEmail(supportEmail)
            : canOpenSupportUrl
                ? l10n.accountDeletionContactSupportOnline
                : l10n.accountDeletionContactSupport;
    final supportActionUri = canCallSupport
        ? supportUri
        : canEmailSupport
            ? supportEmailUri
            : canOpenSupportUrl
                ? supportUrlUri
                : null;
    final supportIcon = canCallSupport
        ? Icons.phone_outlined
        : canEmailSupport
            ? Icons.mail_outline
            : Icons.open_in_new;
    final showSupportAction = supportActionUri != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountDeletionInfoCard(
          icon: Icons.info_outline,
          title: l10n.accountDeletionBeforeTitle,
          body: l10n.accountDeletionBeforeBody,
        ),
        if (_noticeMessage.isNotEmpty) ...[
          const SizedBox(height: 12),
          _AccountDeletionInlineNotice(message: _noticeMessage),
        ],
        const SizedBox(height: 12),
        _AccountDeletionSurface(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _AccountDeletionIcon(
                      icon: Icons.support_agent_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.accountDeletionRequestTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colorScheme.onSurface,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w900,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.accountDeletionRequestBody,
                            style: TextStyle(
                              color: colorScheme.onSurfaceVariant,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (canOpenRequest)
                  FilledButton.icon(
                    onPressed: () => _open(
                      context,
                      requestUri!,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.accountDeletionOpenRequest),
                    style: _accountDeletionPrimaryButtonStyle(context),
                  )
                else
                  _AccountDeletionNotice(
                    message: l10n.accountDeletionNoOnlineRequest,
                  ),
                if (showSupportAction) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _open(context, supportActionUri),
                    icon: Icon(supportIcon),
                    label: Text(supportLabel),
                    style: _accountDeletionOutlineButtonStyle(context),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, Uri uri) async {
    setState(() => _noticeMessage = '');
    final opened = await ref.read(customerLinkLauncherProvider).openExternal(
          uri,
        );
    if (!opened && context.mounted) {
      setState(() {
        _noticeMessage = context.l10n.accountDeletionLaunchFailed;
      });
    }
  }
}

class _AccountDeletionLoadingCard extends StatelessWidget {
  const _AccountDeletionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const _AccountDeletionSurface(
      child: Padding(
        padding: EdgeInsets.all(18),
        child: Column(
          children: [
            _AccountDeletionSkeletonLine(widthFactor: 0.72, height: 16),
            SizedBox(height: 12),
            _AccountDeletionSkeletonLine(widthFactor: 1, height: 12),
            SizedBox(height: 8),
            _AccountDeletionSkeletonLine(widthFactor: 0.84, height: 12),
            SizedBox(height: 18),
            _AccountDeletionSkeletonLine(widthFactor: 1, height: 48),
          ],
        ),
      ),
    );
  }
}

class _AccountDeletionHero extends StatelessWidget {
  const _AccountDeletionHero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                colorScheme.primary,
          ],
        ),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final horizontal = constraints.maxWidth >= 720 ? 28.0 : 18.0;
          return Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 920),
              child: Padding(
                padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 28),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: colorScheme.errorContainer,
                        border: Border.all(
                          color: colorScheme.onPrimary.withValues(alpha: 0.68),
                          width: 2,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox.square(
                        dimension: 62,
                        child: Icon(
                          Icons.delete_outline,
                          color: colorScheme.error,
                          size: 34,
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.accountDeletionHeroTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: colorScheme.onPrimary,
                                  fontWeight: FontWeight.w900,
                                  height: 1.18,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.accountDeletionHeroSubtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.92,
                              ),
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              height: 1.45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AccountDeletionContentSheet extends StatelessWidget {
  const _AccountDeletionContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colorScheme.primary),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: child,
      ),
    );
  }
}

class _AccountDeletionInfoCard extends StatelessWidget {
  const _AccountDeletionInfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _AccountDeletionSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AccountDeletionIcon(
              icon: icon,
              color: colorScheme.tertiary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurface,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      height: 1.45,
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

class _AccountDeletionNotice extends StatelessWidget {
  const _AccountDeletionNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _accountDeletionWarningTint(colorScheme),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.tertiary.withValues(alpha: 0.24),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: colorScheme.onTertiaryContainer,
            fontSize: 13,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _AccountDeletionSurface extends StatelessWidget {
  const _AccountDeletionSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _accountDeletionSurfaceTint(colorScheme),
        border: Border.all(color: _accountDeletionSoftOutline(colorScheme)),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.08),
            blurRadius: 28,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _AccountDeletionSkeletonLine extends StatelessWidget {
  const _AccountDeletionSkeletonLine({
    required this.widthFactor,
    required this.height,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.outlineVariant.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class _AccountDeletionInlineNotice extends StatelessWidget {
  const _AccountDeletionInlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.50),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountDeletionIcon extends StatelessWidget {
  const _AccountDeletionIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 22,
      backgroundColor: color.withAlpha(24),
      child: Icon(icon, color: color),
    );
  }
}

ButtonStyle _accountDeletionPrimaryButtonStyle(BuildContext context) {
  return FilledButton.styleFrom(
    minimumSize: const Size.fromHeight(52),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w900),
  );
}

ButtonStyle _accountDeletionOutlineButtonStyle(BuildContext context) {
  final color = Theme.of(context).colorScheme.primary;
  return OutlinedButton.styleFrom(
    foregroundColor: color,
    side: BorderSide(color: color.withValues(alpha: 0.28)),
    minimumSize: const Size.fromHeight(50),
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
    textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w900),
  );
}

Uri? _supportPhoneUri(String phone) {
  final sanitized = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (sanitized.isEmpty) return null;
  final normalized = sanitized.startsWith('+')
      ? '+${sanitized.substring(1).replaceAll('+', '')}'
      : sanitized.replaceAll('+', '');
  if (normalized.replaceAll('+', '').isEmpty) return null;
  return Uri(scheme: 'tel', path: normalized);
}

Uri? _supportEmailUri(String email) {
  final normalized = email.trim();
  if (normalized.isEmpty || normalized.contains(RegExp(r'\s'))) return null;
  if (!normalized.contains('@')) return null;
  return Uri(scheme: 'mailto', path: normalized);
}

Uri? _supportUrlUri(String url) {
  final uri = Uri.tryParse(url.trim());
  return uri?.scheme.toLowerCase() == 'https' && isSafeExternalLinkUri(uri)
      ? uri
      : null;
}
