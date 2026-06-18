<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class AdminUserTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_central_admin_user_manager_can_create_list_view_update_and_disable_users(): void
    {
        $login = $this->createCentralManagerSession(['admin_user.manage']);
        $supportRoleId = $this->insertRole('central', null, 'central_support', 'Central Support', ['dashboard.view']);
        $auditorRoleId = $this->insertRole('central', null, 'central_auditor', 'Central Auditor', ['audit.view']);

        $created = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/admin-users', [
                'name' => 'Central Managed User',
                'email' => 'managed-central@example.test',
                'phone' => '020000001',
                'password' => 'temporary-secret',
                'status' => 'active',
                'role_ids' => [$supportRoleId],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-user-create',
            ])
            ->assertCreated()
            ->assertJsonPath('tenant_id', null)
            ->assertJsonPath('email', 'managed-central@example.test')
            ->assertJsonPath('roles.0.id', $supportRoleId)
            ->assertJsonPath('permissions.0', 'dashboard.view')
            ->json();

        $this->assertSafeAdminUserResponse($created);
        $this->assertTrue(Hash::check('temporary-secret', (string) DB::table('admin_users')->where('id', $created['id'])->value('password_hash')));

        $list = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/admin-users', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertContains('managed-central@example.test', array_column($list, 'email'));

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/admin-users/'.$created['id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('id', $created['id'])
            ->assertJsonPath('roles.0.id', $supportRoleId);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/admin-users/'.$created['id'], [
                'name' => 'Central Managed User Updated',
                'status' => 'suspended',
                'role_ids' => [$auditorRoleId],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-user-update',
            ])
            ->assertOk()
            ->assertJsonPath('name', 'Central Managed User Updated')
            ->assertJsonPath('status', 'suspended')
            ->assertJsonPath('roles.0.id', $auditorRoleId)
            ->assertJsonPath('permissions.0', 'audit.view');

        $this->assertDatabaseHas('admin_permission_cache_versions', [
            'admin_user_id' => $created['id'],
            'scope_id' => 'scp_central',
            'version' => 3,
        ]);

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/central/admin-users/'.$created['id'], [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-user-disable',
            ])
            ->assertNoContent();

        $this->assertDatabaseMissing('admin_user_roles', [
            'admin_user_id' => $created['id'],
            'scope_id' => 'scp_central',
        ]);
        $this->assertDatabaseHas('admin_users', [
            'id' => $created['id'],
            'status' => 'disabled',
        ]);
        $this->assertSame(3, DB::table('audit_logs')->where('action', 'admin_user.changed')->count());
    }

    public function test_bootstrap_platform_owner_is_hidden_and_cannot_be_disabled_but_other_super_admins_can(): void
    {
        $login = $this->createCentralManagerSession(['admin_user.manage']);
        $superAdminRoleId = $this->insertRole('central', null, 'super_admin', 'Platform Super Admin', ['dashboard.view']);
        $protectedUserId = 'adm_platform_owner';
        $otherSuperAdminId = $this->insertScopedAdminUser('other-platform-owner@example.test', 'central', null, 'scp_central', [$superAdminRoleId]);

        $this->createAdmin($protectedUserId, 'superadmin@newpaotang.test');
        DB::table('admin_user_roles')->insert([
            'admin_user_id' => $protectedUserId,
            'role_id' => $superAdminRoleId,
            'scope_id' => 'scp_central',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $list = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/admin-users', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->json('data');

        $this->assertNotContains('superadmin@newpaotang.test', array_column($list, 'email'));
        $this->assertContains('other-platform-owner@example.test', array_column($list, 'email'));

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/admin-users/'.$protectedUserId, ['X-Admin-Scope' => 'central'])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/admin-users/'.$protectedUserId, [
                'status' => 'disabled',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'protected-platform-owner-update',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/central/admin-users/'.$protectedUserId, [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'protected-platform-owner-disable',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->assertDatabaseHas('admin_users', [
            'id' => $protectedUserId,
            'email' => 'superadmin@newpaotang.test',
            'status' => 'active',
        ]);
        $this->assertDatabaseHas('admin_user_roles', [
            'admin_user_id' => $protectedUserId,
            'role_id' => $superAdminRoleId,
            'scope_id' => 'scp_central',
        ]);

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/central/admin-users/'.$otherSuperAdminId, [], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'other-platform-owner-disable',
            ])
            ->assertNoContent();

        $this->assertDatabaseHas('admin_users', [
            'id' => $otherSuperAdminId,
            'status' => 'disabled',
        ]);
        $this->assertDatabaseMissing('admin_user_roles', [
            'admin_user_id' => $otherSuperAdminId,
            'scope_id' => 'scp_central',
        ]);
    }

    public function test_tenant_admin_user_manager_can_create_list_view_update_and_disable_users(): void
    {
        $login = $this->createTenantManagerSession(['admin_user.manage']);
        $supportRoleId = $this->insertRole('tenant', 'ten_auth', 'tenant_support', 'Tenant Support', ['dashboard.view']);
        $ordersRoleId = $this->insertRole('tenant', 'ten_auth', 'tenant_orders', 'Tenant Orders', ['order.view']);

        $created = $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/tenant/admin-users', [
                'name' => 'Tenant Managed User',
                'email' => 'managed-tenant@example.test',
                'phone' => '020000002',
                'role_ids' => [$supportRoleId],
                'send_invitation' => false,
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-user-create',
            ])
            ->assertCreated()
            ->assertJsonPath('tenant_id', 'ten_auth')
            ->assertJsonPath('email', 'managed-tenant@example.test')
            ->assertJsonPath('status', 'invited')
            ->assertJsonPath('roles.0.id', $supportRoleId)
            ->json();

        $this->assertSafeAdminUserResponse($created);

        $list = $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/admin-users', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertContains('managed-tenant@example.test', array_column($list, 'email'));

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/admin-users/'.$created['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('roles.0.id', $supportRoleId);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/admin-users/'.$created['id'], [
                'name' => 'Tenant Managed User Updated',
                'status' => 'active',
                'role_ids' => [$ordersRoleId],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-user-update',
            ])
            ->assertOk()
            ->assertJsonPath('tenant_id', 'ten_auth')
            ->assertJsonPath('name', 'Tenant Managed User Updated')
            ->assertJsonPath('roles.0.id', $ordersRoleId)
            ->assertJsonPath('permissions.0', 'order.view');

        $this->withToken($login['access_token'])
            ->deleteJson('/api/v1/admin/tenant/admin-users/'.$created['id'], [], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-user-disable',
            ])
            ->assertNoContent();

        $this->assertDatabaseMissing('admin_user_roles', [
            'admin_user_id' => $created['id'],
            'scope_id' => 'scp_tenant',
        ]);
        $this->assertDatabaseHas('admin_users', [
            'id' => $created['id'],
            'status' => 'disabled',
        ]);
    }

    public function test_admin_user_management_defaults_to_deny_without_permission(): void
    {
        $login = $this->createCentralManagerSession(['dashboard.view']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/admin-users', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_tenant_admin_cannot_access_or_mutate_another_tenant_admin_user(): void
    {
        $login = $this->createTenantManagerSession(['admin_user.manage']);
        $this->createPartner('par_other', 'other', 'Other Partner');
        $this->createTenant('ten_other', 'par_other');
        $otherRoleId = $this->insertRole('tenant', 'ten_other', 'other_tenant_admin', 'Other Tenant Admin', ['dashboard.view']);
        $otherUserId = $this->insertScopedAdminUser('ten_other_admin@example.test', 'tenant', 'ten_other', 'scp_t_'.substr(sha1('ten_other'), 0, 20), [$otherRoleId]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/admin-users/'.$otherUserId, [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/tenant/admin-users/'.$otherUserId, [
                'name' => 'Leaked Tenant Update',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
                'Idempotency-Key' => 'tenant-cross-update',
            ])
            ->assertNotFound()
            ->assertJsonPath('error.code', 'resource_not_found');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/admin-users', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_other',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_central_admin_cannot_use_tenant_admin_user_endpoints_without_tenant_access(): void
    {
        $login = $this->createCentralManagerSession(['admin_user.manage']);
        $this->createPartner();
        $this->createTenant('ten_auth');

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/tenant/admin-users', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_role_assignments_reject_roles_outside_requested_scope_or_tenant(): void
    {
        $login = $this->createCentralManagerSession(['admin_user.manage']);
        $this->createPartner();
        $this->createTenant('ten_auth');
        $tenantRoleId = $this->insertRole('tenant', 'ten_auth', 'tenant_only_role', 'Tenant Only Role', ['dashboard.view']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/admin-users', [
                'name' => 'Bad Role User',
                'email' => 'bad-role@example.test',
                'role_ids' => [$tenantRoleId],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'bad-role-assignment',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');
    }

    public function test_admin_user_writes_reject_invalid_idempotency_keys(): void
    {
        $login = $this->createCentralManagerSession(['admin_user.manage']);
        $roleId = $this->insertRole('central', null, 'central_support', 'Central Support', ['dashboard.view']);

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/admin-users', [
                'name' => 'Missing Key',
                'email' => 'missing-key@example.test',
                'role_ids' => [$roleId],
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/admin/central/admin-users', [
                'name' => 'Short Key',
                'email' => 'short-key@example.test',
                'role_ids' => [$roleId],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'short',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');
    }

    public function test_admin_user_update_invalidates_target_permission_cache(): void
    {
        $login = $this->createCentralManagerSession(['admin_user.manage']);
        $supportRoleId = $this->insertRole('central', null, 'central_support', 'Central Support', ['dashboard.view']);
        $auditRoleId = $this->insertRole('central', null, 'central_audit', 'Central Audit', ['audit.view']);
        $targetUserId = $this->insertScopedAdminUser('cache-target@example.test', 'central', null, 'scp_central', [$supportRoleId]);

        DB::table('admin_permission_cache_versions')->insert([
            'id' => 'pcv_target_existing',
            'admin_user_id' => $targetUserId,
            'scope_id' => 'scp_central',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/admin/central/admin-users/'.$targetUserId, [
                'role_ids' => [$auditRoleId],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'cache-update-key',
            ])
            ->assertOk()
            ->assertJsonPath('roles.0.id', $auditRoleId);

        $this->assertDatabaseHas('admin_permission_cache_versions', [
            'admin_user_id' => $targetUserId,
            'scope_id' => 'scp_central',
            'version' => 2,
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createCentralManagerSession(array $permissions): array
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, $permissions, 'central_admin_user_manager');

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
    private function createTenantManagerSession(array $permissions): array
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_tenant', 'tenant@example.test');
        $this->createAdminScope('scp_tenant', 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions('adm_tenant', 'scp_tenant', 'tenant', 'ten_auth', $permissions, 'tenant_admin_user_manager');

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

        $permissionIds = DB::table('permissions')
            ->where('scope_type', $scopeType)
            ->whereIn('code', $permissions)
            ->pluck('id')
            ->all();

        if ($permissionIds !== []) {
            DB::table('role_permissions')->insert(array_map(fn (string $permissionId): array => [
                'role_id' => $roleId,
                'permission_id' => $permissionId,
                'created_at' => now(),
                'updated_at' => now(),
            ], $permissionIds));
        }

        return $roleId;
    }

    /**
     * @param array<int, string> $roleIds
     */
    private function insertScopedAdminUser(string $email, string $scopeType, ?string $tenantId, string $scopeId, array $roleIds): string
    {
        if (! DB::table('admin_scopes')->where('id', $scopeId)->exists()) {
            DB::table('admin_scopes')->insert([
                'id' => $scopeId,
                'scope_type' => $scopeType,
                'tenant_id' => $tenantId,
                'partner_id' => $scopeType === 'tenant' ? DB::table('partner_tenants')->where('id', $tenantId)->value('partner_id') : null,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }

        $adminUserId = 'adm_'.substr(sha1($email), 0, 20);

        DB::table('admin_users')->insert([
            'id' => $adminUserId,
            'name' => 'Scoped Admin User',
            'email' => $email,
            'phone' => null,
            'password_hash' => Hash::make('secret-password'),
            'status' => 'active',
            'two_factor_enabled' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_user_roles')->insert(array_map(fn (string $roleId): array => [
            'admin_user_id' => $adminUserId,
            'role_id' => $roleId,
            'scope_id' => $scopeId,
            'created_at' => now(),
            'updated_at' => now(),
        ], $roleIds));

        return $adminUserId;
    }

    /**
     * @param array<string, mixed> $response
     */
    private function assertSafeAdminUserResponse(array $response): void
    {
        $json = json_encode($response, JSON_THROW_ON_ERROR);

        $this->assertStringNotContainsString('password', $json);
        $this->assertStringNotContainsString('password_hash', $json);
        $this->assertStringNotContainsString('temporary-secret', $json);
        $this->assertStringNotContainsString('token', $json);
        $this->assertStringNotContainsString('invitation', $json);
    }
}
