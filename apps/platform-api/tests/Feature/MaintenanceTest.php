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
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_a',
                'Idempotency-Key' => 'm9-maintenance-full',
                'X-Request-Id' => 'req-m9-maintenance-full',
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
            ->getJson('/api/v1/admin/tenant/maintenance/bypasses', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_validation',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'permission_denied');
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
