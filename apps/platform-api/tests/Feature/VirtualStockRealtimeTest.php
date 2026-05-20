<?php

namespace Tests\Feature;

use App\Modules\CentralStock\Events\StockCoverageUpdated;
use App\Modules\CentralStock\Events\StockTableUpdated;
use App\Modules\PartnerStore\Events\StockAvailabilityUpdated;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class VirtualStockRealtimeTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_stock_settings_store_default_set_distribution(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_settings', 'stock-settings@example.test');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/settings', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('settings.stock_set_distribution_default.0.set_size', 2)
            ->assertJsonPath('settings.stock_set_distribution_default.0.percent', 10)
            ->assertJsonPath('settings.stock_set_distribution_default.1.set_size', 3)
            ->assertJsonPath('settings.stock_set_distribution_default.1.percent', 15)
            ->assertJsonPath('settings.stock_pattern_coverage_default.central.back2_limit', 500)
            ->assertJsonPath('settings.stock_pattern_coverage_default.partner.back2_limit', 200);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/stock/settings', [
                'settings' => [
                    'stock_set_distribution_default' => [
                        ['set_size' => 2, 'percent' => 20],
                        ['set_size' => 4, 'percent' => 5],
                    ],
                    'stock_pattern_coverage_default' => [
                        'central' => ['back2_limit' => 50, 'back3_limit' => 30, 'front3_limit' => 20],
                        'partner' => ['back2_limit' => 40, 'back3_limit' => 30, 'front3_limit' => 10],
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-settings-default-set-distribution',
            ])
            ->assertOk()
            ->assertJsonPath('settings.stock_set_distribution_default.0.set_size', 2)
            ->assertJsonPath('settings.stock_set_distribution_default.0.percent', 20)
            ->assertJsonPath('settings.stock_set_distribution_default.1.set_size', 4)
            ->assertJsonPath('settings.stock_set_distribution_default.1.percent', 5)
            ->assertJsonPath('settings.stock_pattern_coverage_default.central.back2_limit', 50)
            ->assertJsonPath('settings.stock_pattern_coverage_default.partner.front3_limit', 10);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/stock/settings', [
                'settings' => [
                    'stock_set_distribution_default' => [
                        ['set_size' => 2, 'percent' => 80],
                        ['set_size' => 3, 'percent' => 30],
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-settings-default-set-distribution-invalid',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $invalidCoverage = $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/stock/settings', [
                'settings' => [
                    'stock_pattern_coverage_default' => [
                        'central' => ['back2_limit' => 10, 'back3_limit' => 10, 'front3_limit' => 10],
                        'partner' => ['back2_limit' => 11, 'back3_limit' => 10, 'front3_limit' => 10],
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-settings-pattern-coverage-invalid',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->json();
        $this->assertSame(
            'The partner back2_limit default may not exceed the central default of 10.',
            $invalidCoverage['error']['details']['fields']['stock_pattern_coverage_default.partner.back2_limit'][0] ?? null,
        );
    }

    public function test_virtual_profile_generation_does_not_bulk_insert_stock_rows(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_virtual_generate', 'open');
        $this->insertActivePartnerTenantWithDomain('par_virtual_generate', 'ten_virtual_generate', 'generate.newpaotang.test');
        $this->insertBaseLotteryNumbers([
            '000000',
            '000001',
            '000002',
            '000003',
            '000004',
            '000005',
            '000006',
            '000007',
            '000008',
            '000009',
        ]);
        $login = $this->createCentralSession(['stock.generate'], 'adm_virtual_generate', 'virtual-generate@example.test');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_generate',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [
                    ['set_size' => 2, 'percent' => 10],
                    ['set_size' => 3, 'percent' => 15],
                ],
                'partner_distribution' => [
                    ['partner_id' => 'par_virtual_generate', 'percent' => 100],
                ],
                'central_limits' => ['back2_limit' => 500, 'back3_limit' => 300, 'front3_limit' => 200],
                'partner_limits' => [
                    ['partner_id' => 'par_virtual_generate', 'back2_limit' => 200, 'back3_limit' => 100, 'front3_limit' => 80],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-profile-generate',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'virtual_profile')
            ->assertJsonPath('stock_mode', 'virtual')
            ->assertJsonPath('requested_count', 13)
            ->assertJsonPath('generated_count', 13)
            ->assertJsonPath('total_capacity', 13)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/generation-batches/'.$batch['id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('id', $batch['id'])
            ->assertJsonPath('type', 'virtual_profile')
            ->assertJsonPath('requested_count', 13)
            ->assertJsonPath('generated_count', 13);

        $this->assertSame(1, DB::table('stock_supply_profiles')->where('game_id', 'gam_virtual_generate')->where('status', 'active')->count());
        $this->assertSame(1, DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_virtual_generate')->where('status', 'active')->count());
        $this->assertNotNull(DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_virtual_generate')->value('layer_seed'));
        $this->assertSame(1, DB::table('stock_partner_distributions')->where('game_id', 'gam_virtual_generate')->where('partner_id', 'par_virtual_generate')->count());
        $this->assertSame(10000, (int) DB::table('stock_partner_distributions')->where('game_id', 'gam_virtual_generate')->value('percent_basis_points'));
        $this->assertSame(2, DB::table('stock_sale_limit_settings')->where('game_id', 'gam_virtual_generate')->count());
        $this->assertSame(500, (int) DB::table('stock_sale_limit_settings')->where('game_id', 'gam_virtual_generate')->where('scope_type', 'central')->value('back2_limit'));
        $this->assertSame(200, (int) DB::table('stock_sale_limit_settings')->where('game_id', 'gam_virtual_generate')->where('scope_type', 'partner')->value('back2_limit'));
        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_virtual_generate')->count());

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_generate',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [
                    ['set_size' => 2, 'percent' => 10],
                    ['set_size' => 3, 'percent' => 15],
                ],
                'partner_distribution' => [
                    ['partner_id' => 'par_virtual_generate', 'percent' => 100],
                ],
                'central_limits' => ['back2_limit' => 500, 'back3_limit' => 300, 'front3_limit' => 200],
                'partner_limits' => [
                    ['partner_id' => 'par_virtual_generate', 'back2_limit' => 200, 'back3_limit' => 100, 'front3_limit' => 80],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-profile-generate',
            ])
            ->assertAccepted()
            ->assertJsonPath('id', $batch['id'])
            ->assertJsonPath('layer_id', $batch['layer_id']);
        $this->assertSame(1, DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_virtual_generate')->count());

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_generate',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [
                    ['set_size' => 4, 'percent' => 100],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-profile-generate',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');
        $this->assertSame(1, DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_virtual_generate')->count());

        $secondBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_generate',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
                'partner_distribution' => [
                    ['partner_id' => 'par_virtual_generate', 'percent' => 100],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-profile-generate-second',
            ])
            ->assertAccepted()
            ->assertJsonPath('requested_count', 10)
            ->assertJsonPath('top_up', true)
            ->assertJsonPath('total_capacity', 23)
            ->json();
        $this->assertSame(1, DB::table('stock_supply_profiles')->where('game_id', 'gam_virtual_generate')->where('status', 'active')->count());
        $this->assertSame(2, DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_virtual_generate')->where('status', 'active')->count());
        $this->assertSame(23, (int) DB::table('stock_supply_profiles')->where('game_id', 'gam_virtual_generate')->value('total_capacity'));

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/generation-batches?'.http_build_query([
                'game_id' => 'gam_virtual_generate',
                'sort_by' => 'generated_count',
                'sort_dir' => 'asc',
                'limit' => 1,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $secondBatch['id'])
            ->assertJsonPath('meta.sort_by', 'generated_count')
            ->assertJsonPath('meta.sort_dir', 'asc');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/generation-batches?'.http_build_query([
                'game_id' => 'gam_virtual_generate',
                'sort_by' => 'generated_count',
                'sort_dir' => 'desc',
                'limit' => 1,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $batch['id'])
            ->assertJsonPath('meta.sort_by', 'generated_count')
            ->assertJsonPath('meta.sort_dir', 'desc');
    }

    public function test_physical_quota_generation_payloads_are_retired(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_virtual_only', 'open');
        $login = $this->createCentralSession(['stock.generate'], 'adm_virtual_only', 'virtual-only@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_only',
                'total_count' => 1000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'retired-physical-generate',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.generation_mode.0', 'The generation_mode field must be virtual_profile.')
            ->assertJsonPath('error.details.fields.total_count.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_only',
                'generation_mode' => 'quota_random',
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'retired-quota-generate',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.generation_mode.0', 'The generation_mode field must be virtual_profile.')
            ->assertJsonPath('error.details.fields.back2_count_per_number.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.');

        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_virtual_only')->count());
        $this->assertSame(0, DB::table('stock_generation_batches')->where('game_id', 'gam_virtual_only')->where('type', 'generate')->count());
        $this->assertSame(0, DB::table('stock_supply_profiles')->where('game_id', 'gam_virtual_only')->count());
    }

    public function test_virtual_stock_summary_handles_low_pattern_limits_after_generation(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_virtual_low_limits', 'open');
        $this->insertActivePartnerTenantWithDomain('par_virtual_low_limits', 'ten_virtual_low_limits', 'low-limits.newpaotang.test');
        $this->insertBaseLotteryNumbers([
            '000000',
            '000001',
            '000002',
            '001000',
            '001001',
            '001002',
            '002000',
            '002001',
            '002002',
            '123456',
        ]);
        $login = $this->createCentralSession(['stock.generate', 'stock.view'], 'adm_virtual_low_limits', 'virtual-low-limits@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_virtual_low_limits',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [
                    ['set_size' => 2, 'percent' => 10],
                    ['set_size' => 3, 'percent' => 15],
                ],
                'partner_distribution' => [
                    ['partner_id' => 'par_virtual_low_limits', 'percent' => 100],
                ],
                'central_limits' => ['back2_limit' => 1, 'back3_limit' => 1, 'front3_limit' => 1],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-low-limits-generate',
            ])
            ->assertAccepted()
            ->assertJsonPath('requested_count', 13)
            ->assertJsonPath('generated_count', 13);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?game_id=gam_virtual_low_limits', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('stock_mode', 'virtual')
            ->assertJsonPath('total_count', 13)
            ->assertJsonPath('status_counts.total', 13)
            ->assertJsonPath('pattern_totals.back2.limit_total', 100)
            ->assertJsonPath('pattern_totals.back3.limit_total', 1000)
            ->assertJsonPath('pattern_totals.front3.limit_total', 1000);
    }

    public function test_central_stock_grouped_table_and_summary_show_virtual_profile_when_physical_stock_is_empty(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_virtual_table', 'open');
        $this->insertActivePartnerTenantWithDomain('par_virtual_table', 'ten_virtual_table', 'virtual-table.newpaotang.test');
        $this->insertVirtualProfile('gam_virtual_table');
        $this->insertPartnerDistribution('gam_virtual_table', 'par_virtual_table', 'ten_virtual_table', 10000);
        $this->insertBaseLotteryNumbers(['000000', '000001', '123456']);
        $this->insertVirtualCounter('gam_virtual_table', '000000', reserved: 1, sold: 0);
        $this->insertVirtualCounter('gam_virtual_table', '123456', reserved: 0, sold: 1);
        $this->insertVirtualPatternCounter('gam_virtual_table', 'back2', '00', reserved: 1, sold: 2);
        $this->insertVirtualPatternCounter('gam_virtual_table', 'front3', '123', reserved: 0, sold: 1);
        $this->insertVirtualPatternCounter('gam_virtual_table', 'back3', '456', reserved: 0, sold: 1);
        $login = $this->createCentralSession(['stock.view'], 'adm_virtual_table', 'virtual-table@example.test');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'grouped' => true,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(3, 'data')
            ->assertJsonPath('data.0.stock_mode', 'virtual')
            ->assertJsonPath('data.0.full_number', '000000')
            ->assertJsonPath('data.0.total_count', 1)
            ->assertJsonPath('data.0.available_count', 0)
            ->assertJsonPath('data.0.allocated_count', 1)
            ->assertJsonPath('data.0.sold_count', 0)
            ->assertJsonPath('data.1.full_number', '000001')
            ->assertJsonPath('data.1.available_count', 1);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'grouped' => true,
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123456')
            ->assertJsonPath('meta.sort_by', 'full_number')
            ->assertJsonPath('meta.sort_dir', 'desc');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'grouped' => true,
                'sort_by' => 'sold_count',
                'sort_dir' => 'desc',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123456')
            ->assertJsonPath('data.0.sold_count', 1)
            ->assertJsonPath('meta.sort_by', 'sold_count')
            ->assertJsonPath('meta.sort_dir', 'desc');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'grouped' => true,
                'number' => '123456',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.full_number', '123456')
            ->assertJsonPath('data.0.available_count', 0)
            ->assertJsonPath('data.0.sold_count', 1);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?game_id=gam_virtual_table', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('stock_mode', 'virtual')
            ->assertJsonPath('total_count', 1000000)
            ->assertJsonPath('status_counts.available', 49997)
            ->assertJsonPath('status_counts.allocated', 1)
            ->assertJsonPath('status_counts.sold', 1)
            ->assertJsonPath('pattern_totals.back2.sold_count', 2)
            ->assertJsonPath('pattern_totals.front3.sold_count', 1)
            ->assertJsonPath('pattern_totals.back2.generated_count', 3)
            ->assertJsonPath('pattern_totals.back2.limit_total', 50000)
            ->assertJsonPath('pattern_totals.back2.sellable_remaining_count', 2)
            ->assertJsonPath('number_coverage.back2.total_count', 3)
            ->assertJsonPath('empty', false);

        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_virtual_table')->count());

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/patterns?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'dimension' => 'back2',
                'q' => '00',
                'limit' => 5,
                'sort_by' => 'sold_count',
                'sort_dir' => 'desc',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('game_id', 'gam_virtual_table')
            ->assertJsonPath('totals.back2.sold_count', 2)
            ->assertJsonPath('totals.back2.reserved_count', 1)
            ->assertJsonPath('meta.dimension', 'back2')
            ->assertJsonPath('meta.sort_by', 'sold_count')
            ->assertJsonPath('meta.sort_dir', 'desc')
            ->assertJsonPath('data.0.number', '00')
            ->assertJsonPath('data.0.sold_count', 2)
            ->assertJsonPath('data.0.reserved_count', 1);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/patterns?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'dimension' => 'front3',
                'q' => '123',
                'sort_by' => 'number',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.dimension', 'front3')
            ->assertJsonPath('data.0.number', '123')
            ->assertJsonPath('data.0.sold_count', 1);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/patterns?'.http_build_query([
                'game_id' => 'gam_virtual_table',
                'dimension' => 'back3',
                'q' => '456',
                'sort_by' => 'remaining_limit',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.dimension', 'back3')
            ->assertJsonPath('data.0.number', '456')
            ->assertJsonPath('data.0.sold_count', 1);

        $generateLogin = $this->createCentralSession(['stock.generate', 'stock.view'], 'adm_virtual_override', 'virtual-override@example.test');
        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-settings', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'central',
                'scope_id' => 'central',
                'back2_limit' => 2,
                'back3_limit' => 1,
                'front3_limit' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-settings-central-over-supply',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.back2_limit.0', 'The back2_limit field may not exceed generated stock of 1. Generate or top up stock before increasing this limit.');

        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-settings', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'central',
                'scope_id' => 'central',
                'back2_limit' => 1,
                'back3_limit' => 1,
                'front3_limit' => null,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-settings-central-unlimited',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.front3_limit.0', 'The front3_limit field is required and cannot be unlimited.');

        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-settings', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'central',
                'scope_id' => 'central',
                'back2_limit' => 1,
                'back3_limit' => 1,
                'front3_limit' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-settings-central',
            ])
            ->assertOk()
            ->assertJsonPath('limits.back2_limit', 1)
            ->assertJsonPath('limits.back3_limit', 1)
            ->assertJsonPath('limits.front3_limit', 1)
            ->assertJsonPath('data.0.default_limit', 1)
            ->assertJsonPath('data.0.remaining_limit', 0);

        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-settings', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'partner',
                'scope_id' => 'par_virtual_table',
                'back2_limit' => 7,
                'back3_limit' => 8,
                'front3_limit' => 9,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-settings-partner',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.back2_limit.0', 'The back2_limit field may not exceed the central effective limit of 1.');

        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-settings', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'partner',
                'scope_id' => 'par_virtual_table',
                'back2_limit' => 1,
                'back3_limit' => 1,
                'front3_limit' => 1,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-settings-partner-valid',
            ])
            ->assertOk()
            ->assertJsonPath('scope_type', 'partner')
            ->assertJsonPath('scope_id', 'par_virtual_table')
            ->assertJsonPath('limits.back2_limit', 1)
            ->assertJsonPath('data.0.default_limit', 1);

        $invalidCentralOverride = $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-overrides', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'central',
                'scope_id' => 'central',
                'dimension' => 'back2',
                'overrides' => [
                    ['value' => '00', 'limit' => 2],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-override-central-over-supply',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->json();
        $this->assertSame(
            'The override limit may not exceed generated stock of 1. Generate or top up stock before increasing this limit.',
            $invalidCentralOverride['error']['details']['fields']['overrides.0.limit'][0] ?? null,
        );

        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-overrides', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'central',
                'scope_id' => 'central',
                'dimension' => 'back2',
                'overrides' => [
                    ['value' => '00', 'limit' => 1],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-override-central',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.number', '00')
            ->assertJsonPath('data.0.override_limit', 1)
            ->assertJsonPath('data.0.limit', 1)
            ->assertJsonPath('data.0.remaining_limit', 0);

        $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-overrides', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'partner',
                'scope_id' => 'par_virtual_table',
                'dimension' => 'back2',
                'overrides' => [
                    ['value' => '00', 'limit' => 1],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-override-partner',
            ])
            ->assertOk()
            ->assertJsonPath('scope_type', 'partner')
            ->assertJsonPath('scope_id', 'par_virtual_table')
            ->assertJsonPath('data.0.override_limit', 1)
            ->assertJsonPath('data.0.limit', 1);

        $invalidOverride = $this->withToken($generateLogin['access_token'])
            ->putJson('/api/v1/admin/central/stock/limit-overrides', [
                'game_id' => 'gam_virtual_table',
                'scope_type' => 'partner',
                'scope_id' => 'par_virtual_table',
                'dimension' => 'back2',
                'overrides' => [
                    ['value' => '00', 'limit' => 3],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'virtual-limit-override-partner-invalid',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->json();
        $this->assertSame(
            'validation_failed',
            $invalidOverride['error']['code'] ?? null,
        );
        $this->assertNotEmpty($invalidOverride['error']['details']['fields'] ?? []);
    }

    public function test_central_stock_virtual_grouped_total_count_sort_and_full_number_detail(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_virtual_detail', 'open');
        $this->insertActivePartnerTenantWithDomain('par_virtual_detail', 'ten_virtual_detail', 'virtual-detail.newpaotang.test');
        $numbers = ['000000', '000001', '000002', '123456', '555555'];
        $distribution = [['set_size' => 3, 'percent_basis_points' => 5000]];
        $this->insertBaseLotteryNumbers($numbers);
        $this->insertVirtualProfile('gam_virtual_detail', $distribution);
        $this->insertPartnerDistribution('gam_virtual_detail', 'par_virtual_detail', 'ten_virtual_detail', 10000);
        $this->insertSaleLimit('gam_virtual_detail', 'central', 'central', back2: 10, back3: 10, front3: 10);
        $this->insertSaleLimit('gam_virtual_detail', 'partner', 'par_virtual_detail', back2: 5, back3: 5, front3: 5);
        $this->insertScopedVirtualCounter('gam_virtual_detail', 'central', 'central', 'full_number', '123456', reserved: 1, sold: 0);
        $this->insertScopedVirtualCounter('gam_virtual_detail', 'central', 'central', 'back2', '56', reserved: 1, sold: 0);
        $this->insertScopedVirtualCounter('gam_virtual_detail', 'central', 'central', 'back3', '456', reserved: 1, sold: 0);
        $this->insertScopedVirtualCounter('gam_virtual_detail', 'central', 'central', 'front3', '123', reserved: 1, sold: 0);
        $this->insertScopedVirtualCounter('gam_virtual_detail', 'partner', 'par_virtual_detail', 'full_number', '123456', reserved: 1, sold: 0);

        DB::table('stock_items')->insert([
            'id' => 'stk_virtual_detail_0',
            'game_id' => 'gam_virtual_detail',
            'batch_id' => null,
            'full_number' => '123456',
            'front3' => '123',
            'back3' => '456',
            'back2' => '56',
            'status' => 'allocated',
            'partner_id' => 'par_virtual_detail',
            'tenant_id' => 'ten_virtual_detail',
            'allocation_id' => null,
            'virtual_stock_ref' => 'ten_virtual_detail:gam_virtual_detail:123456:0',
            'virtual_copy_index' => 0,
            'image_url' => 'https://cdn.example.test/central/123456.png',
            'image_thumb_url' => 'https://cdn.example.test/central/123456-thumb.png',
            'image_generation_status' => 'completed',
            'image_generation_error' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('local_stock_items')->insert([
            'id' => 'lsi_virtual_detail_0',
            'tenant_id' => 'ten_virtual_detail',
            'partner_id' => 'par_virtual_detail',
            'store_id' => 'ten_virtual_detail',
            'game_id' => 'gam_virtual_detail',
            'stock_item_id' => 'stk_virtual_detail_0',
            'allocation_id' => null,
            'virtual_stock_ref' => 'ten_virtual_detail:gam_virtual_detail:123456:0',
            'virtual_copy_index' => 0,
            'full_number' => '123456',
            'front3' => '123',
            'back3' => '456',
            'back2' => '56',
            'image_url' => 'https://cdn.example.test/local/123456.png',
            'image_thumb_url' => 'https://cdn.example.test/local/123456-thumb.png',
            'image_generation_status' => 'completed',
            'image_generation_error' => null,
            'status' => 'reserved',
            'synced_at' => now(),
            'reserved_at' => now(),
            'sold_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $login = $this->createCentralSession(['stock.view'], 'adm_virtual_detail', 'virtual-detail@example.test');
        $expected = collect($numbers)
            ->map(fn (string $number): array => ['number' => $number, 'capacity' => $this->capacityForNumber($number, 'virtual-test-seed', $distribution)])
            ->sortBy([
                ['capacity', 'desc'],
                ['number', 'asc'],
            ])
            ->values()
            ->all();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_virtual_detail',
                'grouped' => true,
                'sort_by' => 'total_count',
                'sort_dir' => 'desc',
                'limit' => 5,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.sort_by', 'total_count')
            ->assertJsonPath('data.0.full_number', $expected[0]['number'])
            ->assertJsonPath('data.0.total_count', $expected[0]['capacity']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/gam_virtual_detail/numbers/123456?'.http_build_query([
                'scope_type' => 'partner',
                'scope_id' => 'par_virtual_detail',
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('stock_mode', 'virtual')
            ->assertJsonPath('full_number', '123456')
            ->assertJsonPath('generated_capacity', $this->capacityForNumber('123456', 'virtual-test-seed', $distribution))
            ->assertJsonPath('materialized_stock_count', 1)
            ->assertJsonPath('stock_items.0.image_url', 'https://cdn.example.test/central/123456.png')
            ->assertJsonPath('stock_items.0.owner.type', 'partner')
            ->assertJsonPath('stock_items.0.owner.label', 'Partner par_virtual_detail')
            ->assertJsonPath('local_stock_items.0.image_url', 'https://cdn.example.test/local/123456.png')
            ->assertJsonPath('local_stock_items.0.owner.type', 'partner')
            ->assertJsonPath('local_stock_items.0.owner.label', 'Partner par_virtual_detail')
            ->assertJsonPath('virtual_copies.0.owner.type', 'partner')
            ->assertJsonPath('virtual_copies.0.owner.label', 'Partner par_virtual_detail')
            ->assertJsonPath('virtual_copies.0.owner_label', 'Partner par_virtual_detail')
            ->assertJsonPath('virtual_copies.0.materialized', true)
            ->assertJsonPath('virtual_copies.0.image_url', 'https://cdn.example.test/local/123456.png')
            ->assertJsonPath('central_limits.limits.back2.value', '56')
            ->assertJsonPath('partner_limits.scope_id', 'par_virtual_detail');
    }

    public function test_virtual_stock_search_reservation_limits_and_realtime_delta(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_virtual', 'ten_virtual', 'virtual.newpaotang.test');
        $this->insertGame('gam_virtual', 'open');
        $this->insertBaseLotteryNumbers(['123456']);
        $this->insertVirtualProfile('gam_virtual');
        $this->insertPartnerDistribution('gam_virtual', 'par_virtual', 'ten_virtual', 10000);
        $this->insertSaleLimit('gam_virtual', 'central', 'central', back2: 1, back3: 10, front3: 10);

        Event::fake([StockAvailabilityUpdated::class, StockCoverageUpdated::class, StockTableUpdated::class]);

        $search = $this->getJson('http://virtual.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual&number=123456&limit=5')
            ->assertOk()
            ->assertJsonPath('meta.stock_mode', 'virtual')
            ->assertJsonPath('data.0.full_number', '123456')
            ->assertJsonPath('data.0.remaining_count', 1)
            ->json('data.0');

        $customerToken = $this->issueCustomerToken('ten_virtual', 'cus_virtual');
        $reservation = $this->withToken($customerToken)
            ->postJson('http://virtual.newpaotang.test/api/v1/customer/reservations', [
                'game_id' => 'gam_virtual',
                'local_stock_item_ids' => [$search['id']],
            ], ['Idempotency-Key' => 'virtual-reserve-1'])
            ->assertCreated()
            ->assertJsonPath('items.0.full_number', '123456')
            ->assertJsonPath('items.0.stock_mode', 'virtual')
            ->json();

        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_virtual')->whereNull('virtual_stock_ref')->count());
        $this->assertSame(1, DB::table('stock_items')->where('game_id', 'gam_virtual')->whereNotNull('virtual_stock_ref')->count());

        $this->getJson('http://virtual.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual&number=123456&limit=5')
            ->assertOk()
            ->assertJsonCount(0, 'data');

        Event::assertDispatched(StockAvailabilityUpdated::class, fn (StockAvailabilityUpdated $event): bool => (
            ($event->payload['full_number'] ?? null) === '123456'
            && ($event->payload['remaining_count'] ?? null) === 0
            && ($event->payload['status'] ?? null) === 'sold_out'
        ));
        Event::assertDispatched(StockCoverageUpdated::class, function (StockCoverageUpdated $event): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'stock.coverage.updated'
                && ($event->payload['game_id'] ?? null) === 'gam_virtual'
                && ($event->payload['scope_type'] ?? null) === 'central'
                && ($event->payload['dimension'] ?? null) === 'back2'
                && ($event->payload['number'] ?? null) === '56'
                && ($event->payload['reserved_count'] ?? null) === 1
                && ($event->payload['sellable_remaining_count'] ?? null) === 0
                && in_array('private-admin.central.stock.coverage.game.gam_virtual', $channels, true);
        });
        Event::assertDispatched(StockTableUpdated::class, function (StockTableUpdated $event): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'stock.table.updated'
                && ($event->payload['game_id'] ?? null) === 'gam_virtual'
                && ($event->payload['refresh_required'] ?? null) === false
                && ($event->payload['row']['full_number'] ?? null) === '123456'
                && ($event->payload['row']['allocated_count'] ?? null) === 1
                && ($event->payload['row']['available_count'] ?? null) === 0
                && in_array('private-admin.central.stock.table.game.gam_virtual', $channels, true);
        });

        $this->withToken($customerToken)
            ->postJson('http://virtual.newpaotang.test/api/v1/customer/reservations/'.$reservation['id'].'/release', [], [
                'Idempotency-Key' => 'virtual-release-1',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'released');

        $this->getJson('http://virtual.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual&number=123456&limit=5')
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '123456')
            ->assertJsonPath('data.0.remaining_count', 1);

        $this->insertLimitOverride('gam_virtual', 'central', 'central', 'back2', '56', 0);

        $this->getJson('http://virtual.newpaotang.test/api/v1/public/stock/search?game_id=gam_virtual&number=123456&limit=5')
            ->assertOk()
            ->assertJsonCount(0, 'data');
    }

    /**
     * @param array<int, array{set_size: int, percent_basis_points: int}> $distribution
     */
    private function insertVirtualProfile(string $gameId, array $distribution = []): void
    {
        $numbers = DB::table('base_lottery_numbers')->pluck('full_number')->all();
        $baseCount = $numbers === [] ? 1000000 : count($numbers);
        $totalCapacity = $numbers === [] ? 1000000 : 0;
        foreach ($numbers as $number) {
            $totalCapacity += $this->capacityForNumber((string) $number, 'virtual-test-seed', $distribution);
        }

        DB::table('stock_supply_profiles')->insert([
            'id' => 'vsp_'.$gameId,
            'game_id' => $gameId,
            'status' => 'active',
            'seed' => 'virtual-test-seed',
            'base_count' => $baseCount,
            'total_capacity' => $totalCapacity,
            'set_distribution_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, string> $numbers
     */
    private function insertBaseLotteryNumbers(array $numbers): void
    {
        $rows = [];
        foreach ($numbers as $number) {
            $rows[] = [
                'full_number' => $number,
                'front3' => substr($number, 0, 3),
                'back3' => substr($number, -3),
                'back2' => substr($number, -2),
                'created_at' => now(),
                'updated_at' => now(),
            ];
        }

        DB::table('base_lottery_numbers')->insert($rows);
    }

    private function insertVirtualCounter(string $gameId, string $number, int $reserved, int $sold): void
    {
        $this->insertScopedVirtualCounter($gameId, 'central', 'central', 'full_number', $number, $reserved, $sold);
    }

    private function insertVirtualPatternCounter(string $gameId, string $dimension, string $value, int $reserved, int $sold): void
    {
        $this->insertScopedVirtualCounter($gameId, 'central', 'central', $dimension, $value, $reserved, $sold);
    }

    private function insertScopedVirtualCounter(string $gameId, string $scopeType, string $scopeId, string $dimension, string $value, int $reserved, int $sold): void
    {
        DB::table('virtual_stock_counters')->insert([
            'id' => 'vsc_'.substr(sha1($gameId.':'.$scopeType.':'.$scopeId.':'.$dimension.':'.$value), 0, 20),
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'dimension' => $dimension,
            'value' => $value,
            'reserved_count' => $reserved,
            'sold_count' => $sold,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertPartnerDistribution(string $gameId, string $partnerId, string $tenantId, int $basisPoints): void
    {
        DB::table('stock_partner_distributions')->insert([
            'id' => 'spd_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'game_id' => $gameId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'percent_basis_points' => $basisPoints,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $profileId = (string) DB::table('stock_supply_profiles')->where('game_id', $gameId)->value('id');
        $layerIds = DB::table('virtual_stock_supply_layers')
            ->where('profile_id', $profileId)
            ->where('status', 'active')
            ->orderBy('created_at')
            ->orderBy('id')
            ->pluck('id')
            ->map(fn (mixed $value): string => (string) $value)
            ->all();
        if ($layerIds === [] && $profileId !== '') {
            $layerIds = [$profileId];
        }

        DB::table('partner_stock_allocations')->insert([
            'id' => 'alc_'.substr(sha1($gameId.':'.$partnerId), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => (int) floor(((int) DB::table('stock_supply_profiles')->where('id', $profileId)->value('total_capacity') * $basisPoints) / 10000),
            'allocation_percent_basis_points' => $basisPoints,
            'supply_layer_ids_json' => json_encode($layerIds, JSON_THROW_ON_ERROR),
            'allocated_count' => (int) floor(((int) DB::table('stock_supply_profiles')->where('id', $profileId)->value('total_capacity') * $basisPoints) / 10000),
            'recalled_count' => 0,
            'idempotency_key' => 'fixture-'.$gameId.'-'.$partnerId,
            'payload_hash' => hash('sha256', $gameId.':'.$partnerId),
            'created_by_admin_id' => null,
            'reason' => null,
            'cancelled_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, array{set_size: int, percent_basis_points: int}> $distribution
     */
    private function capacityForNumber(string $fullNumber, string $seed, array $distribution): int
    {
        $score = (int) hexdec(substr(hash('sha256', $seed.':'.$fullNumber.':set'), 0, 8)) % 10000;
        $cursor = 0;

        foreach ($distribution as $row) {
            $cursor += (int) $row['percent_basis_points'];
            if ($score < $cursor) {
                return max(1, (int) $row['set_size']);
            }
        }

        return 1;
    }

    private function insertLimitOverride(string $gameId, string $scopeType, string $scopeId, string $dimension, string $value, int $limit): void
    {
        DB::table('stock_sale_limit_overrides')->insert([
            'id' => 'vso_'.$gameId.'_'.$scopeType.'_'.$dimension.'_'.$value,
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'dimension' => $dimension,
            'value' => $value,
            'limit' => $limit,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertSaleLimit(string $gameId, string $scopeType, string $scopeId, int $back2, int $back3, int $front3): void
    {
        DB::table('stock_sale_limit_settings')->insert([
            'id' => 'vsl_'.$gameId.'_'.$scopeType,
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'back2_limit' => $back2,
            'back3_limit' => $back3,
            'front3_limit' => $front3,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
