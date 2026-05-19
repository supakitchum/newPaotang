<?php

namespace Tests\Feature;

use App\Jobs\DispatchStockBatchImageJobs;
use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GenerateStockBatchChunkJob;
use App\Modules\CentralStock\Events\StockGenerationProgressUpdated;
use App\Modules\CentralStock\Services\CentralStockService;
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
                'total_count' => 1000,
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
                'total_count' => 1000,
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'total_count' => 1000,
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'generate')
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('generated_count', 1000)
            ->json();

        $repeatBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'total_count' => 1000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-main',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($batch['id'], $repeatBatch['id']);
        $this->assertSame(1000, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());
        $this->assertGeneratedQuotaCounts($batch['id'], 1);

        $largeBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'total_count' => 3000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-large',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 3000)
            ->json();

        $this->assertNotSame($batch['id'], $largeBatch['id']);
        $this->assertSame(4000, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());
        $this->assertGeneratedQuotaCounts($largeBatch['id'], 3);

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

        $batch = $this->withToken($generateLogin['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_summary',
                'total_count' => 3000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-summary-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 3000)
            ->json();

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

        $this->withToken($generateLogin['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_summary',
                'total_count' => 1000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-summary-extra',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 1000);

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

    public function test_CentralStock_large_async_generation_chunks_progress_idempotency_duplicates_and_image_dispatch(): void
    {
        Queue::fake();
        config([
            'platform.stock_generation.chunk_rounds' => 5,
            'platform.stock_generation.image_dispatch_chunk_size' => 4000,
        ]);

        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_async', 'open');

        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_async', 'stock-async@example.test');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_async',
                'total_count' => 12000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-async-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'queued')
            ->assertJsonPath('requested_count', 12000)
            ->assertJsonPath('generated_count', 0)
            ->assertJsonPath('total_rounds', 12)
            ->assertJsonPath('processed_rounds', 0)
            ->assertJsonPath('chunk_rounds', 5)
            ->assertJsonPath('started_at', null)
            ->assertJsonPath('completed_at', null)
            ->assertJsonPath('failed_at', null)
            ->json();

        $batchId = $batch['id'];

        $this->assertSame(0, DB::table('stock_items')->where('batch_id', $batchId)->count());
        $this->assertSame(3, DB::table('stock_generation_batch_chunks')->where('batch_id', $batchId)->count());
        Queue::assertPushed(GenerateStockBatchChunkJob::class, 3);
        Queue::assertNotPushed(GenerateLotteryImageJob::class);
        Queue::assertNotPushed(DispatchStockBatchImageJobs::class);

        $replay = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_async',
                'total_count' => 12000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-async-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('id', $batchId)
            ->json();

        $this->assertSame($batchId, $replay['id']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_async',
                'total_count' => 13000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-async-main',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $chunks = DB::table('stock_generation_batch_chunks')
            ->where('batch_id', $batchId)
            ->orderBy('chunk_index')
            ->get();

        (new GenerateStockBatchChunkJob((string) $chunks[0]->id))->handle(app(CentralStockService::class));

        $this->assertSame(5000, DB::table('stock_items')->where('batch_id', $batchId)->count());
        $this->assertDatabaseHas('stock_generation_batches', [
            'id' => $batchId,
            'status' => 'processing',
            'generated_count' => 5000,
            'processed_rounds' => 5,
        ]);

        (new GenerateStockBatchChunkJob((string) $chunks[0]->id))->handle(app(CentralStockService::class));
        $this->assertSame(5000, DB::table('stock_items')->where('batch_id', $batchId)->count());

        (new GenerateStockBatchChunkJob((string) $chunks[1]->id))->handle(app(CentralStockService::class));
        (new GenerateStockBatchChunkJob((string) $chunks[2]->id))->handle(app(CentralStockService::class));

        $this->assertSame(12000, DB::table('stock_items')->where('batch_id', $batchId)->count());
        $this->assertDatabaseHas('stock_generation_batches', [
            'id' => $batchId,
            'status' => 'completed',
            'generated_count' => 12000,
            'processed_rounds' => 12,
        ]);
        $this->assertSame(3, DB::table('stock_generation_batch_chunks')->where('batch_id', $batchId)->where('status', 'completed')->count());
        $this->assertNotNull(DB::table('stock_generation_batches')->where('id', $batchId)->value('completed_at'));

        $duplicateFullNumber = DB::table('stock_items')
            ->where('batch_id', $batchId)
            ->select('full_number', DB::raw('COUNT(*) as total'))
            ->groupBy('full_number')
            ->havingRaw('COUNT(*) > 1')
            ->value('full_number');

        $this->assertNotNull($duplicateFullNumber);
        $this->assertStringNotContainsString(
            'insertOrIgnore',
            file_get_contents(app_path('Modules/CentralStock/Services/CentralStockService.php')),
        );

        $summary = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/summary?'.http_build_query([
                'game_id' => 'gam_stock_async',
                'batch_id' => $batchId,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('total_count', 12000)
            ->assertJsonPath('number_coverage.back2.distinct_count', 100)
            ->assertJsonPath('number_coverage.back2.min_count_per_number', 120)
            ->assertJsonPath('number_coverage.back3.distinct_count', 1000)
            ->assertJsonPath('number_coverage.back3.min_count_per_number', 12)
            ->assertJsonPath('number_coverage.front3.distinct_count', 1000)
            ->assertJsonPath('number_coverage.front3.min_count_per_number', 12)
            ->json();

        $this->assertSame(12000, $summary['number_coverage']['front3']['total_count']);

        Queue::assertPushed(DispatchStockBatchImageJobs::class, 1);
        Queue::assertNotPushed(GenerateLotteryImageJob::class);

        (new DispatchStockBatchImageJobs($batchId, null, 4000))->handle(app(CentralStockService::class));

        Queue::assertPushed(GenerateLotteryImageJob::class, 4000);
        Queue::assertPushed(DispatchStockBatchImageJobs::class, 2);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/generation-batches?'.http_build_query([
                'game_id' => 'gam_stock_async',
                'status' => 'completed',
                'limit' => 5,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $batchId)
            ->assertJsonPath('data.0.generated_count', 12000)
            ->assertJsonPath('data.0.total_rounds', 12)
            ->assertJsonPath('data.0.processed_rounds', 12)
            ->assertJsonPath('data.0.failed_at', null)
            ->assertJsonPath('data.0.failure_reason', null);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock/generation-batches/'.$batchId, ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('id', $batchId)
            ->assertJsonPath('generated_count', 12000)
            ->assertJsonPath('chunks.0.status', 'completed')
            ->assertJsonCount(3, 'chunks');
    }

    public function test_CentralStock_async_generation_broadcasts_realtime_progress_events(): void
    {
        Queue::fake();
        Event::fake([StockGenerationProgressUpdated::class]);
        config(['platform.stock_generation.chunk_rounds' => 5]);

        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_realtime', 'open');

        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_realtime', 'stock-realtime@example.test');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_realtime',
                'total_count' => 11000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-realtime-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'queued')
            ->json();

        $batchId = $batch['id'];

        Event::assertDispatched(StockGenerationProgressUpdated::class, function (StockGenerationProgressUpdated $event) use ($batchId): bool {
            $channels = array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn());

            return $event->broadcastAs() === 'stock.generation.progress.updated'
                && ($event->payload['event_type'] ?? null) === 'stock_generation.batch.queued'
                && ($event->payload['batch_id'] ?? null) === $batchId
                && ($event->payload['game_id'] ?? null) === 'gam_stock_realtime'
                && ($event->payload['status'] ?? null) === 'queued'
                && ($event->payload['generated_count'] ?? null) === 0
                && in_array('private-admin.central.stock-generation', $channels, true)
                && in_array('private-admin.central.stock-generation.game.gam_stock_realtime', $channels, true)
                && in_array('private-admin.central.stock-generation.batch.'.$batchId, $channels, true);
        });

        $chunks = DB::table('stock_generation_batch_chunks')
            ->where('batch_id', $batchId)
            ->orderBy('chunk_index')
            ->get();

        (new GenerateStockBatchChunkJob((string) $chunks[0]->id))->handle(app(CentralStockService::class));

        Event::assertDispatched(StockGenerationProgressUpdated::class, fn (StockGenerationProgressUpdated $event): bool => (
            ($event->payload['event_type'] ?? null) === 'stock_generation.batch.processing'
            && ($event->payload['batch_id'] ?? null) === $batchId
            && ($event->payload['status'] ?? null) === 'processing'
            && ($event->payload['generated_count'] ?? null) === 5000
            && ($event->payload['processed_rounds'] ?? null) === 5
            && ($event->payload['image_dispatch_status'] ?? null) === 'waiting_for_stock'
        ));
        Event::assertDispatched(StockGenerationProgressUpdated::class, fn (StockGenerationProgressUpdated $event): bool => (
            ($event->payload['event_type'] ?? null) === 'stock_generation.chunk.completed'
            && ($event->payload['batch_id'] ?? null) === $batchId
            && ($event->payload['generated_count'] ?? null) === 5000
            && ($event->payload['processed_rounds'] ?? null) === 5
        ));

        (new GenerateStockBatchChunkJob((string) $chunks[1]->id))->handle(app(CentralStockService::class));
        (new GenerateStockBatchChunkJob((string) $chunks[2]->id))->handle(app(CentralStockService::class));

        Event::assertDispatched(StockGenerationProgressUpdated::class, fn (StockGenerationProgressUpdated $event): bool => (
            ($event->payload['event_type'] ?? null) === 'stock_generation.batch.completed'
            && ($event->payload['batch_id'] ?? null) === $batchId
            && ($event->payload['status'] ?? null) === 'completed'
            && ($event->payload['generated_count'] ?? null) === 11000
            && ($event->payload['processed_rounds'] ?? null) === 11
            && ($event->payload['image_dispatch_status'] ?? null) === 'queued'
            && ($event->payload['completed_at'] ?? null) !== null
        ));
    }

    public function test_CentralStock_async_generation_failed_chunk_rolls_back_without_partial_rows(): void
    {
        Queue::fake();
        Event::fake([StockGenerationProgressUpdated::class]);
        config(['platform.stock_generation.chunk_rounds' => 5]);

        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_async_fail', 'open');

        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_async_fail', 'stock-async-fail@example.test');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_async_fail',
                'total_count' => 12000,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-async-fail-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'queued')
            ->json();

        $payload = json_decode(
            (string) DB::table('stock_generation_batches')->where('id', $batch['id'])->value('payload_json'),
            true,
            flags: JSON_THROW_ON_ERROR,
        );
        $payload['game_id'] = 'gam_missing_for_fk_failure';

        DB::table('stock_generation_batches')
            ->where('id', $batch['id'])
            ->update(['payload_json' => json_encode($payload, JSON_THROW_ON_ERROR)]);

        $chunkId = (string) DB::table('stock_generation_batch_chunks')
            ->where('batch_id', $batch['id'])
            ->orderBy('chunk_index')
            ->value('id');

        (new GenerateStockBatchChunkJob($chunkId))->handle(app(CentralStockService::class));

        $this->assertSame(0, DB::table('stock_items')->where('batch_id', $batch['id'])->count());
        $this->assertDatabaseHas('stock_generation_batch_chunks', [
            'id' => $chunkId,
            'status' => 'failed',
        ]);
        $this->assertDatabaseHas('stock_generation_batches', [
            'id' => $batch['id'],
            'status' => 'failed',
            'generated_count' => 0,
        ]);
        $this->assertNotNull(DB::table('stock_generation_batches')->where('id', $batch['id'])->value('failure_reason'));
        Event::assertDispatched(StockGenerationProgressUpdated::class, fn (StockGenerationProgressUpdated $event): bool => (
            ($event->payload['event_type'] ?? null) === 'stock_generation.batch.failed'
            && ($event->payload['batch_id'] ?? null) === $batch['id']
            && ($event->payload['status'] ?? null) === 'failed'
            && ($event->payload['generated_count'] ?? null) === 0
            && ($event->payload['failed_at'] ?? null) !== null
            && ($event->payload['failure_reason'] ?? null) !== null
        ));
    }

    public function test_CentralStock_generate_accepts_restored_quota_payloads_and_rejects_legacy_ranges(): void
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
            ->assertAccepted()
            ->assertJsonPath('type', 'generate')
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('generated_count', 1000);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'total_count' => 3000,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-total-retired'])
            ->assertAccepted()
            ->assertJsonPath('type', 'generate')
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('generated_count', 3000);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'start_number' => 1,
                'count' => 10,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-legacy'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.start_number.0', 'This field is no longer supported for stock generation. Use quota-based generation fields instead.')
            ->assertJsonPath('error.details.fields.count.0', 'This field is no longer supported for stock generation. Use quota-based generation fields instead.');

        $this->assertSame(4000, DB::table('stock_items')->where('game_id', 'gam_stock_validation')->count());
    }

    private function assertGeneratedQuotaCounts(string $batchId, int $countPerFrontAndBack3): void
    {
        $this->assertSame(
            1000 * $countPerFrontAndBack3,
            DB::table('stock_items')->where('batch_id', $batchId)->count(),
        );

        foreach (['front3', 'back3'] as $column) {
            $counts = DB::table('stock_items')
                ->where('batch_id', $batchId)
                ->select($column, DB::raw('COUNT(*) as total'))
                ->groupBy($column)
                ->pluck('total', $column)
                ->map(fn (mixed $value): int => (int) $value);

            $this->assertCount(1000, $counts);
            $this->assertSame([$countPerFrontAndBack3], array_values(array_unique($counts->values()->all())));
        }

        $back2Counts = DB::table('stock_items')
            ->where('batch_id', $batchId)
            ->select('back2', DB::raw('COUNT(*) as total'))
            ->groupBy('back2')
            ->pluck('total', 'back2')
            ->map(fn (mixed $value): int => (int) $value);

        $this->assertCount(100, $back2Counts);
        $this->assertSame([$countPerFrontAndBack3 * 10], array_values(array_unique($back2Counts->values()->all())));
    }
}
