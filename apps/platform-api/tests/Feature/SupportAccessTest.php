<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class SupportAccessTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_SupportAccess_approval_impersonation_hashes_token_and_keeps_tenant_scope(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_support_a', 'ten_m9_support_a', 'm9-support-a.test');
        $this->insertActivePartnerTenantWithDomain('par_m9_support_b', 'ten_m9_support_b', 'm9-support-b.test');
        $this->issueCustomerToken('ten_m9_support_a', 'cus_m9_support_a');
        $this->issueCustomerToken('ten_m9_support_b', 'cus_m9_support_b');
        $admin = $this->createTenantSession('ten_m9_support_a', 'par_m9_support_a', [
            'support_access.audit',
            'support_access.request',
            'support_access.approve',
            'support_access.impersonate_customer',
            'support_access.elevated_action',
        ], 'adm_m9_support', 'm9-support@example.test');

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access', [
                'target_user_id' => 'cus_m9_support_b',
                'target_user_type' => 'customer',
                'scope' => 'customer_read',
                'reason' => 'Cross tenant should fail',
                'ticket_id' => 'SUP-M9-X',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
                'Idempotency-Key' => 'm9-support-cross-tenant',
            ])
            ->assertStatus(422)
            ->assertJsonPath('error.code', 'validation_failed');

        $supportAccess = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access', [
                'target_user_id' => 'cus_m9_support_a',
                'target_user_type' => 'customer',
                'scope' => 'customer_read',
                'reason' => 'Investigate customer ticket',
                'ticket_id' => 'SUP-M9-100',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
                'Idempotency-Key' => 'm9-support-create',
                'X-Request-Id' => 'req-m9-support-create',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'pending_approval')
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'].'/approve', [
                'reason' => 'Approved by tenant owner',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
                'Idempotency-Key' => 'm9-support-approve',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'approved');

        $impersonation = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'].'/impersonate', [
                'reason' => 'Start read-only support session',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
                'Idempotency-Key' => 'm9-support-impersonate',
                'X-Request-Id' => 'req-m9-support-impersonate',
            ])
            ->assertOk()
            ->assertJsonPath('active_session.status', 'active')
            ->json();

        $token = $impersonation['active_session']['access_token'];
        $sessionId = $impersonation['active_session']['id'];
        $this->assertIsString($token);
        $this->assertStringStartsWith('npa_sup_', $token);
        $this->assertDatabaseHas('support_impersonation_sessions', [
            'id' => $sessionId,
            'tenant_id' => 'ten_m9_support_a',
            'token_hash' => hash('sha256', $token),
        ]);
        $this->assertSame(0, DB::table('support_impersonation_sessions')->where('token_hash', $token)->count());

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
            ])
            ->assertOk()
            ->assertJsonMissingPath('active_session.access_token')
            ->assertJsonMissing(['token_hash' => hash('sha256', $token)]);

        $this->assertDatabaseHas('sync_outbox', [
            'tenant_id' => 'ten_m9_support_a',
            'event_type' => 'support_impersonation.started.v1',
        ]);

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'].'/elevated-actions', [
                'action' => 'export_sensitive_data',
                'reason' => 'Document denied elevated request',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
                'Idempotency-Key' => 'm9-support-elevated',
            ])
            ->assertAccepted();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'].'/end-session', [
                'reason' => 'Ticket resolved',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_support_a',
                'Idempotency-Key' => 'm9-support-end-session',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'completed');
    }
}
