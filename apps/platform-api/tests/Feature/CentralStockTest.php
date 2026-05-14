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

        $limitedLogin = $this->createCentralSession(['stock.view'], 'adm_stock_limited', 'stock-limited@example.test');

        $this->withToken($limitedLogin['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'count' => 1,
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
                'start_number' => 1,
                'count' => 3,
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $batch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'start_number' => 1,
                'count' => 3,
                'api_secret' => 'redact-me',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'generate')
            ->assertJsonPath('status', 'completed')
            ->assertJsonPath('generated_count', 3)
            ->json();

        $repeatBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'start_number' => 1,
                'count' => 3,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-main',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($batch['id'], $repeatBatch['id']);
        $this->assertSame(3, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());

        $duplicateRangeBatch = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/generate', [
                'game_id' => 'gam_stock_main',
                'start_number' => 1,
                'count' => 3,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-generate-duplicate-range',
            ])
            ->assertAccepted()
            ->assertJsonPath('generated_count', 3)
            ->json();

        $this->assertNotSame($batch['id'], $duplicateRangeBatch['id']);
        $this->assertSame(6, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());
        $this->assertSame(2, DB::table('stock_items')->where('game_id', 'gam_stock_main')->where('full_number', '000001')->count());

        $import = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/imports', [
                'game_id' => 'gam_stock_main',
                'items' => [
                    ['full_number' => '000010'],
                    ['full_number' => '000011'],
                    ['full_number' => '000011'],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-import-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'import')
            ->assertJsonPath('generated_count', 3)
            ->json();

        $this->assertSame(9, DB::table('stock_items')->where('game_id', 'gam_stock_main')->count());
        $this->assertSame(2, DB::table('stock_items')->where('game_id', 'gam_stock_main')->where('full_number', '000011')->count());

        $grouped = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_main&grouped=true&number=000011', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.full_number', '000011')
            ->assertJsonPath('data.0.total_count', 2)
            ->assertJsonPath('data.0.available_count', 2)
            ->json();

        $this->assertNotEmpty($grouped['data'][0]['sample_stock_item_id']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_main&grouped=true&front3=000&limit=2', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.has_more', true);

        $sortedGroups = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_main',
                'grouped' => true,
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000011')
            ->assertJsonPath('data.1.full_number', '000010')
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_main',
                'grouped' => true,
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'cursor' => $sortedGroups['meta']['next_cursor'],
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000003');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?game_id=gam_stock_main&status=available&limit=2', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonCount(2, 'data')
            ->assertJsonPath('meta.has_more', true);

        $sortedTickets = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_main',
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000011')
            ->assertJsonPath('data.1.full_number', '000011')
            ->assertJsonPath('meta.has_more', true)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/stock?'.http_build_query([
                'game_id' => 'gam_stock_main',
                'sort_by' => 'full_number',
                'sort_dir' => 'desc',
                'cursor' => $sortedTickets['meta']['next_cursor'],
                'limit' => 2,
            ]), ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.full_number', '000010');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/stock/exports', [
                'game_id' => 'gam_stock_main',
                'filters' => ['status' => 'available'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'stock-export-main',
            ])
            ->assertAccepted()
            ->assertJsonPath('type', 'export')
            ->assertJsonPath('status', 'pending');

        $stockItemId = (string) DB::table('stock_items')
            ->where('game_id', 'gam_stock_main')
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
}
