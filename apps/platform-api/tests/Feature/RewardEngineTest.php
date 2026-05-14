<?php

namespace Tests\Feature;

use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\DB;
use Tests\Support\M7RewardFixtures;
use Tests\TestCase;

class RewardEngineTest extends TestCase
{
    use M7RewardFixtures;
    use RefreshDatabase;

    public function test_RewardEngine_central_record_check_verify_publish_public_result_and_correct_are_permissioned_idempotent(): void
    {
        $world = $this->prepareRewardWorld('par_reward_engine', 'ten_reward_engine', 'reward-engine.m7.test', 'gam_reward_engine', '0807100000', 790101);
        $denied = $this->centralRewardAdmin([], 'reward-denied');
        $admin = $this->centralRewardAdmin([
            'reward.view',
            'reward.create',
            'reward.verify',
            'reward.publish',
            'reward.correct',
            'reward.audit',
        ], 'reward-engine');
        $prizes = $this->thaiGovernmentLotteryPrizes($world['ticket_number']);
        $prizes[0]['amount']['amount'] = 7000000;

        $this->withToken($denied['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-denied',
            ])
            ->assertForbidden();

        $reward = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-engine',
                'X-Request-Id' => 'req-reward-create-engine',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'summary_ready')
            ->json();

        $replay = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-engine',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($reward['id'], $replay['id']);
        $this->assertSame(7000000, $reward['prizes'][0]['amount']['amount']);
        $this->assertSame(1, DB::table('reward_results')->where('game_id', $world['game_id'])->count());
        $this->assertSame(1, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->count());
        $this->assertSame(7000000, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->value('amount'));

        DB::table('reward_results')->where('id', $reward['id'])->update(['status' => 'recorded', 'updated_at' => now()]);
        Artisan::call('reward:check', ['reward_result_id' => $reward['id'], '--chunk' => 1]);
        $this->assertSame(1, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->count());

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/rewards/'.$reward['id'].'/check-batches', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.status', 'completed');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/verify', [
                'reason' => 'summary checked',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-verify-engine',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'verified');

        $published = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/publish', [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-publish-engine',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'published')
            ->json();

        $this->assertGreaterThanOrEqual(1, $published['version']);
        $this->assertDatabaseHas('reward_publish_logs', [
            'reward_result_id' => $reward['id'],
            'game_id' => $world['game_id'],
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'event_type' => 'reward.published.v1',
            'producer' => 'reward_engine',
            'aggregate_id' => $reward['id'],
        ]);

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/latest')
            ->assertOk()
            ->assertHeader('ETag')
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('reward_version', $published['version']);

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/'.$world['game_id'])
            ->assertOk()
            ->assertHeader('ETag')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$reward['id'].'/correct', [
                'reason' => 'audited correction request',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-correct-engine',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'corrected');
    }

    public function test_RewardEngine_partial_reward_number_and_payout_updates_do_not_require_complete_prizes(): void
    {
        $world = $this->prepareRewardWorld('par_reward_partial', 'ten_reward_partial', 'reward-partial.m7.test', 'gam_reward_partial', '0807100001', 790501);
        $admin = $this->centralRewardAdmin([
            'reward.view',
            'reward.create',
            'reward.audit',
        ], 'reward-partial');
        $rewardResultId = 'rew_partial_updates';
        $now = now();

        DB::table('reward_results')->insert([
            'id' => $rewardResultId,
            'game_id' => $world['game_id'],
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
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach (ThaiGovernmentLotteryRewardTemplate::draftPrizes() as $index => $prize) {
            DB::table('reward_prizes')->insert([
                'id' => 'rpr_partial_'.$index,
                'reward_result_id' => $rewardResultId,
                'game_id' => $world['game_id'],
                'prize_type' => $prize['prize_type'],
                'prize_number' => $prize['prize_number'],
                'amount' => $prize['amount']['amount'],
                'currency' => $prize['amount']['currency'],
                'sort_order' => $index,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$rewardResultId, [
                'prize_number_updates' => [[
                    'prize_type' => 'first_prize',
                    'prize_numbers' => [$world['ticket_number']],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-number-partial',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'draft')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        $this->assertSame(0, DB::table('winning_tickets')->where('reward_result_id', $rewardResultId)->count());

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$rewardResultId, [
                'payout_amount_updates' => [[
                    'prize_type' => 'fifth_prize',
                    'amount' => ['amount' => 25000, 'currency' => 'THB'],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-payout-partial',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'draft');

        $this->assertSame(
            [25000],
            DB::table('reward_prizes')
                ->where('reward_result_id', $rewardResultId)
                ->where('prize_type', 'fifth_prize')
                ->distinct()
                ->pluck('amount')
                ->all(),
        );
    }

    public function test_RewardEngine_payout_amount_updates_are_allowed_while_game_is_open(): void
    {
        $this->seedDefaultRbac();
        $admin = $this->centralRewardAdmin([
            'reward.view',
            'reward.create',
        ], 'reward-open-payout');
        $gameId = 'gam_reward_open_payout';
        $rewardResultId = 'rew_open_payout';
        $now = now();

        DB::table('games')->insert([
            'id' => $gameId,
            'code' => 'open_payout',
            'name' => 'Open Payout Game',
            'sale_start_at' => $now->copy()->subHour(),
            'draw_at' => $now->copy()->addDay(),
            'close_at' => $now->copy()->addHours(20),
            'closed_at' => null,
            'archived_at' => null,
            'status' => 'open',
            'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('reward_results')->insert([
            'id' => $rewardResultId,
            'game_id' => $gameId,
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
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach (ThaiGovernmentLotteryRewardTemplate::draftPrizes() as $index => $prize) {
            DB::table('reward_prizes')->insert([
                'id' => 'rpr_open_payout_'.$index,
                'reward_result_id' => $rewardResultId,
                'game_id' => $gameId,
                'prize_type' => $prize['prize_type'],
                'prize_number' => $prize['prize_number'],
                'amount' => $prize['amount']['amount'],
                'currency' => $prize['amount']['currency'],
                'sort_order' => $index,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$rewardResultId, [
                'payout_amount_updates' => [[
                    'prize_type' => 'first_prize',
                    'amount' => ['amount' => 6500000, 'currency' => 'THB'],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-open-payout',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'draft')
            ->assertJsonPath('prizes.0.amount.amount', 6500000);

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$rewardResultId, [
                'prize_number_updates' => [[
                    'prize_type' => 'first_prize',
                    'prize_numbers' => ['123456'],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-open-number-blocked',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.game_id.0', 'The game must be closed before reward results can be recorded.');
    }

}
