<?php

namespace Tests\Support;

use Database\Seeders\DefaultRbacMenuSeeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;

trait AdminAuthFixtures
{
    protected function seedDefaultRbac(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);
    }

    protected function createPartner(string $partnerId = 'par_auth'): void
    {
        DB::table('partners')->insert([
            'id' => $partnerId,
            'code' => $partnerId,
            'name' => 'Auth Partner '.$partnerId,
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createTenant(string $tenantId, string $partnerId = 'par_auth'): void
    {
        DB::table('partner_tenants')->insert([
            'id' => $tenantId,
            'partner_id' => $partnerId,
            'code' => $tenantId,
            'name' => 'Tenant '.$tenantId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createAdmin(
        string $adminId,
        string $email,
        string $password = 'secret-password',
        string $status = 'active',
    ): void {
        DB::table('admin_users')->insert([
            'id' => $adminId,
            'name' => 'Admin '.$adminId,
            'email' => $email,
            'phone' => null,
            'password_hash' => Hash::make($password),
            'status' => $status,
            'two_factor_enabled' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createAdminScope(string $scopeId, string $scopeType, ?string $tenantId = null, ?string $partnerId = null): void
    {
        DB::table('admin_scopes')->insert([
            'id' => $scopeId,
            'scope_type' => $scopeType,
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    /**
     * @param array<int, string> $permissionCodes
     */
    protected function assignRoleWithPermissions(
        string $adminId,
        string $scopeId,
        string $scopeType,
        ?string $tenantId,
        array $permissionCodes,
        string $roleCode,
    ): void {
        $roleId = 'rol_'.substr(sha1($adminId.':'.$scopeId.':'.$roleCode), 0, 20);

        DB::table('roles')->insert([
            'id' => $roleId,
            'scope_type' => $scopeType,
            'tenant_id' => $tenantId,
            'code' => $roleCode,
            'name' => str($roleCode)->replace('_', ' ')->title()->toString(),
            'status' => 'active',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('admin_user_roles')->insert([
            'admin_user_id' => $adminId,
            'role_id' => $roleId,
            'scope_id' => $scopeId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        if ($permissionCodes === []) {
            return;
        }

        $permissionIds = DB::table('permissions')
            ->where('scope_type', $scopeType)
            ->whereIn('code', $permissionCodes)
            ->pluck('id', 'code')
            ->all();

        $this->assertCount(count($permissionCodes), $permissionIds);

        DB::table('role_permissions')->insert(array_map(fn (string $permissionCode): array => [
            'role_id' => $roleId,
            'permission_id' => $permissionIds[$permissionCode],
            'created_at' => now(),
            'updated_at' => now(),
        ], $permissionCodes));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    protected function loginAdmin(array $payload): array
    {
        return $this->postJson('/api/v1/auth/admin/login', $payload)
            ->assertOk()
            ->json();
    }
}
