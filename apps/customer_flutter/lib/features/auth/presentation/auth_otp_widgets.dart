import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AuthOtpCodeField extends StatelessWidget {
  const AuthOtpCodeField({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.label,
    required this.onSubmitted,
    required this.inputKey,
    required this.boxKeyPrefix,
    super.key,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final String label;
  final VoidCallback onSubmitted;
  final Key inputKey;
  final String boxKeyPrefix;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final digits = controller.text.characters.take(6).toList();

    return Semantics(
      label: label,
      textField: true,
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 364),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final gap = constraints.maxWidth < 320 ? 6.0 : 8.0;
              final available = constraints.maxWidth - (gap * 5);
              final boxSize = (available / 6).clamp(32.0, 54.0).toDouble();

              return SizedBox(
                height: boxSize,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: AutofillGroup(
                        onDisposeAction: AutofillContextAction.cancel,
                        child: TextField(
                          key: inputKey,
                          controller: controller,
                          focusNode: focusNode,
                          enabled: enabled,
                          autofocus: false,
                          autofillHints: const [AutofillHints.oneTimeCode],
                          keyboardType: const TextInputType.numberWithOptions(
                            signed: false,
                            decimal: false,
                          ),
                          textInputAction: TextInputAction.done,
                          textAlign: TextAlign.center,
                          showCursor: false,
                          enableInteractiveSelection: false,
                          autocorrect: false,
                          enableSuggestions: true,
                          style: const TextStyle(
                            color: Colors.transparent,
                            fontSize: 1,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.digitsOnly,
                            LengthLimitingTextInputFormatter(6),
                          ],
                          onSubmitted: (_) {
                            if (enabled) onSubmitted();
                          },
                          onTap: () {
                            controller.selection = TextSelection.collapsed(
                              offset: controller.text.length,
                            );
                          },
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            enabledBorder: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            disabledBorder: InputBorder.none,
                            contentPadding: EdgeInsets.zero,
                            counterText: '',
                          ),
                        ),
                      ),
                    ),
                    IgnorePointer(
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(6, (index) {
                          final hasDigit = index < digits.length;
                          final active =
                              focusNode.hasFocus &&
                              digits.length < 6 &&
                              index == digits.length;
                          return Padding(
                            key: ValueKey('$boxKeyPrefix-$index'),
                            padding: EdgeInsets.only(
                              right: index == 5 ? 0 : gap,
                            ),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 140),
                              width: boxSize,
                              height: boxSize,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: hasDigit
                                    ? colorScheme.primary.withValues(
                                        alpha: 0.07,
                                      )
                                    : colorScheme.surfaceContainerLowest,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: active || hasDigit
                                      ? colorScheme.primary
                                      : colorScheme.outlineVariant,
                                  width: active ? 2 : 1,
                                ),
                              ),
                              child: Text(
                                hasDigit ? digits[index] : '',
                                style: Theme.of(context).textTheme.titleLarge
                                    ?.copyWith(
                                      color: colorScheme.onSurface,
                                      fontSize: 22,
                                      fontWeight: FontWeight.w700,
                                      height: 1,
                                    ),
                              ),
                            ),
                          );
                        }),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class AuthOtpErrorPanel extends StatelessWidget {
  const AuthOtpErrorPanel({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.58),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
            color: colorScheme.onErrorContainer,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}
