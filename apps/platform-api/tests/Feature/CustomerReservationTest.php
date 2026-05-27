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

    public function test_CustomerReservation_rejects_stale_virtual_stock_after_game_sale_window_closes(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_closed_reserve', 'ten_closed_reserve', 'closed-reserve.newpaotang.test');
        $this->insertGame('gam_closed_reserve', 'open');
        $this->insertBaseLotteryNumbers(['654340']);
        $this->insertVirtualProfile('gam_closed_reserve', 1);
        $this->insertVirtualAllocation('gam_closed_reserve', 'par_closed_reserve', 'ten_closed_reserve', 10000, 1);
        $customerToken = $this->issueCustomerToken('ten_closed_reserve', 'cus_closed_reserve');

        $stock = $this->getJson('http://closed-reserve.newpaotang.test/api/v1/public/stock/search?game_id=gam_closed_reserve&number=654340')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '654340')
            ->json('data.0');

        DB::table('games')->where('id', 'gam_closed_reserve')->update([
            'close_at' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        $this->getJson('http://closed-reserve.newpaotang.test/api/v1/public/stock/search?game_id=gam_closed_reserve&number=654340')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        $this->withToken($customerToken)
            ->postJson('http://closed-reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_closed_reserve',
                'local_stock_item_ids' => [$stock['id']],
            ], [
                'Idempotency-Key' => 'reserve-sale-closed',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'reservation_unavailable');

        $this->assertSame(0, DB::table('stock_reservations')->where('customer_id', 'cus_closed_reserve')->count());
        $this->assertSame(0, DB::table('local_stock_items')->where('tenant_id', 'ten_closed_reserve')->whereNotNull('virtual_stock_ref')->count());
    }

    public function test_CustomerReservation_uses_first_cart_expiry_and_cart_endpoint_expires_due_items(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_cart_window', 'ten_cart_window', 'cart-window.newpaotang.test');
        $this->insertGame('gam_cart_window', 'open');
        $this->insertBaseLotteryNumbers(['654330', '654331']);
        $this->insertVirtualProfile('gam_cart_window', 2);
        $this->insertVirtualAllocation('gam_cart_window', 'par_cart_window', 'ten_cart_window', 10000, 2);
        $customerToken = $this->issueCustomerToken('ten_cart_window', 'cus_cart_window');
        $firstStock = $this->getJson('http://cart-window.newpaotang.test/api/v1/public/stock/search?game_id=gam_cart_window&number=654330')
            ->assertOk()
            ->json('data.0');
        $secondStock = $this->getJson('http://cart-window.newpaotang.test/api/v1/public/stock/search?game_id=gam_cart_window&number=654331')
            ->assertOk()
            ->json('data.0');

        $firstReservation = $this->withToken($customerToken)
            ->postJson('http://cart-window.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_cart_window',
                'local_stock_item_ids' => [$firstStock['id']],
            ], [
                'Idempotency-Key' => 'cart-window-first',
            ])
            ->assertCreated()
            ->json();

        $this->assertGreaterThan(0, $firstReservation['expires_in_seconds']);
        $this->assertLessThanOrEqual(900, $firstReservation['expires_in_seconds']);

        $secondReservation = $this->withToken($customerToken)
            ->postJson('http://cart-window.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_cart_window',
                'local_stock_item_ids' => [$secondStock['id']],
            ], [
                'Idempotency-Key' => 'cart-window-second',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame($firstReservation['expires_at'], $secondReservation['expires_at']);
        $this->assertGreaterThan(0, $secondReservation['expires_in_seconds']);
        $this->assertLessThanOrEqual(900, $secondReservation['expires_in_seconds']);

        $cart = $this->withToken($customerToken)
            ->getJson('http://cart-window.newpaotang.test/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('item_count', 2)
            ->json();

        $this->assertGreaterThan(0, $cart['reservations'][0]['expires_in_seconds']);
        $this->assertLessThanOrEqual(900, $cart['reservations'][0]['expires_in_seconds']);

        DB::table('stock_reservations')->whereIn('id', [$firstReservation['id'], $secondReservation['id']])->update([
            'expires_at' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        $this->withToken($customerToken)
            ->getJson('http://cart-window.newpaotang.test/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('item_count', 0)
            ->assertJsonCount(0, 'reservations');

        foreach ([$firstReservation, $secondReservation] as $reservation) {
            $this->assertDatabaseHas('stock_reservations', [
                'id' => $reservation['id'],
                'status' => 'expired',
            ]);
            $this->assertDatabaseHas('local_stock_items', [
                'id' => $reservation['items'][0]['id'],
                'status' => 'available',
            ]);
            $this->assertDatabaseHas('sync_outbox', [
                'event_type' => 'reservation.expired.v1',
                'aggregate_id' => $reservation['id'],
            ]);
        }
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
