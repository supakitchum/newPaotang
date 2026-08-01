import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

final customerBackNavigationHistory = CustomerBackNavigationHistory._();

class CustomerBackNavigationHistory {
  CustomerBackNavigationHistory._();

  static const _maxEntries = 50;

  GoRouter? _router;
  String? _currentLocation;
  final List<String> _previousLocations = [];
  bool _suppressNextTransition = false;

  void attach(GoRouter router) {
    if (identical(_router, router)) return;
    detach();
    _router = router;
    _currentLocation = _locationOf(router);
    router.routeInformationProvider.addListener(_handleRouterChange);
  }

  void detach([GoRouter? router]) {
    final attachedRouter = _router;
    if (attachedRouter == null) return;
    if (router != null && !identical(attachedRouter, router)) return;
    attachedRouter.routeInformationProvider.removeListener(_handleRouterChange);
    _router = null;
    _currentLocation = null;
    _previousLocations.clear();
    _suppressNextTransition = false;
  }

  String? takePrevious(GoRouter router) {
    if (!identical(_router, router)) return null;
    final current = _locationOf(router);
    while (_previousLocations.isNotEmpty) {
      final candidate = _previousLocations.removeLast();
      if (candidate != current) return candidate;
    }
    return null;
  }

  void suppressNextTransition(GoRouter router) {
    if (!identical(_router, router)) return;
    _suppressNextTransition = true;
  }

  void completeAuthenticationTransition(GoRouter router) {
    if (!identical(_router, router)) return;
    _previousLocations.removeWhere(_isAuthenticationGateLocation);
    _suppressNextTransition = true;
  }

  void _handleRouterChange() {
    final router = _router;
    if (router == null) return;
    final next = _locationOf(router);
    final current = _currentLocation;
    if (next == current) return;

    if (_suppressNextTransition) {
      _suppressNextTransition = false;
      _currentLocation = next;
      return;
    }

    if (_previousLocations.isNotEmpty && _previousLocations.last == next) {
      _previousLocations.removeLast();
      _currentLocation = next;
      return;
    }

    if (current != null && current.isNotEmpty) {
      if (_previousLocations.isEmpty || _previousLocations.last != current) {
        _previousLocations.add(current);
        if (_previousLocations.length > _maxEntries) {
          _previousLocations.removeAt(0);
        }
      }
    }
    _currentLocation = next;
  }

  String _locationOf(GoRouter router) {
    return router.routeInformationProvider.value.uri.toString();
  }

  bool _isAuthenticationGateLocation(String location) {
    final path = Uri.tryParse(location)?.path ?? '';
    return path == '/login' ||
        path == '/login/otp' ||
        path == '/pin' ||
        path == '/security-lock';
  }
}

void navigateCustomerBack(
  BuildContext context, {
  required String fallbackPath,
}) {
  final router = GoRouter.of(context);
  final previous = customerBackNavigationHistory.takePrevious(router);
  customerBackNavigationHistory.suppressNextTransition(router);

  if (router.canPop()) {
    context.pop();
    return;
  }

  final current = router.routeInformationProvider.value.uri.toString();
  final fallback = _safeCustomerBackPath(fallbackPath);
  final candidate = previous == null || previous == current
      ? fallback
      : previous;
  final target = candidate == current ? '/' : candidate;
  context.go(target);
}

String _safeCustomerBackPath(String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (trimmed.isEmpty ||
      uri == null ||
      uri.hasScheme ||
      uri.hasAuthority ||
      !trimmed.startsWith('/')) {
    return '/';
  }
  return uri.toString();
}
