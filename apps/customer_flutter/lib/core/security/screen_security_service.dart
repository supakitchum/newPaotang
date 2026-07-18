import 'dart:async';
import 'dart:convert' as convert;

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../network/api_client.dart';
import '../tenant/mobile_runtime_policy.dart';

final screenSecurityServiceProvider = Provider<ScreenSecurityService>(
  (_) => ScreenSecurityService(),
);

final screenSecurityAuditServiceProvider = Provider<ScreenSecurityAuditService>(
  (ref) => ApiScreenSecurityAuditService(
    ref.watch(apiClientProvider),
    platform: ref.watch(customerPlatformKeyProvider),
  ),
);

class ScreenSecurityEvent {
  const ScreenSecurityEvent({
    required this.event,
    required this.route,
    this.reason,
  });

  final String event;
  final String route;
  final String? reason;
}

abstract class ScreenSecurityAuditService {
  const ScreenSecurityAuditService();

  Future<void> record({
    required ScreenSecurityEvent event,
    required String route,
  });
}

class ApiScreenSecurityAuditService extends ScreenSecurityAuditService {
  const ApiScreenSecurityAuditService(
    this._api, {
    required this.platform,
  });

  final ApiClient _api;
  final String platform;

  @override
  Future<void> record({
    required ScreenSecurityEvent event,
    required String route,
  }) async {
    try {
      await _api.post<void>(
        '/customer/auth/security-events',
        data: {
          'event': event.event,
          'route': route,
          if (event.reason?.trim().isNotEmpty == true)
            'reason': event.reason!.trim(),
          if (platform.trim().isNotEmpty) 'platform': platform.trim(),
        },
      );
    } catch (_) {
      // Security logging is best-effort and must not block privacy handling.
    }
  }
}

class ScreenSecurityService {
  ScreenSecurityService() {
    _channel.setMethodCallHandler(_handleNativeCall);
  }

  static const MethodChannel _channel =
      MethodChannel('customer_flutter/screen_security');
  final _events = StreamController<ScreenSecurityEvent>.broadcast();

  Stream<ScreenSecurityEvent> get events => _events.stream;

  Future<void> enable({
    required String route,
    String? overlayTitle,
    String? overlayDescription,
    bool? androidFlagSecure,
    bool? androidProtectRecentAppPreview,
    String? iosScreenshotPolicy,
    bool? iosScreenCaptureOverlay,
    bool? iosExitApp,
  }) async {
    await _invoke('enable', {
      'route': route,
      if (overlayTitle?.trim().isNotEmpty == true)
        'overlay_title': overlayTitle!.trim(),
      if (overlayDescription?.trim().isNotEmpty == true)
        'overlay_description': overlayDescription!.trim(),
      if (androidFlagSecure != null) 'flag_secure': androidFlagSecure,
      if (androidProtectRecentAppPreview != null)
        'protect_recent_app_preview': androidProtectRecentAppPreview,
      if (iosScreenshotPolicy?.trim().isNotEmpty == true)
        'ios_screenshot_policy': iosScreenshotPolicy!.trim(),
      if (iosScreenCaptureOverlay != null)
        'ios_screen_capture_overlay': iosScreenCaptureOverlay,
      if (iosExitApp != null) 'ios_exit_app': iosExitApp,
    });
  }

  Future<void> disable() async {
    await _invoke('disable');
  }

  Future<void> reportSecurityEvent({
    required String event,
    required String route,
    String? reason,
  }) async {
    await _invoke('reportSecurityEvent', {
      'event': event,
      'route': route,
      if (reason?.trim().isNotEmpty == true) 'reason': reason!.trim(),
    });
  }

  Future<void> _invoke(String method, [Map<String, Object?>? arguments]) async {
    try {
      await _channel.invokeMethod<void>(method, arguments);
    } on MissingPluginException {
      // Unsupported platforms keep the Flutter flow usable without native hooks.
    } on PlatformException {
      // A native privacy hook must not strand the customer on a broken route.
    }
  }

  Future<void> _handleNativeCall(MethodCall call) async {
    if (call.method != 'securityEvent') return;
    final arguments = call.arguments;
    if (arguments is! Map) return;
    final payload = _nativeEventPayload(arguments);
    _events.add(
      ScreenSecurityEvent(
        event: _normalizeNativeEvent(
          payload['event'] ??
              payload['eventName'] ??
              payload['event_name'] ??
              payload['eventKey'] ??
              payload['event_key'] ??
              payload['eventCode'] ??
              payload['event_code'] ??
              payload['eventType'] ??
              payload['event_type'] ??
              payload['eventAction'] ??
              payload['event_action'] ??
              payload['securityEventName'] ??
              payload['security_event_name'] ??
              payload['screenSecurityEventName'] ??
              payload['screen_security_event_name'] ??
              payload['securityAction'] ??
              payload['security_action'] ??
              payload['nativeEvent'] ??
              payload['native_event'] ??
              payload['action'] ??
              payload['type'] ??
              payload['kind'] ??
              payload['status'] ??
              payload['state'] ??
              payload['stateName'] ??
              payload['state_name'] ??
              payload['name'],
          payload,
        ),
        route: normalizeScreenSecurityRoute(
          _firstNativeRouteString(
            _screenSecurityRouteKeys.map((key) => payload[key]),
          ),
        ),
        reason: _optionalNativeString(
          payload['reason'] ??
              payload['reasonName'] ??
              payload['reason_name'] ??
              payload['reason_code'] ??
              payload['reasonCode'] ??
              payload['reasonText'] ??
              payload['reason_text'] ??
              payload['cause'] ??
              payload['message'] ??
              payload['description'] ??
              payload['policy'] ??
              payload['policyName'] ??
              payload['policy_name'] ??
              payload['source'] ??
              payload['sourceName'] ??
              payload['source_name'] ??
              payload['trigger'] ??
              payload['triggerName'] ??
              payload['trigger_name'] ??
              payload['detail'] ??
              payload['details'],
        ),
      ),
    );
  }

  static Map<String, dynamic> _nativeEventPayload(
    Map<dynamic, dynamic> arguments, [
    int depth = 0,
  ]) {
    final payload = <String, dynamic>{
      for (final entry in arguments.entries) entry.key.toString(): entry.value,
    };
    if (depth >= 4) return payload;

    var resolvedPayload = payload;
    for (final key in const [
      'securityEvent',
      'security_event',
      'screenSecurityEvent',
      'screen_security_event',
      'eventPayload',
      'event_payload',
      'eventBody',
      'event_body',
      'nativePayload',
      'native_payload',
      'arguments',
      'argument',
      'args',
      'params',
      'parameters',
      'userInfo',
      'user_info',
      'notification',
      'routeInfo',
      'route_info',
      'navigation',
      'navigationInfo',
      'navigation_info',
      'screenInfo',
      'screen_info',
      'viewInfo',
      'view_info',
      'pageInfo',
      'page_info',
      'captureInfo',
      'capture_info',
      'captureStateInfo',
      'capture_state_info',
      'recordingInfo',
      'recording_info',
      'recordingStateInfo',
      'recording_state_info',
      'projectionInfo',
      'projection_info',
      'projectionStateInfo',
      'projection_state_info',
      'event',
      'payload',
      'data',
      'resource',
      'body',
    ]) {
      final nested = _asNativeEventMap(resolvedPayload[key]);
      if (nested.isEmpty) continue;
      if (_isNativeScalarWrapperMap(nested)) continue;
      resolvedPayload = _mergeNativeEventWrapper(
        resolvedPayload,
        _nativeEventPayload(nested, depth + 1),
        nestedKey: key,
      );
    }

    return resolvedPayload;
  }

  static bool _isNativeScalarWrapperMap(Map<dynamic, dynamic> value) {
    if (value.isEmpty) return false;
    return value.keys.every(
      (key) => _nativeScalarWrapperKeys.contains(key.toString()),
    );
  }

  static Map<dynamic, dynamic> _asNativeEventMap(Object? value) {
    if (value is Map) return value;
    if (value is! String) return const <dynamic, dynamic>{};
    final trimmed = value.trim();
    if (!trimmed.startsWith('{')) return const <dynamic, dynamic>{};
    try {
      final decoded = convert.jsonDecode(trimmed);
      return decoded is Map ? decoded : const <dynamic, dynamic>{};
    } catch (_) {
      return const <dynamic, dynamic>{};
    }
  }

  static Map<String, dynamic> _mergeNativeEventWrapper(
    Map<String, dynamic> wrapper,
    Map<String, dynamic> nested, {
    required String nestedKey,
  }) {
    final mergedWrapper = <String, dynamic>{...wrapper}..remove(nestedKey);
    if (_hasAnyNativeKey(nested, _nativeEventKeys)) {
      mergedWrapper.removeWhere((key, _) => _nativeEventKeys.contains(key));
    }
    if (_hasAnyNativeKey(nested, _nativeRouteKeys)) {
      mergedWrapper.removeWhere((key, _) => _nativeRouteKeys.contains(key));
    }
    if (_hasAnyNativeKey(nested, _nativeReasonKeys)) {
      mergedWrapper.removeWhere((key, _) => _nativeReasonKeys.contains(key));
    }
    return {...mergedWrapper, ...nested};
  }

  static bool _hasAnyNativeKey(Map<String, dynamic> payload, Set<String> keys) {
    return keys.any(
      (key) => _optionalNativeString(payload[key]) != null,
    );
  }

  static const _nativeEventKeys = {
    'event',
    'eventName',
    'event_name',
    'eventKey',
    'event_key',
    'eventCode',
    'event_code',
    'eventType',
    'event_type',
    'eventAction',
    'event_action',
    'securityEventName',
    'security_event_name',
    'screenSecurityEventName',
    'screen_security_event_name',
    'securityAction',
    'security_action',
    'nativeEvent',
    'native_event',
    'action',
    'type',
    'kind',
    'status',
    'state',
    'stateName',
    'state_name',
    'name',
  };

  static const _nativeRouteKeys = {..._screenSecurityRouteKeys};

  static const _nativeReasonKeys = {
    'reason',
    'reasonName',
    'reason_name',
    'reason_code',
    'reasonCode',
    'reasonText',
    'reason_text',
    'cause',
    'message',
    'description',
    'policy',
    'policyName',
    'policy_name',
    'source',
    'sourceName',
    'source_name',
    'trigger',
    'triggerName',
    'trigger_name',
    'detail',
    'details',
  };

  static String _normalizeNativeEvent(
    Object? value, [
    Map<String, dynamic> payload = const {},
  ]) {
    final event = _toSnakeCase(_nativeScalarText(value)).trim();
    final captureActive = _nativeCaptureActive(payload);
    return switch (event) {
      '' => 'screen_capture',
      'screen_capture' => 'screen_capture_active',
      'screen_captured' => 'screen_capture_active',
      'screen_capture_detected' => 'screen_capture_active',
      'screen_capture_change' ||
      'screen_capture_changed' ||
      'screen_capture_state_change' ||
      'screen_capture_state_changed' ||
      'screen_capture_did_change' ||
      'ui_screen_captured_did_change' ||
      'ui_screen_captured_did_change_notification' ||
      'uiscreen_captured_did_change' ||
      'uiscreen_captured_did_change_notification' ||
      'captured_changed' ||
      'captured_did_change' =>
        captureActive == false
            ? 'screen_capture_ended'
            : 'screen_capture_active',
      'screen_recording' => 'screen_capture_active',
      'screen_recording_detected' => 'screen_capture_active',
      'screen_recording_change' ||
      'screen_recording_changed' ||
      'screen_recording_state_change' ||
      'screen_recording_state_changed' ||
      'screen_recording_did_change' ||
      'recording_changed' ||
      'recording_did_change' =>
        captureActive == false
            ? 'screen_capture_ended'
            : 'screen_capture_active',
      'media_projection_change' ||
      'media_projection_changed' ||
      'media_projection_state_change' ||
      'media_projection_state_changed' ||
      'media_projection_did_change' =>
        captureActive == false
            ? 'screen_capture_ended'
            : 'screen_capture_active',
      'capture_active' ||
      'captured_active' ||
      'recording_active' ||
      'media_projection' ||
      'media_projection_active' ||
      'is_captured' ||
      'is_recording' =>
        'screen_capture_active',
      'capture_started' => 'screen_capture_active',
      'recording_started' => 'screen_capture_active',
      'media_projection_started' => 'screen_capture_active',
      'screen_capture_started' => 'screen_capture_active',
      'screen_recording_started' => 'screen_capture_active',
      'screen_recording_active' => 'screen_capture_active',
      'capture_inactive' ||
      'captured_inactive' ||
      'recording_inactive' ||
      'media_projection_inactive' ||
      'not_captured' ||
      'not_recording' =>
        'screen_capture_ended',
      'capture_ended' => 'screen_capture_ended',
      'capture_stopped' => 'screen_capture_ended',
      'recording_ended' => 'screen_capture_ended',
      'recording_stopped' => 'screen_capture_ended',
      'media_projection_ended' => 'screen_capture_ended',
      'media_projection_stopped' => 'screen_capture_ended',
      'screen_capture_inactive' => 'screen_capture_ended',
      'screen_capture_stopped' => 'screen_capture_ended',
      'screen_recording_stopped' => 'screen_capture_ended',
      'screen_recording_ended' => 'screen_capture_ended',
      'screenshot' => 'screenshot_detected',
      'screen_shot' => 'screenshot_detected',
      'screenshot_taken' => 'screenshot_detected',
      'screen_capture_screenshot' => 'screenshot_detected',
      'did_take_screenshot' => 'screenshot_detected',
      'user_screenshot' => 'screenshot_detected',
      'user_did_take_screenshot' => 'screenshot_detected',
      'ui_application_user_did_take_screenshot' => 'screenshot_detected',
      'ui_application_user_did_take_screenshot_notification' =>
        'screenshot_detected',
      'uiapplication_user_did_take_screenshot' => 'screenshot_detected',
      'uiapplication_user_did_take_screenshot_notification' =>
        'screenshot_detected',
      'screen_security_exit' => 'screen_security_exit_requested',
      'security_exit_requested' => 'screen_security_exit_requested',
      'exit_requested' => 'screen_security_exit_requested',
      _ => event,
    };
  }

  static bool? _nativeCaptureActive(Map<String, dynamic> payload) {
    for (final key in const [
      'screenCaptureActive',
      'screen_capture_active',
      'screenCaptured',
      'screen_captured',
      'isCaptured',
      'is_captured',
      'captured',
      'captureActive',
      'capture_active',
      'screenRecordingActive',
      'screen_recording_active',
      'screenRecording',
      'screen_recording',
      'isRecording',
      'is_recording',
      'recording',
      'recordingActive',
      'recording_active',
      'captureState',
      'capture_state',
      'screenCaptureState',
      'screen_capture_state',
      'recordingState',
      'recording_state',
      'screenRecordingState',
      'screen_recording_state',
      'mediaProjection',
      'media_projection',
      'mediaProjectionActive',
      'media_projection_active',
      'mediaProjectionRunning',
      'media_projection_running',
      'captureStatus',
      'capture_status',
      'screenCaptureStatus',
      'screen_capture_status',
      'recordingStatus',
      'recording_status',
      'screenRecordingStatus',
      'screen_recording_status',
      'mediaProjectionStatus',
      'media_projection_status',
      'mirrorActive',
      'mirror_active',
      'mirroring',
      'mirrorState',
      'mirror_state',
      'mirrorStatus',
      'mirror_status',
    ]) {
      final parsed = _optionalNativeBool(payload[key]);
      if (parsed != null) return parsed;
    }
    return null;
  }

  static String? _optionalNativeString(Object? value) {
    final stringValue = _nativeScalarText(value);
    return stringValue.isEmpty ? null : stringValue;
  }

  static bool? _optionalNativeBool(Object? value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    final normalized = _nativeScalarText(value).toLowerCase();
    if (normalized.isEmpty) return null;
    return switch (normalized) {
      '1' ||
      'true' ||
      'yes' ||
      'on' ||
      'active' ||
      'captured' ||
      'recording' ||
      'started' ||
      'running' ||
      'capturing' ||
      'projecting' ||
      'mirroring' =>
        true,
      '0' ||
      'false' ||
      'no' ||
      'off' ||
      'inactive' ||
      'ended' ||
      'stopped' ||
      'not_capturing' ||
      'not_captured' ||
      'not_recording' ||
      'not_projecting' ||
      'not_mirroring' =>
        false,
      _ => null,
    };
  }

  static String _firstNativeRouteString(
    Iterable<Object?> values, [
    int depth = 0,
  ]) {
    if (depth >= 4) return '';
    for (final value in values) {
      final route = _nativeRouteString(value, depth);
      if (route.isNotEmpty) return route;
    }
    return '';
  }

  static String _nativeRouteString(Object? value, int depth) {
    if (value == null) return '';
    if (value is String) {
      final nested = _asNativeEventMap(value);
      if (nested.isNotEmpty) return _nativeRouteString(nested, depth + 1);
      return value.trim();
    }
    if (value is num || value is bool) {
      return value.toString().trim();
    }
    if (value is Iterable) {
      return _firstNativeRouteString(value, depth + 1);
    }
    if (value is Map) {
      final payload = <String, dynamic>{
        for (final entry in value.entries) entry.key.toString(): entry.value,
      };
      final route = _firstNativeRouteString(
        _screenSecurityRouteKeys.map((key) => payload[key]),
        depth + 1,
      );
      if (route.isNotEmpty) return route;
      return _nativeScalarText(payload, depth + 1);
    }
    return _nativeScalarText(value);
  }

  static String _nativeScalarText(Object? value, [int depth = 0]) {
    if (value == null) return '';
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.startsWith('{') && depth < 4) {
        final map = _asNativeEventMap(trimmed);
        if (map.isNotEmpty) {
          final text = _nativeScalarText(map, depth + 1);
          if (text.isNotEmpty) return text;
        }
      }
      return trimmed;
    }
    if (value is num || value is bool) return value.toString().trim();
    if (depth >= 4 || value is Iterable) return '';

    final map = _asNativeEventMap(value);
    if (map.isEmpty) return '';
    final payload = <String, dynamic>{
      for (final entry in map.entries) entry.key.toString(): entry.value,
    };

    for (final key in const [
      'value',
      'code',
      'key',
      'text',
      'label',
      'raw',
      'rawValue',
      'raw_value',
      'string',
      'stringValue',
      'string_value',
      'event',
      'eventName',
      'event_name',
      'eventKey',
      'event_key',
      'eventCode',
      'event_code',
      'eventType',
      'event_type',
      'eventAction',
      'event_action',
      'securityEventName',
      'security_event_name',
      'screenSecurityEventName',
      'screen_security_event_name',
      'securityAction',
      'security_action',
      'nativeEvent',
      'native_event',
      'action',
      'type',
      'kind',
      'status',
      'state',
      'stateName',
      'state_name',
      'name',
      'reason',
      'reasonName',
      'reason_name',
      'reason_code',
      'reasonCode',
      'reasonText',
      'reason_text',
      'cause',
      'message',
      'description',
      'policy',
      'policyName',
      'policy_name',
      'source',
      'sourceName',
      'source_name',
      'trigger',
      'triggerName',
      'trigger_name',
      'detail',
      'details',
      'screenCaptureActive',
      'screen_capture_active',
      'screenCaptured',
      'screen_captured',
      'isCaptured',
      'is_captured',
      'captured',
      'captureActive',
      'capture_active',
      'screenRecordingActive',
      'screen_recording_active',
      'screenRecording',
      'screen_recording',
      'isRecording',
      'is_recording',
      'recording',
      'recordingActive',
      'recording_active',
      ..._screenSecurityRouteKeys,
    ]) {
      if (!payload.containsKey(key)) continue;
      final text = _nativeScalarText(payload[key], depth + 1);
      if (text.isNotEmpty) return text;
    }

    if (payload.length == 1) {
      final entry = payload.entries.single;
      final text = _nativeScalarText(entry.value, depth + 1).toLowerCase();
      if (const {
        '1',
        'true',
        'yes',
        'y',
        'on',
        'active',
        'captured',
        'recording',
        'started',
      }.contains(text)) {
        return entry.key.trim();
      }
    }

    return '';
  }

  static String _toSnakeCase(String value) {
    return value
        .replaceAllMapped(
          RegExp(r'([a-z0-9])([A-Z])'),
          (match) => '${match.group(1)}_${match.group(2)}',
        )
        .replaceAll(RegExp(r'[\s\-.]+'), '_')
        .toLowerCase();
  }
}

const _nativeScalarWrapperKeys = {
  'value',
  'code',
  'key',
  'text',
  'label',
  'raw',
  'rawValue',
  'raw_value',
  'string',
  'stringValue',
  'string_value',
};

const _screenSecurityRouteKeys = [
  'route',
  'routeName',
  'route_name',
  'routePath',
  'route_path',
  'routeFullPath',
  'route_full_path',
  'routeUrl',
  'route_url',
  'currentRoute',
  'current_route',
  'activeRoute',
  'active_route',
  'targetRoute',
  'target_route',
  'path',
  'fullPath',
  'full_path',
  'currentFullPath',
  'current_full_path',
  'activeFullPath',
  'active_full_path',
  'targetFullPath',
  'target_full_path',
  'pathname',
  'pathName',
  'path_name',
  'routerPath',
  'router_path',
  'targetPath',
  'target_path',
  'navigationPath',
  'navigation_path',
  'currentNavigationPath',
  'current_navigation_path',
  'activeNavigationPath',
  'active_navigation_path',
  'targetNavigationPath',
  'target_navigation_path',
  'screenPath',
  'screen_path',
  'currentPath',
  'current_path',
  'activePath',
  'active_path',
  'urlPath',
  'url_path',
  'page',
  'pageName',
  'page_name',
  'currentPage',
  'current_page',
  'activePage',
  'active_page',
  'pageRoute',
  'page_route',
  'navigationRoute',
  'navigation_route',
  'currentNavigationRoute',
  'current_navigation_route',
  'activeNavigationRoute',
  'active_navigation_route',
  'targetNavigationRoute',
  'target_navigation_route',
  'viewRoute',
  'view_route',
  'currentViewRoute',
  'current_view_route',
  'activeViewRoute',
  'active_view_route',
  'screen',
  'screenName',
  'screen_name',
  'currentScreen',
  'current_screen',
  'activeScreen',
  'active_screen',
  'screenUrl',
  'screen_url',
  'view',
  'viewName',
  'view_name',
  'currentView',
  'current_view',
  'activeView',
  'active_view',
  'viewPath',
  'view_path',
  'currentViewPath',
  'current_view_path',
  'activeViewPath',
  'active_view_path',
  'viewUrl',
  'view_url',
  'currentViewUrl',
  'current_view_url',
  'activeViewUrl',
  'active_view_url',
  'pagePath',
  'page_path',
  'url',
  'urlString',
  'url_string',
  'currentUrl',
  'current_url',
  'activeUrl',
  'active_url',
  'targetUrl',
  'target_url',
  'routerUrl',
  'router_url',
  'navigationUrl',
  'navigation_url',
  'currentNavigationUrl',
  'current_navigation_url',
  'activeNavigationUrl',
  'active_navigation_url',
  'targetNavigationUrl',
  'target_navigation_url',
  'pageUrl',
  'page_url',
  'webUrl',
  'web_url',
  'requestUrl',
  'request_url',
  'deepLink',
  'deep_link',
  'deepLinkUrl',
  'deep_link_url',
  'appLink',
  'app_link',
  'appLinkUrl',
  'app_link_url',
  'universalLink',
  'universal_link',
  'sourceUrl',
  'source_url',
  'destinationUrl',
  'destination_url',
  'returnUrl',
  'return_url',
  'redirect',
  'redirectUrl',
  'redirect_url',
  'redirectUri',
  'redirect_uri',
  'continueUrl',
  'continue_url',
  'callbackUrl',
  'callback_url',
  'originalUrl',
  'original_url',
  'fragment',
  'hash',
  'hashRoute',
  'hash_route',
  'hashPath',
  'hash_path',
  'query',
  'queryString',
  'query_string',
  'location',
  'href',
  'uri',
  'link',
  'linkUrl',
  'link_url',
];

String normalizeScreenSecurityRoute(String value) {
  final trimmed = value.trim();
  if (trimmed.isEmpty) return '';
  final decoded = _decodeScreenSecurityRouteValue(trimmed);
  if (decoded != trimmed) {
    final decodedRoute = normalizeScreenSecurityRoute(decoded);
    if (decodedRoute.isNotEmpty) return decodedRoute;
  }

  final routeQuery = _screenSecurityFragmentQuery(trimmed);
  if (routeQuery.isNotEmpty) {
    final queryPath = _screenSecurityPathFromQuery(Uri(query: routeQuery));
    if (queryPath.isNotEmpty) return queryPath;
  }

  final parsed = Uri.tryParse(trimmed);
  if (parsed != null) {
    final fragmentPath = _screenSecurityPathFromFragment(parsed.fragment);
    if (fragmentPath.isNotEmpty) return fragmentPath;

    final queryPath = _screenSecurityPathFromQuery(parsed);
    if (queryPath.isNotEmpty) return queryPath;

    final hasUrlShape = parsed.hasScheme ||
        trimmed.startsWith('//') ||
        trimmed.startsWith('/') ||
        trimmed.startsWith('?');
    if (hasUrlShape) return _screenSecurityPath(parsed.path);
  }

  final withoutQuery = trimmed.split('?').first.split('#').first.trim();
  return _screenSecurityPath(withoutQuery);
}

String _screenSecurityPathFromQuery(Uri uri) {
  for (final key in _screenSecurityRouteKeys) {
    final value = uri.queryParameters[key]?.trim() ?? '';
    if (value.isEmpty) continue;
    return normalizeScreenSecurityRoute(value);
  }
  return '';
}

bool screenSecurityRoutesMatch(String eventRoute, String activeRoute) {
  final eventPath = normalizeScreenSecurityRoute(eventRoute);
  if (eventPath.isEmpty) return true;
  final activePath = normalizeScreenSecurityRoute(activeRoute);
  if (eventPath == activePath) return true;
  if (_screenSecurityRoutePatternMatches(eventPath, activePath)) return true;
  return activePath.startsWith('$eventPath/');
}

String _screenSecurityPathFromFragment(String fragment) {
  final decoded = _decodeScreenSecurityRouteValue(fragment.trim());
  final trimmed =
      decoded.startsWith('!') ? decoded.substring(1).trim() : decoded;
  if (trimmed.isEmpty) return '';

  final queryOnly = _screenSecurityFragmentQuery(trimmed);
  if (queryOnly.isNotEmpty) {
    final queryPath = _screenSecurityPathFromQuery(Uri(query: queryOnly));
    if (queryPath.isNotEmpty) return queryPath;
  }

  final parsed = Uri.tryParse(trimmed.startsWith('/') ? trimmed : '/$trimmed');
  if (parsed != null) {
    final queryPath = _screenSecurityPathFromQuery(parsed);
    if (queryPath.isNotEmpty) return queryPath;
  }
  return _screenSecurityPath(parsed?.path ?? trimmed);
}

String _screenSecurityFragmentQuery(String fragment) {
  final trimmed = fragment.trim();
  if (trimmed.startsWith('?')) return trimmed.substring(1);

  final queryStart = trimmed.indexOf('?');
  if (queryStart >= 0 && queryStart < trimmed.length - 1) {
    final query = trimmed.substring(queryStart + 1);
    if (_screenSecurityQueryHasRouteKey(query)) return query;
  }

  return _screenSecurityQueryHasRouteKey(trimmed) ? trimmed : '';
}

bool _screenSecurityQueryHasRouteKey(String value) {
  final query = value.trim();
  if (query.isEmpty || !query.contains('=')) return false;
  final parameters = Uri(query: query).queryParameters;
  return _screenSecurityRouteKeys.any(
    (key) => parameters[key]?.trim().isNotEmpty == true,
  );
}

String _decodeScreenSecurityRouteValue(String value) {
  if (!value.contains('%')) return value;
  try {
    final decoded = Uri.decodeComponent(value).trim();
    return decoded.isEmpty ? value : decoded;
  } catch (_) {
    return value;
  }
}

String _screenSecurityPath(String value) {
  final path = value.trim();
  if (path.isEmpty) return '';
  final normalized = path.startsWith('/') ? path : '/$path';
  if (normalized.length == 1) return normalized;
  return normalized.replaceFirst(RegExp(r'/+$'), '');
}

bool _screenSecurityRoutePatternMatches(String pattern, String path) {
  final patternParts =
      pattern.split('/').where((part) => part.isNotEmpty).toList();
  final pathParts = path.split('/').where((part) => part.isNotEmpty).toList();
  var pathIndex = 0;
  for (var patternIndex = 0;
      patternIndex < patternParts.length;
      patternIndex++) {
    final patternPart = patternParts[patternIndex];
    final lastPatternPart = patternIndex == patternParts.length - 1;
    if (patternPart == '*') {
      return lastPatternPart && pathIndex < pathParts.length;
    }
    if (pathIndex >= pathParts.length) return false;
    if (patternPart.startsWith(':')) {
      pathIndex++;
      continue;
    }
    if (patternPart != pathParts[pathIndex]) return false;
    pathIndex++;
  }
  return pathIndex == pathParts.length;
}
