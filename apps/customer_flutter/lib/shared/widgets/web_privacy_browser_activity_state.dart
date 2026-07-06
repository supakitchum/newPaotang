bool webPrivacyBrowserShouldCover({
  required bool documentHidden,
  required bool windowFocused,
  String documentVisibilityState = 'visible',
  bool pageHidden = false,
  bool pageFrozen = false,
  bool printActive = false,
}) {
  final visibility = documentVisibilityState.trim().toLowerCase();
  final visibilityHidden = visibility.isNotEmpty && visibility != 'visible';
  return documentHidden ||
      visibilityHidden ||
      !windowFocused ||
      pageHidden ||
      pageFrozen ||
      printActive;
}
