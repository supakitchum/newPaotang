<?php

namespace Tests\Feature;

use App\Jobs\DispatchStockBatchImageJobs;
use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GenerateStockBatchChunkJob;
use App\Modules\CentralStock\Events\StockGenerationProgressUpdated;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Queue;
use Tests\Support\CentralStockFixtures;
use Tests\TestCase;

class CentralStockTest extends TestCase
{
    use CentralStockFixtures;
    use RefreshDatabase;

    public function test_CentralStock_generate_import_export_list_and_recall_are_permissioned_safe_and_audited(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_main', 'open');
        $this->insertGame('gam_stock_import', 'open');

        $limitedLogin = $this->createCentralSession(['stock.view'], 'adm_stock_limited', 'stock-limited@example.test');

        $this->withToken($limitedLogin['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-limited',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->createCentralSession([
            'stock.view',
            'stock.generate',
            'stock.export',
            'stock.recall',
        ], 'adm_stock', 'stock@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->insertBaseLotteryNumbers(['000000', '000001', '000002']);

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'virtual_profile')
            ->assertJsonPath('stock_mode', 'virtual')
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('generated_count', 3)
            ->json();

        $repeatBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-main',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($batch['id'], $repeatBatch['id']);
        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());
        $this->assertSame(1, DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_stock_main')->count());

        $largeBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-large',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 3)
            ->assertJsonPath('top_up', true)
            ->assertJsonPath('total_capacity', 6)
            ->json();

        $this->assertNotSame($batch['id'], $largeBatch['id']);
        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());
        $this->assertSame(2, DB::table('virtual_stock_supply_layers')->where('game_id', 'gam_stock_main')->count());

        $virtualTicketSort = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_main',
                'grouped' => true,
                'sort_by' => 'tickets',
                'sort_dir' => 'desc',
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.sort_by', 'total_count')
            ->assertJsonPath('meta.sort_dir', 'desc')
            ->assertJsonCount(2, 'data')
            ->json();

        $this->assertGreaterThanOrEqual(
            (int) $virtualTicketSort['data'][1]['total_count'],
            (int) $virtualTicketSort['data'][0]['total_count'],
        );

        $import = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/imports', [
                'game_id' => 'gam_stock_import',
                'items' => [
                    ['full_number' => '000010'],
                    ['full_number' => '000011'],
                    ['full_number' => '000011'],
                    ['full_number' => '000012'],
                    ['full_number' => '000013'],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-import-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'import')
            ->assertJsonPath('generated_count', 5)
            ->json();

        $this->assertSame(5, DB::table('stock_items')->where('game_id', 'gam_stock_import')->count());
        $this->assertSame(2, DB::table('stock_items')->where('game_id', 'gam_stock_import')->where('full_number', '000011')->count());

        $grouped = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_import&grouped=true&number=000011', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.full_number', '000011')
            ->assertJsonPath('data.0.total_count', 2)
            ->assertJsonPath('data.0.available_count', 2)
            ->json();

        $this->assertNotEmpty($grouped['data'][0]['sample_stock_item_id']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_import&grouped=true&front3=000&limit=2', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.has_more', true);

        $sortedGroups = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_import',
                'grouped' => true,
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000013')
            ->assertJsonPath('data.1.full_number', '000012')
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_import',
                'grouped' => true,
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'cursor' => $sortedGroups['meta']['next_cursor'],
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000011');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_import&status=available&limit=2', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.has_more', true);

        $sortedTickets = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_import',
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000013')
            ->assertJsonPath('data.1.full_number', '000012')
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_import',
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'cursor' => $sortedTickets['meta']['next_cursor'],
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000011');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/exports', [
                'game_id' => 'gam_stock_import',
                'filters' => ['status' => 'available'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-export-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'export')
            ->assertJsonPath('status', 'pending');

        $stockItemId = (string) DB::table('stock_items')
            ->where('game_id', 'gam_stock_import')
            ->where('full_number', '000010')
            ->value('id');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/'.$stockItemId.'/recall', [
                'reason' => 'bad_print',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-recall-available',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'recalled')
            ->assertJsonPath('recall_reason', 'bad_print');

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'stock.recalled',
            'target_id' => $stockItemId,
        ]);
        $this->assertDatabaseMissing('sync_outbox', ['event_type' => 'stock.recalled.v1']);

        $generatedAuditPayloads = DB::table('audit_logs')
            ->where('action', 'stock.generated')
            ->where('target_id', $batch['id'])
            ->orderBy('created_at')
            ->pluck('payload_redacted_json')
            ->map(fn (string $payload): array => json_decode($payload, true, flags: JSON_THROW_ON_ERROR))
            ->all();

        $secretValues = array_map(
            fn (array $auditPayload): ?string => $auditPayload['payload']['api_secret'] ?? null,
            $generatedAuditPayloads,
        );

        $this->assertContains('[REDACTED]', $secretValues);
        $this->assertNotContains('redact-me', $secretValues);
        $this->assertNotSame($batch['id'], $import['id']);
    }

    public function test_CentralStock_old_games_are_view_only_for_stock_changes(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_old', 'closed');
        $this->insertGame('gam_stock_current', 'open');
        $this->insertBaseLotteryNumbers(['000000', '000001']);
        $this->insertStockItems('gam_stock_old', 1, 42);

        $login = $this->createCentralSession([
            'stock.view',
            'stock.generate',
            'stock.recall',
        ], 'adm_stock_old', 'stock-old@example.test');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_old&limit=5', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.game_id', 'gam_stock_old');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_old',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-old',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.game_id.0', 'The game_id field must reference an open game.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/imports', [
                'game_id' => 'gam_stock_old',
                'items' => [
                    ['full_number' => '000099'],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-import-old',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.game_id.0', 'The game_id field must reference an open game.');

        $stockItemId = (string) DB::table('stock_items')
            ->where('game_id', 'gam_stock_old')
            ->value('id');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/'.$stockItemId.'/recall', [
                'reason' => 'old_draw_recall',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-recall-old',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'resource_conflict');

        $this->assertDatabaseHas('stock_items', [
            'id' => $stockItemId,
            'status' => 'available',
            'recall_reason' => null,
        ]);
    }

    public function test_CentralStock_summary_widgets_aggregate_coverage_filters_and_permissions(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_summary', 'open');
        $this->insertGame('gam_stock_empty', 'open');

        $generateLogin = $this->createCentralSession(['stock.generate'], 'adm_sum_gen', 'sum-gen@example.test');
        $viewLogin = $this->createCentralSession(['stock.view'], 'adm_sum_view', 'sum-view@example.test');
        $deniedLogin = $this->createCentralSession([], 'adm_sum_none', 'sum-none@example.test');
        $this->createPartner('par_sum');
        $this->createTenant('ten_sum', 'par_sum');
        $this->createAdmin('adm_sum_ten', 'sum-tenant@example.test');
        $this->createAdminScope('scp_adm_sum_ten', 'tenant', 'ten_sum', 'par_sum');
        $this->assignRoleWithPermissions('adm_sum_ten', 'scp_adm_sum_ten', 'tenant', 'ten_sum', ['stock.view'], 'tenant_sum');
        $tenantLogin = $this->loginAdmin([
            'email' => 'sum-tenant@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_sum',
        ]);

        $batch = ['id' => 'stb_stock_summary_main'];
        $this->insertMaterializedStockBatch('gam_stock_summary', $batch['id'], 3);

        $statusStockIds = DB::table('stock_items')
            ->where('batch_id', $batch['id'])
            ->orderBy('id')
            ->limit(4)
            ->pluck('id')
            ->values()
            ->all();

        $this->assertCount(4, $statusStockIds);

        foreach (['allocated', 'sold', 'recalled', 'voided'] as $index => $status) {
            DB::table('stock_items')
                ->where('id', $statusStockIds[$index])
                ->update(['status' => $status, 'updated_at' => now()]);
        }

        $this->insertMaterializedStockBatch('gam_stock_summary', 'stb_stock_summary_extra', 1);

        $batchSummary = $this->withToken($generateLogin['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?'.http_build_query([
                'game_id' => 'gam_stock_summary',
                'batch_id' => $batch['id'],
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('game_id', 'gam_stock_summary')
            ->assertJsonPath('batch_id', $batch['id'])
            ->assertJsonPath('total_count', 3000)
            ->assertJsonPath('status_counts.available', 2996)
            ->assertJsonPath('status_counts.allocated', 1)
            ->assertJsonPath('status_counts.sold', 1)
            ->assertJsonPath('status_counts.recalled', 1)
            ->assertJsonPath('status_counts.voided', 1)
            ->assertJsonPath('status_counts.total', 3000)
            ->assertJsonPath('number_coverage.back2.expected_distinct', 100)
            ->assertJsonPath('number_coverage.back2.distinct_count', 100)
            ->assertJsonPath('number_coverage.back2.missing_distinct_count', 0)
            ->assertJsonPath('number_coverage.back2.min_count_per_number', 30)
            ->assertJsonPath('number_coverage.back2.max_count_per_number', 30)
            ->assertJsonPath('number_coverage.back2.total_count', 3000)
            ->assertJsonPath('number_coverage.back3.expected_distinct', 1000)
            ->assertJsonPath('number_coverage.back3.distinct_count', 1000)
            ->assertJsonPath('number_coverage.back3.min_count_per_number', 3)
            ->assertJsonPath('number_coverage.back3.max_count_per_number', 3)
            ->assertJsonPath('number_coverage.front3.expected_distinct', 1000)
            ->assertJsonPath('number_coverage.front3.distinct_count', 1000)
            ->assertJsonPath('number_coverage.front3.min_count_per_number', 3)
            ->assertJsonPath('number_coverage.front3.max_count_per_number', 3)
            ->assertJsonPath('empty', false)
            ->json();

        $this->assertSame(3000, $batchSummary['number_coverage']['back3']['total_count']);
        $this->assertSame(3000, $batchSummary['number_coverage']['front3']['total_count']);

        $this->withToken($viewLogin['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?game_id=gam_stock_summary', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('batch_id', null)
            ->assertJsonPath('total_count', 4000)
            ->assertJsonPath('status_counts.available', 3996)
            ->assertJsonPath('status_counts.total', 4000);

        $this->withToken($viewLogin['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?game_id=gam_stock_empty', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('game_id', 'gam_stock_empty')
            ->assertJsonPath('total_count', 0)
            ->assertJsonPath('empty', true)
            ->assertJsonPath('status_counts.available', 0)
            ->assertJsonPath('status_counts.total', 0)
            ->assertJsonPath('number_coverage.back2.distinct_count', 0)
            ->assertJsonPath('number_coverage.back2.missing_distinct_count', 100)
            ->assertJsonPath('number_coverage.back2.min_count_per_number', 0)
            ->assertJsonPath('number_coverage.back2.max_count_per_number', 0)
            ->assertJsonPath('number_coverage.back2.total_count', 0);

        $this->withToken($deniedLogin['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?game_id=gam_stock_summary', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?game_id=gam_stock_summary', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_sum',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_CentralStock_partner_pattern_coverage_uses_precomputed_virtual_generated_counts(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_partner_patterns', 'open');
        $this->insertActivePartnerTenant('par_patterns', 'ten_patterns');
        $this->insertBaseLotteryNumbers(['000000', '000001', '000002', '000003']);

        $login = $this->createCentralSession([
            'stock.view',
            'stock.generate',
            'stock.allocate',
        ], 'adm_stock_patterns', 'stock-patterns@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_partner_patterns',
                'generation_mode' => 'virtual_profile',
                'set_distribution' => [],
                'partner_distribution' => [
                    ['partner_id' => 'par_patterns', 'percent' => 100],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-partner-patterns',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 4);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/allocations', [
                'partner_id' => 'par_patterns',
                'tenant_id' => 'ten_patterns',
                'game_id' => 'gam_stock_partner_patterns',
                'allocation_percent' => 100,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-partner-pattern-allocation',
            ])
            ->assertAccepted()
            ->assertJsonPath('allocated_count', 4);

        $this->assertSame(
            4,
            (int) DB::table('virtual_stock_pattern_generated_counts')
                ->where('game_id', 'gam_stock_partner_patterns')
                ->where('scope_type', 'partner')
                ->where('scope_id', 'par_patterns')
                ->where('dimension', 'back2')
                ->sum('generated_count'),
        );

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/patterns?'.http_build_query([
                'game_id' => 'gam_stock_partner_patterns',
                'scope_type' => 'partner',
                'partner_id' => 'par_patterns',
                'dimension' => 'back2',
                'limit' => 5,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('scope_type', 'partner')
            ->assertJsonPath('scope_id', 'par_patterns')
            ->assertJsonPath('totals.back2.generated_count', 4)
            ->assertJsonPath('data.0.number', '00')
            ->assertJsonPath('data.0.generated_count', 1);
    }

    public function test_CentralStock_retired_physical_generation_does_not_create_async_chunks_or_image_jobs(): void
    {
        Queue::fake();
        Event::fake([StockGenerationProgressUpdated::class]);

        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_async', 'open');

        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_async', 'stock-async@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_async',
                'total_count' => 12000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-async-main',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.total_count.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.');

        $this->assertSame(0, DB::table('stock_generation_batch_chunks')->count());
        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_stock_async')->count());
        Queue::assertNotPushed(GenerateStockBatchChunkJob::class);
        Queue::assertNotPushed(GenerateLotteryImageJob::class);
        Queue::assertNotPushed(DispatchStockBatchImageJobs::class);
        Event::assertNotDispatched(StockGenerationProgressUpdated::class);
    }

    public function test_CentralStock_generate_rejects_retired_quota_physical_and_legacy_ranges(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_validation', 'open');

        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_validation', 'stock-validation@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'generation_mode' => 'quota_random',
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-quota-retired'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.generation_mode.0', 'The generation_mode field must be virtual_profile.')
            ->assertJsonPath('error.details.fields.back2_count_per_number.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'total_count' => 3000,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-total-retired'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.total_count.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'start_number' => 1,
                'count' => 10,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-legacy'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.start_number.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.')
            ->assertJsonPath('error.details.fields.count.0', 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.');

        $this->assertSame(0, DB::table('stock_items')->where('game_id', 'gam_stock_validation')->count());
        $this->assertSame(0, DB::table('stock_generation_batches')->where('game_id', 'gam_stock_validation')->where('type', 'generate')->count());
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

    private function insertMaterializedStockBatch(string $gameId, string $batchId, int $rounds): void
    {
        $now = now();

        DB::table('stock_generation_batches')->insert([
            'id' => $batchId,
            'game_id' => $gameId,
            'type' => 'import',
            'status' => 'completed',
            'requested_count' => $rounds * 1000,
            'generated_count' => $rounds * 1000,
            'total_rounds' => 0,
            'processed_rounds' => 0,
            'chunk_rounds' => 0,
            'range_start' => '000000',
            'range_end' => '999999',
            'number_digits' => 6,
            'idempotency_key' => $batchId,
            'payload_hash' => hash('sha256', $batchId),
            'created_by_admin_id' => null,
            'payload_json' => json_encode(['game_id' => $gameId, 'rounds' => $rounds], JSON_THROW_ON_ERROR),
            'started_at' => $now,
            'completed_at' => $now,
            'failed_at' => null,
            'failure_reason' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $rows = [];

        for ($round = 0; $round < $rounds; $round++) {
            for ($index = 0; $index < 1000; $index++) {
                $front3 = str_pad((string) $index, 3, '0', STR_PAD_LEFT);
                $back3 = str_pad((string) (($index + $round) % 1000), 3, '0', STR_PAD_LEFT);
                $fullNumber = $front3.$back3;

                $rows[] = [
                    'id' => 'stk_'.substr(sha1($batchId.':'.$round.':'.$index.':'.$fullNumber), 0, 20),
                    'game_id' => $gameId,
                    'batch_id' => $batchId,
                    'full_number' => $fullNumber,
                    'front3' => $front3,
                    'back3' => $back3,
                    'back2' => substr($back3, -2),
                    'status' => 'available',
                    'partner_id' => null,
                    'tenant_id' => null,
                    'allocation_id' => null,
                    'recall_reason' => null,
                    'recalled_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ];
            }
        }

        foreach (array_chunk($rows, 1000) as $chunk) {
            DB::table('stock_items')->insert($chunk);
        }
    }
}
