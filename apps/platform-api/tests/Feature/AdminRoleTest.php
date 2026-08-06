<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class AdminRoleTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_central_role_manager_can_create_list_update_and_archive_roles(): void
    {
        $login = $this->createCentralAdminSession(['role.manage']);

        $created = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Central Auditor',
                'permissions' => ['audit.view'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-role-create',
            ])
            ->assertCreated()
            ->assertJsonPath('tenant_id', null)
            ->assertJsonPath('code', 'central_auditor')
            ->assertJsonPath('permissions.0', 'audit.view')
            ->json();

        $list = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/roles', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertContains('central_auditor', array_column($list, 'code'));

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/roles/'.$created['id'], [
                'name' => 'Central Audit Lead',
                'permissions' => ['audit.view', 'role.manage'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-role-update',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Central Audit Lead')
            ->assertJsonPath('version', 2)
            ->assertJsonPath('permissions', ['audit.view', 'role.manage']);

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/central/roles/'.$created['id'], [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-role-delete',
            ])
            ->assertNoContent();

        $this->assertDatabaseHas('roles', [
            'id' => $created['id'],
            'scope_type' => 'central',
            'tenant_id' => null,
            'status' => 'archived',
            'version' => 3,
        ]);

        $this->assertSame(3, DB::table('audit_logs')->where('action', 'role.changed')->count());
    }

    public function test_tenant_role_manager_can_create_list_update_and_archive_roles(): void
    {
        $login = $this->createTenantAdminSession(['role.manage']);

        $created = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/tenant/roles', [
                'name' => 'Order Support',
                'permissions' => ['dashboard.view', 'order.view'],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-role-create',
            ])
            ->assertCreated()
            ->assertJsonPath('tenant_id', 'ten_auth')
            ->assertJsonPath('name', 'Order Support')
            ->assertJsonPath('permissions', ['dashboard.view', 'order.view'])
            ->json();

        $list = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/roles', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->json('data');

        $this->assertContains('order_support', array_column($list, 'code'));

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/roles/'.$created['id'], [
                'name' => 'Tenant Order Support',
                'permissions' => ['order.view'],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-role-update',
            ])
            ->assertOk()
            ->assertJsonPath('tenant_id', 'ten_auth')
            ->assertJsonPath('name', 'Tenant Order Support')
            ->assertJsonPath('version', 2)
            ->assertJsonPath('permissions', ['order.view']);

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/tenant/roles/'.$created['id'], [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-role-delete',
            ])
            ->assertNoContent();

        $this->assertDatabaseHas('roles', [
            'id' => $created['id'],
            'scope_type' => 'tenant',
            'tenant_id' => 'ten_auth',
            'status' => 'archived',
        ]);
    }

    public function test_tenant_role_manager_can_list_every_active_tenant_permission(): void
    {
        $login = $this->createTenantAdminSession(['role.manage']);

        DB::table('permissions')->insert([
            'id' => 'per_tenant_new_capability',
            'scope_type' => 'tenant',
            'code' => 'new_capability.manage',
            'name' => 'Manage new capability',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $permissions = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/role-permissions', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertContains('new_capability.manage', array_column($permissions, 'code'));
        $this->assertSame('Manage new capability', collect($permissions)->firstWhere('code', 'new_capability.manage')['name']);
    }

    public function test_role_management_defaults_to_deny_without_role_manage_permission(): void
    {
        $login = $this->createCentralAdminSession(['dashboard.view']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/roles', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_tenant_admin_cannot_manage_another_tenant_role(): void
    {
        $login = $this->createTenantAdminSession(['role.manage']);
        $this->createPartner('par_auth_other');
        $this->createTenant('ten_other', 'par_auth_other');
        $otherRoleId = $this->insertRole('tenant', 'ten_other', 'other_tenant_role', 'Other Tenant Role', ['dashboard.view']);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/roles/'.$otherRoleId, [
                'name' => 'Leaked Update',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'cross-tenant-role',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/roles', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_other',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_central_admin_cannot_use_tenant_role_endpoints_without_tenant_access(): void
    {
        $login = $this->createCentralAdminSession(['role.manage']);
        $this->createPartner();
        $this->createTenant('ten_auth');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/roles', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_role_permission_codes_must_match_requested_scope(): void
    {
        $login = $this->createCentralAdminSession(['role.manage']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Bad Central Role',
                'permissions' => ['stock.sync'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'bad-permission-scope',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');
    }

    public function test_role_writes_reject_invalid_idempotency_keys(): void
    {
        $login = $this->createCentralAdminSession(['role.manage']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Missing Key',
                'permissions' => [],
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Short Key',
                'permissions' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'short',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Long Key',
                'permissions' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => str_repeat('k', 129),
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');
    }

    public function test_role_name_and_code_must_be_unique_in_scope(): void
    {
        $login = $this->createCentralAdminSession(['role.manage']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Duplicate Role',
                'permissions' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'duplicate-role-1',
            ])
            ->assertCreated();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/roles', [
                'name' => 'Duplicate Role',
                'permissions' => [],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'duplicate-role-2',
            ])
            ->assertConflict()
            ->assertJsonPath('error.code', 'resource_conflict');
    }

    public function test_role_update_increments_version_and_invalidates_permission_cache(): void
    {
        $login = $this->createCentralAdminSession(['role.manage']);
        $roleId = (string) DB::table('roles')->where('code', 'central_role_manager')->value('id');

        DB::table('admin_permission_cache_versions')->insert([
            'id' => 'pcv_existing_cache',
            'admin_user_id' => 'adm_central',
            'scope_id' => 'scp_central',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/roles/'.$roleId, [
                'name' => 'Central Role Manager Updated',
                'permissions' => ['dashboard.view', 'role.manage'],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'manager-role-update',
            ])
            ->assertOk()
            ->assertJsonPath('version', 2)
            ->assertJsonPath('permissions', ['dashboard.view', 'role.manage']);

        $this->assertDatabaseHas('admin_permission_cache_versions', [
            'admin_user_id' => 'adm_central',
            'scope_id' => 'scp_central',
            'version' => 2,
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createCentralAdminSession(array $permissions): array
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, $permissions, 'central_role_manager');

        return $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createTenantAdminSession(array $permissions): array
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_tenant', 'tenant@example.test');
        $this->createAdminScope('scp_tenant', 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions('adm_tenant', 'scp_tenant', 'tenant', 'ten_auth', $permissions, 'tenant_role_manager');

        return $this->loginAdmin([
            'email' => 'tenant@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_auth',
        ]);
    }

    /**
     * @param array<int, string> $permissions
     */
    private function insertRole(string $scopeType, ?string $tenantId, string $code, string $name, array $permissions): string
    {
        $roleId = 'rol_'.substr(sha1($scopeType.':'.$tenantId.':'.$code), 0, 20);

        DB::table('roles')->insert([
            'id' => $roleId,
            'scope_type' => $scopeType,
            'tenant_id' => $tenantId,
            'code' => $code,
            'name' => $name,
            'status' => 'active',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        if ($permissions === []) {
            return $roleId;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', $scopeType)
            ->whereIn('code', $permissions)
            ->pluck('id')
            ->all();

        DB::table('role_permissions')->insert(array_map(fn (string $permissionId): array => [
            'role_id' => $roleId,
            'permission_id' => $permissionId,
            'created_at' => now(),
            'updated_at' => now(),
        ], $permissionIds));

        return $roleId;
    }
}
