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
        $localIds = $this->syncAllocatedStockToLocal('par_reserve', 'ten_reserve', 'gam_reserve', 2, 'alloc-reserve', 654320);
        $customerToken = $this->issueCustomerToken('ten_reserve', 'cus_reserve');

        $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$localIds[0]],
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $reservation = $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$localIds[0]],
            ], [
                'Idempotency-Key' => 'reserve-main',
                'X-Request-Id' => 'req-reserve-main',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('items.0.id', $localIds[0])
            ->json();

        $this->assertDatabaseHas('local_stock_items', [
            'id' => $localIds[0],
            'tenant_id' => 'ten_reserve',
            'status' => 'reserved',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'reservation.created.v1',
            'aggregate_id' => $reservation['id'],
            'tenant_id' => 'ten_reserve',
            'correlation_id' => 'req-reserve-main',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.unavailable.v1',
            'aggregate_id' => $reservation['id'],
            'tenant_id' => 'ten_reserve',
        ]);

        $replay = $this->withToken($customerToken)
            ->postJson('http://reserve.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_reserve',
                'local_stock_item_ids' => [$localIds[0]],
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
                'local_stock_item_ids' => [$localIds[0]],
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
            'id' => $localIds[0],
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
                'local_stock_item_ids' => [$localIds[1]],
            ], [
                'Idempotency-Key' => 'reserve-expire',
            ])
            ->assertCreated()
            ->json();

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
            'id' => $localIds[1],
            'status' => 'available',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'reservation.expired.v1',
            'aggregate_id' => $expiring['id'],
        ]);
    }
}
