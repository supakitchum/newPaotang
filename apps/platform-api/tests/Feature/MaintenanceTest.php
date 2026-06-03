<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class MaintenanceTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_Maintenance_admin_updates_site_config_blocks_by_mode_and_keeps_tenant_isolation(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_a', 'ten_m9_a', 'm9-a.test');
        $this->insertActivePartnerTenantWithDomain('par_m9_b', 'ten_m9_b', 'm9-b.test');
        $this->insertGame('gam_m9_mode', 'open');
        $customerToken = $this->issueCustomerToken('ten_m9_a', 'cus_m9_a');
        $admin = $this->createTenantSession('ten_m9_a', 'par_m9_a', [
            'maintenance.view',
            'maintenance.update',
            'maintenance.schedule',
            'maintenance.bypass',
        ], 'adm_m9_maintenance', 'm9-maintenance@example.test');

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'active',
                'mode' => 'checkout_payment_only',
                'reason' => 'Payment provider maintenance',
                'ticket_id' => 'SUP-M9-1',
                'message' => 'Payments are temporarily unavailable.',
                'retry_after_seconds' => 300,
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
                'Idempotency-Key' => 'm9-maintenance-checkout',
                'X-Request-Id' => 'req-m9-maintenance-checkout',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('mode', 'checkout_payment_only')
            ->assertJsonPath('active', true);

        $this->getJson('http://m9-a.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.maintenance.active', true)
            ->assertJsonPath('data.maintenance.mode', 'checkout_payment_only');

        $this->getJson('http://m9-b.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.maintenance.active', false);

        $this->getJson('http://m9-a.test/api/v1/public/stock/search?game_id=gam_m9_mode')
            ->assertOk();

        $this->withToken($customerToken)
            ->postJson('http://m9-a.test/api/v1/customer/topups', [
                'amount' => 10000,
                'channel' => 'manual',
            ], [
                'Idempotency-Key' => 'm9-topup-blocked',
            ])
            ->assertStatus(503)
            ->assertHeader('Retry-After', '300')
            ->assertJsonPath('error.code', 'maintenance_active');

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'active',
                'mode' => 'full_site',
                'reason' => 'Full site maintenance',
                'message' => 'Maintenance in progress.',
                'retry_after_seconds' => 120,
                'allowed_routes' => ['/api/v1/public/stock/search'],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
                'Idempotency-Key' => 'm9-maintenance-full',
                'X-Request-Id' => 'req-m9-maintenance-full',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'full_site');

        $this->getJson('http://m9-a.test/api/v1/public/stock/search?game_id=gam_m9_mode')
            ->assertOk();

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'active',
                'mode' => 'full_site',
                'reason' => 'Block full site maintenance',
                'message' => 'Maintenance in progress.',
                'retry_after_seconds' => 120,
                'allowed_routes' => [],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
                'Idempotency-Key' => 'm9-maintenance-full-block',
                'X-Request-Id' => 'req-m9-maintenance-full-block',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'full_site');

        $this->getJson('http://m9-a.test/api/v1/public/stock/search?game_id=gam_m9_mode')
            ->assertStatus(503)
            ->assertHeader('Retry-After', '120')
            ->assertJsonPath('error.code', 'maintenance_active');

        $bypass = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/maintenance/bypasses', [
                'actor_type' => 'customer',
                'actor_id' => 'cus_m9_a',
                'reason' => 'Allow support verification during maintenance',
                'ticket_id' => 'SUP-M9-2',
                'expires_at' => now()->addHour()->toISOString(),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
                'Idempotency-Key' => 'm9-maintenance-bypass',
            ])
            ->assertCreated()
            ->assertJsonPath('actor_id', 'cus_m9_a')
            ->json();

        DB::table('partner_tenant_maintenance_bypasses')->insert([
            'id' => 'byp_other_tenant',
            'tenant_id' => 'ten_m9_b',
            'bypass_type' => 'actor',
            'actor_type' => 'customer',
            'actor_id' => 'cus_m9_b',
            'support_impersonation_session_id' => null,
            'status' => 'active',
            'reason' => 'Other tenant bypass must not leak',
            'ticket_id' => 'SUP-M9-OTHER',
            'expires_at' => now()->addHour(),
            'revoked_at' => null,
            'created_by_admin_id' => 'adm_m9_maintenance',
            'revoked_by_admin_id' => null,
            'metadata_json' => json_encode(['token' => 'must-not-return'], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $bypasses = $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/maintenance/bypasses?status=active&limit=10', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $bypass['id'])
            ->assertJsonPath('data.0.actor_id', 'cus_m9_a')
            ->assertJsonPath('data.0.effective_status', 'active')
            ->assertJsonPath('data.0.is_currently_active', true)
            ->assertJsonPath('meta.has_more', false)
            ->json();

        $encodedBypasses = json_encode($bypasses, JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString('cus_m9_b', $encodedBypasses);
        $this->assertStringNotContainsString('must-not-return', $encodedBypasses);
        $this->assertStringNotContainsString('Bearer ', $encodedBypasses);

        $this->withToken($customerToken)
            ->getJson('http://m9-a.test/api/v1/customer/wallet')
            ->assertOk();

        $this->withToken($admin['access_token'])
            ->deleteJson('/api/v1/admin/tenant/maintenance/bypasses/'.$bypass['id'], [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
                'Idempotency-Key' => 'm9-maintenance-bypass-revoke',
            ])
            ->assertNoContent();

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/maintenance/bypasses?status=revoked', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $bypass['id'])
            ->assertJsonPath('data.0.effective_status', 'revoked')
            ->assertJsonPath('data.0.is_currently_active', false);

        $this->assertDatabaseHas('sync_outbox', [
            'tenant_id' => 'ten_m9_a',
            'event_type' => 'maintenance.changed.v1',
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_m9_a',
            'action' => 'maintenance.enabled',
        ]);
        $this->assertDatabaseHas('partner_tenant_maintenance_events', [
            'tenant_id' => 'ten_m9_a',
            'event_type' => 'maintenance.updated',
        ]);
        $this->assertSame(0, DB::table('partner_tenant_maintenance_settings')->where('tenant_id', 'ten_m9_b')->where('status', 'active')->count());
    }

    public function test_Maintenance_rejects_missing_reason_and_requires_schedule_permission(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_validation', 'ten_m9_validation', 'm9-validation.test');
        $admin = $this->createTenantSession('ten_m9_validation', 'par_m9_validation', [
            'maintenance.view',
            'maintenance.update',
        ], 'adm_m9_validation', 'm9-validation@example.test');

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'active',
                'mode' => 'full_site',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_validation',
                'Idempotency-Key' => 'm9-maintenance-missing-reason',
            ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'scheduled',
                'mode' => 'scheduled',
                'reason' => 'Scheduled maintenance window',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_validation',
                'Idempotency-Key' => 'm9-maintenance-schedule-denied',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'active',
                'mode' => 'scheduled',
                'reason' => 'Active maintenance must block traffic',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_validation',
                'Idempotency-Key' => 'm9-maintenance-active-scheduled',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.mode.0', 'The mode field must be a blocking maintenance mode when status is active.');

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/maintenance/bypasses', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_validation',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_Maintenance_customer_web_only_keeps_partner_bo_resolvable(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_bo', 'ten_m9_bo', 'm9-bo.test');
        $admin = $this->createTenantSession('ten_m9_bo', 'par_m9_bo', [
            'maintenance.view',
            'maintenance.update',
        ], 'adm_m9_bo', 'm9-bo@example.test');

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'active',
                'mode' => 'customer_web_only',
                'reason' => 'Pause customer storefront only',
                'message' => 'Customer storefront is temporarily unavailable.',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_bo',
                'Idempotency-Key' => 'm9-maintenance-customer-only',
            ])
            ->assertOk()
            ->assertJsonPath('mode', 'customer_web_only')
            ->assertJsonPath('active', true);

        $this->assertDatabaseHas('partner_tenants', [
            'id' => 'ten_m9_bo',
            'status' => 'maintenance',
        ]);

        $this->getJson('http://bo.m9-bo.test/api/v1/public/admin-site-config')
            ->assertOk()
            ->assertJsonPath('mode', 'partner')
            ->assertJsonPath('partner.id', 'par_m9_bo')
            ->assertJsonPath('tenant.id', 'ten_m9_bo');

        $this->postJson('http://bo.m9-bo.test/api/v1/auth/admin/login', [
            'email' => 'm9-bo@example.test',
            'password' => 'secret-password',
        ])
            ->assertOk()
            ->assertJsonPath('scopes.0.scope', 'tenant')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_m9_bo');
    }

    public function test_Maintenance_can_disable_tenant_status_maintenance_without_schedule_permission(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_disable', 'ten_m9_disable', 'm9-disable.test');
        DB::table('partner_tenants')->where('id', 'ten_m9_disable')->update(['status' => 'maintenance']);

        $admin = $this->createTenantSession('ten_m9_disable', 'par_m9_disable', [
            'maintenance.view',
            'maintenance.update',
        ], 'adm_m9_disable', 'm9-disable@example.test');

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/maintenance', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_disable',
            ])
            ->assertOk()
            ->assertJsonPath('active', true);

        $this->withToken($admin['access_token'])
            ->putJson('/api/v1/admin/tenant/maintenance', [
                'status' => 'inactive',
                'mode' => 'scheduled',
                'reason' => 'Maintenance window finished',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_disable',
                'Idempotency-Key' => 'm9-maintenance-disable',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'inactive')
            ->assertJsonPath('active', false);

        $this->assertDatabaseHas('partner_tenants', [
            'id' => 'ten_m9_disable',
            'status' => 'active',
        ]);

        $this->getJson('http://m9-disable.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.maintenance.active', false);
    }

    public function test_CentralMaintenance_can_list_and_update_partner_tenant_maintenance(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_central', 'ten_m9_central', 'm9-central.test');
        $central = $this->createCentralSession([
            'partner.view',
            'partner.update',
        ], 'adm_m9_central', 'm9-central-owner@example.test');

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/maintenance?q=m9-central', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.partner_id', 'par_m9_central')
            ->assertJsonPath('data.0.tenant_id', 'ten_m9_central')
            ->assertJsonPath('data.0.maintenance.active', false);

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/maintenance/ten_m9_central', [
                'status' => 'active',
                'mode' => 'customer_web_only',
                'reason' => 'Central customer storefront pause',
                'message' => 'Customer storefront is temporarily unavailable.',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-maintenance-enable',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('mode', 'customer_web_only')
            ->assertJsonPath('active', true);

        $this->assertDatabaseHas('partner_tenants', [
            'id' => 'ten_m9_central',
            'status' => 'maintenance',
        ]);

        $this->getJson('http://m9-central.test/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.maintenance.active', true)
            ->assertJsonPath('data.maintenance.mode', 'customer_web_only');

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/maintenance/ten_m9_central', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('active', true);

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/maintenance/ten_m9_central', [
                'status' => 'inactive',
                'mode' => 'scheduled',
                'reason' => 'Central maintenance finished',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-maintenance-disable',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'inactive')
            ->assertJsonPath('active', false);

        $this->assertDatabaseHas('partner_tenants', [
            'id' => 'ten_m9_central',
            'status' => 'active',
        ]);
    }

    public function test_CentralPartnerMaintenance_closes_partner_bo_without_changing_tenant_customer_maintenance(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_partner_bo', 'ten_m9_partner_bo', 'm9-partner-bo.test');
        $tenantAdmin = $this->createTenantSession('ten_m9_partner_bo', 'par_m9_partner_bo', [
            'maintenance.view',
            'maintenance.update',
        ], 'adm_m9_partner_bo', 'm9-partner-bo@example.test');
        $central = $this->createCentralSession([
            'partner.view',
            'partner.update',
        ], 'adm_m9_partner_bo_central', 'm9-partner-bo-central@example.test');

        $this->withToken($central['access_token'])
            ->putJson('/api/v1/admin/central/partner-maintenance/par_m9_partner_bo', [
                'status' => 'active',
                'reason' => 'Central BO maintenance window',
                'message' => 'Partner Back Office is temporarily closed by Central.',
                'retry_after_seconds' => 180,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-partner-maintenance-enable',
            ])
            ->assertOk()
            ->assertJsonPath('source', 'central_partner')
            ->assertJsonPath('scope', 'partner_bo')
            ->assertJsonPath('status', 'active')
            ->assertJsonPath('active', true);

        $this->assertDatabaseHas('partner_central_maintenance_settings', [
            'partner_id' => 'par_m9_partner_bo',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('partner_tenants', [
            'id' => 'ten_m9_partner_bo',
            'status' => 'active',
        ]);

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/maintenance?q=m9-partner-bo', [
                'X-Admin-Scope' => 'central',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.partner_maintenance.active', true)
            ->assertJsonPath('data.0.partner_maintenance.scope', 'partner_bo')
            ->assertJsonPath('data.0.maintenance.active', false);

        $this->getJson('http://bo.m9-partner-bo.test/api/v1/public/admin-site-config')
            ->assertOk()
            ->assertJsonPath('mode', 'partner')
            ->assertJsonPath('maintenance.active', true)
            ->assertJsonPath('maintenance.source', 'central_partner')
            ->assertJsonPath('maintenance.retry_after_seconds', 180);

        $this->postJson('http://bo.m9-partner-bo.test/api/v1/auth/admin/login', [
            'email' => 'm9-partner-bo@example.test',
            'password' => 'secret-password',
        ])
            ->assertStatus(503)
            ->assertHeader('Retry-After', '180')
            ->assertJsonPath('error.code', 'maintenance_active');

        $this->withToken($tenantAdmin['access_token'])
            ->getJson('http://bo.m9-partner-bo.test/api/v1/admin/tenant/settings', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_partner_bo',
            ])
            ->assertStatus(503)
            ->assertHeader('Retry-After', '180')
            ->assertJsonPath('error.code', 'maintenance_active');

        $this->withToken($central['access_token'])
            ->putJson('http://localhost/api/v1/admin/central/partner-maintenance/par_m9_partner_bo', [
                'status' => 'inactive',
                'reason' => 'Central BO maintenance finished',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-partner-maintenance-disable',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'inactive')
            ->assertJsonPath('active', false);

        $this->getJson('http://bo.m9-partner-bo.test/api/v1/public/admin-site-config')
            ->assertOk()
            ->assertJsonPath('maintenance.active', false);

        $this->postJson('http://bo.m9-partner-bo.test/api/v1/auth/admin/login', [
            'email' => 'm9-partner-bo@example.test',
            'password' => 'secret-password',
        ])
            ->assertOk()
            ->assertJsonPath('scopes.0.scope', 'tenant')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_m9_partner_bo');
    }

    public function test_Maintenance_bypass_requires_ticket_id_before_mutations_and_preserves_idempotency(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_bypass_ticket', 'ten_m9_bypass_ticket', 'm9-bypass-ticket.test');
        $this->issueCustomerToken('ten_m9_bypass_ticket', 'cus_m9_bypass_ticket');
        $admin = $this->createTenantSession('ten_m9_bypass_ticket', 'par_m9_bypass_ticket', [
            'maintenance.bypass',
        ], 'adm_m9_bypass_ticket', 'm9-bypass-ticket@example.test');

        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => 'ten_m9_bypass_ticket',
        ];
        $payload = [
            'actor_type' => 'customer',
            'actor_id' => 'cus_m9_bypass_ticket',
            'reason' => 'Allow verification during maintenance',
            'expires_at' => now()->addHour()->toISOString(),
        ];

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/maintenance/bypasses', $payload, $headers + [
                'Idempotency-Key' => 'm9-bypass-missing-ticket',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.ticket_id.0', 'The ticket_id field is required.');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/maintenance/bypasses', $payload + [
                'ticket_id' => '   ',
            ], $headers + [
                'Idempotency-Key' => 'm9-bypass-blank-ticket',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.ticket_id.0', 'The ticket_id field is required.');

        $this->assertSame(0, DB::table('partner_tenant_maintenance_bypasses')->where('tenant_id', 'ten_m9_bypass_ticket')->count());
        $this->assertDatabaseMissing('audit_logs', [
            'tenant_id' => 'ten_m9_bypass_ticket',
            'action' => 'maintenance.bypass_created',
        ]);
        $this->assertDatabaseMissing('idempotency_keys', [
            'tenant_id' => 'ten_m9_bypass_ticket',
            'route_key' => 'tenant.maintenance.bypass.create',
            'idempotency_key' => 'm9-bypass-missing-ticket',
        ]);
        $this->assertDatabaseMissing('idempotency_keys', [
            'tenant_id' => 'ten_m9_bypass_ticket',
            'route_key' => 'tenant.maintenance.bypass.create',
            'idempotency_key' => 'm9-bypass-blank-ticket',
        ]);

        $ticketedPayload = $payload + [
            'ticket_id' => 'SUP-M9-BYPASS-TICKET',
        ];

        $bypass = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/maintenance/bypasses', $ticketedPayload, $headers + [
                'Idempotency-Key' => 'm9-bypass-ticketed-create',
            ])
            ->assertCreated()
            ->assertJsonPath('ticket_id', 'SUP-M9-BYPASS-TICKET')
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/maintenance/bypasses', $ticketedPayload, $headers + [
                'Idempotency-Key' => 'm9-bypass-ticketed-create',
            ])
            ->assertCreated()
            ->assertJsonPath('id', $bypass['id'])
            ->assertJsonPath('ticket_id', 'SUP-M9-BYPASS-TICKET');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/maintenance/bypasses', array_replace($ticketedPayload, [
                'reason' => 'Changed reason must conflict with same key',
            ]), $headers + [
                'Idempotency-Key' => 'm9-bypass-ticketed-create',
            ])
            ->assertStatus(409)
            ->assertJsonPath('error.code', 'idempotency_conflict');

        $this->assertDatabaseHas('partner_tenant_maintenance_bypasses', [
            'id' => $bypass['id'],
            'tenant_id' => 'ten_m9_bypass_ticket',
            'ticket_id' => 'SUP-M9-BYPASS-TICKET',
        ]);
        $this->assertSame(1, DB::table('partner_tenant_maintenance_bypasses')->where('tenant_id', 'ten_m9_bypass_ticket')->count());
    }
}
