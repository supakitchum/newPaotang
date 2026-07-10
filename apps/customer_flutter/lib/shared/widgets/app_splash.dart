import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';
import '../../core/theme/app_theme.dart';
import '../../core/utils/asset_url.dart';
import 'flexible_image.dart';

final appSplashMinimumDurationProvider = Provider<Duration>(
  (_) => const Duration(milliseconds: 650),
);
final appSplashFadeDurationProvider = Provider<Duration>(
  (_) => const Duration(milliseconds: 260),
);

class AppSplashHost extends ConsumerStatefulWidget {
  const AppSplashHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  ConsumerState<AppSplashHost> createState() => _AppSplashHostState();
}

class _AppSplashHostState extends ConsumerState<AppSplashHost> {
  Timer? _minimumTimer;
  Timer? _removeTimer;
  bool _canHide = false;
  bool _leaving = false;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    _minimumTimer = Timer(ref.read(appSplashMinimumDurationProvider), () {
      if (!mounted) return;
      setState(() => _canHide = true);
      _tryClose();
    });
  }

  @override
  void dispose() {
    _minimumTimer?.cancel();
    _removeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final ready = bootstrap.hasValue || bootstrap.hasError;
    if (ready && _canHide && _visible && !_leaving) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _tryClose());
    }

    return Stack(
      children: [
        widget.child,
        if (_visible) _AppSplashOverlay(leaving: _leaving),
      ],
    );
  }

  void _tryClose() {
    if (!mounted || _leaving || !_visible || !_canHide) return;
    final bootstrap = ref.read(mobileBootstrapProvider);
    if (!bootstrap.hasValue && !bootstrap.hasError) return;

    setState(() => _leaving = true);
    _removeTimer?.cancel();
    _removeTimer = Timer(ref.read(appSplashFadeDurationProvider), () {
      if (mounted) setState(() => _visible = false);
    });
  }
}

class _AppSplashOverlay extends StatelessWidget {
  const _AppSplashOverlay({required this.leaving});

  final bool leaving;

  static const _splashMid = Color(0xFF0C6FE0);
  static const _splashEnd = Color(0xFF15AEEA);

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: leaving,
        child: AnimatedOpacity(
          opacity: leaving ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: Material(
            color: AppTheme.appBlue,
            child: Stack(
              children: [
                const Positioned.fill(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppTheme.appBlue,
                          _splashMid,
                          _splashEnd,
                        ],
                        stops: [0, 0.48, 1],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  right: 0,
                  bottom: 0,
                  child: _SplashYellowCorner(),
                ),
                SafeArea(
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(28),
                      child: Semantics(
                        label: context.l10n.appSplashPreparing,
                        liveRegion: true,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(maxWidth: 320),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const _SplashBrandLockup(),
                              const SizedBox(height: 18),
                              const _SplashMark(),
                              const SizedBox(height: 18),
                              _SplashLoader(
                                semanticLabel: context.l10n.appSplashPreparing,
                              ),
                              const SizedBox(height: 18),
                              Text(
                                context.l10n.appSplashPreparing,
                                textAlign: TextAlign.center,
                                style: Theme.of(context)
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                      color: colorScheme.onPrimary.withValues(
                                        alpha: 0.92,
                                      ),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                      height: 1.25,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashBrandLockup extends ConsumerWidget {
  const _SplashBrandLockup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final rawLogoUrl = bootstrap?.brand.logoUrl.trim() ?? '';
    final logoUrl =
        rawLogoUrl.isEmpty ? '' : _resolveSplashLogoUrl(ref, rawLogoUrl);
    final siteName = bootstrap?.siteName.trim() ?? '';
    final textStyle = Theme.of(context).textTheme;
    final onBlue = Theme.of(context).colorScheme.onPrimary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (logoUrl.isNotEmpty)
          SizedBox(
            height: 34,
            width: 96,
            child: FlexibleImage(source: logoUrl, fit: BoxFit.contain),
          )
        else
          Text(
            'GLO',
            textAlign: TextAlign.center,
            style: textStyle.headlineSmall?.copyWith(
              color: onBlue,
              fontSize: 28,
              fontWeight: FontWeight.w700,
              height: 0.92,
            ),
          ),
        if (siteName.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(
            siteName,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: textStyle.labelSmall?.copyWith(
              color: onBlue.withValues(alpha: 0.90),
              fontSize: 10,
              fontWeight: FontWeight.w600,
              height: 1.18,
            ),
          ),
        ],
      ],
    );
  }
}

class _SplashMark extends StatelessWidget {
  const _SplashMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppTheme.appSheet,
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF002D6C).withValues(alpha: 0.26),
            blurRadius: 44,
            offset: const Offset(0, 20),
          ),
        ],
      ),
      child: SizedBox.square(
        dimension: 86,
        child: Center(
          child: Text(
            'L6',
            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  color: AppTheme.appBlue,
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  height: 1,
                ),
          ),
        ),
      ),
    );
  }
}

class _SplashLoader extends StatefulWidget {
  const _SplashLoader({required this.semanticLabel});

  final String semanticLabel;

  @override
  State<_SplashLoader> createState() => _SplashLoaderState();
}

class _SplashLoaderState extends State<_SplashLoader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1050),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final onBlue = Theme.of(context).colorScheme.onPrimary;
    return Semantics(
      label: widget.semanticLabel,
      liveRegion: true,
      child: SizedBox(
        width: 156,
        height: 6,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: ColoredBox(
            color: onBlue.withValues(alpha: 0.32),
            child: AnimatedBuilder(
              animation: _controller,
              builder: (context, _) {
                final progress = _controller.value;
                final alignment = Alignment.lerp(
                  const Alignment(-1.92, 0),
                  const Alignment(2.80, 0),
                  progress,
                )!;
                return Align(
                  alignment: alignment,
                  child: FractionallySizedBox(
                    widthFactor: 0.46,
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: onBlue,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class _SplashYellowCorner extends StatelessWidget {
  const _SplashYellowCorner();

  @override
  Widget build(BuildContext context) {
    final shortestSide = MediaQuery.sizeOf(context).shortestSide;
    final size = (shortestSide * 0.44).clamp(112.0, 180.0);
    return CustomPaint(
      size: Size.square(size),
      painter: _SplashYellowCornerPainter(),
    );
  }
}

class _SplashYellowCornerPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = AppTheme.appYellow;
    final path = Path()
      ..moveTo(size.width, 0)
      ..lineTo(0, size.height)
      ..lineTo(size.width, size.height)
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SplashYellowCornerPainter oldDelegate) => false;
}

String _resolveSplashLogoUrl(WidgetRef ref, String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      (uri.hasScheme ||
          trimmed.startsWith('data:') ||
          trimmed.startsWith('//'))) {
    return trimmed;
  }
  return ref.watch(assetUrlResolverProvider)(trimmed);
}
