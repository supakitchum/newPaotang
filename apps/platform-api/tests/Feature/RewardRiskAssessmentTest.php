<?php

namespace Tests\Feature;

use App\Jobs\FanoutRewardRiskAssessmentJob;
use App\Modules\Reward\Services\RewardService;
use App\Modules\RewardRisk\Services\RewardRiskAssessmentService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Tests\Support\M7RewardFixtures;
use Tests\TestCase;

class RewardRiskAssessmentTest extends TestCase
{
    use M7RewardFixtures;
    use RefreshDatabase;

    public function test_changed_primary_live_payload_and_final_publish_schedule_isolated_assessment_jobs(): void
    {
        $liveWorld = $this->prepareRewardWorld(
            'par_risk_trigger_live',
            'ten_risk_trigger_live',
            'risk-trigger-live.test',
            'gam_risk_trigger_live',
            '0808100091',
            819001,
        );
        $this->insertSetting($liveWorld['tenant_id'], ['first_prize'], '1.00');
        DB::table('games')->where('id', $liveWorld['game_id'])->update(['code' => '01082569', 'updated_at' => now()]);
        Queue::fake();
        $payload = [
            'source' => 'sanook',
            'draw_code' => '01082569',
            'draw_date' => '2026-08-01',
            'scraped_at' => now()->toISOString(),
            'completion_percent' => 8.5,
            'payload_hash' => hash('sha256', 'risk-live-payload'),
            'prizes' => [[
                'prize_type' => 'first_prize',
                'prize_numbers' => [$liveWorld['ticket_number']],
            ]],
        ];

        $result = app(RewardService::class)->ingestLiveResult(
            $payload,
            Request::create('/api/v1/internal/reward-ingest/sanook', 'POST', $payload),
        );
        $this->assertTrue((bool) data_get($result, 'resource.changed'));
        Queue::assertPushed(FanoutRewardRiskAssessmentJob::class, fn (FanoutRewardRiskAssessmentJob $job): bool => (
            $job->rewardResultId === data_get($result, 'resource.reward_result_id')
            && $job->phase === 'provisional'
            && $job->sourceHash === $payload['payload_hash']
        ));

        $finalWorld = $this->prepareRewardWorld(
            'par_risk_trigger_final',
            'ten_risk_trigger_final',
            'risk-trigger-final.test',
            'gam_risk_trigger_final',
            '0808100092',
            819101,
        );
        $this->insertSetting($finalWorld['tenant_id'], ['first_prize'], '1.00');
        $published = $this->publishReward($finalWorld, keySuffix: 'risk-trigger-final');

        Queue::assertPushed(FanoutRewardRiskAssessmentJob::class, fn (FanoutRewardRiskAssessmentJob $job): bool => (
            $job->rewardResultId === $published['id'] && $job->phase === 'final'
        ));
    }

    public function test_stale_provisional_payload_cannot_replace_the_latest_assessment(): void
    {
        $world = $this->prepareRewardWorld(
            'par_risk_stale',
            'ten_risk_stale',
            'risk-stale.test',
            'gam_risk_stale',
            '0808100093',
            819201,
        );
        $this->insertSetting($world['tenant_id'], ['first_prize'], '1.00');
        $rewardResultId = $this->insertRewardResultWithMatches($world, 'draft', false);
        DB::table('reward_results')->where('id', $rewardResultId)->update([
            'summary_json' => json_encode(['source' => ['payload_hash' => 'payload-new']], JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ]);

        $service = app(RewardRiskAssessmentService::class);
        $this->assertNull($service->evaluateTenant($world['tenant_id'], $rewardResultId, 'provisional', 'payload-old'));
        $this->assertDatabaseCount('reward_risk_runs', 0);

        $run = $service->evaluateTenant($world['tenant_id'], $rewardResultId, 'provisional', 'payload-new');
        $this->assertNotNull($run);
        $this->assertSame('completed', $run['status']);
        $this->assertDatabaseCount('reward_risk_runs', 1);
    }

    public function test_final_assessment_groups_multiple_prizes_and_never_mutates_transactional_records(): void
    {
        $world = $this->prepareRewardWorld(
            'par_risk_final',
            'ten_risk_final',
            'risk-final.test',
            'gam_risk_final',
            '0808100001',
            810001,
        );
        $rewardResultId = $this->insertRewardResultWithMatches($world, 'published');
        $this->insertSetting($world['tenant_id'], ['first_prize', 'back2'], '1.00');

        $before = [
            'order' => DB::table('orders')->where('id', $world['order']['id'])->first(),
            'ticket' => DB::table('tickets')->where('id', $world['ticket_id'])->first(),
            'winning' => DB::table('winning_tickets')->where('reward_result_id', $rewardResultId)->orderBy('id')->get()->all(),
            'claims' => DB::table('reward_claims')->count(),
        ];

        $run = app(RewardRiskAssessmentService::class)->evaluateTenant(
            $world['tenant_id'],
            $rewardResultId,
            'final',
            'final-source-v1',
        );

        $purchaseAmount = (int) DB::table('order_items')->where('order_id', $world['order']['id'])->sum('price_amount');
        $this->assertSame(1, $run['evaluated_group_count']);
        $this->assertSame(1, $run['finding_count']);
        $this->assertDatabaseHas('reward_risk_findings', [
            'run_id' => $run['id'],
            'tenant_id' => $world['tenant_id'],
            'customer_id' => $world['auth']['user']['id'],
            'full_number' => $world['ticket_number'],
            'ticket_count' => 1,
            'purchase_amount' => $purchaseAmount,
            'prize_amount' => 600200000,
            'threshold_amount' => $purchaseAmount,
            'excess_amount' => 600200000 - $purchaseAmount,
            'status' => 'threshold_exceeded',
        ]);
        $this->assertSame(2, DB::table('reward_risk_finding_tickets')->where('run_id', $run['id'])->count());

        $this->assertEquals($before['order'], DB::table('orders')->where('id', $world['order']['id'])->first());
        $this->assertEquals($before['ticket'], DB::table('tickets')->where('id', $world['ticket_id'])->first());
        $this->assertEquals($before['winning'], DB::table('winning_tickets')->where('reward_result_id', $rewardResultId)->orderBy('id')->get()->all());
        $this->assertSame($before['claims'], DB::table('reward_claims')->count());

        DB::table('orders')->where('id', $world['order']['id'])->update(['refunded_at' => now(), 'updated_at' => now()]);
        $refundedRun = app(RewardRiskAssessmentService::class)->evaluateTenant(
            $world['tenant_id'],
            $rewardResultId,
            'final',
            'final-source-after-refund',
        );
        $this->assertSame(0, $refundedRun['evaluated_group_count']);
        $this->assertSame(0, $refundedRun['finding_count']);
        $this->assertDatabaseHas('reward_risk_runs', [
            'id' => $run['id'],
            'status' => 'superseded',
            'is_current' => false,
        ]);
    }

    public function test_provisional_assessment_uses_selected_prizes_and_settings_version_for_idempotency(): void
    {
        $world = $this->prepareRewardWorld(
            'par_risk_live',
            'ten_risk_live',
            'risk-live.test',
            'gam_risk_live',
            '0808100002',
            810101,
        );
        $rewardResultId = $this->insertRewardResultWithMatches($world, 'draft', false);
        $settingId = $this->insertSetting($world['tenant_id'], ['back2'], '1.00');
        $service = app(RewardRiskAssessmentService::class);

        $first = $service->evaluateTenant($world['tenant_id'], $rewardResultId, 'provisional', 'payload-a');
        $replay = $service->evaluateTenant($world['tenant_id'], $rewardResultId, 'provisional', 'payload-a');

        $this->assertSame($first['id'], $replay['id']);
        $this->assertSame(1, DB::table('reward_risk_runs')->where('tenant_id', $world['tenant_id'])->count());
        $this->assertDatabaseHas('reward_risk_findings', [
            'run_id' => $first['id'],
            'prize_amount' => 200000,
        ]);
        $this->assertDatabaseMissing('reward_risk_finding_tickets', [
            'run_id' => $first['id'],
            'prize_type' => 'first_prize',
        ]);

        DB::table('tenant_reward_risk_settings')->where('id', $settingId)->update([
            'threshold_multiplier' => '1000.00',
            'version' => 2,
            'updated_at' => now(),
        ]);
        $second = $service->evaluateTenant($world['tenant_id'], $rewardResultId, 'provisional', 'payload-a');

        $this->assertNotSame($first['id'], $second['id']);
        $this->assertSame(0, $second['finding_count']);
        $this->assertSame(2, DB::table('reward_risk_runs')->where('tenant_id', $world['tenant_id'])->count());
        $this->assertDatabaseHas('reward_risk_runs', ['id' => $first['id'], 'status' => 'superseded', 'is_current' => false]);
    }

    public function test_reward_risk_endpoints_require_restricted_roles_and_mask_central_customer_data(): void
    {
        $world = $this->prepareRewardWorld(
            'par_risk_api',
            'ten_risk_api',
            'risk-api.test',
            'gam_risk_api',
            '0808100003',
            810201,
        );
        $rewardResultId = $this->insertRewardResultWithMatches($world, 'published');
        $this->insertSetting($world['tenant_id'], ['first_prize'], '1.00');
        app(RewardRiskAssessmentService::class)->evaluateTenant($world['tenant_id'], $rewardResultId, 'final', 'api-final');

        $owner = $this->restrictedAdminSession('tenant', 'owner', ['reward_risk.view', 'reward_risk.manage'], $world, 'owner');
        $viewer = $this->restrictedAdminSession('tenant', 'risk_viewer', ['reward_risk.view', 'reward_risk.manage'], $world, 'viewer');

        $this->withToken($owner['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-risk/overview', $this->tenantHeaders($world))
            ->assertOk()
            ->assertJsonPath('final.finding_count', 1);
        $this->withToken($viewer['access_token'])
            ->getJson('/api/v1/admin/tenant/reward-risk/overview', $this->tenantHeaders($world))
            ->assertForbidden();
        $this->withToken($owner['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '1001.2001',
                'channel_name' => 'private-admin.tenant.'.$world['tenant_id'].'.reward-risk',
            ], $this->tenantHeaders($world))
            ->assertOk();
        $this->withToken($viewer['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '1001.2002',
                'channel_name' => 'private-admin.tenant.'.$world['tenant_id'].'.reward-risk',
            ], $this->tenantHeaders($world))
            ->assertForbidden();

        $this->withToken($owner['access_token'])
            ->putJson('/api/v1/admin/tenant/reward-risk/settings', [
                'enabled' => true,
                'monitored_prize_types' => ['first_prize', 'back2'],
                'threshold_multiplier' => '1.25',
            ], $this->tenantHeaders($world) + ['Idempotency-Key' => 'risk-settings-api'])
            ->assertOk()
            ->assertJsonPath('threshold_multiplier', '1.25');
        $this->withToken($owner['access_token'])
            ->putJson('/api/v1/admin/tenant/reward-risk/settings', [
                'enabled' => true,
                'monitored_prize_types' => ['first_prize', 'back2'],
                'threshold_multiplier' => '1.25',
            ], $this->tenantHeaders($world) + ['Idempotency-Key' => 'risk-settings-api'])
            ->assertOk()
            ->assertJsonPath('threshold_multiplier', '1.25');
        $this->assertSame(2, (int) DB::table('tenant_reward_risk_settings')->where('tenant_id', $world['tenant_id'])->value('version'));
        $this->assertSame(1, DB::table('audit_logs')->where('action', 'reward_risk.settings.updated')->where('tenant_id', $world['tenant_id'])->count());
        $this->withToken($owner['access_token'])
            ->putJson('/api/v1/admin/tenant/reward-risk/settings', [
                'enabled' => true,
                'monitored_prize_types' => ['first_prize'],
                'threshold_multiplier' => '2.00',
            ], $this->tenantHeaders($world) + ['Idempotency-Key' => 'risk-settings-api'])
            ->assertConflict()
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $superAdmin = $this->restrictedAdminSession('central', 'super_admin', ['reward_risk.view'], $world, 'super');
        $centralViewer = $this->restrictedAdminSession('central', 'risk_viewer', ['reward_risk.view'], $world, 'central-viewer');
        $response = $this->withToken($superAdmin['access_token'])
            ->getJson('/api/v1/admin/central/reward-risk/findings', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.customer.id', null)
            ->json();

        $this->assertStringContainsString('*', (string) data_get($response, 'data.0.customer.customer_no'));
        $this->assertStringContainsString('*', (string) data_get($response, 'data.0.customer.phone'));
        $this->withToken($superAdmin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '1001.2003',
                'channel_name' => 'private-admin.central.reward-risk',
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk();
        $this->withToken($centralViewer['access_token'])
            ->getJson('/api/v1/admin/central/reward-risk/overview', ['X-Admin-Scope' => 'central'])
            ->assertForbidden();
        $this->withToken($centralViewer['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '1001.2004',
                'channel_name' => 'private-admin.central.reward-risk',
            ], ['X-Admin-Scope' => 'central'])
            ->assertForbidden();
    }

    private function insertSetting(string $tenantId, array $types, string $multiplier): string
    {
        $id = 'rrs_'.substr(sha1($tenantId), 0, 20);
        DB::table('tenant_reward_risk_settings')->insert([
            'id' => $id,
            'tenant_id' => $tenantId,
            'enabled' => true,
            'monitored_prize_types_json' => json_encode($types, JSON_THROW_ON_ERROR),
            'threshold_multiplier' => $multiplier,
            'version' => 1,
            'updated_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $id;
    }

    private function insertRewardResultWithMatches(array $world, string $status, bool $insertWinners = true): string
    {
        $rewardResultId = 'rew_'.substr(sha1($world['tenant_id']), 0, 20);
        $now = now();
        DB::table('reward_results')->insert([
            'id' => $rewardResultId,
            'game_id' => $world['game_id'],
            'status' => $status,
            'version' => 1,
            'summary_json' => null,
            'created_by_admin_id' => null,
            'verified_by_admin_id' => null,
            'published_by_admin_id' => null,
            'corrected_by_admin_id' => null,
            'correction_note' => null,
            'checked_at' => $status === 'published' ? $now : null,
            'verified_at' => $status === 'published' ? $now : null,
            'published_at' => $status === 'published' ? $now : null,
            'corrected_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $prizes = [
            ['id' => 'rpr_'.substr(sha1($rewardResultId.':first'), 0, 20), 'type' => 'first_prize', 'number' => $world['ticket_number'], 'amount' => 600000000],
            ['id' => 'rpr_'.substr(sha1($rewardResultId.':back2'), 0, 20), 'type' => 'back2', 'number' => substr($world['ticket_number'], -2), 'amount' => 200000],
        ];
        foreach ($prizes as $index => $prize) {
            DB::table('reward_prizes')->insert([
                'id' => $prize['id'],
                'reward_result_id' => $rewardResultId,
                'game_id' => $world['game_id'],
                'prize_type' => $prize['type'],
                'prize_number' => $prize['number'],
                'amount' => $prize['amount'],
                'currency' => 'THB',
                'sort_order' => $index,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            if ($insertWinners) {
                DB::table('winning_tickets')->insert([
                    'id' => 'wti_'.substr(sha1($world['ticket_id'].':'.$prize['type']), 0, 20),
                    'tenant_id' => $world['tenant_id'],
                    'game_id' => $world['game_id'],
                    'ticket_id' => $world['ticket_id'],
                    'reward_result_id' => $rewardResultId,
                    'reward_prize_id' => $prize['id'],
                    'prize_type' => $prize['type'],
                    'prize_number' => $prize['number'],
                    'amount' => $prize['amount'],
                    'currency' => 'THB',
                    'status' => 'verified',
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        return $rewardResultId;
    }

    private function restrictedAdminSession(string $scope, string $roleCode, array $permissions, array $world, string $suffix): array
    {
        $adminId = 'adm_risk_'.substr(sha1($scope.':'.$suffix), 0, 12);
        $email = 'risk-'.$scope.'-'.$suffix.'@example.test';
        $scopeId = 'scp_'.$adminId;
        $this->createAdmin($adminId, $email);
        $this->createAdminScope(
            $scopeId,
            $scope,
            $scope === 'tenant' ? $world['tenant_id'] : null,
            $scope === 'tenant' ? $world['partner_id'] : null,
        );
        $this->assignRoleWithPermissions(
            $adminId,
            $scopeId,
            $scope,
            $scope === 'tenant' ? $world['tenant_id'] : null,
            $permissions,
            $roleCode,
        );

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => $scope,
            'tenant_id' => $scope === 'tenant' ? $world['tenant_id'] : null,
        ]);
    }

    private function tenantHeaders(array $world): array
    {
        return ['X-Admin-Scope' => 'tenant', 'X-Tenant-Id' => $world['tenant_id']];
    }
}
