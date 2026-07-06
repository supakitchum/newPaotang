import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../customer_loading_indicator.dart';

class AsyncStateView<T> extends StatelessWidget {
  const AsyncStateView({
    required this.value,
    required this.data,
    super.key,
    this.loadingText,
    this.errorText,
    this.empty,
  });

  final AsyncValue<T> value;
  final Widget Function(T data) data;
  final String? loadingText;
  final String? errorText;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return value.when(
      data: data,
      loading: () => _AsyncStatePanel(
        icon: CustomerLoadingMark(
          width: 28,
          height: 20,
          semanticLabel: loadingText ?? l10n.commonLoadingData,
        ),
        message: loadingText ?? l10n.commonLoadingData,
      ),
      error: (error, _) =>
          empty ??
          _AsyncStatePanel(
            icon: Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            message: errorText ?? l10n.commonLoadFailed,
            error: true,
          ),
    );
  }
}

class _AsyncStatePanel extends StatelessWidget {
  const _AsyncStatePanel({
    required this.icon,
    required this.message,
    this.error = false,
  });

  final Widget icon;
  final String message;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textColor = error ? colorScheme.error : colorScheme.onSurfaceVariant;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.primary.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            icon,
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                      height: 1.4,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
