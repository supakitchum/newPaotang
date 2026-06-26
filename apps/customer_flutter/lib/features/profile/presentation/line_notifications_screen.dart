import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/line_notification_models.dart';
import '../data/line_notification_repository.dart';

class LineNotificationsScreen extends ConsumerStatefulWidget {
  const LineNotificationsScreen({super.key});

  @override
  ConsumerState<LineNotificationsScreen> createState() =>
      _LineNotificationsScreenState();
}

class _LineNotificationsScreenState
    extends ConsumerState<LineNotificationsScreen> {
  bool _saving = false;
  bool _connecting = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(lineNotificationSettingsProvider);
    return AppShell(
      title: l10n.profileLineNotifications,
      currentPath: '/profile',
      sensitive: true,
      child: settings.when(
        data: (data) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
          children: [
            _HeaderCard(settings: data),
            const SizedBox(height: 12),
            if (data.identity != null)
              _NotificationToggleCard(
                identity: data.identity!,
                saving: _saving,
                onChanged: (value) => _saveToggle(value),
              ),
            const SizedBox(height: 12),
            const _LineEventsCard(),
            if (!data.lineAvailable) ...[
              const SizedBox(height: 12),
              _WarningCard(
                title: l10n.profileLineStoreUnavailableTitle,
                message: l10n.profileLineStoreUnavailableMessage,
              ),
            ],
            const SizedBox(height: 18),
            FilledButton.icon(
              onPressed: _connecting || !data.lineAvailable
                  ? null
                  : () => _connectLine(),
              icon: _connecting
                  ? const SizedBox.square(
                      dimension: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.chat_bubble_outline),
              label: Text(
                data.isConnected
                    ? l10n.profileLineReconnect
                    : l10n.profileLineConnect,
              ),
            ),
            if (data.addFriendUrl.isNotEmpty &&
                data.identity?.friendFlag != true) ...[
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => _openUrl(data.addFriendUrl),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: Text(l10n.profileLineAddFriend),
              ),
            ],
            if (data.isConnected) ...[
              const SizedBox(height: 10),
              TextButton(
                onPressed: _saving ? null : _disconnect,
                child: Text(l10n.profileLineDisconnect),
              ),
            ],
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          onRetry: () => ref.invalidate(lineNotificationSettingsProvider),
        ),
      ),
    );
  }

  Future<void> _connectLine() async {
    final connectFailedMessage = context.l10n.profileLineConnectFailed;
    setState(() => _connecting = true);
    try {
      final url = await ref.read(authRepositoryProvider).socialLoginUrl('line');
      await _openUrl(url);
    } catch (_) {
      if (mounted) _showSnack(connectFailedMessage);
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _saveToggle(bool enabled) async {
    final saveFailedMessage = context.l10n.profileLineSaveFailed;
    setState(() => _saving = true);
    try {
      await ref
          .read(lineNotificationRepositoryProvider)
          .updateNotificationEnabled(enabled);
      ref.invalidate(lineNotificationSettingsProvider);
    } catch (_) {
      if (mounted) _showSnack(saveFailedMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnect() async {
    final disconnectedMessage = context.l10n.profileLineDisconnected;
    final disconnectFailedMessage = context.l10n.profileLineDisconnectFailed;
    setState(() => _saving = true);
    try {
      await ref.read(lineNotificationRepositoryProvider).disconnect();
      ref.invalidate(lineNotificationSettingsProvider);
      if (mounted) _showSnack(disconnectedMessage);
    } catch (_) {
      if (mounted) _showSnack(disconnectFailedMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (uri == null) {
      _showSnack(context.l10n.profileLineMissingUrl);
      return;
    }
    await ref.read(customerLinkLauncherProvider).openExternal(
          uri,
          preferSameWindowInLine: true,
        );
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.settings});

  final LineNotificationSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final identity = settings.identity;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor:
                      settings.isConnected ? const Color(0xff06c755) : null,
                  backgroundImage: identity?.pictureUrl.isNotEmpty == true
                      ? NetworkImage(identity!.pictureUrl)
                      : null,
                  child: identity?.pictureUrl.isNotEmpty == true
                      ? null
                      : const Icon(Icons.chat_bubble_outline),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.botDisplayName.isEmpty
                            ? 'LINE OA'
                            : settings.botDisplayName,
                        style: const TextStyle(
                          color: Color(0xff06a948),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.isConnected
                            ? l10n.profileLineConnectedTitle
                            : l10n.profileLineNotConnectedTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      Text(
                        identity?.displayName.isNotEmpty == true
                            ? identity!.displayName
                            : l10n.profileLineConnectOnce,
                      ),
                    ],
                  ),
                ),
                Chip(
                  label: Text(
                    settings.isConnected
                        ? l10n.profileLineReady
                        : l10n.profileLineNotLinked,
                  ),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _StatusTile(
                    icon: Icons.notifications_active_outlined,
                    label: l10n.profileLineNotificationStatus,
                    value: identity?.notificationEnabled == true
                        ? l10n.profileLineNotificationOn
                        : l10n.profileLineNotificationOff,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _StatusTile(
                    icon: Icons.person_add_alt_1_outlined,
                    label: l10n.profileLineFriendStatus,
                    value: identity?.friendFlag == true
                        ? l10n.profileLineFriendAdded
                        : l10n.profileLineFriendMissing,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationToggleCard extends StatelessWidget {
  const _NotificationToggleCard({
    required this.identity,
    required this.saving,
    required this.onChanged,
  });

  final LineIdentity identity;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: SwitchListTile(
        value: identity.notificationEnabled,
        onChanged: saving ? null : onChanged,
        title: Text(
          l10n.profileLineToggleTitle,
          style: const TextStyle(fontWeight: FontWeight.w900),
        ),
        subtitle: Text(l10n.profileLineToggleSubtitle),
      ),
    );
  }
}

class _LineEventsCard extends StatelessWidget {
  const _LineEventsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final events = [
      (Icons.account_balance_wallet_outlined, l10n.profileLineEventTopup),
      (Icons.confirmation_number_outlined, l10n.profileLineEventOrder),
      (Icons.stars_outlined, l10n.profileLineEventActivity),
      (Icons.emoji_events_outlined, l10n.profileLineEventReward),
    ];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileLineEventsTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 4),
            Text(l10n.profileLineEventsSubtitle),
            const SizedBox(height: 12),
            for (final event in events)
              ListTile(
                dense: true,
                contentPadding: EdgeInsets.zero,
                leading: Icon(event.$1),
                title: Text(event.$2),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),
            const SizedBox(height: 8),
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _WarningCard extends StatelessWidget {
  const _WarningCard({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.orange.shade50,
      child: ListTile(
        leading:
            Icon(Icons.warning_amber_rounded, color: Colors.orange.shade800),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        subtitle: Text(message),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(l10n.profileLineLoadFailed),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
