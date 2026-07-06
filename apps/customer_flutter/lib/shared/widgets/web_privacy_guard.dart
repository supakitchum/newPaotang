import 'package:flutter/material.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/security/web_privacy_mode.dart';
import 'web_privacy_browser_activity.dart';

class WebPrivacyGuard extends StatefulWidget {
  const WebPrivacyGuard({
    required this.enabled,
    required this.child,
    this.mode = 'limited',
    this.watermarkEnabled = true,
    this.privacyOverlayTitle,
    this.privacyOverlayDescription,
    super.key,
  });

  final bool enabled;
  final Widget child;
  final String mode;
  final bool watermarkEnabled;
  final String? privacyOverlayTitle;
  final String? privacyOverlayDescription;

  @override
  State<WebPrivacyGuard> createState() => _WebPrivacyGuardState();
}

class _WebPrivacyGuardState extends State<WebPrivacyGuard>
    with WidgetsBindingObserver {
  late final WebPrivacyBrowserActivity _browserActivity;
  bool _browserShouldCover = false;
  bool _lifecycleShouldCover = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setLifecycleShouldCover(WidgetsBinding.instance.lifecycleState);
    _browserActivity = WebPrivacyBrowserActivity(_handleBrowserCoverChanged)
      ..start();
  }

  @override
  void didUpdateWidget(covariant WebPrivacyGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
  }

  @override
  void dispose() {
    _browserActivity.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _setLifecycleShouldCover(state);
    _syncCoverVisible();
  }

  void _handleBrowserCoverChanged(bool shouldCover) {
    _browserShouldCover = shouldCover;
    _syncCoverVisible();
  }

  void _syncCoverVisible() {
    if (!mounted) return;
    setState(() {});
  }

  void _setLifecycleShouldCover(AppLifecycleState? state) {
    _lifecycleShouldCover = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final l10n = context.l10n;
    final title = _runtimeCopy(
      widget.privacyOverlayTitle,
      l10n.securityCaptureTitle,
    );
    final description = _runtimeCopy(
      widget.privacyOverlayDescription,
      l10n.securityCaptureDescription,
    );
    final showWatermark = webPrivacyModeShowsWatermark(
      widget.mode,
      watermarkEnabled: widget.watermarkEnabled,
    );
    final coverVisible = webPrivacyModeShouldShowCover(
      widget.mode,
      lifecycleShouldCover: _lifecycleShouldCover,
      browserShouldCover: _browserShouldCover,
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        if (showWatermark)
          IgnorePointer(
            child: CustomPaint(
              painter: _PrivacyWatermarkPainter(
                text: title,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        if (coverVisible)
          Positioned.fill(
            child: _PrivacyCover(
              title: title,
              description: description,
            ),
          ),
      ],
    );
  }

  String _runtimeCopy(String? value, String fallback) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? fallback : trimmed;
  }
}

class _PrivacyCover extends StatelessWidget {
  const _PrivacyCover({
    required this.title,
    required this.description,
  });

  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final tone = colors.primary;
    return ColoredBox(
      color: colors.surface,
      child: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 360),
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DecoratedBox(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color.lerp(tone, colors.surface, 0.86),
                      border: Border.all(color: tone.withValues(alpha: 0.18)),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(18),
                      child: Icon(
                        Icons.visibility_off_rounded,
                        size: 40,
                        color: tone,
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    title,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: colors.onSurface,
                      fontWeight: FontWeight.w900,
                      height: 1.16,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    description,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurfaceVariant,
                      fontWeight: FontWeight.w700,
                      height: 1.42,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PrivacyWatermarkPainter extends CustomPainter {
  const _PrivacyWatermarkPainter({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (text.trim().isEmpty || size.isEmpty) return;

    final textPainter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color.withValues(alpha: 0.055),
          fontSize: 18,
          fontWeight: FontWeight.w900,
        ),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();

    const xGap = 210.0;
    const yGap = 145.0;
    canvas.save();
    canvas.rotate(-0.36);
    for (var y = -size.height; y < size.height * 1.8; y += yGap) {
      for (var x = -size.width; x < size.width * 1.8; x += xGap) {
        textPainter.paint(canvas, Offset(x, y));
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _PrivacyWatermarkPainter oldDelegate) {
    return oldDelegate.text != text || oldDelegate.color != color;
  }
}
