import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/auth/auth_error_message.dart';
import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/biometric_device_models.dart';
import '../data/biometric_device_repository.dart';

final _biometricCapabilityProvider = FutureProvider.autoDispose<bool>((ref) {
  return ref.watch(biometricAuthServiceProvider).canUseBiometric();
});

final _currentBiometricDeviceIdProvider =
    FutureProvider.autoDispose<String?>((ref) {
  return ref.watch(biometricAuthServiceProvider).currentDeviceId();
});

class BiometricDevicesScreen extends ConsumerStatefulWidget {
  const BiometricDevicesScreen({super.key});

  @override
  ConsumerState<BiometricDevicesScreen> createState() =>
      _BiometricDevicesScreenState();
}

class _BiometricDevicesScreenState
    extends ConsumerState<BiometricDevicesScreen> {
  bool _saving = false;
  String? _statusMessage;
  _BiometricStatusKind _statusKind = _BiometricStatusKind.info;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final devices = ref.watch(biometricDevicesProvider);
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final platformKey = ref.watch(customerPlatformKeyProvider);
    final policyEnabled = bootstrap.maybeWhen(
      data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
      orElse: () => false,
    );
    final capability = policyEnabled
        ? ref.watch(_biometricCapabilityProvider)
        : const AsyncValue<bool>.data(false);
    final currentDeviceId = policyEnabled
        ? ref.watch(_currentBiometricDeviceIdProvider).valueOrNull
        : null;

    return AppShell(
      title: l10n.profileBiometrics,
      currentPath: '/profile/biometrics',
      backPath: '/profile',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(_biometricCapabilityProvider);
          ref.invalidate(_currentBiometricDeviceIdProvider);
          final refreshedDevices = ref.refresh(biometricDevicesProvider.future);
          await refreshedDevices;
        },
        child: ListView(
          padding: EdgeInsets.zero,
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const _BiometricHero(),
            _BiometricContentSheet(
              child: CustomerPageBody(
                top: 16,
                bottom: 128,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!policyEnabled)
                      _EnableBiometricCard(
                        canUseBiometric: false,
                        loadingCapability: bootstrap.isLoading,
                        saving: _saving,
                        onEnable: null,
                      )
                    else
                      _EnableBiometricCard(
                        canUseBiometric: capability.valueOrNull == true,
                        loadingCapability: capability.isLoading,
                        saving: _saving,
                        onEnable: capability.valueOrNull == true && !_saving
                            ? _enableBiometric
                            : null,
                      ),
                    const SizedBox(height: 12),
                    if (_statusMessage case final message?) ...[
                      _BiometricStatusPanel(
                        message: message,
                        kind: _statusKind,
                        onDismiss: () {
                          if (mounted) {
                            setState(() => _statusMessage = null);
                          }
                        },
                      ),
                      const SizedBox(height: 12),
                    ],
                    devices.when(
                      data: (items) => _DeviceList(
                        devices: items,
                        currentDeviceId: currentDeviceId,
                        saving: _saving,
                        onRevoke: _revokeDevice,
                      ),
                      loading: () => const _BiometricDeviceLoadingCard(),
                      error: (error, __) => _ErrorCard(
                        message: authErrorMessage(
                          error,
                          l10n.profileBiometricLoadFailed,
                        ),
                        onRetry: () {
                          setState(() => _statusMessage = null);
                          ref.invalidate(biometricDevicesProvider);
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _enableBiometric() async {
    final l10n = context.l10n;
    final enabledMessage = l10n.profileBiometricEnabled;
    final failedMessage = l10n.profileBiometricEnableFailed;
    final platformKey = ref.read(customerPlatformKeyProvider);
    final deviceName = _defaultDeviceName(l10n, platformKey);
    final pin = await _askForPin();
    if (pin == null || pin.length != 6) return;

    setState(() => _saving = true);
    try {
      await ref.read(biometricAuthServiceProvider).registerDevice(
            pin: pin,
            platform: platformKey,
            localizedReason: mobileBiometricPromptReason(
              ref.read(mobileBootstrapProvider).valueOrNull,
              purpose: 'biometric_setup',
              fallback: l10n.profileBiometricSetupReason,
              setup: true,
            ),
            deviceName: deviceName,
          );
      ref.invalidate(biometricDevicesProvider);
      ref.invalidate(_currentBiometricDeviceIdProvider);
      if (mounted) _showStatus(enabledMessage, _BiometricStatusKind.success);
    } catch (error) {
      if (mounted) {
        _showStatus(
          authErrorMessage(error, failedMessage),
          _BiometricStatusKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _revokeDevice(BiometricDevice device) async {
    final l10n = context.l10n;
    final deviceName = _deviceName(device, l10n);
    final revokedMessage = l10n.profileBiometricRevoked;
    final failedMessage = l10n.profileBiometricRevokeFailed;
    final confirm = await showDialog<bool>(
      context: context,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.46),
      builder: (context) => _BiometricRevokeDialog(deviceName: deviceName),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(biometricDeviceRepositoryProvider).revoke(device.id);
      await ref
          .read(biometricAuthServiceProvider)
          .clearLocalDeviceKey(deviceId: device.deviceId);
      ref.invalidate(biometricDevicesProvider);
      ref.invalidate(_currentBiometricDeviceIdProvider);
      if (mounted) _showStatus(revokedMessage, _BiometricStatusKind.success);
    } catch (error) {
      if (mounted) {
        _showStatus(
          authErrorMessage(error, failedMessage),
          _BiometricStatusKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askForPin() {
    return showDialog<String>(
      context: context,
      barrierColor: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.46),
      builder: (context) => const _PinConfirmDialog(),
    );
  }

  String _defaultDeviceName(CustomerLocalizations l10n, String platformKey) {
    return switch (platformKey) {
      'ios' => l10n.profileBiometricDeviceNameIos,
      'android' => l10n.profileBiometricDeviceNameAndroid,
      _ => l10n.profileBiometricDeviceNameFallback,
    };
  }

  void _showStatus(String message, _BiometricStatusKind kind) {
    setState(() {
      _statusMessage = message;
      _statusKind = kind;
    });
  }
}

enum _BiometricStatusKind { success, error, info }

class _PinConfirmDialog extends StatefulWidget {
  const _PinConfirmDialog();

  @override
  State<_PinConfirmDialog> createState() => _PinConfirmDialogState();
}

class _PinConfirmDialogState extends State<_PinConfirmDialog> {
  final FocusNode _focusNode = FocusNode(debugLabel: 'biometric-pin-keypad');
  String _pin = '';
  bool _submitted = false;

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final media = MediaQuery.of(context);
    final compact = media.size.height < 700;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKeyEvent,
        child: _BiometricDialogSurface(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 390),
            child: Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, compact ? 14 : 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      color: Color.lerp(colors.primary, colors.surface, 0.88),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: colors.primary.withValues(alpha: 0.14),
                      ),
                    ),
                    child: SizedBox.square(
                      dimension: 54,
                      child: Icon(
                        Icons.lock_outline,
                        color: colors.primary,
                        size: 28,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Text(
                    l10n.profileBiometricPinDialogTitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.15,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l10n.profileBiometricIntroSubtitle,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                          fontWeight: FontWeight.w700,
                          height: 1.45,
                        ),
                  ),
                  SizedBox(height: compact ? 18 : 24),
                  _BiometricPinIndicator(length: _pin.length),
                  SizedBox(height: compact ? 16 : 22),
                  _BiometricPinKeypad(
                    enabled: !_submitted,
                    compact: compact,
                    onDigit: _appendDigit,
                    onBackspace: _removeDigit,
                  ),
                  SizedBox(height: compact ? 4 : 10),
                  TextButton(
                    onPressed:
                        _submitted ? null : () => Navigator.of(context).pop(),
                    child: Text(l10n.commonCancel),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  KeyEventResult _handleKeyEvent(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _submitted) return KeyEventResult.ignored;
    final digit = _digitFromKey(event.logicalKey);
    if (digit != null) {
      _appendDigit(digit);
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.backspace ||
        event.logicalKey == LogicalKeyboardKey.delete) {
      _removeDigit();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  void _appendDigit(String digit) {
    if (_submitted || _pin.length >= 6 || !RegExp(r'^\d$').hasMatch(digit)) {
      return;
    }
    final next = '$_pin$digit';
    setState(() => _pin = next);
    if (next.length == 6) _submitPin(next);
  }

  void _removeDigit() {
    if (_submitted || _pin.isEmpty) return;
    setState(() => _pin = _pin.substring(0, _pin.length - 1));
  }

  Future<void> _submitPin(String pin) async {
    setState(() => _submitted = true);
    await Future<void>.delayed(const Duration(milliseconds: 90));
    if (mounted) Navigator.of(context).pop(pin);
  }
}

class _BiometricRevokeDialog extends StatelessWidget {
  const _BiometricRevokeDialog({required this.deviceName});

  final String deviceName;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      backgroundColor: Colors.transparent,
      child: _BiometricDialogSurface(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color.lerp(colors.error, colors.surface, 0.88),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: colors.error.withValues(alpha: 0.14),
                        ),
                      ),
                      child: SizedBox.square(
                        dimension: 48,
                        child: Icon(
                          Icons.link_off,
                          color: colors.error,
                          size: 25,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.profileBiometricRevokeDialogTitle,
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                                  color: colors.onSurface,
                                  fontWeight: FontWeight.w900,
                                  height: 1.2,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.profileBiometricRevokeDialogMessage(
                              deviceName,
                            ),
                            style:
                                Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: colors.onSurfaceVariant,
                                      fontWeight: FontWeight.w700,
                                      height: 1.45,
                                    ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).pop(false),
                        child: Text(l10n.commonCancel),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton(
                        onPressed: () => Navigator.of(context).pop(true),
                        child: Text(l10n.commonConfirm),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BiometricHero extends StatelessWidget {
  const _BiometricHero();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final onPrimary = colorScheme.onPrimary;
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
                padding: EdgeInsets.fromLTRB(horizontal, 24, horizontal, 28),
                child: Row(
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: onPrimary.withValues(alpha: 0.16),
                        border: Border.all(
                          color: onPrimary.withValues(alpha: 0.28),
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: SizedBox.square(
                        dimension: 62,
                        child: Icon(
                          Icons.face_retouching_natural,
                          color: onPrimary,
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
                            l10n.profileBiometricIntroTitle,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                                  color: onPrimary,
                                  fontWeight: FontWeight.w900,
                                  height: 1.18,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.profileBiometricIntroSubtitle,
                            maxLines: 3,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: onPrimary.withValues(alpha: 0.92),
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

class _BiometricContentSheet extends StatelessWidget {
  const _BiometricContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(color: colors.primary),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        ),
        child: child,
      ),
    );
  }
}

class _EnableBiometricCard extends StatelessWidget {
  const _EnableBiometricCard({
    required this.canUseBiometric,
    required this.loadingCapability,
    required this.saving,
    required this.onEnable,
  });

  final bool canUseBiometric;
  final bool loadingCapability;
  final bool saving;
  final VoidCallback? onEnable;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final checkingCapability = loadingCapability && !saving;
    final unavailable = !checkingCapability && !canUseBiometric;
    final title = checkingCapability
        ? l10n.commonLoadingData
        : unavailable
            ? l10n.profileBiometricUnavailableTitle
            : l10n.profileBiometricEnableTitle;
    final message = unavailable
        ? l10n.profileBiometricUnavailableMessage
        : l10n.profileBiometricEnableMessage;
    final icon = checkingCapability
        ? Icons.manage_search_outlined
        : unavailable
            ? Icons.phonelink_lock_outlined
            : Icons.verified_user_outlined;
    final tone = unavailable ? colors.error : colors.primary;

    return _BiometricSurface(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  icon,
                  color: tone,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    title,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurfaceVariant,
                    fontWeight: FontWeight.w700,
                    height: 1.4,
                  ),
            ),
            if (checkingCapability) ...[
              const SizedBox(height: 12),
              CustomerLoadingMark(
                width: 112,
                height: 20,
                color: colors.primary,
                trackColor: colors.outlineVariant.withValues(alpha: 0.42),
              ),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: onEnable,
                child: saving
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox.square(
                            dimension: 16,
                            child: CustomerLoadingMark(
                              width: 18,
                              height: 14,
                              color: colors.onPrimary,
                              trackColor:
                                  colors.onPrimary.withValues(alpha: 0.24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(l10n.profileBiometricSaving),
                        ],
                      )
                    : checkingCapability
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox.square(
                                dimension: 16,
                                child: CustomerLoadingMark(
                                  width: 18,
                                  height: 14,
                                  color: colors.onPrimary,
                                  trackColor:
                                      colors.onPrimary.withValues(alpha: 0.24),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(l10n.commonLoadingData),
                            ],
                          )
                        : Text(l10n.profileBiometricEnableButton),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricDeviceLoadingCard extends StatelessWidget {
  const _BiometricDeviceLoadingCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return _BiometricSurface(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: Color.lerp(colors.primary, colors.surface, 0.88),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: colors.primary.withValues(alpha: 0.14),
                    ),
                  ),
                  child: SizedBox.square(
                    dimension: 42,
                    child: Icon(
                      Icons.devices_other_outlined,
                      color: colors.primary,
                      size: 23,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    l10n.commonLoadingData,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          color: colors.onSurface,
                          fontWeight: FontWeight.w900,
                          height: 1.2,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const _BiometricSkeletonLine(widthFactor: 1, height: 13),
            const SizedBox(height: 10),
            const _BiometricSkeletonLine(widthFactor: 0.72, height: 13),
            const SizedBox(height: 18),
            const _BiometricSkeletonLine(widthFactor: 0.48, height: 26),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.currentDeviceId,
    required this.saving,
    required this.onRevoke,
  });

  final List<BiometricDevice> devices;
  final String? currentDeviceId;
  final bool saving;
  final ValueChanged<BiometricDevice> onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = devices.where((device) => device.isActive).toList();
    final revoked = devices.where((device) => !device.isActive).toList();

    if (devices.isEmpty) {
      final colors = Theme.of(context).colorScheme;
      return _BiometricSurface(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              Icon(
                Icons.devices_other_outlined,
                color: colors.primary,
                size: 38,
              ),
              const SizedBox(height: 10),
              Text(
                l10n.profileBiometricEmptyTitle,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                      height: 1.2,
                    ),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.profileBiometricEmptyMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.profileBiometricActiveDevices,
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        if (active.isEmpty)
          _MutedInfoCard(message: l10n.profileBiometricNoActiveDevices)
        else
          for (final device in active) ...[
            _DeviceCard(
              device: device,
              currentDeviceId: currentDeviceId,
              saving: saving,
              onRevoke: () => onRevoke(device),
            ),
            const SizedBox(height: 8),
          ],
        if (revoked.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            l10n.profileBiometricRevokedDevices,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (final device in revoked) ...[
            _DeviceCard(
              device: device,
              currentDeviceId: currentDeviceId,
              saving: saving,
            ),
            const SizedBox(height: 8),
          ],
        ],
      ],
    );
  }
}

class _DeviceCard extends StatelessWidget {
  const _DeviceCard({
    required this.device,
    required this.currentDeviceId,
    required this.saving,
    this.onRevoke,
  });

  final BiometricDevice device;
  final String? currentDeviceId;
  final bool saving;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final isCurrentDevice =
        currentDeviceId != null && currentDeviceId == device.deviceId;
    return _BiometricSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  backgroundColor: device.isActive
                      ? colors.primaryContainer
                      : colors.surfaceContainerHighest,
                  child: Icon(
                    _deviceIcon(device),
                    color: device.isActive
                        ? colors.onPrimaryContainer
                        : colors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _deviceName(device, l10n),
                        style:
                            Theme.of(context).textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w900,
                                ),
                      ),
                      const SizedBox(height: 4),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          _BiometricDevicePill(
                            label: _deviceStatusLabel(device, l10n),
                            color: device.isActive
                                ? colors.primary
                                : colors.onSurfaceVariant,
                          ),
                          if (isCurrentDevice)
                            _BiometricDevicePill(
                              label: l10n.profileBiometricCurrentDevice,
                              color: colors.primary,
                            ),
                          _BiometricDevicePill(
                            label: _platformLabel(device),
                            color: colors.onSurfaceVariant,
                          ),
                          if (device.algorithm.isNotEmpty)
                            _BiometricDevicePill(
                              label: device.algorithm,
                              color: colors.onSurfaceVariant,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            _DeviceMeta(
              label: l10n.profileBiometricRegisteredLabel,
              value: _localizedDateTime(device.registeredAt, l10n),
            ),
            const SizedBox(height: 4),
            _DeviceMeta(
              label: l10n.profileBiometricLastUsedLabel,
              value: device.lastUsedAt.isEmpty
                  ? l10n.profileBiometricNeverUsed
                  : _localizedDateTime(device.lastUsedAt, l10n),
            ),
            if (device.isActive && onRevoke != null) ...[
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: OutlinedButton.icon(
                  onPressed: saving ? null : onRevoke,
                  icon: const Icon(Icons.link_off),
                  label: Text(l10n.profileBiometricRevokeDevice),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _BiometricDevicePill extends StatelessWidget {
  const _BiometricDevicePill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(color, colors.surface, 0.88),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.16)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: color,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ),
      ),
    );
  }
}

class _DeviceMeta extends StatelessWidget {
  const _DeviceMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                  fontWeight: FontWeight.w700,
                  height: 1.35,
                ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colors.onSurface,
                  fontWeight: FontWeight.w800,
                  height: 1.35,
                ),
          ),
        ),
      ],
    );
  }
}

class _MutedInfoCard extends StatelessWidget {
  const _MutedInfoCard({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return _BiometricSurface(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: colors.onSurfaceVariant,
              size: 20,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
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

String _deviceName(BiometricDevice device, CustomerLocalizations l10n) {
  if (device.deviceName.trim().isNotEmpty) return device.deviceName.trim();
  return switch (device.platform) {
    'ios' => 'iPhone / iPad',
    'android' => 'Android',
    'web' => 'Web',
    'macos' => 'Mac',
    _ => l10n.profileBiometricDeviceNameFallback,
  };
}

String _deviceStatusLabel(
  BiometricDevice device,
  CustomerLocalizations l10n,
) {
  return device.isActive
      ? l10n.profileBiometricStatusActive
      : l10n.profileBiometricStatusRevoked;
}

String _platformLabel(BiometricDevice device) {
  return switch (device.platform) {
    'ios' => 'iOS',
    'android' => 'Android',
    'web' => 'Web',
    'macos' => 'macOS',
    _ => device.platform.isEmpty ? '-' : device.platform,
  };
}

IconData _deviceIcon(BiometricDevice device) {
  return switch (device.platform) {
    'ios' => Icons.phone_iphone,
    'android' => Icons.phone_android,
    'web' => Icons.public,
    'macos' => Icons.laptop_mac,
    _ => Icons.devices_other_outlined,
  };
}

String _localizedDateTime(Object? value, CustomerLocalizations l10n) {
  return formatLocalizedDateTime(value, localeTag(l10n.locale));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return _BiometricSurface(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Icon(Icons.error_outline, color: colors.error, size: 34),
            const SizedBox(height: 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface,
                    fontWeight: FontWeight.w800,
                    height: 1.4,
                  ),
            ),
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

class _BiometricSkeletonLine extends StatelessWidget {
  const _BiometricSkeletonLine({
    required this.widthFactor,
    required this.height,
  });

  final double widthFactor;
  final double height;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return FractionallySizedBox(
      widthFactor: widthFactor,
      alignment: Alignment.centerLeft,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.outlineVariant.withValues(alpha: 0.80),
          borderRadius: BorderRadius.circular(999),
        ),
        child: SizedBox(height: height),
      ),
    );
  }
}

class _BiometricStatusPanel extends StatelessWidget {
  const _BiometricStatusPanel({
    required this.message,
    required this.kind,
    required this.onDismiss,
  });

  final String message;
  final _BiometricStatusKind kind;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tone = switch (kind) {
      _BiometricStatusKind.success => colors.primary,
      _BiometricStatusKind.error => colors.error,
      _BiometricStatusKind.info => colors.secondary,
    };
    final icon = switch (kind) {
      _BiometricStatusKind.success => Icons.check_circle_outline,
      _BiometricStatusKind.error => Icons.error_outline,
      _BiometricStatusKind.info => Icons.info_outline,
    };

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(tone, colors.surface, 0.9),
        border: Border.all(color: tone.withValues(alpha: 0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: tone, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
              ),
            ),
            IconButton(
              tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
              visualDensity: VisualDensity.compact,
              onPressed: onDismiss,
              icon: const Icon(Icons.close, size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

class _BiometricSurface extends StatelessWidget {
  const _BiometricSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: colors.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BiometricDialogSurface extends StatelessWidget {
  const _BiometricDialogSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: colors.outlineVariant.withValues(alpha: 0.7)),
        boxShadow: [
          BoxShadow(
            color: colors.shadow.withValues(alpha: 0.14),
            blurRadius: 28,
            offset: const Offset(0, 14),
          ),
        ],
      ),
      child: child,
    );
  }
}

class _BiometricPinIndicator extends StatelessWidget {
  const _BiometricPinIndicator({required this.length});

  final int length;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Semantics(
      label: 'PIN $length/6',
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var index = 0; index < 6; index++)
            AnimatedContainer(
              key: ValueKey(
                'biometric-pin-dot-$index-${index < length ? 'active' : 'empty'}',
              ),
              duration: const Duration(milliseconds: 140),
              curve: Curves.easeOutCubic,
              width: 10,
              height: 10,
              margin: const EdgeInsets.symmetric(horizontal: 6),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: index < length
                    ? colors.onSurface
                    : colors.outlineVariant.withValues(alpha: 0.92),
              ),
            ),
        ],
      ),
    );
  }
}

class _BiometricPinKeypad extends StatelessWidget {
  const _BiometricPinKeypad({
    required this.onDigit,
    required this.onBackspace,
    required this.enabled,
    required this.compact,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 330),
      child: GridView.count(
        shrinkWrap: true,
        crossAxisCount: 3,
        mainAxisSpacing: compact ? 14 : 20,
        crossAxisSpacing: compact ? 20 : 26,
        childAspectRatio: compact ? 1.58 : 1.72,
        physics: const NeverScrollableScrollPhysics(),
        children: [
          for (final key in keys)
            if (key.isEmpty)
              const SizedBox.shrink()
            else
              Semantics(
                button: true,
                label: key == 'back' ? l10n.commonBack : key,
                child: TextButton(
                  onPressed: !enabled
                      ? null
                      : key == 'back'
                          ? onBackspace
                          : () => onDigit(key),
                  style: TextButton.styleFrom(
                    foregroundColor: key == 'back'
                        ? colors.onSurfaceVariant
                        : colors.onSurface,
                    disabledForegroundColor:
                        colors.onSurface.withValues(alpha: 0.38),
                    minimumSize: Size(54, compact ? 36 : 42),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                  child: key == 'back'
                      ? const Icon(Icons.backspace_outlined, size: 20)
                      : Text(key),
                ),
              ),
        ],
      ),
    );
  }
}

String? _digitFromKey(LogicalKeyboardKey key) {
  return switch (key) {
    LogicalKeyboardKey.digit0 || LogicalKeyboardKey.numpad0 => '0',
    LogicalKeyboardKey.digit1 || LogicalKeyboardKey.numpad1 => '1',
    LogicalKeyboardKey.digit2 || LogicalKeyboardKey.numpad2 => '2',
    LogicalKeyboardKey.digit3 || LogicalKeyboardKey.numpad3 => '3',
    LogicalKeyboardKey.digit4 || LogicalKeyboardKey.numpad4 => '4',
    LogicalKeyboardKey.digit5 || LogicalKeyboardKey.numpad5 => '5',
    LogicalKeyboardKey.digit6 || LogicalKeyboardKey.numpad6 => '6',
    LogicalKeyboardKey.digit7 || LogicalKeyboardKey.numpad7 => '7',
    LogicalKeyboardKey.digit8 || LogicalKeyboardKey.numpad8 => '8',
    LogicalKeyboardKey.digit9 || LogicalKeyboardKey.numpad9 => '9',
    _ => null,
  };
}
