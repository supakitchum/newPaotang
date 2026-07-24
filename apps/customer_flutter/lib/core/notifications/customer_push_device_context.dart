import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:package_info_plus/package_info_plus.dart';

final customerPushDeviceContextLoaderProvider =
    Provider<CustomerPushDeviceContextLoader>((_) {
      return CustomerPushDeviceContextLoader();
    });

class CustomerPushDeviceContext {
  const CustomerPushDeviceContext({
    this.appVersion = '',
    this.deviceName = '',
    this.metadata = const {},
  });

  factory CustomerPushDeviceContext.normalized({
    String appVersion = '',
    String deviceName = '',
    Map<String, dynamic> metadata = const {},
  }) {
    return CustomerPushDeviceContext(
      appVersion: _boundedPushText(appVersion, 40),
      deviceName: _boundedPushText(deviceName, 255),
      metadata: _normalizedPushMetadata(metadata),
    );
  }

  final String appVersion;
  final String deviceName;
  final Map<String, dynamic> metadata;

  String get registrationSignature {
    final keys = metadata.keys.toList()..sort();
    final metadataSignature = keys
        .map((key) => '$key=${metadata[key]}')
        .join('&');
    return '$appVersion|$deviceName|$metadataSignature';
  }
}

class CustomerPushDeviceContextLoader {
  CustomerPushDeviceContextLoader({
    Future<CustomerPushDeviceContext> Function()? load,
  }) : _load = load ?? _loadCustomerPushDeviceContext;

  final Future<CustomerPushDeviceContext> Function() _load;
  Future<CustomerPushDeviceContext>? _cached;

  Future<CustomerPushDeviceContext> load() {
    return _cached ??= _load().catchError(
      (_) => const CustomerPushDeviceContext(),
    );
  }
}

Future<CustomerPushDeviceContext> _loadCustomerPushDeviceContext() async {
  if (kIsWeb) return const CustomerPushDeviceContext();

  var appVersion = '';
  final metadata = <String, dynamic>{};
  try {
    final package = await PackageInfo.fromPlatform();
    final version = package.version.trim();
    final buildNumber = package.buildNumber.trim();
    appVersion = version;
    if (buildNumber.isNotEmpty) {
      appVersion = version.isEmpty ? buildNumber : '$version+$buildNumber';
      metadata['app_build_number'] = buildNumber;
    }
  } catch (_) {
    // Device registration still works when package metadata is unavailable.
  }

  var deviceName = '';
  try {
    final plugin = DeviceInfoPlugin();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        final device = await plugin.androidInfo;
        final manufacturer = device.manufacturer.trim();
        final model = device.model.trim();
        deviceName = _joinedDeviceName([manufacturer, model]);
        metadata.addAll({
          'os_name': 'Android',
          if (device.version.release.trim().isNotEmpty)
            'os_version': device.version.release.trim(),
          'os_sdk': device.version.sdkInt,
          if (manufacturer.isNotEmpty) 'manufacturer': manufacturer,
          if (model.isNotEmpty) 'device_model': model,
          'is_physical_device': device.isPhysicalDevice,
        });
      case TargetPlatform.iOS:
        final device = await plugin.iosInfo;
        final model = device.model.trim();
        final machine = device.utsname.machine.trim();
        deviceName = _joinedDeviceName([model, machine]);
        metadata.addAll({
          'os_name': device.systemName.trim().isEmpty
              ? 'iOS'
              : device.systemName.trim(),
          if (device.systemVersion.trim().isNotEmpty)
            'os_version': device.systemVersion.trim(),
          if (model.isNotEmpty) 'device_model': model,
          if (machine.isNotEmpty) 'device_machine': machine,
          'is_physical_device': device.isPhysicalDevice,
        });
      default:
        break;
    }
  } catch (_) {
    // FCM token registration must not depend on optional device diagnostics.
  }

  return CustomerPushDeviceContext.normalized(
    appVersion: appVersion,
    deviceName: deviceName,
    metadata: metadata,
  );
}

String _joinedDeviceName(List<String> values) {
  final unique = <String>[];
  for (final value in values) {
    final normalized = value.trim();
    if (normalized.isEmpty || unique.contains(normalized)) continue;
    unique.add(normalized);
  }
  return unique.join(' ');
}

const _pushMetadataTextLimits = <String, int>{
  'app_build_number': 40,
  'os_name': 40,
  'os_version': 80,
  'manufacturer': 120,
  'device_model': 160,
  'device_machine': 160,
};

Map<String, dynamic> _normalizedPushMetadata(Map<String, dynamic> source) {
  final metadata = <String, dynamic>{};
  for (final entry in _pushMetadataTextLimits.entries) {
    final value = source[entry.key];
    if (value is! String) continue;
    final text = _boundedPushText(value, entry.value);
    if (text.isNotEmpty) metadata[entry.key] = text;
  }

  final osSdk = source['os_sdk'];
  if (osSdk is int && osSdk >= 0 && osSdk <= 1000) {
    metadata['os_sdk'] = osSdk;
  }
  final physical = source['is_physical_device'];
  if (physical is bool) metadata['is_physical_device'] = physical;
  return metadata;
}

String _boundedPushText(String value, int maximumLength) {
  final trimmed = value.trim();
  final runes = trimmed.runes;
  if (runes.length <= maximumLength) return trimmed;
  return String.fromCharCodes(runes.take(maximumLength));
}
