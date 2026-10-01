import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_gradient_button.dart';

double authHeroTopPadding(BuildContext context) {
  final topInset = MediaQuery.paddingOf(context).top;
  return topInset + 14 > 58 ? topInset + 14 : 58;
}

double authContentSheetOverlap(double viewportWidth) {
  return (-viewportWidth * 0.15).clamp(-64.0, -34.0);
}

double authContentSheetMinHeight(
  double viewportWidth,
  double viewportHeight,
) {
  if (viewportWidth <= 520) {
    return viewportHeight > 155 ? viewportHeight - 155 : 0;
  }
  return 620;
}

class AuthBlueHeroBackdrop extends StatelessWidget {
  const AuthBlueHeroBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return CustomerBlueHeroBackdrop(
      primary: colorScheme.primary,
      secondary: colorScheme.secondary,
      child: child,
    );
  }
}

class AuthLoginHeroBackdrop extends StatelessWidget {
  const AuthLoginHeroBackdrop({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            colorScheme.primary,
            AppTheme.heroGradientEnd(colorScheme.primary),
          ],
        ),
      ),
      child: Stack(
        children: [
          const _AuthLoginHeroAccents(),
          child,
        ],
      ),
    );
  }
}

class _AuthLoginHeroAccents extends StatelessWidget {
  const _AuthLoginHeroAccents();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Positioned.fill(
      child: IgnorePointer(
        child: Stack(
          children: [
            Positioned(
              right: -76,
              bottom: -126,
              child: Container(
                width: 344,
                height: 344,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.secondary.withValues(alpha: 0.34),
                ),
              ),
            ),
            Positioned(
              right: 34,
              bottom: 34,
              child: Container(
                width: 116,
                height: 116,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: colorScheme.tertiary.withValues(alpha: 0.86),
                ),
              ),
            ),
            Positioned(
              left: -78,
              top: 26,
              child: Transform.rotate(
                angle: -0.58,
                child: Container(
                  width: 360,
                  height: 88,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(44),
                  ),
                ),
              ),
            ),
            Positioned(
              left: 82,
              bottom: 40,
              child: Transform.rotate(
                angle: -0.58,
                child: Container(
                  width: 310,
                  height: 78,
                  decoration: BoxDecoration(
                    color: colorScheme.onPrimary.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(42),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

Widget authBlueHeroTopRow(
  BuildContext context, {
  required String title,
  required String tooltip,
  VoidCallback? onBack,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Center(
    child: ConstrainedBox(
      constraints:
          BoxConstraints(maxWidth: customerContentMaxWidthFor(context)),
      child: SizedBox(
        height: 42,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PositionedDirectional(
              start: 0,
              top: 0,
              child: authHeroBackButton(
                context,
                tooltip: tooltip,
                onPressed: onBack,
              ),
            ),
            Positioned.fill(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 54),
                child: Center(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: colorScheme.onPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          height: 1.15,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Widget authHeroBackButton(
  BuildContext context, {
  required String tooltip,
  VoidCallback? onPressed,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return IconButton(
    tooltip: tooltip,
    onPressed: onPressed,
    color: colorScheme.onPrimary,
    disabledColor: colorScheme.onPrimary.withValues(alpha: 0.54),
    icon: const Icon(Icons.chevron_left_rounded, size: 31),
    style: IconButton.styleFrom(
      backgroundColor: Colors.transparent,
      fixedSize: const Size.square(42),
      minimumSize: const Size.square(42),
      padding: EdgeInsets.zero,
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    ),
  );
}

InputDecoration authInputDecoration(
  BuildContext context, {
  required String hintText,
  required Widget prefixIcon,
  Widget? suffixIcon,
  bool softFill = false,
  Color? accentColor,
  double borderRadius = 12,
  double prefixIconSize = 22,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final effectiveAccent = accentColor ?? colorScheme.primary;
  final radius = BorderRadius.circular(borderRadius);
  final fillColor = softFill
      ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.34)
      : colorScheme.surface;
  final borderColor = colorScheme.outlineVariant.withValues(alpha: 0.86);
  final disabledBorderColor =
      colorScheme.outlineVariant.withValues(alpha: 0.72);

  OutlineInputBorder border(Color color, {double width = 1}) {
    return OutlineInputBorder(
      borderRadius: radius,
      borderSide: BorderSide(color: color, width: width),
    );
  }

  return InputDecoration(
    hintText: hintText,
    prefixIcon: IconTheme(
      data: IconThemeData(color: effectiveAccent, size: prefixIconSize),
      child: prefixIcon,
    ),
    prefixIconConstraints: const BoxConstraints(minWidth: 46, minHeight: 54),
    suffixIcon: suffixIcon,
    suffixIconConstraints: const BoxConstraints(minWidth: 48, minHeight: 54),
    filled: true,
    fillColor: fillColor,
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 16),
    enabledBorder: border(borderColor),
    focusedBorder: border(effectiveAccent, width: 1.2),
    errorBorder: border(colorScheme.error),
    focusedErrorBorder: border(colorScheme.error, width: 1.2),
    disabledBorder: border(disabledBorderColor),
  );
}

Widget authInputActionButton(
  BuildContext context, {
  required IconData icon,
  required String tooltip,
  required VoidCallback? onPressed,
}) {
  final colorScheme = Theme.of(context).colorScheme;
  return Padding(
    padding: const EdgeInsetsDirectional.only(end: 8),
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 20),
      style: IconButton.styleFrom(
        backgroundColor: Colors.transparent,
        disabledBackgroundColor: Colors.transparent,
        foregroundColor: colorScheme.onSurfaceVariant,
        disabledForegroundColor:
            colorScheme.onSurfaceVariant.withValues(alpha: 0.54),
        overlayColor: Colors.transparent,
        fixedSize: const Size.square(36),
        minimumSize: const Size.square(36),
        padding: EdgeInsets.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
    ),
  );
}

TextStyle? authInputTextStyle(
  BuildContext context, {
  FontWeight fontWeight = FontWeight.w600,
}) {
  final theme = Theme.of(context);
  return theme.textTheme.bodyLarge?.copyWith(
    color: theme.colorScheme.onSurface,
    fontSize: 16,
    fontWeight: fontWeight,
    height: 1.2,
  );
}

Widget authPrimaryActionButton({
  required String label,
  required VoidCallback? onPressed,
  double height = 52,
  double fontSize = 16,
  bool shadow = true,
}) {
  return CustomerGradientButton.text(
    onPressed: onPressed,
    height: height,
    fontSize: fontSize,
    shadow: shadow,
    label: label,
  );
}
