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
            ->assertJsonPath('total.amount', 8000);

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
            'amount' => -8000,
            'reference_id' => $order['id'],
            'idempotency_key' => 'checkout-wallet-main',
        ]);
        $this->assertDatabaseHas('order_items', [
            'tenant_id' => 'ten_checkout',
            'order_id' => $order['id'],
            'price_amount' => 8000,
            'currency' => 'THB',
        ]);
        $snapshot = json_decode((string) DB::table('order_items')->where('order_id', $order['id'])->value('sale_price_rule_snapshot_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(8000, $snapshot['effective_amount']['amount'] ?? null);
        $this->assertSame('central', $snapshot['source'] ?? null);
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

    public function test_CustomerCheckout_locks_reservation_price_when_cart_is_created(): void
    {
        $world = $this->prepareReservedCart('par_checkout_price', 'ten_checkout_price', 'checkout-price.m5.test', 'gam_checkout_price', '0802003001', 710101);

        DB::table('game_sale_price_rules')->insert([
            'id' => 'gsp_checkout_price',
            'game_id' => 'gam_checkout_price',
            'set_size' => 1,
            'price_amount' => 12300,
            'currency' => 'THB',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('reservations.0.items.0.price.amount', 8000)
            ->assertJsonPath('total.amount', 8000);

        $order = $this->checkoutWallet($world, 'checkout-sale-price-rule');
        $this->assertSame(8000, $order['total']['amount']);
        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'total_amount' => 8000,
            'currency' => 'THB',
        ]);
        $this->assertDatabaseHas('order_items', [
            'tenant_id' => 'ten_checkout_price',
            'order_id' => $order['id'],
            'price_amount' => 8000,
            'currency' => 'THB',
        ]);
        $snapshot = json_decode((string) DB::table('order_items')->where('order_id', $order['id'])->value('sale_price_rule_snapshot_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertNotSame('gsp_checkout_price', $snapshot['central_rule_id'] ?? null);
        $this->assertSame(8000, $snapshot['effective_amount']['amount'] ?? null);
    }
}
