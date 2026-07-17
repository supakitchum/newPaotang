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
    final foreground = switch (state.variant) {
      AppAlertVariant.error => const Color(0xFFE03131),
      AppAlertVariant.warning => const Color(0xFFF19B00),
      AppAlertVariant.info => const Color(0xFF086BDD),
    };
    final iconBackground = switch (state.variant) {
      AppAlertVariant.error => const Color(0xFFFFE8E8),
      AppAlertVariant.warning => const Color(0xFFFFF4DF),
      AppAlertVariant.info => const Color(0xFFE8F4FF),
    };
    final icon = switch (state.variant) {
      AppAlertVariant.error => Icons.close_rounded,
      AppAlertVariant.warning => Icons.priority_high_rounded,
      AppAlertVariant.info => Icons.info_outline_rounded,
    };
    final iconSize = switch (state.variant) {
      AppAlertVariant.error => 30.0,
      AppAlertVariant.warning => 38.0,
      AppAlertVariant.info => 34.0,
    };
    final title =
        state.title.trim().isEmpty ? l10n.appAlertDefaultTitle : state.title;
    final button =
        state.button.trim().isEmpty ? l10n.appAlertDefaultButton : state.button;

    return Positioned.fill(
      child: Material(
        color: const Color(0x94001636),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Center(
              child: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 342),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.fromLTRB(24, 31, 24, 25),
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFFFFF),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x3D002658),
                          blurRadius: 44,
                          offset: Offset(0, 20),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: iconBackground,
                            shape: BoxShape.circle,
                          ),
                          alignment: Alignment.center,
                          child: Icon(
                            icon,
                            color: foreground,
                            size: iconSize,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style:
                              Theme.of(context).textTheme.titleLarge?.copyWith(
                                    color: const Color(0xFF242833),
                                    fontSize: 22,
                                    fontWeight: FontWeight.w800,
                                    height: 1.3,
                                  ),
                        ),
                        if (state.message.trim().isNotEmpty) ...[
                          const SizedBox(height: 12),
                          Text(
                            state.message,
                            textAlign: TextAlign.center,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: const Color(0xFF5D6470),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  height: 1.55,
                                ),
                          ),
                        ],
                        const SizedBox(height: 22),
                        SizedBox(
                          width: double.infinity,
                          child: CustomerGradientButton.text(
                            key: const ValueKey('app-alert-close-button'),
                            onPressed: () {
                              ref
                                  .read(appAlertControllerProvider.notifier)
                                  .close();
                            },
                            height: 52,
                            fontSize: 18,
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
        ),
      ),
    );
  }
}
