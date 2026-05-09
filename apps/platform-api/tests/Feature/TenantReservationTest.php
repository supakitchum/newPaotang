<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class TenantReservationTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_TenantReservation_list_and_cancel_are_permissioned_scoped_idempotent_and_release_stock(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_admin_res', 'ten_admin_res', 'admin-res.newpaotang.test');
        $this->insertActivePartnerTenantWithDomain('par_admin_other', 'ten_admin_other', 'admin-other.newpaotang.test');
        $this->insertGame('gam_admin_res', 'open');
        $localIds = $this->syncAllocatedStockToLocal('par_admin_res', 'ten_admin_res', 'gam_admin_res', 1, 'alloc-admin-res', 777770);
        $customerToken = $this->issueCustomerToken('ten_admin_res', 'cus_admin_res');

        $reservation = $this->withToken($customerToken)
            ->postJson('http://admin-res.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_admin_res',
                'local_stock_item_ids' => [$localIds[0]],
            ], [
                'Idempotency-Key' => 'admin-reserve',
            ])
            ->assertCreated()
            ->json();

        $limited = $this->createTenantSession('ten_admin_res', 'par_admin_res', ['stock.view'], 'adm_res_limited', 'res-limited@example.test');
        $this->withToken($limited['access_token'])
            ->getJson('/api/v1/admin/tenant/reservations', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $viewer = $this->createTenantSession('ten_admin_res', 'par_admin_res', ['reservation.view'], 'adm_res_view', 'res-view@example.test');
        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/reservations?status=active&customer_id=cus_admin_res', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $reservation['id'])
            ->assertJsonPath('data.0.customer_id', 'cus_admin_res');

        $canceller = $this->createTenantSession(
            'ten_admin_res',
            'par_admin_res',
            ['reservation.cancel'],
            'adm_res_cancel',
            'res-cancel@example.test',
        );

        $this->withToken($canceller['access_token'])
            ->postJson('/api/v1/admin/tenant/reservations/'.$reservation['id'].'/cancel', [
                'reason' => 'customer request',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $otherAdmin = $this->createTenantSession(
            'ten_admin_other',
            'par_admin_other',
            ['reservation.cancel'],
            'adm_res_other',
            'res-other@example.test',
        );

        $this->withToken($otherAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/reservations/'.$reservation['id'].'/cancel', [
                'reason' => 'wrong tenant',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_other',
                'Idempotency-Key' => 'other-cancel',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $cancelled = $this->withToken($canceller['access_token'])
            ->postJson('/api/v1/admin/tenant/reservations/'.$reservation['id'].'/cancel', [
                'reason' => 'customer request',
                'api_secret' => 'redact-admin',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
                'Idempotency-Key' => 'tenant-res-cancel',
                'X-Request-Id' => 'req-tenant-res-cancel',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'cancelled')
            ->json();

        $this->assertSame($reservation['id'], $cancelled['id']);
        $this->assertDatabaseHas('local_stock_items', [
            'id' => $localIds[0],
            'tenant_id' => 'ten_admin_res',
            'status' => 'available',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'reservation.released.v1',
            'aggregate_id' => $reservation['id'],
            'idempotency_key' => 'tenant-res-cancel',
            'correlation_id' => 'req-tenant-res-cancel',
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_admin_res',
            'action' => 'reservation.cancelled',
            'target_id' => $reservation['id'],
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('target_id', $reservation['id'])
            ->where('action', 'reservation.cancelled')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['api_secret']);

        $replay = $this->withToken($canceller['access_token'])
            ->postJson('/api/v1/admin/tenant/reservations/'.$reservation['id'].'/cancel', [
                'reason' => 'customer request',
                'api_secret' => 'redact-admin',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
                'Idempotency-Key' => 'tenant-res-cancel',
            ])
            ->assertOk()
            ->json();

        $this->assertSame($reservation['id'], $replay['id']);
        $this->assertSame(1, DB::table('stock_reservations')->where('id', $reservation['id'])->where('status', 'cancelled')->count());
    }
}
