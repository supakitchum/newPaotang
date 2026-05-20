<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\CentralStockFixtures;
use Tests\TestCase;

class PartnerQuotaTest extends TestCase
{
    use CentralStockFixtures;
    use RefreshDatabase;

    public function test_PartnerQuota_writes_are_retired_but_legacy_list_remains_permissioned(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_quota', 'ten_quota');
        $this->insertGame('gam_quota', 'open');
        $this->insertQuota('pqt_quota', 'par_quota', 'gam_quota', 5);

        $limitedLogin = $this->createCentralSession(['partner.view'], 'adm_quota_limited', 'quota-limited@example.test');

        $this->withToken($limitedLogin['access_token'])
            ->getJson('/api/v1/admin/central/partner-quotas', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->createCentralSession(['partner.quota.manage'], 'adm_quota', 'quota@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partner-quotas', [
                'partner_id' => 'par_quota',
                'game_id' => 'gam_quota',
                'quota_count' => 5,
            ], ['X-Admin-Scope' => 'central'])
            ->assertStatus(410)
            ->assertJsonPath('error.code', 'retired_flow')
            ->assertJsonPath('error.message', 'Partner quota writes are retired. Use partner stock percent allocation instead.');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partner-quotas?partner_id=par_quota&game_id=gam_quota', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', 'pqt_quota')
            ->assertJsonPath('data.0.quota_count', 5);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-quotas/pqt_quota', [
                'quota_count' => 8,
            ], [
                'X-Admin-Scope' => 'central',
            ])
            ->assertStatus(410)
            ->assertJsonPath('error.code', 'retired_flow');

        $this->assertSame(5, (int) DB::table('partner_quotas')->where('id', 'pqt_quota')->value('quota_count'));
    }
}
