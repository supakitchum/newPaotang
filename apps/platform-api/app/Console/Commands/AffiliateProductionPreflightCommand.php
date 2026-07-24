<?php

namespace App\Console\Commands;

use App\Support\EncryptedJsonPayload;
use Illuminate\Console\Command;
use Illuminate\Database\Query\Builder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

class AffiliateProductionPreflightCommand extends Command
{
    protected $signature = 'affiliate:production-preflight
        {--phase=pre : Gate phase: pre or post}
        {--ack-legacy-external-approved : Confirm finance approved legacy external approved payouts as paid}
        {--json : Emit machine-readable JSON}';

    protected $description = 'Run read-only Affiliate production data-integrity gates.';

    public function handle(): int
    {
        $phase = strtolower(trim((string) $this->option('phase')));
        if (! in_array($phase, ['pre', 'post'], true)) {
            $this->error('The --phase option must be pre or post.');

            return self::INVALID;
        }

        $checks = $this->baseChecks();
        if ($phase === 'post') {
            $checks = [...$checks, ...$this->postMigrationChecks()];
        }

        $database = (string) DB::connection()->getDatabaseName();
        $blockers = count(array_filter(
            $checks,
            static fn (array $check): bool => $check['severity'] === 'blocker' && $check['count'] > 0,
        ));
        $payload = [
            'database' => $database,
            'phase' => $phase,
            'read_only' => true,
            'passed' => $blockers === 0,
            'blocker_count' => $blockers,
            'checks' => $checks,
        ];

        if ((bool) $this->option('json')) {
            $this->line(json_encode($payload, JSON_THROW_ON_ERROR | JSON_UNESCAPED_SLASHES));
        } else {
            $this->info('Affiliate production preflight (read-only)');
            $this->line('Database: '.$database.' | Phase: '.$phase);
            $this->newLine();
            $this->table(
                ['Check', 'Severity', 'Count', 'Result'],
                array_map(static fn (array $check): array => [
                    $check['key'],
                    $check['severity'],
                    $check['count'],
                    $check['count'] === 0 || $check['severity'] !== 'blocker' ? 'PASS' : 'BLOCK',
                ], $checks),
            );

            foreach ($checks as $check) {
                if ($check['count'] > 0 && $check['message'] !== '') {
                    $this->line(sprintf('[%s] %s', strtoupper($check['severity']), $check['message']));
                }
            }
        }

        return $blockers === 0 ? self::SUCCESS : self::FAILURE;
    }

    /**
     * @return array<int, array{key: string, severity: string, count: int, message: string}>
     */
    private function baseChecks(): array
    {
        $required = [
            'affiliate_accounts',
            'affiliate_attributions',
            'affiliate_programs',
            'affiliate_tier_campaigns',
            'affiliate_payouts',
            'commission_rules',
            'commission_transactions',
            'customers',
            'orders',
        ];
        $missingTables = array_values(array_filter(
            $required,
            static fn (string $table): bool => ! Schema::hasTable($table),
        ));
        if ($missingTables !== []) {
            return [[
                'key' => 'required_tables',
                'severity' => 'blocker',
                'count' => count($missingTables),
                'message' => 'Missing tables: '.implode(', ', $missingTables),
            ]];
        }

        $duplicateAccounts = DB::query()
            ->fromSub(
                DB::table('affiliate_accounts')
                    ->select(['tenant_id', 'customer_id'])
                    ->whereNotNull('customer_id')
                    ->groupBy('tenant_id', 'customer_id')
                    ->havingRaw('COUNT(*) > 1'),
                'duplicate_affiliate_accounts',
            )
            ->count();
        $approvedWallet = DB::table('affiliate_payouts')
            ->where('status', 'approved')
            ->where('payout_method', 'wallet_credit')
            ->count();
        $approvedExternalQuery = DB::table('affiliate_payouts')
            ->where('status', 'approved')
            ->whereIn('payout_method', ['bank_transfer', 'manual_cash']);
        $approvedExternal = (clone $approvedExternalQuery)->count();
        $approvedExternalAmount = (int) ((clone $approvedExternalQuery)->sum('amount') ?? 0);
        $externalAcknowledged = (bool) $this->option('ack-legacy-external-approved');
        $overlappingCampaigns = DB::table('affiliate_tier_campaigns as a')
            ->join('affiliate_tier_campaigns as b', function ($join): void {
                $join->on('b.tenant_id', '=', 'a.tenant_id')
                    ->whereColumn('b.id', '>', 'a.id')
                    ->whereColumn('b.starts_at', '<', 'a.ends_at')
                    ->whereColumn('b.ends_at', '>', 'a.starts_at');
            })
            ->whereIn('a.status', ['scheduled', 'active'])
            ->whereIn('b.status', ['scheduled', 'active'])
            ->count();
        $postPaymentAttributions = DB::table('affiliate_attributions as attribution')
            ->join('orders', function ($join): void {
                $join->on('orders.id', '=', 'attribution.order_id')
                    ->on('orders.tenant_id', '=', 'attribution.tenant_id');
            })
            ->whereIn('attribution.status', ['pending', 'converted'])
            ->whereRaw(
                'COALESCE(attribution.attributed_at, attribution.created_at) > COALESCE(orders.paid_at, orders.created_at)',
            )
            ->count();
        $missingRefundReversals = DB::table('commission_transactions as commission')
            ->join('orders', function ($join): void {
                $join->on('orders.id', '=', 'commission.order_id')
                    ->on('orders.tenant_id', '=', 'commission.tenant_id');
            })
            ->where('commission.transaction_type', 'commission')
            ->where(function ($query): void {
                $query->where('orders.payment_status', 'refunded')->orWhere('orders.status', 'refunded');
            })
            ->whereNotExists(function ($query): void {
                $query->selectRaw('1')
                    ->from('commission_transactions as reversal')
                    ->whereColumn('reversal.tenant_id', 'commission.tenant_id')
                    ->whereColumn('reversal.original_commission_id', 'commission.id')
                    ->where('reversal.transaction_type', 'reversal');
            })
            ->count();
        $invalidCommissionArithmetic = 0;
        if (
            Schema::hasColumn('commission_transactions', 'ticket_count')
            && Schema::hasColumn('commission_transactions', 'commission_per_ticket_amount')
        ) {
            $invalidCommissionArithmetic = DB::table('commission_transactions')
                ->where('transaction_type', 'commission')
                ->where(function ($query): void {
                    $query
                        ->whereNull('ticket_count')
                        ->orWhereNull('commission_per_ticket_amount')
                        ->orWhere('ticket_count', '<=', 0)
                        ->orWhere('commission_per_ticket_amount', '<=', 0)
                        ->orWhereRaw('amount <> ticket_count * commission_per_ticket_amount');
                })
                ->count();
        }
        $invalidTierRuleCardinality = DB::query()
            ->fromSub($this->tierRuleCardinalityQuery(), 'invalid_tier_rules')
            ->count();
        $commissionBacklog = DB::table('orders')
            ->where(function ($query): void {
                $query->where('orders.status', 'paid')->orWhere('orders.payment_status', 'paid');
            })
            ->whereExists(function ($query): void {
                $query->selectRaw('1')
                    ->from('affiliate_attributions')
                    ->whereColumn('affiliate_attributions.tenant_id', 'orders.tenant_id')
                    ->where('affiliate_attributions.status', 'pending')
                    ->where(function ($candidate): void {
                        $candidate
                            ->whereColumn('affiliate_attributions.order_id', 'orders.id')
                            ->orWhere(function ($unbound): void {
                                $unbound
                                    ->whereNull('affiliate_attributions.order_id')
                                    ->whereColumn('affiliate_attributions.customer_id', 'orders.customer_id');
                            });
                    })
                    ->whereRaw(
                        'COALESCE(affiliate_attributions.attributed_at, affiliate_attributions.created_at) <= COALESCE(orders.paid_at, orders.created_at)',
                    );
            })
            ->count();
        $legacyRefundedOrders = DB::table('orders')
            ->where(function ($query): void {
                $query->where('status', 'refunded')->orWhere('payment_status', 'refunded');
            })
            ->count();
        $legacyPlaintextBankPayloads = $this->legacyPlaintextBankPayloadCount();

        return [
            $this->check('duplicate_affiliate_accounts', 'blocker', $duplicateAccounts, 'Resolve duplicate tenant/customer Affiliate accounts before migration.'),
            $this->check('approved_wallet_without_ledger_evidence', 'blocker', $approvedWallet, 'Reconcile approved wallet payouts before migration.'),
            $this->check(
                'legacy_external_approved_payouts',
                $externalAcknowledged ? 'info' : 'blocker',
                $approvedExternal,
                $approvedExternal === 0
                    ? ''
                    : sprintf(
                        '%d legacy external approved payouts (%d minor units) require finance sign-off%s.',
                        $approvedExternal,
                        $approvedExternalAmount,
                        $externalAcknowledged ? ' and were acknowledged' : '',
                    ),
            ),
            $this->check('overlapping_tier_campaigns', 'blocker', $overlappingCampaigns, 'Resolve overlapping scheduled/active Tier campaigns.'),
            $this->check('post_payment_attributions', 'blocker', $postPaymentAttributions, 'Attributions created after payment must not receive commission.'),
            $this->check('refunded_commissions_without_reversal', 'blocker', $missingRefundReversals, 'Reconcile refunded orders that still retain commission.'),
            $this->check('invalid_commission_arithmetic', 'blocker', $invalidCommissionArithmetic, 'Commission snapshots must equal ticket count multiplied by per-ticket rate.'),
            $this->check('invalid_active_tier_rule_cardinality', 'blocker', $invalidTierRuleCardinality, 'Each active Tier must have exactly one active tenant-wide per-ticket rule.'),
            $this->check('eligible_commission_backlog', 'info', $commissionBacklog, 'Pending eligible orders remain for the Affiliate commission worker.'),
            $this->check('legacy_refunded_orders_requiring_evidence', 'info', $legacyRefundedOrders, 'Legacy refunded orders require finance reconciliation after the order_refunds evidence table is created.'),
            $this->check('legacy_plaintext_bank_payloads', 'info', $legacyPlaintextBankPayloads, 'Sensitive Affiliate/customer bank payloads remain in legacy plaintext columns and must be encrypted by migration.'),
        ];
    }

    /**
     * @return array<int, array{key: string, severity: string, count: int, message: string}>
     */
    private function postMigrationChecks(): array
    {
        $requiredColumns = [
            'wallet_id',
            'payout_ledger_id',
            'payment_reference',
            'paid_by_admin_id',
            'paid_at',
        ];
        $missingColumns = array_values(array_filter(
            $requiredColumns,
            static fn (string $column): bool => ! Schema::hasColumn('affiliate_payouts', $column),
        ));
        $missingWebhookColumns = array_values(array_filter(
            ['webhook_secret_encrypted'],
            static fn (string $column): bool => ! Schema::hasColumn('tenant_payment_provider_connections', $column),
        ));
        $missingBankEncryptionColumns = array_values(array_filter(
            [
                'affiliate_payouts.bank_account_encrypted',
                'affiliate_accounts.payout_profile_encrypted',
                'customers.reward_payout_bank_account_encrypted',
            ],
            static function (string $qualifiedColumn): bool {
                [$table, $column] = explode('.', $qualifiedColumn, 2);

                return ! Schema::hasColumn($table, $column);
            },
        ));
        $schemaChecks = [];
        if ($missingColumns !== []) {
            $schemaChecks[] = [
                'key' => 'payout_evidence_columns',
                'severity' => 'blocker',
                'count' => count($missingColumns),
                'message' => 'Missing Affiliate payout evidence columns: '.implode(', ', $missingColumns),
            ];
        }
        if ($missingWebhookColumns !== []) {
            $schemaChecks[] = [
                'key' => 'payment_webhook_auth_columns',
                'severity' => 'blocker',
                'count' => count($missingWebhookColumns),
                'message' => 'Missing payment webhook authentication columns: '.implode(', ', $missingWebhookColumns),
            ];
        }
        if ($missingBankEncryptionColumns !== []) {
            $schemaChecks[] = [
                'key' => 'affiliate_bank_encryption_columns',
                'severity' => 'blocker',
                'count' => count($missingBankEncryptionColumns),
                'message' => 'Missing encrypted bank payload columns: '.implode(', ', $missingBankEncryptionColumns),
            ];
        }
        if (! Schema::hasTable('order_refunds')) {
            $schemaChecks[] = [
                'key' => 'order_refund_evidence_table',
                'severity' => 'blocker',
                'count' => 1,
                'message' => 'Missing immutable order_refunds evidence table.',
            ];
        }
        if ($schemaChecks !== []) {
            return $schemaChecks;
        }

        $paidWithoutEvidence = DB::table('affiliate_payouts')
            ->where('status', 'paid')
            ->where(function ($query): void {
                $query
                    ->whereNull('paid_at')
                    ->orWhereNull('payment_reference')
                    ->orWhere(function ($wallet): void {
                        $wallet
                            ->where('payout_method', 'wallet_credit')
                            ->whereNull('payout_ledger_id');
                    });
            })
            ->count();
        $walletLedgerMismatch = DB::table('affiliate_payouts as payout')
            ->leftJoin('wallet_ledger as ledger', 'ledger.id', '=', 'payout.payout_ledger_id')
            ->where('payout.status', 'paid')
            ->where('payout.payout_method', 'wallet_credit')
            ->where(function ($query): void {
                $query
                    ->whereNull('ledger.id')
                    ->orWhere('ledger.entry_type', '!=', 'credit')
                    ->orWhere('ledger.reference_type', '!=', 'affiliate_payout')
                    ->orWhereColumn('ledger.reference_id', '!=', 'payout.id')
                    ->orWhereColumn('ledger.amount', '!=', 'payout.amount')
                    ->orWhereColumn('ledger.currency', '!=', 'payout.currency');
            })
            ->count();
        $tierHistoryMissing = Schema::hasTable('affiliate_tier_rate_history')
            ? DB::query()
                ->fromSub(
                    DB::table('affiliate_programs as program')
                        ->leftJoin('affiliate_tier_rate_history as history', function ($join): void {
                            $join->on('history.tenant_id', '=', 'program.tenant_id')
                                ->on('history.affiliate_program_id', '=', 'program.id');
                        })
                        ->select(['program.tenant_id', 'program.id'])
                        ->whereNotNull('program.tier_rank')
                        ->groupBy('program.tenant_id', 'program.id')
                        ->havingRaw('COUNT(history.id) = 0'),
                    'affiliate_tiers_without_rate_history',
                )
                ->count()
            : DB::table('affiliate_programs')->whereNotNull('tier_rank')->count();
        $duplicatePaymentReferences = DB::query()
            ->fromSub(
                DB::table('affiliate_payouts')
                    ->select(['tenant_id', 'payout_method', 'payment_reference'])
                    ->whereNotNull('payment_reference')
                    ->groupBy('tenant_id', 'payout_method', 'payment_reference')
                    ->havingRaw('COUNT(*) > 1'),
                'duplicate_affiliate_payment_references',
            )
            ->count();
        $activePaymentProvidersWithoutWebhookSecret = DB::table('tenant_payment_provider_connections')
            ->where('status', 'active')
            ->where(function ($query): void {
                $query
                    ->whereNull('webhook_secret_encrypted')
                    ->orWhere('webhook_secret_encrypted', '');
            })
            ->count();
        $pendingPaymentsWithoutWebhookAuthentication = DB::table('payments as payment')
            ->whereIn('payment.status', ['pending', 'processing'])
            ->whereNotExists(function ($query): void {
                $query->selectRaw('1')
                    ->from('tenant_payment_provider_connections as connection')
                    ->whereColumn('connection.tenant_id', 'payment.tenant_id')
                    ->whereColumn('connection.provider', 'payment.provider')
                    ->where('connection.status', 'active')
                    ->whereNotNull('connection.webhook_secret_encrypted')
                    ->where('connection.webhook_secret_encrypted', '!=', '');
            })
            ->count();
        $refundedOrdersWithoutEvidence = DB::table('orders as orders')
            ->where(function ($query): void {
                $query->where('orders.status', 'refunded')->orWhere('orders.payment_status', 'refunded');
            })
            ->whereNotExists(function ($query): void {
                $query->selectRaw('1')
                    ->from('order_refunds as refund')
                    ->whereColumn('refund.tenant_id', 'orders.tenant_id')
                    ->whereColumn('refund.order_id', 'orders.id');
            })
            ->count();
        $walletRefundEvidenceMismatch = DB::table('order_refunds as refund')
            ->join('orders', function ($join): void {
                $join->on('orders.tenant_id', '=', 'refund.tenant_id')
                    ->on('orders.id', '=', 'refund.order_id');
            })
            ->leftJoin('wallet_ledger as ledger', 'ledger.id', '=', 'refund.wallet_ledger_id')
            ->where('refund.method', 'wallet_refund')
            ->where(function ($query): void {
                $query
                    ->where('orders.payment_method', '!=', 'wallet')
                    ->orWhereNull('refund.wallet_ledger_id')
                    ->orWhereNull('ledger.id')
                    ->orWhere('ledger.entry_type', '!=', 'reversal')
                    ->orWhere('ledger.reference_type', '!=', 'order_refund')
                    ->orWhereColumn('ledger.reference_id', '!=', 'orders.id')
                    ->orWhereColumn('ledger.amount', '!=', 'refund.amount')
                    ->orWhereColumn('ledger.currency', '!=', 'refund.currency');
            })
            ->count();
        $externalRefundEvidenceMismatch = DB::table('order_refunds as refund')
            ->join('orders', function ($join): void {
                $join->on('orders.tenant_id', '=', 'refund.tenant_id')
                    ->on('orders.id', '=', 'refund.order_id');
            })
            ->leftJoin('payments as payment', 'payment.id', '=', 'refund.payment_id')
            ->whereIn('refund.method', ['manual_refund', 'original_payment'])
            ->where(function ($query): void {
                $query
                    ->where('orders.payment_method', '!=', 'external_payment')
                    ->orWhereNull('refund.external_reference')
                    ->orWhere('refund.external_reference', '')
                    ->orWhereNull('payment.id')
                    ->orWhere('payment.status', '!=', 'refunded')
                    ->orWhereColumn('payment.amount', '!=', 'refund.amount')
                    ->orWhereColumn('payment.currency', '!=', 'refund.currency');
            })
            ->count();
        $cancelledPaidOrders = DB::table('orders')
            ->where('status', 'cancelled')
            ->whereIn('payment_status', ['paid', 'refunded'])
            ->count();
        $legacyPlaintextBankPayloads = $this->legacyPlaintextBankPayloadCount();
        $undecryptableBankPayloads = $this->undecryptableBankPayloadCount();
        $invalidBankTransferSnapshots = $this->invalidBankTransferSnapshotCount();

        return [
            $this->check('paid_payouts_without_evidence', 'blocker', $paidWithoutEvidence, 'Every paid payout requires immutable payment evidence.'),
            $this->check('wallet_payout_ledger_mismatch', 'blocker', $walletLedgerMismatch, 'Wallet payout and ledger evidence do not reconcile.'),
            $this->check('tier_rate_history_missing', 'blocker', $tierHistoryMissing, 'Every Tier requires effective-dated rate history.'),
            $this->check('duplicate_payment_references', 'blocker', $duplicatePaymentReferences, 'Payment references must be unique per tenant and payout method.'),
            $this->check('active_payment_providers_without_webhook_secret', 'blocker', $activePaymentProvidersWithoutWebhookSecret, 'Every active payment provider requires an encrypted webhook secret.'),
            $this->check('pending_payments_without_webhook_authentication', 'blocker', $pendingPaymentsWithoutWebhookAuthentication, 'Pending payments must resolve to an active provider connection with webhook authentication.'),
            $this->check('refunded_orders_without_evidence', 'blocker', $refundedOrdersWithoutEvidence, 'Every refunded order requires immutable refund evidence.'),
            $this->check('wallet_refund_evidence_mismatch', 'blocker', $walletRefundEvidenceMismatch, 'Wallet refund evidence must reconcile to one posted reversal ledger entry.'),
            $this->check('external_refund_evidence_mismatch', 'blocker', $externalRefundEvidenceMismatch, 'External refund evidence must reconcile to the refunded provider payment and external reference.'),
            $this->check('cancelled_paid_orders', 'blocker', $cancelledPaidOrders, 'Paid orders must use the refund lifecycle and cannot remain cancelled.'),
            $this->check('legacy_plaintext_bank_payloads_after_migration', 'blocker', $legacyPlaintextBankPayloads, 'Legacy plaintext bank payload columns must be empty after migration.'),
            $this->check('undecryptable_bank_payloads', 'blocker', $undecryptableBankPayloads, 'Every encrypted Affiliate/customer bank payload must decrypt with the active APP_KEY.'),
            $this->check('invalid_bank_transfer_snapshots', 'blocker', $invalidBankTransferSnapshots, 'Every Affiliate bank-transfer payout requires an encrypted bank name and account number snapshot.'),
        ];
    }

    private function legacyPlaintextBankPayloadCount(): int
    {
        $count = 0;
        foreach ($this->bankPayloadColumns() as $target) {
            if (
                ! Schema::hasTable($target['table'])
                || ! Schema::hasColumn($target['table'], $target['legacy'])
            ) {
                continue;
            }

            $count += DB::table($target['table'])
                ->whereNotNull($target['legacy'])
                ->count();
        }

        return $count;
    }

    private function undecryptableBankPayloadCount(): int
    {
        $count = 0;
        foreach ($this->bankPayloadColumns() as $target) {
            DB::table($target['table'])
                ->select(['id', $target['encrypted']])
                ->whereNotNull($target['encrypted'])
                ->where($target['encrypted'], '!=', '')
                ->orderBy('id')
                ->chunkById(250, function ($rows) use ($target, &$count): void {
                    foreach ($rows as $row) {
                        try {
                            EncryptedJsonPayload::decrypt($row->{$target['encrypted']});
                        } catch (\Throwable) {
                            $count++;
                        }
                    }
                }, 'id');
        }

        return $count;
    }

    private function invalidBankTransferSnapshotCount(): int
    {
        $count = 0;
        DB::table('affiliate_payouts')
            ->select(['id', 'bank_account_encrypted'])
            ->where('payout_method', 'bank_transfer')
            ->orderBy('id')
            ->chunkById(250, function ($rows) use (&$count): void {
                foreach ($rows as $row) {
                    try {
                        $bankAccount = EncryptedJsonPayload::decrypt($row->bank_account_encrypted);
                    } catch (\Throwable) {
                        continue;
                    }

                    if (
                        trim((string) ($bankAccount['bank_name'] ?? '')) === ''
                        || trim((string) ($bankAccount['account_number'] ?? '')) === ''
                    ) {
                        $count++;
                    }
                }
            }, 'id');

        return $count;
    }

    /**
     * @return array<int, array{table: string, legacy: string, encrypted: string}>
     */
    private function bankPayloadColumns(): array
    {
        return [
            [
                'table' => 'affiliate_payouts',
                'legacy' => 'bank_account_json',
                'encrypted' => 'bank_account_encrypted',
            ],
            [
                'table' => 'affiliate_accounts',
                'legacy' => 'payout_profile_json',
                'encrypted' => 'payout_profile_encrypted',
            ],
            [
                'table' => 'customers',
                'legacy' => 'reward_payout_bank_account_json',
                'encrypted' => 'reward_payout_bank_account_encrypted',
            ],
        ];
    }

    private function tierRuleCardinalityQuery(): Builder
    {
        return DB::table('affiliate_programs as program')
            ->leftJoin('commission_rules as rule', function ($join): void {
                $join->on('rule.tenant_id', '=', 'program.tenant_id')
                    ->on('rule.affiliate_program_id', '=', 'program.id')
                    ->whereNull('rule.affiliate_account_id')
                    ->where('rule.rule_type', '=', 'per_ticket')
                    ->where('rule.status', '=', 'active');
            })
            ->select(['program.tenant_id', 'program.id'])
            ->where('program.status', 'active')
            ->whereNotNull('program.tier_rank')
            ->groupBy('program.tenant_id', 'program.id')
            ->havingRaw('COUNT(rule.id) <> 1');
    }

    /**
     * @return array{key: string, severity: string, count: int, message: string}
     */
    private function check(string $key, string $severity, int $count, string $message): array
    {
        return [
            'key' => $key,
            'severity' => $severity,
            'count' => $count,
            'message' => $count > 0 ? $message : '',
        ];
    }
}
