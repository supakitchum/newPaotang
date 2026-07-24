<?php

namespace Tests\Feature;

use App\Models\AffiliateAccount;
use App\Modules\Growth\Services\AffiliateTierService;
use Illuminate\Foundation\Testing\DatabaseMigrations;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class AffiliateConcurrencyTest extends TestCase
{
    use DatabaseMigrations;
    use M8GrowthFixtures;

    public function test_concurrent_payout_requests_cannot_reserve_more_than_available_balance(): void
    {
        $this->requireProcessForking();
        $world = $this->prepareM8World('affiliate-concurrent-payout');
        $tiers = app(AffiliateTierService::class)->ensureTenantTiers($world['tenant_id']);
        $affiliateId = 'aff_concurrent_payout';
        $now = now();
        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['customer_id'],
            'affiliate_program_id' => $tiers['bronze']->id,
            'code' => 'Cp1A2B',
            'name' => 'Concurrent Payout Store',
            'store_name_status' => 'approved',
            'store_name_normalized' => 'concurrent payout store',
            'store_name_approved_at' => $now,
            'store_name_change_available_at' => $now->copy()->addMonthsNoOverflow(3),
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $ruleId = (string) DB::table('commission_rules')
            ->where('tenant_id', $world['tenant_id'])
            ->where('affiliate_program_id', $tiers['bronze']->id)
            ->where('rule_type', 'per_ticket')
            ->value('id');
        DB::table('commission_transactions')->insert([
            'id' => 'cmt_concurrent_payout',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $affiliateId,
            'affiliate_attribution_id' => null,
            'order_id' => $world['order_id'],
            'commission_rule_id' => $ruleId,
            'original_commission_id' => null,
            'transaction_type' => 'commission',
            'status' => 'approved',
            'amount' => 100000,
            'ticket_count' => 1,
            'tier_code' => 'bronze',
            'commission_per_ticket_amount' => 100000,
            'currency' => 'THB',
            'idempotency_key' => 'concurrent-payout-balance',
            'payload_hash' => hash('sha256', 'concurrent-payout-balance'),
            'calculated_at' => $now,
            'approved_by_admin_id' => null,
            'approved_at' => $now,
            'metadata_json' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::beginTransaction();
        AffiliateAccount::query()->whereKey($affiliateId)->lockForUpdate()->firstOrFail();

        try {
            $results = $this->runConcurrentWorkers([
                [
                    'action' => 'payout',
                    'tenant_id' => $world['tenant_id'],
                    'customer_id' => $world['customer_id'],
                    'idempotency_key' => 'concurrent-payout-first',
                ],
                [
                    'action' => 'payout',
                    'tenant_id' => $world['tenant_id'],
                    'customer_id' => $world['customer_id'],
                    'idempotency_key' => 'concurrent-payout-second',
                ],
            ], function (): void {
                usleep(500000);
                DB::commit();
            });
        } finally {
            if (DB::transactionLevel() > 0) {
                DB::rollBack();
            }
        }

        $statuses = collect($results)->map(fn (array $result): int => (int) ($result['status'] ?? 0))->sort()->values()->all();
        $errors = collect($results)->pluck('error')->filter()->values()->all();

        $this->assertSame([0, 201], $statuses);
        $this->assertSame(['validation_failed'], $errors);
        $this->assertSame(1, DB::table('affiliate_payouts')
            ->where('affiliate_account_id', $affiliateId)
            ->where('status', 'pending')
            ->count());
        $this->assertSame(70000, (int) DB::table('affiliate_payouts')
            ->where('affiliate_account_id', $affiliateId)
            ->where('status', 'pending')
            ->sum('amount'));
    }

    public function test_concurrent_registration_reserves_a_normalized_store_name_once(): void
    {
        $this->requireProcessForking();
        $tenantId = 'ten_aff_concurrent_name';
        $host = 'affiliate-concurrent-name.test';
        $firstCustomerId = 'cus_aff_concurrent_name_1';
        $secondCustomerId = 'cus_aff_concurrent_name_2';
        $this->insertActivePartnerTenantWithDomain('par_aff_concurrent_name', $tenantId, $host);
        $this->issueCustomerToken($tenantId, $firstCustomerId);
        $this->issueCustomerToken($tenantId, $secondCustomerId);

        $results = $this->runConcurrentWorkers([
            [
                'action' => 'register',
                'tenant_id' => $tenantId,
                'customer_id' => $firstCustomerId,
                'name' => '  Café   Lucky  ',
                'idempotency_key' => 'concurrent-name-first',
            ],
            [
                'action' => 'register',
                'tenant_id' => $tenantId,
                'customer_id' => $secondCustomerId,
                'name' => "CAFE\u{0301} LUCKY",
                'idempotency_key' => 'concurrent-name-second',
            ],
        ]);

        $statuses = collect($results)->map(fn (array $result): int => (int) ($result['status'] ?? 0))->sort()->values()->all();
        $errors = collect($results)->pluck('error')->filter()->values()->all();

        $this->assertSame([0, 201], $statuses);
        $this->assertSame(['validation_failed'], $errors);
        $this->assertSame(1, DB::table('affiliate_accounts')->where('tenant_id', $tenantId)->count());
        $this->assertSame(1, DB::table('affiliate_store_name_requests')
            ->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->count());
        $this->assertSame(1, DB::table('affiliate_store_name_claims')
            ->where('tenant_id', $tenantId)
            ->where('status', 'pending')
            ->count());
    }

    public function test_concurrent_campaign_creation_cannot_schedule_overlapping_periods(): void
    {
        $this->requireProcessForking();
        $partnerId = 'par_aff_concurrent_campaign';
        $tenantId = 'ten_aff_concurrent_campaign';
        $adminId = 'adm_aff_conc_camp';
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant($partnerId, $tenantId);
        $this->createTenantSession(
            $tenantId,
            $partnerId,
            ['affiliate_tier_campaign.manage'],
            $adminId,
            'affiliate-concurrent-campaign@example.test',
        );
        $startsAt = now()->addHour()->startOfSecond()->toIso8601String();
        $endsAt = now()->addHours(2)->startOfSecond()->toIso8601String();

        $results = $this->runConcurrentWorkers([
            [
                'action' => 'campaign',
                'tenant_id' => $tenantId,
                'customer_id' => 'unused',
                'admin_id' => $adminId,
                'name' => 'Concurrent Campaign First',
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'idempotency_key' => 'concurrent-campaign-first',
            ],
            [
                'action' => 'campaign',
                'tenant_id' => $tenantId,
                'customer_id' => 'unused',
                'admin_id' => $adminId,
                'name' => 'Concurrent Campaign Second',
                'starts_at' => $startsAt,
                'ends_at' => $endsAt,
                'idempotency_key' => 'concurrent-campaign-second',
            ],
        ]);

        $statuses = collect($results)->map(fn (array $result): int => (int) ($result['status'] ?? 0))->sort()->values()->all();
        $errors = collect($results)->pluck('error')->filter()->values()->all();

        $this->assertSame([0, 201], $statuses);
        $this->assertSame(['validation_failed'], $errors);
        $this->assertSame(1, DB::table('affiliate_tier_campaigns')
            ->where('tenant_id', $tenantId)
            ->where('status', 'scheduled')
            ->count());
    }

    public function test_concurrent_bank_payouts_cannot_reuse_payment_reference(): void
    {
        $this->requireProcessForking();
        $world = $this->prepareM8World('affiliate-concurrent-payment-reference');
        $graph = $this->insertM8AffiliateGraph($world, 'concurrent-payment-reference');
        $admin = $this->m8TenantAdmin($world, ['payout.manage'], 'concurrent-payment-reference');
        $now = now();
        $bankAccount = json_encode([
            'bank_name' => 'Concurrency Bank',
            'account_name' => 'Affiliate Recipient',
            'account_number' => '9988776655',
        ], JSON_THROW_ON_ERROR);

        foreach (['one', 'two'] as $suffix) {
            DB::table('affiliate_payouts')->insert([
                'id' => 'pyo_concurrent_reference_'.$suffix,
                'tenant_id' => $world['tenant_id'],
                'affiliate_account_id' => $graph['affiliate_id'],
                'status' => 'approved',
                'payout_method' => 'bank_transfer',
                'amount' => 1000,
                'currency' => 'THB',
                'bank_account_json' => $bankAccount,
                'approved_by_admin_id' => $admin['user']['id'],
                'approved_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $results = collect($this->runConcurrentWorkers([
            [
                'action' => 'pay',
                'tenant_id' => $world['tenant_id'],
                'customer_id' => $world['customer_id'],
                'admin_id' => $admin['user']['id'],
                'payout_id' => 'pyo_concurrent_reference_one',
                'payment_reference' => 'BANK-CONCURRENT-REFERENCE',
                'idempotency_key' => 'pay-concurrent-reference-one',
            ],
            [
                'action' => 'pay',
                'tenant_id' => $world['tenant_id'],
                'customer_id' => $world['customer_id'],
                'admin_id' => $admin['user']['id'],
                'payout_id' => 'pyo_concurrent_reference_two',
                'payment_reference' => 'BANK-CONCURRENT-REFERENCE',
                'idempotency_key' => 'pay-concurrent-reference-two',
            ],
        ]));

        $this->assertSame(1, $results->filter(
            fn (array $result): bool => ($result['resource']['status'] ?? null) === 'paid',
        )->count());
        $this->assertSame(1, $results->where('error', 'validation_failed')->count());
        $this->assertSame(1, DB::table('affiliate_payouts')
            ->where('tenant_id', $world['tenant_id'])
            ->where('payment_reference', 'BANK-CONCURRENT-REFERENCE')
            ->where('status', 'paid')
            ->count());
    }

    public function test_hardening_migration_aborts_before_schema_changes_when_duplicate_accounts_exist(): void
    {
        $tenantId = 'ten_aff_duplicate_guard';
        $customerId = 'cus_aff_duplicate_guard';
        $this->insertActivePartnerTenant('par_aff_duplicate_guard', $tenantId);
        $this->issueCustomerToken($tenantId, $customerId);
        $migration = require database_path('migrations/2026_07_24_000001_harden_affiliate_financial_integrity.php');
        $migration->down();

        $now = now();
        foreach (['aff_duplicate_guard_1', 'aff_duplicate_guard_2'] as $index => $affiliateId) {
            DB::table('affiliate_accounts')->insert([
                'id' => $affiliateId,
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'affiliate_program_id' => null,
                'code' => 'Dg'.($index + 1).'A2B',
                'name' => 'Duplicate Guard '.($index + 1),
                'store_name_status' => 'pending',
                'store_name_normalized' => null,
                'store_name_approved_at' => null,
                'store_name_change_available_at' => null,
                'phone' => null,
                'email' => null,
                'status' => 'active',
                'wallet_balance_amount' => 0,
                'currency' => 'THB',
                'payout_profile_json' => null,
                'metadata_json' => null,
                'created_by_admin_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $message = null;

        try {
            $migration->up();
        } catch (RuntimeException $exception) {
            $message = $exception->getMessage();
        } finally {
            DB::table('affiliate_accounts')
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customerId)
                ->where('id', 'aff_duplicate_guard_2')
                ->delete();
        }

        $this->assertSame(
            'Cannot enforce one Affiliate account per customer: duplicate tenant/customer rows exist.',
            $message,
        );
        $this->assertFalse(Schema::hasColumn('affiliate_payouts', 'payout_ledger_id'));
        $this->assertFalse(Schema::hasTable('affiliate_tier_rate_history'));

        $migration->up();
        $this->assertTrue(Schema::hasColumn('affiliate_payouts', 'payout_ledger_id'));
        $this->assertTrue(Schema::hasTable('affiliate_tier_rate_history'));
    }

    public function test_hardening_migration_aborts_for_legacy_approved_wallet_payout_without_ledger_evidence(): void
    {
        $world = $this->prepareM8World('affiliate-wallet-payout-migration-guard');
        $graph = $this->insertM8AffiliateGraph($world, 'wallet-payout-migration-guard');
        $migration = require database_path('migrations/2026_07_24_000001_harden_affiliate_financial_integrity.php');
        $migration->down();

        DB::table('affiliate_payouts')->insert([
            'id' => 'pyo_legacy_wallet_approved',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'status' => 'approved',
            'payout_method' => 'wallet_credit',
            'amount' => 500,
            'currency' => 'THB',
            'approved_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $message = null;
        try {
            $migration->up();
        } catch (RuntimeException $exception) {
            $message = $exception->getMessage();
        } finally {
            DB::table('affiliate_payouts')
                ->where('id', 'pyo_legacy_wallet_approved')
                ->delete();
        }

        $this->assertSame(
            'Cannot harden Affiliate payouts: approved wallet-credit rows require ledger remediation.',
            $message,
        );
        $this->assertFalse(Schema::hasColumn('affiliate_payouts', 'payout_ledger_id'));
        $this->assertFalse(Schema::hasTable('affiliate_tier_rate_history'));

        $migration->up();
        $this->assertTrue(Schema::hasColumn('affiliate_payouts', 'payout_ledger_id'));
        $this->assertTrue(Schema::hasTable('affiliate_tier_rate_history'));
    }

    public function test_hardening_migration_backfills_legacy_approved_external_payouts_as_paid_evidence(): void
    {
        $world = $this->prepareM8World('affiliate-external-payout-migration');
        $graph = $this->insertM8AffiliateGraph($world, 'external-payout-migration');
        $admin = $this->m8TenantAdmin($world, ['payout.manage'], 'external-payout-migration');
        $migration = require database_path('migrations/2026_07_24_000001_harden_affiliate_financial_integrity.php');
        $migration->down();
        $approvedAt = now()->subMinute()->startOfSecond();

        $payouts = [
            'bank_transfer' => 'pyo_leg_bank_paid',
            'manual_cash' => 'pyo_leg_cash_paid',
        ];
        foreach ($payouts as $method => $id) {
            DB::table('affiliate_payouts')->insert([
                'id' => $id,
                'tenant_id' => $world['tenant_id'],
                'affiliate_account_id' => $graph['affiliate_id'],
                'status' => 'approved',
                'payout_method' => $method,
                'amount' => 500,
                'currency' => 'THB',
                'approved_by_admin_id' => $admin['user']['id'],
                'approved_at' => $approvedAt,
                'created_at' => $approvedAt,
                'updated_at' => $approvedAt,
            ]);
        }

        $migration->up();

        foreach ($payouts as $method => $id) {
            $row = DB::table('affiliate_payouts')->where('id', $id)->first();
            $this->assertSame('paid', $row->status);
            $this->assertSame('migration-20260724-approved:'.$id, $row->payment_reference);
            $this->assertSame($admin['user']['id'], $row->paid_by_admin_id);
            $this->assertNotNull($row->paid_at);
        }

        $migration->down();
        foreach ($payouts as $id) {
            $this->assertSame(
                'approved',
                DB::table('affiliate_payouts')->where('id', $id)->value('status'),
            );
        }
        $migration->up();
    }

    public function test_hardening_migration_reconstructs_effective_rates_from_tier_audit_history(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_aff_rate_migration';
        $tenantId = 'ten_aff_rate_migration';
        $this->insertActivePartnerTenant($partnerId, $tenantId);
        $admin = $this->createTenantSession(
            $tenantId,
            $partnerId,
            ['affiliate_tier.view', 'affiliate_tier.manage'],
            'adm_aff_rate_migrate',
            'affiliate-rate-migration@example.test',
        );
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $tenantId,
        ];

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/affiliate-tiers', $headers)
            ->assertOk();
        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliate-tiers/bronze', [
                'commission_per_ticket' => ['amount' => 175, 'currency' => 'THB'],
                'minimum_payout' => ['amount' => 30000, 'currency' => 'THB'],
            ], $headers + ['Idempotency-Key' => 'affiliate-rate-migration-175'])
            ->assertOk();
        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliate-tiers/bronze', [
                'commission_per_ticket' => ['amount' => 250, 'currency' => 'THB'],
                'minimum_payout' => ['amount' => 30000, 'currency' => 'THB'],
            ], $headers + ['Idempotency-Key' => 'affiliate-rate-migration-250'])
            ->assertOk();

        $programId = (string) DB::table('affiliate_programs')
            ->where('tenant_id', $tenantId)
            ->where('code', 'bronze')
            ->value('id');
        $liveHistory = DB::table('affiliate_tier_rate_history')
            ->where('tenant_id', $tenantId)
            ->where('affiliate_program_id', $programId)
            ->orderBy('effective_at')
            ->pluck('commission_per_ticket_amount')
            ->map(fn ($amount): int => (int) $amount)
            ->all();
        $this->assertSame([100, 175, 250], $liveHistory);

        $migration = require database_path('migrations/2026_07_24_000001_harden_affiliate_financial_integrity.php');
        $migration->down();
        $migration->up();

        $history = DB::table('affiliate_tier_rate_history')
            ->where('tenant_id', $tenantId)
            ->where('affiliate_program_id', $programId)
            ->orderBy('effective_at')
            ->get(['commission_per_ticket_amount', 'source']);

        $this->assertSame(
            [100, 175, 250],
            $history->pluck('commission_per_ticket_amount')->map(fn ($amount): int => (int) $amount)->all(),
        );
        $this->assertSame(
            ['migration_initial', 'migration_audit_backfill', 'migration_audit_backfill'],
            $history->pluck('source')->all(),
        );
    }

    /**
     * @param array<int, array<string, mixed>> $workers
     * @return array<int, array<string, mixed>>
     */
    private function runConcurrentWorkers(array $workers, ?callable $afterStart = null): array
    {
        $directory = sys_get_temp_dir().'/affiliate-concurrency-'.bin2hex(random_bytes(8));
        mkdir($directory, 0700, true);
        $startFile = $directory.'/start';
        $processes = [];

        foreach ($workers as $index => $worker) {
            $readyFile = $directory.'/ready-'.$index;
            $payload = base64_encode(json_encode([
                ...$worker,
                'ready_file' => $readyFile,
                'start_file' => $startFile,
            ], JSON_THROW_ON_ERROR));
            $pipes = [];
            $process = proc_open(
                [
                    PHP_BINARY,
                    base_path('tests/Support/affiliate_concurrency_worker.php'),
                    $payload,
                ],
                [
                    0 => ['pipe', 'r'],
                    1 => ['pipe', 'w'],
                    2 => ['pipe', 'w'],
                ],
                $pipes,
                base_path(),
            );
            if (! is_resource($process)) {
                throw new RuntimeException('Unable to start Affiliate concurrency worker.');
            }

            fclose($pipes[0]);
            $processes[$index] = [
                'process' => $process,
                'pipes' => $pipes,
                'ready_file' => $readyFile,
            ];
        }

        $readyDeadline = microtime(true) + 15;
        while (collect($processes)->contains(fn (array $worker): bool => ! is_file($worker['ready_file']))) {
            if (microtime(true) >= $readyDeadline) {
                throw new RuntimeException('Affiliate concurrency workers did not become ready.');
            }
            usleep(10000);
        }

        touch($startFile);
        if ($afterStart !== null) {
            $afterStart();
        }

        $results = [];
        try {
            foreach ($processes as $index => $worker) {
                $stdout = stream_get_contents($worker['pipes'][1]);
                $stderr = stream_get_contents($worker['pipes'][2]);
                fclose($worker['pipes'][1]);
                fclose($worker['pipes'][2]);
                $status = proc_close($worker['process']);
                $this->assertSame(0, $status, trim($stderr) === '' ? 'Worker failed.' : trim($stderr));
                $results[$index] = (array) json_decode($stdout, true, 512, JSON_THROW_ON_ERROR);
            }
        } finally {
            foreach ($processes as $worker) {
                if (is_resource($worker['process'])) {
                    proc_terminate($worker['process']);
                }
            }
            foreach (glob($directory.'/*') ?: [] as $file) {
                unlink($file);
            }
            rmdir($directory);
        }

        ksort($results);

        return array_values($results);
    }

    private function requireProcessForking(): void
    {
        if (! function_exists('proc_open')) {
            $this->markTestSkipped('The proc_open function is required for Affiliate concurrency tests.');
        }
    }
}
