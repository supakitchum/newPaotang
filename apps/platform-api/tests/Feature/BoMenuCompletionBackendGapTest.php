<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class BoMenuCompletionBackendGapTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_scoped_bo_gap_routes_are_registered(): void
    {
        $routes = collect(Route::getRoutes())->map(fn ($route): string => implode('|', $route->methods()).' '.$route->uri())->all();

        foreach ([
            'GET|HEAD api/v1/admin/central/partner-monitoring',
            'GET|HEAD api/v1/admin/central/partner-monitoring/{monitoring_profile_id}',
            'PATCH api/v1/admin/central/partner-monitoring/{monitoring_profile_id}',
            'GET|HEAD api/v1/admin/central/partner-usage',
            'GET|HEAD api/v1/admin/central/partner-usage/{usage_meter_id}',
            'PATCH api/v1/admin/central/partner-usage/{usage_meter_id}',
            'GET|HEAD api/v1/admin/central/billing-plans',
            'POST api/v1/admin/central/billing-plans',
            'GET|HEAD api/v1/admin/central/billing-plans/{billing_plan_id}',
            'PATCH api/v1/admin/central/billing-plans/{billing_plan_id}',
            'GET|HEAD api/v1/admin/central/billing-bindings',
            'GET|HEAD api/v1/admin/central/billing-bindings/{billing_binding_id}',
            'PATCH api/v1/admin/central/billing-bindings/{billing_binding_id}',
            'GET|HEAD api/v1/admin/central/alert-policies',
            'POST api/v1/admin/central/alert-policies',
            'GET|HEAD api/v1/admin/central/alert-policies/{alert_policy_id}',
            'PATCH api/v1/admin/central/alert-policies/{alert_policy_id}',
            'GET|HEAD api/v1/admin/central/alert-events',
            'GET|HEAD api/v1/admin/central/alert-events/{alert_event_id}',
            'POST api/v1/admin/central/alert-events/{alert_event_id}/acknowledge',
            'POST api/v1/admin/central/alert-events/{alert_event_id}/resolve',
            'GET|HEAD api/v1/admin/central/system-settings',
            'PATCH api/v1/admin/central/system-settings',
            'GET|HEAD api/v1/admin/central/webhook-logs',
            'GET|HEAD api/v1/admin/central/webhook-logs/{webhook_log_id}',
            'GET|HEAD api/v1/admin/central/sync-logs',
            'GET|HEAD api/v1/admin/tenant/price-rules',
            'GET|HEAD api/v1/admin/tenant/price-rule-games',
            'GET|HEAD api/v1/admin/tenant/price-rules/live-settings',
            'PATCH api/v1/admin/tenant/price-rules/live-settings',
            'POST api/v1/admin/tenant/price-rules',
            'GET|HEAD api/v1/admin/tenant/price-rules/{price_rule_id}',
            'PATCH api/v1/admin/tenant/price-rules/{price_rule_id}',
            'DELETE api/v1/admin/tenant/price-rules/{price_rule_id}',
            'GET|HEAD api/v1/admin/tenant/domains',
            'POST api/v1/admin/tenant/domains',
            'GET|HEAD api/v1/admin/tenant/domains/{domain_id}',
            'PATCH api/v1/admin/tenant/domains/{domain_id}',
            'DELETE api/v1/admin/tenant/domains/{domain_id}',
            'POST api/v1/admin/tenant/domains/{domain_id}/verify',
            'GET|HEAD api/v1/admin/tenant/members',
            'POST api/v1/admin/tenant/members',
            'GET|HEAD api/v1/admin/tenant/members/{member_id}',
            'PATCH api/v1/admin/tenant/members/{member_id}',
            'POST api/v1/admin/tenant/members/{member_id}/status',
            'GET|HEAD api/v1/admin/tenant/monitoring',
            'GET|HEAD api/v1/admin/tenant/usage',
            'GET|HEAD api/v1/admin/tenant/sync-logs',
        ] as $expected) {
            $this->assertContains($expected, $routes);
        }
    }

    public function test_central_bo_gap_endpoints_enforce_rbac_and_support_operational_reads_and_writes(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner('par_bo_gap');
        $this->createTenant('ten_bo_gap', 'par_bo_gap');
        $this->createAdmin('adm_central_gap', 'central-gap@example.test');
        $this->createAdminScope('scp_central_gap', 'central');
        $this->assignRoleWithPermissions('adm_central_gap', 'scp_central_gap', 'central', null, [
            'partner.monitoring.view',
            'partner.monitoring.manage',
            'partner.usage.view',
            'partner.usage.manage',
            'partner.billing.view',
            'partner.billing.manage',
            'partner.alert.manage',
            'partner.alert.view',
            'audit.view',
            'system.settings.manage',
        ], 'central_bo_gap');

        $this->createAdmin('adm_central_limited', 'central-gap-limited@example.test');
        $this->createAdminScope('scp_central_limited', 'central');
        $this->assignRoleWithPermissions('adm_central_limited', 'scp_central_limited', 'central', null, ['partner.view'], 'central_limited');

        $this->insertCentralOperationalFixtures();

        $limited = $this->loginAdmin([
            'email' => 'central-gap-limited@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $this->withToken($limited['access_token'])
            ->getJson('/api/v1/admin/central/partner-monitoring', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->loginAdmin([
            'email' => 'central-gap@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
        $headers = ['X-Admin-Scope' => 'central'];

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partner-monitoring?partner_id=par_bo_gap', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.id', 'mon_bo_gap')
            ->assertJsonPath('data.0.partner.id', 'par_bo_gap')
            ->assertJsonPath('data.0.checks.0.tenant_id', 'ten_bo_gap');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-monitoring/mon_bo_gap', [
                'status' => 'paused',
                'health_status' => 'critical',
            ], $headers + ['Idempotency-Key' => 'central-monitoring-update'])
            ->assertOk()
            ->assertJsonPath('status', 'paused')
            ->assertJsonPath('health_status', 'critical');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partner-usage/usg_bo_gap', $headers)
            ->assertOk()
            ->assertJsonPath('id', 'usg_bo_gap')
            ->assertJsonPath('meter_key', 'api_requests');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-usage/usg_bo_gap', [
                'limit_value' => 2000,
                'status' => 'paused',
            ], $headers + ['Idempotency-Key' => 'central-usage-update'])
            ->assertOk()
            ->assertJsonPath('status', 'paused')
            ->assertJsonPath('limit_value', 2000);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/billing-plans', [
                'code' => 'enterprise',
                'name' => 'Enterprise',
                'monthly_fee_amount' => 500000,
                'limits' => ['tenants' => 10],
            ], $headers)
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $plan = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/billing-plans', [
                'code' => 'enterprise',
                'name' => 'Enterprise',
                'monthly_fee_amount' => 500000,
                'limits' => ['tenants' => 10],
            ], $headers + ['Idempotency-Key' => 'central-billing-create'])
            ->assertCreated()
            ->assertJsonPath('code', 'enterprise')
            ->assertJsonPath('monthly_fee.amount', 500000)
            ->json();

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/billing-plans/'.$plan['id'], [
                'status' => 'archived',
            ], $headers + ['Idempotency-Key' => 'central-billing-update'])
            ->assertOk()
            ->assertJsonPath('status', 'archived');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/billing-bindings?partner_id=par_bo_gap', $headers)
            ->assertOk()
            ->assertJsonPath('data.0.id', 'bpb_bo_gap')
            ->assertJsonPath('data.0.partner.id', 'par_bo_gap');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/billing-bindings/bpb_bo_gap', $headers)
            ->assertOk()
            ->assertJsonPath('id', 'bpb_bo_gap')
            ->assertJsonPath('billing_plan_code', 'starter');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/billing-bindings/bpb_bo_gap', [
                'billing_plan_code' => 'enterprise',
                'status' => 'active',
            ], $headers + ['Idempotency-Key' => 'central-billing-binding-update'])
            ->assertOk()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('billing_plan_code', 'enterprise');

        $policy = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/alert-policies', [
                'partner_id' => 'par_bo_gap',
                'policy_key' => 'sync_lag',
                'severity' => 'critical',
                'config' => ['threshold_seconds' => 300],
            ], $headers + ['Idempotency-Key' => 'central-alert-policy-create'])
            ->assertCreated()
            ->assertJsonPath('partner_id', 'par_bo_gap')
            ->assertJsonPath('policy_key', 'sync_lag')
            ->json();

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/alert-policies/'.$policy['id'], [
                'status' => 'paused',
            ], $headers + ['Idempotency-Key' => 'central-alert-policy-update'])
            ->assertOk()
            ->assertJsonPath('status', 'paused');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/alert-events/ale_bo_gap/acknowledge', [
                'reason' => 'Investigating',
            ], $headers + ['Idempotency-Key' => 'central-alert-event-ack'])
            ->assertOk()
            ->assertJsonPath('status', 'acknowledged');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/system-settings', $headers)
            ->assertOk()
            ->assertJsonPath('settings.bo_menu_completion_backend_gaps', 'implemented');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/system-settings', [
                'settings' => ['release_gate_note' => 'backend gap closed'],
            ], $headers + ['Idempotency-Key' => 'central-system-settings-update'])
            ->assertOk()
            ->assertJsonPath('settings.release_gate_note', 'backend gap closed');

        $webhook = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/webhook-logs/whc_bo_gap', $headers)
            ->assertOk()
            ->assertJsonPath('provider', 'payment')
            ->json();

        $this->assertSame('[REDACTED]', $webhook['payload']['client_secret']);
        $syncLogs = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/sync-logs?status=pending', $headers)
            ->assertOk()
            ->json();

        $this->assertContains('outbox', array_column($syncLogs['data'], 'direction'));
        $this->assertContains('inbox', array_column($syncLogs['data'], 'direction'));
        $this->assertDatabaseHas('audit_logs', ['action' => 'billing_plan.created', 'target_id' => $plan['id']]);
        $this->assertDatabaseHas('audit_logs', ['action' => 'partner_monitoring.updated', 'target_id' => 'mon_bo_gap']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'billing_binding.updated', 'target_id' => 'bpb_bo_gap']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'alert_event.acknowledged', 'target_id' => 'ale_bo_gap']);
    }

    public function test_tenant_bo_gap_endpoints_are_tenant_scoped_and_support_members_price_rules_monitoring_and_usage(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner('par_tenant_gap');
        $this->createPartner('par_other_gap');
        $this->createTenant('ten_tenant_gap', 'par_tenant_gap');
        $this->createTenant('ten_other_gap', 'par_other_gap');
        $this->createAdmin('adm_tenant_gap', 'tenant-gap@example.test');
        $this->createAdminScope('scp_tenant_gap', 'tenant', 'ten_tenant_gap', 'par_tenant_gap');
        $this->assignRoleWithPermissions('adm_tenant_gap', 'scp_tenant_gap', 'tenant', 'ten_tenant_gap', [
            'price_rule.view',
            'price_rule.manage',
            'customer.view',
            'customer.create',
            'customer.update',
            'customer.suspend',
            'monitoring.view',
            'usage.view',
            'sync_log.view',
            'settings.view',
            'settings.manage',
        ], 'tenant_bo_gap');

        $this->createAdmin('adm_tenant_limited', 'tenant-gap-limited@example.test');
        $this->createAdminScope('scp_tenant_limited', 'tenant', 'ten_tenant_gap', 'par_tenant_gap');
        $this->assignRoleWithPermissions('adm_tenant_limited', 'scp_tenant_limited', 'tenant', 'ten_tenant_gap', ['customer.view'], 'tenant_limited');

        $this->insertTenantOperationalFixtures();

        $limited = $this->loginAdmin([
            'email' => 'tenant-gap-limited@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_tenant_gap',
        ]);
        $tenantHeaders = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => 'ten_tenant_gap',
        ];

        $this->withToken($limited['access_token'])
            ->getJson('/api/v1/admin/tenant/price-rules', $tenantHeaders)
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->loginAdmin([
            'email' => 'tenant-gap@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_tenant_gap',
        ]);

        DB::table('platform_system_settings')->insert([
            'id' => 'pss_live_url',
            'key' => 'waiting_result_youtube_url',
            'value_json' => json_encode('https://www.youtube.com/watch?v=M7lc1UVf-VE', JSON_THROW_ON_ERROR),
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/price-rule-games', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('meta.default_game_id', 'gam_price_gap')
            ->assertJsonPath('data.0.game_id', 'gam_price_gap');

        $priceRule = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/price-rules?game_id=gam_price_gap', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('data.0.game_id', 'gam_price_gap')
            ->assertJsonPath('data.0.prize_type', 'first_prize')
            ->assertJsonPath('data.0.central_reward_amount.amount', 6000000)
            ->assertJsonPath('data.0.partner_payout_amount.amount', 6000000)
            ->assertJsonPath('meta.live_settings.waiting_result_youtube_url', 'https://www.youtube.com/watch?v=M7lc1UVf-VE')
            ->assertJsonPath('meta.live_settings.waiting_result_youtube_embed_url', 'https://www.youtube.com/embed/M7lc1UVf-VE')
            ->assertJsonPath('meta.live_settings.source', 'central_default')
            ->json();
        $firstPrizeRowId = $priceRule['data'][0]['id'];

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/price-rules/live-settings', [
                'live' => [
                    'waiting_result_youtube_url' => 'https://youtu.be/dQw4w9WgXcQ',
                ],
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-price-rule-live-settings'])
            ->assertOk()
            ->assertJsonPath('tenant_override_youtube_url', 'https://youtu.be/dQw4w9WgXcQ')
            ->assertJsonPath('waiting_result_youtube_url', 'https://youtu.be/dQw4w9WgXcQ')
            ->assertJsonPath('waiting_result_youtube_embed_url', 'https://www.youtube.com/embed/dQw4w9WgXcQ')
            ->assertJsonPath('central_default_youtube_url', 'https://www.youtube.com/watch?v=M7lc1UVf-VE')
            ->assertJsonPath('source', 'tenant_override');

        $updatedPriceRule = $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/price-rules/'.$firstPrizeRowId, [
                'partner_payout_amount' => 5900000,
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-price-rule-payout-update'])
            ->assertOk()
            ->assertJsonPath('id', $firstPrizeRowId)
            ->assertJsonPath('partner_payout_amount.amount', 5900000)
            ->assertJsonPath('adjustment_amount.amount', -100000)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/price-rules/'.$firstPrizeRowId, $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('partner_payout_amount.amount', 5900000)
            ->assertJsonPath('tenant_price_rule_id', $updatedPriceRule['tenant_price_rule_id']);

        $domain = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/tenant/domains', [
                'host' => 'tenant-gap.newpaotang.test',
                'type' => 'subdomain',
                'is_primary' => true,
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-domain-create'])
            ->assertCreated()
            ->assertJsonPath('tenant_id', 'ten_tenant_gap')
            ->assertJsonPath('host', 'tenant-gap.newpaotang.test')
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('readiness.local_only', true)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/domains/'.$domain['id'], $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('id', $domain['id'])
            ->assertJsonPath('is_primary', true);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/tenant/domains/'.$domain['id'].'/verify', [
                'dns_verified' => true,
                'ssl_ready' => true,
                'cloudflare_proxy_verified' => true,
                'https_enforced' => true,
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-domain-verify'])
            ->assertAccepted()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('readiness.dns_verified', true);

        $this->getJson('http://tenant-gap.newpaotang.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.live.waiting_result_youtube_url', 'https://youtu.be/dQw4w9WgXcQ')
            ->assertJsonPath('data.live.waiting_result_youtube_embed_url', 'https://www.youtube.com/embed/dQw4w9WgXcQ')
            ->assertJsonPath('data.live.central_default_youtube_url', 'https://www.youtube.com/watch?v=M7lc1UVf-VE')
            ->assertJsonPath('data.live.source', 'tenant_override');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/domains/'.$domain['id'], [
                'status' => 'suspended',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-domain-update'])
            ->assertOk()
            ->assertJsonPath('status', 'suspended');

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/tenant/domains/'.$domain['id'], [
                'reason' => 'Domain removed by tenant admin',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-domain-delete'])
            ->assertNoContent();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/domains/'.$domain['id'], $tenantHeaders)
            ->assertNotFound();

        $member = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/tenant/members', [
                'name' => 'Tenant Member',
                'phone' => '0811111111',
                'email' => 'member@example.test',
                'password' => 'member-secret',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-member-create'])
            ->assertCreated()
            ->assertJsonPath('tenant_id', 'ten_tenant_gap')
            ->assertJsonPath('phone', '0811111111')
            ->assertJsonMissingPath('password_hash')
            ->json();

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/members/'.$member['id'], [
                'name' => 'Tenant Member Updated',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-member-update'])
            ->assertOk()
            ->assertJsonPath('name', 'Tenant Member Updated');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/tenant/members/'.$member['id'].'/status', [
                'status' => 'suspended',
                'reason' => 'Risk review',
            ], $tenantHeaders + ['Idempotency-Key' => 'tenant-member-status'])
            ->assertOk()
            ->assertJsonPath('status', 'suspended');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/members?status=suspended', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('data.0.id', $member['id'])
            ->assertJsonMissing(['cus_other_gap']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/members/cus_other_gap', $tenantHeaders)
            ->assertNotFound();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/monitoring', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('tenant_id', 'ten_tenant_gap')
            ->assertJsonPath('partner_id', 'par_tenant_gap')
            ->assertJsonPath('checks.0.tenant_id', 'ten_tenant_gap');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/usage?date_from=2026-05-01&date_to=2026-05-31', $tenantHeaders)
            ->assertOk()
            ->assertJsonPath('tenant_id', 'ten_tenant_gap')
            ->assertJsonPath('totals.api_request_count', 9)
            ->assertJsonPath('summaries.0.tenant_id', 'ten_tenant_gap');

        $syncLogs = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/sync-logs?status=pending', $tenantHeaders)
            ->assertOk()
            ->assertJsonMissing(['ten_other_gap'])
            ->json();

        $this->assertNotEmpty($syncLogs['data']);
        $this->assertSame(['ten_tenant_gap'], array_values(array_unique(array_column($syncLogs['data'], 'tenant_id'))));

        $this->assertDatabaseHas('audit_logs', ['action' => 'price_rule.updated', 'target_id' => $updatedPriceRule['tenant_price_rule_id'], 'tenant_id' => 'ten_tenant_gap']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'domain.created', 'target_id' => $domain['id'], 'tenant_id' => 'ten_tenant_gap']);
        $this->assertDatabaseHas('audit_logs', ['action' => 'member.status_changed', 'target_id' => $member['id'], 'tenant_id' => 'ten_tenant_gap']);
    }

    private function insertCentralOperationalFixtures(): void
    {
        DB::table('partner_monitoring_profiles')->insert([
            'id' => 'mon_bo_gap',
            'partner_id' => 'par_bo_gap',
            'status' => 'active',
            'health_status' => 'warning',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_health_checks')->insert([
            'id' => 'phc_bo_gap',
            'partner_id' => 'par_bo_gap',
            'tenant_id' => 'ten_bo_gap',
            'check_key' => 'queue_lag',
            'health_status' => 'warning',
            'checked_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_usage_meters')->insert([
            'id' => 'usg_bo_gap',
            'partner_id' => 'par_bo_gap',
            'meter_key' => 'api_requests',
            'value' => 42,
            'limit_value' => 1000,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_billing_plan_bindings')->insert([
            'id' => 'bpb_bo_gap',
            'partner_id' => 'par_bo_gap',
            'billing_plan_code' => 'starter',
            'status' => 'trial',
            'effective_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_daily_usage_summaries')->insert([
            'id' => 'pdu_bo_gap',
            'partner_id' => 'par_bo_gap',
            'tenant_id' => 'ten_bo_gap',
            'usage_date' => '2026-05-09',
            'api_request_count' => 42,
            'booking_request_count' => 2,
            'checkout_request_count' => 1,
            'order_count' => 1,
            'sold_ticket_count' => 1,
            'image_bandwidth_gb' => 0,
            'storage_gb' => 0,
            'queue_job_count' => 3,
            'rate_limited_count' => 0,
            'error_count' => 0,
            'sync_event_count' => 1,
            'labels_json' => json_encode(['source' => 'test'], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('sync_outbox')->insert([
            'id' => 'out_bo_gap',
            'event_id' => 'evt_bo_gap_outbox',
            'event_type' => 'stock.allocated.v1',
            'event_version' => 1,
            'producer' => 'central_stock',
            'tenant_id' => 'ten_bo_gap',
            'partner_id' => 'par_bo_gap',
            'game_id' => null,
            'aggregate_type' => 'stock_allocation',
            'aggregate_id' => 'alc_bo_gap',
            'idempotency_key' => 'central-gap-sync',
            'correlation_id' => 'req-central-gap-sync',
            'payload_json' => json_encode(['client_secret' => 'sync-secret'], JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => now(),
            'processed_at' => null,
            'last_error' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('sync_inbox')->insert([
            'id' => 'inb_bo_gap',
            'event_id' => 'evt_bo_gap_inbox',
            'event_type' => 'stock.sold.v1',
            'event_version' => 1,
            'consumer' => 'central_stock',
            'tenant_id' => 'ten_bo_gap',
            'partner_id' => 'par_bo_gap',
            'game_id' => null,
            'idempotency_key' => 'central-gap-inbox',
            'payload_hash' => hash('sha256', 'central-gap-inbox'),
            'status' => 'pending',
            'processed_at' => null,
            'last_error' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_alert_events')->insert([
            'id' => 'ale_bo_gap',
            'partner_id' => 'par_bo_gap',
            'tenant_id' => 'ten_bo_gap',
            'alert_policy_id' => null,
            'policy_key' => 'sync_lag',
            'severity' => 'warning',
            'status' => 'open',
            'channel' => 'database',
            'title' => 'Sync lag',
            'message' => 'Partner sync lag exceeded threshold.',
            'labels_json' => json_encode(['env' => 'test'], JSON_THROW_ON_ERROR),
            'payload_redacted_json' => json_encode(['queue' => 'partner-inbox-normal'], JSON_THROW_ON_ERROR),
            'dry_run' => true,
            'triggered_at' => now(),
            'delivered_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('webhook_callbacks')->insert([
            'id' => 'whc_bo_gap',
            'domain' => 'payments',
            'provider' => 'payment',
            'callback_key' => 'cb_bo_gap',
            'payload_hash' => hash('sha256', 'cb_bo_gap'),
            'status' => 'accepted',
            'payment_id' => null,
            'topup_request_id' => null,
            'payload_json' => json_encode(['client_secret' => 'should-redact'], JSON_THROW_ON_ERROR),
            'response_json' => json_encode(['ok' => true], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function insertTenantOperationalFixtures(): void
    {
        DB::table('games')->insert([
            'id' => 'gam_price_gap',
            'code' => 'PRICE-GAP',
            'name' => 'Price Gap Draw',
            'sale_start_at' => now()->subHour(),
            'draw_at' => now()->addDay(),
            'close_at' => now()->addHours(20),
            'closed_at' => null,
            'archived_at' => null,
            'status' => 'open',
            'metadata_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('customers')->insert([
            'id' => 'cus_other_gap',
            'tenant_id' => 'ten_other_gap',
            'phone' => '0899999999',
            'email' => 'other@example.test',
            'password_hash' => null,
            'avatar_url' => null,
            'name' => 'Other Tenant',
            'status' => 'active',
            'last_login_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_monitoring_profiles')->insert([
            'id' => 'mon_tenant_gap',
            'partner_id' => 'par_tenant_gap',
            'status' => 'active',
            'health_status' => 'healthy',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_health_checks')->insert([
            'id' => 'phc_tenant_gap',
            'partner_id' => 'par_tenant_gap',
            'tenant_id' => 'ten_tenant_gap',
            'check_key' => 'runtime',
            'health_status' => 'healthy',
            'checked_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_daily_usage_summaries')->insert([
            'id' => 'pdu_tenant_gap',
            'partner_id' => 'par_tenant_gap',
            'tenant_id' => 'ten_tenant_gap',
            'usage_date' => '2026-05-09',
            'api_request_count' => 9,
            'booking_request_count' => 1,
            'checkout_request_count' => 1,
            'order_count' => 1,
            'sold_ticket_count' => 1,
            'image_bandwidth_gb' => 0,
            'storage_gb' => 0,
            'queue_job_count' => 1,
            'rate_limited_count' => 0,
            'error_count' => 0,
            'sync_event_count' => 1,
            'labels_json' => json_encode(['source' => 'tenant-test'], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_daily_usage_summaries')->insert([
            'id' => 'pdu_other_gap',
            'partner_id' => 'par_tenant_gap',
            'tenant_id' => 'ten_other_gap',
            'usage_date' => '2026-05-09',
            'api_request_count' => 999,
            'booking_request_count' => 0,
            'checkout_request_count' => 0,
            'order_count' => 0,
            'sold_ticket_count' => 0,
            'image_bandwidth_gb' => 0,
            'storage_gb' => 0,
            'queue_job_count' => 0,
            'rate_limited_count' => 0,
            'error_count' => 0,
            'sync_event_count' => 0,
            'labels_json' => json_encode(['source' => 'other-test'], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('sync_outbox')->insert([
            'id' => 'out_tenant_gap',
            'event_id' => 'evt_tenant_gap_outbox',
            'event_type' => 'wallet.updated.v1',
            'event_version' => 1,
            'producer' => 'tenant_wallet',
            'tenant_id' => 'ten_tenant_gap',
            'partner_id' => 'par_tenant_gap',
            'game_id' => null,
            'aggregate_type' => 'wallet',
            'aggregate_id' => 'wal_tenant_gap',
            'idempotency_key' => 'tenant-gap-sync',
            'correlation_id' => 'req-tenant-gap-sync',
            'payload_json' => json_encode(['customer_phone' => '0811111111'], JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => now(),
            'processed_at' => null,
            'last_error' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('sync_inbox')->insert([
            'id' => 'inb_tenant_gap',
            'event_id' => 'evt_tenant_gap_inbox',
            'event_type' => 'stock.allocated.v1',
            'event_version' => 1,
            'consumer' => 'tenant_stock',
            'tenant_id' => 'ten_tenant_gap',
            'partner_id' => 'par_tenant_gap',
            'game_id' => null,
            'idempotency_key' => 'tenant-gap-inbox',
            'payload_hash' => hash('sha256', 'tenant-gap-inbox'),
            'status' => 'pending',
            'processed_at' => null,
            'last_error' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('sync_outbox')->insert([
            'id' => 'out_other_gap',
            'event_id' => 'evt_other_gap_outbox',
            'event_type' => 'wallet.updated.v1',
            'event_version' => 1,
            'producer' => 'tenant_wallet',
            'tenant_id' => 'ten_other_gap',
            'partner_id' => 'par_tenant_gap',
            'game_id' => null,
            'aggregate_type' => 'wallet',
            'aggregate_id' => 'wal_other_gap',
            'idempotency_key' => 'tenant-other-sync',
            'correlation_id' => 'req-tenant-other-sync',
            'payload_json' => json_encode(['customer_phone' => '0899999999'], JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => now(),
            'processed_at' => null,
            'last_error' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
