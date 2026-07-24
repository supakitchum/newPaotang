<?php

namespace Database\Seeders;

use App\Models\AdminMenu;
use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminScope;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\Partner;
use App\Models\PartnerAlertPolicy;
use App\Models\PartnerBillingPlanBinding;
use App\Models\PartnerHealthCheck;
use App\Models\PartnerMonitoringProfile;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDeploymentProfile;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantFeatureFlag;
use App\Models\PartnerTenantMaintenanceEvent;
use App\Models\PartnerTenantMaintenanceSetting;
use App\Models\PartnerTenantSetting;
use App\Models\PartnerTenantTheme;
use App\Models\PartnerUsageMeter;
use App\Models\Permission;
use App\Models\Role;
use App\Models\RoleMenu;
use App\Models\RolePermission;
use App\Shared\Observability\ObservabilityCatalog;
use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;

class DemoTenantSeeder extends Seeder
{
    public function run(): void
    {
        $now = now();

        foreach ($this->tenants() as $tenant) {
            $this->seedTenant($tenant, $now);
        }
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function tenants(): array
    {
        return [
            [
                'partner_id' => 'par_demo_alpha',
                'partner_code' => 'demo_alpha',
                'partner_name' => 'Demo Alpha Partner',
                'tenant_id' => 'ten_demo_alpha',
                'tenant_code' => 'demo_alpha',
                'tenant_name' => 'Demo Alpha Lottery',
                'domain_host' => 'alpha.newpaotang.test',
                'owner_id' => 'adm_demo_alpha_owner',
                'owner_name' => 'Alpha Owner',
                'owner_email' => 'owner@alpha.newpaotang.test',
                'site_name' => 'Alpha Lucky Shop',
                'primary_color' => '#0F766E',
                'features' => ['affiliate' => true, 'agent_network' => true, 'custom_domain' => false],
            ],
            [
                'partner_id' => 'par_demo_beta',
                'partner_code' => 'demo_beta',
                'partner_name' => 'Demo Beta Partner',
                'tenant_id' => 'ten_demo_beta',
                'tenant_code' => 'demo_beta',
                'tenant_name' => 'Demo Beta Rewards',
                'domain_host' => 'beta.newpaotang.test',
                'owner_id' => 'adm_demo_beta_owner',
                'owner_name' => 'Beta Owner',
                'owner_email' => 'owner@beta.newpaotang.test',
                'site_name' => 'Beta Reward House',
                'primary_color' => '#2563EB',
                'features' => ['affiliate' => true, 'agent_network' => false, 'topup_qr' => true],
            ],
            [
                'partner_id' => 'par_demo_gamma',
                'partner_code' => 'demo_gamma',
                'partner_name' => 'Demo Gamma Partner',
                'tenant_id' => 'ten_demo_gamma',
                'tenant_code' => 'demo_gamma',
                'tenant_name' => 'Demo Gamma Prizes',
                'domain_host' => 'gamma.newpaotang.test',
                'owner_id' => 'adm_demo_gamma_owner',
                'owner_name' => 'Gamma Owner',
                'owner_email' => 'owner@gamma.newpaotang.test',
                'site_name' => 'Gamma Prize Market',
                'primary_color' => '#7C3AED',
                'features' => ['affiliate' => false, 'agent_network' => true, 'cashback' => true],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     */
    private function seedTenant(array $tenant, mixed $now): void
    {
        Partner::updateOrCreate(
            ['id' => $tenant['partner_id']],
            [
                'code' => $tenant['partner_code'],
                'name' => $tenant['partner_name'],
                'type' => 'white_label',
                'status' => 'active',
            ],
        );

        PartnerTenant::updateOrCreate(
            ['id' => $tenant['tenant_id']],
            [
                'partner_id' => $tenant['partner_id'],
                'code' => $tenant['tenant_code'],
                'name' => $tenant['tenant_name'],
                'status' => 'active',
            ],
        );

        PartnerTenantDomain::updateOrCreate(
            ['id' => $this->stableId('dom', $tenant['domain_host'])],
            [
                'partner_id' => $tenant['partner_id'],
                'tenant_id' => $tenant['tenant_id'],
                'host' => $tenant['domain_host'],
                'type' => 'subdomain',
                'status' => 'active',
                'is_primary' => true,
                'verified_at' => $now,
                'ssl_ready_at' => $now,
            ],
        );

        $scopeId = $this->tenantScopeId($tenant['tenant_id']);
        $roleId = $this->stableId('rol', 'tenant:'.$tenant['tenant_id'].':owner');

        AdminScope::updateOrCreate(
            ['id' => $scopeId],
            [
                'scope_type' => 'tenant',
                'tenant_id' => $tenant['tenant_id'],
                'partner_id' => $tenant['partner_id'],
            ],
        );

        Role::updateOrCreate(
            ['id' => $roleId],
            [
                'scope_type' => 'tenant',
                'tenant_id' => $tenant['tenant_id'],
                'code' => 'owner',
                'name' => 'Tenant Owner',
                'status' => 'active',
                'version' => 1,
            ],
        );

        AdminUser::updateOrCreate(
            ['email' => $tenant['owner_email']],
            [
                'id' => $tenant['owner_id'],
                'name' => $tenant['owner_name'],
                'phone' => null,
                'password_hash' => Hash::make($this->tenantOwnerPassword()),
                'status' => 'active',
                'two_factor_enabled' => false,
            ] + $this->forcedPasswordDefaults(),
        );

        AdminUserRole::query()->insertOrIgnore([[
            'admin_user_id' => $tenant['owner_id'],
            'role_id' => $roleId,
            'scope_id' => $scopeId,
            'created_at' => $now,
            'updated_at' => $now,
        ]]);

        $this->syncRolePermissions($roleId, 'tenant', $now);
        $this->syncRoleMenus($roleId, 'tenant', $now);
        $this->seedTenantConfig($tenant, $now);
        $this->seedRuntimeDefaults($tenant, $now);
        $this->seedStarterAffiliateDefaults($tenant, $now);

        AdminPermissionCacheVersion::updateOrCreate(
            ['admin_user_id' => $tenant['owner_id'], 'scope_id' => $scopeId],
            [
                'id' => $this->stableId('pcv', $tenant['owner_id'].':'.$scopeId),
                'version' => 2,
            ],
        );
    }

    /**
     * @param array<string, mixed> $tenant
     */
    private function seedTenantConfig(array $tenant, mixed $now): void
    {
        PartnerTenantSetting::updateOrCreate(
            ['tenant_id' => $tenant['tenant_id']],
            [
                'id' => $this->stableId('pts', $tenant['tenant_id']),
                'site_name' => $tenant['site_name'],
                'display_name' => $tenant['tenant_name'],
                'locale' => 'th-TH',
                'timezone' => 'Asia/Bangkok',
                'support_email' => 'support@'.$tenant['domain_host'],
                'support_phone' => null,
                'default_title' => $tenant['site_name'],
                'title_template' => '%s | '.$tenant['site_name'],
                'default_description' => $tenant['tenant_name'].' demo tenant for local development.',
                'default_keywords_json' => ['lottery', 'reward', $tenant['tenant_code']],
                'robots_default' => 'index,follow',
                'sitemap_enabled' => true,
                'robots_enabled' => true,
                'maintenance_active' => false,
                'maintenance_mode' => null,
                'maintenance_message' => null,
                'maintenance_expected_end_at' => null,
                'maintenance_retry_after_seconds' => null,
                'maintenance_allowed_routes_json' => [],
                'maintenance_blocked_route_patterns_json' => [],
                'api_base_url' => '/api/v1',
                'realtime_url' => null,
                'asset_cdn_base_url' => 'https://'.$tenant['domain_host'],
                'config_version' => 1,
            ],
        );

        PartnerTenantTheme::updateOrCreate(
            ['tenant_id' => $tenant['tenant_id']],
            [
                'id' => $this->stableId('ptt', $tenant['tenant_id']),
                'logo_url' => null,
                'favicon_url' => null,
                'og_image_url' => null,
                'primary_color' => $tenant['primary_color'],
                'secondary_color' => '#2563EB',
                'accent_color' => '#F59E0B',
                'background_color' => '#FFFFFF',
                'text_color' => '#111827',
                'font_family' => 'Inter, sans-serif',
                'config_version' => 1,
            ],
        );

        PartnerTenantMaintenanceSetting::updateOrCreate(
            ['tenant_id' => $tenant['tenant_id']],
            [
                'id' => $this->stableId('pms', $tenant['tenant_id']),
                'status' => 'inactive',
                'mode' => 'scheduled',
                'message' => null,
                'reason' => null,
                'ticket_id' => null,
                'scheduled_start_at' => null,
                'started_at' => null,
                'expected_end_at' => null,
                'ended_at' => null,
                'retry_after_seconds' => null,
                'allowed_routes_json' => [],
                'blocked_route_patterns_json' => [],
                'created_by_admin_id' => $tenant['owner_id'],
                'updated_by_admin_id' => $tenant['owner_id'],
            ],
        );

        PartnerTenantMaintenanceEvent::updateOrCreate(
            ['id' => $this->stableId('pme', $tenant['tenant_id'].':seeded')],
            [
                'tenant_id' => $tenant['tenant_id'],
                'maintenance_setting_id' => $this->stableId('pms', $tenant['tenant_id']),
                'event_type' => 'seeded',
                'status' => 'inactive',
                'mode' => 'scheduled',
                'reason' => 'Initial maintenance state from bootstrap seeder.',
                'ticket_id' => null,
                'actor_admin_id' => $tenant['owner_id'],
                'payload_json' => ['source' => 'DemoTenantSeeder'],
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        foreach (array_merge($this->defaultFeatures(), $tenant['features']) as $featureKey => $enabled) {
            PartnerTenantFeatureFlag::updateOrCreate(
                ['tenant_id' => $tenant['tenant_id'], 'feature_key' => $featureKey],
                [
                    'id' => $this->stableId('pff', $tenant['tenant_id'].':'.$featureKey),
                    'enabled' => (bool) $enabled,
                ],
            );
        }
    }

    /**
     * @param array<string, mixed> $tenant
     */
    private function seedRuntimeDefaults(array $tenant, mixed $now): void
    {
        PartnerTenantDeploymentProfile::updateOrCreate(
            ['tenant_id' => $tenant['tenant_id']],
            [
                'id' => $this->stableId('pdp', $tenant['tenant_id']),
                'mode' => 'shared',
                'status' => 'active',
                'runtime_region' => 'local',
                'resource_pool' => 'local',
            ],
        );

        PartnerMonitoringProfile::updateOrCreate(
            ['partner_id' => $tenant['partner_id']],
            [
                'id' => $this->stableId('pmp', $tenant['partner_id']),
                'status' => 'active',
                'health_status' => 'unknown',
            ],
        );

        foreach ($this->defaultUsageMeters() as $meterKey) {
            PartnerUsageMeter::updateOrCreate(
                ['partner_id' => $tenant['partner_id'], 'meter_key' => $meterKey],
                [
                    'id' => $this->stableId('pum', $tenant['partner_id'].':'.$meterKey),
                    'value' => 0,
                    'limit_value' => null,
                    'status' => 'active',
                ],
            );
        }

        foreach ($this->defaultAlertPolicies() as $policyKey => $policy) {
            PartnerAlertPolicy::updateOrCreate(
                ['partner_id' => $tenant['partner_id'], 'policy_key' => $policyKey],
                [
                    'id' => $this->stableId('pap', $tenant['partner_id'].':'.$policyKey),
                    'status' => 'active',
                    'severity' => $policy['severity'],
                    'config_json' => [
                        'metric' => $policy['metric'],
                        'threshold' => $policy['threshold'],
                        'window_seconds' => $policy['window_seconds'],
                        'description' => $policy['description'],
                        'data_source' => $policy['data_source'],
                    ],
                ],
            );
        }

        PartnerHealthCheck::updateOrCreate(
            ['partner_id' => $tenant['partner_id'], 'check_key' => 'site_config'],
            [
                'id' => $this->stableId('phc', $tenant['partner_id'].':site_config'),
                'tenant_id' => $tenant['tenant_id'],
                'health_status' => 'unknown',
                'checked_at' => null,
            ],
        );

        PartnerBillingPlanBinding::updateOrCreate(
            ['partner_id' => $tenant['partner_id']],
            [
                'id' => $this->stableId('pbb', $tenant['partner_id']),
                'billing_plan_code' => 'starter',
                'status' => 'trial',
                'effective_at' => $now,
            ],
        );
    }

    /**
     * @param array<string, mixed> $tenant
     */
    private function seedStarterAffiliateDefaults(array $tenant, mixed $now): void
    {
        $tenantId = (string) $tenant['tenant_id'];
        $tiers = [
            ['bronze', 'Bronze', 1, 100, 30000],
            ['silver', 'Silver', 2, 150, 25000],
            ['gold', 'Gold', 3, 200, 20000],
            ['platinum', 'Platinum', 4, 250, 15000],
            ['diamond', 'Diamond', 5, 300, 10000],
        ];
        foreach ($tiers as [$code, $name, $rank, $commission, $minimumPayout]) {
            $programId = $this->stableId('afp', $tenantId.':'.$code);
            DB::table('affiliate_programs')->insertOrIgnore([
                'id' => $programId,
                'tenant_id' => $tenantId,
                'code' => $code,
                'name' => $name,
                'status' => 'active',
                'tier_rank' => $rank,
                'minimum_payout_amount' => $minimumPayout,
                'commission_per_ticket_amount' => $commission,
                'starts_at' => null,
                'ends_at' => null,
                'metadata_json' => json_encode(['system_tier' => true], JSON_THROW_ON_ERROR),
                'created_by_admin_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('commission_rules')->insertOrIgnore([
                'id' => $this->stableId('cmr', $tenantId.':'.$code.'_per_ticket'),
                'tenant_id' => $tenantId,
                'affiliate_program_id' => $programId,
                'affiliate_account_id' => null,
                'code' => $code.'_per_ticket',
                'name' => $name.' commission per ticket',
                'rule_type' => 'per_ticket',
                'amount' => $commission,
                'rate_bps' => 0,
                'currency' => 'THB',
                'status' => 'active',
                'metadata_json' => json_encode(['system_tier' => true], JSON_THROW_ON_ERROR),
                'created_by_admin_id' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    private function syncRolePermissions(string $roleId, string $scopeType, mixed $now): void
    {
        $permissionIds = Permission::where('scope_type', $scopeType)
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        RolePermission::query()->insertOrIgnore(array_map(fn (string $permissionId): array => [
            'role_id' => $roleId,
            'permission_id' => $permissionId,
            'created_at' => $now,
            'updated_at' => $now,
        ], $permissionIds));
    }

    private function syncRoleMenus(string $roleId, string $scopeType, mixed $now): void
    {
        $menuIds = AdminMenu::where('scope_type', $scopeType)
            ->where('status', 'active')
            ->pluck('id')
            ->all();

        RoleMenu::query()->insertOrIgnore(array_map(fn (string $menuId): array => [
            'role_id' => $roleId,
            'menu_id' => $menuId,
            'created_at' => $now,
            'updated_at' => $now,
        ], $menuIds));
    }

    private function tenantOwnerPassword(): string
    {
        return (string) config('platform.seed.tenant_owner_password');
    }

    private function tenantScopeId(string $tenantId): string
    {
        return 'scp_t_'.substr(sha1($tenantId), 0, 20);
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }

    /**
     * @return array<string, mixed>
     */
    private function forcedPasswordDefaults(): array
    {
        $values = [];

        if (Schema::hasColumn('admin_users', 'must_change_password')) {
            $values['must_change_password'] = true;
        }

        if (Schema::hasColumn('admin_users', 'password_changed_at')) {
            $values['password_changed_at'] = null;
        }

        return $values;
    }

    /**
     * @return array<int, string>
     */
    private function defaultUsageMeters(): array
    {
        return (new ObservabilityCatalog())->defaultUsageMeters();
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    private function defaultAlertPolicies(): array
    {
        return (new ObservabilityCatalog())->defaultAlertPolicies();
    }

    /**
     * @return array<string, bool>
     */
    private function defaultFeatures(): array
    {
        return [
            'affiliate' => false,
            'agent_network' => false,
            'topup_qr' => false,
            'topup_credit' => false,
            'cashback' => false,
            'reward_check' => true,
            'custom_theme' => true,
            'custom_domain' => false,
        ];
    }
}
