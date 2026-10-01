<?php

namespace Tests\Feature;

use App\Jobs\TriggerLottoScraperPollJob;
use App\Modules\Reward\Services\LottoScraperTriggerClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Bus;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
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

    public function test_reward_entry_owner_comparison_includes_thairath_snapshot(): void
    {
        $this->seedDefaultRbac();
        $world = $this->prepareRewardWorld('par_re_msrc', 'ten_re_msrc', 'reward-entry-multi-source.m7.test', 'gam_re_msrc', '0807440022', 794601);

        $officer = $this->createResultOfficerSession('adm_re_msrc', 'result-multi-source@example.test');
        $owner = $this->centralRewardAdmin(['reward_entry.view', 'reward_entry.submit', 'reward_entry.resolve'], 'reward-entry-multi-source-owner');
        $operatorPrizes = $this->thaiGovernmentLotteryPrizes('123456', $world['ticket_number']);
        $sanookPrizes = $this->thaiGovernmentLotteryPrizes('654321', $world['ticket_number']);
        $thairathPrizes = $this->thaiGovernmentLotteryPrizes('789012', $world['ticket_number']);
        $sanookPrizes = $this->replaceFirstPrizeNumbersForType($sanookPrizes, 'fourth_prize', ['000002', '000001']);
        $thairathPrizes = $this->replaceFirstPrizeNumbersForType($thairathPrizes, 'fourth_prize', ['000001', '000002']);

        $session = $this->withToken($officer['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/current?game_id='.$world['game_id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->json('data');

        $this->insertDraftScraperRewardResult($world['game_id'], $sanookPrizes, [
            'thairath' => $thairathPrizes,
        ]);

        $this->withToken($owner['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/current?game_id='.$world['game_id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.scraper_snapshot.sources.0.label', 'Sanook')
            ->assertJsonPath('data.scraper_snapshot.sources.1.label', 'Thai Rath')
            ->assertJsonPath('data.scraper_snapshot.sources.1.prizes.0.prize_number', '789012');

        $this->withToken($officer['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/current?game_id='.$world['game_id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.scraper_snapshot.sources.0.label', 'Sanook')
            ->assertJsonPath('data.scraper_snapshot.sources.0.meta.live.completion_percent', 100)
            ->assertJsonPath('data.scraper_snapshot.sources.1.label', 'Thai Rath')
            ->assertJsonPath('data.scraper_snapshot.sources.1.meta.live.completion_percent', 100)
            ->assertJsonMissingPath('data.scraper_snapshot.sources.0.prizes.0.prize_number')
            ->assertJsonMissingPath('data.scraper_snapshot.sources.1.prizes.0.prize_number')
            ->assertJsonMissingPath('data.scraper_snapshot.prizes.0.prize_number');

        $this->withToken($officer['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/submit', [
                'prizes' => $operatorPrizes,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-multi-source-submit',
            ])
            ->assertAccepted()
            ->assertJsonPath('submission.diff_to_scraper.summary.source_count', 2)
            ->assertJsonPath('submission.diff_to_scraper.summary.sources.1.label', 'Thai Rath')
            ->assertJsonPath('submission.diff_to_scraper.rows.0.scraper_sources.1.number', '789012');

        $comparison = $this->withToken($owner['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/comparison', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.sources.0.id', 'scraper')
            ->assertJsonPath('data.sources.0.label', 'Sanook')
            ->assertJsonPath('data.sources.1.id', 'scraper:thairath')
            ->assertJsonPath('data.sources.1.label', 'Thai Rath')
            ->assertJsonPath('data.sources.1.prizes.0.prize_number', '789012')
            ->json('data');

        $fourthPrizeRows = array_values(array_filter(
            $comparison['matrix'] ?? [],
            fn (array $row): bool => ($row['prize_type'] ?? null) === 'fourth_prize',
        ));

        $this->assertSame('000001', $fourthPrizeRows[0]['values'][0]['number'] ?? null);
        $this->assertSame('000001', $fourthPrizeRows[0]['values'][1]['number'] ?? null);
        $this->assertSame('000002', $fourthPrizeRows[1]['values'][0]['number'] ?? null);
        $this->assertSame('000002', $fourthPrizeRows[1]['values'][1]['number'] ?? null);
    }

    public function test_reward_entry_manual_trigger_queues_selected_scraper_source(): void
    {
        $this->seedDefaultRbac();
        $world = $this->prepareRewardWorld('par_re_trigger', 'ten_re_trigger', 'reward-entry-trigger.m7.test', 'gam_re_trigger', '0807440033', 794701);

        $officer = $this->createResultOfficerSession('adm_re_trigger', 'result-trigger@example.test');
        $drawCode = (string) DB::table('games')->where('id', $world['game_id'])->value('code');
        $drawDate = \Carbon\CarbonImmutable::parse((string) DB::table('games')->where('id', $world['game_id'])->value('draw_at'))
            ->timezone('Asia/Bangkok')
            ->format('Y-m-d');

        $session = $this->withToken($officer['access_token'])
            ->getJson('/api/v1/admin/central/reward-entry/sessions/current?game_id='.$world['game_id'], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->json('data');

        Bus::fake();

        $this->withToken($officer['access_token'])
            ->postJson('/api/v1/admin/central/reward-entry/sessions/'.$session['id'].'/trigger-scraper', [
                'source' => 'thairath',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'reward-entry-trigger-thairath',
            ])
            ->assertAccepted()
            ->assertJsonPath('session_id', $session['id'])
            ->assertJsonPath('draw_code', $drawCode)
            ->assertJsonPath('draw_date', $drawDate)
            ->assertJsonPath('source', 'thairath')
            ->assertJsonPath('status', 'queued');

        Bus::assertDispatched(TriggerLottoScraperPollJob::class, function (TriggerLottoScraperPollJob $job) use ($drawCode, $drawDate, $world): bool {
            return $job->drawCode === $drawCode
                && $job->gameId === $world['game_id']
                && $job->source === 'thairath'
                && $job->drawDate === $drawDate;
        });
    }

    public function test_lotto_scraper_trigger_client_sends_source_specific_payloads(): void
    {
        config([
            'platform.lotto_scraper.trigger_source_urls' => [
                'sanook' => 'http://lotto-scraper:3200/internal/poll',
                'thairath' => 'http://lotto-scraper-thairath:3200/internal/poll',
            ],
            'platform.lotto_scraper.trigger_urls' => [],
            'platform.lotto_scraper.trigger_url' => '',
            'platform.lotto_scraper.trigger_secret' => 'test-secret',
        ]);

        $requests = [];

        Http::fake(function ($request) use (&$requests) {
            $requests[] = [
                'url' => (string) $request->url(),
                'payload' => json_decode((string) $request->body(), true, 512, JSON_THROW_ON_ERROR),
            ];

            return Http::response(['ok' => true], 202);
        });

        $result = app(LottoScraperTriggerClient::class)->triggerDraw(
            '16062569',
            'gam_reward_trigger_source',
            'reward_entry_manual_all',
            'all',
            '2026-06-16',
        );

        $this->assertTrue($result['ok']);
        $this->assertCount(2, $requests);
        $this->assertSame('sanook', $requests[0]['payload']['source']);
        $this->assertSame('thairath', $requests[1]['payload']['source']);
        $this->assertSame('2026-06-16', $requests[0]['payload']['draw_date']);
        $this->assertSame('2026-06-16', $requests[1]['payload']['draw_date']);
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
     * @param array<int, string> $numbers
     * @return array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}>
     */
    private function replaceFirstPrizeNumbersForType(array $prizes, string $type, array $numbers): array
    {
        $index = 0;

        return array_map(function (array $prize) use ($type, $numbers, &$index): array {
            if ($prize['prize_type'] !== $type || ! array_key_exists($index, $numbers)) {
                return $prize;
            }

            $prize['prize_number'] = $numbers[$index];
            $index++;

            return $prize;
        }, $prizes);
    }

    /**
     * @param array<int, array{prize_type: string, prize_number: string, amount: array{amount: int, currency: string}}> $prizes
     */
    private function insertDraftScraperRewardResult(string $gameId, array $prizes, array $comparisonSources = []): void
    {
        $now = now();
        $rewardResultId = 'rew_late_scraper';
        $comparisonSourcePayloads = [];

        foreach ($comparisonSources as $source => $sourcePrizes) {
            $comparisonSourcePayloads[$source] = [
                'source' => [
                    'name' => $source,
                    'draw_code' => '01062569',
                    'payload_hash' => $source.'-scraper-payload',
                    'completion_percent' => 100,
                ],
                'live' => [
                    'status' => 'draft',
                    'completion_percent' => 100,
                    'updated_at' => $now->toISOString(),
                ],
                'updated_at' => $now->toISOString(),
                'prizes' => $sourcePrizes,
            ];
        }

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
                'comparison_sources' => $comparisonSourcePayloads,
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
