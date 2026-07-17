<?php

namespace Tests\Feature;

use App\Jobs\GenerateSoldTicketImageJob;
use App\Modules\Commerce\Events\CustomerOrderUpdated;
use App\Modules\Commerce\Events\CustomerTicketsUpdated;
use App\Modules\Commerce\Events\CustomerWalletUpdated;
use App\Modules\PartnerStore\Services\VirtualLotteryImageService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;
use Mockery;
use Tests\Support\M5CommerceFixtures;
use Tests\TestCase;

class CustomerCheckoutTest extends TestCase
{
    use M5CommerceFixtures;
    use RefreshDatabase;

    public function test_CustomerCheckout_wallet_checkout_is_idempotent_and_emits_paid_sold_wallet_events(): void
    {
        $world = $this->prepareReservedCart('par_checkout', 'ten_checkout', 'checkout.m5.test', 'gam_checkout', '0802003000', 710001);
        Event::fake([
            CustomerOrderUpdated::class,
            CustomerTicketsUpdated::class,
            CustomerWalletUpdated::class,
        ]);

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
        $expectedImageUrl = 'http://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/stk_checkout.webp';
        $expectedThumbUrl = 'http://cdn.lottery.test/lotteries/gam_checkout/batch/partners/par_checkout/thumbs/stk_checkout.webp';

        $order = $this->checkoutWallet($world, 'checkout-wallet-main');

        $this->assertSame('paid', $order['status']);
        $this->assertCount(1, $order['tickets']);
        $this->assertSame($expectedImageUrl, $order['tickets'][0]['image_url']);
        $this->assertSame($expectedThumbUrl, $order['tickets'][0]['image_thumb_url']);
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
        Event::assertDispatched(CustomerOrderUpdated::class, function (CustomerOrderUpdated $event) use ($order, $world): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'order.updated'
                && ($event->payload['order_id'] ?? null) === $order['id']
                && ($event->payload['status'] ?? null) === 'paid'
                && ($event->payload['ticket_ids'][0] ?? null) === $order['tickets'][0]['id']
                && in_array('private-customer.tenant.ten_checkout.customer.'.$world['auth']['user']['id'].'.orders', $channels, true);
        });
        Event::assertDispatched(CustomerTicketsUpdated::class, function (CustomerTicketsUpdated $event) use ($order, $world): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'tickets.updated'
                && ($event->payload['order_id'] ?? null) === $order['id']
                && ($event->payload['ticket_ids'][0] ?? null) === $order['tickets'][0]['id']
                && in_array('private-customer.tenant.ten_checkout.customer.'.$world['auth']['user']['id'].'.tickets', $channels, true);
        });
        Event::assertDispatched(CustomerWalletUpdated::class, function (CustomerWalletUpdated $event) use ($world): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'wallet.updated'
                && ($event->payload['wallet_id'] ?? null) === $world['wallet_id']
                && ($event->payload['entry_type'] ?? null) === 'debit'
                && ($event->payload['amount'] ?? null) === -8000
                && in_array('private-customer.tenant.ten_checkout.customer.'.$world['auth']['user']['id'].'.wallet', $channels, true);
        });

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
        Event::assertDispatchedTimes(CustomerOrderUpdated::class, 1);
        Event::assertDispatchedTimes(CustomerTicketsUpdated::class, 1);
        Event::assertDispatchedTimes(CustomerWalletUpdated::class, 1);
        $this->assertSame(1, DB::table('orders')->where('tenant_id', 'ten_checkout')->count());
        $this->assertSame(1, DB::table('tickets')->where('tenant_id', 'ten_checkout')->count());
        $this->assertDatabaseHas('tickets', [
            'tenant_id' => 'ten_checkout',
            'order_id' => $order['id'],
            'image_url' => $expectedImageUrl,
            'image_thumb_url' => $expectedThumbUrl,
        ]);
        $this->assertSame(2, DB::table('wallet_ledger')->where('wallet_id', $world['wallet_id'])->count());

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/orders/'.$order['id'])
            ->assertOk()
            ->assertJsonPath('id', $order['id'])
            ->assertJsonPath('ticket_count', 1)
            ->assertJsonPath('game.name', 'Game gam_checkout');

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/orders')
            ->assertOk()
            ->assertJsonPath('data.0.id', $order['id'])
            ->assertJsonPath('data.0.ticket_count', 1)
            ->assertJsonPath('data.0.total.amount', 8000)
            ->assertJsonPath('data.0.game.name', 'Game gam_checkout')
            ->assertJsonPath('meta.total', 1);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $order['tickets'][0]['id'])
            ->assertJsonPath('data.0.image_url', $expectedImageUrl)
            ->assertJsonPath('data.0.image_thumb_url', $expectedThumbUrl);
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

    public function test_CustomerCheckout_wallet_checkout_queues_and_generates_sold_ticket_image_after_payment(): void
    {
        $world = $this->prepareReservedCart('par_checkout_image', 'ten_checkout_image', 'checkout-image.m5.test', 'gam_checkout_image', '0802003004', 710401);
        Queue::fake([GenerateSoldTicketImageJob::class]);

        $order = $this->checkoutWallet($world, 'checkout-wallet-sold-image');
        $ticketId = (string) ($order['tickets'][0]['id'] ?? '');
        $localStockRef = (string) DB::table('local_stock_items')->where('id', $world['local_ids'][0])->value('virtual_stock_ref');

        $snapshot = json_decode((string) DB::table('tickets')->where('id', $ticketId)->value('image_render_snapshot_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('queued', $snapshot['render_status'] ?? null);
        $this->assertSame($ticketId, $snapshot['ticket_id'] ?? null);
        $this->assertSame($localStockRef, $snapshot['virtual_stock_ref'] ?? null);

        $renderer = Mockery::mock(VirtualLotteryImageService::class);
        $renderer
            ->shouldReceive('renderSoldTicketImages')
            ->once()
            ->with($ticketId, Mockery::on(fn (object $stock): bool => (string) $stock->id === (string) $world['local_ids'][0]))
            ->andReturn([
                'image_url' => 'https://cdn.lottery.test/sold/'.$ticketId.'.webp',
                'image_thumb_url' => 'https://cdn.lottery.test/sold/thumbs/'.$ticketId.'.webp',
                'image_storage_path' => 'lotteries/sold/'.$ticketId.'.webp',
                'image_thumb_storage_path' => 'lotteries/sold/thumbs/'.$ticketId.'.webp',
                'snapshot' => [
                    'ticket_id' => $ticketId,
                    'virtual_stock_ref' => $localStockRef,
                    'render_status' => 'generated',
                    'image_storage_path' => 'lotteries/sold/'.$ticketId.'.webp',
                    'image_thumb_storage_path' => 'lotteries/sold/thumbs/'.$ticketId.'.webp',
                ],
            ]);

        (new GenerateSoldTicketImageJob($ticketId, force: true))->handle($renderer);

        $this->assertDatabaseHas('tickets', [
            'id' => $ticketId,
            'image_url' => 'http://cdn.lottery.test/sold/'.$ticketId.'.webp',
            'image_thumb_url' => 'http://cdn.lottery.test/sold/thumbs/'.$ticketId.'.webp',
        ]);

        $generatedSnapshot = json_decode((string) DB::table('tickets')->where('id', $ticketId)->value('image_render_snapshot_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('generated', $generatedSnapshot['render_status'] ?? null);
        $this->assertSame('lotteries/sold/'.$ticketId.'.webp', $generatedSnapshot['image_storage_path'] ?? null);
    }

    public function test_CustomerCheckout_wallet_checkout_calculates_affiliate_commission_immediately(): void
    {
        $world = $this->prepareReservedCart('par_checkout_affiliate', 'ten_checkout_affiliate', 'checkout-affiliate.m5.test', 'gam_checkout_affiliate', '0802003003', 710301);
        $affiliateCustomerId = 'cus_checkout_affiliate_owner';

        DB::table('customers')->insert([
            'id' => $affiliateCustomerId,
            'tenant_id' => $world['tenant_id'],
            'phone' => '0802003999',
            'name' => 'Affiliate Owner',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_programs')->insert([
            'id' => 'afp_checkout_affiliate',
            'tenant_id' => $world['tenant_id'],
            'code' => 'checkout_affiliate',
            'name' => 'Checkout Affiliate',
            'status' => 'active',
            'starts_at' => null,
            'ends_at' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_accounts')->insert([
            'id' => 'aff_checkout_affiliate',
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $affiliateCustomerId,
            'code' => 'AfC123',
            'name' => 'Affiliate Owner',
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_links')->insert([
            'id' => 'afl_checkout_affiliate',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => 'aff_checkout_affiliate',
            'affiliate_program_id' => 'afp_checkout_affiliate',
            'code' => 'LnC123',
            'url' => 'https://checkout-affiliate.m5.test/?ref=LnC123',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_attributions')->insert([
            'id' => 'aat_checkout_affiliate',
            'tenant_id' => $world['tenant_id'],
            'affiliate_account_id' => 'aff_checkout_affiliate',
            'affiliate_link_id' => 'afl_checkout_affiliate',
            'affiliate_program_id' => 'afp_checkout_affiliate',
            'customer_id' => $world['auth']['user']['id'],
            'order_id' => null,
            'status' => 'pending',
            'attributed_at' => now(),
            'converted_at' => null,
            'metadata_json' => json_encode(['expires_at' => now()->addDays(30)->toISOString()], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('commission_rules')->insert([
            'id' => 'cmr_checkout_affiliate',
            'tenant_id' => $world['tenant_id'],
            'affiliate_program_id' => 'afp_checkout_affiliate',
            'affiliate_account_id' => null,
            'code' => 'checkout_affiliate_rule',
            'name' => 'Checkout Affiliate Rule',
            'rule_type' => 'per_ticket',
            'amount' => 2000,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $order = $this->checkoutWallet($world, 'checkout-wallet-affiliate-commission');

        $this->assertDatabaseHas('commission_transactions', [
            'tenant_id' => $world['tenant_id'],
            'order_id' => $order['id'],
            'affiliate_account_id' => 'aff_checkout_affiliate',
            'affiliate_attribution_id' => 'aat_checkout_affiliate',
            'commission_rule_id' => 'cmr_checkout_affiliate',
            'amount' => 2000,
            'status' => 'approved',
        ]);
        $this->assertDatabaseHas('affiliate_attributions', [
            'id' => 'aat_checkout_affiliate',
            'status' => 'converted',
            'order_id' => $order['id'],
        ]);
    }

    public function test_CustomerCheckout_wallet_checkout_converts_every_active_cart_reservation(): void
    {
        $world = $this->prepareReservedCart('par_checkout_multi', 'ten_checkout_multi', 'checkout-multi.m5.test', 'gam_checkout_multi', '0802003002', 710201);
        $secondReservation = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reservations', [
                'game_id' => $world['game_id'],
                'local_stock_item_ids' => [$this->firstVirtualStockRef($world['host'], $world['game_id'], 710202)],
            ], [
                'Idempotency-Key' => 'reserve-ten_checkout_multi-second',
            ])
            ->assertCreated()
            ->json();
        $reservationIds = [
            $world['reservation']['id'],
            $secondReservation['id'],
        ];
        $secondLocalIds = array_values(array_map(
            fn (array $item): string => (string) $item['id'],
            $secondReservation['items'] ?? [],
        ));

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('item_count', 2)
            ->assertJsonPath('total.amount', 16000)
            ->assertJsonCount(2, 'reservations');

        $order = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $reservationIds[0],
                'reservation_ids' => $reservationIds,
                'payment_method' => 'wallet',
            ], [
                'Idempotency-Key' => 'checkout-wallet-multi',
                'X-Request-Id' => 'req-checkout-wallet-multi',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame('paid', $order['status']);
        $this->assertSame(16000, $order['total']['amount']);
        $this->assertCount(2, $order['tickets']);
        foreach ($reservationIds as $reservationId) {
            $this->assertDatabaseHas('stock_reservations', [
                'id' => $reservationId,
                'status' => 'converted',
            ]);
            $this->assertDatabaseHas('stock_reservation_items', [
                'reservation_id' => $reservationId,
                'status' => 'converted',
            ]);
        }
        foreach (array_merge($world['local_ids'], $secondLocalIds) as $localId) {
            $this->assertDatabaseHas('local_stock_items', [
                'id' => $localId,
                'status' => 'sold',
            ]);
        }
        $this->assertDatabaseHas('orders', [
            'id' => $order['id'],
            'total_amount' => 16000,
        ]);
        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => 'ten_checkout_multi',
            'wallet_id' => $world['wallet_id'],
            'entry_type' => 'debit',
            'amount' => -16000,
            'reference_id' => $order['id'],
            'idempotency_key' => 'checkout-wallet-multi',
        ]);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('item_count', 0)
            ->assertJsonPath('total.amount', 0);
    }

    public function test_CustomerCheckout_cart_prices_duplicate_number_with_partner_set_rule(): void
    {
        $world = $this->prepareReservedCart(
            'par_checkout_set_price',
            'ten_checkout_set_price',
            'checkout-set-price.m5.test',
            'gam_checkout_set_price',
            '0802003005',
            710501,
            [['set_size' => 2, 'percent_basis_points' => 10000]],
        );

        DB::table('tenant_sale_price_overrides')->insert([
            'id' => 'tsp_checkout_set_price',
            'tenant_id' => $world['tenant_id'],
            'partner_id' => $world['partner_id'],
            'game_id' => $world['game_id'],
            'set_size' => 2,
            'price_amount' => 19000,
            'currency' => 'THB',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $secondReservation = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reservations', [
                'game_id' => $world['game_id'],
                'local_stock_item_ids' => [$this->firstVirtualStockRef($world['host'], $world['game_id'], 710501)],
            ], [
                'Idempotency-Key' => 'reserve-ten_checkout_set_price-second',
            ])
            ->assertCreated()
            ->json();
        $reservationIds = [
            $world['reservation']['id'],
            $secondReservation['id'],
        ];

        DB::table('tenant_sale_price_overrides')->where('id', 'tsp_checkout_set_price')->update([
            'price_amount' => 21000,
            'updated_at' => now(),
        ]);

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/cart')
            ->assertOk()
            ->assertJsonPath('item_count', 2)
            ->assertJsonPath('total.amount', 19000)
            ->assertJsonPath('reservations.0.items.0.price_rule_summary.set_size', 2)
            ->assertJsonPath('reservations.0.items.0.price_rule_summary.source', 'tenant_override')
            ->assertJsonPath('reservations.1.items.0.price_rule_summary.set_size', 2)
            ->assertJsonPath('reservations.1.items.0.price_rule_summary.source', 'tenant_override');

        $order = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/checkout', [
                'reservation_id' => $reservationIds[0],
                'reservation_ids' => $reservationIds,
                'payment_method' => 'wallet',
            ], [
                'Idempotency-Key' => 'checkout-wallet-set-price',
                'X-Request-Id' => 'req-checkout-wallet-set-price',
            ])
            ->assertCreated()
            ->json();

        $this->assertSame(19000, $order['total']['amount']);
        $this->assertSame(19000, (int) DB::table('order_items')->where('order_id', $order['id'])->sum('price_amount'));
        $snapshot = json_decode((string) DB::table('order_items')->where('order_id', $order['id'])->orderBy('id')->value('sale_price_rule_snapshot_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame(2, $snapshot['set_size'] ?? null);
        $this->assertSame('tenant_override', $snapshot['source'] ?? null);
    }
}
