import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LotteryDigitInputStyle {
  const LotteryDigitInputStyle({
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.focusedBorderColor,
    this.borderRadius = 16,
    this.spacing = 6,
    this.verticalPadding = 12,
  });

  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? focusedBorderColor;
  final double borderRadius;
  final double spacing;
  final double verticalPadding;
}

class LotteryDigitInputRow extends StatelessWidget {
  const LotteryDigitInputRow({
    required this.controllers,
    super.key,
    this.style = const LotteryDigitInputStyle(),
    this.onSubmitted,
    this.onTap,
    this.readOnly = false,
  }) : assert(controllers.length == 6, 'Lottery number requires 6 digits');

  final List<TextEditingController> controllers;
  final LotteryDigitInputStyle style;
  final VoidCallback? onSubmitted;
  final VoidCallback? onTap;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final fillColor = style.fillColor ?? Colors.white;
    final focusedBorderColor = style.focusedBorderColor ?? colorScheme.primary;
    final hintColor =
        style.hintColor ?? colorScheme.onSurface.withValues(alpha: 0.28);
    final textColor = style.textColor ?? colorScheme.onSurface;

    return Row(
      children: [
        for (var index = 0; index < controllers.length; index++) ...[
          Expanded(
            child: TextField(
              controller: controllers[index],
              readOnly: readOnly,
              showCursor: !readOnly,
              enableInteractiveSelection: !readOnly,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              textInputAction: index == controllers.length - 1
                  ? TextInputAction.search
                  : TextInputAction.next,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
                LengthLimitingTextInputFormatter(1),
              ],
              style: theme.textTheme.titleLarge?.copyWith(
                color: textColor,
                fontWeight: FontWeight.w900,
              ),
              decoration: InputDecoration(
                hintText: '${index + 1}',
                hintStyle: TextStyle(
                  color: hintColor,
                  fontWeight: FontWeight.w900,
                ),
                contentPadding:
                    EdgeInsets.symmetric(vertical: style.verticalPadding),
                filled: true,
                fillColor: fillColor,
                border: _border(style.borderRadius, BorderSide.none),
                enabledBorder: _border(style.borderRadius, BorderSide.none),
                focusedBorder: _border(
                  style.borderRadius,
                  BorderSide(color: focusedBorderColor, width: 2),
                ),
              ),
              onChanged: (_) {
                if (readOnly) return;
                if (controllers[index].text.isNotEmpty &&
                    index < controllers.length - 1) {
                  FocusScope.of(context).nextFocus();
                }
              },
              onTap: onTap,
              onSubmitted: (_) {
                if (readOnly) return;
                if (index == controllers.length - 1) onSubmitted?.call();
              },
            ),
          ),
          if (index < controllers.length - 1) SizedBox(width: style.spacing),
        ],
      ],
    );
  }
}

OutlineInputBorder _border(double radius, BorderSide side) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: side,
  );
}
