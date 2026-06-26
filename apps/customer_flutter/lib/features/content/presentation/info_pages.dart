import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../shared/widgets/app_shell.dart';

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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            icon: Icons.description_outlined,
            title: parsed.title,
            subtitle: siteName,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionPill(label: l10n.contentTermsSectionTitle),
                  const SizedBox(height: 18),
                  if (parsed.numbered.isNotEmpty)
                    for (final term in parsed.numbered)
                      _NumberedText(number: term.number, text: term.text)
                  else
                    Text(parsed.plainText, style: _bodyStyle(context)),
                  for (final paragraph in parsed.extraParagraphs) ...[
                    const SizedBox(height: 16),
                    Text(paragraph, style: _bodyStyle(context)),
                  ],
                ],
              ),
            ),
          ),
        ],
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            icon: Icons.emoji_events_outlined,
            title: l10n.contentRewardTermsHeroTitle,
            subtitle: l10n.contentRewardTermsHeroSubtitle,
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                children: [
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
            ),
          ),
        ],
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
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _HeroCard(
            icon: Icons.school_outlined,
            title: l10n.contentKnowledgeTitle,
            subtitle: l10n.contentKnowledgeSubtitle,
          ),
          const SizedBox(height: 12),
          for (final section in _knowledgeSections(l10n))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _KnowledgeCard(section: section),
            ),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  Text(
                    l10n.contentKnowledgeMoreInfo,
                    style: _bodyStyle(context),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.contentKnowledgeContact,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.primary,
                      fontWeight: FontWeight.w900,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(icon, color: Theme.of(context).colorScheme.primary),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: TextStyle(
                color: Colors.grey.shade700,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
              textAlign: TextAlign.center,
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
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Text(
          label,
          style: TextStyle(
            color: Theme.of(context).colorScheme.primary,
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
    );
  }
}

class _NumberedText extends StatelessWidget {
  const _NumberedText({required this.number, required this.text});

  final String number;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 17,
            backgroundColor: Theme.of(context).colorScheme.primary,
            child: Text(
              number,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: _bodyStyle(context))),
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
    return Row(
      children: [
        Expanded(
          flex: 5,
          child: Text(
            l10n.contentRewardHeaderPrizeType,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          flex: 3,
          child: Text(
            l10n.contentRewardHeaderCount,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
        ),
        Expanded(
          flex: 4,
          child: Text(
            l10n.contentRewardHeaderAmount,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w900),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 5,
            child: Text(title, style: const TextStyle(height: 1.35)),
          ),
          Expanded(
            flex: 3,
            child: Text(
              count,
              textAlign: TextAlign.center,
              style: const TextStyle(height: 1.35),
            ),
          ),
          Expanded(
            flex: 4,
            child: Text(
              amount,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w800, height: 1.35),
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
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              section.title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w900,
                  ),
            ),
            const SizedBox(height: 16),
            for (var index = 0; index < section.items.length; index++)
              _NumberedText(
                number: '${index + 1}',
                text: section.items[index],
              ),
          ],
        ),
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
    final lines = content
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
  return Theme.of(context).textTheme.bodyLarge?.copyWith(
            color: Colors.grey.shade800,
            fontWeight: FontWeight.w700,
            height: 1.55,
          ) ??
      TextStyle(
        color: Colors.grey.shade800,
        fontWeight: FontWeight.w700,
        height: 1.55,
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
