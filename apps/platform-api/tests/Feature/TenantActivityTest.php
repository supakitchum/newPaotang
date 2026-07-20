<?php

namespace Tests\Feature;

use App\Jobs\FanoutCustomerNotificationRecipientsJob;
use App\Modules\Activities\Services\TenantActivityService;
use App\Modules\Activities\Events\ActivityClaimUpdated;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class TenantActivityTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_activity_claim_updated_event_broadcasts_to_current_customer_channel(): void
    {
        $event = new ActivityClaimUpdated([
            'tenant_id' => 'ten_activity_rt',
            'customer_id' => 'cus_activity_rt',
            'claim_id' => 'acl_activity_rt',
        ]);

        $this->assertSame([
            'private-customer.tenant.ten_activity_rt.customer.cus_activity_rt.activity-claims',
        ], array_map(fn (object $channel): string => (string) $channel->name, $event->broadcastOn()));
    }

    public function test_customer_activity_entry_requires_and_replays_idempotency_key(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_act_entry_api', 'ten_act_entry_api', 'act-entry-api.test');
        $this->insertGame('gam_act_entry_api', 'open');
        $token = $this->issueCustomerToken('ten_act_entry_api', 'cus_act_entry_api');
        $this->insertLuckyActivity('ten_act_entry_api', 'gam_act_entry_api', 'act_entry_api', thresholdTickets: 1);
        $this->insertPaidOrderWithTickets('par_act_entry_api', 'ten_act_entry_api', 'gam_act_entry_api', 'cus_act_entry_api', 'ord_act_entry_api', ['123456'], 8000);
        $url = 'http://act-entry-api.test/api/v1/customer/activities/act_entry_api/entries';
        $payload = [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ];

        $this->withToken($token)
            ->postJson($url, $payload)
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $entry = $this->withToken($token)
            ->postJson($url, $payload, ['Idempotency-Key' => 'activity-entry-api'])
            ->assertCreated()
            ->json();

        $replay = $this->withToken($token)
            ->postJson($url, $payload, ['Idempotency-Key' => 'activity-entry-api'])
            ->assertCreated()
            ->json();

        $this->assertSame($entry['id'], $replay['id']);
        $this->assertSame(1, DB::table('tenant_activity_entries')->where('customer_id', 'cus_act_entry_api')->count());

        $this->withToken($token)
            ->postJson($url, [
                'prediction_type' => 'first_prize_last2',
                'selected_number' => '57',
            ], ['Idempotency-Key' => 'activity-entry-api'])
            ->assertConflict()
            ->assertJsonPath('error.code', 'idempotency_conflict');
    }

    public function test_lucky_board_rights_use_paid_ticket_counts_and_block_overuse(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_rights', 'ten_act_rights', 'act-rights.test');
        $this->insertGame('gam_act_rights', 'open');
        $this->issueCustomerToken('ten_act_rights', 'cus_act_rights');
        $this->insertLuckyActivity('ten_act_rights', 'gam_act_rights', 'act_lucky_rights', thresholdTickets: 2);
        $this->insertPaidOrderWithTickets('par_act_rights', 'ten_act_rights', 'gam_act_rights', 'cus_act_rights', 'ord_rights', ['123455', '123456'], 16000);

        $context = $this->customerContext('ten_act_rights', 'cus_act_rights');
        $rights = $service->customerRights('ten_act_rights', $context, 'act_lucky_rights');

        $this->assertSame(1, $rights['earned_count']);
        $this->assertSame(0, $rights['used_count']);
        $this->assertSame(1, $rights['remaining_count']);
        $this->assertSame(2, $rights['ticket_count']);

        $entry = $service->createCustomerEntry('ten_act_rights', $context, 'act_lucky_rights', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->assertSame(201, $entry['status'] ?? null);

        $second = $service->createCustomerEntry('ten_act_rights', $context, 'act_lucky_rights', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '99',
        ]);
        $this->assertSame('resource_conflict', $second['error'] ?? null);
    }

    public function test_lucky_board_cumulative_rights_are_ticket_blocks_consumed_across_activities(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_blocks', 'ten_act_blocks', 'act-blocks.test');
        $this->insertGame('gam_act_blocks', 'open');
        $this->issueCustomerToken('ten_act_blocks', 'cus_act_blocks');
        $this->insertLuckyActivity('ten_act_blocks', 'gam_act_blocks', 'act_lucky_15', thresholdTickets: 15);
        $this->insertLuckyActivity('ten_act_blocks', 'gam_act_blocks', 'act_lucky_20', thresholdTickets: 20);
        $this->insertPaidOrderWithTickets(
            'par_act_blocks',
            'ten_act_blocks',
            'gam_act_blocks',
            'cus_act_blocks',
            'ord_blocks_30',
            array_map(fn (int $index): string => (string) (123400 + $index), range(1, 30)),
            240000,
        );

        $context = $this->customerContext('ten_act_blocks', 'cus_act_blocks');
        $first = $service->customerRights('ten_act_blocks', $context, 'act_lucky_15');
        $second = $service->customerRights('ten_act_blocks', $context, 'act_lucky_20');

        $this->assertSame(2, $first['earned_count']);
        $this->assertSame(2, $first['remaining_count']);
        $this->assertSame(1, $second['earned_count']);
        $this->assertSame(1, $second['remaining_count']);

        $entry = $service->createCustomerEntry('ten_act_blocks', $context, 'act_lucky_20', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '20',
        ]);
        $this->assertSame(201, $entry['status'] ?? null);

        $blocked = $service->customerRights('ten_act_blocks', $context, 'act_lucky_15');
        $this->assertSame(0, $blocked['earned_count']);
        $this->assertSame(0, $blocked['remaining_count']);
        $this->assertSame(10, $blocked['available_ticket_count']);

        $conflict = $service->createCustomerEntry('ten_act_blocks', $context, 'act_lucky_15', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '15',
        ]);
        $this->assertSame('resource_conflict', $conflict['error'] ?? null);

        $this->insertPaidOrderWithTickets(
            'par_act_blocks',
            'ten_act_blocks',
            'gam_act_blocks',
            'cus_act_blocks',
            'ord_blocks_5',
            array_map(fn (int $index): string => (string) (223400 + $index), range(1, 5)),
            40000,
        );

        $afterTopup = $service->customerRights('ten_act_blocks', $context, 'act_lucky_15');
        $this->assertSame(1, $afterTopup['earned_count']);
        $this->assertSame(1, $afterTopup['remaining_count']);
        $this->assertSame(15, $afterTopup['available_ticket_count']);
    }

    public function test_lucky_board_numbers_are_reserved_globally_and_exposed_for_customer_board(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_reserved', 'ten_act_reserved', 'act-reserved.test');
        $this->insertGame('gam_act_reserved', 'open');
        $this->issueCustomerToken('ten_act_reserved', 'cus_act_reserved_one');
        $this->issueCustomerToken('ten_act_reserved', 'cus_act_reserved_two');
        $this->insertLuckyActivity('ten_act_reserved', 'gam_act_reserved', 'act_lucky_reserved', thresholdTickets: 1);
        $this->insertPaidOrderWithTickets('par_act_reserved', 'ten_act_reserved', 'gam_act_reserved', 'cus_act_reserved_one', 'ord_reserved_one', ['423456'], 8000);
        $this->insertPaidOrderWithTickets('par_act_reserved', 'ten_act_reserved', 'gam_act_reserved', 'cus_act_reserved_two', 'ord_reserved_two', ['523456'], 8000);

        $first = $service->createCustomerEntry('ten_act_reserved', $this->customerContext('ten_act_reserved', 'cus_act_reserved_one'), 'act_lucky_reserved', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->assertSame(201, $first['status'] ?? null);

        $duplicate = $service->createCustomerEntry('ten_act_reserved', $this->customerContext('ten_act_reserved', 'cus_act_reserved_two'), 'act_lucky_reserved', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->assertSame('resource_conflict', $duplicate['error'] ?? null);

        $detail = $service->publicFindBySlug('ten_act_reserved', 'act-lucky-reserved');
        $this->assertSame(100, $detail['number_board']['total_count'] ?? null);
        $this->assertSame(1, $detail['number_board']['reserved_count'] ?? null);
        $this->assertSame(99, $detail['number_board']['remaining_count'] ?? null);
        $this->assertContains('56', $detail['number_board']['reserved_numbers'] ?? []);

        $list = $service->publicList('ten_act_reserved');
        $this->assertSame(99, $list['data'][0]['number_board']['remaining_count'] ?? null);
        $this->assertArrayNotHasKey('reserved_numbers', $list['data'][0]['number_board']);
    }

    public function test_lucky_board_entry_closes_thirty_minutes_after_sale_close(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_deadline', 'ten_act_deadline', 'act-deadline.test');
        $this->insertGame('gam_act_deadline', 'open');
        DB::table('games')->where('id', 'gam_act_deadline')->update([
            'close_at' => now()->subMinutes(31),
            'updated_at' => now(),
        ]);
        $this->issueCustomerToken('ten_act_deadline', 'cus_act_deadline');
        $this->insertLuckyActivity('ten_act_deadline', 'gam_act_deadline', 'act_lucky_deadline', thresholdTickets: 1);
        $this->insertPaidOrderWithTickets('par_act_deadline', 'ten_act_deadline', 'gam_act_deadline', 'cus_act_deadline', 'ord_deadline', ['123456'], 8000);

        $detail = $service->publicFindBySlug('ten_act_deadline', 'act-lucky-deadline');
        $this->assertTrue($detail['entry_closed'] ?? false);
        $this->assertSame(30, $detail['entry_close_after_minutes'] ?? null);

        $blocked = $service->createCustomerEntry('ten_act_deadline', $this->customerContext('ten_act_deadline', 'cus_act_deadline'), 'act_lucky_deadline', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->assertSame('activity_entry_closed', $blocked['error'] ?? null);

        DB::table('games')->where('id', 'gam_act_deadline')->update([
            'close_at' => now()->subMinutes(29),
            'updated_at' => now(),
        ]);

        $allowed = $service->createCustomerEntry('ten_act_deadline', $this->customerContext('ten_act_deadline', 'cus_act_deadline'), 'act_lucky_deadline', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->assertSame(201, $allowed['status'] ?? null);
    }

    public function test_public_and_customer_activity_lists_default_to_current_draw_and_history_requires_history_mode(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_draws', 'ten_act_draws', 'act-draws.test');
        $this->insertGame('gam_act_draw_current', 'open');
        $this->insertGame('gam_act_draw_history', 'reward_published');
        DB::table('games')->where('id', 'gam_act_draw_current')->update([
            'name' => 'งวดวันที่ 16 มิ.ย. 2569',
            'draw_at' => now()->addDay(),
            'updated_at' => now(),
        ]);
        DB::table('games')->where('id', 'gam_act_draw_history')->update([
            'name' => 'งวดวันที่ 1 มิ.ย. 2569',
            'draw_at' => now()->subDays(15),
            'updated_at' => now(),
        ]);
        $this->insertLuckyActivity('ten_act_draws', 'gam_act_draw_current', 'act_draw_current', thresholdTickets: 1);
        $this->insertLuckyActivity('ten_act_draws', 'gam_act_draw_history', 'act_draw_history', thresholdTickets: 1);
        $this->issueCustomerToken('ten_act_draws', 'cus_act_draws');

        $current = $service->publicList('ten_act_draws', ['limit' => 10]);
        $this->assertSame(['gam_act_draw_current'], array_values(array_unique(array_column($current['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_current', $current['meta']['current_game_id']);
        $this->assertSame('gam_act_draw_current', $current['meta']['selected_game_id']);
        $this->assertTrue($current['meta']['has_history']);
        $this->assertCount(2, $current['meta']['games']);

        $adminDefault = $service->list('ten_act_draws', ['limit' => 10]);
        $this->assertSame(['gam_act_draw_current'], array_values(array_unique(array_column($adminDefault['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_current', $adminDefault['meta']['selected_game_id']);

        $adminHistory = $service->list('ten_act_draws', ['limit' => 10, 'game_id' => 'gam_act_draw_history']);
        $this->assertSame(['gam_act_draw_history'], array_values(array_unique(array_column($adminHistory['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_history', $adminHistory['meta']['selected_game_id']);

        $ignoredHistory = $service->publicList('ten_act_draws', ['limit' => 10, 'game_id' => 'gam_act_draw_history']);
        $this->assertSame(['gam_act_draw_current'], array_values(array_unique(array_column($ignoredHistory['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_current', $ignoredHistory['meta']['selected_game_id']);

        $history = $service->publicList('ten_act_draws', ['limit' => 10, 'history' => 1, 'game_id' => 'gam_act_draw_history']);
        $this->assertSame(['gam_act_draw_history'], array_values(array_unique(array_column($history['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_history', $history['meta']['selected_game_id']);
        $this->assertSame('history', $history['meta']['mode']);
        $this->assertCount(1, $history['meta']['games']);

        $customer = $service->customerActivities('ten_act_draws', $this->customerContext('ten_act_draws', 'cus_act_draws'), [
            'limit' => 10,
            'history' => 1,
            'game_id' => 'gam_act_draw_history',
        ]);
        $this->assertSame(['gam_act_draw_history'], array_values(array_unique(array_column($customer['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_history', $customer['meta']['selected_game_id']);

        $customerCurrent = $service->customerActivities('ten_act_draws', $this->customerContext('ten_act_draws', 'cus_act_draws'), [
            'limit' => 10,
            'game_id' => 'gam_act_draw_history',
        ]);
        $this->assertSame(['gam_act_draw_current'], array_values(array_unique(array_column($customerCurrent['data'], 'game_id'))));
        $this->assertSame('gam_act_draw_current', $customerCurrent['meta']['selected_game_id']);
    }

    public function test_public_and_customer_activity_lists_support_cursor_pagination(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_pages', 'ten_act_pages', 'act-pages.test');
        $this->insertGame('gam_act_pages', 'open');
        $this->insertCashbackActivity('ten_act_pages', 'gam_act_pages', 'act_page_3', 'fixed', 0, 1000, 1, 10000, 3);
        $this->insertCashbackActivity('ten_act_pages', 'gam_act_pages', 'act_page_2', 'fixed', 0, 1000, 1, 10000, 2);
        $this->insertCashbackActivity('ten_act_pages', 'gam_act_pages', 'act_page_1', 'fixed', 0, 1000, 1, 10000, 1);
        $this->issueCustomerToken('ten_act_pages', 'cus_act_pages');

        $firstPage = $service->publicList('ten_act_pages', ['limit' => 2]);

        $this->assertSame(['act_page_3', 'act_page_2'], array_column($firstPage['data'], 'id'));
        $this->assertTrue($firstPage['meta']['has_more']);
        $this->assertNotEmpty($firstPage['meta']['next_cursor']);

        $secondPage = $service->publicList('ten_act_pages', [
            'limit' => 2,
            'cursor' => $firstPage['meta']['next_cursor'],
        ]);

        $this->assertSame(['act_page_1'], array_column($secondPage['data'], 'id'));
        $this->assertFalse($secondPage['meta']['has_more']);
        $this->assertNull($secondPage['meta']['next_cursor']);

        $customerPage = $service->customerActivities('ten_act_pages', $this->customerContext('ten_act_pages', 'cus_act_pages'), [
            'limit' => 2,
            'cursor' => $firstPage['meta']['next_cursor'],
        ]);

        $this->assertSame(['act_page_1'], array_column($customerPage['data'], 'id'));
        $this->assertFalse($customerPage['meta']['has_more']);
    }

    public function test_customer_activity_awards_and_claims_support_cursor_pagination(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_claim_pages', 'ten_act_claim_pages', 'act-claim-pages.test');
        $this->insertGame('gam_act_claim_pages', 'open');
        $this->issueCustomerToken('ten_act_claim_pages', 'cus_act_claim_pages');
        $this->insertCashbackActivity('ten_act_claim_pages', 'gam_act_claim_pages', 'act_claim_pages', 'fixed', 0, 1000, 1, 10000, 1);
        $createdAt = now();

        foreach ([1, 2, 3] as $index) {
            $awardId = 'awa_claim_page_'.$index;
            $this->insertActivityAward('ten_act_claim_pages', 'gam_act_claim_pages', 'act_claim_pages', 'cus_act_claim_pages', $awardId, $createdAt);
            $this->insertActivityClaim('ten_act_claim_pages', 'gam_act_claim_pages', 'act_claim_pages', 'cus_act_claim_pages', $awardId, 'acl_claim_page_'.$index, $createdAt);
        }

        $customer = $this->customerContext('ten_act_claim_pages', 'cus_act_claim_pages');
        $firstAwards = $service->customerAwards('ten_act_claim_pages', $customer, ['limit' => 2]);

        $this->assertSame(['awa_claim_page_3', 'awa_claim_page_2'], array_column($firstAwards['data'], 'id'));
        $this->assertTrue($firstAwards['meta']['has_more']);
        $this->assertSame('awa_claim_page_2', $firstAwards['meta']['next_cursor']);

        $secondAwards = $service->customerAwards('ten_act_claim_pages', $customer, [
            'limit' => 2,
            'cursor' => $firstAwards['meta']['next_cursor'],
        ]);

        $this->assertSame(['awa_claim_page_1'], array_column($secondAwards['data'], 'id'));
        $this->assertFalse($secondAwards['meta']['has_more']);
        $this->assertNull($secondAwards['meta']['next_cursor']);

        $firstClaims = $service->customerClaims('ten_act_claim_pages', $customer, ['limit' => 2]);

        $this->assertSame(['acl_claim_page_3', 'acl_claim_page_2'], array_column($firstClaims['data'], 'id'));
        $this->assertTrue($firstClaims['meta']['has_more']);
        $this->assertSame('acl_claim_page_2', $firstClaims['meta']['next_cursor']);

        $secondClaims = $service->customerClaims('ten_act_claim_pages', $customer, [
            'limit' => 2,
            'cursor' => $firstClaims['meta']['next_cursor'],
        ]);

        $this->assertSame(['acl_claim_page_1'], array_column($secondClaims['data'], 'id'));
        $this->assertFalse($secondClaims['meta']['has_more']);
        $this->assertNull($secondClaims['meta']['next_cursor']);
    }

    public function test_lucky_board_customer_detail_exposes_announced_result_and_customer_status(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_result', 'ten_act_result', 'act-result.test');
        $this->insertGame('gam_act_result', 'open');
        $this->markActivityResultReady('gam_act_result');
        $this->issueCustomerToken('ten_act_result', 'cus_act_result_winner');
        $this->issueCustomerToken('ten_act_result', 'cus_act_result_loser');
        $this->insertLuckyActivity('ten_act_result', 'gam_act_result', 'act_lucky_result', thresholdTickets: 1);
        $this->insertPaidOrderWithTickets('par_act_result', 'ten_act_result', 'gam_act_result', 'cus_act_result_winner', 'ord_result_winner', ['123456'], 8000);
        $this->insertPaidOrderWithTickets('par_act_result', 'ten_act_result', 'gam_act_result', 'cus_act_result_loser', 'ord_result_loser', ['223457'], 8000);

        $winner = $this->customerContext('ten_act_result', 'cus_act_result_winner');
        $loser = $this->customerContext('ten_act_result', 'cus_act_result_loser');
        $this->assertSame(201, $service->createCustomerEntry('ten_act_result', $winner, 'act_lucky_result', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ])['status'] ?? null);
        $this->assertSame(201, $service->createCustomerEntry('ten_act_result', $loser, 'act_lucky_result', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '57',
        ])['status'] ?? null);
        $this->insertPublishedRewardResult('gam_act_result', 'rwr_act_result', '123456', '99');
        $this->assertSame(['lucky_awards' => 1, 'cashback_awards' => 0], $service->processGame('gam_act_result', 'lucky'));

        $winnerDetail = $service->customerActivity('ten_act_result', $winner, 'act_lucky_result');
        $loserDetail = $service->customerActivity('ten_act_result', $loser, 'act_lucky_result');

        $this->assertSame('announced', $winnerDetail['result_summary']['status'] ?? null);
        $this->assertSame('56', $winnerDetail['result_summary']['winning_number'] ?? null);
        $this->assertSame(['56'], $winnerDetail['result_summary']['winning_numbers'] ?? null);
        $this->assertSame('won', $winnerDetail['result_summary']['customer']['status'] ?? null);
        $this->assertSame(['56'], $winnerDetail['result_summary']['customer']['winning_numbers'] ?? null);
        $this->assertSame(10000, $winnerDetail['result_summary']['customer']['award_amount']['amount'] ?? null);
        $this->assertSame('lost', $loserDetail['result_summary']['customer']['status'] ?? null);
        $this->assertSame([], $loserDetail['result_summary']['customer']['winning_numbers'] ?? null);
    }

    public function test_lucky_board_single_order_rights_consume_ticket_blocks_from_the_same_order(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_order_blocks', 'ten_act_order_blocks', 'act-order-blocks.test');
        $this->insertGame('gam_act_order_blocks', 'open');
        $this->issueCustomerToken('ten_act_order_blocks', 'cus_act_order_blocks');
        $this->insertLuckyActivity('ten_act_order_blocks', 'gam_act_order_blocks', 'act_order_5', thresholdTickets: 5, eligibilityRule: 'single_order_exact_tickets');
        $this->insertLuckyActivity('ten_act_order_blocks', 'gam_act_order_blocks', 'act_order_10', thresholdTickets: 10, eligibilityRule: 'single_order_exact_tickets');
        $this->insertPaidOrderWithTickets(
            'par_act_order_blocks',
            'ten_act_order_blocks',
            'gam_act_order_blocks',
            'cus_act_order_blocks',
            'ord_single_15',
            array_map(fn (int $index): string => (string) (323400 + $index), range(1, 15)),
            120000,
        );

        $context = $this->customerContext('ten_act_order_blocks', 'cus_act_order_blocks');
        $five = $service->customerRights('ten_act_order_blocks', $context, 'act_order_5');
        $ten = $service->customerRights('ten_act_order_blocks', $context, 'act_order_10');

        $this->assertSame(3, $five['earned_count']);
        $this->assertSame(3, $five['remaining_count']);
        $this->assertSame(1, $ten['earned_count']);
        $this->assertSame(1, $ten['remaining_count']);

        $firstEntry = $service->createCustomerEntry('ten_act_order_blocks', $context, 'act_order_5', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '05',
        ]);
        $this->assertSame(201, $firstEntry['status'] ?? null);

        $tenAfterFive = $service->customerRights('ten_act_order_blocks', $context, 'act_order_10');
        $this->assertSame(1, $tenAfterFive['remaining_count']);
        $this->assertSame(10, $tenAfterFive['available_ticket_count']);

        $secondEntry = $service->createCustomerEntry('ten_act_order_blocks', $context, 'act_order_10', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '10',
        ]);
        $this->assertSame(201, $secondEntry['status'] ?? null);

        $fiveAfterTen = $service->customerRights('ten_act_order_blocks', $context, 'act_order_5');
        $this->assertSame(1, $fiveAfterTen['used_count']);
        $this->assertSame(0, $fiveAfterTen['remaining_count']);
        $this->assertSame(0, $fiveAfterTen['available_ticket_count']);
    }

    public function test_lucky_award_can_be_claimed_and_partner_approval_credits_wallet(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_claim', 'ten_act_claim', 'act-claim.test');
        $this->insertGame('gam_act_claim', 'open');
        $this->markActivityResultReady('gam_act_claim');
        $this->issueCustomerToken('ten_act_claim', 'cus_act_claim');
        $this->insertLuckyActivity('ten_act_claim', 'gam_act_claim', 'act_lucky_claim', thresholdTickets: 1, firstPrizeLast2Amount: 50000);
        $this->insertPaidOrderWithTickets('par_act_claim', 'ten_act_claim', 'gam_act_claim', 'cus_act_claim', 'ord_claim', ['123456'], 8000);

        $customer = $this->customerContext('ten_act_claim', 'cus_act_claim');
        $service->createCustomerEntry('ten_act_claim', $customer, 'act_lucky_claim', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->insertPublishedRewardResult('gam_act_claim', 'rwr_act_claim', '123456', '99');

        $this->assertSame(['lucky_awards' => 1, 'cashback_awards' => 0], $service->processGame('gam_act_claim', 'lucky'));
        $this->assertSame(['lucky_awards' => 0, 'cashback_awards' => 0], $service->processGame('gam_act_claim', 'lucky'));

        $awardId = (string) DB::table('tenant_activity_awards')->where('activity_id', 'act_lucky_claim')->value('id');
        $claim = $service->createCustomerClaim('ten_act_claim', $customer, [
            'award_id' => $awardId,
            'payout_method' => 'wallet_credit',
            'pin' => '246810',
        ], $this->idempotentRequest('act-claim-wallet'));

        $this->assertSame(201, $claim['status'] ?? null);
        $replay = $service->createCustomerClaim('ten_act_claim', $customer, [
            'award_id' => $awardId,
            'payout_method' => 'wallet_credit',
            'pin' => '246810',
        ], $this->idempotentRequest('act-claim-wallet'));
        $this->assertSame(201, $replay['status'] ?? null);
        $this->assertSame($claim['resource']['id'], $replay['resource']['id'] ?? null);
        $this->assertSame(1, DB::table('activity_claims')->where('activity_award_id', $awardId)->count());

        $this->createAdmin('adm_act_claim', 'act-claim-admin@example.test');
        $approved = $service->approveTenantClaim('ten_act_claim', $this->adminContext('ten_act_claim', 'par_act_claim', 'adm_act_claim'), $claim['resource']['id'], [
            'reason' => 'approved from activity test',
        ]);

        $this->assertSame('paid', $approved['resource']['status'] ?? null);
        $this->assertDatabaseHas('wallet_ledger', [
            'tenant_id' => 'ten_act_claim',
            'customer_id' => 'cus_act_claim',
            'reference_type' => 'activity_claim',
            'reference_id' => $claim['resource']['id'],
            'amount' => 50000,
            'balance_after' => 50000,
        ]);
    }

    public function test_activity_award_auto_creates_claim_when_customer_enabled_auto_reward(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_auto', 'ten_act_auto', 'act-auto.test');
        $this->insertGame('gam_act_auto', 'open');
        $this->markActivityResultReady('gam_act_auto');
        $this->issueCustomerToken('ten_act_auto', 'cus_act_auto');
        DB::table('customers')->where('id', 'cus_act_auto')->update([
            'auto_reward_claim_enabled' => true,
            'auto_reward_claim_payout_method' => 'wallet_credit',
            'updated_at' => now(),
        ]);
        $this->insertLuckyActivity('ten_act_auto', 'gam_act_auto', 'act_lucky_auto', thresholdTickets: 1, firstPrizeLast2Amount: 75000);
        $this->insertPaidOrderWithTickets('par_act_auto', 'ten_act_auto', 'gam_act_auto', 'cus_act_auto', 'ord_auto', ['223456'], 8000);

        $customer = $this->customerContext('ten_act_auto', 'cus_act_auto');
        $service->createCustomerEntry('ten_act_auto', $customer, 'act_lucky_auto', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->insertPublishedRewardResult('gam_act_auto', 'rwr_act_auto', '123456', '99');

        $this->assertSame(['lucky_awards' => 1, 'cashback_awards' => 0], $service->processGame('gam_act_auto', 'lucky'));
        $this->assertSame(['lucky_awards' => 0, 'cashback_awards' => 0], $service->processGame('gam_act_auto', 'lucky'));

        $award = DB::table('tenant_activity_awards')->where('activity_id', 'act_lucky_auto')->first();
        $this->assertNotNull($award);
        $this->assertSame('claimed', (string) $award->status);

        $claims = DB::table('activity_claims')->where('activity_award_id', $award->id)->get();
        $this->assertCount(1, $claims);
        $claim = $claims->first();
        $this->assertSame('submitted', (string) $claim->status);
        $this->assertSame('wallet_credit', (string) $claim->payout_method);
        $this->assertSame(75000, (int) $claim->claim_amount);
        $this->assertNotNull($claim->wallet_id);
    }

    public function test_activity_config_uses_one_lucky_prediction_and_one_cashback_minimum(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_config', 'ten_act_config', 'act-config.test');
        $this->insertGame('gam_act_config', 'open');
        $this->createAdmin('adm_act_config', 'act-config-admin@example.test');
        $actor = $this->adminContext('ten_act_config', 'par_act_config', 'adm_act_config');

        $lucky = $service->create('ten_act_config', [
            'name' => 'Lucky selector',
            'slug' => 'lucky-selector',
            'game_id' => 'gam_act_config',
            'type' => 'lucky_board',
            'status' => 'active',
            'config' => [
                'prediction_type' => 'last2',
                'first_prize_last2_enabled' => true,
                'first_prize_last3_enabled' => true,
                'last2_enabled' => true,
                'eligibility_rule' => 'cumulative_tickets',
                'threshold_tickets' => 1,
                'first_prize_last2_amount' => 10000,
                'first_prize_last3_amount' => 20000,
                'last2_amount' => 30000,
            ],
        ], $actor, Request::create('/api/v1/admin/tenant/activities', 'POST'));

        $this->assertArrayHasKey('resource', $lucky);
        $this->assertMatchesRegularExpression('/^par-act-config-[a-z0-9]{5}$/', $lucky['resource']['slug']);
        $this->assertNotSame('lucky-selector', $lucky['resource']['slug']);
        $this->assertDatabaseHas('tenant_activity_lucky_configs', [
            'activity_id' => $lucky['resource']['id'],
            'first_prize_last2_enabled' => false,
            'first_prize_last3_enabled' => false,
            'last2_enabled' => true,
        ]);

        $cashback = $service->create('ten_act_config', [
            'name' => 'Amount minimum cashback',
            'slug' => 'amount-minimum-cashback',
            'game_id' => 'gam_act_config',
            'type' => 'cashback',
            'status' => 'active',
            'config' => [
                'cashback_type' => 'percent',
                'cashback_percent_bps' => 500,
                'fixed_amount' => 0,
                'minimum_type' => 'amount',
                'min_ticket_count' => 99,
                'min_purchase_amount' => 120000,
            ],
        ], $actor, Request::create('/api/v1/admin/tenant/activities', 'POST'));

        $this->assertArrayHasKey('resource', $cashback);
        $this->assertMatchesRegularExpression('/^par-act-config-[a-z0-9]{5}$/', $cashback['resource']['slug']);
        $this->assertNotSame('amount-minimum-cashback', $cashback['resource']['slug']);
        $this->assertDatabaseHas('tenant_activity_cashback_configs', [
            'activity_id' => $cashback['resource']['id'],
            'min_ticket_count' => 0,
            'min_purchase_amount' => 120000,
        ]);
    }

    public function test_activity_customer_notification_requires_explicit_publish_transition_opt_in(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_notify', 'ten_act_notify', 'act-notify.test');
        $this->insertGame('gam_act_notify', 'open');
        $this->createAdmin('adm_act_notify', 'act-notify-admin@example.test');
        $actor = $this->adminContext('ten_act_notify', 'par_act_notify', 'adm_act_notify');
        Queue::fake();

        $basePayload = [
            'game_id' => 'gam_act_notify',
            'type' => 'lucky_board',
            'config' => [
                'prediction_type' => 'last2',
                'eligibility_rule' => 'cumulative_tickets',
                'threshold_tickets' => 1,
                'last2_amount' => 10000,
            ],
        ];
        $withoutNotification = $service->create('ten_act_notify', [
            ...$basePayload,
            'name' => 'Active without notification',
            'status' => 'active',
            'notify_customers' => false,
        ], $actor, Request::create('/api/v1/admin/tenant/activities', 'POST'));
        $this->assertArrayHasKey('resource', $withoutNotification);

        $draft = $service->create('ten_act_notify', [
            ...$basePayload,
            'name' => 'Draft notification activity',
            'status' => 'draft',
            'notify_customers' => true,
        ], $actor, Request::create('/api/v1/admin/tenant/activities', 'POST'));
        $this->assertArrayHasKey('resource', $draft);
        $this->assertDatabaseCount('customer_notifications', 0);
        Queue::assertNotPushed(FanoutCustomerNotificationRecipientsJob::class);

        $published = $service->update(
            'ten_act_notify',
            (string) $draft['resource']['id'],
            ['status' => 'active', 'notify_customers' => true],
            $actor,
            Request::create('/api/v1/admin/tenant/activities/'.$draft['resource']['id'], 'PATCH'),
        );
        $this->assertArrayHasKey('resource', $published);
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => 'ten_act_notify',
            'event_key' => 'content.activity.published',
            'action_key' => 'activity',
            'action_entity_id' => $published['resource']['slug'],
            'subject_type' => 'tenant_activity',
            'subject_id' => $draft['resource']['id'],
        ]);
        Queue::assertPushed(FanoutCustomerNotificationRecipientsJob::class, 1);

        $service->update(
            'ten_act_notify',
            (string) $draft['resource']['id'],
            ['name' => 'Edited active activity', 'notify_customers' => true],
            $actor,
            Request::create('/api/v1/admin/tenant/activities/'.$draft['resource']['id'], 'PATCH'),
        );
        $this->assertDatabaseCount('customer_notifications', 1);
        Queue::assertPushed(FanoutCustomerNotificationRecipientsJob::class, 1);
    }

    public function test_cashback_uses_order_totals_once_and_keeps_only_highest_activity(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_cashback', 'ten_act_cashback', 'act-cashback.test');
        $this->insertGame('gam_act_cashback', 'closed');
        $this->markActivityResultReady('gam_act_cashback');
        $this->issueCustomerToken('ten_act_cashback', 'cus_act_cashback');
        $this->insertCashbackActivity('ten_act_cashback', 'gam_act_cashback', 'act_cashback_percent', 'percent', 1000, 0, 1, 10000, 10);
        $this->insertCashbackActivity('ten_act_cashback', 'gam_act_cashback', 'act_cashback_fixed', 'fixed', 0, 1000, 1, 10000, 1);
        $this->insertPaidOrderWithTickets('par_act_cashback', 'ten_act_cashback', 'gam_act_cashback', 'cus_act_cashback', 'ord_cashback', ['223456', '223457'], 16000);
        $this->insertPublishedRewardResult('gam_act_cashback', 'rwr_act_cashback', '999999', '88');

        $detail = $service->customerActivity('ten_act_cashback', $this->customerContext('ten_act_cashback', 'cus_act_cashback'), 'act_cashback_percent');
        $this->assertSame(1600, $detail['cashback_progress']['estimated_amount']['amount'] ?? null);

        $this->assertSame(['lucky_awards' => 0, 'cashback_awards' => 1], $service->processGame('gam_act_cashback', 'cashback'));
        $this->assertSame(['lucky_awards' => 0, 'cashback_awards' => 0], $service->processGame('gam_act_cashback', 'cashback'));

        $this->assertDatabaseHas('tenant_activity_awards', [
            'tenant_id' => 'ten_act_cashback',
            'activity_id' => 'act_cashback_percent',
            'customer_id' => 'cus_act_cashback',
            'type' => 'cashback',
            'amount' => 1600,
            'status' => 'claimable',
        ]);
        $this->assertSame(1, DB::table('tenant_activity_awards')->where('tenant_id', 'ten_act_cashback')->where('type', 'cashback')->count());
    }

    public function test_activity_processing_waits_until_five_pm_on_draw_date(): void
    {
        $service = app(TenantActivityService::class);
        $this->insertActivePartnerTenantWithDomain('par_act_schedule', 'ten_act_schedule', 'act-schedule.test');
        $this->insertGame('gam_act_schedule', 'open');
        $this->issueCustomerToken('ten_act_schedule', 'cus_act_schedule');
        $this->insertLuckyActivity('ten_act_schedule', 'gam_act_schedule', 'act_lucky_schedule', thresholdTickets: 1, firstPrizeLast2Amount: 50000);
        $this->insertPaidOrderWithTickets('par_act_schedule', 'ten_act_schedule', 'gam_act_schedule', 'cus_act_schedule', 'ord_schedule', ['123456'], 8000);

        $customer = $this->customerContext('ten_act_schedule', 'cus_act_schedule');
        $service->createCustomerEntry('ten_act_schedule', $customer, 'act_lucky_schedule', [
            'prediction_type' => 'first_prize_last2',
            'selected_number' => '56',
        ]);
        $this->insertPublishedRewardResult('gam_act_schedule', 'rwr_act_schedule', '123456', '99');

        $this->assertSame(['lucky_awards' => 0, 'cashback_awards' => 0], $service->processGame('gam_act_schedule', 'lucky'));
        $this->assertDatabaseMissing('tenant_activity_awards', [
            'tenant_id' => 'ten_act_schedule',
            'activity_id' => 'act_lucky_schedule',
        ]);
    }

    private function customerContext(string $tenantId, string $customerId): CustomerSessionContext
    {
        return new CustomerSessionContext([
            'id' => 'cas_'.substr(sha1($tenantId.':'.$customerId), 0, 20),
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'pin_verified' => true,
        ], [
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'has_pin' => true,
        ]);
    }

    private function adminContext(string $tenantId, string $partnerId, string $adminId): AdminSessionContext
    {
        return new AdminSessionContext([
            'id' => 'ads_'.substr(sha1($adminId), 0, 20),
            'scope_type' => 'tenant',
            'scope_id' => 'scp_'.$adminId,
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
        ], [
            'id' => $adminId,
            'email' => $adminId.'@example.test',
        ], []);
    }

    private function idempotentRequest(string $key): Request
    {
        $request = Request::create('/api/v1/customer/activity-claims', 'POST');
        $request->headers->set('Idempotency-Key', $key);

        return $request;
    }

    private function markActivityResultReady(string $gameId): void
    {
        DB::table('games')->where('id', $gameId)->update([
            'draw_at' => now()->subDay(),
            'updated_at' => now(),
        ]);
    }

    private function insertLuckyActivity(
        string $tenantId,
        string $gameId,
        string $activityId,
        int $thresholdTickets,
        int $firstPrizeLast2Amount = 10000,
        string $eligibilityRule = 'cumulative_tickets',
    ): void {
        $this->insertActivity($tenantId, $gameId, $activityId, 'lucky_board', 1);
        DB::table('tenant_activity_lucky_configs')->insert([
            'activity_id' => $activityId,
            'first_prize_last2_enabled' => true,
            'first_prize_last3_enabled' => false,
            'last2_enabled' => false,
            'eligibility_rule' => $eligibilityRule,
            'threshold_tickets' => $thresholdTickets,
            'first_prize_last2_amount' => $firstPrizeLast2Amount,
            'first_prize_last3_amount' => 0,
            'last2_amount' => 5000,
            'currency' => 'THB',
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertCashbackActivity(
        string $tenantId,
        string $gameId,
        string $activityId,
        string $cashbackType,
        int $cashbackPercentBps,
        int $fixedAmount,
        int $minTicketCount,
        int $minPurchaseAmount,
        int $sortOrder,
    ): void {
        $this->insertActivity($tenantId, $gameId, $activityId, 'cashback', $sortOrder);
        DB::table('tenant_activity_cashback_configs')->insert([
            'activity_id' => $activityId,
            'cashback_type' => $cashbackType,
            'cashback_percent_bps' => $cashbackPercentBps,
            'fixed_amount' => $fixedAmount,
            'min_ticket_count' => $minTicketCount,
            'min_purchase_amount' => $minPurchaseAmount,
            'currency' => 'THB',
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertActivityAward(
        string $tenantId,
        string $gameId,
        string $activityId,
        string $customerId,
        string $awardId,
        mixed $createdAt,
    ): void {
        DB::table('tenant_activity_awards')->insert([
            'id' => $awardId,
            'tenant_id' => $tenantId,
            'activity_id' => $activityId,
            'game_id' => $gameId,
            'customer_id' => $customerId,
            'entry_id' => null,
            'type' => 'cashback',
            'prediction_type' => null,
            'amount' => 1000,
            'currency' => 'THB',
            'status' => 'claimable',
            'calculated_at' => $createdAt,
            'metadata_json' => null,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
    }

    private function insertActivityClaim(
        string $tenantId,
        string $gameId,
        string $activityId,
        string $customerId,
        string $awardId,
        string $claimId,
        mixed $createdAt,
    ): void {
        DB::table('activity_claims')->insert([
            'id' => $claimId,
            'tenant_id' => $tenantId,
            'activity_award_id' => $awardId,
            'activity_id' => $activityId,
            'game_id' => $gameId,
            'customer_id' => $customerId,
            'wallet_id' => null,
            'payout_ledger_id' => null,
            'reference' => 'ACT-'.strtoupper(substr($claimId, -10)),
            'status' => 'submitted',
            'payout_method' => 'wallet_credit',
            'claim_amount' => 1000,
            'currency' => 'THB',
            'bank_account_json' => null,
            'customer_note' => null,
            'admin_note' => null,
            'idempotency_key' => null,
            'payload_hash' => sha1($claimId),
            'reviewed_by_admin_id' => null,
            'paid_by_admin_id' => null,
            'submitted_at' => $createdAt,
            'reviewed_at' => null,
            'paid_at' => null,
            'created_at' => $createdAt,
            'updated_at' => $createdAt,
        ]);
    }

    private function insertActivity(string $tenantId, string $gameId, string $activityId, string $type, int $sortOrder): void
    {
        DB::table('tenant_activities')->insert([
            'id' => $activityId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'name' => 'Activity '.$activityId,
            'slug' => str_replace('_', '-', $activityId),
            'type' => $type,
            'status' => 'active',
            'sort_order' => $sortOrder,
            'image_full_asset_id' => null,
            'image_thumb_asset_id' => null,
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, string> $numbers
     */
    private function insertPaidOrderWithTickets(
        string $partnerId,
        string $tenantId,
        string $gameId,
        string $customerId,
        string $orderId,
        array $numbers,
        int $totalAmount,
    ): void {
        $localIds = $this->syncAllocatedStockToLocal($partnerId, $tenantId, $gameId, count($numbers), $orderId, (int) $numbers[0], 'store_'.$tenantId);
        $localIds = array_slice($localIds, -count($numbers));
        $reservationId = 'res_'.substr(sha1($orderId), 0, 20);
        DB::table('stock_reservations')->insert([
            'id' => $reservationId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'status' => 'converted',
            'expires_at' => now()->addMinutes(15),
            'released_at' => null,
            'cancelled_at' => null,
            'converted_at' => now(),
            'idempotency_key' => 'reservation-'.$orderId,
            'payload_hash' => sha1($orderId),
            'released_idempotency_key' => null,
            'released_payload_hash' => null,
            'cancelled_idempotency_key' => null,
            'cancelled_payload_hash' => null,
            'cancelled_by_admin_id' => null,
            'cancel_reason' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('orders')->insert([
            'id' => $orderId,
            'tenant_id' => $tenantId,
            'customer_id' => $customerId,
            'reservation_id' => $reservationId,
            'game_id' => $gameId,
            'wallet_id' => null,
            'payment_method' => 'wallet',
            'status' => 'paid',
            'payment_status' => 'paid',
            'total_amount' => $totalAmount,
            'currency' => 'THB',
            'reference' => 'ORD-'.$orderId,
            'admin_note' => null,
            'idempotency_key' => 'order-'.$orderId,
            'payload_hash' => sha1('order-'.$orderId),
            'paid_at' => now(),
            'cancelled_at' => null,
            'refunded_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        foreach (array_values($localIds) as $index => $localId) {
            $number = str_pad((string) $numbers[$index], 6, '0', STR_PAD_LEFT);
            DB::table('stock_reservation_items')->insert([
                'reservation_id' => $reservationId,
                'local_stock_item_id' => $localId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'converted',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
            DB::table('tickets')->insert([
                'id' => 'tic_'.substr(sha1($orderId.':'.$index), 0, 20),
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'order_id' => $orderId,
                'local_stock_item_id' => $localId,
                'game_id' => $gameId,
                'full_number' => $number,
                'status' => 'active',
                'image_url' => null,
                'image_thumb_url' => null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    private function insertPublishedRewardResult(string $gameId, string $resultId, string $firstPrize, string $last2): void
    {
        DB::table('reward_results')->insert([
            'id' => $resultId,
            'game_id' => $gameId,
            'status' => 'published',
            'version' => 1,
            'summary_json' => null,
            'created_by_admin_id' => null,
            'verified_by_admin_id' => null,
            'published_by_admin_id' => null,
            'corrected_by_admin_id' => null,
            'correction_note' => null,
            'checked_at' => now(),
            'verified_at' => now(),
            'published_at' => now(),
            'corrected_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('reward_prizes')->insert([
            [
                'id' => 'rpr_'.substr(sha1($resultId.':first'), 0, 20),
                'reward_result_id' => $resultId,
                'game_id' => $gameId,
                'prize_type' => 'first_prize',
                'prize_number' => $firstPrize,
                'amount' => 600000000,
                'currency' => 'THB',
                'sort_order' => 1,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'rpr_'.substr(sha1($resultId.':back2'), 0, 20),
                'reward_result_id' => $resultId,
                'game_id' => $gameId,
                'prize_type' => 'back2',
                'prize_number' => $last2,
                'amount' => 200000,
                'currency' => 'THB',
                'sort_order' => 2,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);
    }
}
