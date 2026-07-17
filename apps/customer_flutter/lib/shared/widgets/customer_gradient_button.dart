import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

class CustomerGradientButton extends StatelessWidget {
  const CustomerGradientButton({
    required this.onPressed,
    required this.child,
    super.key,
    this.height = 47,
    this.fontSize = 17,
    this.fontWeight = FontWeight.w700,
    this.horizontalPadding = 18,
    this.shadow = true,
    this.enabledGradient,
  });

  factory CustomerGradientButton.text({
    required String label,
    required VoidCallback? onPressed,
    Key? key,
    double height = 47,
    double fontSize = 17,
    FontWeight fontWeight = FontWeight.w700,
    double horizontalPadding = 18,
    bool shadow = true,
    LinearGradient? enabledGradient,
  }) {
    return CustomerGradientButton(
      key: key,
      onPressed: onPressed,
      height: height,
      fontSize: fontSize,
      fontWeight: fontWeight,
      horizontalPadding: horizontalPadding,
      shadow: shadow,
      enabledGradient: enabledGradient,
      child: Text(label),
    );
  }

  final VoidCallback? onPressed;
  final Widget child;
  final double height;
  final double fontSize;
  final FontWeight fontWeight;
  final double horizontalPadding;
  final bool shadow;
  final LinearGradient? enabledGradient;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final enabled = onPressed != null;
    final gradient = enabledGradient ??
        LinearGradient(
          colors: [
            AppTheme.primaryActionStart(colorScheme.primary),
            AppTheme.primaryActionEnd(colorScheme.primary),
          ],
        );

    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: enabled ? gradient : null,
        color: enabled ? null : AppTheme.appDisabledAction,
        borderRadius: BorderRadius.circular(999),
        boxShadow: enabled && shadow
            ? [
                BoxShadow(
                  color: colorScheme.primary.withValues(alpha: 0.22),
                  blurRadius: 22,
                  offset: const Offset(0, 10),
                ),
              ]
            : null,
      ),
      child: SizedBox(
        height: height,
        child: FilledButton(
          onPressed: onPressed,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            disabledBackgroundColor: Colors.transparent,
            foregroundColor: colorScheme.onPrimary,
            disabledForegroundColor: colorScheme.onPrimary,
            shadowColor: Colors.transparent,
            padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
            shape: const StadiumBorder(),
            textStyle: Theme.of(context).textTheme.titleSmall?.copyWith(
                  fontSize: fontSize,
                  fontWeight: fontWeight,
                  height: 1.1,
                ),
          ).copyWith(
            overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          ),
          child: child,
        ),
      ),
    );
  }
}

class CustomerPaymentSelectionCountText extends StatelessWidget {
  const CustomerPaymentSelectionCountText({
    required this.count,
    required this.countText,
    super.key,
    this.numberFontSize = 21,
    this.textFontSize = 18,
  });

  final int count;
  final String countText;
  final double numberFontSize;
  final double textFontSize;

  @override
  Widget build(BuildContext context) {
    final number = count.toString();
    final numberIndex = countText.indexOf(number);
    if (numberIndex < 0) {
      return Text(
        countText,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              color: AppTheme.appInk,
              fontSize: textFontSize,
              fontWeight: FontWeight.w600,
              height: 1,
            ),
      );
    }
    final before = countText.substring(0, numberIndex);
    final after = countText.substring(numberIndex + number.length);
    return Text.rich(
      TextSpan(
        children: [
          if (before.isNotEmpty) TextSpan(text: before),
          TextSpan(
            text: number,
            style: TextStyle(
              color: AppTheme.primaryPaymentCount(
                Theme.of(context).colorScheme.primary,
              ),
              fontSize: numberFontSize,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (after.isNotEmpty) TextSpan(text: after),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: AppTheme.appInk,
            fontSize: textFontSize,
            fontWeight: FontWeight.w600,
            height: 1,
          ),
    );
  }
}
