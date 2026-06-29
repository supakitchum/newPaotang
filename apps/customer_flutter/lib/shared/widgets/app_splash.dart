import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';
import 'tenant_brand_header.dart';

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

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        ignoring: leaving,
        child: AnimatedOpacity(
          opacity: leaving ? 0 : 1,
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          child: Material(
            color: colors.primary,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    colors.primary,
                    colors.secondary,
                  ],
                ),
              ),
              child: SafeArea(
                child: Center(
                  child: Semantics(
                    label: context.l10n.appSplashPreparing,
                    liveRegion: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const TenantBrandHeader(
                          showName: true,
                          size: 74,
                          icon: Icons.confirmation_number_outlined,
                          textColor: Colors.white,
                        ),
                        const SizedBox(height: 22),
                        SizedBox(
                          width: 34,
                          height: 34,
                          child: CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              colors.onPrimary,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          context.l10n.appSplashPreparing,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleMedium?.copyWith(
                                    color: colors.onPrimary,
                                    fontWeight: FontWeight.w800,
                                  ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
