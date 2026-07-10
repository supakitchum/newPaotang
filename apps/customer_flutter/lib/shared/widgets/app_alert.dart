import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/customer_localizations.dart';
import 'customer_gradient_button.dart';

final appAlertControllerProvider =
    StateNotifierProvider<AppAlertController, AppAlertState>((ref) {
  return AppAlertController();
});

enum AppAlertVariant { info, warning, error }

class AppAlertState {
  const AppAlertState({
    this.visible = false,
    this.title = '',
    this.message = '',
    this.button = '',
    this.variant = AppAlertVariant.info,
  });

  final bool visible;
  final String title;
  final String message;
  final String button;
  final AppAlertVariant variant;

  AppAlertState copyWith({
    bool? visible,
    String? title,
    String? message,
    String? button,
    AppAlertVariant? variant,
  }) {
    return AppAlertState(
      visible: visible ?? this.visible,
      title: title ?? this.title,
      message: message ?? this.message,
      button: button ?? this.button,
      variant: variant ?? this.variant,
    );
  }
}

class AppAlertController extends StateNotifier<AppAlertState> {
  AppAlertController() : super(const AppAlertState());

  void show({
    required String message,
    String title = '',
    String button = '',
    AppAlertVariant variant = AppAlertVariant.info,
  }) {
    state = AppAlertState(
      visible: true,
      title: title,
      message: message,
      button: button,
      variant: variant,
    );
  }

  void close() {
    state = state.copyWith(visible: false);
  }
}

class AppAlertHost extends ConsumerWidget {
  const AppAlertHost({
    required this.child,
    super.key,
  });

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(appAlertControllerProvider);
    return Stack(
      children: [
        child,
        if (state.visible) _AppAlertOverlay(state: state),
      ],
    );
  }
}

class _AppAlertOverlay extends ConsumerWidget {
  const _AppAlertOverlay({required this.state});

  final AppAlertState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final colors = Theme.of(context).colorScheme;
    final foreground = switch (state.variant) {
      AppAlertVariant.error => colors.error,
      AppAlertVariant.warning => colors.tertiary,
      AppAlertVariant.info => colors.primary,
    };
    final icon = switch (state.variant) {
      AppAlertVariant.error => Icons.close_rounded,
      AppAlertVariant.warning => Icons.priority_high_rounded,
      AppAlertVariant.info => Icons.info_outline_rounded,
    };
    final title =
        state.title.trim().isEmpty ? l10n.appAlertDefaultTitle : state.title;
    final button =
        state.button.trim().isEmpty ? l10n.appAlertDefaultButton : state.button;

    return Positioned.fill(
      child: Material(
        color: colors.scrim.withValues(alpha: 0.48),
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Container(
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
                decoration: BoxDecoration(
                  color: colors.surface,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: colors.shadow.withValues(alpha: 0.15),
                      blurRadius: 28,
                      offset: const Offset(0, 16),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(
                      radius: 30,
                      backgroundColor: foreground.withValues(alpha: 0.12),
                      child: Icon(icon, color: foreground, size: 34),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w900,
                            color: colors.onSurface,
                          ),
                    ),
                    if (state.message.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Text(
                        state.message,
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colors.onSurfaceVariant
                                  .withValues(alpha: 0.9),
                              height: 1.4,
                            ),
                      ),
                    ],
                    const SizedBox(height: 22),
                    SizedBox(
                      width: double.infinity,
                      child: CustomerGradientButton.text(
                        key: const ValueKey('app-alert-close-button'),
                        onPressed: () {
                          ref.read(appAlertControllerProvider.notifier).close();
                        },
                        height: 47,
                        fontSize: 15,
                        shadow: false,
                        label: button,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
