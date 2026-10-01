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
        $this->insertBaseLotteryNumbers(['777770']);
        $this->insertVirtualProfile('gam_admin_res', 1);
        $this->insertVirtualAllocation('gam_admin_res', 'par_admin_res', 'ten_admin_res', 10000, 1);
        $customerToken = $this->issueCustomerToken('ten_admin_res', 'cus_admin_res');
        $stock = $this->getJson('http://admin-res.newpaotang.test/api/v1/public/stock/search?game_id=gam_admin_res&number=777770')
            ->assertOk()
            ->json('data.0');

        $reservation = $this->withToken($customerToken)
            ->postJson('http://admin-res.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_admin_res',
                'local_stock_item_ids' => [$stock['id']],
            ], [
                'Idempotency-Key' => 'admin-reserve',
            ])
            ->assertCreated()
            ->json();
        $localStockId = $reservation['items'][0]['id'];

        $limited = $this->createTenantSession('ten_admin_res', 'par_admin_res', ['stock.view'], 'adm_res_limited', 'res-limited@example.test');
        $this->withToken($limited['access_token'])
            ->getJson('/api/v1/admin/tenant/reservations', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $viewer = $this->createTenantSession('ten_admin_res', 'par_admin_res', ['reservation.view'], 'adm_res_view', 'res-view@example.test');
        $customerNo = (string) DB::table('customers')->where('id', 'cus_admin_res')->value('customer_no');
        DB::table('stock_reservations')->insert([
            'id' => 'res_admin_res_older',
            'tenant_id' => 'ten_admin_res',
            'customer_id' => 'cus_admin_res',
            'game_id' => 'gam_admin_res',
            'status' => 'active',
            'expires_at' => now()->addMinutes(15),
            'idempotency_key' => 'admin-reserve-older',
            'payload_hash' => hash('sha256', 'admin-reserve-older'),
            'created_at' => now()->subHour(),
            'updated_at' => now()->subHour(),
        ]);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/reservations?status=active&customer_no='.$customerNo, [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $reservation['id'])
            ->assertJsonPath('data.0.customer_id', 'cus_admin_res')
            ->assertJsonPath('data.0.customer_no', $customerNo);

        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/reservations/'.$reservation['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_admin_res',
            ])
            ->assertOk()
            ->assertJsonPath('id', $reservation['id'])
            ->assertJsonPath('customer_no', $customerNo);

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
            'id' => $localStockId,
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

    /**
     * @param array<int, string> $numbers
     */
    private function insertBaseLotteryNumbers(array $numbers): void
    {
        DB::table('base_lottery_numbers')->insert(array_map(fn (string $number): array => [
            'full_number' => $number,
            'front3' => substr($number, 0, 3),
            'back3' => substr($number, -3),
            'back2' => substr($number, -2),
            'created_at' => now(),
            'updated_at' => now(),
        ], $numbers));
    }

    private function insertVirtualProfile(string $gameId, int $totalCapacity): void
    {
        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'tenant-reservation-virtual-seed',
            'base_count' => $totalCapacity,
            'total_capacity' => $totalCapacity,
            'set_distribution_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertVirtualAllocation(string $gameId, string $partnerId, string $tenantId, int $basisPoints, int $allocatedCount): void
    {
        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => $allocatedCount,
            'allocation_percent_basis_points' => $basisPoints,
            'allocated_count' => $allocatedCount,
            'recalled_count' => 0,
            'supply_layer_ids_json' => json_encode(['vsp_'.$gameId], JSON_THROW_ON_ERROR),
            'idempotency_key' => 'tenant-reservation-virtual',
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId.':'.$basisPoints),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
