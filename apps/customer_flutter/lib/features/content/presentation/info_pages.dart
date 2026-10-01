import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';

class TermsScreen extends ConsumerWidget {
  const TermsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final l10n = context.l10n;
    final siteName = bootstrap.maybeWhen(
      data: (data) => data.siteName,
      orElse: () => l10n.contentTermsSiteFallback,
    );
    final content = bootstrap.maybeWhen(
      data: (data) => data.termsContent.trim().isNotEmpty
          ? data.termsContent
          : l10n.contentTermsDefaultContent(data.siteName),
      orElse: () => l10n.contentTermsDefaultContent(siteName),
    );
    final parsed = _ParsedTerms.fromContent(
      content,
      fallbackTitle: l10n.contentTermsSectionTitle,
    );

    return AppShell(
      title: l10n.contentTermsTitle,
      currentPath: '/profile',
      backPath: '/profile',
      showBottomNavigation: false,
      compactHeader: true,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: _InfoPageShell(
        readingSurface: true,
        child: _LegalReadingContent(parsed: parsed),
      ),
    );
  }
}

class PrivacyPolicyScreen extends ConsumerStatefulWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  ConsumerState<PrivacyPolicyScreen> createState() =>
      _PrivacyPolicyScreenState();
}

class _PrivacyPolicyScreenState extends ConsumerState<PrivacyPolicyScreen> {
  String _noticeMessage = '';

  @override
  Widget build(BuildContext context) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final l10n = context.l10n;
    final siteName = bootstrap.maybeWhen(
      data: (data) => data.siteName,
      orElse: () => l10n.contentTermsSiteFallback,
    );
    final content = bootstrap.maybeWhen(
      data: (data) => data.privacyContent.trim().isNotEmpty
          ? data.privacyContent
          : l10n.contentPrivacyDefaultContent(data.siteName),
      orElse: () => l10n.contentPrivacyDefaultContent(siteName),
    );
    final policyUri = bootstrap.maybeWhen(
      data: (data) => Uri.tryParse(data.privacyPolicyUrl),
      orElse: () => null,
    );
    final parsed = _ParsedTerms.fromContent(
      content,
      fallbackTitle: l10n.contentPrivacyTitle,
    );

    return AppShell(
      title: l10n.contentPrivacyTitle,
      currentPath: '/profile',
      backPath: '/profile',
      showBottomNavigation: false,
      compactHeader: true,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: _InfoPageShell(
        readingSurface: true,
        child: _LegalReadingContent(
          parsed: parsed,
          footer: [
            if (_noticeMessage.isNotEmpty)
              _InfoInlineNotice(message: _noticeMessage),
            if (isSafeExternalLinkUri(policyUri))
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () async {
                    setState(() => _noticeMessage = '');
                    final opened = await ref
                        .read(customerLinkLauncherProvider)
                        .openExternal(policyUri!);
                    if (!opened && context.mounted) {
                      setState(() {
                        _noticeMessage = l10n.contentPrivacyOpenFailed;
                      });
                    }
                  },
                  icon: const Icon(Icons.open_in_new),
                  label: Text(l10n.contentPrivacyOpenPolicy),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class TermRewardScreen extends StatelessWidget {
  const TermRewardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.contentRewardTermsTitle,
      currentPath: '/',
      backPath: '/',
      showBottomNavigation: false,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: _RewardTermsSheet(l10n: l10n),
    );
  }
}

class LotteryKnowledgeScreen extends StatelessWidget {
  const LotteryKnowledgeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.contentKnowledgeTitle,
      currentPath: '/profile',
      backPath: '/profile',
      showBottomNavigation: false,
      compactHeader: true,
      heroMinHeight: customerReferenceCompactHeroHeight,
      heroSheetOverlap: 0,
      heroContentTopGap: 0,
      heroContent: const SizedBox.shrink(),
      child: _InfoPageShell(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in _knowledgeSections(l10n))
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _KnowledgeCard(section: section),
              ),
            const SizedBox(height: 2),
            const _KnowledgeFooter(),
          ],
        ),
      ),
    );
  }
}

class _InfoPageShell extends StatelessWidget {
  const _InfoPageShell({required this.child, this.readingSurface = false});

  final Widget child;
  final bool readingSurface;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth <= 390;

        return ColoredBox(
          color: readingSurface
              ? colorScheme.surface
              : Color.lerp(colorScheme.primary, colorScheme.surface, 0.96) ??
                  colorScheme.surface,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              CustomerPageBody(
                maxWidth: 640,
                top: readingSurface ? 22 : 0,
                bottom: 42,
                mobileHorizontal: readingSurface ? 20 : (narrow ? 14 : 18),
                wideHorizontal: readingSurface ? 24 : 18,
                minViewportHeight: true,
                child: child,
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LegalReadingContent extends StatelessWidget {
  const _LegalReadingContent({required this.parsed, this.footer = const []});

  final _ParsedTerms parsed;
  final List<Widget> footer;

  @override
  Widget build(BuildContext context) {
    final paragraphs = parsed.extraParagraphs
        .where((paragraph) => paragraph.trim().isNotEmpty)
        .toList(growable: false);

    return Column(
      key: const ValueKey('legal-reading-surface'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (parsed.numbered.isNotEmpty)
          for (final term in parsed.numbered)
            _LegalNumberedItem(number: term.number, text: term.text)
        else if (paragraphs.isNotEmpty)
          for (final paragraph in paragraphs)
            _LegalParagraph(text: paragraph)
        else if (parsed.plainText.trim().isNotEmpty)
          _LegalParagraph(text: parsed.plainText.trim()),
        if (parsed.numbered.isNotEmpty)
          for (final paragraph in paragraphs)
            _LegalParagraph(text: paragraph),
        if (footer.isNotEmpty) ...[
          const SizedBox(height: 10),
          for (var index = 0; index < footer.length; index++) ...[
            if (index > 0) const SizedBox(height: 14),
            footer[index],
          ],
        ],
      ],
    );
  }
}

class _LegalNumberedItem extends StatelessWidget {
  const _LegalNumberedItem({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width <= 390;
    final numberFill =
        Color.lerp(colorScheme.primary, colorScheme.surface, 0.9) ??
        colorScheme.primaryContainer;

    return Padding(
      padding: const EdgeInsets.only(bottom: 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 30,
            height: 30,
            alignment: Alignment.center,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: numberFill,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              number,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 14,
                fontWeight: FontWeight.w700,
                height: 1,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurface,
                fontSize: narrow ? 15.5 : 16.5,
                fontWeight: FontWeight.w500,
                height: 1.62,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LegalParagraph extends StatelessWidget {
  const _LegalParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 390;
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Text(
        text,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
          color: Theme.of(context).colorScheme.onSurface,
          fontSize: narrow ? 15.5 : 16.5,
          fontWeight: FontWeight.w400,
          height: 1.68,
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 24, vertical: 26),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 390;
    final effectivePadding = narrow
        ? const EdgeInsets.symmetric(horizontal: 22, vertical: 24)
        : padding;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Theme.of(
              context,
            ).colorScheme.primary.withValues(alpha: 0.11),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(padding: effectivePadding, child: child),
    );
  }
}

class _RewardTermsSheet extends StatelessWidget {
  const _RewardTermsSheet({required this.l10n});

  final CustomerLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final primary = colorScheme.primary;
    final rewardInk =
        Color.lerp(colorScheme.onSurface, primary, 0.2) ??
        colorScheme.onSurface;
    final gradientStart =
        Color.lerp(colorScheme.secondary, colorScheme.surface, 0.62) ??
        colorScheme.secondaryContainer;
    final gradientMiddle =
        Color.lerp(colorScheme.secondary, colorScheme.surface, 0.82) ??
        colorScheme.secondaryContainer;

    return LayoutBuilder(
      builder: (context, constraints) {
        final minimumHeight = constraints.maxHeight > 744
            ? constraints.maxHeight
            : 744.0;
        final bottomSafeArea = MediaQuery.paddingOf(context).bottom;

        return ListView(
          padding: EdgeInsets.zero,
          children: [
            ConstrainedBox(
              constraints: BoxConstraints(minHeight: minimumHeight),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0, 0.46, 1],
                    colors: [
                      gradientStart.withValues(alpha: 0.88),
                      gradientMiddle.withValues(alpha: 0.96),
                      colorScheme.surface,
                    ],
                  ),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(13),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsets.fromLTRB(28, 29, 28, 24 + bottomSafeArea),
                  child: Center(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 640),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const _RewardOfficeMark(),
                          const SizedBox(height: 23),
                          Text(
                            l10n.contentRewardTermsHeroTitle,
                            style: TextStyle(
                              color: rewardInk,
                              fontSize: 25,
                              fontWeight: FontWeight.w800,
                              height: 1.24,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            l10n.contentRewardTermsHeroSubtitle,
                            style: TextStyle(
                              color: rewardInk,
                              fontSize: 18,
                              fontWeight: FontWeight.w500,
                              height: 1.55,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          _RewardTable(l10n: l10n),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _RewardOfficeMark extends StatelessWidget {
  const _RewardOfficeMark();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final officeBlue =
        Color.lerp(
          AppTheme.heroGradientEnd(colorScheme.primary),
          colorScheme.secondary,
          0.32,
        ) ??
        colorScheme.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              l10n.contentRewardTermsOfficeAbbr,
              style: TextStyle(
                color: officeBlue,
                fontSize: 37,
                fontWeight: FontWeight.w700,
                height: 0.9,
              ),
            ),
            Transform.translate(
              offset: const Offset(-4, 0),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: colorScheme.tertiary,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          l10n.contentRewardTermsOfficeName,
          style: TextStyle(
            color: officeBlue,
            fontSize: 5,
            fontWeight: FontWeight.w500,
            height: 1.15,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class _KnowledgeFooter extends ConsumerStatefulWidget {
  const _KnowledgeFooter();

  @override
  ConsumerState<_KnowledgeFooter> createState() => _KnowledgeFooterState();
}

class _KnowledgeFooterState extends ConsumerState<_KnowledgeFooter> {
  String _noticeMessage = '';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;
    final fontSize = MediaQuery.sizeOf(context).width <= 390 ? 15.0 : 16.0;
    final bootstrap = ref.watch(mobileBootstrapProvider).valueOrNull;
    final websiteUri = customerHttpsUri(bootstrap?.supportUrl ?? '');
    final phoneUri = customerPhoneUri(bootstrap?.supportPhone ?? '');
    final phoneLabel = bootstrap?.supportPhone.trim() ?? '';

    if (websiteUri == null && phoneUri == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        children: [
          Text(
            l10n.contentKnowledgeMoreInfo,
            style: _bodyStyle(
              context,
            ).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          if (websiteUri != null) ...[
            const SizedBox(height: 4),
            _KnowledgeFooterLink(
              label: customerExternalLinkLabel(websiteUri),
              fontSize: fontSize,
              onTap: () => _openContact(websiteUri),
            ),
          ],
          if (phoneUri != null && phoneLabel.isNotEmpty)
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  websiteUri == null
                      ? l10n.contentKnowledgePhoneOnlyLead
                      : l10n.contentKnowledgePhoneLead,
                  style: _bodyStyle(context).copyWith(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: fontSize,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 4),
                _KnowledgeFooterLink(
                  label: phoneLabel,
                  fontSize: fontSize,
                  onTap: () => _openContact(phoneUri),
                ),
              ],
            ),
          if (_noticeMessage.isNotEmpty) ...[
            const SizedBox(height: 12),
            _InfoInlineNotice(message: _noticeMessage),
          ],
        ],
      ),
    );
  }

  Future<void> _openContact(Uri uri) async {
    if (_noticeMessage.isNotEmpty) {
      setState(() => _noticeMessage = '');
    }
    final opened = await ref
        .read(customerLinkLauncherProvider)
        .openExternal(uri);
    if (!opened && mounted) {
      setState(() => _noticeMessage = context.l10n.contentKnowledgeOpenFailed);
    }
  }
}

class _KnowledgeFooterLink extends StatelessWidget {
  const _KnowledgeFooterLink({
    required this.label,
    required this.fontSize,
    required this.onTap,
  });

  final String label;
  final double fontSize;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      link: true,
      button: true,
      label: label,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Text(
            label,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: fontSize,
              fontWeight: FontWeight.w700,
              height: 1.45,
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoInlineNotice extends StatelessWidget {
  const _InfoInlineNotice({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color:
            Color.lerp(colorScheme.error, colorScheme.surface, 0.88) ??
            colorScheme.errorContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              Color.lerp(colorScheme.error, colorScheme.surface, 0.68) ??
              colorScheme.error.withValues(alpha: 0.32),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: colorScheme.error,
              size: 20,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: colorScheme.error,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
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

class _NumberedText extends StatelessWidget {
  const _NumberedText({
    required this.number,
    required this.text,
    this.large = false,
  });

  final String number;
  final String text;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 390;
    final colorScheme = Theme.of(context).colorScheme;
    final fontSize = large ? (narrow ? 15.5 : 16.5) : (narrow ? 16.0 : 18.0);
    final rowGap = large ? 10.0 : (narrow ? 14.0 : 16.0);
    final gridWidth = large ? 32.0 : (narrow ? 38.0 : 40.0);
    final bottom = large ? 16.0 : (narrow ? 18.0 : 20.0);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: gridWidth,
            child: Container(
              width: large ? 28 : 34,
              height: large ? 28 : 34,
              alignment: Alignment.center,
              margin: EdgeInsets.only(top: large ? 3 : 2),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                shape: BoxShape.circle,
              ),
              child: Text(
                number,
                style: TextStyle(
                  color: colorScheme.onPrimary,
                  fontSize: large ? 14 : 17,
                  fontWeight: large ? FontWeight.w700 : FontWeight.w900,
                  height: 1,
                ),
              ),
            ),
          ),
          SizedBox(width: rowGap),
          Expanded(
            child: Text(
              text,
              style: _bodyStyle(context).copyWith(
                fontSize: fontSize,
                fontWeight: large ? FontWeight.w500 : FontWeight.w800,
                height: large ? 1.58 : 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardTable extends StatelessWidget {
  const _RewardTable({required this.l10n});

  final CustomerLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final rows = _rewardRows(l10n);
    final headerColor = AppTheme.heroGradientEnd(colorScheme.primary);
    final stripeColor =
        Color.lerp(colorScheme.primary, colorScheme.surface, 0.91) ??
        colorScheme.primaryContainer;

    return ClipRRect(
      borderRadius: BorderRadius.circular(11),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colorScheme.surface,
          border: Border.all(color: colorScheme.primary),
          borderRadius: BorderRadius.circular(11),
        ),
        child: Column(
          children: [
            _RewardTableRow(
              title: l10n.contentRewardHeaderPrizeType,
              count: l10n.contentRewardHeaderCount,
              amount: l10n.contentRewardHeaderAmount,
              background: headerColor,
              foreground: colorScheme.onPrimary,
              header: true,
            ),
            for (var index = 0; index < rows.length; index++)
              _RewardTableRow(
                title: rows[index].title,
                count: rows[index].count,
                amount: rows[index].amount,
                background: index.isOdd ? stripeColor : colorScheme.surface,
                foreground:
                    Color.lerp(
                      colorScheme.onSurface,
                      colorScheme.primary,
                      0.2,
                    ) ??
                    colorScheme.onSurface,
              ),
          ],
        ),
      ),
    );
  }
}

class _RewardTableRow extends StatelessWidget {
  const _RewardTableRow({
    required this.title,
    required this.count,
    required this.amount,
    required this.background,
    required this.foreground,
    this.header = false,
  });

  final String title;
  final String count;
  final String amount;
  final Color background;
  final Color foreground;
  final bool header;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: background,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 105,
              child: _RewardTableCell(
                title,
                foreground: foreground,
                header: header,
                bold: true,
              ),
            ),
            Expanded(
              flex: 98,
              child: _RewardTableCell(
                count,
                textAlign: TextAlign.center,
                foreground: foreground,
                header: header,
              ),
            ),
            Expanded(
              flex: 118,
              child: _RewardTableCell(
                amount,
                textAlign: TextAlign.right,
                foreground: foreground,
                header: header,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardTableCell extends StatelessWidget {
  const _RewardTableCell(
    this.text, {
    required this.foreground,
    required this.header,
    this.bold = false,
    this.textAlign = TextAlign.left,
  });

  final String text;
  final Color foreground;
  final bool header;
  final bool bold;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: header ? 50 : 58),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Align(
          alignment: textAlign == TextAlign.right
              ? Alignment.centerRight
              : textAlign == TextAlign.center
              ? Alignment.center
              : Alignment.centerLeft,
          child: Text(
            text,
            style: TextStyle(
              color: foreground,
              fontSize: 15,
              fontWeight: header || bold ? FontWeight.w800 : FontWeight.w500,
              height: 1.45,
            ),
            textAlign: textAlign,
          ),
        ),
      ),
    );
  }
}

class _KnowledgeCard extends StatelessWidget {
  const _KnowledgeCard({required this.section});

  final _KnowledgeSection section;

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width <= 390;

    return _InfoCard(
      padding: EdgeInsets.symmetric(
        horizontal: narrow ? 18 : 22,
        vertical: narrow ? 20 : 22,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
              fontSize: narrow ? 18 : 20,
              fontWeight: FontWeight.w800,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),
          for (var index = 0; index < section.items.length; index++)
            _NumberedText(
              number: '${index + 1}',
              text: section.items[index],
              large: true,
            ),
        ],
      ),
    );
  }
}

class _ParsedTerms {
  const _ParsedTerms({
    required this.title,
    required this.numbered,
    required this.extraParagraphs,
    required this.plainText,
  });

  factory _ParsedTerms.fromContent(
    String content, {
    required String fallbackTitle,
  }) {
    final lines = _normalizeInfoContentText(content)
        .split(RegExp(r'\r?\n'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList(growable: false);
    final title = lines.isEmpty || _isNumberedLine(lines.first)
        ? fallbackTitle
        : lines.first;
    final numbered = lines
        .map((line) {
          final match = RegExp(r'^(\d+)\.\s*(.+)$').firstMatch(line);
          return match == null
              ? null
              : _NumberedTerm(match.group(1) ?? '', match.group(2) ?? '');
        })
        .whereType<_NumberedTerm>()
        .toList(growable: false);
    final extra = lines
        .asMap()
        .entries
        .where((entry) => !(entry.key == 0 && entry.value == title))
        .map((entry) => entry.value)
        .where((line) => !_isNumberedLine(line))
        .toList(growable: false);
    final plain = lines
        .asMap()
        .entries
        .where((entry) => !(entry.key == 0 && entry.value == title))
        .map((entry) => entry.value)
        .where((line) => !_isNumberedLine(line))
        .join('\n');

    return _ParsedTerms(
      title: title,
      numbered: numbered,
      extraParagraphs: extra,
      plainText: plain,
    );
  }

  final String title;
  final List<_NumberedTerm> numbered;
  final List<String> extraParagraphs;
  final String plainText;
}

String _normalizeInfoContentText(String value) {
  final decoded = _decodeInfoHtmlEntities(value.trim());
  if (decoded.isEmpty) return '';

  final withBreaks = decoded
      .replaceAll(RegExp(r'<\s*br\s*/?\s*>', caseSensitive: false), '\n')
      .replaceAll(
        RegExp(
          r'</\s*(p|div|li|h[1-6]|section|article|ul|ol)\s*>',
          caseSensitive: false,
        ),
        '\n',
      )
      .replaceAll(
        RegExp(
          r'<\s*(p|div|li|h[1-6]|section|article|ul|ol)(\s[^>]*)?>',
          caseSensitive: false,
        ),
        '',
      );

  return _decodeInfoHtmlEntities(withBreaks.replaceAll(RegExp(r'<[^>]+>'), ''))
      .split(RegExp(r'\r?\n'))
      .map(_normalizeInfoMarkdownLine)
      .where((line) => line.isNotEmpty)
      .join('\n');
}

String _normalizeInfoMarkdownLine(String line) {
  var normalized = line.trim();
  if (normalized.isEmpty) return '';
  if (RegExp(r'^(-{3,}|\*{3,}|_{3,})$').hasMatch(normalized)) return '';

  normalized = normalized.replaceFirst(RegExp(r'^>\s?'), '');
  normalized = normalized.replaceFirst(RegExp(r'^#{1,6}\s+'), '');
  normalized = normalized.replaceFirst(RegExp(r'^\s*[-*+]\s+'), '');
  normalized = normalized.replaceFirst(RegExp(r'^\[[ xX]\]\s+'), '');
  normalized = normalized.replaceFirstMapped(
    RegExp(r'^(\d+)[.)]\s+'),
    (match) => '${match.group(1)}. ',
  );

  return _stripInfoInlineMarkdown(normalized).trim();
}

String _stripInfoInlineMarkdown(String value) {
  var normalized = value;
  normalized = normalized.replaceAllMapped(
    RegExp(r'!\[([^\]]*)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]+\)'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\*\*([^*]+)\*\*'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'__([^_]+)__'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'~~([^~]+)~~'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'`([^`]+)`'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'\*([^*]+)\*'),
    (match) => match.group(1) ?? '',
  );
  normalized = normalized.replaceAllMapped(
    RegExp(r'_([^_]+)_'),
    (match) => match.group(1) ?? '',
  );
  return normalized;
}

String _decodeInfoHtmlEntities(String value) {
  var decoded = value;
  for (var index = 0; index < 2; index++) {
    final next = decoded
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#34;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>');
    if (next == decoded) break;
    decoded = next;
  }
  return decoded;
}

class _NumberedTerm {
  const _NumberedTerm(this.number, this.text);

  final String number;
  final String text;
}

class _KnowledgeSection {
  const _KnowledgeSection({required this.title, required this.items});

  final String title;
  final List<String> items;
}

class _RewardDefinition {
  const _RewardDefinition({
    required this.title,
    required this.count,
    required this.amount,
  });

  final String title;
  final String count;
  final String amount;
}

TextStyle _bodyStyle(BuildContext context) {
  final colorScheme = Theme.of(context).colorScheme;
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.6,
      ) ??
      TextStyle(
        color: colorScheme.onSurface,
        fontWeight: FontWeight.w800,
        height: 1.6,
      );
}

bool _isNumberedLine(String line) => RegExp(r'^\d+\.\s*').hasMatch(line);

List<_RewardDefinition> _rewardRows(CustomerLocalizations l10n) => [
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('first'),
    count: l10n.contentRewardRowCount('first'),
    amount: l10n.contentRewardRowAmount('first'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('second'),
    count: l10n.contentRewardRowCount('second'),
    amount: l10n.contentRewardRowAmount('second'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('third'),
    count: l10n.contentRewardRowCount('third'),
    amount: l10n.contentRewardRowAmount('third'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('fourth'),
    count: l10n.contentRewardRowCount('fourth'),
    amount: l10n.contentRewardRowAmount('fourth'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('fifth'),
    count: l10n.contentRewardRowCount('fifth'),
    amount: l10n.contentRewardRowAmount('fifth'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('adjacent_first'),
    count: l10n.contentRewardRowCount('adjacent_first'),
    amount: l10n.contentRewardRowAmount('adjacent_first'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('front3'),
    count: l10n.contentRewardRowCount('front3'),
    amount: l10n.contentRewardRowAmount('front3'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('last3'),
    count: l10n.contentRewardRowCount('last3'),
    amount: l10n.contentRewardRowAmount('last3'),
  ),
  _RewardDefinition(
    title: l10n.contentRewardRowTitle('last2'),
    count: l10n.contentRewardRowCount('last2'),
    amount: l10n.contentRewardRowAmount('last2'),
  ),
];

List<_KnowledgeSection> _knowledgeSections(CustomerLocalizations l10n) => [
  _KnowledgeSection(
    title: l10n.contentKnowledgeSectionTitle('digital_lottery'),
    items: [
      l10n.contentKnowledgeSectionItem('digital_lottery', 1),
      l10n.contentKnowledgeSectionItem('digital_lottery', 2),
      l10n.contentKnowledgeSectionItem('digital_lottery', 3),
    ],
  ),
  _KnowledgeSection(
    title: l10n.contentKnowledgeSectionTitle('sellers'),
    items: [
      l10n.contentKnowledgeSectionItem('sellers', 1),
      l10n.contentKnowledgeSectionItem('sellers', 2),
      l10n.contentKnowledgeSectionItem('sellers', 3),
    ],
  ),
];
