<?php

namespace Tests\Feature;

use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
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
                'code' => 'should_be_ignored',
                'name' => 'April 2026 Draw',
                'sale_start_at' => '2026-03-30T10:00:00+07:00',
                'draw_at' => '2026-04-01T20:00:00+07:00',
                'close_at' => '2026-04-01T12:00:00+07:00',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-create-may',
            ])
            ->assertCreated()
            ->assertJsonPath('code', '01042569')
            ->assertJsonPath('status', 'draft')
            ->json();

        $rewardId = (string) DB::table('reward_results')->where('game_id', $game['id'])->value('id');
        $this->assertNotSame('', $rewardId);
        $this->assertSame('draft', DB::table('reward_results')->where('id', $rewardId)->value('status'));
        $this->assertSame($this->thaiGovernmentLotteryPrizeCount(), DB::table('reward_prizes')->where('reward_result_id', $rewardId)->count());

        $rewardAdmin = $this->createCentralSession(['reward.create'], 'adm_reward_guard', 'reward-guard@example.test');

        $this->withToken($rewardAdmin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$rewardId, [
                'prizes' => $this->thaiGovernmentLotteryPrizes('123456'),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-draft-too-early',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.game_id.0', 'The game must be closed before reward results can be recorded.');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$game['id'], [
                'code' => 'manual_code_is_ignored',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-code-manual-ignore',
            ])
            ->assertOk()
            ->assertJsonPath('code', '01042569');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$game['id'], [
                'draw_at' => '2026-04-02T20:00:00+07:00',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-code-draw-sync',
            ])
            ->assertOk()
            ->assertJsonPath('code', '02042569');

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

    public function test_CentralGame_open_requires_previous_closed_result_and_no_other_open_game(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_previous', 'open');

        $login = $this->createCentralSession([
            'game.view',
            'game.create',
            'game.update',
        ], 'adm_game_rules', 'game-rules@example.test');

        $next = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/games', [
                'code' => 'june_2026',
                'name' => 'June 2026 Draw',
                'sale_start_at' => now()->addDay()->toISOString(),
                'draw_at' => now()->addDays(2)->toISOString(),
                'close_at' => now()->addDay()->addHours(20)->toISOString(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-create-june',
            ])
            ->assertCreated()
            ->json();

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$next['id'], [
                'status' => 'open',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-open-june-overlap',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.status.0', 'Another game is already open for sale. Close it and record results before opening a new game.');

        DB::table('games')->where('id', 'gam_previous')->update([
            'status' => 'closed',
            'closed_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$next['id'], [
                'status' => 'open',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-open-june-no-result',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.status.0', 'The previous game must be closed and have recorded reward results before opening a new game.');

        DB::table('reward_results')->insert([
            'id' => 'rr_gam_previous',
            'game_id' => 'gam_previous',
            'status' => 'recorded',
            'version' => 1,
            'summary_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'verified_by_admin_id' => null,
            'published_by_admin_id' => null,
            'corrected_by_admin_id' => null,
            'correction_note' => null,
            'checked_at' => null,
            'verified_at' => null,
            'published_at' => null,
            'corrected_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('games')->where('id', 'gam_previous')->update([
            'status' => 'reward_recorded',
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/games/'.$next['id'], [
                'status' => 'open',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-open-june-after-result',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'open');
    }

    public function test_CentralGame_archived_game_without_recorded_reward_does_not_block_next_open_game(): void
    {
        $this->seedDefaultRbac();
        $this->insertGame('gam_archived_previous', 'archived');

        DB::table('games')->where('id', 'gam_archived_previous')->update([
            'closed_at' => now()->subHour(),
            'archived_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('reward_results')->insert([
            'id' => 'rr_gam_archived_previous',
            'game_id' => 'gam_archived_previous',
            'status' => 'draft',
            'version' => 1,
            'summary_json' => null,
            'created_by_admin_id' => null,
            'verified_by_admin_id' => null,
            'published_by_admin_id' => null,
            'corrected_by_admin_id' => null,
            'correction_note' => null,
            'checked_at' => null,
            'verified_at' => null,
            'published_at' => null,
            'corrected_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $login = $this->createCentralSession([
            'game.create',
        ], 'adm_game_archive_rules', 'game-archive-rules@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/games', [
                'name' => 'Next Draw After Archived',
                'status' => 'open',
                'sale_start_at' => now()->addDay()->toISOString(),
                'draw_at' => now()->addDays(2)->toISOString(),
                'close_at' => now()->addDay()->addHours(20)->toISOString(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'game-create-after-archived',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'open');
    }

    private function thaiGovernmentLotteryPrizeCount(): int
    {
        return array_sum(array_map(
            fn (array $rule): int => $rule['count'],
            ThaiGovernmentLotteryRewardTemplate::rules(),
        ));
    }

    /**
     * @return array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}>
     */
    private function thaiGovernmentLotteryPrizes(string $firstPrizeNumber): array
    {
        $rows = [];

        foreach (ThaiGovernmentLotteryRewardTemplate::rules() as $type => $rule) {
            for ($index = 1; $index <= $rule['count']; $index++) {
                $rows[] = [
                    'prize_type' => $type,
                    'prize_number' => $type === 'first_prize'
                        ? $firstPrizeNumber
                        : str_pad((string) $index, $rule['digits'], '0', STR_PAD_LEFT),
                    'amount' => [
                        'amount' => $rule['amount'],
                        'currency' => ThaiGovernmentLotteryRewardTemplate::CURRENCY,
                    ],
                ];
            }
        }

        return $rows;
    }
}
