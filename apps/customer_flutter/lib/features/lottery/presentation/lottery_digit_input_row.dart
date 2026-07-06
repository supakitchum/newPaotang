import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class LotteryDigitInputStyle {
  const LotteryDigitInputStyle({
    this.fillColor,
    this.textColor,
    this.hintColor,
    this.focusedBorderColor,
    this.enabledBorderColor,
    this.shadowColor,
    this.borderRadius = 16,
    this.spacing = 6,
    this.verticalPadding = 12,
    this.borderWidth = 1,
    this.shadowBlurRadius = 0,
    this.shadowOffset = Offset.zero,
    this.maxDigitWidth,
  });

  final Color? fillColor;
  final Color? textColor;
  final Color? hintColor;
  final Color? focusedBorderColor;
  final Color? enabledBorderColor;
  final Color? shadowColor;
  final double borderRadius;
  final double spacing;
  final double verticalPadding;
  final double borderWidth;
  final double shadowBlurRadius;
  final Offset shadowOffset;
  final double? maxDigitWidth;
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
    final enabledBorderSide = style.enabledBorderColor == null
        ? BorderSide.none
        : BorderSide(
            color: style.enabledBorderColor!,
            width: style.borderWidth,
          );
    final hintColor =
        style.hintColor ?? colorScheme.onSurface.withValues(alpha: 0.28);
    final textColor = style.textColor ?? colorScheme.onSurface;

    Widget fieldForIndex(int index) {
      final field = TextField(
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
          contentPadding: EdgeInsets.symmetric(vertical: style.verticalPadding),
          filled: true,
          fillColor: fillColor,
          border: _border(style.borderRadius, enabledBorderSide),
          enabledBorder: _border(style.borderRadius, enabledBorderSide),
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
      );

      if (style.shadowColor == null || style.shadowBlurRadius <= 0) {
        return field;
      }

      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(style.borderRadius),
          boxShadow: [
            BoxShadow(
              color: style.shadowColor!,
              blurRadius: style.shadowBlurRadius,
              offset: style.shadowOffset,
            ),
          ],
        ),
        child: field,
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final maxDigitWidth = style.maxDigitWidth;
        if (maxDigitWidth != null && constraints.hasBoundedWidth) {
          final totalGaps = style.spacing * (controllers.length - 1);
          final rawWidth =
              ((constraints.maxWidth - totalGaps) / controllers.length).clamp(
            0.0,
            maxDigitWidth,
          );
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var index = 0; index < controllers.length; index++)
                SizedBox(
                  width: rawWidth.toDouble(),
                  child: fieldForIndex(index),
                ),
            ],
          );
        }

        return Row(
          children: [
            for (var index = 0; index < controllers.length; index++) ...[
              Expanded(child: fieldForIndex(index)),
              if (index < controllers.length - 1)
                SizedBox(width: style.spacing),
            ],
          ],
        );
      },
    );
  }
}

OutlineInputBorder _border(double radius, BorderSide side) {
  return OutlineInputBorder(
    borderRadius: BorderRadius.circular(radius),
    borderSide: side,
  );
}
