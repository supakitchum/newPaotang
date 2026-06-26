import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/mobile_bootstrap_controller.dart';
import 'flexible_image.dart';

class TenantBrandHeader extends ConsumerWidget {
  const TenantBrandHeader({
    super.key,
    this.icon = Icons.confirmation_number_outlined,
    this.showName = true,
    this.size = 72,
  });

  final IconData icon;
  final bool showName;
  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return bootstrap.maybeWhen(
      data: (data) {
        final logoUrl = data.brand.logoUrl.trim();
        final siteName = data.siteName.trim();

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: size,
              height: size,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(22),
              ),
              clipBehavior: Clip.antiAlias,
              child: logoUrl.isEmpty
                  ? Icon(icon, color: colorScheme.onPrimaryContainer)
                  : FlexibleImage(
                      source: logoUrl,
                      fit: BoxFit.contain,
                      errorIcon: icon,
                    ),
            ),
            if (showName && siteName.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                siteName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
              ),
            ],
          ],
        );
      },
      orElse: () => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: colorScheme.primaryContainer,
          borderRadius: BorderRadius.circular(22),
        ),
        child: Icon(icon, color: colorScheme.onPrimaryContainer),
      ),
    );
  }
}
