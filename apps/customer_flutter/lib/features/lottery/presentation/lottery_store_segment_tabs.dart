import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';

class LotteryStoreSegmentTabs extends StatelessWidget {
  const LotteryStoreSegmentTabs({
    required this.activePath,
    super.key,
  });

  final String activePath;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final selected = activePath == '/stores' ? '/stores' : '/buy';
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [
          ButtonSegment<String>(
            value: '/buy',
            icon: const Icon(Icons.confirmation_number_outlined),
            label: Text(l10n.lotteryAllTab),
          ),
          ButtonSegment<String>(
            value: '/stores',
            icon: const Icon(Icons.storefront_outlined),
            label: Text(l10n.lotteryStoresTab),
          ),
        ],
        selected: {selected},
        onSelectionChanged: (selection) {
          final target = selection.isEmpty ? selected : selection.first;
          if (target != selected) context.go(target);
        },
      ),
    );
  }
}
