<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class CustomerCheckoutTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_CustomerCheckout_wallet_checkout_is_idempotent_and_emits_paid_sold_wallet_events(): void
    {
        $world = $this->prepareReservedCart('par_checkout', 'ten_checkout', 'checkout.m5.test', 'gam_checkout', '0802003000', 710001);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('item_count', 1)
            ->assertJsonPath('total.amount', 10000);

        DB::table('local_stock_items')->where('id', $world['local_ids'][0])->update([
            'image_url' => 'https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/stk_checkout.webp',
            'image_thumb_url' => 'https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/thumbs/stk_checkout.webp',
            'image_generation_status' => 'generated',
            'image_generated_at' => now(),
            'updated_at' => now(),
        ]);

        $order = $this->checkoutWallet($world, 'checkout-wallet-main');

        $this->assertSame('paid', $order['status']);
        $this->assertCount(1, $order['tickets']);
        $this->assertSame('https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/stk_checkout.webp', $order['tickets'][0]['image_url']);
        $this->assertSame('https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/thumbs/stk_checkout.webp', $order['tickets'][0]['image_thumb_url']);
        $this->assertDatabaseHas('stock_reservations', [
            'id' => $world['reservation']['id'],
            'status' => 'converted',
        ]);
        $this->assertDatabaseHas('local_stock_items', [
            'id' => $world['local_ids'][0],
            'status' => 'sold',
        ]);
        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => 'ten_checkout',
            'wallet_id' => $world['wallet_id'],
            'entry_type' => 'debit',
            'amount' => -10000,
            'reference_id' => $order['id'],
            'idempotency_key' => 'checkout-wallet-main',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'order.paid.v1',
            'aggregate_id' => $order['id'],
            'tenant_id' => 'ten_checkout',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'stock.sold.v1',
            'aggregate_id' => $order['id'],
            'tenant_id' => 'ten_checkout',
            'status' => 'pending',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'wallet.updated.v1',
            'aggregate_id' => $world['wallet_id'],
            'tenant_id' => 'ten_checkout',
        ]);

        $replay = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $world['reservation']['id'],
                'payment_method' => 'wallet',
            ], [
                'Idempotency-Key' => 'checkout-wallet-main',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame($order['id'], $replay['id']);
        $this->assertSame(1, DB::table('orders')->where('tenant_id', 'ten_checkout')->count());
        $this->assertSame(1, DB::table('tickets')->where('tenant_id', 'ten_checkout')->count());
        $this->assertDatabaseHas('tickets', [
            'tenant_id' => 'ten_checkout',
            'order_id' => $order['id'],
            'image_url' => 'https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/stk_checkout.webp',
            'image_thumb_url' => 'https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/thumbs/stk_checkout.webp',
        ]);
        $this->assertSame(2, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/orders/'.$order['id'])
            ->assertOk()
            ->assertJsonPath('id', $order['id']);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $order['tickets'][0]['id'])
            ->assertJsonPath('data.0.image_url', 'https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/stk_checkout.webp')
            ->assertJsonPath('data.0.image_thumb_url', 'https://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/thumbs/stk_checkout.webp');
    }
}
