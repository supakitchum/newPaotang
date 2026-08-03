import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/auth/auth_controller.dart';
import '../../../core/auth/auth_repository.dart';
import '../../../core/auth/native_line_auth_service.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_gradient_button.dart';
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
    ref.listen<AsyncValue<LineNotificationSettings>>(
      lineNotificationSettingsProvider,
      (previous, next) {
        final error = next.error;
        if (error == null || identical(previous?.error, error)) return;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          _handleOperationalError(error);
        });
      },
    );
    final lineBrandColor = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (bootstrap) {
            for (final provider in bootstrap.authProviders) {
              if (normalizeSocialAuthProvider(provider.provider) == 'line') {
                return provider.brandColor ??
                    provider.buttonBackgroundColor ??
                    Theme.of(context).colorScheme.tertiary;
              }
            }
            return Theme.of(context).colorScheme.tertiary;
          },
          orElse: () => Theme.of(context).colorScheme.tertiary,
        );
    return AppShell(
      title: l10n.profileLineNotifications,
      currentPath: '/profile/line-notifications',
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: false,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: settings.when(
        data: (data) {
          if (!data.lineAvailable) {
            return _LineContentSheet(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  CustomerPageBody(
                    top: 16,
                    bottom: 40,
                    mobileHorizontal: 14,
                    minViewportHeight: true,
                    child: _WarningCard(
                      title: l10n.profileLineStoreUnavailableTitle,
                      message: l10n.profileLineStoreUnavailableMessage,
                    ),
                  ),
                ],
              ),
            );
          }
          return _LineContentSheet(
            child: Column(
              children: [
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      CustomerPageBody(
                        top: 16,
                        bottom: 28,
                        mobileHorizontal: 16,
                        minViewportHeight: true,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            if (_noticeMessage.isNotEmpty) ...[
                              _LineNoticeCard(
                                message: _noticeMessage,
                                isError: _noticeIsError,
                              ),
                              const SizedBox(height: 16),
                            ],
                            _HeaderCard(
                              settings: data,
                              brandColor: lineBrandColor,
                            ),
                            const SizedBox(height: 16),
                            if (data.identity != null)
                              _NotificationToggleCard(
                                identity: data.identity!,
                                brandColor: lineBrandColor,
                                saving: _saving,
                                onChanged: (value) => _saveToggle(value),
                              ),
                            if (data.identity != null)
                              const SizedBox(height: 16),
                            const _LineEventsCard(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                _LineActionFooter(
                  settings: data,
                  brandColor: lineBrandColor,
                  saving: _saving,
                  connecting: _connecting,
                  onConnect: _connectLine,
                  onAddFriend: () => _openUrl(data.addFriendUrl),
                  onDisconnect: _disconnect,
                ),
              ],
            ),
          );
        },
        loading: () => _LineContentSheet(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              CustomerPageBody(
                top: 16,
                bottom: 128,
                mobileHorizontal: 14,
                minViewportHeight: true,
                child: Column(
                  children: [
                    _LineSkeletonCard(lines: 3),
                    SizedBox(height: 12),
                    _LineSkeletonCard(lines: 2),
                  ],
                ),
              ),
            ],
          ),
        ),
        error: (error, __) => _LineContentSheet(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              CustomerPageBody(
                top: 16,
                bottom: 128,
                mobileHorizontal: 14,
                minViewportHeight: true,
                child: _ErrorState(
                  message: authErrorMessage(error, l10n.profileLineLoadFailed),
                  onRetry: () =>
                      ref.invalidate(lineNotificationSettingsProvider),
                ),
              ),
            ],
          ),
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
      final nativeResult = await ref
          .read(nativeLineAuthServiceProvider)
          .authenticate(
            purpose: 'link',
            redirect: '/profile/line-notifications',
            auth: true,
            promptToAddOfficialAccount: true,
          );
      if (!mounted) return;
      if (nativeResult != null) {
        final session = nativeResult.session;
        if (session == null) {
          throw StateError(
            nativeResult.message.isEmpty
                ? 'LINE account could not be connected.'
                : nativeResult.message,
          );
        }
        ref.read(authControllerProvider).applySession(session);
        ref.invalidate(lineNotificationSettingsProvider);
        _setNotice(context.l10n.profileLineConnectedTitle, isError: false);
        return;
      }

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
    } on NativeLineLoginCancelled {
      return;
    } catch (error) {
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (mounted) {
        _setNotice(authErrorMessage(error, connectFailedMessage));
      }
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
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
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
      if (!mounted) return;
      if (await _handleOperationalError(error)) return;
      if (mounted) {
        _setNotice(authErrorMessage(error, disconnectFailedMessage));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _openUrl(String value) async {
    final missingUrlMessage = context.l10n.profileLineMissingUrl;
    final uri = Uri.tryParse(value);
    if (!isSafeExternalLinkUri(uri)) {
      _setNotice(missingUrlMessage);
      return;
    }
    try {
      final opened = await ref.read(customerLinkLauncherProvider).openExternal(
            uri!,
            preferSameWindowInLine: true,
          );
      if (!opened) _setNotice(missingUrlMessage);
    } catch (_) {
      _setNotice(missingUrlMessage);
    }
  }

  void _setNotice(String message, {bool isError = true}) {
    if (!mounted) return;
    setState(() {
      _noticeMessage = message;
      _noticeIsError = isError;
    });
  }

  Future<bool> _handleOperationalError(Object error) {
    return handleCustomerOperationalError(
      ref: ref,
      context: context,
      error: error,
    );
  }
}

class _LineContentSheet extends StatelessWidget {
  const _LineContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: child,
    );
  }
}

class _LineActionFooter extends StatelessWidget {
  const _LineActionFooter({
    required this.settings,
    required this.brandColor,
    required this.saving,
    required this.connecting,
    required this.onConnect,
    required this.onAddFriend,
    required this.onDisconnect,
  });

  final LineNotificationSettings settings;
  final Color brandColor;
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
      key: const ValueKey('line-action-footer'),
      decoration: BoxDecoration(
        color: colorScheme.surface.withValues(alpha: 0.98),
        border: Border(top: BorderSide(color: colorScheme.outlineVariant)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, -12),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            CustomerGradientButton(
              key: const ValueKey('line-connect-action'),
              onPressed:
                  connecting || !settings.lineAvailable ? null : onConnect,
              height: 47,
              fontSize: 14,
              fontWeight: FontWeight.w600,
              shadow: false,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (connecting) ...[
                    SizedBox.square(
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
                    ),
                    const SizedBox(width: 8),
                  ],
                  Text(
                    settings.isConnected
                        ? l10n.profileLineReconnect
                        : l10n.profileLineConnect,
                  ),
                ],
              ),
            ),
            if (needsAddFriend) ...[
              const SizedBox(height: 8),
              _LineFooterAction(
                key: const ValueKey('line-add-friend-action'),
                label: l10n.profileLineAddFriend,
                icon: Icons.person_add_alt_1_outlined,
                onPressed: onAddFriend,
                foreground: brandColor,
                background: Color.lerp(
                      brandColor,
                      colorScheme.surface,
                      0.9,
                    ) ??
                    _lineSuccessTint(colorScheme),
                minHeight: 42,
              ),
            ],
            if (settings.isConnected) ...[
              const SizedBox(height: 4),
              _LineFooterAction(
                label: l10n.profileLineDisconnect,
                onPressed: saving ? null : onDisconnect,
                foreground: colorScheme.onSurfaceVariant,
                background: Colors.transparent,
                minHeight: 34,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _LineFooterAction extends StatelessWidget {
  const _LineFooterAction({
    required this.label,
    required this.onPressed,
    required this.foreground,
    required this.background,
    required this.minHeight,
    super.key,
    this.icon,
  });

  final String label;
  final VoidCallback? onPressed;
  final Color foreground;
  final Color background;
  final double minHeight;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) ...[
                    Icon(icon, color: foreground, size: 18),
                    const SizedBox(width: 7),
                  ],
                  Text(
                    label,
                    style: TextStyle(
                      color: enabled
                          ? foreground
                          : foreground.withValues(alpha: 0.48),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderCard extends StatelessWidget {
  const _HeaderCard({required this.settings, required this.brandColor});

  final LineNotificationSettings settings;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final identity = settings.identity;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('line-account-card'),
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LineAvatar(
                  pictureUrl: identity?.pictureUrl ?? '',
                  connected: settings.isConnected,
                  brandColor: brandColor,
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          height: 1.3,
                        ).copyWith(color: brandColor),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        settings.isConnected
                            ? l10n.profileLineConnectedTitle
                            : l10n.profileLineNotConnectedTitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: colorScheme.onSurface,
                              fontSize: 19,
                              fontWeight: FontWeight.w600,
                              height: 1.3,
                            ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                _ConnectionBadge(
                  label: Text(
                    settings.isConnected
                        ? l10n.profileLineReady
                        : l10n.profileLineNotLinked,
                  ),
                  connected: settings.isConnected,
                  brandColor: brandColor,
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              identity?.displayName.isNotEmpty == true
                  ? identity!.displayName
                  : l10n.profileLineConnectOnce,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.55,
              ),
            ),
            const SizedBox(height: 18),
            Divider(height: 1, color: colorScheme.outlineVariant),
            _StatusRow(
              icon: Icons.notifications_none_rounded,
              label: l10n.profileLineNotificationStatus,
              value: identity?.notificationEnabled == true
                  ? l10n.profileLineNotificationOn
                  : l10n.profileLineNotificationOff,
              active: identity?.notificationEnabled == true,
              brandColor: brandColor,
            ),
            Divider(height: 1, color: colorScheme.outlineVariant),
            _StatusRow(
              icon: Icons.person_add_alt_1_outlined,
              label: l10n.profileLineFriendStatus,
              value: identity?.friendFlag == true
                  ? l10n.profileLineFriendAdded
                  : l10n.profileLineFriendMissing,
              active: identity?.friendFlag == true,
              brandColor: brandColor,
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
    required this.brandColor,
    required this.saving,
    required this.onChanged,
  });

  final LineIdentity identity;
  final Color brandColor;
  final bool saving;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: _lineSurfaceDecoration(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 17, 14, 17),
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
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    l10n.profileLineToggleSubtitle,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),
            _LineSwitch(
              value: identity.notificationEnabled,
              onChanged: saving ? null : onChanged,
              activeColor: brandColor,
            ),
          ],
        ),
      ),
    );
  }
}

class _LineSwitch extends StatelessWidget {
  const _LineSwitch({
    required this.value,
    required this.onChanged,
    required this.activeColor,
  });

  static const switchKey = Key('line_notification_switch');

  final bool value;
  final ValueChanged<bool>? onChanged;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final enabled = onChanged != null;
    final colorScheme = Theme.of(context).colorScheme;
    return Semantics(
      toggled: value,
      enabled: enabled,
      label: context.l10n.profileLineToggleTitle,
      child: MouseRegion(
        cursor: enabled ? SystemMouseCursors.click : MouseCursor.defer,
        child: GestureDetector(
          key: switchKey,
          behavior: HitTestBehavior.opaque,
          onTap: enabled ? () => onChanged!(!value) : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 56,
            height: 32,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: value ? activeColor : colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
            child: AnimatedAlign(
              duration: const Duration(milliseconds: 200),
              alignment: value ? Alignment.centerRight : Alignment.centerLeft,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colorScheme.surface,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: colorScheme.shadow.withValues(alpha: 0.18),
                      blurRadius: 7,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const SizedBox.square(dimension: 26),
              ),
            ),
          ),
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
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.profileLineEventsTitle,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: colorScheme.onSurface,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
            ),
            const SizedBox(height: 5),
            Text(
              l10n.profileLineEventsSubtitle,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 12),
            for (var index = 0; index < events.length; index++) ...[
              _LineEventRow(icon: events[index].$1, label: events[index].$2),
              if (index < events.length - 1)
                Divider(
                  height: 1,
                  indent: 46,
                  color: colorScheme.outlineVariant,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StatusRow extends StatelessWidget {
  const _StatusRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.active,
    required this.brandColor,
  });

  final IconData icon;
  final String label;
  final String value;
  final bool active;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 13),
      child: Row(
        children: [
          Icon(icon, color: colorScheme.onSurfaceVariant, size: 21),
          const SizedBox(width: 11),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color: active ? brandColor : colorScheme.outline,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              value,
              style: TextStyle(
                color: active ? brandColor : colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
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
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: TextStyle(
                      color: colorScheme.onSurfaceVariant,
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      height: 1.55,
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
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  height: 1.5,
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
  const _LineAvatar({
    required this.pictureUrl,
    required this.connected,
    required this.brandColor,
  });

  final String pictureUrl;
  final bool connected;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: ColoredBox(
        color: connected
            ? Color.lerp(brandColor, colorScheme.surface, 0.9) ??
                _lineSuccessTint(colorScheme)
            : _linePrimaryTint(colorScheme),
        child: SizedBox.square(
          dimension: 56,
          child: pictureUrl.isNotEmpty
              ? Image.network(pictureUrl, fit: BoxFit.cover)
              : Icon(
                  Icons.chat_bubble,
                  color: connected ? brandColor : colorScheme.onSurfaceVariant,
                  size: 31,
                ),
        ),
      ),
    );
  }
}

class _ConnectionBadge extends StatelessWidget {
  const _ConnectionBadge({
    required this.label,
    required this.connected,
    required this.brandColor,
  });

  final Widget label;
  final bool connected;
  final Color brandColor;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      key: const ValueKey('line-connection-badge'),
      decoration: BoxDecoration(
        color: connected
            ? Color.lerp(brandColor, colorScheme.surface, 0.9) ??
                _lineSuccessTint(colorScheme)
            : _lineWarningTint(colorScheme),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 7),
        child: DefaultTextStyle.merge(
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: connected ? brandColor : colorScheme.onTertiaryContainer,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            height: 1.1,
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          DecoratedBox(
            decoration: BoxDecoration(
              color: _linePrimaryTint(colorScheme),
              shape: BoxShape.circle,
            ),
            child: SizedBox.square(
              dimension: 34,
              child: Icon(icon, color: colorScheme.primary, size: 18),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w400,
                height: 1.4,
              ),
            ),
          ),
        ],
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
  final resolvedBorderColor =
      borderColor ?? colorScheme.outlineVariant.withValues(alpha: 0.88);
  return BoxDecoration(
    color: color ?? colorScheme.surface,
    border: Border.all(color: resolvedBorderColor),
    borderRadius: BorderRadius.circular(8),
    boxShadow: [
      BoxShadow(
        color: colorScheme.shadow.withValues(alpha: 0.05),
        blurRadius: 18,
        offset: const Offset(0, 6),
      ),
    ],
  );
}
