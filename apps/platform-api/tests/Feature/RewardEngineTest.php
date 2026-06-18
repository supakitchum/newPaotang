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

    public function test_RewardEngine_central_rewards_live_settings_save_and_list_meta(): void
    {
        $this->seedDefaultRbac();
        $denied = $this->centralRewardAdmin(['reward.view'], 'reward-live-denied');
        $admin = $this->centralRewardAdmin(['reward.view', 'reward.create'], 'reward-live');

        $this->withToken($denied['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/live-settings', [
                'waiting_result_youtube_url' => 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-live-denied',
            ])
            ->assertForbidden();

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/live-settings', [
                'waiting_result_youtube_url' => 'https://www.youtube.com/watch?v=M7lc1UVf-VE',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-live-save',
            ])
            ->assertOk()
            ->assertJsonPath('waiting_result_youtube_url', 'https://www.youtube.com/watch?v=M7lc1UVf-VE')
            ->assertJsonPath('waiting_result_youtube_embed_url', 'https://www.youtube.com/embed/M7lc1UVf-VE')
            ->assertJsonPath('source', 'central_default');

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/rewards/live-settings', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('waiting_result_youtube_url', 'https://www.youtube.com/watch?v=M7lc1UVf-VE');

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/rewards', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.live_settings.waiting_result_youtube_embed_url', 'https://www.youtube.com/embed/M7lc1UVf-VE');

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/live-settings', [
                'waiting_result_youtube_url' => 'https://example.test/watch?v=M7lc1UVf-VE',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-live-invalid',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.waiting_result_youtube_url.0', 'The waiting_result_youtube_url field must be a valid YouTube URL.');
    }

    public function test_RewardEngine_thai_government_lottery_template_matches_current_reward_amounts(): void
    {
        $rules = ThaiGovernmentLotteryRewardTemplate::rules();

        $this->assertSame(['count' => 1, 'amount' => 600000000], [
            'count' => $rules['first_prize']['count'],
            'amount' => $rules['first_prize']['amount'],
        ]);
        $this->assertSame(['count' => 5, 'amount' => 20000000], [
            'count' => $rules['second_prize']['count'],
            'amount' => $rules['second_prize']['amount'],
        ]);
        $this->assertSame(['count' => 10, 'amount' => 8000000], [
            'count' => $rules['third_prize']['count'],
            'amount' => $rules['third_prize']['amount'],
        ]);
        $this->assertSame(['count' => 50, 'amount' => 4000000], [
            'count' => $rules['fourth_prize']['count'],
            'amount' => $rules['fourth_prize']['amount'],
        ]);
        $this->assertSame(['count' => 100, 'amount' => 2000000], [
            'count' => $rules['fifth_prize']['count'],
            'amount' => $rules['fifth_prize']['amount'],
        ]);
        $this->assertSame(['count' => 2, 'amount' => 10000000], [
            'count' => $rules['near_first_prize']['count'],
            'amount' => $rules['near_first_prize']['amount'],
        ]);
        $this->assertSame(['count' => 2, 'amount' => 400000], [
            'count' => $rules['front3']['count'],
            'amount' => $rules['front3']['amount'],
        ]);
        $this->assertSame(['count' => 2, 'amount' => 400000], [
            'count' => $rules['back3']['count'],
            'amount' => $rules['back3']['amount'],
        ]);
        $this->assertSame(['count' => 1, 'amount' => 200000], [
            'count' => $rules['back2']['count'],
            'amount' => $rules['back2']['amount'],
        ]);
    }

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

    public function test_RewardEngine_central_winners_default_to_latest_opened_game(): void
    {
        $oldWorld = $this->prepareRewardWorld('par_reward_winners_old', 'ten_reward_winners_old', 'reward-winners-old.m7.test', 'gam_reward_winners_old', '0807110001', 791101);
        DB::table('games')->where('id', $oldWorld['game_id'])->update([
            'sale_start_at' => now()->subDays(20),
            'draw_at' => now()->subDays(19),
            'close_at' => now()->subDays(18),
            'updated_at' => now(),
        ]);
        $this->publishReward($oldWorld, null, 'winners-old');

        $latestWorld = $this->prepareRewardWorld('par_reward_winners_new', 'ten_reward_winners_new', 'reward-winners-new.m7.test', 'gam_reward_winners_new', '0807110002', 791201);
        DB::table('games')->where('id', $latestWorld['game_id'])->update([
            'sale_start_at' => now()->subDay(),
            'draw_at' => now()->addDay(),
            'close_at' => now()->subHour(),
            'updated_at' => now(),
        ]);
        $this->publishReward($latestWorld, null, 'winners-latest');

        $denied = $this->centralRewardAdmin([], 'reward-winners-denied');
        $admin = $this->centralRewardAdmin(['reward.view'], 'reward-winners-view');

        $this->withToken($denied['access_token'])
            ->getJson('/api/v1/admin/central/winners', ['X-Admin-Scope' => 'central'])
            ->assertForbidden();

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners/games', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.default_game_id', $latestWorld['game_id'])
            ->assertJsonPath('data.0.id', $latestWorld['game_id'])
            ->assertJsonPath('data.0.is_default', true);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.game_id', $latestWorld['game_id'])
            ->assertJsonPath('meta.winner_count', 1)
            ->assertJsonPath('meta.total_prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.game_id', $latestWorld['game_id'])
            ->assertJsonPath('data.0.full_number', $latestWorld['ticket_number'])
            ->assertJsonPath('data.0.prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.status', 'verified');

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners?game_id='.$oldWorld['game_id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.game_id', $oldWorld['game_id'])
            ->assertJsonPath('data.0.game_id', $oldWorld['game_id']);
    }

    public function test_RewardEngine_central_winners_preview_central_draft_results(): void
    {
        $world = $this->prepareRewardWorld('par_reward_winners_draft', 'ten_reward_winners_draft', 'reward-winners-draft.m7.test', 'gam_reward_winners_draft', '0807110003', 791301);
        $admin = $this->centralRewardAdmin(['reward.view', 'reward.create'], 'reward-winners-draft');
        $prizes = $this->thaiGovernmentLotteryPrizes($world['ticket_number']);

        $reward = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards', [
                'game_id' => $world['game_id'],
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-winners-draft-create',
            ])
            ->assertAccepted()
            ->json();

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$reward['id'], [
                'prize_number_updates' => [[
                    'prize_type' => 'second_prize',
                    'prize_numbers' => [''],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-winners-draft-partial',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'draft');

        $this->assertSame(0, DB::table('winning_tickets')->where('game_id', $world['game_id'])->count());

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners?game_id='.$world['game_id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.game_id', $world['game_id'])
            ->assertJsonPath('meta.reward_result_id', $reward['id'])
            ->assertJsonPath('meta.has_live_result', true)
            ->assertJsonPath('meta.source.name', 'central')
            ->assertJsonPath('meta.winner_count', 1)
            ->assertJsonPath('meta.total_prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.full_number', $world['ticket_number'])
            ->assertJsonPath('data.0.customer_no', $world['auth']['user']['customer_no'])
            ->assertJsonPath('data.0.ticket_count', 1)
            ->assertJsonPath('data.0.total_prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.status', 'live_draft')
            ->assertJsonPath('data.0.source', 'central')
            ->assertJsonPath('data.0.official_claimable', false);
    }

    public function test_RewardEngine_tenant_winners_are_scoped_and_include_customer_no(): void
    {
        $world = $this->prepareRewardWorld('par_reward_tenant_winners', 'ten_reward_tenant_winners', 'reward-tenant-winners.m7.test', 'gam_reward_tenant_winners', '0807110004', 791401);
        $otherWorld = $this->prepareRewardWorld('par_reward_tenant_other', 'ten_reward_tenant_other', 'reward-tenant-other.m7.test', 'gam_reward_tenant_other', '0807110005', 791501);
        $this->publishReward($world, null, 'tenant-winners');
        $this->publishReward($otherWorld, null, 'tenant-winners-other');

        $denied = $this->tenantAdmin($world, [], 'tenant-winners-denied');
        $admin = $this->tenantAdmin($world, ['reward_claim.view'], 'tenant-winners-view');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $world['tenant_id'],
        ];

        $this->withToken($denied['access_token'])
            ->getJson('/api/v1/admin/tenant/winners', $headers)
            ->assertForbidden();

        $games = $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/winners/games', $headers)
            ->assertOk()
            ->assertJsonPath('meta.default_game_id', $world['game_id'])
            ->json('data');

        $this->assertContains($world['game_id'], array_column($games, 'id'));
        $this->assertNotContains($otherWorld['game_id'], array_column($games, 'id'));

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/winners?game_id='.$world['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('meta.scope_type', 'tenant')
            ->assertJsonPath('meta.tenant_id', $world['tenant_id'])
            ->assertJsonPath('meta.winner_count', 1)
            ->assertJsonPath('data.0.tenant_id', $world['tenant_id'])
            ->assertJsonPath('data.0.customer_no', $world['auth']['user']['customer_no'])
            ->assertJsonPath('data.0.full_number', $world['ticket_number']);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/winners?game_id='.$otherWorld['game_id'], $headers)
            ->assertOk()
            ->assertJsonPath('meta.winner_count', 0)
            ->assertJsonCount(0, 'data');
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

    public function test_RewardEngine_sanook_live_ingest_updates_live_draft_without_publishing_until_confirmed(): void
    {
        config(['platform.lotto_scraper.hmac_secret' => 'test-secret']);
        $world = $this->prepareRewardWorld('par_reward_live', 'ten_reward_live', 'reward-live.m7.test', 'gam_reward_live', '0807100099', 791001);
        DB::table('games')->where('id', $world['game_id'])->update(['code' => '01062569']);

        $payload = $this->sanookLivePayload('01062569', [[
            'prize_type' => 'first_prize',
            'prize_numbers' => [$world['ticket_number']],
        ]], 0.58);

        $this->postJson('/api/v1/internal/reward-ingest/sanook', $payload)
            ->assertForbidden();

        $draft = $this->postSignedSanookIngest($payload)
            ->assertOk()
            ->assertJsonPath('status', 'live_draft')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number'])
            ->assertJsonPath('live_estimate.mode', 'live_result')
            ->assertJsonPath('live_estimate.official_claimable', false)
            ->json();

        $this->assertSame(0, DB::table('winning_tickets')->where('game_id', $world['game_id'])->count());

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/live/latest')
            ->assertOk()
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('status', 'live_draft')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        DB::table('games')->where('id', $world['game_id'])->update([
            'status' => 'open',
            'updated_at' => now(),
        ]);

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/live/'.$world['game_id'])
            ->assertOk()
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('status', 'live_draft')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        DB::table('games')->where('id', $world['game_id'])->update([
            'status' => 'closed',
            'updated_at' => now(),
        ]);

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/latest')
            ->assertNotFound();

        $admin = $this->centralRewardAdmin(['reward.view', 'reward.create', 'reward.audit'], 'reward-live-confirm');
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$draft['reward_result_id'].'/confirm-live', [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-live-confirm-incomplete',
            ])
            ->assertConflict();

        $completePayload = $this->sanookLivePayload('01062569', $this->groupPrizeNumbers($this->thaiGovernmentLotteryPrizes($world['ticket_number'])), 100);
        $this->postSignedSanookIngest($completePayload)
            ->assertOk()
            ->assertJsonPath('completion_percent', 100);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$draft['reward_result_id'].'/confirm-live', [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-live-confirm-complete',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'published');

        $this->assertSame(1, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->count());

        $this->withToken($world['auth']['token'])
            ->getJson('http://'.$world['host'].'/api/v1/customer/tickets')
            ->assertOk()
            ->assertJsonPath('data.0.id', $world['ticket_id'])
            ->assertJsonPath('data.0.status', 'winning')
            ->assertJsonPath('data.0.reward_status.status', 'winning')
            ->assertJsonPath('data.0.reward_status.claimable', true);

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/latest')
            ->assertOk()
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('status', 'published')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        $this->getJson('http://'.$world['host'].'/api/v1/public/results/live/latest')
            ->assertOk()
            ->assertJsonPath('game_id', $world['game_id'])
            ->assertJsonPath('status', 'published')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);
    }

    public function test_RewardEngine_sanook_live_ingest_handles_reordered_prize_numbers(): void
    {
        config(['platform.lotto_scraper.hmac_secret' => 'test-secret']);
        $world = $this->prepareRewardWorld('par_reward_reorder', 'ten_reward_reorder', 'reward-reorder.m7.test', 'gam_reward_reorder', '0807100100', 791002);
        DB::table('games')->where('id', $world['game_id'])->update(['code' => '16062569']);

        $initialPayload = $this->sanookLivePayload('16062569', [[
            'prize_type' => 'fourth_prize',
            'prize_numbers' => ['111111', '222222'],
        ]], 1.16);
        $this->postSignedSanookIngest($initialPayload)
            ->assertOk()
            ->assertJsonPath('status', 'live_draft');

        $reorderedPayload = $this->sanookLivePayload('16062569', [[
            'prize_type' => 'fourth_prize',
            'prize_numbers' => ['222222', '111111'],
        ]], 1.16);
        $this->postSignedSanookIngest($reorderedPayload)
            ->assertOk()
            ->assertJsonPath('status', 'live_draft');

        $fourthPrizeNumbers = DB::table('reward_prizes')
            ->where('game_id', $world['game_id'])
            ->where('prize_type', 'fourth_prize')
            ->orderBy('sort_order')
            ->limit(2)
            ->pluck('prize_number')
            ->all();

        $this->assertSame(['222222', '111111'], $fourthPrizeNumbers);
    }

    public function test_RewardEngine_thairath_live_ingest_is_stored_as_comparison_source(): void
    {
        config(['platform.lotto_scraper.hmac_secret' => 'test-secret']);
        $world = $this->prepareRewardWorld('par_reward_thairath', 'ten_reward_thairath', 'reward-thairath.m7.test', 'gam_reward_thairath', '0807100101', 791003);
        DB::table('games')->where('id', $world['game_id'])->update(['code' => '16062569']);

        $sanookPayload = $this->livePayload('sanook', '16062569', [[
            'prize_type' => 'first_prize',
            'prize_numbers' => [$world['ticket_number']],
        ]], 1.17);
        $this->postSignedLiveIngest('sanook', $sanookPayload)
            ->assertOk()
            ->assertJsonPath('status', 'live_draft')
            ->assertJsonPath('source.name', 'sanook')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        $payload = $this->livePayload('thairath', '16062569', [[
            'prize_type' => 'first_prize',
            'prize_numbers' => ['999999'],
        ], [
            'prize_type' => 'back2',
            'prize_numbers' => [substr($world['ticket_number'], -2)],
        ]], 1.17);

        $this->postSignedLiveIngest('thairath', $payload)
            ->assertOk()
            ->assertJsonPath('status', 'live_draft')
            ->assertJsonPath('source.name', 'sanook')
            ->assertJsonPath('comparison_source.source.name', 'thairath')
            ->assertJsonPath('comparison_sources.thairath.source.name', 'thairath')
            ->assertJsonPath('prizes.0.prize_number', $world['ticket_number']);

        $this->assertSame($world['ticket_number'], DB::table('reward_prizes')
            ->where('game_id', $world['game_id'])
            ->where('prize_type', 'first_prize')
            ->value('prize_number'));
        $this->assertSame(0, DB::table('winning_tickets')->where('game_id', $world['game_id'])->count());
    }


    public function test_RewardEngine_redraw_discards_unapproved_claims_and_blocks_after_approval(): void
    {
        $world = $this->prepareRewardWorld('par_reward_redraw', 'ten_reward_redraw', 'reward-redraw.m7.test', 'gam_reward_redraw', '0807100299', 793001);
        $published = $this->publishReward($world, keySuffix: 'redraw');
        $claim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'bank_transfer',
                'pin' => '246810',
                'bank_account' => ['bank' => 'test', 'account_no' => '1234567890'],
            ], [
                'Idempotency-Key' => 'reward-redraw-claim-create',
            ])
            ->assertCreated()
            ->json();
        $admin = $this->centralRewardAdmin(['reward.view', 'reward.create'], 'reward-redraw-admin');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$published['id'].'/redraw', [
                'reason' => 'scraped result changed before approval',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-redraw-before-approval',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'draft')
            ->assertJsonPath('prizes.0.prize_number', 'pending_first_prize_001');

        $this->assertDatabaseMissing('reward_claims', ['id' => $claim['id']]);
        $this->assertSame(0, DB::table('winning_tickets')->where('reward_result_id', $published['id'])->count());

        $completePayload = $this->thaiGovernmentLotteryPrizes($world['ticket_number']);
        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/central/rewards/'.$published['id'], [
                'prizes' => $completePayload,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-redraw-reload',
            ])
            ->assertOk();
        $republished = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$published['id'].'/confirm-live', [
                'reason' => 'confirmed redraw',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-redraw-confirm',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'published')
            ->json();

        $approvedClaim = $this->withToken($world['auth']['token'])
            ->postJson('http://'.$world['host'].'/api/v1/customer/reward-claims', [
                'ticket_id' => $world['ticket_id'],
                'payout_method' => 'bank_transfer',
                'pin' => '246810',
                'bank_account' => ['bank' => 'test', 'account_no' => '1234567890'],
            ], [
                'Idempotency-Key' => 'reward-redraw-approved-claim-create',
            ])
            ->assertCreated()
            ->json();
        $tenantAdmin = $this->tenantAdmin($world, ['reward_claim.view', 'reward_claim.approve'], 'reward-redraw-tenant');
        $this->withToken($tenantAdmin['access_token'])
            ->postJson('/api/v1/admin/tenant/reward-claims/'.$approvedClaim['id'].'/approve', [
                'reason' => 'approved bank transfer',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'reward-redraw-approve-bank',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/central/rewards/'.$republished['id'].'/redraw', [
                'reason' => 'must be blocked',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-redraw-after-approval',
            ])
            ->assertConflict();
    }

    public function test_RewardEngine_central_winners_use_sanook_live_results_without_separate_api(): void
    {
        config(['platform.lotto_scraper.hmac_secret' => 'test-secret']);
        $world = $this->prepareRewardWorld('par_reward_winners_live', 'ten_reward_winners_live', 'reward-winners-live.m7.test', 'gam_reward_winners_live', '0807100199', 792001);
        DB::table('games')->where('id', $world['game_id'])->update([
            'code' => '01072569',
            'sale_start_at' => now(),
            'draw_at' => now()->addHour(),
            'close_at' => now()->subMinute(),
            'status' => 'open',
            'updated_at' => now(),
        ]);
        DB::table('games')->insert([
            'id' => 'gam_reward_winners_live_closed',
            'code' => 'closed_winners_live',
            'name' => 'Closed Winners Live Game',
            'sale_start_at' => now()->subDay(),
            'draw_at' => now()->subDay(),
            'close_at' => now()->subMinute(),
            'closed_at' => now()->subMinute(),
            'archived_at' => null,
            'status' => 'closed',
            'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $payload = $this->sanookLivePayload('01072569', [[
            'prize_type' => 'first_prize',
            'prize_numbers' => [$world['ticket_number']],
        ]], 4.25);
        $draft = $this->postSignedSanookIngest($payload)->assertOk()->json();
        $denied = $this->centralRewardAdmin([], 'reward-winners-live-denied');
        $admin = $this->centralRewardAdmin(['reward.view'], 'reward-winners-live-view');

        $this->withToken($denied['access_token'])
            ->getJson('/api/v1/admin/central/winners/games', ['X-Admin-Scope' => 'central'])
            ->assertForbidden();

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners/games', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.default_game_id', $world['game_id'])
            ->assertJsonPath('data.0.id', $world['game_id'])
            ->assertJsonPath('data.0.is_default', true);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners?game_id=gam_reward_winners_live_closed', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.game.id', 'gam_reward_winners_live_closed')
            ->assertJsonPath('data', []);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/central/winners', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.game_id', $world['game_id'])
            ->assertJsonPath('meta.reward_result_id', $draft['reward_result_id'])
            ->assertJsonPath('meta.has_live_result', true)
            ->assertJsonPath('meta.source.name', 'sanook')
            ->assertJsonPath('meta.completion_percent', 4.25)
            ->assertJsonPath('meta.winner_count', 1)
            ->assertJsonPath('meta.winning_row_count', 1)
            ->assertJsonPath('meta.total_prize_amount.amount', 600000000)
            ->assertJsonPath('meta.live_estimate.official_claimable', false)
            ->assertJsonPath('data.0.full_number', $world['ticket_number'])
            ->assertJsonPath('data.0.ticket_count', 1)
            ->assertJsonPath('data.0.total_prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.prize_amount.amount', 600000000)
            ->assertJsonPath('data.0.prize_breakdown.0.ticket_count', 1)
            ->assertJsonPath('data.0.status', 'live_draft')
            ->assertJsonPath('data.0.claim_status', 'pending_confirmation')
            ->assertJsonPath('data.0.source', 'sanook')
            ->assertJsonPath('data.0.official_claimable', false);

        $this->assertSame(0, DB::table('winning_tickets')->where('ticket_id', $world['ticket_id'])->count());
    }

    /**
     * @param array<int, array{prize_type: string, prize_numbers: array<int, string>}> $prizes
     * @return array<string, mixed>
     */
    private function sanookLivePayload(string $drawCode, array $prizes, float $completionPercent): array
    {
        return $this->livePayload('sanook', $drawCode, $prizes, $completionPercent);
    }

    /**
     * @param array<int, array{prize_type: string, prize_numbers: array<int, string>}> $prizes
     * @return array<string, mixed>
     */
    private function livePayload(string $source, string $drawCode, array $prizes, float $completionPercent): array
    {
        return [
            'source' => $source,
            'draw_code' => $drawCode,
            'draw_date' => '2026-06-01',
            'scraped_at' => now()->toISOString(),
            'completion_percent' => $completionPercent,
            'payload_hash' => hash('sha256', $drawCode.json_encode($prizes, JSON_THROW_ON_ERROR).$completionPercent),
            'prizes' => $prizes,
        ];
    }

    /**
     * @param array<int, array{prize_type: string, prize_number: string}> $prizes
     * @return array<int, array{prize_type: string, prize_numbers: array<int, string>}>
     */
    private function groupPrizeNumbers(array $prizes): array
    {
        $groups = [];

        foreach ($prizes as $prize) {
            $groups[$prize['prize_type']][] = $prize['prize_number'];
        }

        return array_map(
            fn (string $type, array $numbers): array => ['prize_type' => $type, 'prize_numbers' => array_values($numbers)],
            array_keys($groups),
            array_values($groups),
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function postSignedSanookIngest(array $payload, string $secret = 'test-secret'): \Illuminate\Testing\TestResponse
    {
        return $this->postSignedLiveIngest('sanook', $payload, $secret);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function postSignedLiveIngest(string $source, array $payload, string $secret = 'test-secret'): \Illuminate\Testing\TestResponse
    {
        $body = json_encode($payload, JSON_THROW_ON_ERROR);
        $timestamp = (string) time();
        $signature = 'sha256='.hash_hmac('sha256', $timestamp.'.'.$body, $secret);

        return $this->call('POST', '/api/v1/internal/reward-ingest/'.$source, [], [], [], [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X_LOTTO_SCRAPER_TIMESTAMP' => $timestamp,
            'HTTP_X_LOTTO_SCRAPER_SIGNATURE' => $signature,
        ], $body);
    }

}
