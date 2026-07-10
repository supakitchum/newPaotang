import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/line_notification_models.dart';
import '../data/line_notification_repository.dart';

Color _linePrimaryTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.primary, colorScheme.surface, 0.88) ??
    colorScheme.primary.withValues(alpha: 0.12);

Color _lineSuccessTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiaryContainer, colorScheme.surface, 0.36) ??
    colorScheme.tertiaryContainer.withValues(alpha: 0.64);

Color _lineWarningTint(ColorScheme colorScheme) =>
    Color.lerp(colorScheme.tertiaryContainer, colorScheme.surface, 0.18) ??
    colorScheme.tertiaryContainer.withValues(alpha: 0.82);

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
  String _noticeMessage = '';
  bool _noticeIsError = true;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final settings = ref.watch(lineNotificationSettingsProvider);
    return AppShell(
      title: l10n.profileLineNotifications,
      currentPath: '/profile',
      sensitive: true,
      fullScreen: true,
      child: settings.when(
        data: (data) => Column(
          children: [
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _LineHero(onBack: () => context.go('/profile')),
                  _LineContentSheet(
                    child: CustomerPageBody(
                      top: 16,
                      bottom: 20,
                      mobileHorizontal: 14,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (_noticeMessage.isNotEmpty) ...[
                            _LineNoticeCard(
                              message: _noticeMessage,
                              isError: _noticeIsError,
                            ),
                            const SizedBox(height: 12),
                          ],
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
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            _LineActionFooter(
              settings: data,
              saving: _saving,
              connecting: _connecting,
              onConnect: _connectLine,
              onAddFriend: () => _openUrl(data.addFriendUrl),
              onDisconnect: _disconnect,
            ),
          ],
        ),
        loading: () => ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _LineHero(onBack: () => context.go('/profile')),
            _LineContentSheet(
              child: CustomerPageBody(
                top: 16,
                bottom: 128,
                mobileHorizontal: 14,
                child: Column(
                  children: [
                    _LineSkeletonCard(lines: 3),
                    SizedBox(height: 12),
                    _LineSkeletonCard(lines: 2),
                  ],
                ),
              ),
            ),
          ],
        ),
        error: (error, __) => ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            _LineHero(onBack: () => context.go('/profile')),
            _LineContentSheet(
              child: CustomerPageBody(
                top: 16,
                bottom: 128,
                mobileHorizontal: 14,
                child: _ErrorState(
                  message: authErrorMessage(error, l10n.profileLineLoadFailed),
                  onRetry: () =>
                      ref.invalidate(lineNotificationSettingsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _connectLine() async {
    final connectFailedMessage = context.l10n.profileLineConnectFailed;
    final missingUrlMessage = context.l10n.profileLineMissingUrl;
    setState(() {
      _connecting = true;
      _noticeMessage = '';
    });
    try {
      final url = await ref.read(authRepositoryProvider).socialLoginUrl(
            'line',
            redirect: '/profile/line-notifications',
            callbackUsesAuth: true,
          );
      final uri = Uri.tryParse(url);
      if (!isSafeSocialLoginUri(uri)) {
        _setNotice(missingUrlMessage);
        return;
      }
      final opened =
          await ref.read(customerLinkLauncherProvider).openSocialLogin(
                'line',
                uri!,
              );
      if (!opened) _setNotice(missingUrlMessage);
    } catch (error) {
      if (mounted) _setNotice(authErrorMessage(error, connectFailedMessage));
    } finally {
      if (mounted) setState(() => _connecting = false);
    }
  }

  Future<void> _saveToggle(bool enabled) async {
    final saveFailedMessage = context.l10n.profileLineSaveFailed;
    setState(() {
      _saving = true;
      _noticeMessage = '';
    });
    try {
      await ref
          .read(lineNotificationRepositoryProvider)
          .updateNotificationEnabled(enabled);
      ref.invalidate(lineNotificationSettingsProvider);
    } catch (error) {
      if (mounted) _setNotice(authErrorMessage(error, saveFailedMessage));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _disconnect() async {
    final disconnectedMessage = context.l10n.profileLineDisconnected;
    final disconnectFailedMessage = context.l10n.profileLineDisconnectFailed;
    setState(() {
      _saving = true;
      _noticeMessage = '';
    });
    try {
      await ref.read(lineNotificationRepositoryProvider).disconnect();
      ref.invalidate(lineNotificationSettingsProvider);
      if (mounted) _setNotice(disconnectedMessage, isError: false);
    } catch (error) {
      if (mounted) _setNotice(authErrorMessage(error, disconnectFailedMessage));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUrl(String value) async {
    final uri = Uri.tryParse(value);
    if (!isSafeExternalLinkUri(uri)) {
      _setNotice(context.l10n.profileLineMissingUrl);
      return;
    }
    await ref.read(customerLinkLauncherProvider).openExternal(
          uri!,
          preferSameWindowInLine: true,
        );
  }

  void _setNotice(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _noticeMessage = message;
      _noticeIsError = isError;
    });
  }
}

class _LineHero extends StatelessWidget {
  const _LineHero({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final topInset = MediaQuery.paddingOf(context).top;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            AppTheme.heroGradientEnd(colorScheme.primary),
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
                padding: EdgeInsets.fromLTRB(
                  horizontal,
                  topInset + 58,
                  horizontal,
                  28,
                ),
                child: Column(
                  children: [
                    _ProfileHeroTitleRow(
                      title: l10n.profileLineNotifications,
                      onBack: onBack,
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        DecoratedBox(
                          decoration: BoxDecoration(
                            color: Color.lerp(
                                  colorScheme.primary,
                                  colorScheme.secondary,
                                  0.35,
                                ) ??
                                colorScheme.primary,
                            border: Border.all(
                              color: colorScheme.onPrimary.withValues(
                                alpha: 0.78,
                              ),
                              width: 3,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            boxShadow: [
                              BoxShadow(
                                color:
                                    colorScheme.shadow.withValues(alpha: 0.14),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: SizedBox.square(
                            dimension: 62,
                            child: Icon(
                              Icons.chat_bubble,
                              color: colorScheme.onPrimary,
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
                                l10n.profileLineHeroTitle,
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
                                l10n.profileLineHeroSubtitle,
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

class _ProfileHeroTitleRow extends StatelessWidget {
  const _ProfileHeroTitleRow({
    required this.title,
    required this.onBack,
  });

  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 42,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            left: 0,
            child: IconButton(
              tooltip: context.l10n.commonBack,
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_ios_new, size: 31),
              color: colorScheme.onPrimary,
              style: IconButton.styleFrom(
                fixedSize: const Size.square(42),
                padding: EdgeInsets.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                backgroundColor: Colors.transparent,
                foregroundColor: colorScheme.onPrimary,
                shape: const CircleBorder(),
              ).copyWith(
                overlayColor: const WidgetStatePropertyAll(Colors.transparent),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 54),
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    height: 1.15,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LineContentSheet extends StatelessWidget {
  const _LineContentSheet({required this.child});

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

class _LineActionFooter extends StatelessWidget {
  const _LineActionFooter({
    required this.settings,
    required this.saving,
    required this.connecting,
    required this.onConnect,
    required this.onAddFriend,
    required this.onDisconnect,
  });

  final LineNotificationSettings settings;
  final bool saving;
  final bool connecting;
  final VoidCallback onConnect;
  final VoidCallback onAddFriend;
  final VoidCallback onDisconnect;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final needsAddFriend = settings.addFriendUrl.isNotEmpty &&
        settings.identity?.friendFlag != true;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.96),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: SafeArea(
        minimum: const EdgeInsets.fromLTRB(16, 12, 16, 108),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 430),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                FilledButton.icon(
                  onPressed:
                      connecting || !settings.lineAvailable ? null : onConnect,
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(47),
                    shape: const StadiumBorder(),
                    textStyle: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  icon: connecting
                      ? SizedBox.square(
                          dimension: 16,
                          child: CustomerLoadingMark(
                            width: 18,
                            height: 14,
                            color: Theme.of(context).colorScheme.onPrimary,
                            trackColor: Theme.of(context)
                                .colorScheme
                                .onPrimary
                                .withValues(alpha: 0.24),
                          ),
                        )
                      : const Icon(Icons.chat_bubble_outline),
                  label: Text(
                    settings.isConnected
                        ? l10n.profileLineReconnect
                        : l10n.profileLineConnect,
                  ),
                ),
                if (needsAddFriend) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: onAddFriend,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(42),
                      backgroundColor: _lineSuccessTint(colorScheme),
                      foregroundColor: colorScheme.tertiary,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    icon: const Icon(Icons.person_add_alt_1_outlined),
                    label: Text(l10n.profileLineAddFriend),
                  ),
                ],
                if (settings.isConnected) ...[
                  const SizedBox(height: 4),
                  TextButton(
                    onPressed: saving ? null : onDisconnect,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(34),
                      foregroundColor: colorScheme.onSurfaceVariant,
                      shape: const StadiumBorder(),
                      textStyle: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    child: Text(l10n.profileLineDisconnect),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.settings});

  final LineNotificationSettings settings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final identity = settings.identity;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                _LineAvatar(
                  pictureUrl: identity?.pictureUrl ?? '',
                  connected: settings.isConnected,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        settings.botDisplayName.isEmpty
                            ? 'LINE OA'
                            : settings.botDisplayName,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w900,
                        ).copyWith(color: colorScheme.tertiary),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        settings.isConnected
                            ? l10n.profileLineConnectedTitle
                            : l10n.profileLineNotConnectedTitle,
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  height: 1.25,
                                ),
                      ),
                      Text(
                        identity?.displayName.isNotEmpty == true
                            ? identity!.displayName
                            : l10n.profileLineConnectOnce,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ),
                ),
                _ConnectionBadge(
                  label: Text(
                    settings.isConnected
                        ? l10n.profileLineReady
                        : l10n.profileLineNotLinked,
                  ),
                  connected: settings.isConnected,
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileLineToggleTitle,
                    style: TextStyle(
                      color: colorScheme.onSurface,
                      fontSize: 17,
                      fontWeight: FontWeight.w900,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.profileLineToggleSubtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
            Switch(
              value: identity.notificationEnabled,
              onChanged: saving ? null : onChanged,
              activeThumbColor: colorScheme.tertiary,
            ),
          ],
        ),
      ),
    );
  }
}

class _LineEventsCard extends StatelessWidget {
  const _LineEventsCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final events = [
      (Icons.account_balance_wallet_outlined, l10n.profileLineEventTopup),
      (Icons.confirmation_number_outlined, l10n.profileLineEventOrder),
      (Icons.stars_outlined, l10n.profileLineEventActivity),
      (Icons.emoji_events_outlined, l10n.profileLineEventReward),
    ];
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: _linePrimaryTint(colorScheme),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SizedBox.square(
                    dimension: 42,
                    child: Icon(
                      Icons.chat_bubble_outline,
                      color: colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
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
                      Text(
                        l10n.profileLineEventsSubtitle,
                        style: TextStyle(
                          color: colorScheme.onSurfaceVariant,
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
            const SizedBox(height: 13),
            for (final event in events)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _LineEventRow(icon: event.$1, label: event.$2),
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _linePrimaryTint(colorScheme),
        border: Border.all(
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.74) ??
              colorScheme.primary.withValues(alpha: 0.22),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(11),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colorScheme.primary, size: 18),
            const SizedBox(height: 7),
            Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              value,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontWeight: FontWeight.w900,
              ),
            ),
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
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(
        context,
        color: _lineWarningTint(colorScheme),
        borderColor: colorScheme.tertiary.withValues(alpha: 0.24),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.warning_amber_rounded,
              color: colorScheme.onTertiaryContainer,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: colorScheme.onTertiaryContainer,
                      fontSize: 14,
                      fontWeight: FontWeight.w900,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    message,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
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
    );
  }
}

class _LineNoticeCard extends StatelessWidget {
  const _LineNoticeCard({
    required this.message,
    required this.isError,
  });

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final foreground = isError ? colorScheme.error : colorScheme.tertiary;
    final background = isError
        ? colorScheme.errorContainer.withValues(alpha: 0.50)
        : _lineSuccessTint(colorScheme);
    final border = isError
        ? colorScheme.error.withValues(alpha: 0.22)
        : colorScheme.tertiary.withValues(alpha: 0.22);
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(
        context,
        color: background,
        borderColor: border,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: foreground,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: TextStyle(
                  color: foreground,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.45,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(l10n.commonRetry),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineAvatar extends StatelessWidget {
  const _LineAvatar({required this.pictureUrl, required this.connected});

  final String pictureUrl;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: connected
            ? _lineSuccessTint(colorScheme)
            : _linePrimaryTint(colorScheme),
        child: SizedBox.square(
          dimension: 56,
          child: pictureUrl.isNotEmpty
              ? Image.network(pictureUrl, fit: BoxFit.cover)
              : Icon(
                  Icons.chat_bubble,
                  color: connected
                      ? colorScheme.tertiary
                      : colorScheme.onSurfaceVariant,
                  size: 31,
                ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({required this.label, required this.connected});

  final Widget label;
  final bool connected;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: connected
            ? _lineSuccessTint(colorScheme)
            : _lineWarningTint(colorScheme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: connected
                ? colorScheme.tertiary
                : colorScheme.onTertiaryContainer,
            fontSize: 11,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
          child: label,
        ),
      ),
    );
  }
}

class _LineEventRow extends StatelessWidget {
  const _LineEventRow({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: _linePrimaryTint(colorScheme),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        child: Row(
          children: [
            Icon(icon, color: colorScheme.primary, size: 19),
            const SizedBox(width: 9),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: colorScheme.onSurface,
                  fontSize: 13,
                  fontWeight: FontWeight.w900,
                  height: 1.25,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LineSkeletonCard extends StatelessWidget {
  const _LineSkeletonCard({required this.lines});

  final int lines;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var index = 0; index < lines; index++) ...[
              FractionallySizedBox(
                widthFactor: index == 0
                    ? 0.62
                    : index == lines - 1
                        ? 0.42
                        : 1,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colorScheme.outlineVariant.withValues(alpha: 0.80),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const SizedBox(height: 13),
                ),
              ),
              if (index < lines - 1) const SizedBox(height: 10),
            ],
          ],
        ),
      ),
    );
  }
}

BoxDecoration _lineSurfaceDecoration(
  BuildContext context, {
  Color? color,
  Color? borderColor,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final resolvedBorderColor = borderColor ??
      (Color.lerp(colorScheme.primary, colorScheme.surface, 0.82) ??
          colorScheme.primary.withValues(alpha: 0.18));
  return BoxDecoration(
    color: color ?? colorScheme.surface,
    border: Border.all(color: resolvedBorderColor),
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: colorScheme.primary.withValues(alpha: 0.07),
        blurRadius: 24,
        offset: const Offset(0, 8),
      ),
    ],
  );
}
