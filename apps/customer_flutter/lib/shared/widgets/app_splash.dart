import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/auth/auth_controller.dart';
import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';

const appSplashBackgroundAsset = 'assets/images/splash/siamblend_splash.jpg';
const _appSplashFallbackColor = Color(0xFF0B96DC);
const _appSplashNavigationBarColor = Color(0xFF0788CF);

Future<void> precacheAppSplashBackground() async {
  final stream = const AssetImage(
    appSplashBackgroundAsset,
  ).resolve(ImageConfiguration.empty);
  final completer = Completer<void>();
  late final ImageStreamListener listener;
  listener = ImageStreamListener(
    (_, __) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
    onError: (_, __) {
      stream.removeListener(listener);
      if (!completer.isCompleted) completer.complete();
    },
  );
  stream.addListener(listener);
  await completer.future;
}

final appSplashMinimumDurationProvider = Provider<Duration>(
  (_) => const Duration(milliseconds: 650),
);
final appSplashFadeDurationProvider = Provider<Duration>(
  (_) => const Duration(milliseconds: 260),
);

class AppSplashHost extends ConsumerStatefulWidget {
  const AppSplashHost({required this.child, super.key});

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
    final authStartup = ref.watch(authSessionStartupProvider);
    final bootstrapReady = bootstrap.hasValue || bootstrap.hasError;
    final authReady = authStartup.hasValue || authStartup.hasError;
    final ready = bootstrapReady && authReady;
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
    final authStartup = ref.read(authSessionStartupProvider);
    if ((!bootstrap.hasValue && !bootstrap.hasError) ||
        (!authStartup.hasValue && !authStartup.hasError)) {
      return;
    }

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

  @override
  Widget build(BuildContext context) {
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: leaving,
        child: AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.transparent,
            statusBarBrightness: Brightness.dark,
            statusBarIconBrightness: Brightness.light,
            systemNavigationBarColor: _appSplashNavigationBarColor,
            systemNavigationBarIconBrightness: Brightness.light,
          ),
          child: AnimatedOpacity(
            opacity: leaving ? 0 : 1,
            duration: const Duration(milliseconds: 260),
            curve: Curves.easeOut,
            child: Material(
              key: const ValueKey('app-splash-surface'),
              color: _appSplashFallbackColor,
              child: Stack(
                children: [
                  const Positioned.fill(child: _SplashArtwork()),
                  const Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.transparent,
                            Colors.transparent,
                            Color(0x1A034E91),
                          ],
                          stops: [0, 0.72, 1],
                        ),
                      ),
                    ),
                  ),
                  SafeArea(
                    minimum: const EdgeInsets.fromLTRB(28, 16, 28, 24),
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: _SplashLoader(
                        semanticLabel: context.l10n.appSplashPreparing,
                      ),
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

class _SplashArtwork extends StatelessWidget {
  const _SplashArtwork();

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final useContainedArtwork =
        size.height > 0 && size.width / size.height >= 0.75;

    return ColoredBox(
      color: _appSplashFallbackColor,
      child: Image.asset(
        appSplashBackgroundAsset,
        key: const ValueKey('app-splash-background'),
        fit: useContainedArtwork ? BoxFit.contain : BoxFit.cover,
        alignment: Alignment.center,
        filterQuality: FilterQuality.high,
        gaplessPlayback: true,
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
      duration: const Duration(milliseconds: 1350),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      key: const ValueKey('app-splash-loader'),
      label: widget.semanticLabel,
      liveRegion: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 190),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: const Color(0xA6075A9C),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: const Color(0x4DFFFFFF)),
            boxShadow: const [
              BoxShadow(
                color: Color(0x3300315E),
                blurRadius: 20,
                offset: Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 10, 18, 11),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  widget.semanticLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                    shadows: const [
                      Shadow(color: Color(0x4000315E), blurRadius: 6),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: 142,
                  height: 4,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: ColoredBox(
                      color: const Color(0x47FFFFFF),
                      child: AnimatedBuilder(
                        animation: _controller,
                        builder: (context, _) {
                          final progress = Curves.easeInOut.transform(
                            _controller.value,
                          );
                          final alignment = Alignment.lerp(
                            const Alignment(-2.2, 0),
                            const Alignment(2.8, 0),
                            progress,
                          )!;
                          return Align(
                            alignment: alignment,
                            child: FractionallySizedBox(
                              widthFactor: 0.42,
                              heightFactor: 1,
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: const LinearGradient(
                                    colors: [
                                      Color(0xFFFFF2B8),
                                      Color(0xFFE7B64C),
                                      Color(0xFFFFEBA0),
                                    ],
                                  ),
                                  borderRadius: BorderRadius.circular(999),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Color(0x99F3CC69),
                                      blurRadius: 5,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
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
