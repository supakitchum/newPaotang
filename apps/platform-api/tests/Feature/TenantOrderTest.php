<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class TenantOrderTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_TenantOrder_permissions_update_cancel_and_refund_are_idempotent_and_tenant_scoped(): void
    {
        $world = $this->prepareReservedCart('par_tenant_order', 'ten_tenant_order', 'tenant-order.m5.test', 'gam_tenant_order', '0805006000', 740001);
        $order = $this->checkoutWallet($world, 'tenant-order-checkout');
        $viewer = $this->tenantAdmin($world, ['order.view'], 'orderview');
        $manager = $this->tenantAdmin($world, ['order.view', 'order.update', 'order.cancel', 'order.refund'], 'ordermgr');

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/orders', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $order['id']);

        $this->withToken($viewer['access_token'])
            ->patchJson('/api/v1/admin/tenant/orders/'.$order['id'], [
                'status' => 'paid',
                'reason' => 'viewer should not update',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-update-denied',
            ])
            ->assertForbidden();

        $this->withToken($manager['access_token'])
            ->patchJson('/api/v1/admin/tenant/orders/'.$order['id'], [
                'admin_note' => 'checked',
                'reason' => 'ops update',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-update-main',
            ])
            ->assertOk()
            ->assertJsonPath('admin_note', 'checked');

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$order['id'].'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'reason' => 'customer refund',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-refund-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'refunded')
            ->assertJsonPath('payment_status', 'refunded');

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$order['id'].'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'reason' => 'customer refund',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-refund-main',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'refunded');

        $this->assertSame(3, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_tenant_order',
            'action' => 'order.refunded',
            'target_id' => $order['id'],
        ]);
    }
}
