const webPrivacyModeNone = 'none';
const webPrivacyModeLimited = 'limited';
const webPrivacyModeStrict = 'strict';
const webPrivacyModeWatermark = 'watermark';

String normalizeWebPrivacyMode(
  Object? value, {
  String fallback = webPrivacyModeLimited,
}) {
  final raw = value?.toString().trim() ?? '';
  if (raw.isEmpty) return fallback;

  final token = raw
      .toLowerCase()
      .replaceAll(RegExp(r'[\s\-.]+'), '_')
      .replaceAll(RegExp(r'_+'), '_')
      .replaceAll(RegExp(r'^_+|_+$'), '');

  return switch (token) {
    '0' ||
    'false' ||
    'no' ||
    'none' ||
    'off' ||
    'disable' ||
    'disabled' =>
      webPrivacyModeNone,
    '1' ||
    'true' ||
    'yes' ||
    'y' ||
    'on' ||
    'enable' ||
    'enabled' ||
    'active' ||
    'available' ||
    'allowed' ||
    'supported' ||
    'ready' ||
    'protect' ||
    'protected' ||
    'privacy' ||
    'privacy_mode' ||
    'sensitive' ||
    'sensitive_mode' ||
    'screen_security' ||
    'screen_protection' ||
    'web_privacy' ||
    'web_privacy_mode' ||
    'cover' ||
    'cover_only' ||
    'blank' ||
    'blank_only' ||
    'hide' ||
    'hide_only' ||
    'hidden' ||
    'hidden_only' ||
    'mask' ||
    'mask_only' ||
    'overlay' ||
    'overlay_only' ||
    'privacy_cover' ||
    'monitor' ||
    'monitor_only' ||
    'report' ||
    'report_only' ||
    'audit' ||
    'audit_only' ||
    'screen_cover' ||
    'screen_overlay' =>
      webPrivacyModeLimited,
    'strict' ||
    'full' ||
    'full_protection' ||
    'lock' ||
    'lock_and_blank' ||
    'cover_and_watermark' ||
    'watermark_and_cover' ||
    'watermark_cover' =>
      webPrivacyModeStrict,
    'watermark' ||
    'watermark_only' ||
    'watermarked' ||
    'privacy_watermark' =>
      webPrivacyModeWatermark,
    _ => token,
  };
}

bool webPrivacyModeAllowsGuard(
  Object? mode, {
  required bool watermarkEnabled,
}) {
  final normalized = normalizeWebPrivacyMode(mode);
  if (normalized == webPrivacyModeNone) return false;
  if (watermarkEnabled) return true;
  return {
    webPrivacyModeLimited,
    webPrivacyModeStrict,
    webPrivacyModeWatermark,
  }.contains(normalized);
}

bool webPrivacyModeShowsWatermark(
  Object? mode, {
  required bool watermarkEnabled,
}) {
  if (watermarkEnabled) return true;
  final normalized = normalizeWebPrivacyMode(mode);
  return normalized == webPrivacyModeStrict ||
      normalized == webPrivacyModeWatermark;
}

bool webPrivacyModeShowsLifecycleCover(Object? mode) {
  final normalized = normalizeWebPrivacyMode(mode);
  return normalized == webPrivacyModeLimited ||
      normalized == webPrivacyModeStrict;
}

bool webPrivacyModeShouldShowCover(
  Object? mode, {
  required bool lifecycleShouldCover,
  required bool browserShouldCover,
}) {
  return webPrivacyModeShowsLifecycleCover(mode) &&
      (lifecycleShouldCover || browserShouldCover);
}
