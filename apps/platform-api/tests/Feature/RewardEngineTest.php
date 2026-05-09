<?php

namespace Tests\Feature;

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

        $this->withToken($denied['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => [[
                    'prize_type' => 'first_prize',
                    'prize_number' => $world['ticket_number'],
                    'amount' => ['amount' => 1000000, 'currency' => 'THB'],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-denied',
            ])
            ->assertForbidden();

        $reward = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => [[
                    'prize_type' => 'first_prize',
                    'prize_number' => $world['ticket_number'],
                    'amount' => ['amount' => 1000000, 'currency' => 'THB'],
                ]],
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
                'prizes' => [[
                    'prize_type' => 'first_prize',
                    'prize_number' => $world['ticket_number'],
                    'amount' => ['amount' => 1000000, 'currency' => 'THB'],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-create-engine',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($reward['id'], $replay['id']);
        $this->assertSame(1, DB::table('reward_results')->where('game_id', $world['game_id'])->count());
        $this->assertSame(1, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->count());

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
}
