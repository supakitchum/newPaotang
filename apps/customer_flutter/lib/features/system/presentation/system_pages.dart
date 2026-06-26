import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/i18n/app_locale.dart';
import '../../../core/i18n/customer_localizations.dart';
import '../../../core/tenant/mobile_bootstrap_controller.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/purchase_history/data/purchase_history_models.dart';
import '../../../features/purchase_history/data/purchase_history_repository.dart';
import '../../../features/purchase_history/presentation/purchase_history_localization.dart';
import '../../../features/results/data/result_repository.dart';
import '../../../shared/widgets/app_shell.dart';

class MaintenanceScreen extends ConsumerWidget {
  const MaintenanceScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bootstrap = ref.watch(mobileBootstrapProvider);
    final l10n = context.l10n;
    return bootstrap.when(
      data: (data) {
        final message = data.maintenance.message.isNotEmpty
            ? data.maintenance.message
            : l10n.maintenanceDefaultMessage;
        return _FullPageState(
          icon: Icons.construction_outlined,
          title: l10n.maintenanceTitle(data.siteName),
          message: message,
          footer: [
            if (data.maintenance.expectedEndAt != null)
              Text(
                l10n.maintenanceExpectedEnd(
                  formatLocalizedDateTime(
                    data.maintenance.expectedEndAt,
                    localeTag(l10n.locale),
                  ),
                ),
                textAlign: TextAlign.center,
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
            if (data.supportPhone.isNotEmpty)
              OutlinedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.support_agent_outlined),
                label: Text(l10n.maintenanceSupport(data.supportPhone)),
              ),
          ],
        );
      },
      loading: () => _FullPageState(
        icon: Icons.construction_outlined,
        title: l10n.maintenanceLoadingTitle,
        message: l10n.maintenanceLoadingMessage,
        loading: true,
      ),
      error: (_, __) => _FullPageState(
        icon: Icons.construction_outlined,
        title: l10n.maintenanceFallbackTitle,
        message: l10n.maintenanceDefaultMessage,
      ),
    );
  }
}

class AccountSuspendedScreen extends StatelessWidget {
  const AccountSuspendedScreen({
    super.key,
    this.reason = '',
    this.suspendedUntil,
    this.permanent = false,
  });

  final String reason;
  final String? suspendedUntil;
  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final untilText = permanent
        ? l10n.accountSuspendedPermanent
        : suspendedUntil == null || suspendedUntil!.isEmpty
            ? l10n.accountSuspendedTemporary
            : l10n.accountSuspendedUntil(
                formatLocalizedDateTime(suspendedUntil, localeTag(l10n.locale)),
              );
    return _FullPageState(
      icon: Icons.shield_outlined,
      iconColor: Colors.red.shade700,
      title: l10n.accountSuspendedTitle,
      message: l10n.accountSuspendedMessage,
      footer: [
        _InfoPanel(
          label: l10n.accountSuspendedReason,
          value: reason.trim().isEmpty
              ? l10n.accountSuspendedNoReason
              : reason.trim(),
        ),
        _InfoPanel(label: l10n.accountSuspendedDuration, value: untilText),
        FilledButton(
          onPressed: () => context.go('/login'),
          child: Text(l10n.accountSuspendedBackToLogin),
        ),
      ],
    );
  }
}

class CountdownScreen extends ConsumerStatefulWidget {
  const CountdownScreen({super.key});

  @override
  ConsumerState<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends ConsumerState<CountdownScreen> {
  Timer? _timer;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final game = ref.watch(currentResultProvider);
    final l10n = context.l10n;
    return AppShell(
      title: l10n.countdownTitle,
      currentPath: '/',
      child: game.when(
        data: (bundle) {
          final current = bundle.currentGame;
          final saleStartAt = parseDateTime(current?.saleStartAt);
          final remaining = saleStartAt == null
              ? Duration.zero
              : saleStartAt.difference(_now);
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    children: [
                      const Icon(Icons.hourglass_top, size: 54),
                      const SizedBox(height: 14),
                      Text(
                        l10n.countdownWaitingTitle,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        current?.name.isNotEmpty == true
                            ? current!.name
                            : l10n.countdownCurrentDrawFallback,
                        textAlign: TextAlign.center,
                      ),
                      if (saleStartAt != null) ...[
                        const SizedBox(height: 6),
                        Text(
                          l10n.countdownSaleOpensAt(
                            formatLocalizedDateTime(
                              saleStartAt,
                              localeTag(l10n.locale),
                            ),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: 18),
                      _CountdownGrid(remaining: remaining),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: () => context.go('/result'),
                icon: const Icon(Icons.emoji_events_outlined),
                label: Text(l10n.waitingResultCheckResult),
              ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorCard(
          message: l10n.countdownLoadFailed,
          onRetry: () => ref.invalidate(currentResultProvider),
        ),
      ),
    );
  }
}

class SuccessScreen extends ConsumerWidget {
  const SuccessScreen({super.key, this.orderId});

  final String? orderId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final id = orderId ?? '';
    final order = id.isEmpty
        ? const AsyncValue<PurchaseHistoryOrder?>.data(null)
        : ref
            .watch(purchaseHistoryDetailProvider(id))
            .whenData((value) => value);
    return AppShell(
      title: context.l10n.successTitle,
      currentPath: '/tickets',
      sensitive: true,
      child: order.when(
        data: (item) => ListView(
          padding: const EdgeInsets.all(18),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(22),
                child: Column(
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: Colors.green.shade50,
                      child: Icon(
                        Icons.check_rounded,
                        color: Colors.green.shade700,
                        size: 42,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      context.l10n.successPurchaseTitle,
                      style: Theme.of(context)
                          .textTheme
                          .titleLarge
                          ?.copyWith(fontWeight: FontWeight.w900),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      context.l10n.successPurchaseSubtitle,
                      textAlign: TextAlign.center,
                    ),
                    if (item != null) ...[
                      const Divider(height: 28),
                      _ReceiptRow(
                        label: context.l10n.purchaseHistoryTicketCountLabel,
                        value: context.l10n
                            .purchaseHistoryTicketCount(item.ticketCount),
                      ),
                      _ReceiptRow(
                        label: context.l10n.purchaseHistoryDrawDateLabel,
                        value: localizedPurchaseDrawDate(context, item),
                      ),
                      _ReceiptRow(
                        label: context.l10n.purchaseHistoryPaymentChannelLabel,
                        value: localizedPurchasePaymentChannel(item),
                      ),
                      _ReceiptRow(
                        label: context.l10n.purchaseHistoryTotalLabel,
                        value: formatBaht(item.total),
                      ),
                      _ReceiptRow(
                        label: context.l10n.purchaseHistoryReferenceLabel,
                        value: item.displayReference,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: () => context.go('/tickets'),
              icon: const Icon(Icons.confirmation_number_outlined),
              label: Text(context.l10n.successViewTickets),
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorCard(
          message: context.l10n.successPaymentLoadFailed,
          onRetry: () => ref.invalidate(purchaseHistoryDetailProvider(id)),
        ),
      ),
    );
  }
}

class _FullPageState extends StatelessWidget {
  const _FullPageState({
    required this.icon,
    required this.title,
    required this.message,
    this.iconColor,
    this.footer = const [],
    this.loading = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color? iconColor;
  final List<Widget> footer;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final color = iconColor ?? Theme.of(context).colorScheme.primary;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      CircleAvatar(
                        radius: 42,
                        backgroundColor: color.withValues(alpha: 0.12),
                        child: Icon(icon, size: 42, color: color),
                      ),
                      const SizedBox(height: 18),
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: Theme.of(context)
                            .textTheme
                            .headlineSmall
                            ?.copyWith(fontWeight: FontWeight.w900),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        message,
                        textAlign: TextAlign.center,
                        style: const TextStyle(height: 1.45),
                      ),
                      if (loading) ...[
                        const SizedBox(height: 18),
                        const CircularProgressIndicator(),
                      ],
                      if (footer.isNotEmpty) ...[
                        const SizedBox(height: 18),
                        for (final item in footer)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 10),
                            child: item,
                          ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CountdownGrid extends StatelessWidget {
  const _CountdownGrid({required this.remaining});

  final Duration remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final safe = remaining.isNegative ? Duration.zero : remaining;
    final days = safe.inDays;
    final hours = safe.inHours.remainder(24);
    final minutes = safe.inMinutes.remainder(60);
    final seconds = safe.inSeconds.remainder(60);
    final items = [
      (l10n.countdownDay, days),
      (l10n.countdownHour, hours),
      (l10n.countdownMinute, minutes),
      (l10n.countdownSecond, seconds),
    ];
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      childAspectRatio: 0.95,
      children: [
        for (final item in items)
          DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  item.$2.toString().padLeft(2, '0'),
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(fontWeight: FontWeight.w900),
                ),
                Text(item.$1),
              ],
            ),
          ),
      ],
    );
  }
}

class _InfoPanel extends StatelessWidget {
  const _InfoPanel({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(label, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 4),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _ReceiptRow extends StatelessWidget {
  const _ReceiptRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(message, textAlign: TextAlign.center),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
