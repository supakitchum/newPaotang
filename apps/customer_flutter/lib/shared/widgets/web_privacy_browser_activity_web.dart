import 'dart:async';

import 'package:web/web.dart' as web;

import 'web_privacy_browser_activity_state.dart';

typedef WebPrivacyCoverChanged = void Function(bool shouldCover);

class WebPrivacyBrowserActivity {
  WebPrivacyBrowserActivity(this._onChanged);

  final WebPrivacyCoverChanged _onChanged;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  bool _windowFocused = true;
  bool _pageHidden = false;
  bool _pageFrozen = false;
  bool _printActive = false;
  bool _disposed = false;

  void start() {
    _windowFocused = _documentHasFocus();
    _emitCurrentState();
    _subscriptions
      ..add(
        web.document.onVisibilityChange.listen((_) {
          _emitCurrentState();
        }),
      )
      ..add(
        web.EventStreamProviders.blurEvent.forTarget(web.window).listen((_) {
          _windowFocused = false;
          _emitCurrentState();
        }),
      )
      ..add(
        web.EventStreamProviders.focusEvent.forTarget(web.window).listen((_) {
          _windowFocused = true;
          _emitCurrentState();
        }),
      )
      ..add(
        web.EventStreamProviders.pageHideEvent
            .forTarget(web.window)
            .listen((_) {
          _pageHidden = true;
          _emitCurrentState();
        }),
      )
      ..add(
        web.EventStreamProviders.pageShowEvent
            .forTarget(web.window)
            .listen((_) {
          _pageHidden = false;
          _pageFrozen = false;
          _windowFocused = _documentHasFocus();
          _emitCurrentState();
        }),
      )
      ..add(
        const web.EventStreamProvider<web.Event>('freeze')
            .forTarget(web.document)
            .listen((_) {
          _pageFrozen = true;
          _emitCurrentState();
        }),
      )
      ..add(
        const web.EventStreamProvider<web.Event>('resume')
            .forTarget(web.document)
            .listen((_) {
          _pageFrozen = false;
          _windowFocused = _documentHasFocus();
          _emitCurrentState();
        }),
      )
      ..add(
        const web.EventStreamProvider<web.Event>('beforeprint')
            .forTarget(web.window)
            .listen((_) {
          _printActive = true;
          _emitCurrentState();
        }),
      )
      ..add(
        const web.EventStreamProvider<web.Event>('afterprint')
            .forTarget(web.window)
            .listen((_) {
          _printActive = false;
          _emitCurrentState();
        }),
      );
  }

  void dispose() {
    _disposed = true;
    for (final subscription in _subscriptions) {
      unawaited(subscription.cancel());
    }
    _subscriptions.clear();
  }

  void _emitCurrentState() {
    if (_disposed) return;
    _onChanged(
      webPrivacyBrowserShouldCover(
        documentHidden: web.document.hidden,
        documentVisibilityState: web.document.visibilityState,
        windowFocused: _windowFocused,
        pageHidden: _pageHidden,
        pageFrozen: _pageFrozen,
        printActive: _printActive,
      ),
    );
  }

  bool _documentHasFocus() {
    return web.document.hasFocus();
  }
}
