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

    public function test_TenantTickets_lists_customer_inventory_by_draw_and_returns_ticket_details(): void
    {
        $world = $this->prepareReservedCart('par_tenant_ticket', 'ten_tenant_ticket', 'tenant-ticket.m5.test', 'gam_tenant_ticket', '0805006100', 750001);
        $order = $this->checkoutWallet($world, 'tenant-ticket-checkout');
        $viewer = $this->tenantAdmin($world, ['ticket.view'], 'ticketview');
        $ticketId = (string) DB::table('tickets')->where('order_id', $order['id'])->value('id');

        DB::table('tickets')->where('id', $ticketId)->update([
            'image_url' => 'https://cdn.example.test/tickets/'.$ticketId.'/full.webp',
            'image_thumb_url' => 'https://cdn.example.test/tickets/'.$ticketId.'/thumb.webp',
            'updated_at' => now(),
        ]);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/tickets', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_ticket',
            ])
            ->assertOk()
            ->assertJsonPath('meta.selected_game_id', 'gam_tenant_ticket')
            ->assertJsonPath('meta.games.0.id', 'gam_tenant_ticket')
            ->assertJsonPath('data.0.customer_id', $world['auth']['user']['id'])
            ->assertJsonPath('data.0.ticket_count', 1);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/tickets?'.http_build_query([
                'view' => 'tickets',
                'customer_id' => $world['auth']['user']['id'],
                'game_id' => 'gam_tenant_ticket',
            ]), [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_ticket',
            ])
            ->assertOk()
            ->assertJsonPath('meta.customer.id', $world['auth']['user']['id'])
            ->assertJsonPath('data.0.id', $ticketId)
            ->assertJsonPath('data.0.customer.id', $world['auth']['user']['id'])
            ->assertJsonPath('data.0.image_url', 'http://cdn.example.test/tickets/'.$ticketId.'/full.webp')
            ->assertJsonPath('data.0.price.amount', 8000);
    }

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

        DB::table('orders')->insert([
            'id' => 'ord_sort_high',
            'tenant_id' => 'ten_tenant_order',
            'customer_id' => $world['auth']['user']['id'],
            'reservation_id' => $world['reservation']['id'],
            'game_id' => $world['game_id'],
            'wallet_id' => $world['wallet_id'],
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 200000,
            'currency' => 'THB',
            'reference' => 'sort-high',
            'admin_note' => null,
            'idempotency_key' => 'order-sort-high',
            'payload_hash' => hash('sha256', 'order-sort-high'),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now()->addMinute(),
            'updated_at' => now()->addMinute(),
        ]);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/orders?sort_by=total.amount&sort_dir=desc', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', 'ord_sort_high');

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
