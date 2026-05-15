<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
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
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
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
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
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
                'back2_count_per_number' => 30,
                'back3_count_per_number' => 3,
                'front3_count_per_number' => 3,
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

    public function test_CentralStock_generate_quota_validation_rejects_conflicts_over_limit_and_legacy_payloads(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_stock_validation', 'open');

        $login = $this->createCentralSession(['stock.generate'], 'adm_stock_validation', 'stock-validation@example.test');

        $baseHeaders = ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation'];

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'back2_count_per_number' => 9,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 1,
            ], $baseHeaders)
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.back2_count_per_number.0', 'The back2_count_per_number field must equal 10 times back3_count_per_number.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'back2_count_per_number' => 10,
                'back3_count_per_number' => 1,
                'front3_count_per_number' => 2,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-front3'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.front3_count_per_number.0', 'The front3_count_per_number field must equal back3_count_per_number.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'back2_count_per_number' => 110,
                'back3_count_per_number' => 11,
                'front3_count_per_number' => 11,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-limit'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.back3_count_per_number.0', 'The back3_count_per_number field may not create more than 10000 stock items for synchronous generation.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_validation',
                'start_number' => 1,
                'count' => 10,
            ], ['X-Admin-Scope' => 'central', 'Idempotency-Key' => 'stock-validation-legacy'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.start_number.0', 'This field is no longer supported for stock generation. Use quota-based generation fields instead.')
            ->assertJsonPath('error.details.fields.count.0', 'This field is no longer supported for stock generation. Use quota-based generation fields instead.');
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
