class BiometricDevice {
  const BiometricDevice({
    required this.id,
    required this.deviceId,
    required this.platform,
    required this.deviceName,
    required this.algorithm,
    required this.status,
    required this.registeredAt,
    required this.lastUsedAt,
    required this.revokedAt,
  });

  factory BiometricDevice.fromJson(Map<String, dynamic> json) {
    return BiometricDevice(
      id: json['id']?.toString() ?? '',
      deviceId: json['device_id']?.toString() ?? '',
      platform: json['platform']?.toString() ?? '',
      deviceName: json['device_name']?.toString() ?? '',
      algorithm: json['algorithm']?.toString() ?? '',
      status: json['status']?.toString() ?? '',
      registeredAt: json['registered_at']?.toString() ?? '',
      lastUsedAt: json['last_used_at']?.toString() ?? '',
      revokedAt: json['revoked_at']?.toString() ?? '',
    );
  }

  final String id;
  final String deviceId;
  final String platform;
  final String deviceName;
  final String algorithm;
  final String status;
  final String registeredAt;
  final String lastUsedAt;
  final String revokedAt;

  bool get isActive => status == 'active';
}
