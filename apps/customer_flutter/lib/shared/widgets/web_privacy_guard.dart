import 'package:flutter/material.dart';

import '../../core/i18n/customer_localizations.dart';

class WebPrivacyGuard extends StatefulWidget {
  const WebPrivacyGuard({
    required this.enabled,
    required this.child,
    super.key,
  });

  final bool enabled;
  final Widget child;

  @override
  State<WebPrivacyGuard> createState() => _WebPrivacyGuardState();
}

class _WebPrivacyGuardState extends State<WebPrivacyGuard>
    with WidgetsBindingObserver {
  bool _coverVisible = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didUpdateWidget(covariant WebPrivacyGuard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _coverVisible) {
      _coverVisible = false;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (!widget.enabled) return;
    final shouldCover = state == AppLifecycleState.inactive ||
        state == AppLifecycleState.hidden ||
        state == AppLifecycleState.paused ||
        state == AppLifecycleState.detached;
    if (_coverVisible == shouldCover || !mounted) return;
    setState(() => _coverVisible = shouldCover);
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    final l10n = context.l10n;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        IgnorePointer(
          child: CustomPaint(
            painter: _PrivacyWatermarkPainter(
              text: l10n.securityCaptureTitle,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        if (_coverVisible)
          Positioned.fill(
            child: ColoredBox(
              color: Theme.of(context).colorScheme.surface,
              child: SafeArea(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(28),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.visibility_off_rounded, size: 56),
                        const SizedBox(height: 18),
                        Text(
                          l10n.securityCaptureTitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: 10),
                        Text(
                          l10n.securityCaptureDescription,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
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
