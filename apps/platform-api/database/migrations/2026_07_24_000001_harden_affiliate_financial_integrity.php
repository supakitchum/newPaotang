<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        $hasDuplicateCustomers = DB::table('affiliate_accounts')
            ->select(['tenant_id', 'customer_id'])
            ->whereNotNull('customer_id')
            ->groupBy('tenant_id', 'customer_id')
            ->havingRaw('COUNT(*) > 1')
            ->limit(1)
            ->exists();

        if ($hasDuplicateCustomers) {
            throw new RuntimeException(
                'Cannot enforce one Affiliate account per customer: duplicate tenant/customer rows exist.',
            );
        }

        $hasUnsettledLegacyWalletPayouts = DB::table('affiliate_payouts')
            ->where('status', 'approved')
            ->where('payout_method', 'wallet_credit')
            ->exists();
        if ($hasUnsettledLegacyWalletPayouts) {
            throw new RuntimeException(
                'Cannot harden Affiliate payouts: approved wallet-credit rows require ledger remediation.',
            );
        }

        Schema::table('affiliate_accounts', function (Blueprint $table): void {
            $table->unique(
                ['tenant_id', 'customer_id'],
                'affiliate_accounts_tenant_customer_unique',
            );
        });

        Schema::table('affiliate_payouts', function (Blueprint $table): void {
            $table->string('wallet_id', 30)->nullable()->after('bank_account_json');
            $table->string('payout_ledger_id', 30)->nullable()->after('wallet_id');
            $table->string('payment_reference', 191)->nullable()->after('payout_ledger_id');
            $table->string('paid_by_admin_id', 30)->nullable()->after('approved_by_admin_id');
            $table->timestampTz('paid_at')->nullable()->after('approved_at');

            $table->foreign('wallet_id')->references('id')->on('wallets')->nullOnDelete();
            $table->foreign('payout_ledger_id')->references('id')->on('wallet_ledger')->nullOnDelete();
            $table->foreign('paid_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->unique('payout_ledger_id', 'affiliate_payouts_ledger_unique');
            $table->unique(
                ['tenant_id', 'payout_method', 'payment_reference'],
                'affiliate_payouts_payment_reference_unique',
            );
        });

        DB::table('affiliate_payouts')
            ->where('status', 'approved')
            ->whereIn('payout_method', ['bank_transfer', 'manual_cash'])
            ->update([
                'status' => 'paid',
                'payment_reference' => DB::raw("'migration-20260724-approved:' || id"),
                'paid_by_admin_id' => DB::raw('approved_by_admin_id'),
                'paid_at' => DB::raw('COALESCE(approved_at, updated_at, created_at)'),
                'updated_at' => now(),
            ]);

        Schema::create('affiliate_tier_rate_history', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_program_id', 30);
            $table->bigInteger('commission_per_ticket_amount');
            $table->string('source')->default('tier_update');
            $table->json('metadata_json')->nullable();
            $table->timestampTz('effective_at', 6);
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_program_id')->references('id')->on('affiliate_programs')->cascadeOnDelete();
            $table->unique(
                ['tenant_id', 'affiliate_program_id', 'effective_at'],
                'affiliate_tier_rate_history_effective_unique',
            );
            $table->index(
                ['tenant_id', 'affiliate_program_id', 'effective_at'],
                'affiliate_tier_rate_history_lookup_index',
            );
        });

        $defaultRates = [
            'bronze' => 100,
            'silver' => 150,
            'gold' => 200,
            'platinum' => 250,
            'diamond' => 300,
        ];
        $now = now();
        DB::table('affiliate_programs')
            ->whereNotNull('tier_rank')
            ->orderBy('tenant_id')
            ->orderBy('id')
            ->get()
            ->each(function (object $program) use ($defaultRates, $now): void {
                $lastEffectiveAt = Carbon::parse($program->created_at ?? $now);
                $lastRate = (int) ($defaultRates[(string) $program->code]
                    ?? $program->commission_per_ticket_amount);
                $insertRate = function (
                    int $rate,
                    string $source,
                    Carbon $effectiveAt,
                    array $metadata,
                ) use ($program, $now, &$lastEffectiveAt, &$lastRate): void {
                    if ($effectiveAt->lte($lastEffectiveAt) && $source !== 'migration_initial') {
                        $effectiveAt = $lastEffectiveAt->copy()->addMicrosecond();
                    }
                    DB::table('affiliate_tier_rate_history')->insert([
                        'id' => 'arh_'.substr(sha1(implode(':', [
                            (string) $program->tenant_id,
                            (string) $program->id,
                            $source,
                            $effectiveAt->format('Y-m-d H:i:s.uP'),
                            (string) $rate,
                        ])), 0, 20),
                        'tenant_id' => $program->tenant_id,
                        'affiliate_program_id' => $program->id,
                        'commission_per_ticket_amount' => $rate,
                        'source' => $source,
                        'metadata_json' => json_encode($metadata, JSON_THROW_ON_ERROR),
                        'effective_at' => $effectiveAt->format('Y-m-d H:i:s.uP'),
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                    $lastEffectiveAt = $effectiveAt->copy();
                    $lastRate = $rate;
                };

                $insertRate(
                    $lastRate,
                    'migration_initial',
                    $lastEffectiveAt,
                    ['backfilled' => true, 'tier_code' => (string) $program->code],
                );

                DB::table('audit_logs')
                    ->where('tenant_id', $program->tenant_id)
                    ->where('action', 'affiliate.tier.update')
                    ->where('target_type', 'affiliate_program')
                    ->where('target_id', $program->id)
                    ->orderBy('created_at')
                    ->orderBy('id')
                    ->get()
                    ->each(function (object $audit) use ($insertRate, &$lastRate, $now): void {
                        $payload = json_decode((string) ($audit->payload_redacted_json ?? ''), true);
                        if (! is_array($payload)) {
                            return;
                        }
                        $rawRate = $payload['commission_per_ticket']
                            ?? $payload['commission_per_ticket_amount']
                            ?? null;
                        if (is_array($rawRate)) {
                            $rawRate = $rawRate['amount'] ?? null;
                        }
                        if (! is_numeric($rawRate) || (int) $rawRate === $lastRate) {
                            return;
                        }
                        $insertRate(
                            max(0, (int) $rawRate),
                            'migration_audit_backfill',
                            Carbon::parse($audit->created_at ?? $now),
                            ['backfilled' => true, 'audit_log_id' => (string) $audit->id],
                        );
                    });

                $currentRate = max(0, (int) $program->commission_per_ticket_amount);
                if ($currentRate !== $lastRate) {
                    $insertRate(
                        $currentRate,
                        'migration_current_snapshot',
                        $now->copy(),
                        ['backfilled' => true, 'audit_gap' => true],
                    );
                }
            });
    }

    public function down(): void
    {
        Schema::dropIfExists('affiliate_tier_rate_history');

        DB::table('affiliate_payouts')
            ->where('status', 'paid')
            ->whereIn('payout_method', ['bank_transfer', 'manual_cash'])
            ->whereNull('payout_ledger_id')
            ->whereRaw("payment_reference = 'migration-20260724-approved:' || id")
            ->update([
                'status' => 'approved',
                'payment_reference' => null,
                'paid_by_admin_id' => null,
                'paid_at' => null,
                'updated_at' => now(),
            ]);

        Schema::table('affiliate_payouts', function (Blueprint $table): void {
            $table->dropUnique('affiliate_payouts_payment_reference_unique');
            $table->dropUnique('affiliate_payouts_ledger_unique');
            $table->dropForeign(['wallet_id']);
            $table->dropForeign(['payout_ledger_id']);
            $table->dropForeign(['paid_by_admin_id']);
            $table->dropColumn([
                'wallet_id',
                'payout_ledger_id',
                'payment_reference',
                'paid_by_admin_id',
                'paid_at',
            ]);
        });

        Schema::table('affiliate_accounts', function (Blueprint $table): void {
            $table->dropUnique('affiliate_accounts_tenant_customer_unique');
        });
    }
};
