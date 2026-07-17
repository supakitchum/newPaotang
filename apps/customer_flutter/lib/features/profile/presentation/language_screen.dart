import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_locale_controller.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/i18n/customer_translation_repository.dart';
import '../../../shared/utils/customer_operational_error.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_loading_indicator.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../data/profile_settings_repository.dart';

class LanguageScreen extends ConsumerStatefulWidget {
  const LanguageScreen({super.key});

  @override
  ConsumerState<LanguageScreen> createState() => _LanguageScreenState();
}

class _LanguageScreenState extends ConsumerState<LanguageScreen> {
  bool _saving = false;
  String _errorMessage = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final activeTag = localeTag(ref.watch(customerLocaleProvider));
    final localeOptions = ref.watch(customerSupportedLocaleOptionsProvider);

    return AppShell(
      title: l10n.profileLanguageTitle,
      currentPath: '/profile/language',
      backPath: '/profile',
      sensitive: true,
      showBottomNavigation: true,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _LanguageContentSheet(
            child: CustomerPageBody(
              top: 23,
              bottom: 118,
              mobileHorizontal: 18,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(bottom: 14),
                    child: Text(
                      l10n.profileLanguageSubtitle,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            height: 1.45,
                          ),
                    ),
                  ),
                  for (var index = 0;
                      index < localeOptions.length;
                      index++) ...[
                    _LanguageOptionRow(
                      key: ValueKey(
                        'profile_language_${localeOptions[index].tag}',
                      ),
                      label: _languageLabel(l10n, localeOptions[index]),
                      selected: activeTag == localeOptions[index].tag,
                      saving: _saving,
                      onTap: () => _setLocale(
                        localeOptions[index].locale,
                      ),
                    ),
                    Divider(
                      height: 1,
                      color: Theme.of(context)
                          .colorScheme
                          .outlineVariant
                          .withValues(alpha: 0.78),
                    ),
                  ],
                  if (_errorMessage.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _LanguageErrorNotice(message: _errorMessage),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  String _languageLabel(
    CustomerLocalizations l10n,
    CustomerLocaleOption option,
  ) {
    final runtimeLabel = option.displayName;
    if (runtimeLabel != option.tag) return runtimeLabel;
    return switch (option.locale.languageCode) {
      'th' => l10n.commonThai,
      'en' => l10n.commonEnglish,
      _ => option.tag,
    };
  }

  Future<void> _setLocale(Locale locale) async {
    final tag = localeTag(locale);
    final previousLocale = ref.read(customerLocaleProvider);
    final wasOverridden = ref.read(customerLocaleOverriddenProvider);
    if (_saving || localeTag(previousLocale) == tag) return;

    setCustomerLocale(ref, locale);
    setState(() {
      _saving = true;
      _errorMessage = '';
    });
    try {
      await ref
          .read(profileSettingsRepositoryProvider)
          .savePreferredLocale(tag);
      ref.invalidate(customerProfileSettingsProvider);
    } catch (error) {
      ref.read(customerLocaleProvider.notifier).state = previousLocale;
      ref.read(customerLocaleOverriddenProvider.notifier).state = wasOverridden;
      if (!mounted) return;
      if (await handleCustomerOperationalError(
        ref: ref,
        context: context,
        error: error,
      )) {
        return;
      }
      if (!mounted) return;
      setState(() {
        _errorMessage = customerErrorMessage(
          error,
          context.l10n.profileLanguageSaveFailed,
        );
      });
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _LanguageContentSheet extends StatelessWidget {
  const _LanguageContentSheet({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 620),
        child: child,
      ),
    );
  }
}

class _LanguageOptionRow extends StatelessWidget {
  const _LanguageOptionRow({
    super.key,
    required this.label,
    required this.selected,
    required this.saving,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final bool saving;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final row = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 72),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurface,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.25,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            if (saving && selected)
              CustomerLoadingMark(
                width: 24,
                height: 18,
                color: colorScheme.primary,
                semanticLabel: context.l10n.commonLoadingData,
              )
            else if (selected)
              Icon(
                Icons.check_circle_rounded,
                size: 25,
                color: colorScheme.primary,
              ),
          ],
        ),
      ),
    );

    return Semantics(
      button: true,
      selected: selected,
      child: MouseRegion(
        cursor: saving ? MouseCursor.defer : SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: saving ? null : onTap,
          child: row,
        ),
      ),
    );
  }
}

class _LanguageErrorNotice extends StatelessWidget {
  const _LanguageErrorNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.errorContainer.withValues(alpha: 0.48),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: colorScheme.error.withValues(alpha: 0.22)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.error_outline_rounded, color: colorScheme.error),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.error,
                      fontSize: 13,
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
