<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class ImpersonationSecurityTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_ImpersonationSecurity_blocks_sensitive_wallet_action_and_records_audit_outbox(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_m9_security', 'ten_m9_security', 'm9-security.test');
        $this->issueCustomerToken('ten_m9_security', 'cus_m9_security');
        DB::table('wallets')->insert([
            'id' => 'wal_m9_security',
            'tenant_id' => 'ten_m9_security',
            'customer_id' => 'cus_m9_security',
            'name' => 'Primary wallet',
            'type' => 'primary',
            'status' => 'active',
            'balance_amount' => 50000,
            'currency' => 'THB',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $admin = $this->createTenantSession('ten_m9_security', 'par_m9_security', [
            'support_access.audit',
            'support_access.request',
            'support_access.approve',
            'support_access.impersonate_customer',
            'wallet.adjust',
        ], 'adm_m9_security', 'm9-security@example.test');

        $supportAccess = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access', [
                'target_user_id' => 'cus_m9_security',
                'target_user_type' => 'customer',
                'scope' => 'customer_read',
                'reason' => 'Security review',
                'ticket_id' => 'SUP-M9-SEC',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_security',
                'Idempotency-Key' => 'm9-security-support-create',
            ])
            ->assertCreated()
            ->json();

        $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'].'/approve', [
                'reason' => 'Approved for security test',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_security',
                'Idempotency-Key' => 'm9-security-support-approve',
            ])
            ->assertOk();

        $impersonation = $this->withToken($admin['access_token'])
            ->postJson('/api/v1/admin/tenant/support-access/'.$supportAccess['id'].'/impersonate', [
                'reason' => 'Start support session',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_security',
                'Idempotency-Key' => 'm9-security-support-impersonate',
            ])
            ->assertOk()
            ->json();

        $this->withToken($admin['access_token'])
            ->patchJson('/api/v1/admin/tenant/wallets/wal_m9_security/adjust', [
                'amount' => 1000,
                'reason' => 'Should be blocked',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_m9_security',
                'Idempotency-Key' => 'm9-security-wallet-adjust',
                'X-Support-Impersonation-Session-Id' => $impersonation['active_session']['id'],
                'X-Support-Impersonation-Token' => $impersonation['active_session']['access_token'],
                'X-Request-Id' => 'req-m9-security-block',
            ])
            ->assertStatus(403)
            ->assertJsonPath('error.code', 'permission_denied');

        $this->assertDatabaseHas('support_impersonation_blocked_actions', [
            'tenant_id' => 'ten_m9_security',
            'support_impersonation_session_id' => $impersonation['active_session']['id'],
            'action' => 'wallet_adjust',
            'status' => 'blocked',
        ]);
        $this->assertDatabaseHas('sync_outbox', [
            'tenant_id' => 'ten_m9_security',
            'event_type' => 'support_impersonation.action_blocked.v1',
        ]);
        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => 'ten_m9_security',
            'action' => 'support_impersonation.action_blocked',
        ]);
        $this->assertSame(50000, DB::table('wallets')->where('id', 'wal_m9_security')->value('balance_amount'));
    }
}
