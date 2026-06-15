<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M7RewardFixtures;
use Tests\TestCase;

class RewardEntryTest extends TestCase
{
    use M7RewardFixtures;
    use RefreshDatabase;

    public function test_result_officers_submit_independent_entries_and_owner_resolves_without_winner_access(): void
    {
        $this->seedDefaultRbac();
        $world = $this->prepareRewardWorld('par_reward_entry', 'ten_reward_entry', 'reward-entry.m7.test', 'gam_reward_entry', '0807440000', 794401);

        $officerOne = $this->createResultOfficerSession('adm_result_one', 'result-one@example.test');
        $officerTwo = $this->createResultOfficerSession('adm_result_two', 'result-two@example.test');
        $owner = $this->centralRewardAdmin(['reward_entry.view', 'reward_entry.submit', 'reward_entry.resolve'], 'reward-entry-owner');
        $prizes = $this->thaiGovernmentLotteryPrizes('123456', $world['ticket_number']);

        $session = $this->withToken($officerOne['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/current?game_id='.$world['game_id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.expected_operator_count', 2)
            ->assertJsonPath('data.submitted_count', 0)
            ->assertJsonPath('data.scraper_snapshot', null)
            ->json('data');

        $this->withToken($officerOne['access_token'])
            ->getJson('/api/v1/admin/central/winners', ['X-Admin-Scope' => 'central'])
            ->assertForbidden();

        $this->withToken($officerOne['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/resolve', [
                'selected_source_type' => 'manual',
                'final_prizes' => $prizes,
                'reason' => 'not owner',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-denied-resolve',
            ])
            ->assertForbidden();

        $this->withToken($officerOne['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/submit', [
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-submit-one',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'collecting')
            ->assertJsonPath('submitted_count', 1)
            ->assertJsonPath('submission.status', 'submitted')
            ->assertJsonPath('submission.diff_to_scraper.summary.has_scraper', false);

        $this->withToken($officerTwo['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/submit', [
                'prizes' => $prizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-submit-two',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'ready_for_owner')
            ->assertJsonPath('submitted_count', 2);

        $comparison = $this->withToken($owner['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/comparison', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonCount(2, 'data.sources')
            ->json('data');

        $selectedSubmissionId = $comparison['sources'][0]['id'];

        $this->withToken($owner['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/resolve', [
                'selected_source_type' => 'submission',
                'selected_submission_id' => $selectedSubmissionId,
                'final_prizes' => $prizes,
                'reason' => 'Both result officers submitted matching results.',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-owner-resolve',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'resolved')
            ->assertJsonPath('resolution.selected_source_type', 'submission');

        $this->assertDatabaseHas('reward_entry_sessions', [
            'id' => $session['id'],
            'status' => 'resolved',
            'game_id' => $world['game_id'],
        ]);
        $this->assertDatabaseHas('reward_results', [
            'game_id' => $world['game_id'],
        ]);
        $this->assertDatabaseMissing('reward_results', [
            'game_id' => $world['game_id'],
            'status' => 'published',
        ]);
    }

    public function test_reward_entry_refreshes_lotto_scraper_snapshot_after_session_was_created(): void
    {
        $this->seedDefaultRbac();
        $world = $this->prepareRewardWorld('par_reward_entry_late', 'ten_reward_entry_late', 'reward-entry-late.m7.test', 'gam_reward_entry_late', '0807440011', 794501);

        $officer = $this->createResultOfficerSession('adm_result_late', 'result-late@example.test');
        $owner = $this->centralRewardAdmin(['reward_entry.view', 'reward_entry.submit', 'reward_entry.resolve'], 'reward-entry-late-owner');
        $operatorPrizes = $this->thaiGovernmentLotteryPrizes('123456', $world['ticket_number']);

        $session = $this->withToken($officer['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/current?game_id='.$world['game_id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.scraper_snapshot', null)
            ->json('data');

        $scraperPrizes = $this->thaiGovernmentLotteryPrizes('654321', $world['ticket_number']);
        $this->insertDraftScraperRewardResult($world['game_id'], $scraperPrizes);

        $this->withToken($officer['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/submit', [
                'prizes' => $operatorPrizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-late-submit',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'ready_for_owner')
            ->assertJsonPath('submission.diff_to_scraper.summary.has_scraper', true)
            ->assertJsonPath('submission.diff_to_scraper.summary.mismatch_count', 1);

        $this->withToken($owner['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/comparison', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.sources.0.source_type', 'scraper')
            ->assertJsonPath('data.sources.0.prizes.0.prize_number', '654321');

        $this->assertDatabaseMissing('reward_entry_sessions', [
            'id' => $session['id'],
            'scraper_snapshot_json' => null,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function createResultOfficerSession(string $adminId, string $email): array
    {
        $this->createAdmin($adminId, $email);
        $scopeId = 'scp_'.$adminId;
        $this->createAdminScope($scopeId, 'central');

        DB::table('admin_user_roles')->insert([
            'admin_user_id' => $adminId,
            'role_id' => 'rol_c_result_officer',
            'scope_id' => $scopeId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    /**
     * @param array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}> $prizes
     */
    private function insertDraftScraperRewardResult(string $gameId, array $prizes): void
    {
        $now = now();
        $rewardResultId = 'rew_late_scraper';

        DB::table('reward_results')->insert([
            'id' => $rewardResultId,
            'game_id' => $gameId,
            'status' => 'draft',
            'version' => 1,
            'summary_json' => json_encode([
                'source' => [
                    'name' => 'sanook',
                    'draw_code' => '01062569',
                    'payload_hash' => 'late-scraper-payload',
                ],
                'live' => [
                    'status' => 'draft',
                    'completion_percent' => 100,
                    'updated_at' => $now->toISOString(),
                ],
            ], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        DB::table('reward_prizes')->insert(array_map(fn (array $prize, int $index): array => [
            'id' => 'rpr_late_scraper_'.str_pad((string) $index, 3, '0', STR_PAD_LEFT),
            'reward_result_id' => $rewardResultId,
            'game_id' => $gameId,
            'prize_type' => $prize['prize_type'],
            'prize_number' => $prize['prize_number'],
            'amount' => $prize['amount']['amount'],
            'currency' => $prize['amount']['currency'],
            'sort_order' => $index,
            'created_at' => $now,
            'updated_at' => $now,
        ], $prizes, array_keys($prizes)));
    }
}
