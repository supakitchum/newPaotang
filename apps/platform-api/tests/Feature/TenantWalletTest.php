<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
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

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/wallets', [
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
                'amount' => ['amount' => -1000, 'currency' => 'THB'],
                'reason' => 'manual correction',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_wallet',
                'Idempotency-Key' => 'tenant-wallet-adjust',
            ])
            ->assertOk()
            ->assertJsonPath('balance.amount', 99000);
    }
}
