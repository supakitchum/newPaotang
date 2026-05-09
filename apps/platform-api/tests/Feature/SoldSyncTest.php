<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class SoldSyncTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_SoldSync_command_marks_central_stock_sold_idempotently_from_stock_sold_event(): void
    {
        $world = $this->prepareReservedCart('par_sold_sync', 'ten_sold_sync', 'sold-sync.m5.test', 'gam_sold_sync', '0809001000', 780001);
        $order = $this->checkoutWallet($world, 'sold-sync-checkout');
        $stockItemId = DB::table('local_stock_items')->where('id', $world['local_ids'][0])->value('stock_item_id');

        $this->assertDatabaseHas('stock_items', [
            'id' => $stockItemId,
            'status' => 'allocated',
        ]);

        Artisan::call('stock:sold:sync', ['--limit' => 10]);

        $this->assertDatabaseHas('stock_items', [
            'id' => $stockItemId,
            'status' => 'sold',
        ]);
        $this->assertDatabaseHas('sync_inbox', [
            'event_type' => 'stock.sold.v1',
            'consumer' => 'central_stock',
            'status' => 'processed',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.sold.v1',
            'aggregate_id' => $order['id'],
            'status' => 'processed',
        ]);

        DB::table('sync_outbox')
            ->where('event_type', 'stock.sold.v1')
            ->where('aggregate_id', $order['id'])
            ->update([
                'status' => 'pending',
                'processed_at' => null,
                'updated_at' => now(),
            ]);

        Artisan::call('stock:sold:sync', ['--limit' => 10]);

        $this->assertSame(1, DB::table('sync_inbox')->where('event_type', 'stock.sold.v1')->where('consumer', 'central_stock')->count());
        $this->assertDatabaseHas('stock_items', [
            'id' => $stockItemId,
            'status' => 'sold',
        ]);
    }
}
