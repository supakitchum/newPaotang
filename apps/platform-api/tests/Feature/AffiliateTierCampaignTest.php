<?php

namespace Tests\Feature;

use App\Models\AffiliateTierCampaign;
use App\Modules\Growth\Services\AffiliateTierService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use RuntimeException;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class AffiliateTierCampaignTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_campaign_batch_isolates_one_failure_and_finalizes_the_next_campaign(): void
    {
        $this->seedDefaultRbac();
        $tenantId = 'ten_aff_batch_isolation';
        $this->insertActivePartnerTenant('par_aff_batch_isolation', $tenantId);
        $realService = app(AffiliateTierService::class);
        $tiers = $realService->ensureTenantTiers($tenantId);
        $failedCampaignId = $this->insertCampaign($tenantId, 'fixed_threshold', [
            [0, 'bronze'],
            [200, 'silver'],
        ], $tiers, 'batch-failed');
        $goodCampaignId = $this->insertCampaign($tenantId, 'fixed_threshold', [
            [0, 'bronze'],
            [200, 'silver'],
        ], $tiers, 'batch-good');

        $service = $this->partialMock(AffiliateTierService::class, function ($mock) use ($tenantId, $failedCampaignId): void {
            $mock->shouldReceive('finalizeCampaign')
                ->once()
                ->with($tenantId, $failedCampaignId)
                ->andThrow(new RuntimeException('synthetic campaign failure'));
            $mock->shouldReceive('finalizeCampaign')
                ->atLeast()
                ->once()
                ->passthru();
        });

        $result = $service->finalizeDueCampaignsBatch();

        $this->assertSame(2, $result['selected']);
        $this->assertSame(1, $result['succeeded']);
        $this->assertSame(1, $result['failed']);
        $this->assertSame($failedCampaignId, $result['failures'][0]['campaign_id']);
        $this->assertSame(RuntimeException::class, $result['failures'][0]['exception']);
        $this->assertDatabaseHas('affiliate_tier_campaigns', [
            'id' => $failedCampaignId,
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('affiliate_tier_campaigns', [
            'id' => $goodCampaignId,
            'status' => 'completed',
        ]);
    }

    public function test_fixed_campaign_applies_every_threshold_and_can_reduce_an_existing_tier(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_aff_fixed';
        $tenantId = 'ten_aff_fixed';
        $gameId = 'gam_aff_fixed';
        $this->insertActivePartnerTenant($partnerId, $tenantId);
        $this->insertGame($gameId, 'open');
        $service = app(AffiliateTierService::class);
        $tiers = $service->ensureTenantTiers($tenantId);
        $cases = [
            ['count' => 0, 'expected' => 'bronze'],
            ['count' => 199, 'expected' => 'bronze'],
            ['count' => 200, 'expected' => 'silver'],
            ['count' => 299, 'expected' => 'silver'],
            ['count' => 300, 'expected' => 'gold'],
            ['count' => 399, 'expected' => 'gold'],
            ['count' => 400, 'expected' => 'platinum'],
            ['count' => 499, 'expected' => 'platinum'],
            ['count' => 500, 'expected' => 'diamond'],
            ['count' => 250, 'expected' => 'silver', 'initial' => 'diamond'],
            ['count' => 5, 'expected' => 'bronze', 'initial' => 'gold', 'excluded' => 'refunded'],
            ['count' => 5, 'expected' => 'bronze', 'initial' => 'diamond', 'excluded' => 'cancelled'],
        ];
        $affiliateIds = [];
        $orderIds = [];

        foreach ($cases as $index => $case) {
            $initial = (string) ($case['initial'] ?? 'bronze');
            $affiliate = $this->insertAffiliate(
                $tenantId,
                sprintf('F%05d', $index),
                (string) $tiers[$initial]->id,
                'fixed-'.$index,
            );
            $affiliateIds[$index] = $affiliate['affiliate_id'];
            if ($case['count'] > 0) {
                $orderIds[$index] = $this->insertAttributedPaidSale(
                    $partnerId,
                    $tenantId,
                    $gameId,
                    $affiliate,
                    (int) $case['count'],
                    now()->subHour(),
                    'fixed-'.$index,
                );
                if (($case['excluded'] ?? null) === 'refunded') {
                    DB::table('orders')->where('id', $orderIds[$index])->update([
                        'payment_status' => 'refunded',
                        'refunded_at' => now()->subMinute(),
                        'updated_at' => now(),
                    ]);
                } elseif (($case['excluded'] ?? null) === 'cancelled') {
                    DB::table('orders')->where('id', $orderIds[$index])->update([
                        'status' => 'cancelled',
                        'cancelled_at' => now()->subMinute(),
                        'updated_at' => now(),
                    ]);
                }
            }
        }

        $campaignId = $this->insertCampaign(
            $tenantId,
            'fixed_threshold',
            [
                [0, 'bronze'],
                [200, 'silver'],
                [300, 'gold'],
                [400, 'platinum'],
                [500, 'diamond'],
            ],
            $tiers,
            'fixed',
        );

        $result = $service->finalizeCampaign($tenantId, $campaignId);
        $this->assertArrayNotHasKey('error', $result);
        $this->assertSame('completed', $result['resource']['status']);

        foreach ($cases as $index => $case) {
            $expectedTicketCount = isset($case['excluded']) ? 0 : $case['count'];
            $programCode = DB::table('affiliate_accounts')
                ->join('affiliate_programs', 'affiliate_programs.id', '=', 'affiliate_accounts.affiliate_program_id')
                ->where('affiliate_accounts.id', $affiliateIds[$index])
                ->value('affiliate_programs.code');
            $this->assertSame($case['expected'], $programCode, 'Unexpected tier for '.$case['count'].' tickets.');
            $this->assertDatabaseHas('affiliate_tier_campaign_results', [
                'campaign_id' => $campaignId,
                'affiliate_account_id' => $affiliateIds[$index],
                'ticket_count' => $expectedTicketCount,
            ]);
            $this->assertDatabaseHas('affiliate_tier_campaign_stats', [
                'campaign_id' => $campaignId,
                'affiliate_account_id' => $affiliateIds[$index],
                'ticket_count' => $expectedTicketCount,
            ]);
        }

        $this->assertSame(10, DB::table('affiliate_tier_history')->where('campaign_id', $campaignId)->count());
        DB::table('orders')->where('id', $orderIds[8])->update([
            'payment_status' => 'refunded',
            'refunded_at' => now(),
            'updated_at' => now(),
        ]);
        $secondFinalize = $service->finalizeCampaign($tenantId, $campaignId);
        $this->assertArrayNotHasKey('error', $secondFinalize);
        $this->assertSame(count($cases), DB::table('affiliate_tier_campaign_results')->where('campaign_id', $campaignId)->count());
        $this->assertSame(10, DB::table('affiliate_tier_history')->where('campaign_id', $campaignId)->count());
        $this->assertSame(10, DB::table('customer_notifications')
            ->where('tenant_id', $tenantId)
            ->where('event_key', 'affiliate.tier.changed')
            ->where('subject_id', $campaignId)
            ->count());
    }

    public function test_ranking_campaign_uses_reached_time_then_code_and_never_reduces_tier(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_aff_rank';
        $tenantId = 'ten_aff_rank';
        $gameId = 'gam_aff_rank';
        $this->insertActivePartnerTenant($partnerId, $tenantId);
        $this->insertGame($gameId, 'open');
        $service = app(AffiliateTierService::class);
        $tiers = $service->ensureTenantTiers($tenantId);

        $early = $this->insertAffiliate($tenantId, 'Z00001', (string) $tiers['bronze']->id, 'rank-early');
        $codeFirst = $this->insertAffiliate($tenantId, 'A00001', (string) $tiers['bronze']->id, 'rank-code-first');
        $codeSecond = $this->insertAffiliate($tenantId, 'B00001', (string) $tiers['bronze']->id, 'rank-code-second');
        $existingDiamond = $this->insertAffiliate($tenantId, 'D00001', (string) $tiers['diamond']->id, 'rank-diamond');
        $nonParticipant = $this->insertAffiliate($tenantId, 'N00001', (string) $tiers['bronze']->id, 'rank-no-sales');
        $this->insertAttributedPaidSale($partnerId, $tenantId, $gameId, $early, 5, now()->subMinutes(90), 'rank-early');
        $this->insertAttributedPaidSale($partnerId, $tenantId, $gameId, $codeFirst, 5, now()->subMinutes(80), 'rank-code-first');
        $this->insertAttributedPaidSale($partnerId, $tenantId, $gameId, $codeSecond, 5, now()->subMinutes(80), 'rank-code-second');
        $this->insertAttributedPaidSale($partnerId, $tenantId, $gameId, $existingDiamond, 1, now()->subMinutes(70), 'rank-diamond');

        $campaignId = $this->insertCampaign(
            $tenantId,
            'ranking',
            [
                [1, 1, 'diamond'],
                [2, 2, 'platinum'],
                [3, 3, 'gold'],
            ],
            $tiers,
            'ranking',
        );
        $result = $service->finalizeCampaign($tenantId, $campaignId);
        $this->assertArrayNotHasKey('error', $result);
        $this->assertSame('Store rank-early', data_get($result, 'resource.leaderboard.0.affiliate_name'));
        $this->assertSame(5, data_get($result, 'resource.leaderboard.0.ticket_count'));

        $this->assertCampaignResult($campaignId, $early['affiliate_id'], 1, 'diamond');
        $this->assertCampaignResult($campaignId, $codeFirst['affiliate_id'], 2, 'platinum');
        $this->assertCampaignResult($campaignId, $codeSecond['affiliate_id'], 3, 'gold');
        $this->assertCampaignResult($campaignId, $existingDiamond['affiliate_id'], 4, 'diamond');
        $this->assertDatabaseMissing('affiliate_tier_campaign_results', [
            'campaign_id' => $campaignId,
            'affiliate_account_id' => $nonParticipant['affiliate_id'],
        ]);
        $this->assertSame('bronze', DB::table('affiliate_accounts')
            ->join('affiliate_programs', 'affiliate_programs.id', '=', 'affiliate_accounts.affiliate_program_id')
            ->where('affiliate_accounts.id', $nonParticipant['affiliate_id'])
            ->value('affiliate_programs.code'));
        $this->assertSame(3, DB::table('customer_notifications')
            ->where('tenant_id', $tenantId)
            ->where('event_key', 'affiliate.tier.changed')
            ->where('subject_id', $campaignId)
            ->count());
    }

    public function test_store_name_is_reserved_while_pending_and_change_cooldown_starts_only_on_approval(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_aff_name';
        $tenantId = 'ten_aff_name';
        $host = 'affiliate-name.test';
        $this->insertActivePartnerTenantWithDomain($partnerId, $tenantId, $host);
        $firstToken = $this->issueCustomerToken($tenantId, 'cus_aff_name_1');
        $secondToken = $this->issueCustomerToken($tenantId, 'cus_aff_name_2');

        $registered = $this->withToken($firstToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', ['name' => '  Café   Lucky  '], [
                'Idempotency-Key' => 'affiliate-name-register-1',
            ])
            ->assertCreated()
            ->assertJsonPath('store_name.status', 'pending')
            ->json();
        $this->withToken($secondToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate', ['name' => "CAFE\u{0301} LUCKY"], [
                'Idempotency-Key' => 'affiliate-name-register-2',
            ])
            ->assertUnprocessable();
        $this->getJson('http://'.$host.'/api/v1/public/stores')
            ->assertOk()
            ->assertJsonPath('data', []);

        $admin = $this->createTenantSession(
            $tenantId,
            $partnerId,
            ['affiliate_name_review.view', 'affiliate_name_review.manage'],
            'adm_aff_name',
            'affiliate-name-admin@example.test',
        );
        $requestId = (string) DB::table('affiliate_store_name_requests')
            ->where('affiliate_account_id', $registered['affiliate']['id'])
            ->where('status', 'pending')
            ->value('id');
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $tenantId,
            'Idempotency-Key' => 'affiliate-name-approve-1',
        ];
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-store-name-requests/'.$requestId.'/approve', [], $headers)
            ->assertOk();
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $tenantId,
            'event_key' => 'affiliate.store_name.approved',
            'subject_id' => $requestId,
        ]);
        $this->getJson('http://'.$host.'/api/v1/public/stores')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Café Lucky');

        $this->withToken($firstToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/store-name-requests', ['name' => 'Lucky Next'], [
                'Idempotency-Key' => 'affiliate-name-change-too-soon',
            ])
            ->assertUnprocessable();

        DB::table('affiliate_accounts')
            ->where('id', $registered['affiliate']['id'])
            ->update([
                'store_name_approved_at' => now()->subMonthsNoOverflow(3),
                'store_name_change_available_at' => now()->subSecond(),
                'updated_at' => now(),
            ]);
        $change = $this->withToken($firstToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/store-name-requests', ['name' => 'Lucky Next'], [
                'Idempotency-Key' => 'affiliate-name-change-allowed',
            ])
            ->assertCreated()
            ->json();
        $this->getJson('http://'.$host.'/api/v1/public/stores')
            ->assertOk()
            ->assertJsonPath('data.0.name', 'Café Lucky');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-store-name-requests/'.$change['id'].'/reject', [
                'reason' => 'Please choose another name.',
            ], $headers + ['Idempotency-Key' => 'affiliate-name-reject-change'])
            ->assertOk();
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $tenantId,
            'event_key' => 'affiliate.store_name.rejected',
            'subject_id' => $change['id'],
        ]);
        $this->withToken($firstToken)
            ->postJson('http://'.$host.'/api/v1/customer/affiliate/store-name-requests', ['name' => 'Lucky Final'], [
                'Idempotency-Key' => 'affiliate-name-change-after-reject',
            ])
            ->assertCreated();
    }

    public function test_campaign_milestone_notifications_are_sent_once_and_future_campaign_cannot_finalize(): void
    {
        $this->seedDefaultRbac();
        $tenantId = 'ten_aff_milestone';
        $this->insertActivePartnerTenant('par_aff_milestone', $tenantId);
        $service = app(AffiliateTierService::class);
        $tiers = $service->ensureTenantTiers($tenantId);
        $affiliate = $this->insertAffiliate(
            $tenantId,
            'M00001',
            (string) $tiers['bronze']->id,
            'milestone',
        );
        $now = now();
        DB::table('affiliate_tier_campaigns')->insert([
            [
                'id' => 'atc_milestone_started',
                'tenant_id' => $tenantId,
                'name' => 'Started campaign',
                'campaign_type' => 'fixed_threshold',
                'status' => 'scheduled',
                'starts_at' => $now->copy()->subMinute(),
                'ends_at' => $now->copy()->addDays(2),
                'created_at' => $now,
                'updated_at' => $now,
            ],
            [
                'id' => 'atc_milestone_ending',
                'tenant_id' => $tenantId,
                'name' => 'Ending campaign',
                'campaign_type' => 'ranking',
                'status' => 'active',
                'starts_at' => $now->copy()->subDay(),
                'ends_at' => $now->copy()->addHour(),
                'created_at' => $now,
                'updated_at' => $now,
            ],
        ]);

        $this->assertSame(0, $service->finalizeDueCampaigns());
        $this->assertDatabaseHas('affiliate_tier_campaigns', [
            'id' => 'atc_milestone_started',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $tenantId,
            'event_key' => 'affiliate.tier_campaign.started',
            'subject_id' => 'atc_milestone_started',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => $tenantId,
            'event_key' => 'affiliate.tier_campaign.ending_soon',
            'subject_id' => 'atc_milestone_ending',
        ]);
        $this->assertDatabaseHas('customer_notification_recipients', [
            'tenant_id' => $tenantId,
            'customer_id' => $affiliate['customer_id'],
        ]);
        $this->assertSame(0, $service->finalizeDueCampaigns());
        $this->assertSame(2, DB::table('customer_notifications')->where('tenant_id', $tenantId)->count());

        $futureFinalize = $service->finalizeCampaign($tenantId, 'atc_milestone_ending');
        $this->assertSame('resource_conflict', $futureFinalize['error'] ?? null);
    }

    public function test_admin_can_configure_tiers_preview_campaigns_and_cancel_safely(): void
    {
        $this->seedDefaultRbac();
        $partnerId = 'par_aff_admin';
        $tenantId = 'ten_aff_admin';
        $this->insertActivePartnerTenant($partnerId, $tenantId);
        $admin = $this->createTenantSession(
            $tenantId,
            $partnerId,
            ['affiliate_program.manage', 'affiliate_tier.view', 'affiliate_tier.manage', 'affiliate_tier_campaign.view', 'affiliate_tier_campaign.manage'],
            'adm_aff_admin',
            'affiliate-tier-admin@example.test',
        );
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => $tenantId,
        ];

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/affiliate-tiers', $headers)
            ->assertOk()
            ->assertJsonCount(5, 'data')
            ->assertJsonPath('data.0.code', 'bronze');
        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliate-tiers/bronze', [
                'name' => 'Bronze',
                'commission_per_ticket' => ['amount' => 175, 'currency' => 'THB'],
                'minimum_payout' => ['amount' => 27500, 'currency' => 'THB'],
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-update-bronze'])
            ->assertOk()
            ->assertJsonPath('commission_per_ticket.amount', 175)
            ->assertJsonPath('minimum_payout.amount', 27500);
        $this->assertDatabaseHas('commission_rules', [
            'tenant_id' => $tenantId,
            'code' => 'bronze_per_ticket',
            'rule_type' => 'per_ticket',
            'amount' => 175,
            'status' => 'active',
        ]);
        $bronzeProgramId = (string) DB::table('affiliate_programs')
            ->where('tenant_id', $tenantId)
            ->where('code', 'bronze')
            ->value('id');
        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/affiliate-programs/'.$bronzeProgramId, [
                'minimum_payout' => ['amount' => 1, 'currency' => 'THB'],
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-generic-update-blocked'])
            ->assertConflict();
        $this->withToken($admin['access_token'])
            ->deleteJson(
                '/api/v1/admin/tenant/affiliate-programs/'.$bronzeProgramId,
                [],
                $headers + ['Idempotency-Key' => 'affiliate-tier-generic-archive-blocked'],
            )
            ->assertConflict();

        $startsAt = now()->addHour()->startOfSecond();
        $endsAt = now()->addHours(2)->startOfSecond();
        $payload = [
            'name' => 'Quarter tier review',
            'campaign_type' => 'fixed_threshold',
            'status' => 'scheduled',
            'starts_at' => $startsAt->toIso8601String(),
            'ends_at' => $endsAt->toIso8601String(),
            'rules' => [
                ['minimum_ticket_count' => 0, 'target_tier_code' => 'bronze'],
                ['minimum_ticket_count' => 200, 'target_tier_code' => 'silver'],
                ['minimum_ticket_count' => 500, 'target_tier_code' => 'diamond'],
            ],
        ];
        $campaign = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns', $payload, $headers + [
                'Idempotency-Key' => 'affiliate-tier-campaign-create',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'scheduled')
            ->json();
        $campaignId = (string) $campaign['id'];

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/affiliate-tier-campaigns/'.$campaignId, $headers)
            ->assertOk()
            ->assertJsonPath('id', $campaignId)
            ->assertJsonCount(3, 'rules')
            ->assertJsonStructure(['leaderboard']);
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns/'.$campaignId.'/finalize', [], $headers + [
                'Idempotency-Key' => 'affiliate-tier-campaign-too-early',
            ])
            ->assertConflict();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns', [
                ...$payload,
                'name' => 'Overlapping campaign',
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-campaign-overlap'])
            ->assertUnprocessable();
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns', [
                'name' => 'Invalid ranking ranges',
                'campaign_type' => 'ranking',
                'status' => 'draft',
                'starts_at' => $startsAt->copy()->addDay()->toIso8601String(),
                'ends_at' => $endsAt->copy()->addDay()->toIso8601String(),
                'rules' => [
                    ['rank_from' => 1, 'rank_to' => 10, 'target_tier_code' => 'diamond'],
                    ['rank_from' => 10, 'rank_to' => 20, 'target_tier_code' => 'platinum'],
                ],
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-campaign-bad-ranges'])
            ->assertUnprocessable();
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns', [
                'name' => 'Invalid fixed tier order',
                'campaign_type' => 'fixed_threshold',
                'status' => 'draft',
                'starts_at' => $startsAt->copy()->addDays(2)->toIso8601String(),
                'ends_at' => $endsAt->copy()->addDays(2)->toIso8601String(),
                'rules' => [
                    ['minimum_ticket_count' => 0, 'target_tier_code' => 'bronze'],
                    ['minimum_ticket_count' => 200, 'target_tier_code' => 'gold'],
                    ['minimum_ticket_count' => 300, 'target_tier_code' => 'silver'],
                ],
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-campaign-bad-fixed-order'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.rules.0',
                'Fixed-threshold target tiers must increase with ticket thresholds.',
            );
        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns', [
                'name' => 'Invalid ranking tier order',
                'campaign_type' => 'ranking',
                'status' => 'draft',
                'starts_at' => $startsAt->copy()->addDays(3)->toIso8601String(),
                'ends_at' => $endsAt->copy()->addDays(3)->toIso8601String(),
                'rules' => [
                    ['rank_from' => 1, 'rank_to' => 10, 'target_tier_code' => 'silver'],
                    ['rank_from' => 11, 'rank_to' => 20, 'target_tier_code' => 'diamond'],
                ],
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-campaign-bad-ranking-order'])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.rules.0',
                'Competition target tiers must not increase for lower leaderboard positions.',
            );

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/affiliate-tier-campaigns/'.$campaignId.'/cancel', [
                'reason' => 'Cancelled in test.',
            ], $headers + ['Idempotency-Key' => 'affiliate-tier-campaign-cancel'])
            ->assertOk()
            ->assertJsonPath('status', 'cancelled');
    }

    /** @return array{affiliate_id: string, customer_id: string, program_id: string} */
    private function insertAffiliate(string $tenantId, string $code, string $programId, string $suffix): array
    {
        $key = substr(sha1($tenantId.':'.$suffix), 0, 16);
        $customerId = 'cus_'.$key;
        $affiliateId = 'aff_'.$key;
        DB::table('customers')->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'customer_no' => strtoupper(substr(sha1($customerId), 0, 16)),
            'phone' => '08'.substr($key, 0, 8),
            'name' => 'Affiliate '.$suffix,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('affiliate_accounts')->insert([
            'id' => $affiliateId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'affiliate_program_id' => $programId,
            'code' => $code,
            'name' => 'Store '.$suffix,
            'store_name_status' => 'approved',
            'store_name_normalized' => 'store '.$suffix,
            'store_name_approved_at' => now(),
            'store_name_change_available_at' => now()->addMonthsNoOverflow(3),
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now()->subDay(),
            'updated_at' => now(),
        ]);

        return ['affiliate_id' => $affiliateId, 'customer_id' => $customerId, 'program_id' => $programId];
    }

    /** @param array{affiliate_id: string, customer_id: string, program_id: string} $affiliate */
    private function insertAttributedPaidSale(
        string $partnerId,
        string $tenantId,
        string $gameId,
        array $affiliate,
        int $ticketCount,
        Carbon $paidAt,
        string $suffix,
    ): string {
        $key = substr(sha1($tenantId.':'.$suffix), 0, 16);
        $buyerId = 'buy_'.$key;
        $reservationId = 'res_'.$key;
        $orderId = 'ord_'.$key;
        DB::table('customers')->insert([
            'id' => $buyerId,
            'tenant_id' => $tenantId,
            'customer_no' => strtoupper(substr(sha1($buyerId), 0, 16)),
            'phone' => '09'.substr($key, 0, 8),
            'name' => 'Buyer '.$suffix,
            'status' => 'active',
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);
        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $buyerId,
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => $paidAt->copy()->addMinutes(15),
            'converted_at' => $paidAt,
            'idempotency_key' => 'reserve-'.$key,
            'payload_hash' => hash('sha256', 'reserve-'.$key),
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);
        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => $tenantId,
            'customer_id' => $buyerId,
            'reservation_id' => $reservationId,
            'game_id' => $gameId,
            'wallet_id' => null,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => $ticketCount * 8000,
            'currency' => 'THB',
            'reference' => 'REF-'.$key,
            'idempotency_key' => 'order-'.$key,
            'payload_hash' => hash('sha256', 'order-'.$key),
            'paid_at' => $paidAt,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);
        DB::table('affiliate_attributions')->insert([
            'id' => 'aat_'.$key,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate['affiliate_id'],
            'affiliate_link_id' => null,
            'affiliate_program_id' => $affiliate['program_id'],
            'customer_id' => $buyerId,
            'order_id' => $orderId,
            'status' => 'converted',
            'attributed_at' => $paidAt->copy()->subMinute(),
            'converted_at' => $paidAt,
            'metadata_json' => null,
            'created_at' => $paidAt,
            'updated_at' => $paidAt,
        ]);

        $stocks = [];
        $localStocks = [];
        $tickets = [];
        for ($index = 0; $index < $ticketCount; $index++) {
            $itemKey = substr(sha1($orderId.':'.$index), 0, 20);
            $stockId = 'stk_'.$itemKey;
            $localStockId = 'lsi_'.$itemKey;
            $number = str_pad((string) ($index % 1000000), 6, '0', STR_PAD_LEFT);
            $stocks[] = [
                'id' => $stockId,
                'game_id' => $gameId,
                'full_number' => $number,
                'status' => 'sold',
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'created_at' => $paidAt,
                'updated_at' => $paidAt,
            ];
            $localStocks[] = [
                'id' => $localStockId,
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
                'game_id' => $gameId,
                'stock_item_id' => $stockId,
                'full_number' => $number,
                'status' => 'sold',
                'synced_at' => $paidAt,
                'reserved_at' => $paidAt,
                'sold_at' => $paidAt,
                'created_at' => $paidAt,
                'updated_at' => $paidAt,
            ];
            $tickets[] = [
                'id' => 'tic_'.$itemKey,
                'tenant_id' => $tenantId,
                'customer_id' => $buyerId,
                'order_id' => $orderId,
                'local_stock_item_id' => $localStockId,
                'game_id' => $gameId,
                'full_number' => $number,
                'status' => 'active',
                'created_at' => $paidAt,
                'updated_at' => $paidAt,
            ];
        }
        foreach (array_chunk($stocks, 400) as $rows) {
            DB::table('stock_items')->insert($rows);
        }
        foreach (array_chunk($localStocks, 400) as $rows) {
            DB::table('local_stock_items')->insert($rows);
        }
        foreach (array_chunk($tickets, 400) as $rows) {
            DB::table('tickets')->insert($rows);
        }

        return $orderId;
    }

    /**
     * @param array<int, array<int, int|string>> $rules
     * @param array<string, mixed> $tiers
     */
    private function insertCampaign(string $tenantId, string $type, array $rules, array $tiers, string $suffix): string
    {
        $campaignId = 'atc_'.substr(sha1($tenantId.':'.$suffix), 0, 20);
        DB::table('affiliate_tier_campaigns')->insert([
            'id' => $campaignId,
            'tenant_id' => $tenantId,
            'name' => ucfirst($suffix).' campaign',
            'campaign_type' => $type,
            'status' => 'active',
            'starts_at' => now()->subHours(2),
            'ends_at' => now()->subMinute(),
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        foreach ($rules as $index => $rule) {
            $tierCode = (string) end($rule);
            DB::table('affiliate_tier_campaign_rules')->insert([
                'id' => 'acr_'.substr(sha1($campaignId.':'.$index), 0, 20),
                'tenant_id' => $tenantId,
                'campaign_id' => $campaignId,
                'target_program_id' => $tiers[$tierCode]->id,
                'rule_order' => $index,
                'minimum_ticket_count' => $type === 'fixed_threshold' ? $rule[0] : null,
                'rank_from' => $type === 'ranking' ? $rule[0] : null,
                'rank_to' => $type === 'ranking' ? $rule[1] : null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        return $campaignId;
    }

    private function assertCampaignResult(string $campaignId, string $affiliateId, int $rank, string $tierCode): void
    {
        $row = DB::table('affiliate_tier_campaign_results')
            ->join('affiliate_programs', 'affiliate_programs.id', '=', 'affiliate_tier_campaign_results.applied_program_id')
            ->where('affiliate_tier_campaign_results.campaign_id', $campaignId)
            ->where('affiliate_tier_campaign_results.affiliate_account_id', $affiliateId)
            ->select(['affiliate_tier_campaign_results.rank', 'affiliate_programs.code'])
            ->first();
        $this->assertNotNull($row);
        $this->assertSame($rank, (int) $row->rank);
        $this->assertSame($tierCode, (string) $row->code);
    }
}
