import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/i18n/customer_localizations.dart';
import '../../core/tenant/mobile_bootstrap_controller.dart';
import '../../core/theme/app_theme.dart';
import 'customer_loading_indicator.dart';

const _pinInk = Color(0xFF2F3337);
const _pinMuted = Color(0xFF9AA0A6);
const _pinBack = Color(0xFF8B9299);
const _pinBrand = Color(0xFF8487F8);
const _pinErrorColor = Color(0xFFD3455B);
const _pinDotEmpty = Color(0xFFDDDDDF);
const _pinDotError = Color(0xFFF2B6BD);

class PinConfirmationStep extends ConsumerWidget {
  const PinConfirmationStep({
    required this.title,
    required this.subtitle,
    required this.pin,
    required this.error,
    required this.saving,
    required this.biometricEnabled,
    required this.biometricLabel,
    required this.onBack,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
    this.brand,
    super.key,
  });

  final String? brand;
  final String title;
  final String subtitle;
  final String pin;
  final String error;
  final bool saving;
  final bool biometricEnabled;
  final String biometricLabel;
  final VoidCallback onBack;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final width = MediaQuery.sizeOf(context).width;
    final height = MediaQuery.sizeOf(context).height;
    final compactHeight = height < 660;
    final mainVerticalPadding = (height * 0.05).clamp(10.0, 58.0).toDouble();
    final horizontal = width <= 360 ? 22.0 : 28.0;
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(horizontal, 12, horizontal, 22),
          child: Column(
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: _PinConfirmationTopBar(
                  brand: brand ??
                      customerPinBrandLabel(
                        context,
                        ref.watch(mobileBootstrapProvider).valueOrNull,
                      ),
                  saving: saving,
                  onBack: onBack,
                ),
              ),
              Expanded(
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 430),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        vertical: mainVerticalPadding,
                      ),
                      child: Center(
                        child: _PinConfirmationMainContent(
                          title: title,
                          subtitle: subtitle,
                          pinLength: pin.length,
                          error: error,
                          saving: saving,
                          biometricEnabled: biometricEnabled,
                          biometricLabel: biometricLabel,
                          compact: compactHeight,
                          onBiometric: onBiometric,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: _PinKeypad(
                  pinLength: pin.length,
                  enabled: !saving,
                  compact: compactHeight,
                  onDigit: onDigit,
                  onBackspace: onBackspace,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String customerPinBrandLabel(
  BuildContext context,
  MobileBootstrap? bootstrap,
) {
  final siteName = bootstrap?.siteName.trim() ?? '';
  if (siteName.isNotEmpty) return siteName;
  final productLabel = bootstrap?.lotteryProductLabel.trim() ?? '';
  if (productLabel.isNotEmpty) return productLabel;
  return context.l10n.pinBrand;
}

class _PinConfirmationTopBar extends StatelessWidget {
  const _PinConfirmationTopBar({
    required this.brand,
    required this.saving,
    required this.onBack,
  });

  final String? brand;
  final bool saving;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final resolvedBrand = brand?.trim().isNotEmpty == true
        ? brand!.trim()
        : context.l10n.pinBrand;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 430),
      child: SizedBox(
        height: 42,
        child: Row(
          children: [
            SizedBox(
              width: 42,
              child: IconButton(
                alignment: Alignment.centerLeft,
                padding: EdgeInsets.zero,
                tooltip: MaterialLocalizations.of(context).backButtonTooltip,
                onPressed: saving ? null : onBack,
                icon: const Icon(Icons.chevron_left, size: 24),
                color: _pinBack,
                disabledColor: _pinBack.withValues(alpha: 0.45),
                style: IconButton.styleFrom(
                  overlayColor: Colors.transparent,
                ),
              ),
            ),
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    resolvedBrand,
                    maxLines: 1,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: _pinBrand,
                          fontSize: 16,
                          fontWeight: FontWeight.w900,
                          height: 1,
                        ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 42),
          ],
        ),
      ),
    );
  }
}

class _PinConfirmationMainContent extends StatelessWidget {
  const _PinConfirmationMainContent({
    required this.title,
    required this.subtitle,
    required this.pinLength,
    required this.error,
    required this.saving,
    required this.biometricEnabled,
    required this.biometricLabel,
    required this.compact,
    required this.onBiometric,
  });

  final String title;
  final String subtitle;
  final int pinLength;
  final String error;
  final bool saving;
  final bool biometricEnabled;
  final String biometricLabel;
  final bool compact;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final height = MediaQuery.sizeOf(context).height;
    final dotGap = (height * 0.05).clamp(21.0, 34.0).toDouble();
    final messageTop = (height * 0.03).clamp(12.0, 17.0).toDouble();
    final messageMinHeight =
        compact ? 18.0 : (height * 0.04).clamp(18.0, 33.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                color: _pinInk,
                fontSize: 30,
                fontWeight: FontWeight.w900,
                height: 1.2,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: _pinMuted,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
        ),
        SizedBox(height: dotGap),
        _PinDots(length: pinLength, hasError: error.isNotEmpty),
        AnimatedOpacity(
          opacity: error.isEmpty ? 0 : 1,
          duration: const Duration(milliseconds: 120),
          child: Container(
            constraints: BoxConstraints(
              minHeight: messageMinHeight,
              maxWidth: 260,
            ),
            alignment: Alignment.center,
            margin: EdgeInsets.only(top: messageTop),
            child: Text(
              error.isEmpty ? ' ' : error,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _pinErrorColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    height: 1.35,
                  ),
            ),
          ),
        ),
        if (saving) ...[
          const SizedBox(height: 10),
          CustomerLoadingMark(
            semanticLabel: title,
            width: 140,
            height: 18,
            color: colorScheme.primary,
            trackColor: colorScheme.outlineVariant.withValues(alpha: 0.56),
          ),
        ],
        if (biometricEnabled) ...[
          const SizedBox(height: 4),
          SizedBox(
            height: 32,
            child: Center(
              child: TextButton.icon(
                onPressed: saving ? null : onBiometric,
                icon: const Icon(Icons.face_retouching_natural, size: 18),
                label: Text(biometricLabel),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.pinAction(
                    Theme.of(context).colorScheme.primary,
                  ),
                  minimumSize: const Size(64, 32),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        height: 1,
                      ),
                ).copyWith(
                  overlayColor: const WidgetStatePropertyAll(
                    Colors.transparent,
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PinDots extends StatelessWidget {
  const _PinDots({required this.length, required this.hasError});

  final int length;
  final bool hasError;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var index = 0; index < 6; index++) ...[
          AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            curve: Curves.easeOut,
            width: 9,
            height: 9,
            decoration: BoxDecoration(
              color: hasError
                  ? _pinDotError
                  : index < length
                      ? _pinInk
                      : _pinDotEmpty,
              shape: BoxShape.circle,
            ),
          ),
          if (index < 5) const SizedBox(width: 12),
        ],
      ],
    );
  }
}

class _PinKeypad extends StatelessWidget {
  const _PinKeypad({
    required this.pinLength,
    required this.enabled,
    required this.compact,
    required this.onDigit,
    required this.onBackspace,
  });

  final int pinLength;
  final bool enabled;
  final bool compact;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    final horizontalGap = MediaQuery.sizeOf(context).width <= 360 ? 24.0 : 30.0;
    final height = MediaQuery.sizeOf(context).height;
    final verticalGap = (height * 0.05).clamp(17.0, 26.0).toDouble();
    final itemHeight = (height * 0.085).clamp(36.0, 43.0).toDouble();
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 340),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final itemWidth = (constraints.maxWidth - horizontalGap * 2) / 3;
          return Wrap(
            spacing: horizontalGap,
            runSpacing: verticalGap,
            children: [
              for (final key in keys)
                SizedBox(
                  width: itemWidth,
                  height: itemHeight,
                  child: key.isEmpty
                      ? const SizedBox.shrink()
                      : _PinKeyButton(
                          value: key,
                          enabled: enabled,
                          backspaceEnabled: pinLength > 0,
                          onDigit: onDigit,
                          onBackspace: onBackspace,
                        ),
                ),
            ],
          );
        },
      ),
    );
  }
}

class _PinKeyButton extends StatelessWidget {
  const _PinKeyButton({
    required this.value,
    required this.enabled,
    required this.backspaceEnabled,
    required this.onDigit,
    required this.onBackspace,
  });

  final String value;
  final bool enabled;
  final bool backspaceEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;

  bool get _isBackspace => value == 'back';

  @override
  Widget build(BuildContext context) {
    final active = enabled && (!_isBackspace || backspaceEnabled);
    return Semantics(
      button: true,
      label: _isBackspace
          ? MaterialLocalizations.of(context).deleteButtonTooltip
          : value,
      enabled: active,
      child: TextButton(
        onPressed: active
            ? _isBackspace
                ? onBackspace
                : () => onDigit(value)
            : null,
        style: TextButton.styleFrom(
          foregroundColor: _isBackspace ? _pinBack : _pinInk,
          disabledForegroundColor:
              (_isBackspace ? _pinBack : _pinInk).withValues(alpha: 0.42),
          minimumSize: const Size(54, 36),
          padding: EdgeInsets.zero,
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          shape: const CircleBorder(),
          textStyle: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
        ).copyWith(
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
        child: _isBackspace
            ? const Icon(Icons.backspace_outlined, size: 17)
            : Text(value),
      ),
    );
  }
}
