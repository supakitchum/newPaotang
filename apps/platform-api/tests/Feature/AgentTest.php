<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\M8GrowthFixtures;
use Tests\TestCase;

class AgentTest extends TestCase
{
    use M8GrowthFixtures;
    use RefreshDatabase;

    public function test_Agent_endpoints_are_permissioned_idempotent_and_tenant_scoped(): void
    {
        $world = $this->prepareM8World('agent-main');
        $other = $this->prepareM8World('agent-other');
        $viewer = $this->m8TenantAdmin($world, ['agent.view'], 'agent-view');
        $manager = $this->m8TenantAdmin($world, ['agent.view', 'agent.create', 'agent.update', 'agent.quota.manage'], 'agent-manager');

        DB::table('agents')->insert([
            'id' => 'agt_other_agent_test',
            'tenant_id' => $other['tenant_id'],
            'partner_id' => $other['partner_id'],
            'code' => 'other_agent',
            'name' => 'Other Agent',
            'phone' => null,
            'email' => null,
            'store_id' => null,
            'status' => 'active',
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($viewer['access_token'])
            ->postJson('/api/v1/admin/tenant/agents', ['name' => 'Denied Agent'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'agent-denied-main',
            ])
            ->assertForbidden();

        $created = $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/agents', [
                'code' => 'agent_alpha',
                'name' => 'Agent Alpha',
                'store_id' => 'store-alpha',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'agent-create-main',
                'X-Request-Id' => 'req-agent-create',
            ])
            ->assertCreated()
            ->assertJsonPath('tenant_id', $world['tenant_id'])
            ->assertJsonPath('code', 'agent_alpha')
            ->json();

        $this->withToken($manager['access_token'])
            ->postJson('/api/v1/admin/tenant/agents', [
                'code' => 'agent_alpha',
                'name' => 'Agent Alpha',
                'store_id' => 'store-alpha',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'agent-create-main',
            ])
            ->assertCreated()
            ->assertJsonPath('id', $created['id']);

        $this->withToken($manager['access_token'])
            ->patchJson('/api/v1/admin/tenant/agents/'.$created['id'].'/quotas', [
                'game_id' => $world['game_id'],
                'quota_count' => 12,
                'used_count' => 2,
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
                'Idempotency-Key' => 'agent-quota-main',
            ])
            ->assertOk()
            ->assertJsonPath('quotas.0.quota_count', 12);

        $this->withToken($manager['access_token'])
            ->getJson('/api/v1/admin/tenant/agents', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => $world['tenant_id'],
            ])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $created['id']);

        $this->assertDatabaseHas('audit_logs', [
            'tenant_id' => $world['tenant_id'],
            'action' => 'agent.created',
            'target_id' => $created['id'],
        ]);
    }
}
