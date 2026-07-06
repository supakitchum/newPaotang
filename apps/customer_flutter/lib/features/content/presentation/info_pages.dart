import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/navigation/customer_link_launcher.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/customer_page_body.dart';
import '../../../shared/widgets/tenant_brand_header.dart';

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
      compactHeader: true,
      child: _InfoPageShell(
        heroTitle: parsed.title,
        heroSubtitle: siteName,
        heroIcon: Icons.description_outlined,
        heroHeight: 330,
        sheetOverlap: 82,
        child: _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionPill(label: l10n.contentTermsSectionTitle),
              const SizedBox(height: 20),
              if (parsed.numbered.isNotEmpty)
                for (final term in parsed.numbered)
                  _NumberedText(number: term.number, text: term.text)
              else
                Text(parsed.plainText, style: _bodyStyle(context)),
              for (final paragraph in parsed.extraParagraphs) ...[
                const SizedBox(height: 18),
                Text(paragraph, style: _bodyStyle(context)),
              ],
            ],
          ),
        ),
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
      compactHeader: true,
      child: _InfoPageShell(
        heroTitle: parsed.title,
        heroSubtitle: l10n.contentPrivacyHeroSubtitle(siteName),
        heroIcon: Icons.privacy_tip_outlined,
        heroHeight: 330,
        sheetOverlap: 82,
        child: _InfoCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _SectionPill(label: l10n.contentPrivacySectionTitle),
              const SizedBox(height: 20),
              if (parsed.numbered.isNotEmpty)
                for (final term in parsed.numbered)
                  _NumberedText(number: term.number, text: term.text)
              else
                Text(parsed.plainText, style: _bodyStyle(context)),
              for (final paragraph in parsed.extraParagraphs) ...[
                const SizedBox(height: 18),
                Text(paragraph, style: _bodyStyle(context)),
              ],
              if (_noticeMessage.isNotEmpty) ...[
                const SizedBox(height: 18),
                _InfoInlineNotice(message: _noticeMessage),
              ],
              if (isSafeExternalLinkUri(policyUri)) ...[
                const SizedBox(height: 22),
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
            ],
          ),
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
      compactHeader: true,
      child: _InfoPageShell(
        heroTitle: l10n.contentRewardTermsTitle,
        heroSubtitle: '',
        heroIcon: Icons.emoji_events_outlined,
        heroHeight: 176,
        sheetOverlap: 26,
        showHeroContent: false,
        bottom: 96,
        child: _RewardTermsCard(l10n: l10n),
      ),
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
      compactHeader: true,
      child: _InfoPageShell(
        heroTitle: l10n.contentKnowledgeTitle,
        heroSubtitle: l10n.contentKnowledgeSubtitle,
        heroIcon: Icons.school_outlined,
        heroHeight: 340,
        sheetOverlap: 88,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final section in _knowledgeSections(l10n))
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
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
  const _InfoPageShell({
    required this.heroTitle,
    required this.heroSubtitle,
    required this.heroIcon,
    required this.heroHeight,
    required this.sheetOverlap,
    required this.child,
    this.showHeroContent = true,
    this.bottom = 128,
  });

  final String heroTitle;
  final String heroSubtitle;
  final IconData heroIcon;
  final double heroHeight;
  final double sheetOverlap;
  final Widget child;
  final bool showHeroContent;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return LayoutBuilder(
      builder: (context, constraints) {
        final narrow = constraints.maxWidth <= 390;
        final height =
            narrow && heroHeight >= 300 ? heroHeight - 14 : heroHeight;
        final overlap =
            narrow && sheetOverlap >= 70 ? sheetOverlap - 6 : sheetOverlap;

        return ColoredBox(
          color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.96) ??
              colorScheme.surface,
          child: ListView(
            padding: EdgeInsets.zero,
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  _InfoHeroBand(
                    height: height,
                    overlap: overlap,
                    title: heroTitle,
                    subtitle: heroSubtitle,
                    icon: heroIcon,
                    showContent: showHeroContent,
                  ),
                  Padding(
                    padding: EdgeInsets.only(top: height - overlap),
                    child: CustomerPageBody(
                      maxWidth: 640,
                      top: 0,
                      bottom: bottom,
                      mobileHorizontal: narrow ? 14 : 18,
                      wideHorizontal: 18,
                      child: child,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _InfoHeroBand extends StatelessWidget {
  const _InfoHeroBand({
    required this.height,
    required this.overlap,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.showContent,
  });

  final double height;
  final double overlap;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool showContent;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final narrow = MediaQuery.sizeOf(context).width <= 390;

    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              colorScheme.primary,
              Color.lerp(colorScheme.primary, colorScheme.secondary, 0.46) ??
                  colorScheme.primary,
            ],
          ),
        ),
        child: showContent
            ? CustomerPageBody(
                maxWidth: 640,
                top: 24,
                bottom: overlap + 24,
                mobileHorizontal: 18,
                wideHorizontal: 18,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TenantBrandHeader(
                      icon: icon,
                      showName: false,
                      size: narrow ? 62 : 72,
                    ),
                    if (subtitle.trim().isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Text(
                        subtitle.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: colorScheme.onPrimary.withValues(alpha: 0.9),
                          fontSize: 14,
                          fontWeight: FontWeight.w900,
                          height: 1.35,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    const SizedBox(height: 8),
                    Text(
                      title.trim(),
                      style:
                          Theme.of(context).textTheme.headlineSmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontSize: narrow ? 25 : 29,
                                fontWeight: FontWeight.w900,
                                height: 1.22,
                              ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              )
            : const SizedBox.expand(),
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
            color:
                Theme.of(context).colorScheme.primary.withValues(alpha: 0.11),
            blurRadius: 32,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Padding(
        padding: effectivePadding,
        child: child,
      ),
    );
  }
}

class _RewardTermsCard extends StatelessWidget {
  const _RewardTermsCard({required this.l10n});

  final CustomerLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return _InfoCard(
      padding: const EdgeInsets.fromLTRB(18, 22, 18, 18),
      child: Column(
        children: [
          const _RewardOfficeMark(),
          const SizedBox(height: 20),
          Text(
            l10n.contentRewardTermsHeroTitle,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: colorScheme.onSurface,
                  fontWeight: FontWeight.w900,
                  height: 1.24,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          Text(
            l10n.contentRewardTermsHeroSubtitle,
            style: _bodyStyle(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontWeight: FontWeight.w800,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          const _RewardHeaderRow(),
          const Divider(height: 18),
          for (final row in _rewardRows(l10n))
            _RewardRow(
              title: row.title,
              count: row.count,
              amount: row.amount,
            ),
        ],
      ),
    );
  }
}

class _RewardOfficeMark extends StatelessWidget {
  const _RewardOfficeMark();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: colorScheme.primary, width: 1.4),
            borderRadius: BorderRadius.circular(8),
            color: colorScheme.surface,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text(
              l10n.contentRewardTermsOfficeAbbr,
              style: TextStyle(
                color: colorScheme.primary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                height: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            l10n.contentRewardTermsOfficeName,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: colorScheme.onSurfaceVariant,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.25,
            ),
          ),
        ),
      ],
    );
  }
}

class _KnowledgeFooter extends StatelessWidget {
  const _KnowledgeFooter();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 4),
      child: Column(
        children: [
          Text(
            l10n.contentKnowledgeMoreInfo,
            style: _bodyStyle(context).copyWith(
              color: colorScheme.onSurfaceVariant,
              fontSize: MediaQuery.sizeOf(context).width <= 390 ? 18 : 20,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            l10n.contentKnowledgeContact,
            style: TextStyle(
              color: Theme.of(context).colorScheme.primary,
              fontSize: MediaQuery.sizeOf(context).width <= 390 ? 18 : 20,
              fontWeight: FontWeight.w900,
              height: 1.45,
            ),
            textAlign: TextAlign.center,
          ),
        ],
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
        color: Color.lerp(colorScheme.error, colorScheme.surface, 0.88) ??
            colorScheme.errorContainer.withValues(alpha: 0.52),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: Color.lerp(colorScheme.error, colorScheme.surface, 0.68) ??
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

class _SectionPill extends StatelessWidget {
  const _SectionPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Color.lerp(colorScheme.primary, colorScheme.surface, 0.9),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: colorScheme.primary,
            fontSize: 14,
            fontWeight: FontWeight.w900,
            height: 1,
          ),
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
    final fontSize = large ? (narrow ? 19.0 : 22.0) : (narrow ? 16.0 : 18.0);
    final rowGap = large ? (narrow ? 14.0 : 18.0) : (narrow ? 14.0 : 16.0);
    final gridWidth = large ? (narrow ? 38.0 : 42.0) : (narrow ? 38.0 : 40.0);
    final bottom = large ? (narrow ? 24.0 : 28.0) : (narrow ? 18.0 : 20.0);

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: gridWidth,
            child: Container(
              width: 34,
              height: 34,
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
                  fontSize: large ? 18 : 17,
                  fontWeight: FontWeight.w900,
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
                fontWeight: FontWeight.w800,
                height: large ? 1.55 : 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RewardHeaderRow extends StatelessWidget {
  const _RewardHeaderRow();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final style = TextStyle(
      color: Theme.of(context).colorScheme.primary,
      fontSize: 13,
      fontWeight: FontWeight.w900,
      height: 1.25,
    );

    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(l10n.contentRewardHeaderPrizeType, style: style),
        ),
        Expanded(
          flex: 3,
          child: Text(
            l10n.contentRewardHeaderCount,
            textAlign: TextAlign.center,
            style: style,
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            l10n.contentRewardHeaderAmount,
            textAlign: TextAlign.right,
            style: style,
          ),
        ),
      ],
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({
    required this.title,
    required this.count,
    required this.amount,
  });

  final String title;
  final String count;
  final String amount;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(
              title,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w800,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              count,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colorScheme.onSurfaceVariant,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: TextStyle(
                color: colorScheme.onSurface,
                fontSize: 14,
                fontWeight: FontWeight.w900,
                height: 1.35,
              ),
            ),
          ),
        ],
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
        horizontal: narrow ? 22 : 26,
        vertical: narrow ? 24 : 28,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            section.title,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: narrow ? 21 : 24,
                  fontWeight: FontWeight.w900,
                  height: 1.3,
                ),
          ),
          const SizedBox(height: 24),
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
