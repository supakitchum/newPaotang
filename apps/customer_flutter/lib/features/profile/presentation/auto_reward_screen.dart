import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../shared/widgets/app_shell.dart';
import '../data/profile_settings_models.dart';
import '../data/profile_settings_repository.dart';

class AutoRewardScreen extends ConsumerStatefulWidget {
  const AutoRewardScreen({super.key});

  @override
  ConsumerState<AutoRewardScreen> createState() => _AutoRewardScreenState();
}

class _AutoRewardScreenState extends ConsumerState<AutoRewardScreen> {
  bool _showIntro = true;
  String _payoutType = 'wallet';
  String _hydratedProfileId = '';
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final profile = ref.watch(customerProfileSettingsProvider);
    return profile.when(
      data: (data) {
        _hydrate(data);
        return _showIntro
            ? _AutoRewardIntro(
                onStart: () => setState(() => _showIntro = false),
              )
            : _AutoRewardSelect(
                profile: data,
                payoutType: _payoutType,
                saving: _saving,
                onInfo: () => setState(() => _showIntro = true),
                onChanged: _selectPayoutType,
                onSave: () => _save(data),
              );
      },
      loading: () => AppShell(
        title: l10n.profileAutoReward,
        currentPath: '/profile',
        sensitive: true,
        child: const Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => AppShell(
        title: l10n.profileAutoReward,
        currentPath: '/profile',
        sensitive: true,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      l10n.profileAutoRewardLoadFailed,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () =>
                          ref.invalidate(customerProfileSettingsProvider),
                      icon: const Icon(Icons.refresh),
                      label: Text(l10n.commonRetry),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _hydrate(CustomerProfileSettings profile) {
    if (_hydratedProfileId == profile.id) return;
    _hydratedProfileId = profile.id;
    _payoutType =
        profile.autoReward.isBankTransfer ? 'bank_transfer' : 'wallet';
    _showIntro = !profile.autoReward.enabled;
  }

  void _selectPayoutType(String type, CustomerProfileSettings profile) {
    setState(() => _payoutType = type);
    if (type == 'bank_transfer' && !profile.bankAccount.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.profileAutoRewardSaveBankFirst),
        ),
      );
    }
  }

  Future<void> _save(CustomerProfileSettings profile) async {
    final l10n = context.l10n;
    if (_payoutType == 'bank_transfer' && !profile.bankAccount.isComplete) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.profileAutoRewardAddBankFirst)),
      );
      context.go('/profile/reward-bank?redirect=/profile/auto-reward');
      return;
    }

    final savedMessage = l10n.profileAutoRewardSaved;
    final failedMessage = l10n.profileAutoRewardSaveFailed;
    setState(() => _saving = true);
    try {
      await ref.read(profileSettingsRepositoryProvider).saveAutoReward(
            enabled: true,
            payoutMethod: _payoutType,
          );
      ref.invalidate(customerProfileSettingsProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(savedMessage)),
      );
      context.go('/profile');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(failedMessage)),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class _AutoRewardIntro extends StatelessWidget {
  const _AutoRewardIntro({required this.onStart});

  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final benefits = [
      l10n.profileAutoRewardBenefitConvenient,
      l10n.profileAutoRewardBenefitEasy,
      l10n.profileAutoRewardBenefitFast,
    ];
    return AppShell(
      title: l10n.profileAutoReward,
      currentPath: '/profile',
      sensitive: true,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(22),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 42,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(
                      Icons.account_balance_wallet_outlined,
                      size: 40,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.profileAutoReward,
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w900,
                        ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    l10n.profileAutoRewardIntroSubtitle,
                    textAlign: TextAlign.center,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 20),
                  for (final item in benefits) _BenefitRow(text: item),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.profileAutoRewardConditionsTitle,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _BulletText(
                    l10n.profileAutoRewardConditionAutoClaim,
                  ),
                  _BulletText(
                    l10n.profileAutoRewardConditionChangeBefore,
                  ),
                  _BulletText(
                    l10n.profileAutoRewardConditionNoRetroactive,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onStart,
            icon: const Icon(Icons.settings_outlined),
            label: Text(l10n.profileAutoRewardStartButton),
          ),
        ],
      ),
    );
  }
}

class _AutoRewardSelect extends StatelessWidget {
  const _AutoRewardSelect({
    required this.profile,
    required this.payoutType,
    required this.saving,
    required this.onInfo,
    required this.onChanged,
    required this.onSave,
  });

  final CustomerProfileSettings profile;
  final String payoutType;
  final bool saving;
  final VoidCallback onInfo;
  final void Function(String, CustomerProfileSettings) onChanged;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return AppShell(
      title: l10n.profileAutoReward,
      currentPath: '/profile',
      sensitive: true,
      actions: [
        IconButton(
          onPressed: onInfo,
          icon: const Icon(Icons.info_outline),
          tooltip: l10n.profileAutoRewardInfoTooltip,
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            l10n.profileAutoRewardSelectTitle,
            style: Theme.of(context)
                .textTheme
                .titleLarge
                ?.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.profileAutoRewardSelectSubtitle,
            style: TextStyle(color: Colors.grey.shade700, height: 1.4),
          ),
          const SizedBox(height: 16),
          _PayoutOption(
            selected: payoutType == 'wallet',
            icon: Icons.account_balance_wallet_outlined,
            title: l10n.profileAutoRewardWalletTitle,
            subtitle: maskWalletId(profile.customerNo),
            helper: l10n.profileAutoRewardWalletSubtitle,
            onTap: () => onChanged('wallet', profile),
          ),
          const SizedBox(height: 10),
          _PayoutOption(
            selected: payoutType == 'bank_transfer',
            icon: Icons.account_balance_outlined,
            title: _bankTitle(profile.bankAccount, l10n),
            subtitle: profile.bankAccount.isComplete
                ? '${profile.bankAccount.accountName} · ${profile.bankAccount.maskedNumber}'
                : l10n.profileAutoRewardBankMissingSubtitle,
            helper: profile.bankAccount.isComplete
                ? ''
                : l10n.profileAutoRewardBankMissingHelper,
            onTap: () => onChanged('bank_transfer', profile),
            warning: !profile.bankAccount.isComplete,
          ),
          const SizedBox(height: 18),
          FilledButton.icon(
            onPressed: saving ? null : onSave,
            icon: saving
                ? const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.arrow_forward),
            label: Text(l10n.commonNext),
          ),
        ],
      ),
    );
  }

  String _bankTitle(
    RewardBankAccount account,
    CustomerLocalizations l10n,
  ) {
    if (!account.isComplete) return l10n.profileAutoRewardBankTitle;
    final bank = account.bankName.trim();
    return bank.isEmpty ? l10n.profileAutoRewardBankTitle : bank;
  }
}

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.helper = '',
    this.warning = false,
  });

  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final String helper;
  final bool warning;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = warning
        ? Colors.orange.shade800
        : selected
            ? Theme.of(context).colorScheme.primary
            : Colors.grey.shade600;
    return Card(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color:
              selected ? Theme.of(context).colorScheme.primary : Colors.black12,
          width: selected ? 2 : 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(
                selected ? Icons.check_circle : Icons.radio_button_unchecked,
                color: color,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle),
                    if (helper.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        helper,
                        style: TextStyle(
                          color: color,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              CircleAvatar(
                backgroundColor: color.withValues(alpha: 0.12),
                child: Icon(icon, color: color),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  const _BenefitRow({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: Colors.green.shade700),
          const SizedBox(width: 10),
          Expanded(
            child:
                Text(text, style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _BulletText extends StatelessWidget {
  const _BulletText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('• '),
          Expanded(child: Text(text, style: const TextStyle(height: 1.45))),
        ],
      ),
    );
  }
}
