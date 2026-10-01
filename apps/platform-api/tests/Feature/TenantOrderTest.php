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
                'status' => 'refunded',
                'payment_status' => 'refunded',
                'admin_note' => 'attempted lifecycle bypass',
                'reason' => 'must use refund endpoint',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-update-lifecycle-bypass',
            ])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.status.0',
                'The status field cannot be updated directly. Use the dedicated order lifecycle endpoint.',
            )
            ->assertJsonPath(
                'error.details.fields.payment_status.0',
                'The payment_status field cannot be updated directly. Use the dedicated order lifecycle endpoint.',
            );

        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'status' => 'paid',
            'payment_status' => 'paid',
        ]);

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
            ->postJson('/api/v1/admin/tenant/orders/'.$order['id'].'/cancel', [
                'reason' => 'paid orders must not bypass refund evidence',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-cancel-paid-blocked',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');

        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'status' => 'paid',
            'payment_status' => 'paid',
        ]);
        $this->assertDatabaseCount('order_refunds', 0);

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

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$order['id'].'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'reason' => 'customer refund duplicate request',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_tenant_order',
                'Idempotency-Key' => 'order-refund-second-key',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'refunded');

        $this->assertSame(3, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());
        $refund = DB::table('order_refunds')->where('order_id', $order['id'])->first();
        $this->assertNotNull($refund);
        $this->assertSame('wallet_refund', $refund->method);
        $this->assertNotNull($refund->wallet_ledger_id);
        $this->assertNull($refund->external_reference);
        $this->assertDatabaseHas('wallet_ledger', [
            'id' => $refund->wallet_ledger_id,
            'reference_type' => 'order_refund',
            'reference_id' => $order['id'],
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_tenant_order',
            'action' => 'order.refunded',
            'target_id' => $order['id'],
        ]);
    }

    public function test_External_order_refund_requires_unique_recorded_evidence_before_status_changes(): void
    {
        $world = $this->prepareReservedCart(
            'par_external_refund',
            'ten_external_refund',
            'external-refund.m5.test',
            'gam_external_refund',
            '0805006200',
            760001,
        );
        $manager = $this->tenantAdmin($world, ['order.view', 'order.cancel', 'order.refund'], 'external-refund');
        $orderId = 'ord_external_refund';
        $paymentId = 'pay_external_refund';
        $now = now();

        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['auth']['user']['id'],
            'reservation_id' => $world['reservation']['id'],
            'game_id' => $world['game_id'],
            'wallet_id' => null,
            'payment_method' => 'external_payment',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 8000,
            'currency' => 'THB',
            'reference' => 'external-refund-order',
            'admin_note' => null,
            'idempotency_key' => 'external-refund-order',
            'payload_hash' => hash('sha256', 'external-refund-order'),
            'paid_at' => $now,
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        DB::table('payments')->insert([
            'id' => $paymentId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['auth']['user']['id'],
            'order_id' => $orderId,
            'provider' => 'provider_test',
            'status' => 'succeeded',
            'amount' => 8000,
            'currency' => 'THB',
            'reference' => 'external-refund-payment',
            'redirect_url' => null,
            'idempotency_key' => 'external-refund-payment',
            'payload_hash' => hash('sha256', 'external-refund-payment'),
            'provider_event_id' => 'evt_external_refund',
            'provider_reference' => 'provider_external_refund',
            'provider_payload_json' => json_encode(['source' => 'signed_webhook'], JSON_THROW_ON_ERROR),
            'paid_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
            'Idempotency-Key' => 'external-refund-missing-reference',
        ];
        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$orderId.'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'method' => 'manual_refund',
                'reason' => 'manual provider refund',
            ], $headers)
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.refund_reference.0',
                'The refund_reference field is required for an external refund.',
            );

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$orderId.'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'method' => 'wallet_refund',
                'reason' => 'invalid method for external payment',
            ], [
                ...$headers,
                'Idempotency-Key' => 'external-refund-invalid-method',
            ])
            ->assertUnprocessable();

        $this->assertDatabaseHas('orders', [
            'id' => $orderId,
            'status' => 'paid',
            'payment_status' => 'paid',
        ]);
        $this->assertDatabaseMissing('order_refunds', ['order_id' => $orderId]);

        DB::table('payments')->where('id', $paymentId)->update([
            'status' => 'pending',
            'updated_at' => now(),
        ]);
        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$orderId.'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'method' => 'original_payment',
                'refund_reference' => 'rfnd_provider_pending',
                'reason' => 'payment has not settled',
            ], [
                ...$headers,
                'Idempotency-Key' => 'external-refund-pending-payment',
            ])
            ->assertConflict();
        $this->assertDatabaseMissing('order_refunds', ['order_id' => $orderId]);
        DB::table('payments')->where('id', $paymentId)->update([
            'status' => 'succeeded',
            'updated_at' => now(),
        ]);

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$orderId.'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'method' => 'original_payment',
                'refund_reference' => 'rfnd_provider_0001',
                'reason' => 'provider refund confirmed',
            ], [
                ...$headers,
                'Idempotency-Key' => 'external-refund-confirmed',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'refunded')
            ->assertJsonPath('payment_status', 'refunded');

        $this->assertDatabaseHas('order_refunds', [
            'tenant_id' => $world['tenant_id'],
            'order_id' => $orderId,
            'payment_id' => $paymentId,
            'method' => 'original_payment',
            'amount' => 8000,
            'currency' => 'THB',
            'external_reference' => 'rfnd_provider_0001',
            'wallet_ledger_id' => null,
        ]);
        $this->assertDatabaseHas('payments', [
            'id' => $paymentId,
            'status' => 'refunded',
        ]);
        $audit = DB::table('audit_logs')
            ->where('tenant_id', $world['tenant_id'])
            ->where('action', 'order.refunded')
            ->where('target_id', $orderId)
            ->latest('created_at')
            ->first();
        $this->assertNotNull($audit);
        $auditPayload = json_decode(
            (string) $audit->payload_redacted_json,
            true,
            flags: JSON_THROW_ON_ERROR,
        );
        $this->assertSame('[REDACTED]', $auditPayload['payload']['refund_reference']);
        $this->assertStringNotContainsString(
            'rfnd_provider_0001',
            (string) $audit->payload_redacted_json,
        );

        $secondOrderId = 'ord_external_refund_second';
        $secondPaymentId = 'pay_external_refund_second';
        DB::table('orders')->insert([
            'id' => $secondOrderId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['auth']['user']['id'],
            'reservation_id' => $world['reservation']['id'],
            'game_id' => $world['game_id'],
            'wallet_id' => null,
            'payment_method' => 'external_payment',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => 8000,
            'currency' => 'THB',
            'reference' => 'external-refund-order-second',
            'admin_note' => null,
            'idempotency_key' => 'external-refund-order-second',
            'payload_hash' => hash('sha256', 'external-refund-order-second'),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('payments')->insert([
            'id' => $secondPaymentId,
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['auth']['user']['id'],
            'order_id' => $secondOrderId,
            'provider' => 'provider_test',
            'status' => 'succeeded',
            'amount' => 8000,
            'currency' => 'THB',
            'reference' => 'external-refund-payment-second',
            'redirect_url' => null,
            'idempotency_key' => 'external-refund-payment-second',
            'payload_hash' => hash('sha256', 'external-refund-payment-second'),
            'provider_event_id' => 'evt_external_refund_second',
            'provider_reference' => 'provider_external_refund_second',
            'provider_payload_json' => json_encode(['source' => 'signed_webhook'], JSON_THROW_ON_ERROR),
            'paid_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/orders/'.$secondOrderId.'/refund', [
                'amount' => ['amount' => 8000, 'currency' => 'THB'],
                'method' => 'original_payment',
                'refund_reference' => 'rfnd_provider_0001',
                'reason' => 'must not reuse another order refund reference',
            ], [
                ...$headers,
                'Idempotency-Key' => 'external-refund-duplicate-reference',
            ])
            ->assertConflict();
        $this->assertDatabaseMissing('order_refunds', ['order_id' => $secondOrderId]);
        $this->assertDatabaseHas('orders', [
            'id' => $secondOrderId,
            'status' => 'paid',
            'payment_status' => 'paid',
        ]);
        $this->assertDatabaseHas('payments', [
            'id' => $secondPaymentId,
            'status' => 'succeeded',
        ]);
    }
}
