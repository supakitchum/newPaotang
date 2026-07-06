typedef WebPrivacyCoverChanged = void Function(bool shouldCover);

class WebPrivacyBrowserActivity {
  WebPrivacyBrowserActivity(this._onChanged);

  // Keep the callback field so the stub constructor mirrors the web runtime.
  final WebPrivacyCoverChanged _onChanged;

  void start() {
    _onChanged(false);
  }

  void dispose() {}
}
