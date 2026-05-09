<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class TenantTopupTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_TenantTopup_approve_reject_cancel_are_permissioned_idempotent_and_ledger_based(): void
    {
        $world = $this->prepareReservedCart('par_tenant_topup', 'ten_tenant_topup', 'tenant-topup.m5.test', 'gam_tenant_topup', '0807008000', 760001);
        $topups = [];

        foreach (['approve', 'reject', 'cancel'] as $action) {
            $topups[$action] = $this->withToken($world['auth']['token'])
                ->postJson('http://'.$world['host'].'/api/v1/customer/topups', [
                    'channel' => 'bank_transfer',
                    'amount' => 10000,
                ], [
                    'Idempotency-Key' => 'tenant-topup-'.$action,
                ])
                ->assertCreated()
                ->json();
        }

        $viewer = $this->tenantAdmin($world, ['topup.view'], 'topupview');
        $manager = $this->tenantAdmin($world, ['topup.view', 'topup.approve', 'topup.reject', 'topup.cancel'], 'topupmgr');

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/topups', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_topup',
            ])
            ->assertOk()
            ->assertJsonCount(3, 'data');

        $this->withToken($viewer['access_token'])
            ->postJson('/api/v1/admin/tenant/topups/'.$topups['approve']['id'].'/approve', [
                'reason' => 'viewer cannot approve',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_topup',
                'Idempotency-Key' => 'topup-approve-denied',
            ])
            ->assertForbidden();

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/topups/'.$topups['approve']['id'].'/approve', [
                'reason' => 'transfer verified',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_topup',
                'Idempotency-Key' => 'topup-approve-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/topups/'.$topups['approve']['id'].'/approve', [
                'reason' => 'transfer verified',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_topup',
                'Idempotency-Key' => 'topup-approve-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/topups/'.$topups['reject']['id'].'/reject', [
                'reason' => 'bad slip',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_topup',
                'Idempotency-Key' => 'topup-reject-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'rejected');

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/topups/'.$topups['cancel']['id'].'/cancel', [
                'reason' => 'customer cancelled',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_topup',
                'Idempotency-Key' => 'topup-cancel-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'cancelled');

        $this->assertSame(2, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
        $this->assertDatabaseHas('sync_outbox', [
            'tenant_id' => 'ten_tenant_topup',
            'event_type' => 'wallet.updated.v1',
            'aggregate_id' => $world['wallet_id'],
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_tenant_topup',
            'action' => 'topup.approved',
            'target_id' => $topups['approve']['id'],
        ]);
    }
}
