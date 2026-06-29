import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';

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
      loading: () => Card(
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              const SizedBox.square(
                dimension: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  loadingText ?? l10n.commonLoadingData,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
            ],
          ),
        ),
      ),
      error: (error, _) =>
          empty ??
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Row(
                children: [
                  const Icon(Icons.error_outline),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      errorText ?? l10n.commonLoadFailed,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
    );
  }
}
