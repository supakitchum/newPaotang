import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/biometric_device_models.dart';
import '../data/biometric_device_repository.dart';

class BiometricDevicesScreen extends ConsumerStatefulWidget {
  const BiometricDevicesScreen({super.key});

  @override
  ConsumerState<BiometricDevicesScreen> createState() =>
      _BiometricDevicesScreenState();
}

class _BiometricDevicesScreenState
    extends ConsumerState<BiometricDevicesScreen> {
  bool _saving = false;

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

    return AppShell(
      title: l10n.profileBiometrics,
      currentPath: '/profile/biometrics',
      sensitive: true,
      child: RefreshIndicator(
        onRefresh: () async => ref.refresh(biometricDevicesProvider.future),
        child: ListView(
          children: [
            CustomerPageBody(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const _BiometricIntroCard(),
                  const SizedBox(height: 12),
                  if (!policyEnabled)
                    _EnableBiometricCard(
                      canUseBiometric: false,
                      loadingCapability: false,
                      saving: _saving,
                      onEnable: null,
                    )
                  else
                    FutureBuilder<bool>(
                      future: ref
                          .read(biometricAuthServiceProvider)
                          .canUseBiometric(),
                      builder: (context, snapshot) {
                        final canUse = snapshot.data == true;
                        return _EnableBiometricCard(
                          canUseBiometric: canUse,
                          loadingCapability: snapshot.connectionState ==
                              ConnectionState.waiting,
                          saving: _saving,
                          onEnable:
                              canUse && !_saving ? _enableBiometric : null,
                        );
                      },
                    ),
                  const SizedBox(height: 12),
                  devices.when(
                    data: (items) => _DeviceList(
                      devices: items,
                      saving: _saving,
                      onRevoke: _revokeDevice,
                    ),
                    loading: () => const Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                    error: (_, __) => _ErrorCard(
                      onRetry: () => ref.invalidate(biometricDevicesProvider),
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
            deviceName: deviceName,
          );
      ref.invalidate(biometricDevicesProvider);
      if (mounted) _showSnack(enabledMessage);
    } catch (_) {
      if (mounted) _showSnack(failedMessage);
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
      builder: (context) => AlertDialog(
        title: Text(l10n.profileBiometricRevokeDialogTitle),
        content: Text(l10n.profileBiometricRevokeDialogMessage(deviceName)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      await ref.read(biometricDeviceRepositoryProvider).revoke(device.id);
      ref.invalidate(biometricDevicesProvider);
      if (mounted) _showSnack(revokedMessage);
    } catch (_) {
      if (mounted) _showSnack(failedMessage);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<String?> _askForPin() {
    final l10n = context.l10n;
    final controller = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.profileBiometricPinDialogTitle),
        content: TextField(
          controller: controller,
          autofocus: true,
          obscureText: true,
          keyboardType: TextInputType.number,
          maxLength: 6,
          inputFormatters: [
            FilteringTextInputFormatter.digitsOnly,
            LengthLimitingTextInputFormatter(6),
          ],
          decoration: const InputDecoration(
            labelText: 'PIN',
            counterText: '',
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value.trim()),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: Text(l10n.commonConfirm),
          ),
        ],
      ),
    ).whenComplete(controller.dispose);
  }

  String _defaultDeviceName(CustomerLocalizations l10n, String platformKey) {
    return switch (platformKey) {
      'ios' => l10n.profileBiometricDeviceNameIos,
      'android' => l10n.profileBiometricDeviceNameAndroid,
      _ => l10n.profileBiometricDeviceNameFallback,
    };
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }
}

class _BiometricIntroCard extends StatelessWidget {
  const _BiometricIntroCard();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colors.primaryContainer,
              child: Icon(
                Icons.face_retouching_natural,
                color: colors.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileBiometricIntroTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(l10n.profileBiometricIntroSubtitle),
                ],
              ),
            ),
          ],
        ),
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
    final unavailable = !loadingCapability && !canUseBiometric;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  unavailable
                      ? Icons.phonelink_lock_outlined
                      : Icons.verified_user_outlined,
                  color: unavailable ? colors.error : colors.primary,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    unavailable
                        ? l10n.profileBiometricUnavailableTitle
                        : l10n.profileBiometricEnableTitle,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              unavailable
                  ? l10n.profileBiometricUnavailableMessage
                  : l10n.profileBiometricEnableMessage,
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: onEnable,
                icon: saving
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.face_retouching_natural),
                label: Text(
                  saving
                      ? l10n.profileBiometricSaving
                      : l10n.profileBiometricEnableButton,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeviceList extends StatelessWidget {
  const _DeviceList({
    required this.devices,
    required this.saving,
    required this.onRevoke,
  });

  final List<BiometricDevice> devices;
  final bool saving;
  final ValueChanged<BiometricDevice> onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final active = devices.where((device) => device.isActive).toList();
    final revoked = devices.where((device) => !device.isActive).toList();

    if (devices.isEmpty) {
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            children: [
              const Icon(Icons.devices_other_outlined, size: 38),
              const SizedBox(height: 10),
              Text(
                l10n.profileBiometricEmptyTitle,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              Text(
                l10n.profileBiometricEmptyMessage,
                textAlign: TextAlign.center,
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
            _DeviceCard(device: device, saving: saving),
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
    required this.saving,
    this.onRevoke,
  });

  final BiometricDevice device;
  final bool saving;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    return Card(
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
                    device.platform == 'ios'
                        ? Icons.phone_iphone
                        : Icons.phone_android,
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
                          Chip(
                            label: Text(_deviceStatusLabel(device, l10n)),
                            visualDensity: VisualDensity.compact,
                            backgroundColor: device.isActive
                                ? colors.primaryContainer
                                : colors.surfaceContainerHighest,
                          ),
                          Chip(
                            label: Text(_platformLabel(device)),
                            visualDensity: VisualDensity.compact,
                          ),
                          if (device.algorithm.isNotEmpty)
                            Chip(
                              label: Text(device.algorithm),
                              visualDensity: VisualDensity.compact,
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

class _DeviceMeta extends StatelessWidget {
  const _DeviceMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: TextStyle(color: Theme.of(context).colorScheme.outline),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Text(message),
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
    _ => device.platform.isEmpty ? '-' : device.platform,
  };
}

String _localizedDateTime(Object? value, CustomerLocalizations l10n) {
  return formatLocalizedDateTime(value, localeTag(l10n.locale));
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            const Icon(Icons.error_outline, size: 34),
            const SizedBox(height: 8),
            Text(l10n.profileBiometricLoadFailed),
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
