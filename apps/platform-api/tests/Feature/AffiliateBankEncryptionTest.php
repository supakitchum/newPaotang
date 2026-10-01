<?php

namespace Tests\Feature;

use App\Support\EncryptedJsonPayload;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class AffiliateBankEncryptionTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_sensitive_legacy_bank_payload_migration_round_trips_without_plaintext_residue(): void
    {
        $world = $this->prepareM8World('affiliate-bank-encryption');
        $graph = $this->insertM8AffiliateGraph($world, 'affiliate-bank-encryption', 100);
        $bankAccount = [
            'bank_name' => 'Encryption Test Bank',
            'account_name' => 'Affiliate Owner',
            'account_number' => '1234567890',
        ];
        $profile = ['bank_account' => $bankAccount];

        DB::table('customers')->where('id', $graph['owner_customer_id'])->update([
            'reward_payout_bank_account_json' => json_encode($bankAccount, JSON_THROW_ON_ERROR),
            'reward_payout_bank_account_encrypted' => null,
        ]);
        DB::table('affiliate_accounts')->where('id', $graph['affiliate_id'])->update([
            'payout_profile_json' => json_encode($profile, JSON_THROW_ON_ERROR),
            'payout_profile_encrypted' => null,
        ]);
        DB::table('affiliate_payouts')->insert([
            'id' => 'pyo_bank_encryption_round_trip',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => $graph['affiliate_id'],
            'status' => 'pending',
            'payout_method' => 'bank_transfer',
            'amount' => 100,
            'currency' => 'THB',
            'bank_account_json' => json_encode($bankAccount, JSON_THROW_ON_ERROR),
            'bank_account_encrypted' => null,
            'admin_note' => null,
            'idempotency_key' => 'bank-encryption-round-trip',
            'payload_hash' => hash('sha256', 'bank-encryption-round-trip'),
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

        $migration = require database_path(
            'migrations/2026_07_24_000005_encrypt_affiliate_bank_payloads.php',
        );
        $migration->up();

        $this->assertEncryptedPayload(
            'customers',
            $graph['owner_customer_id'],
            'reward_payout_bank_account_json',
            'reward_payout_bank_account_encrypted',
            $bankAccount,
        );
        $this->assertEncryptedPayload(
            'affiliate_accounts',
            $graph['affiliate_id'],
            'payout_profile_json',
            'payout_profile_encrypted',
            $profile,
        );
        $this->assertEncryptedPayload(
            'affiliate_payouts',
            'pyo_bank_encryption_round_trip',
            'bank_account_json',
            'bank_account_encrypted',
            $bankAccount,
        );

        $migration->down();

        $this->assertFalse(Schema::hasColumn('affiliate_payouts', 'bank_account_encrypted'));
        $this->assertFalse(Schema::hasColumn('affiliate_accounts', 'payout_profile_encrypted'));
        $this->assertFalse(Schema::hasColumn('customers', 'reward_payout_bank_account_encrypted'));
        $this->assertSame(
            $bankAccount,
            json_decode(
                (string) DB::table('affiliate_payouts')
                    ->where('id', 'pyo_bank_encryption_round_trip')
                    ->value('bank_account_json'),
                true,
                flags: JSON_THROW_ON_ERROR,
            ),
        );

        $migration->up();

        $this->assertEncryptedPayload(
            'affiliate_payouts',
            'pyo_bank_encryption_round_trip',
            'bank_account_json',
            'bank_account_encrypted',
            $bankAccount,
        );
    }

    /**
     * @param array<string, mixed> $expected
     */
    private function assertEncryptedPayload(
        string $table,
        string $id,
        string $legacyColumn,
        string $encryptedColumn,
        array $expected,
    ): void {
        $row = DB::table($table)->where('id', $id)->first([
            $legacyColumn,
            $encryptedColumn,
        ]);

        $this->assertNotNull($row);
        $this->assertNull($row->{$legacyColumn});
        $this->assertNotEmpty($row->{$encryptedColumn});
        $this->assertStringNotContainsString('1234567890', (string) $row->{$encryptedColumn});
        $this->assertSame($expected, EncryptedJsonPayload::decrypt($row->{$encryptedColumn}));
    }
}
