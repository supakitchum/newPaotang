import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/tenant/mobile_bootstrap_controller.dart';
import '../../core/utils/asset_url.dart';
import 'flexible_image.dart';

class TenantBrandHeader extends ConsumerWidget {
  const TenantBrandHeader({
    super.key,
    this.icon = Icons.confirmation_number_outlined,
    this.showName = true,
    this.size = 72,
    this.maxWidth = 280,
    this.textColor,
  });

  final IconData icon;
  final bool showName;
  final double size;
  final double maxWidth;
  final Color? textColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return bootstrap.maybeWhen(
      data: (data) {
        final rawLogoUrl = data.brand.logoUrl.trim();
        final logoUrl =
            rawLogoUrl.isEmpty ? '' : _resolveTenantLogoUrl(ref, rawLogoUrl);
        final siteName = data.siteName.trim();
        final headerMaxWidth = maxWidth < size ? size : maxWidth;

        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: headerMaxWidth),
          child: Column(
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
                        height: 1.15,
                        color: textColor,
                      ),
                ),
              ],
            ],
          ),
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

/// Flutter counterpart of Nuxt's `BrandLogo` lockup.
class TenantBrandLogo extends ConsumerWidget {
  const TenantBrandLogo({
    super.key,
    this.color,
    this.alignment = CrossAxisAlignment.start,
  });

  final Color? color;
  final CrossAxisAlignment alignment;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final rawLogoUrl = bootstrap?.brand.logoUrl.trim() ?? '';
    final logoUrl =
        rawLogoUrl.isEmpty ? '' : _resolveTenantLogoUrl(ref, rawLogoUrl);
    final siteName = bootstrap?.siteName.trim() ?? '';
    final productLabel = bootstrap?.lotteryProductLabel.trim() ?? '';
    final supportLabel = bootstrap?.supportPhone.trim() ?? '';
    final foreground = color ?? Theme.of(context).colorScheme.onPrimary;
    final fallbackLabel = siteName.isNotEmpty ? siteName : productLabel;
    final secondaryLines = <String>[
      if (logoUrl.isNotEmpty && siteName.isNotEmpty) siteName,
      if (supportLabel.isNotEmpty) supportLabel,
    ];

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 96),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: alignment,
        children: [
          if (logoUrl.isNotEmpty)
            SizedBox(
              width: 96,
              height: 34,
              child: FlexibleImage(
                source: logoUrl,
                fit: BoxFit.contain,
                errorIcon: Icons.confirmation_number_outlined,
              ),
            ),
          if (logoUrl.isEmpty && fallbackLabel.isNotEmpty)
            Text(
              fallbackLabel,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: foreground,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    height: 1.02,
                    letterSpacing: 0,
                  ),
            )
          else if (logoUrl.isEmpty)
            Icon(
              Icons.confirmation_number_outlined,
              color: foreground,
              size: 30,
            ),
          if (secondaryLines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Text(
                secondaryLines.join('\n'),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: foreground.withValues(alpha: 0.9),
                      fontSize: 5,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                      letterSpacing: 0,
                    ),
              ),
            ),
        ],
      ),
    );
  }
}

String _resolveTenantLogoUrl(WidgetRef ref, String value) {
  final trimmed = value.trim();
  final uri = Uri.tryParse(trimmed);
  if (uri != null &&
      (uri.hasScheme ||
          trimmed.startsWith('data:') ||
          trimmed.startsWith('//'))) {
    return trimmed;
  }
  return ref.watch(assetUrlResolverProvider)(trimmed);
}
