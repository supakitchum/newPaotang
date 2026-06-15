<?php

namespace Tests\Feature;

use App\Modules\Reward\Services\TenantRewardPriceRuleService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class TenantRewardPriceRuleServiceTest extends TestCase
{
    use RefreshDatabase;

    public function test_payout_settings_fall_back_to_central_rewards_when_reward_rule_columns_are_missing(): void
    {
        Schema::shouldReceive('hasColumn')
            ->once()
            ->with('tenant_price_rules', 'base_source')
            ->andReturnFalse();

        $service = new TenantRewardPriceRuleService();
        $rows = $service->settingRows('ten_runtime_gap', 'gam_runtime_gap');
        $firstPrize = collect($rows)->firstWhere('prize_type', 'first_prize');

        $this->assertNotNull($firstPrize);
        $this->assertSame(600000000, $firstPrize['central_reward_amount']['amount']);
        $this->assertSame(600000000, $firstPrize['partner_payout_amount']['amount']);
        $this->assertNull($firstPrize['tenant_price_rule_id']);

        $saveResult = $service->savePayoutSetting('ten_runtime_gap', $firstPrize['id'], [
            'partner_payout_amount' => 599900000,
        ]);

        $this->assertSame('validation_failed', $saveResult['error'] ?? null);
        $this->assertArrayHasKey('price_rule_schema', $saveResult['errors'] ?? []);
    }
}
