<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class TenantWalletTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_TenantWallet_list_view_ledger_and_adjust_enforce_wallet_permissions(): void
    {
        $world = $this->prepareReservedCart('par_tenant_wallet', 'ten_tenant_wallet', 'tenant-wallet.m5.test', 'gam_tenant_wallet', '0806007000', 750001);
        $viewer = $this->tenantAdmin($world, ['wallet.view'], 'walletview');
        $adjuster = $this->tenantAdmin($world, ['wallet.view', 'wallet.adjust'], 'walletadjust');
        $customerNo = $world['auth']['user']['customer_no'];
        DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->update([
            'created_at' => now()->subHour(),
            'updated_at' => now()->subHour(),
        ]);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/wallets', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['wallet_id'])
            ->assertJsonPath('data.0.customer_no', $customerNo)
            ->assertJsonPath('data.0.customer_name', 'M5 Customer');

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/wallets?customer_no='.$customerNo.'&sort_by=customer_name&sort_dir=asc', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['wallet_id']);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/ledger', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.entry_type', 'credit');

        $this->withToken($viewer['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/adjust', [
                'amount' => ['amount' => 1000, 'currency' => 'THB'],
                'reason' => 'permission test',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
                'Idempotency-Key' => 'tenant-wallet-denied',
            ])
            ->assertForbidden();

        $this->withToken($adjuster['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/adjust', [
                'transaction_type' => 'withdraw',
                'amount' => ['amount' => 1000, 'currency' => 'THB'],
                'reason' => 'manual correction',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
                'Idempotency-Key' => 'tenant-wallet-adjust',
            ])
            ->assertOk()
            ->assertJsonPath('balance.amount', 99000);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/ledger?entry_type=adjustment&sort_by=created_at&sort_dir=desc', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.reason', 'manual correction');

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/wallets/'.$world['wallet_id'].'/ledger', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.reason', 'manual correction');
    }
}
