<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class WalletLedgerTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_WalletLedger_admin_adjustment_is_idempotent_ledger_based_and_audited(): void
    {
        $world = $this->prepareReservedCart('par_wallet_ledger', 'ten_wallet_ledger', 'wallet-ledger.m5.test', 'gam_wallet_ledger', '0803004000', 720001);
        $admin = $this->tenantAdmin($world, ['wallet.view', 'wallet.adjust'], 'walletledger');

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/adjust', [
                'amount' => ['amount' => 5000, 'currency' => 'THB'],
                'reason' => 'QA adjustment',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_wallet_ledger',
            ])
            ->assertUnprocessable();

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/adjust', [
                'amount' => ['amount' => 5000, 'currency' => 'THB'],
                'reason' => 'QA adjustment',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_wallet_ledger',
                'Idempotency-Key' => 'wallet-adjust-main',
            ])
            ->assertOk()
            ->assertJsonPath('balance.amount', 105000);

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/adjust', [
                'amount' => ['amount' => 5000, 'currency' => 'THB'],
                'reason' => 'QA adjustment',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_wallet_ledger',
                'Idempotency-Key' => 'wallet-adjust-main',
            ])
            ->assertOk()
            ->assertJsonPath('balance.amount', 105000);

        $this->assertSame(2, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_wallet_ledger',
            'action' => 'wallet.adjusted',
            'target_id' => $world['wallet_id'],
        ]);
    }
}
