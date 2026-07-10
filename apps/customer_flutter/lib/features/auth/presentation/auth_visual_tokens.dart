import 'package:flutter/material.dart';

import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/customer_gradient_button.dart';

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
}) {
  final colorScheme = Theme.of(context).colorScheme;
  final effectiveAccent = accentColor ?? colorScheme.primary;
  final radius = BorderRadius.circular(12);
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
      data: IconThemeData(color: effectiveAccent, size: 22),
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
        backgroundColor: colorScheme.primaryContainer.withValues(alpha: 0.72),
        disabledBackgroundColor:
            colorScheme.surfaceContainerHighest.withValues(alpha: 0.62),
        foregroundColor: colorScheme.primary,
        disabledForegroundColor:
            colorScheme.onSurfaceVariant.withValues(alpha: 0.54),
        fixedSize: const Size.square(34),
        minimumSize: const Size.square(34),
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
