<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\CentralStockFixtures;
use Tests\TestCase;

class CentralGameTest extends TestCase
{
    use CentralStockFixtures;
    use RefreshDatabase;

    public function test_CentralGame_lifecycle_is_permissioned_idempotency_guarded_audited_and_emits_close_event(): void
    {
        $this->seedDefaultRbac();

        $limitedLogin = $this->createCentralSession(['dashboard.view'], 'adm_game_limited', 'game-limited@example.test');

        $this->withToken($limitedLogin['access_token'])
            ->getJson('/api/v1/admin/central/games', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->createCentralSession([
            'game.view',
            'game.create',
            'game.update',
            'game.close',
        ], 'adm_game', 'game@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/games', [
                'code' => 'may_2026',
                'name' => 'May 2026 Draw',
                'draw_at' => now()->addDay()->toISOString(),
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $game = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/games', [
                'code' => 'may_2026',
                'name' => 'May 2026 Draw',
                'draw_at' => now()->addDay()->toISOString(),
                'close_at' => now()->addHours(20)->toISOString(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-create-may',
            ])
            ->assertCreated()
            ->assertJsonPath('code', 'may_2026')
            ->assertJsonPath('status', 'draft')
            ->json();

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$game['id'], [
                'status' => 'open',
                'name' => 'May 2026 Draw Open',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-open-may',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'open')
            ->assertJsonPath('name', 'May 2026 Draw Open');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$game['id'], [
                'status' => 'archived',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-invalid-transition',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.status.0', 'The requested game status transition is not allowed.');

        $closed = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/games/'.$game['id'].'/close', [
                'reason' => 'draw_cutoff',
                'api_secret' => 'should-redact',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-close-may',
                'X-Request-Id' => 'req-game-close',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'closed')
            ->json();

        $this->assertSame($game['id'], $closed['id']);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'game.closed.v1',
            'producer' => 'central_stock',
            'game_id' => $game['id'],
            'idempotency_key' => 'game-close-may',
            'correlation_id' => 'req-game-close',
            'status' => 'pending',
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('action', 'game.closed')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['api_secret']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/games/'.$game['id'].'/archive', [
                'reason' => 'retention',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-archive-may',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'archived');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/games', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $game['id']);
    }
}
