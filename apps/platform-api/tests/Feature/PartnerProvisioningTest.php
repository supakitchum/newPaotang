<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use RuntimeException;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class PartnerProvisioningTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_PartnerProvisioning_stock_percent_is_saved_as_partner_base_default(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession([
            'partner.view',
            'partner.create',
            'partner.update',
        ], 'adm_stock_percent', 'stock-percent@example.test');

        $partner = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners', [
                'code' => 'stock_percent_partner',
                'name' => 'Stock Percent Partner',
                'type' => 'partner_store',
                'status' => 'active',
                'stock_percent' => 12.5,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-stock-percent-create',
            ])
            ->assertCreated()
            ->assertJsonPath('stock_percent', 12.5)
            ->assertJsonPath('stock_percent_basis_points', 1250)
            ->json();

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'], [
                'stock_percent' => 22.25,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-stock-percent-update',
            ])
            ->assertOk()
            ->assertJsonPath('stock_percent', 22.25)
            ->assertJsonPath('stock_percent_basis_points', 2225);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/partners?q=stock_percent_partner', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('data.0.id', $partner['id'])
            ->assertJsonPath('data.0.stock_percent', 22.25);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'], [
                'stock_percent' => 101,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-stock-percent-too-high',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.stock_percent.0', 'The stock_percent field must be between 0 and 100.');
    }

    public function test_PartnerProvisioning_central_profile_updates_partner_tenant_domain_settings_theme_and_owner(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession([
            'partner.view',
            'partner.create',
            'partner.update',
            'partner.provision',
        ], 'adm_profile', 'profile-manager@example.test');

        $partner = $this->createPartnerViaApi($login, 'profile_partner', 'Profile Partner');
        $provisioned = $this->provisionViaApi($login, $partner['id'], [
            'tenant_code' => 'profile_partner',
            'tenant_name' => 'Profile Partner',
            'domain_host' => 'profile.example.test',
            'owner_email' => 'owner@profile.test',
            'owner_name' => 'Profile Owner',
            'owner_password' => 'owner-password',
            'site_name' => 'Profile Site',
        ]);
        $tenantId = $provisioned['tenants'][0]['id'];

        $this->assertDatabaseHas('affiliate_programs', [
            'tenant_id' => $tenantId,
            'code' => 'bronze',
            'name' => 'Bronze',
            'status' => 'active',
            'tier_rank' => 1,
            'minimum_payout_amount' => 30000,
            'commission_per_ticket_amount' => 100,
        ]);
        $this->assertDatabaseHas('commission_rules', [
            'tenant_id' => $tenantId,
            'code' => 'bronze_per_ticket',
            'name' => 'Bronze commission per ticket',
            'rule_type' => 'per_ticket',
            'amount' => 100,
            'status' => 'active',
        ]);
        $this->assertSame(5, DB::table('affiliate_programs')
            ->where('tenant_id', $tenantId)
            ->whereNotNull('tier_rank')
            ->where('status', 'active')
            ->count());
        $this->assertDatabaseHas('affiliate_programs', [
            'tenant_id' => $tenantId,
            'code' => 'diamond',
            'tier_rank' => 5,
            'minimum_payout_amount' => 10000,
            'commission_per_ticket_amount' => 300,
        ]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'].'/profile', [
                'section' => 'tenant',
                'tenant' => [
                    'code' => 'profile_tenant',
                    'name' => 'Profile Tenant Updated',
                    'status' => 'maintenance',
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'tenant-profile-update',
            ])
            ->assertOk()
            ->assertJsonPath('tenants.0.code', 'profile_tenant')
            ->assertJsonPath('tenants.0.name', 'Profile Tenant Updated')
            ->assertJsonPath('tenants.0.status', 'maintenance');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'].'/profile', [
                'section' => 'domain',
                'domain' => [
                    'host' => 'profile-updated.example.test',
                    'type' => 'custom_domain',
                    'status' => 'active',
                    'is_primary' => true,
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'domain-profile-update',
            ])
            ->assertOk()
            ->assertJsonPath('domains.0.host', 'profile-updated.example.test')
            ->assertJsonPath('domains.0.type', 'custom_domain')
            ->assertJsonPath('domains.0.status', 'active');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'].'/profile', [
                'section' => 'domain',
                'domain' => [
                    'host' => 'พบโชค.localhost',
                    'type' => 'custom_domain',
                    'status' => 'active',
                    'is_primary' => true,
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'domain-profile-idn-update',
            ])
            ->assertOk()
            ->assertJsonPath('domains.0.host', 'xn--42cl1cp5p.localhost');

        $this->assertDatabaseHas('partner_tenant_domains', [
            'tenant_id' => $tenantId,
            'host' => 'xn--42cl1cp5p.localhost',
        ]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'].'/profile', [
                'section' => 'settings',
                'settings' => [
                    'site' => [
                        'site_name' => 'Profile Shop',
                        'display_name' => 'Profile Shop BO',
                        'support_email' => 'support@profile.test',
                        'support_url' => 'https://support.profile.test/help',
                        'lottery_product_label' => 'L6 Profile',
                        'ticket_image_watermark' => 'Profile Lottery Office',
                    ],
                    'seo' => [
                        'default_title' => 'Profile SEO',
                        'default_keywords' => ['vip', 'lottery'],
                    ],
                    'maintenance' => [
                        'active' => true,
                        'mode' => 'read_only',
                        'message' => 'Read only window',
                    ],
                    'api' => [
                        'asset_cdn_base_url' => 'https://cdn.profile.test',
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'settings-profile-update',
            ])
            ->assertOk()
            ->assertJsonPath('tenant_settings.site.site_name', 'Profile Shop')
            ->assertJsonPath('tenant_settings.site.display_name', 'Profile Shop BO')
            ->assertJsonPath('tenant_settings.site.support_url', 'https://support.profile.test/help')
            ->assertJsonPath('tenant_settings.site.lottery_product_label', 'L6 Profile')
            ->assertJsonPath('tenant_settings.site.ticket_image_watermark', 'Profile Lottery Office')
            ->assertJsonPath('tenant_settings.seo.default_keywords', ['lottery', 'vip'])
            ->assertJsonPath('tenant_settings.maintenance.active', true)
            ->assertJsonPath('tenant_settings.api.asset_cdn_base_url', 'https://cdn.profile.test');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'].'/profile', [
                'section' => 'theme',
                'theme' => [
                    'brand' => [
                        'logo_url' => 'https://cdn.profile.test/logo.webp',
                        'favicon_url' => 'https://cdn.profile.test/favicon.webp',
                    ],
                    'theme' => [
                        'primary_color' => '#123ABC',
                        'secondary_color' => '#456DEF',
                        'accent_color' => '#F59E0B',
                        'background_color' => '#FFFFFF',
                        'text_color' => '#111827',
                        'font_family' => 'Prompt, sans-serif',
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'theme-profile-update',
            ])
            ->assertOk()
            ->assertJsonPath('tenant_theme.brand.logo_url', 'https://cdn.profile.test/logo.webp')
            ->assertJsonPath('tenant_theme.theme.primary_color', '#123ABC');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/partners/'.$partner['id'].'/profile', [
                'section' => 'owner',
                'owner' => [
                    'owner_email' => 'new-owner@profile.test',
                    'owner_name' => 'Profile Owner Updated',
                    'owner_password' => 'new-owner-password',
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'owner-profile-update',
            ])
            ->assertOk()
            ->assertJsonPath('owner_admin.email', 'new-owner@profile.test')
            ->assertJsonPath('owner_admin.name', 'Profile Owner Updated');

        $this->assertDatabaseHas('partner_tenants', [
            'id' => $tenantId,
            'code' => 'profile_tenant',
            'name' => 'Profile Tenant Updated',
            'status' => 'maintenance',
        ]);
        $this->assertDatabaseHas('partner_tenant_domains', [
            'tenant_id' => $tenantId,
            'host' => 'xn--42cl1cp5p.localhost',
            'type' => 'custom_domain',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('partner_tenant_settings', [
            'tenant_id' => $tenantId,
            'site_name' => 'Profile Shop',
            'support_email' => 'support@profile.test',
        ]);
        $this->assertDatabaseHas('partner_tenant_themes', [
            'tenant_id' => $tenantId,
            'logo_url' => 'https://cdn.profile.test/logo.webp',
            'primary_color' => '#123ABC',
        ]);
    }

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
                'stock_percent' => 12.5,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-create-acme',
            ])
            ->assertCreated()
            ->assertJsonPath('code', 'acme_partner')
            ->assertJsonPath('status', 'draft')
            ->assertJsonPath('stock_percent', 12.5)
            ->assertJsonPath('stock_percent_basis_points', 1250)
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
                'stock_percent' => 22.25,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-update-acme',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Acme Partner Updated')
            ->assertJsonPath('stock_percent', 22.25)
            ->assertJsonPath('stock_percent_basis_points', 2225);

        $this->assertDatabaseHas('partners', [
            'id' => $partner['id'],
            'stock_percent_basis_points' => 2225,
        ]);

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
        $this->acceptOwnerInvitation($provisioned, 'owner-password', 'accept-acme-owner');

        $this->assertDatabaseHas('partner_tenant_themes', [
            'tenant_id' => $tenantId,
            'primary_color' => '#087FF0',
            'secondary_color' => '#19B8EF',
            'accent_color' => '#FFD10B',
            'text_color' => '#242833',
            'font_family' => 'Kanit',
        ]);

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
            ->assertJsonPath('error.code', 'admin_session_replaced');

        $this->withToken($ownerThemeLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/theme', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
            ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'admin_session_replaced');

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
            ->assertJsonPath('tenants.0.name', 'Acme Partner Suspended')
            ->assertJsonPath('status', 'suspended');

        $this->assertDatabaseHas('partner_tenants', [
            'id' => $tenantId,
            'name' => 'Acme Partner Suspended',
        ]);

        $this->getJson('http://acme.example.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.status', 'suspended')
            ->assertJsonPath('data.domain.status', 'suspended')
            ->assertJsonPath('data.maintenance.active', true)
            ->assertJsonPath('data.maintenance.mode', 'customer_web_only')
            ->assertJsonPath('data.maintenance.message', 'ขณะนี้ระบบปิดให้บริการชั่วคราว กรุณากลับมาใหม่ภายหลัง');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/unsuspend', [
                'reason' => 'contract restored',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'partner-unsuspend-acme',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('tenants.0.status', 'active')
            ->assertJsonPath('domains.0.status', 'active');

        $this->assertDatabaseHas('partner_tenants', ['id' => $tenantId, 'status' => 'active']);
        $this->assertDatabaseHas('partner_tenant_domains', ['tenant_id' => $tenantId, 'status' => 'active']);
        $this->assertDatabaseHas('partner_billing_plan_bindings', ['partner_id' => $partner['id'], 'status' => 'active']);

        $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@acme.test',
            'password' => 'owner-password',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertOk()
            ->assertJsonStructure(['access_token', 'refresh_token']);
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
            'support_url' => 'https://support.site.example.test/lottery',
            'lottery_product_label' => '  L6 Site  ',
            'ticket_image_watermark' => '  Site Lottery Office  ',
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
            ->assertJsonPath('data.site.support_url', 'https://support.site.example.test/lottery')
            ->assertJsonPath('data.site.lottery_product_label', 'L6 Site')
            ->assertJsonPath('data.site.ticket_image_watermark', 'Site Lottery Office')
            ->assertJsonPath('data.legal.terms_content', implode("\n", [
                'ข้อตกลงการใช้งาน',
                '1. Site Luckyเป็นระบบจำหน่ายลอตเตอรี่ออนไลน์',
                '2. บริษัทไม่สนับสนุนการจำหน่ายสลากให้กับบุคคลที่มีอายุไม่ถึง 20 ปี',
                '3. บริษัทสนับสนุนผู้ไม่มีรายได้ ผู้พิการ ในการเป็นตัวแทนจำหน่ายลอตเตอรี่ออนไลน์',
                '4. บริษัทเก็บรักษาสลากที่ลูกค้าซื้อเพื่อความปลอดภัย รวมถึงการขึ้นรางวัลให้กับลูกค้า',
                '5. หากผู้ซื้อนำรูปภาพสลากหรือสลากจริงไปขายต่อ ทางบริษัทไม่มีส่วนเกี่ยวข้องและไม่รับผิดชอบความเสียหายในทุกกรณี',
                '6. หลังจาก ทำรายการ และ กดปุ่ม " ชำระเงิน " ทางบริษัทถือว่า ผู้สั่งซื้อได้รับทราบ ข้อตกลงและเงื่อนไขต่างๆของบริษัทเป็นที่เรียบร้อย',
                '7. บริษัทขอสงวนสิทธิ์ ขึ้นเงินรางวัลให้ลูกค้าที่ซื้อกับระบบ ในกรณีลูกค้าถูกรางวัล โดยไม่มีค่าใช้จ่ายใดๆ ทั้งสิ้น',
                '8. ลูกค้าสามารถยกเลิกการสั่งซื้อสลากได้ภายใน 15 นาทีทุกกรณี หากเกินระยะเวลาที่กำหนด บริษัทขอสงวนสิทธิ์ไม่คืนเงินค่าสลากทุกกรณี',
            ]))
            ->assertJsonPath('data.legal.privacy_content', implode("\n", [
                'นโยบายความเป็นส่วนตัว',
                '1. Site Lucky ใช้ข้อมูลส่วนบุคคลเพื่อให้บริการซื้อสลาก เติมเงิน รับเงินรางวัล และแจ้งเตือนรายการ',
                '2. ระบบเก็บข้อมูลเท่าที่จำเป็นตามกฎหมายและมาตรฐานความปลอดภัย',
                '3. ลูกค้าสามารถติดต่อร้านค้าเพื่อขอแก้ไข ส่งออก หรือลบข้อมูลบัญชีได้',
                '4. การลบบัญชีอาจยังต้องเก็บข้อมูลธุรกรรมที่กฎหมายกำหนดไว้',
            ]))
            ->assertJsonPath('data.legal.privacy_policy_url', '')
            ->assertJsonPath('data.legal.account_deletion_url', '')
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

        $this->getJson('http://site.example.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->assertJsonPath('data.mobile.lottery_product_label', 'L6 Site')
            ->assertJsonPath('data.mobile.ticket_image_watermark', 'Site Lottery Office');

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
            ->assertJsonPath('user.must_change_password', false)
            ->json();

        $this->withToken($ownerLogin['access_token'])
            ->postJson('/api/v1/auth/admin/password/change', [
                'current_password' => 'owner-password',
                'new_password' => 'owner-password-updated',
                'new_password_confirmation' => 'owner-password-updated',
            ], ['Idempotency-Key' => 'settings-owner-force-change'])
            ->assertNoContent();

        $ownerLogin = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'owner@settings-one.test',
            'password' => 'owner-password-updated',
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
        ])
            ->assertOk()
            ->assertJsonPath('user.must_change_password', false)
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
                    'support_url' => 'http://support.settings-one.test',
                ],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
                'Idempotency-Key' => 'settings-support-url-invalid',
            ])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.support_url.0',
                'The support_url field must be a valid HTTPS URL.',
            );

        $this->withToken($ownerLogin['access_token'])
            ->patchJson('/api/v1/admin/tenant/settings', [
                'site' => [
                    'site_name' => 'Settings One Updated',
                    'support_email' => 'support@settings-one.test',
                    'support_url' => 'https://support.settings-one.test/help',
                    'lottery_product_label' => 'L6 Settings',
                    'ticket_image_watermark' => 'Settings Lottery Office',
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
                'legal' => [
                    'terms_content' => 'Custom terms for Settings One',
                    'privacy_content' => 'Custom privacy for Settings One',
                    'privacy_content_i18n' => [
                        'en-US' => 'Custom privacy in English',
                    ],
                    'privacy_policy_url' => 'https://settings-one.example.test/privacy',
                    'account_deletion_url' => 'https://settings-one.example.test/account/delete',
                ],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $tenantId,
                'Idempotency-Key' => 'settings-update',
            ])
            ->assertOk()
            ->assertJsonPath('site.site_name', 'Settings One Updated')
            ->assertJsonPath('site.support_email', 'support@settings-one.test')
            ->assertJsonPath('site.support_url', 'https://support.settings-one.test/help')
            ->assertJsonPath('site.lottery_product_label', 'L6 Settings')
            ->assertJsonPath('site.ticket_image_watermark', 'Settings Lottery Office')
            ->assertJsonPath('seo.default_keywords', ['lottery', 'lucky'])
            ->assertJsonPath('maintenance.active', true)
            ->assertJsonPath('api.base_url', 'https://api.settings-one.test/api/v1')
            ->assertJsonPath('legal.terms_content', 'Custom terms for Settings One')
            ->assertJsonPath('legal.privacy_content', 'Custom privacy in English')
            ->assertJsonPath('legal.privacy_content_i18n.en-US', 'Custom privacy in English')
            ->assertJsonPath('legal.privacy_policy_url', 'https://settings-one.example.test/privacy')
            ->assertJsonPath('legal.account_deletion_url', 'https://settings-one.example.test/account/delete');

        $this->getJson('http://settings-one.example.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.site.support_url', 'https://support.settings-one.test/help')
            ->assertJsonPath('data.site.lottery_product_label', 'L6 Settings')
            ->assertJsonPath('data.site.ticket_image_watermark', 'Settings Lottery Office')
            ->assertJsonPath('data.legal.terms_content', 'Custom terms for Settings One')
            ->assertJsonPath('data.legal.privacy_content', 'Custom privacy in English')
            ->assertJsonPath('data.legal.privacy_policy_url', 'https://settings-one.example.test/privacy')
            ->assertJsonPath('data.legal.account_deletion_url', 'https://settings-one.example.test/account/delete');

        $mobileBootstrap = $this->getJson('http://settings-one.example.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->assertJsonPath('data.site.support_url', 'https://support.settings-one.test/help')
            ->assertJsonPath('data.mobile.lottery_product_label', 'L6 Settings')
            ->assertJsonPath('data.mobile.ticket_image_watermark', 'Settings Lottery Office')
            ->assertJsonPath('data.legal.privacy_content', 'Custom privacy in English')
            ->assertJsonPath('data.legal.privacy_policy_url', 'https://settings-one.example.test/privacy')
            ->assertJsonPath('data.legal.account_deletion_url', 'https://settings-one.example.test/account/delete')
            ->json();

        $this->assertContains(
            '/profile/account-deletion',
            data_get($mobileBootstrap, 'data.mobile.screen_security.sensitive_routes', []),
        );

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

    public function test_PartnerProvisioning_rejects_second_tenant_for_partner(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['partner.create', 'partner.provision']);
        $partner = $this->createPartnerViaApi($login, 'one_tenant_partner', 'One Tenant Partner');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/provision', [
                'tenant_id' => 'ten_one_tenant_first',
                'tenant_code' => 'one_tenant_first',
                'tenant_name' => 'One Tenant First',
                'domain_host' => 'one-tenant-first.example.test',
                'owner_email' => 'owner@one-tenant-first.test',
                'owner_password' => 'owner-password',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'one-tenant-first',
            ])
            ->assertAccepted();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partner['id'].'/provision', [
                'tenant_id' => 'ten_one_tenant_second',
                'tenant_code' => 'one_tenant_second',
                'tenant_name' => 'One Tenant Second',
                'domain_host' => 'one-tenant-second.example.test',
                'owner_email' => 'owner@one-tenant-second.test',
                'owner_password' => 'owner-password',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'one-tenant-second',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');

        $this->assertSame(1, DB::table('partner_tenants')->where('partner_id', $partner['id'])->count());
    }

    public function test_partner_tenant_partner_id_migration_guard_reports_duplicates(): void
    {
        Schema::table('partner_tenants', function (Blueprint $table): void {
            $table->dropUnique('partner_tenants_partner_id_unique');
        });

        DB::table('partners')->insert([
            'id' => 'par_duplicate_tenants',
            'code' => 'duplicate_tenants',
            'name' => 'Duplicate Tenants',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            [
                'id' => 'ten_duplicate_one',
                'partner_id' => 'par_duplicate_tenants',
                'code' => 'duplicate_one',
                'name' => 'Duplicate One',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'ten_duplicate_two',
                'partner_id' => 'par_duplicate_tenants',
                'code' => 'duplicate_two',
                'name' => 'Duplicate Two',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        $migration = include database_path('migrations/2026_05_21_000001_guard_partner_tenants_one_tenant_per_partner.php');

        $this->expectException(RuntimeException::class);
        $this->expectExceptionMessage('par_duplicate_tenants (2)');

        $migration->up();
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
        $response = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/partners/'.$partnerId.'/provision', $payload, [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'provision-'.$payload['tenant_code'],
            ])
            ->assertAccepted()
            ->json();

        if (isset($payload['owner_password'])) {
            $this->acceptOwnerInvitation(
                $response,
                (string) $payload['owner_password'],
                'accept-'.$payload['tenant_code'].'-owner',
            );
        }

        return $response;
    }

    /**
     * @param array<string, mixed> $response
     */
    private function acceptOwnerInvitation(array $response, string $password, string $idempotencyKey): void
    {
        if (! isset($response['invitation']['path'])) {
            return;
        }

        $query = parse_url((string) $response['invitation']['path'], PHP_URL_QUERY);
        parse_str(is_string($query) ? $query : '', $parameters);
        $token = (string) ($parameters['token'] ?? '');

        $this->postJson('/api/v1/auth/admin/invitations/'.rawurlencode($token).'/accept', [
            'password' => $password,
            'password_confirmation' => $password,
        ], [
            'Idempotency-Key' => $idempotencyKey,
        ])->assertOk();
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
