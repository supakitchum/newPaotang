import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';

class AccountDeletionScreen extends ConsumerWidget {
  const AccountDeletionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.accountDeletionTitle,
      currentPath: '/profile',
      sensitive: true,
      child: ListView(
        children: [
          CustomerPageBody(
            child: bootstrap.when(
              data: (data) => _AccountDeletionContent(bootstrap: data),
              loading: () => const _AccountDeletionLoadingCard(),
              error: (_, __) => _AccountDeletionContent(
                bootstrap: MobileBootstrap.fromJson(const {}),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountDeletionContent extends ConsumerWidget {
  const _AccountDeletionContent({required this.bootstrap});

  final MobileBootstrap bootstrap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final requestUri = Uri.tryParse(bootstrap.accountDeletionUrl);
    final supportUri = _supportPhoneUri(bootstrap.supportPhone);
    final canOpenRequest = isSafeExternalLinkUri(requestUri);
    final canCallSupport = isSafeExternalLinkUri(supportUri);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _AccountDeletionHeroCard(
          title: l10n.accountDeletionHeroTitle,
          subtitle: l10n.accountDeletionHeroSubtitle,
        ),
        const SizedBox(height: 12),
        _AccountDeletionInfoCard(
          icon: Icons.info_outline,
          title: l10n.accountDeletionBeforeTitle,
          body: l10n.accountDeletionBeforeBody,
        ),
        const SizedBox(height: 12),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(18),
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
                                ?.copyWith(fontWeight: FontWeight.w900),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.accountDeletionRequestBody,
                            style: TextStyle(
                              color: Colors.grey.shade700,
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
                      ref,
                      requestUri!,
                    ),
                    icon: const Icon(Icons.open_in_new),
                    label: Text(l10n.accountDeletionOpenRequest),
                  )
                else
                  _AccountDeletionNotice(
                    message: l10n.accountDeletionNoOnlineRequest,
                  ),
                if (canCallSupport) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: () => _open(context, ref, supportUri!),
                    icon: const Icon(Icons.phone_outlined),
                    label: Text(l10n.accountDeletionContactSupport),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _open(BuildContext context, WidgetRef ref, Uri uri) async {
    final opened = await ref.read(customerLinkLauncherProvider).openExternal(
          uri,
        );
    if (!opened && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.accountDeletionLaunchFailed)),
      );
    }
  }
}

class _AccountDeletionLoadingCard extends StatelessWidget {
  const _AccountDeletionLoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _AccountDeletionHeroCard extends StatelessWidget {
  const _AccountDeletionHeroCard({
    required this.title,
    required this.subtitle,
  });

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Colors.red.shade50,
              child: Icon(Icons.delete_outline, color: Colors.red.shade700),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AccountDeletionIcon(
              icon: icon,
              color: Colors.orange.shade700,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: TextStyle(
                      color: Colors.grey.shade700,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.orange.shade50,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.orange.shade100),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: TextStyle(
            color: Colors.orange.shade900,
            fontWeight: FontWeight.w800,
            height: 1.35,
          ),
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

Uri? _supportPhoneUri(String phone) {
  final sanitized = phone.trim().replaceAll(RegExp(r'[^\d+]'), '');
  if (sanitized.isEmpty) return null;
  final normalized = sanitized.startsWith('+')
      ? '+${sanitized.substring(1).replaceAll('+', '')}'
      : sanitized.replaceAll('+', '');
  if (normalized.replaceAll('+', '').isEmpty) return null;
  return Uri(scheme: 'tel', path: normalized);
}
