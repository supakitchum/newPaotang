<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class PartnerProvisioningTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_PartnerProvisioning_central_admin_can_create_provision_idempotently_login_owner_and_suspend(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession([
            'partner.view',
            'partner.create',
            'partner.update',
            'partner.provision',
            'partner.suspend',
        ]);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners', [
                'code' => 'acme_partner',
                'name' => 'Acme Partner',
                'type' => 'white_label',
                'status' => 'draft',
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $partner = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners', [
                'code' => 'acme_partner',
                'name' => 'Acme Partner',
                'type' => 'white_label',
                'status' => 'draft',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-create-acme',
            ])
            ->assertCreated()
            ->assertJsonPath('code', 'acme_partner')
            ->assertJsonPath('status', 'draft')
            ->json();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners', [
                'code' => 'acme_partner',
                'name' => 'Acme Duplicate',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-create-acme-2',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'], [
                'name' => 'Acme Partner Updated',
                'status' => 'draft',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-update-acme',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Acme Partner Updated');

        $provisionPayload = [
            'tenant_code' => 'acme_tenant',
            'tenant_name' => 'Acme Tenant',
            'domain_host' => 'acme.example.test',
            'domain_type' => 'custom_domain',
            'owner_email' => 'owner@acme.test',
            'owner_name' => 'Acme Owner',
            'owner_password' => 'owner-password',
            'site_name' => 'Acme Lucky Shop',
            'features' => [
                'affiliate' => true,
                'custom_domain' => true,
            ],
        ];

        $provisioned = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/provision', $provisionPayload, [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-provision-acme',
            ])
            ->assertAccepted()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('tenants.0.code', 'acme_tenant')
            ->assertJsonPath('domains.0.host', 'acme.example.test')
            ->json();

        $tenantId = $provisioned['tenants'][0]['id'];

        $counts = $this->provisioningCounts($partner['id'], $tenantId);

        $secondProvision = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/provision', $provisionPayload, [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-provision-acme-repeat',
            ])
            ->assertAccepted()
            ->json();

        $this->assertSame($tenantId, $secondProvision['tenants'][0]['id']);
        $this->assertSame($counts, $this->provisioningCounts($partner['id'], $tenantId));

        $ownerLogin = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@acme.test',
            'password' => 'owner-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertOk()
            ->json();

        $this->withToken($ownerLogin['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertOk()
            ->assertJsonPath('active_scope', 'tenant')
            ->assertJsonPath('active_tenant_id', $tenantId);

        $ownerThemeLogin = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@acme.test',
            'password' => 'owner-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertOk()
            ->json();

        $ownerRefreshLogin = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@acme.test',
            'password' => 'owner-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertOk()
            ->json();

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('action', 'partner.provisioned')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['owner_password']);
        $this->assertStringNotContainsString('owner-password', json_encode($auditPayload, JSON_THROW_ON_ERROR));

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/suspend', [
                'reason' => 'contract ended',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-suspend-acme',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'suspended')
            ->assertJsonPath('tenants.0.status', 'suspended')
            ->assertJsonPath('domains.0.status', 'suspended');

        $this->assertDatabaseHas('partner_tenants', ['id' => $tenantId, 'status' => 'suspended']);
        $this->assertDatabaseHas('partner_tenant_domains', ['tenant_id' => $tenantId, 'status' => 'suspended']);
        $this->assertDatabaseHas('partner_billing_plan_bindings', ['partner_id' => $partner['id'], 'status' => 'suspended']);

        $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@acme.test',
            'password' => 'owner-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->withToken($ownerLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/settings', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
            ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->withToken($ownerThemeLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/theme', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
            ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->postJson('/api/v1/auth/admin/refresh', [
            'refresh_token' => $ownerRefreshLogin['refresh_token'],
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partners/'.$partner['id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('id', $partner['id'])
            ->assertJsonPath('status', 'suspended');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'], [
                'name' => 'Acme Partner Suspended',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-update-after-suspend',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Acme Partner Suspended')
            ->assertJsonPath('status', 'suspended');

        $this->getJson('http://acme.example.test/api/v1/public/site-config')
            ->assertConflict()
            ->assertJsonPath('error.code', 'domain_not_active');
    }

    public function test_PartnerApiClient_management_is_permissioned_and_never_returns_secret_material(): void
    {
        $this->seedDefaultRbac();
        $this->insertPartner('par_api', 'api_partner');

        $limitedLogin = $this->createCentralSession(['partner.view'], 'adm_limited', 'limited@example.test');

        $this->withToken($limitedLogin['access_token'])
            ->getJson('/api/v1/admin/central/partner-api-clients', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $login = $this->createCentralSession(['partner.api.manage'], 'adm_api', 'api-manager@example.test');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partner-api-clients', [
                'partner_id' => 'par_api',
                'name' => 'Main Integration',
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $created = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partner-api-clients', [
                'partner_id' => 'par_api',
                'name' => 'Main Integration',
                'scopes' => ['orders.read', 'stock.write'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'api-client-create',
            ])
            ->assertCreated()
            ->assertJsonPath('partner_id', 'par_api')
            ->assertJsonPath('status', 'active')
            ->assertJsonMissingPath('secret')
            ->assertJsonMissingPath('secret_hash')
            ->json();

        $this->assertStringNotContainsString('secret', json_encode($created, JSON_THROW_ON_ERROR));
        $this->assertDatabaseHas('partner_api_clients', [
            'id' => $created['id'],
            'partner_id' => 'par_api',
            'status' => 'active',
        ]);
        $this->assertNotNull(DB::table('partner_api_clients')->where('id', $created['id'])->value('secret_hash'));

        $list = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partner-api-clients?partner_id=par_api', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->json('data');

        $this->assertCount(1, $list);
        $this->assertArrayNotHasKey('secret_hash', $list[0]);
        $this->assertArrayNotHasKey('secret', $list[0]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partner-api-clients/'.$created['id'], [
                'name' => 'Main Integration Suspended',
                'status' => 'suspended',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'api-client-update',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'suspended')
            ->assertJsonPath('name', 'Main Integration Suspended');

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/central/partner-api-clients/'.$created['id'], [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'api-client-delete',
            ])
            ->assertNoContent();

        $this->assertDatabaseHas('partner_api_clients', [
            'id' => $created['id'],
            'status' => 'revoked',
        ]);
        $this->assertNotNull(DB::table('partner_api_clients')->where('id', $created['id'])->value('revoked_at'));
    }

    public function test_SiteConfig_resolves_host_returns_openapi_shape_maintenance_and_safe_errors(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['partner.create', 'partner.provision']);
        $partner = $this->createPartnerViaApi($login, 'site_partner', 'Site Partner');

        $provisioned = $this->provisionViaApi($login, $partner['id'], [
            'tenant_code' => 'site_tenant',
            'tenant_name' => 'Site Tenant',
            'domain_host' => 'site.example.test',
            'owner_email' => 'owner@site.test',
            'owner_password' => 'owner-password',
            'site_name' => 'Site Lucky',
            'primary_color' => '#123456',
            'features' => ['affiliate' => true],
        ]);
        $tenantId = $provisioned['tenants'][0]['id'];

        $this->getJson('http://site.example.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.partner_id', $partner['id'])
            ->assertJsonPath('data.tenant_id', $tenantId)
            ->assertJsonPath('data.status', 'active')
            ->assertJsonPath('data.site.site_name', 'Site Lucky')
            ->assertJsonPath('data.domain.host', 'site.example.test')
            ->assertJsonPath('data.theme.primary_color', '#123456')
            ->assertJsonPath('data.features.affiliate', true)
            ->assertJsonStructure([
                'data' => [
                    'partner_id',
                    'tenant_id',
                    'status',
                    'site' => ['site_name', 'timezone'],
                    'domain' => ['host', 'canonical_url', 'type', 'status', 'https_required', 'cloudflare_proxy_required'],
                    'brand',
                    'theme',
                    'features',
                    'seo' => ['default_title', 'canonical_base_url', 'robots_default'],
                    'maintenance' => ['active'],
                    'api',
                    'timestamps',
                ],
            ]);

        DB::table('partner_tenants')->where('id', $tenantId)->update(['status' => 'maintenance', 'updated_at' => now()]);

        $this->getJson('http://site.example.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.status', 'maintenance')
            ->assertJsonPath('data.maintenance.active', true);

        $this->getJson('http://missing.example.test/api/v1/public/site-config')
            ->assertNotFound()
            ->assertJsonPath('error.code', 'tenant_not_found');

        DB::table('partner_tenants')->where('id', $tenantId)->update(['status' => 'active', 'updated_at' => now()]);
        DB::table('partner_tenant_domains')->where('tenant_id', $tenantId)->update(['status' => 'suspended', 'updated_at' => now()]);

        $this->getJson('http://site.example.test/api/v1/public/site-config')
            ->assertConflict()
            ->assertJsonPath('error.code', 'domain_not_active');
    }

    public function test_TenantSettings_theme_read_update_are_permissioned_and_tenant_scoped(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession(['partner.create', 'partner.provision']);
        $firstPartner = $this->createPartnerViaApi($centralLogin, 'tenant_settings_one', 'Tenant Settings One');
        $secondPartner = $this->createPartnerViaApi($centralLogin, 'tenant_settings_two', 'Tenant Settings Two');
        $firstProvision = $this->provisionViaApi($centralLogin, $firstPartner['id'], [
            'tenant_code' => 'tenant_settings_one',
            'tenant_name' => 'Tenant Settings One',
            'domain_host' => 'settings-one.example.test',
            'owner_email' => 'owner@settings-one.test',
            'owner_password' => 'owner-password',
            'site_name' => 'Settings One',
        ]);
        $secondProvision = $this->provisionViaApi($centralLogin, $secondPartner['id'], [
            'tenant_code' => 'tenant_settings_two',
            'tenant_name' => 'Tenant Settings Two',
            'domain_host' => 'settings-two.example.test',
            'owner_email' => 'owner@settings-two.test',
            'owner_password' => 'owner-password',
            'site_name' => 'Settings Two',
        ]);
        $tenantId = $firstProvision['tenants'][0]['id'];
        $otherTenantId = $secondProvision['tenants'][0]['id'];

        $ownerLogin = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@settings-one.test',
            'password' => 'owner-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertOk()
            ->json();

        $this->withToken($ownerLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/settings', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
            ])
            ->assertOk()
            ->assertJsonPath('tenant_id', $tenantId)
            ->assertJsonPath('site.site_name', 'Settings One');

        $this->withToken($ownerLogin['access_token'])
            ->patchJson('/api/v1/admin/tenant/settings', [
                'tenant_id' => $otherTenantId,
                'site' => ['site_name' => 'Wrong Tenant'],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
                'Idempotency-Key' => 'settings-tamper',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.tenant_id.0', 'The tenant_id field must match the selected tenant.');

        $this->withToken($ownerLogin['access_token'])
            ->patchJson('/api/v1/admin/tenant/settings', [
                'site' => [
                    'site_name' => 'Settings One Updated',
                    'support_email' => 'support@settings-one.test',
                ],
                'seo' => [
                    'default_title' => 'Settings One SEO',
                    'default_keywords' => ['lottery', 'lucky'],
                ],
                'maintenance' => [
                    'active' => true,
                    'mode' => 'read_only',
                    'allowed_routes' => ['/'],
                ],
                'api' => [
                    'base_url' => 'https://api.settings-one.test/api/v1',
                ],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
                'Idempotency-Key' => 'settings-update',
            ])
            ->assertOk()
            ->assertJsonPath('site.site_name', 'Settings One Updated')
            ->assertJsonPath('site.support_email', 'support@settings-one.test')
            ->assertJsonPath('seo.default_keywords', ['lottery', 'lucky'])
            ->assertJsonPath('maintenance.active', true)
            ->assertJsonPath('api.base_url', 'https://api.settings-one.test/api/v1');

        $this->assertDatabaseHas('partner_tenant_settings', [
            'tenant_id' => $otherTenantId,
            'site_name' => 'Settings Two',
        ]);

        $this->withToken($ownerLogin['access_token'])
            ->patchJson('/api/v1/admin/tenant/theme', [
                'brand' => [
                    'logo_url' => 'https://cdn.settings-one.test/logo.png',
                ],
                'theme' => [
                    'primary_color' => '#ABCDEF',
                    'font_family' => 'Inter, sans-serif',
                ],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
                'Idempotency-Key' => 'theme-update',
            ])
            ->assertOk()
            ->assertJsonPath('brand.logo_url', 'https://cdn.settings-one.test/logo.png')
            ->assertJsonPath('theme.primary_color', '#ABCDEF');

        $this->withToken($ownerLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/theme', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $otherTenantId,
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $auditPayload = json_decode((string) DB::table('audit_logs')
            ->where('action', 'settings.changed')
            ->where('target_type', 'tenant_theme')
            ->value('payload_redacted_json'), true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('theme.updated', $auditPayload['change_type']);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createCentralSession(
        array $permissions,
        string $adminId = 'adm_central',
        string $email = 'central@example.test',
    ): array {
        $this->createAdmin($adminId, $email);
        $this->createAdminScope('scp_'.$adminId, 'central');
        $this->assignRoleWithPermissions($adminId, 'scp_'.$adminId, 'central', null, $permissions, 'central_'.$adminId);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    private function insertPartner(string $partnerId, string $code): void
    {
        DB::table('partners')->insert([
            'id' => $partnerId,
            'code' => $code,
            'name' => 'Partner '.$code,
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<string, mixed> $login
     * @return array<string, mixed>
     */
    private function createPartnerViaApi(array $login, string $code, string $name): array
    {
        return $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners', [
                'code' => $code,
                'name' => $name,
                'type' => 'white_label',
                'status' => 'draft',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'create-'.$code,
            ])
            ->assertCreated()
            ->json();
    }

    /**
     * @param array<string, mixed> $login
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function provisionViaApi(array $login, string $partnerId, array $payload): array
    {
        return $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partnerId.'/provision', $payload, [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'provision-'.$payload['tenant_code'],
            ])
            ->assertAccepted()
            ->json();
    }

    /**
     * @return array<string, int>
     */
    private function provisioningCounts(string $partnerId, string $tenantId): array
    {
        return [
            'tenants' => DB::table('partner_tenants')->where('partner_id', $partnerId)->count(),
            'domains' => DB::table('partner_tenant_domains')->where('partner_id', $partnerId)->count(),
            'settings' => DB::table('partner_tenant_settings')->where('tenant_id', $tenantId)->count(),
            'themes' => DB::table('partner_tenant_themes')->where('tenant_id', $tenantId)->count(),
            'features' => DB::table('partner_tenant_feature_flags')->where('tenant_id', $tenantId)->count(),
            'deployment_profiles' => DB::table('partner_tenant_deployment_profiles')->where('tenant_id', $tenantId)->count(),
            'monitoring_profiles' => DB::table('partner_monitoring_profiles')->where('partner_id', $partnerId)->count(),
            'usage_meters' => DB::table('partner_usage_meters')->where('partner_id', $partnerId)->count(),
            'alert_policies' => DB::table('partner_alert_policies')->where('partner_id', $partnerId)->count(),
            'health_checks' => DB::table('partner_health_checks')->where('partner_id', $partnerId)->count(),
            'billing_bindings' => DB::table('partner_billing_plan_bindings')->where('partner_id', $partnerId)->count(),
        ];
    }
}
