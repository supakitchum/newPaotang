<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerReservationTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_CustomerReservation_creates_replays_releases_and_expires_with_local_stock_locking(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_reserve', 'ten_reserve', 'reserve.newpaotang.test');
        $this->insertGame('gam_reserve', 'open');
        $this->insertBaseLotteryNumbers(['654320', '654321']);
        $this->insertVirtualProfile('gam_reserve', 2);
        $this->insertVirtualAllocation('gam_reserve', 'par_reserve', 'ten_reserve', 10000, 2);
        $customerToken = $this->issueCustomerToken('ten_reserve', 'cus_reserve');
        $firstStock = $this->getJson('http://reserve.newpaotang.test/api/v1/public/stock/search?game_id=gam_reserve&number=654320')
            ->assertOk()
            ->json('data.0');
        $secondStock = $this->getJson('http://reserve.newpaotang.test/api/v1/public/stock/search?game_id=gam_reserve&number=654321')
            ->assertOk()
            ->json('data.0');

        $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$firstStock['id']],
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $reservation = $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$firstStock['id']],
            ], [
                'Idempotency-Key' => 'reserve-main',
                'X-Request-Id' => 'req-reserve-main',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('items.0.stock_ref', $firstStock['id'])
            ->json();
        $reservedLocalId = $reservation['items'][0]['id'];

        $this->assertDatabaseHas('local_stock_items', [
            'id' => $reservedLocalId,
            'tenant_id' => 'ten_reserve',
            'virtual_stock_ref' => $firstStock['id'],
            'status' => 'reserved',
        ]);

        $replay = $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$firstStock['id']],
            ], [
                'Idempotency-Key' => 'reserve-main',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame($reservation['id'], $replay['id']);
        $this->assertSame(1, DB::table('stock_reservations')->where('customer_id', 'cus_reserve')->count());

        $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$firstStock['id']],
            ], [
                'Idempotency-Key' => 'reserve-double',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'reservation_unavailable');

        $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations/'.$reservation['id'].'/release', [], [
                'Idempotency-Key' => 'reserve-release',
                'X-Request-Id' => 'req-reserve-release',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'released');

        $this->assertDatabaseHas('local_stock_items', [
            'id' => $reservedLocalId,
            'status' => 'available',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'reservation.released.v1',
            'aggregate_id' => $reservation['id'],
            'idempotency_key' => 'reserve-release',
        ]);

        $expiring = $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$secondStock['id']],
            ], [
                'Idempotency-Key' => 'reserve-expire',
            ])
            ->assertCreated()
            ->json();
        $expiringLocalId = $expiring['items'][0]['id'];

        DB::table('stock_reservations')->where('id', $expiring['id'])->update([
            'expires_at' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        Artisan::call('stock:reservations:expire', ['--limit' => 10]);

        $this->assertDatabaseHas('stock_reservations', [
            'id' => $expiring['id'],
            'status' => 'expired',
        ]);
        $this->assertDatabaseHas('local_stock_items', [
            'id' => $expiringLocalId,
            'status' => 'available',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'reservation.expired.v1',
            'aggregate_id' => $expiring['id'],
        ]);
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
            'seed' => 'customer-reservation-virtual-seed',
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
            'idempotency_key' => 'customer-reservation-virtual',
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId.':'.$basisPoints),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
