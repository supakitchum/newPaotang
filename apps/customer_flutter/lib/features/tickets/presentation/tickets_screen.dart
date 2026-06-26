import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/customer_localizations.dart';
import '../../../core/security/biometric_auth_service.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/tenant/mobile_runtime_policy.dart';
import '../../../core/utils/asset_url.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/profile/data/profile_settings_models.dart';
import '../../../features/profile/data/profile_settings_repository.dart';
import '../../../shared/widgets/app_shell.dart';
import '../../../shared/widgets/async/async_state_view.dart';
import '../data/ticket_models.dart';
import '../data/ticket_repository.dart';
import 'ticket_localization.dart';

class TicketsScreen extends ConsumerWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tickets = ref.watch(currentTicketsProvider);
    final l10n = context.l10n;

    return AppShell(
      title: l10n.ticketsTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.ticketsHistoryTooltip,
          onPressed: () => context.go('/tickets/history'),
          icon: const Icon(Icons.history),
        ),
      ],
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l10n.ticketsCurrentDrawTitle,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                  ),
                  const SizedBox(height: 8),
                  Text(l10n.ticketsCurrentDrawSubtitle),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          AsyncStateView(
            value: tickets,
            data: (items) {
              if (items.isEmpty) return const _EmptyTicketsCard();
              return Column(
                children: [
                  for (final ticket in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _TicketTile(ticket: ticket),
                    ),
                ],
              );
            },
            empty: const _EmptyTicketsCard(),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: () => context.go('/buy'),
            icon: const Icon(Icons.search),
            label: Text(l10n.ticketsSearchNumbers),
          ),
        ],
      ),
    );
  }
}

class _EmptyTicketsCard extends StatelessWidget {
  const _EmptyTicketsCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(
          child: Icon(Icons.confirmation_number_outlined),
        ),
        title: Text(context.l10n.ticketsEmptyTitle),
        subtitle: Text(context.l10n.ticketsEmptySubtitle),
      ),
    );
  }
}

class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.ticket, this.fromHistory = false});

  final CustomerTicket ticket;
  final bool fromHistory;

  @override
  Widget build(BuildContext context) {
    final statusColor = _ticketStatusColor(context, ticket);
    final l10n = context.l10n;
    final drawDate = ticketDrawDateText(l10n, ticket);
    return Card(
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: statusColor.withValues(alpha: 0.12),
          child: Icon(Icons.confirmation_number_outlined, color: statusColor),
        ),
        title: Text(
          ticket.number.isEmpty
              ? context.l10n.ticketsNumberFallback
              : ticket.number,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w900,
                letterSpacing: 2,
              ),
        ),
        subtitle: Text(
          [
            ticketStatusLabel(l10n, ticket),
            if (drawDate != '-') drawDate,
            l10n.ticketsCount(ticket.count),
          ].join(' • '),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: ticket.id.isEmpty
            ? null
            : () => context.go(
                  '/tickets/view?id=${ticket.id}'
                  '${fromHistory ? '&from=history' : ''}',
                ),
      ),
    );
  }
}

class TicketHistoryScreen extends ConsumerStatefulWidget {
  const TicketHistoryScreen({super.key});

  @override
  ConsumerState<TicketHistoryScreen> createState() =>
      _TicketHistoryScreenState();
}

class _TicketHistoryScreenState extends ConsumerState<TicketHistoryScreen> {
  final _tickets = <CustomerTicket>[];
  String? _cursor;
  bool _hasMore = false;
  bool _loadingInitial = true;
  bool _loadingMore = false;
  String _error = '';

  @override
  void initState() {
    super.initState();
    Future.microtask(_loadInitial);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return AppShell(
      title: l10n.ticketHistoryTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.ticketCurrentTooltip,
          onPressed: () => context.go('/tickets'),
          icon: const Icon(Icons.confirmation_number_outlined),
        ),
      ],
      child: RefreshIndicator(
        onRefresh: _loadInitial,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).colorScheme.primaryContainer,
                  child: const Icon(Icons.history),
                ),
                title: Text(
                  l10n.ticketHistoryHeaderTitle,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                subtitle: Text(l10n.ticketHistoryHeaderSubtitle),
              ),
            ),
            const SizedBox(height: 12),
            if (_loadingInitial)
              const _TicketLoadingList()
            else if (_error.isNotEmpty)
              _TicketErrorCard(message: _error, onRetry: _loadInitial)
            else if (_tickets.isEmpty)
              const _TicketEmptyHistoryCard()
            else ...[
              for (final ticket in _tickets)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _TicketTile(ticket: ticket, fromHistory: true),
                ),
              if (_hasMore)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: OutlinedButton.icon(
                    onPressed: _loadingMore ? null : _loadMore,
                    icon: _loadingMore
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.expand_more),
                    label: Text(
                      _loadingMore
                          ? l10n.commonLoadingMore
                          : l10n.commonLoadMore,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _loadInitial() async {
    setState(() {
      _loadingInitial = true;
      _error = '';
    });
    try {
      final page = await ref.read(ticketRepositoryProvider).history();
      if (!mounted) return;
      setState(() {
        _tickets
          ..clear()
          ..addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.ticketHistoryLoadFailed);
    } finally {
      if (mounted) setState(() => _loadingInitial = false);
    }
  }

  Future<void> _loadMore() async {
    final cursor = _cursor;
    if (cursor == null || cursor.isEmpty || _loadingMore) return;
    setState(() => _loadingMore = true);
    try {
      final page = await ref.read(ticketRepositoryProvider).history(
            cursor: cursor,
          );
      if (!mounted) return;
      setState(() {
        _tickets.addAll(page.items);
        _cursor = page.nextCursor;
        _hasMore = page.hasMore;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.ticketHistoryLoadMoreFailed)),
      );
    } finally {
      if (mounted) setState(() => _loadingMore = false);
    }
  }
}

class TicketViewScreen extends ConsumerWidget {
  const TicketViewScreen({
    required this.ticketId,
    required this.fromHistory,
    super.key,
  });

  final String ticketId;
  final bool fromHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ticket = ref.watch(ticketDetailProvider(ticketId));
    final backPath = fromHistory ? '/tickets/history' : '/tickets';

    return AppShell(
      title: context.l10n.ticketDetailTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: context.l10n.commonBack,
          onPressed: () => context.go(backPath),
          icon: const Icon(Icons.close),
        ),
      ],
      child: AsyncStateView(
        value: ticket,
        data: (item) => _TicketDetailContent(
          ticket: item,
          fromHistory: fromHistory,
        ),
        empty: _TicketErrorCard(message: context.l10n.ticketsNotFound),
      ),
    );
  }
}

class _TicketDetailContent extends ConsumerWidget {
  const _TicketDetailContent({
    required this.ticket,
    required this.fromHistory,
  });

  final CustomerTicket ticket;
  final bool fromHistory;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final resolver = ref.watch(assetUrlResolverProvider);
    final statusColor = _ticketStatusColor(context, ticket);
    final l10n = context.l10n;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _TicketImageCard(ticket: ticket, resolver: resolver),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        ticket.number.isEmpty
                            ? l10n.ticketLabelLotteryNumber
                            : ticket.number,
                        style:
                            Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 3,
                                ),
                      ),
                    ),
                    _TicketStatusPill(
                      label: ticketStatusLabel(l10n, ticket),
                      color: statusColor,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _TicketInfoRow(
                  label: l10n.ticketLabelDraw,
                  value: ticket.gameName,
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelDrawDate,
                  value: ticketDrawDateText(l10n, ticket),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelCount,
                  value: l10n.ticketsCount(ticket.count),
                ),
                if (ticket.prizeAmount > 0)
                  _TicketInfoRow(
                    label: l10n.ticketLabelPrizeAmount,
                    value: formatBaht(ticket.prizeAmount),
                    emphasize: true,
                  ),
                if (ticket.prizes.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final prize in ticket.prizes)
                        Chip(
                          label: Text(
                            '${ticketPrizeTypeLabel(l10n, prize.prizeType)} '
                            '${formatBaht(prize.amount)}',
                          ),
                        ),
                    ],
                  ),
                ],
                if (ticket.rewardStatus.adminNote.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Text(
                    ticket.rewardStatus.adminNote,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (ticket.hasExistingClaim && !ticket.canCreateClaim)
          FilledButton.icon(
            onPressed: () =>
                context.go('/reward-claims/${ticket.rewardClaimId}'),
            icon: const Icon(Icons.receipt_long),
            label: Text(l10n.ticketClaimViewClaim),
          )
        else if (ticket.canCreateClaim)
          FilledButton.icon(
            onPressed: () => context.go(
              '/tickets/claim/${ticket.id}'
              '?from=${fromHistory ? 'history' : 'current'}',
            ),
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: Text(l10n.ticketClaimStart),
          )
        else
          OutlinedButton.icon(
            onPressed: null,
            icon: const Icon(Icons.info_outline),
            label: Text(ticketStatusLabel(l10n, ticket)),
          ),
      ],
    );
  }
}

class TicketClaimScreen extends ConsumerStatefulWidget {
  const TicketClaimScreen({
    required this.ticketId,
    required this.fromHistory,
    super.key,
  });

  final String ticketId;
  final bool fromHistory;

  @override
  ConsumerState<TicketClaimScreen> createState() => _TicketClaimScreenState();
}

class _TicketClaimScreenState extends ConsumerState<TicketClaimScreen> {
  CustomerTicket? _ticket;
  CustomerProfileSettings? _profile;
  RewardClaimSubmission? _submittedClaim;
  String _payoutMethod = 'wallet_credit';
  String _pin = '';
  String _error = '';
  String _pinError = '';
  bool _loading = true;
  bool _submitting = false;
  _ClaimStep _step = _ClaimStep.select;

  @override
  void initState() {
    super.initState();
    Future.microtask(_load);
  }

  @override
  Widget build(BuildContext context) {
    final backPath = widget.fromHistory ? '/tickets/history' : '/tickets';
    final l10n = context.l10n;
    return AppShell(
      title: _step == _ClaimStep.pin
          ? l10n.ticketClaimPinTitle
          : l10n.ticketClaimTitle,
      currentPath: '/tickets',
      sensitive: true,
      actions: [
        IconButton(
          tooltip: l10n.commonBack,
          onPressed: () {
            if (_step == _ClaimStep.confirm) {
              setState(() => _step = _ClaimStep.select);
              return;
            }
            if (_step == _ClaimStep.pin) {
              setState(() {
                _step = _ClaimStep.confirm;
                _pin = '';
                _pinError = '';
              });
              return;
            }
            context.go(backPath);
          },
          icon: const Icon(Icons.close),
        ),
      ],
      child: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error.isNotEmpty) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [_TicketErrorCard(message: _error, onRetry: _load)],
      );
    }

    final ticket = _ticket;
    if (ticket == null) {
      return Center(child: Text(context.l10n.ticketsNotFound));
    }
    if (ticket.hasExistingClaim && !ticket.canCreateClaim) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const CircleAvatar(child: Icon(Icons.receipt_long)),
              title: Text(context.l10n.ticketClaimAlreadyTitle),
              subtitle: Text(context.l10n.ticketClaimAlreadySubtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => context.go('/reward-claims/${ticket.rewardClaimId}'),
            ),
          ),
        ],
      );
    }

    final platformKey = ref.watch(customerPlatformKeyProvider);
    final biometricEnabled = ref.watch(mobileBootstrapProvider).maybeWhen(
          data: (data) => mobileBiometricAllowedForPlatform(data, platformKey),
          orElse: () => false,
        );

    return switch (_step) {
      _ClaimStep.select => _ClaimSelectStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          onMethodChanged: (value) => setState(() => _payoutMethod = value),
          onNext: _canContinue
              ? () => setState(() => _step = _ClaimStep.confirm)
              : null,
        ),
      _ClaimStep.confirm => _ClaimConfirmStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          submitting: _submitting,
          onBack: () => setState(() => _step = _ClaimStep.select),
          onConfirm: _canContinue
              ? () => setState(() {
                    _step = _ClaimStep.pin;
                    _pin = '';
                    _pinError = '';
                  })
              : null,
        ),
      _ClaimStep.pin => _ClaimPinStep(
          pin: _pin,
          error: _pinError,
          submitting: _submitting,
          biometricEnabled: biometricEnabled,
          onDigit: _appendPinDigit,
          onBackspace: _removePinDigit,
          onBiometric: _submitClaimWithBiometric,
        ),
      _ClaimStep.processing => _ClaimProcessingStep(
          ticket: ticket,
          profile: _profile,
          payoutMethod: _payoutMethod,
          submittedClaim: _submittedClaim,
        ),
    };
  }

  bool get _hasBankAccount => _profile?.bankAccount.isComplete ?? false;

  bool get _canContinue {
    final ticket = _ticket;
    if (ticket == null || _submitting || !ticket.canCreateClaim) return false;
    if (_payoutMethod == 'bank_transfer' && !_hasBankAccount) return false;
    return true;
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = '';
    });
    try {
      final ticket =
          await ref.read(ticketRepositoryProvider).detail(widget.ticketId);
      TicketRewardStatus? rewardStatus;
      try {
        rewardStatus = await ref
            .read(ticketRepositoryProvider)
            .rewardStatus(widget.ticketId);
      } catch (_) {
        rewardStatus = null;
      }
      CustomerProfileSettings? profile;
      try {
        profile = await ref.read(profileSettingsRepositoryProvider).load();
      } catch (_) {
        profile = null;
      }
      if (!mounted) return;
      setState(() {
        _ticket = rewardStatus == null
            ? ticket
            : CustomerTicket.fromJson({
                'id': ticket.id,
                'game_id': ticket.gameId,
                'game': {
                  'id': ticket.gameId,
                  'name': ticket.gameName,
                  'draw_at': ticket.drawAt,
                },
                'full_number': ticket.number,
                'status': ticket.status,
                'reward_status': {
                  'status': rewardStatus.status,
                  'claim_status': rewardStatus.claimStatus,
                  'claimable': rewardStatus.claimable,
                  'prize_type': rewardStatus.prizeType,
                  'prize_number': rewardStatus.prizeNumber,
                  'prize_amount': {
                    'amount': (rewardStatus.prizeAmount * 100).round(),
                  },
                  'prizes': rewardStatus.prizes
                      .map(
                        (prize) => {
                          'prize_type': prize.prizeType,
                          'prize_number': prize.prizeNumber,
                          'amount': {
                            'amount': (prize.amount * 100).round(),
                          },
                        },
                      )
                      .toList(growable: false),
                  'reward_claim_id': rewardStatus.rewardClaimId,
                  'payout_method': rewardStatus.payoutMethod,
                  'admin_note': rewardStatus.adminNote,
                },
                'image_url': ticket.imageUrl,
                'image_thumb_url': ticket.imageThumbUrl,
                'preview_image_url': ticket.previewImageUrl,
                'image_status': ticket.imageStatus,
                'image_error': ticket.imageError,
              });
        _profile = profile;
        if (profile?.bankAccount.isComplete ?? false) {
          _payoutMethod = 'bank_transfer';
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _error = context.l10n.ticketClaimLoadFailed);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _appendPinDigit(String digit) {
    if (_pin.length >= 6 || _submitting) return;
    setState(() {
      _pin += digit;
      _pinError = '';
    });
    if (_pin.length == 6) _submitClaim();
  }

  void _removePinDigit() {
    if (_pin.isEmpty || _submitting) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _pinError = '';
    });
  }

  Future<void> _submitClaim({String pinAssertionToken = ''}) async {
    final ticket = _ticket;
    if (ticket == null || !_canContinue || _submitting) return;
    setState(() => _submitting = true);
    try {
      final claim = await ref.read(ticketRepositoryProvider).createRewardClaim(
            ticketId: ticket.id,
            payoutMethod: _payoutMethod,
            pin: pinAssertionToken.isEmpty ? _pin : '',
            pinAssertionToken: pinAssertionToken,
            bankAccount: _payoutMethod == 'bank_transfer'
                ? _profile?.bankAccount.toJson()
                : null,
          );
      if (!mounted) return;
      setState(() {
        _submittedClaim = claim;
        _step = _ClaimStep.processing;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _pin = '';
        _pinError = _claimErrorText(error);
      });
      if (_pinError.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(context.l10n.ticketClaimSubmitFailed)),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _submitClaimWithBiometric() async {
    if (_submitting) return;
    setState(() {
      _pin = '';
      _pinError = '';
    });
    try {
      final token =
          await ref.read(biometricAuthServiceProvider).requestPinAssertion(
                purpose: 'reward_claim',
                localizedReason: context.l10n.pinBiometricReason,
              );
      if (!mounted) return;
      if (token == null || token.isEmpty) {
        setState(
          () => _pinError = context.l10n.ticketClaimBiometricUnavailable,
        );
        return;
      }
      await _submitClaim(pinAssertionToken: token);
    } catch (_) {
      if (!mounted) return;
      setState(() => _pinError = context.l10n.ticketClaimBiometricFailed);
    }
  }

  String _claimErrorText(Object error) {
    final code = _errorCode(error);
    final l10n = context.l10n;
    if (code == 'pin_invalid') {
      return l10n.ticketClaimPinInvalid;
    }
    if (code == 'pin_locked') {
      return l10n.ticketClaimPinLocked;
    }
    if (code == 'pin_setup_required' || code == 'pin_required') {
      return l10n.ticketClaimPinSetupRequired;
    }
    if (code == 'pin_assertion_invalid') {
      return l10n.ticketClaimPinAssertionInvalid;
    }
    if (code == 'resource_conflict') {
      return l10n.ticketClaimConflict;
    }
    return '';
  }

  String _errorCode(Object error) {
    final data = error is DioException ? error.response?.data : null;
    if (data is Map) {
      final err = data['error'];
      if (err is Map && err['code'] != null) return err['code'].toString();
      if (data['code'] != null) return data['code'].toString();
    }
    return '';
  }
}

class _ClaimSelectStep extends StatelessWidget {
  const _ClaimSelectStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.onMethodChanged,
    required this.onNext,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final ValueChanged<String> onMethodChanged;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final bank = profile?.bankAccount;
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ClaimTicketSummary(ticket: ticket),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.ticketClaimPayoutMethodTitle,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 12),
                _PayoutOption(
                  selected: payoutMethod == 'wallet_credit',
                  icon: Icons.account_balance_wallet_outlined,
                  title: l10n.ticketClaimWalletTitle,
                  subtitle: l10n.ticketClaimWalletSubtitle,
                  onTap: () => onMethodChanged('wallet_credit'),
                ),
                const SizedBox(height: 8),
                _PayoutOption(
                  selected: payoutMethod == 'bank_transfer',
                  enabled: bank?.isComplete ?? false,
                  icon: Icons.account_balance_outlined,
                  title: bank?.isComplete ?? false
                      ? '${bank!.bankName} ${bank.maskedNumber}'
                      : l10n.ticketClaimBankTitle,
                  subtitle: bank?.isComplete ?? false
                      ? l10n.ticketClaimBankSubtitleReady
                      : l10n.ticketClaimBankSubtitleMissing,
                  onTap: () => onMethodChanged('bank_transfer'),
                ),
                if (!(bank?.isComplete ?? false)) ...[
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: () => context.go(
                      '/profile/reward-bank?redirect=/tickets/claim/${ticket.id}',
                    ),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.ticketClaimAddBank),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: onNext,
          child: Text(l10n.commonNext),
        ),
      ],
    );
  }
}

class _ClaimConfirmStep extends StatelessWidget {
  const _ClaimConfirmStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.submitting,
    required this.onBack,
    required this.onConfirm,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final bool submitting;
  final VoidCallback onBack;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        _ClaimTicketSummary(ticket: ticket),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _TicketInfoRow(
                  label: l10n.ticketLabelRecipient,
                  value: profile?.name ?? '-',
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPayoutChannel,
                  value: _payoutLabel(l10n, profile, payoutMethod),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelLotteryNumber,
                  value: ticket.number,
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPrizeAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
                const Divider(height: 28),
                _TicketInfoRow(
                  label: l10n.ticketLabelNetAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: submitting ? null : onBack,
                child: Text(l10n.commonBack),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton(
                onPressed: submitting ? null : onConfirm,
                child: Text(l10n.commonConfirm),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClaimPinStep extends StatelessWidget {
  const _ClaimPinStep({
    required this.pin,
    required this.error,
    required this.submitting,
    required this.biometricEnabled,
    required this.onDigit,
    required this.onBackspace,
    required this.onBiometric,
  });

  final String pin;
  final String error;
  final bool submitting;
  final bool biometricEnabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final VoidCallback onBiometric;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'back'];
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 24),
        Icon(
          Icons.lock_outline,
          size: 52,
          color: Theme.of(context).colorScheme.primary,
        ),
        const SizedBox(height: 16),
        Text(
          l10n.ticketClaimEnterPin,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w900,
              ),
        ),
        const SizedBox(height: 8),
        Text(
          '${'●' * pin.length}${'○' * (6 - pin.length)}',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (error.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            error,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Theme.of(context).colorScheme.error,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
        if (submitting) ...[
          const SizedBox(height: 12),
          const Center(child: CircularProgressIndicator()),
        ],
        const SizedBox(height: 24),
        if (biometricEnabled) ...[
          OutlinedButton.icon(
            onPressed: submitting ? null : onBiometric,
            icon: const Icon(Icons.face_retouching_natural),
            label: Text(l10n.pinUseBiometric),
          ),
          const SizedBox(height: 12),
        ],
        GridView.count(
          shrinkWrap: true,
          crossAxisCount: 3,
          childAspectRatio: 1.55,
          physics: const NeverScrollableScrollPhysics(),
          children: [
            for (final key in keys)
              if (key.isEmpty)
                const SizedBox.shrink()
              else
                Padding(
                  padding: const EdgeInsets.all(6),
                  child: FilledButton.tonal(
                    onPressed: submitting
                        ? null
                        : key == 'back'
                            ? onBackspace
                            : () => onDigit(key),
                    child: key == 'back'
                        ? const Icon(Icons.backspace_outlined)
                        : Text(
                            key,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                  ),
                ),
          ],
        ),
      ],
    );
  }
}

class _ClaimProcessingStep extends StatelessWidget {
  const _ClaimProcessingStep({
    required this.ticket,
    required this.profile,
    required this.payoutMethod,
    required this.submittedClaim,
  });

  final CustomerTicket ticket;
  final CustomerProfileSettings? profile;
  final String payoutMethod;
  final RewardClaimSubmission? submittedClaim;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Icon(
                  Icons.schedule,
                  size: 56,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 12),
                Text(
                  l10n.ticketClaimProcessingTitle,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w900,
                      ),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.ticketClaimProcessingSubtitle,
                  textAlign: TextAlign.center,
                ),
                const Divider(height: 28),
                _TicketInfoRow(
                  label: l10n.ticketLabelRecipient,
                  value: profile?.name ?? '-',
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPayoutChannel,
                  value: _payoutLabel(l10n, profile, payoutMethod),
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelLotteryNumber,
                  value: ticket.number,
                ),
                _TicketInfoRow(
                  label: l10n.ticketLabelPrizeAmount,
                  value: formatBaht(ticket.prizeAmount),
                  emphasize: true,
                ),
                if (submittedClaim != null)
                  _TicketInfoRow(
                    label: l10n.ticketLabelSubmittedAt,
                    value: rewardClaimSubmittedText(l10n, submittedClaim!),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: () => context.go('/tickets'),
          child: Text(l10n.ticketClaimViewMyTickets),
        ),
      ],
    );
  }
}

class _ClaimTicketSummary extends StatelessWidget {
  const _ClaimTicketSummary({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.ticketLabelGovernmentLottery,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            _TicketInfoRow(
              label: l10n.ticketLabelLotteryNumber,
              value: ticket.number,
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelDraw,
              value: ticketDrawDateText(l10n, ticket),
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelPrize,
              value: ticketPrizeSummary(l10n, ticket),
            ),
            _TicketInfoRow(
              label: l10n.ticketLabelPrizeAmount,
              value: formatBaht(ticket.prizeAmount),
              emphasize: true,
            ),
          ],
        ),
      ),
    );
  }
}

class _PayoutOption extends StatelessWidget {
  const _PayoutOption({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
  });

  final bool selected;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme.primary;
    return InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? color : Theme.of(context).dividerColor,
            width: selected ? 2 : 1,
          ),
          color: selected ? color.withValues(alpha: 0.08) : null,
        ),
        child: Row(
          children: [
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? color : null,
            ),
            const SizedBox(width: 12),
            CircleAvatar(child: Icon(icon)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  Text(subtitle),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TicketImageCard extends StatelessWidget {
  const _TicketImageCard({required this.ticket, required this.resolver});

  final CustomerTicket ticket;
  final AssetUrlResolver resolver;

  @override
  Widget build(BuildContext context) {
    final url = resolver(ticket.primaryImageUrl);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: AspectRatio(
        aspectRatio: 16 / 10,
        child: url.isEmpty
            ? _ImagePlaceholder(ticket: ticket)
            : Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) =>
                    _ImagePlaceholder(ticket: ticket),
                loadingBuilder: (context, child, loadingProgress) {
                  if (loadingProgress == null) return child;
                  return const Center(child: CircularProgressIndicator());
                },
              ),
      ),
    );
  }
}

class _ImagePlaceholder extends StatelessWidget {
  const _ImagePlaceholder({required this.ticket});

  final CustomerTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.center,
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.image_not_supported_outlined, size: 44),
          const SizedBox(height: 8),
          Text(
            ticket.imageStatus == 'ready'
                ? context.l10n.ticketImageUnavailable
                : context.l10n.ticketImagePreparing,
            textAlign: TextAlign.center,
            style: const TextStyle(fontWeight: FontWeight.w900),
          ),
          if (ticket.imageError.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(ticket.imageError, textAlign: TextAlign.center),
          ],
        ],
      ),
    );
  }
}

class _TicketInfoRow extends StatelessWidget {
  const _TicketInfoRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });

  final String label;
  final String value;
  final bool emphasize;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontWeight: emphasize ? FontWeight.w900 : FontWeight.w700,
                color: emphasize ? Theme.of(context).colorScheme.primary : null,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TicketStatusPill extends StatelessWidget {
  const _TicketStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        color: color.withValues(alpha: 0.12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _TicketLoadingList extends StatelessWidget {
  const _TicketLoadingList();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _TicketErrorCard extends StatelessWidget {
  const _TicketErrorCard({required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Icon(
              Icons.error_outline,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 8),
            Text(message, textAlign: TextAlign.center),
            if (onRetry != null) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _TicketEmptyHistoryCard extends StatelessWidget {
  const _TicketEmptyHistoryCard();

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        leading: const CircleAvatar(child: Icon(Icons.history)),
        title: Text(context.l10n.ticketHistoryEmptyTitle),
        subtitle: Text(context.l10n.ticketHistoryEmptySubtitle),
      ),
    );
  }
}

enum _ClaimStep { select, confirm, pin, processing }

Color _ticketStatusColor(BuildContext context, CustomerTicket ticket) {
  final status = ticket.rewardStatus.status;
  if (status == 'paid' || status == 'paid_out' || ticket.status == 'paid') {
    return Colors.green;
  }
  if (status == 'rejected' ||
      ticket.rewardStatus.claimStatus == 'rejected' ||
      ticket.status == 'rejected') {
    return Theme.of(context).colorScheme.error;
  }
  if (status == 'winning') return Colors.orange.shade800;
  if (status == 'non_winning') return Theme.of(context).colorScheme.outline;
  return Theme.of(context).colorScheme.primary;
}

String _payoutLabel(
  CustomerLocalizations l10n,
  CustomerProfileSettings? profile,
  String method,
) {
  if (method == 'bank_transfer') {
    final bank = profile?.bankAccount;
    if (bank == null || !bank.isComplete) return l10n.ticketClaimBankTitle;
    return '${bank.bankName} ${bank.maskedNumber}';
  }
  return l10n.ticketClaimWalletTitle;
}
