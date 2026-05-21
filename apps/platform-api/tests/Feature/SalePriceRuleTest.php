<?php

namespace Tests\Feature;

use App\Modules\Pricing\Services\LotterySalePriceService;
use App\Modules\Pricing\Events\SalePriceUpdated;
use Database\Seeders\DefaultSalePriceRuleSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class SalePriceRuleTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_SalePriceRules_central_rules_tenant_overrides_and_public_effective_price(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_sale_price', 'ten_sale_price', 'sale-price.newpaotang.test');
        $this->insertGame('gam_sale_price', 'open');
        $this->insertBaseLotteryNumbers(['120000', '120001']);
        $this->insertVirtualProfile('gam_sale_price', 2);
        $this->insertVirtualAllocation('gam_sale_price', 'par_sale_price', 'ten_sale_price', 10000, 2);
        Event::fake([SalePriceUpdated::class]);

        $central = $this->createCentralSession(['price_rule.view', 'price_rule.manage'], 'adm_sale_price_central', 'sale-price-central@example.test');
        $centralHeaders = [
            'X-Admin-Scope' => 'central',
            'Idempotency-Key' => 'central-sale-price-set-one',
        ];
        $centralRule = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/sale-price-rules', [
                'game_id' => 'gam_sale_price',
                'set_size' => 1,
                'price_amount' => 9000,
                'currency' => 'THB',
                'status' => 'active',
            ], $centralHeaders)
            ->assertCreated()
            ->assertJsonPath('price.amount', 9000)
            ->json();
        Event::assertDispatched(SalePriceUpdated::class, fn (SalePriceUpdated $event): bool => (
            ($event->payload['tenant_id'] ?? null) === 'ten_sale_price'
            && ($event->payload['game_id'] ?? null) === 'gam_sale_price'
            && (int) ($event->payload['set_size'] ?? 0) === 1
            && (int) data_get($event->payload, 'price.amount') === 9000
            && in_array('private-customer.tenant.ten_sale_price.stock.game.gam_sale_price', $this->eventChannelNames($event), true)
            && in_array('customer.tenant.ten_sale_price.stock.game.gam_sale_price', $this->eventChannelNames($event), true)
            && in_array('customer.tenant.ten_sale_price.sale-price', $this->eventChannelNames($event), true)
        ));

        $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/sale-price-rules', [
                'game_id' => 'gam_sale_price',
                'set_size' => 2,
                'price_amount' => 17000,
                'currency' => 'THB',
                'status' => 'active',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-sale-price-set-two',
            ])
            ->assertCreated()
            ->assertJsonPath('price.amount', 17000);

        $service = app(LotterySalePriceService::class);
        $this->assertSame(17000, $service->effectivePrice('ten_sale_price', 'gam_sale_price', 2)['amount']);
        $fallback = $service->effectivePrice('ten_sale_price', 'gam_sale_price', 3);
        $this->assertSame(27000, $fallback['amount']);
        $this->assertTrue($fallback['fallback']);

        $tenant = $this->createTenantSession(
            'ten_sale_price',
            'par_sale_price',
            ['price_rule.view', 'price_rule.manage'],
            'adm_sale_price_tenant',
            'sale-price-tenant@example.test',
        );
        $tenantHeaders = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => 'ten_sale_price',
        ];

        $this->withToken($tenant['access_token'])
            ->getJson('/api/v1/admin/tenant/sale-price-rules?game_id=gam_sale_price', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('data.0.central_rule_id', $centralRule['id'])
            ->assertJsonPath('data.0.central_price.amount', 9000)
            ->assertJsonPath('data.0.partner_price.amount', 9000)
            ->assertJsonPath('data.0.source', 'central');

        $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/sale-price-rules', [
                'game_id' => 'gam_sale_price',
                'set_size' => 1,
                'price_amount' => 8500,
                'currency' => 'THB',
                'status' => 'active',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-sale-price-too-low'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.price_amount.0', 'The partner sale price must be greater than or equal to the central sale price.');

        $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/sale-price-rules', [
                'game_id' => 'gam_sale_price',
                'set_size' => 1,
                'price_amount' => 9500,
                'currency' => 'THB',
                'status' => 'active',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-sale-price-valid'])
            ->assertCreated()
            ->assertJsonPath('partner_price.amount', 9500)
            ->assertJsonPath('source', 'tenant_override');
        Event::assertDispatched(SalePriceUpdated::class, fn (SalePriceUpdated $event): bool => (
            ($event->payload['tenant_id'] ?? null) === 'ten_sale_price'
            && ($event->payload['game_id'] ?? null) === 'gam_sale_price'
            && (int) ($event->payload['set_size'] ?? 0) === 1
            && (int) data_get($event->payload, 'price.amount') === 9500
            && in_array('private-customer.tenant.ten_sale_price.stock.game.gam_sale_price', $this->eventChannelNames($event), true)
            && in_array('customer.tenant.ten_sale_price.stock.game.gam_sale_price', $this->eventChannelNames($event), true)
            && in_array('customer.tenant.ten_sale_price.sale-price', $this->eventChannelNames($event), true)
        ));

        $search = $this->getJson('http://sale-price.newpaotang.test/api/v1/public/stock/search?game_id=gam_sale_price&number=120000')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '120000')
            ->assertJsonPath('data.0.price.amount', 9500)
            ->assertJsonPath('data.0.price_rule_summary.source', 'tenant_override')
            ->json();
        $this->assertArrayNotHasKey('stock_mode', $search['data'][0]);
    }

    public function test_DefaultSalePriceRuleSeeder_seeds_sets_one_through_twenty_at_eighty_thb_per_ticket(): void
    {
        $this->insertGame('gam_sale_price_seed', 'open');
        DB::table('game_sale_price_rules')->insert([
            'id' => 'gsp_existing_seed_one',
            'game_id' => 'gam_sale_price_seed',
            'set_size' => 1,
            'price_amount' => 9999,
            'currency' => 'THB',
            'status' => 'inactive',
            'created_at' => now()->subDay(),
            'updated_at' => now()->subDay(),
        ]);

        $this->seed(DefaultSalePriceRuleSeeder::class);
        $this->seed(DefaultSalePriceRuleSeeder::class);

        $rules = DB::table('game_sale_price_rules')
            ->where('game_id', 'gam_sale_price_seed')
            ->orderBy('set_size')
            ->get(['set_size', 'price_amount', 'currency', 'status']);

        $this->assertCount(20, $rules);
        $this->assertSame(8000, (int) $rules->firstWhere('set_size', 1)->price_amount);
        $this->assertSame(160000, (int) $rules->firstWhere('set_size', 20)->price_amount);
        $this->assertTrue($rules->every(fn (object $rule): bool => (string) $rule->currency === 'THB'));
        $this->assertTrue($rules->every(fn (object $rule): bool => (string) $rule->status === 'active'));
    }

    public function test_TenantSalePriceRule_broadcasts_immediately_when_saved_inside_transaction(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_sale_price_tx', 'ten_sale_price_tx', 'sale-price-tx.newpaotang.test');
        $this->insertGame('gam_sale_price_tx', 'open');
        DB::table('game_sale_price_rules')->insert([
            'id' => 'gsp_sale_price_tx_one',
            'game_id' => 'gam_sale_price_tx',
            'set_size' => 1,
            'price_amount' => 8000,
            'currency' => 'THB',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        Event::fake([SalePriceUpdated::class]);

        DB::beginTransaction();

        try {
            $result = app(LotterySalePriceService::class)->upsertTenantRule('ten_sale_price_tx', [
                'game_id' => 'gam_sale_price_tx',
                'set_size' => 1,
                'price_amount' => 9000,
                'currency' => 'THB',
                'status' => 'active',
            ]);

            $this->assertArrayHasKey('resource', $result);
            Event::assertDispatched(SalePriceUpdated::class, fn (SalePriceUpdated $event): bool => (
                ($event->payload['tenant_id'] ?? null) === 'ten_sale_price_tx'
                && ($event->payload['game_id'] ?? null) === 'gam_sale_price_tx'
                && (int) data_get($event->payload, 'price.amount') === 9000
                && in_array('customer.tenant.ten_sale_price_tx.sale-price', $this->eventChannelNames($event), true)
            ));
        } finally {
            DB::rollBack();
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
            'seed' => 'sale-price-virtual-seed',
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
            'idempotency_key' => 'sale-price-virtual-'.$gameId,
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId.':'.$basisPoints),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @return array<int, string>
     */
    private function eventChannelNames(SalePriceUpdated $event): array
    {
        return array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());
    }
}
