<?php

namespace Tests\Feature;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class AffiliateProductionPreflightCommandTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_pre_and_post_gates_pass_for_reconciled_affiliate_data(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-clean');
        $this->insertM8AffiliateGraph($world, 'affiliate-preflight-clean', 500);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);

        $this->assertSame(0, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'pre',
            '--json' => true,
        ]));
        $pre = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $this->assertTrue($pre['read_only']);
        $this->assertTrue($pre['passed']);
        $this->assertSame(0, $pre['blocker_count']);

        $this->assertSame(0, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'post',
            '--json' => true,
        ]));
        $post = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $this->assertTrue($post['passed']);
        $this->assertSame('post', $post['phase']);
    }

    public function test_gate_blocks_refunded_commission_without_reversal(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-refund');
        $this->insertM8AffiliateGraph($world, 'affiliate-preflight-refund', 600);
        app(GrowthService::class)->calculateCommissions($world['order_id'], $world['tenant_id']);
        DB::table('orders')->where('id', $world['order_id'])->update([
            'status' => 'refunded',
            'payment_status' => 'refunded',
            'refunded_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'pre',
            '--json' => true,
        ]));
        $payload = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $check = collect($payload['checks'])->firstWhere('key', 'refunded_commissions_without_reversal');

        $this->assertFalse($payload['passed']);
        $this->assertSame(1, $check['count']);
        $this->assertSame('blocker', $check['severity']);
    }

    public function test_gate_requires_explicit_finance_ack_for_legacy_external_approval(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-legacy-external');
        $graph = $this->insertM8AffiliateGraph($world, 'affiliate-preflight-legacy-external', 700);
        DB::table('affiliate_payouts')->insert([
            'id' => 'apo_preflight_legacy',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'status' => 'approved',
            'payout_method' => 'bank_transfer',
            'amount' => 700,
            'currency' => 'THB',
            'bank_account_json' => json_encode([
                'bank_name' => 'Test Bank',
                'account_number' => '1234567890',
            ], JSON_THROW_ON_ERROR),
            'admin_note' => null,
            'idempotency_key' => 'affiliate-preflight-legacy',
            'payload_hash' => hash('sha256', 'affiliate-preflight-legacy'),
            'requested_by_admin_id' => null,
            'approved_by_admin_id' => null,
            'approved_at' => now(),
            'wallet_id' => null,
            'payout_ledger_id' => null,
            'payment_reference' => null,
            'paid_by_admin_id' => null,
            'paid_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'pre',
            '--json' => true,
        ]));
        $this->assertSame(0, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'pre',
            '--ack-legacy-external-approved' => true,
            '--json' => true,
        ]));
        $acknowledged = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $check = collect($acknowledged['checks'])->firstWhere('key', 'legacy_external_approved_payouts');
        $this->assertSame('info', $check['severity']);
        $this->assertSame(1, $check['count']);
    }

    public function test_post_gate_blocks_active_payment_provider_without_webhook_secret(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-webhook');
        DB::table('tenant_payment_provider_connections')->insert([
            'id' => 'tpc_preflight_webhook',
            'tenant_id' => $world['tenant_id'],
            'provider' => 'provider_preflight',
            'status' => 'active',
            'api_key_encrypted' => Crypt::encryptString('provider-api-key'),
            'webhook_secret_encrypted' => null,
            'verified_at' => now(),
            'last_tested_at' => now(),
            'last_test_status' => 'ok',
            'last_error' => null,
            'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'post',
            '--json' => true,
        ]));
        $payload = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $check = collect($payload['checks'])->firstWhere('key', 'active_payment_providers_without_webhook_secret');

        $this->assertFalse($payload['passed']);
        $this->assertSame('blocker', $check['severity']);
        $this->assertSame(1, $check['count']);
    }

    public function test_post_gate_blocks_refunded_order_without_immutable_refund_evidence(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-refund-evidence');
        DB::table('orders')->where('id', $world['order_id'])->update([
            'status' => 'refunded',
            'payment_status' => 'refunded',
            'refunded_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'post',
            '--json' => true,
        ]));
        $payload = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $check = collect($payload['checks'])->firstWhere('key', 'refunded_orders_without_evidence');

        $this->assertFalse($payload['passed']);
        $this->assertSame('blocker', $check['severity']);
        $this->assertSame(1, $check['count']);
    }

    public function test_post_gate_blocks_plaintext_and_undecryptable_bank_payloads(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-bank-encryption');
        $graph = $this->insertM8AffiliateGraph(
            $world,
            'affiliate-preflight-bank-encryption',
            100,
        );
        DB::table('affiliate_accounts')->where('id', $graph['affiliate_id'])->update([
            'payout_profile_json' => json_encode([
                'bank_name' => 'Legacy Bank',
                'account_number' => '1234567890',
            ], JSON_THROW_ON_ERROR),
        ]);
        DB::table('affiliate_payouts')->insert([
            'id' => 'pyo_preflight_bad_encryption',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'status' => 'pending',
            'payout_method' => 'bank_transfer',
            'amount' => 100,
            'currency' => 'THB',
            'bank_account_json' => null,
            'bank_account_encrypted' => 'not-a-valid-laravel-ciphertext',
            'admin_note' => null,
            'idempotency_key' => 'preflight-bad-encryption',
            'payload_hash' => hash('sha256', 'preflight-bad-encryption'),
            'requested_by_admin_id' => null,
            'approved_by_admin_id' => null,
            'approved_at' => null,
            'wallet_id' => null,
            'payout_ledger_id' => null,
            'payment_reference' => null,
            'paid_by_admin_id' => null,
            'paid_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'post',
            '--json' => true,
        ]));
        $payload = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $plaintext = collect($payload['checks'])->firstWhere(
            'key',
            'legacy_plaintext_bank_payloads_after_migration',
        );
        $undecryptable = collect($payload['checks'])->firstWhere(
            'key',
            'undecryptable_bank_payloads',
        );

        $this->assertFalse($payload['passed']);
        $this->assertSame('blocker', $plaintext['severity']);
        $this->assertSame(1, $plaintext['count']);
        $this->assertSame('blocker', $undecryptable['severity']);
        $this->assertSame(1, $undecryptable['count']);
    }

    public function test_post_gate_blocks_bank_transfer_without_complete_encrypted_snapshot(): void
    {
        $world = $this->prepareM8World('affiliate-preflight-bank-snapshot');
        $graph = $this->insertM8AffiliateGraph(
            $world,
            'affiliate-preflight-bank-snapshot',
            100,
        );
        DB::table('affiliate_payouts')->insert([
            'id' => 'pyo_preflight_missing_snapshot',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'status' => 'pending',
            'payout_method' => 'bank_transfer',
            'amount' => 100,
            'currency' => 'THB',
            'bank_account_json' => null,
            'bank_account_encrypted' => null,
            'admin_note' => null,
            'idempotency_key' => 'preflight-missing-snapshot',
            'payload_hash' => hash('sha256', 'preflight-missing-snapshot'),
            'requested_by_admin_id' => null,
            'approved_by_admin_id' => null,
            'approved_at' => null,
            'wallet_id' => null,
            'payout_ledger_id' => null,
            'payment_reference' => null,
            'paid_by_admin_id' => null,
            'paid_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->assertSame(1, Artisan::call('affiliate:production-preflight', [
            '--phase' => 'post',
            '--json' => true,
        ]));
        $payload = json_decode(trim(Artisan::output()), true, flags: JSON_THROW_ON_ERROR);
        $check = collect($payload['checks'])->firstWhere(
            'key',
            'invalid_bank_transfer_snapshots',
        );

        $this->assertFalse($payload['passed']);
        $this->assertSame('blocker', $check['severity']);
        $this->assertSame(1, $check['count']);
    }
}
