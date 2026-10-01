<?php

namespace Tests\Support;

use Database\Seeders\DefaultRbacMenuSeeder;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;

trait AdminAuthFixtures
{
    protected function seedDefaultRbac(): void
    {
        $this->seed(DefaultRbacMenuSeeder::class);
    }

    protected function createPartner(string $partnerId = 'par_auth', ?string $code = null, ?string $name = null): void
    {
        DB::table('partners')->insert([
            'id' => $partnerId,
            'code' => $code ?? $partnerId,
            'name' => $name ?? 'Auth Partner '.$partnerId,
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createTenant(string $tenantId, string $partnerId = 'par_auth', ?string $code = null, ?string $name = null): void
    {
        DB::table('partner_tenants')->insert([
            'id' => $tenantId,
            'partner_id' => $partnerId,
            'code' => $code ?? $tenantId,
            'name' => $name ?? 'Tenant '.$tenantId,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createTenantDomain(
        string $domainId,
        string $partnerId,
        string $tenantId,
        string $host,
        string $status = 'active',
    ): void {
        DB::table('partner_tenant_domains')->insert([
            'id' => $domainId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'host' => $host,
            'type' => 'custom_domain',
            'status' => $status,
            'is_primary' => true,
            'verified_at' => now(),
            'ssl_ready_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createTenantSettings(string $tenantId, string $siteName, ?string $displayName = null): void
    {
        DB::table('partner_tenant_settings')->insert([
            'id' => 'pts_'.substr(sha1($tenantId), 0, 20),
            'tenant_id' => $tenantId,
            'site_name' => $siteName,
            'display_name' => $displayName,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'default_title' => $siteName,
            'title_template' => null,
            'default_description' => null,
            'default_keywords_json' => json_encode([], JSON_THROW_ON_ERROR),
            'robots_default' => 'index,follow',
            'sitemap_enabled' => true,
            'robots_enabled' => true,
            'maintenance_active' => false,
            'maintenance_mode' => null,
            'maintenance_message' => null,
            'maintenance_expected_end_at' => null,
            'maintenance_retry_after_seconds' => null,
            'maintenance_allowed_routes_json' => json_encode([], JSON_THROW_ON_ERROR),
            'maintenance_blocked_route_patterns_json' => json_encode([], JSON_THROW_ON_ERROR),
            'api_base_url' => '/api/v1',
            'realtime_url' => null,
            'asset_cdn_base_url' => null,
            'config_version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createTenantTheme(string $tenantId, ?string $logoUrl = null, ?string $faviconUrl = null): void
    {
        DB::table('partner_tenant_themes')->insert([
            'id' => 'ptt_'.substr(sha1($tenantId), 0, 20),
            'tenant_id' => $tenantId,
            'logo_url' => $logoUrl,
            'favicon_url' => $faviconUrl,
            'og_image_url' => null,
            'primary_color' => '#0F766E',
            'secondary_color' => '#2563EB',
            'accent_color' => '#F59E0B',
            'background_color' => '#FFFFFF',
            'text_color' => '#111827',
            'font_family' => 'Inter, sans-serif',
            'config_version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    protected function createAdmin(
        string $adminId,
        string $email,
        string $password = 'secret-password',
        string $status = 'active',
        bool $mustChangePassword = false,
    ): void {
        $row = [
            'id' => $adminId,
            'name' => 'Admin '.$adminId,
            'email' => $email,
            'phone' => null,
            'password_hash' => Hash::make($password),
            'status' => $status,
            'two_factor_enabled' => false,
            'created_at' => now(),
            'updated_at' => now(),
        ];

        if (Schema::hasColumn('admin_users', 'must_change_password')) {
            $row['must_change_password'] = $mustChangePassword;
        }

        if (Schema::hasColumn('admin_users', 'password_changed_at')) {
            $row['password_changed_at'] = $mustChangePassword ? null : now();
        }

        DB::table('admin_users')->insert($row);
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
        return $this->postJson('http://localhost/api/v1/auth/admin/login', $payload)
            ->assertOk()
            ->json();
    }
}
