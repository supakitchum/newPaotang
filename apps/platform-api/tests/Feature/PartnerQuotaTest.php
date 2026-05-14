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

    public function test_PartnerQuota_create_list_update_validate_active_constraints_and_default_deny(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenant('par_quota', 'ten_quota');
        $this->insertGame('gam_quota', 'open');

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
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $quota = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partner-quotas', [
                'partner_id' => 'par_quota',
                'game_id' => 'gam_quota',
                'quota_count' => 5,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'quota-create-main',
            ])
            ->assertCreated()
            ->assertJsonPath('partner_id', 'par_quota')
            ->assertJsonPath('game_id', 'gam_quota')
            ->assertJsonPath('quota_count', 5)
            ->assertJsonPath('remaining_count', 5)
            ->json();

        $this->assertNotNull($quota['sale_start_at']);
        $this->assertNotNull($quota['sale_close_at']);
        $this->assertNull($quota['sale_start_override_at']);
        $this->assertNull($quota['sale_close_override_at']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partner-quotas', [
                'partner_id' => 'par_quota',
                'game_id' => 'gam_quota',
                'quota_count' => 7,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'quota-create-duplicate',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partner-quotas?partner_id=par_quota&game_id=gam_quota', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $quota['id']);

        $updatedQuota = $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-quotas/'.$quota['id'], [
                'quota_count' => 8,
                'sale_start_at' => now()->addHour()->toISOString(),
                'sale_close_at' => now()->addHours(10)->toISOString(),
                'status' => 'active',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'quota-update-main',
            ])
            ->assertOk()
            ->assertJsonPath('quota_count', 8)
            ->assertJsonPath('remaining_count', 8)
            ->json();

        $this->assertNotNull($updatedQuota['sale_start_override_at']);
        $this->assertNotNull($updatedQuota['sale_close_override_at']);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-quotas/'.$quota['id'], [
                'sale_start_at' => now()->subDay()->toISOString(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'quota-update-before-central',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.sale_start_at.0', 'Partner sale_start_at cannot be before the central sale_start_at.');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-quotas/'.$quota['id'], [
                'sale_close_at' => now()->addDays(2)->toISOString(),
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'quota-update-after-central',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.sale_close_at.0', 'Partner sale_close_at cannot be after the central close_at.');

        DB::table('partners')->where('id', 'par_quota')->update(['status' => 'suspended', 'updated_at' => now()]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partner-quotas', [
                'partner_id' => 'par_quota',
                'game_id' => 'gam_quota',
                'quota_count' => 2,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'quota-create-suspended-partner',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.partner_id.0', 'The partner_id field must reference an active partner.');

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'partner_quota.created',
            'target_id' => $quota['id'],
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'action' => 'partner_quota.updated',
            'target_id' => $quota['id'],
        ]);
    }
}
