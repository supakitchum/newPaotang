<?php

namespace Tests\Feature;

use App\Shared\Audit\AuditLogger;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class AdminOperationsTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_AdminDashboard_central_and_tenant_summaries_work_with_permission(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession(['dashboard.view']);
        $tenantLogin = $this->createTenantSession(['dashboard.view']);

        $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/summary', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('scope', 'central')
            ->assertJsonPath('tenant_id', null)
            ->assertJsonStructure(['scope', 'generated_at', 'kpis', 'charts', 'alerts']);

        $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/dashboard/summary', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('scope', 'tenant')
            ->assertJsonPath('tenant_id', 'ten_auth')
            ->assertJsonStructure(['scope', 'tenant_id', 'generated_at', 'kpis', 'charts', 'alerts']);
    }

    public function test_AdminDashboard_defaults_to_deny_without_dashboard_view(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['menu.manage']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/dashboard/summary', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminRealtime_authorizes_allowed_channels_and_rejects_scope_mismatch(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession([]);
        $tenantLogin = $this->createTenantSession([]);

        $centralAuth = $this->withToken($centralLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => 'private-admin.central.dashboard',
            ], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data', 'expires_at'])
            ->json();

        $this->assertStringStartsWith('newpaotang-admin:', $centralAuth['auth']);
        $this->assertNull($centralAuth['channel_data']);

        $this->withToken($centralLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => 'private-admin.tenant.ten_auth.dashboard',
            ], ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $tenantAuth = $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '9876.5432',
                'channel_name' => 'presence-admin.tenant.ten_auth',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonStructure(['auth', 'channel_data', 'expires_at'])
            ->json();

        $this->assertStringContainsString('"tenant_id":"ten_auth"', $tenantAuth['channel_data']);

        $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '9876.5432',
                'channel_name' => 'private-admin.tenant.ten_other.dashboard',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminRealtime_stock_generation_channels_require_central_stock_generate_permission(): void
    {
        $this->seedDefaultRbac();
        $stockLogin = $this->createCentralSession(['stock.generate'], 'adm_realtime_stock', 'realtime-stock@example.test', 'central_stock_realtime');
        $deniedLogin = $this->createCentralSession(['stock.view'], 'adm_realtime_stock_denied', 'realtime-stock-denied@example.test', 'central_stock_realtime_denied');
        $tenantLogin = $this->createTenantSession([]);

        foreach ([
            'private-admin.central.stock-generation',
            'private-admin.central.stock-generation.game.gam_realtime',
            'private-admin.central.stock-generation.batch.stb_realtime',
        ] as $channelName) {
            $this->withToken($stockLogin['access_token'])
                ->postJson('/api/v1/admin/central/realtime/auth', [
                    'socket_id' => '2222.3333',
                    'channel_name' => $channelName,
                ], ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->assertJsonStructure(['auth', 'channel_data', 'expires_at']);
        }

        $this->withToken($deniedLogin['access_token'])
            ->postJson('/api/v1/admin/central/realtime/auth', [
                'socket_id' => '2222.3333',
                'channel_name' => 'private-admin.central.stock-generation.batch.stb_realtime',
            ], ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->withToken($tenantLogin['access_token'])
            ->postJson('/api/v1/admin/tenant/realtime/auth', [
                'socket_id' => '2222.3333',
                'channel_name' => 'private-admin.central.stock-generation',
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AdminMenu_management_read_and_update_validates_idempotency_and_writes_audit(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['menu.manage']);
        $roleId = (string) DB::table('roles')->where('code', 'central_ops')->value('id');

        $dashboardMenu = $this->menuItemByKey(
            $this->withToken($login['access_token'])
                ->getJson('/api/v1/admin/central/menu-management', ['X-Admin-Scope' => 'central'])
                ->assertOk()
                ->json('data'),
            'dashboard',
        );

        $this->assertNotNull($dashboardMenu);
        $this->assertArrayHasKey('required_permission_code', $dashboardMenu);

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [],
            ], ['X-Admin-Scope' => 'central'])
            ->assertUnprocessable()
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        DB::table('admin_permission_cache_versions')->insert([
            'id' => 'pcv_admin_menu_existing',
            'admin_user_id' => 'adm_central',
            'scope_id' => 'scp_central',
            'version' => 1,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $updated = $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [[
                    'id' => $dashboardMenu['id'],
                    'key' => 'dashboard',
                    'label' => 'Dashboard Managed',
                    'route' => '/central/dashboard',
                    'required_permission_code' => 'dashboard.view',
                    'sort_order' => 5,
                    'status' => 'active',
                    'role_ids' => [$roleId],
                    'children' => [],
                ]],
                'reason' => 'menu update',
                'password' => 'super-secret',
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-menu-update',
            ])
            ->assertOk()
            ->json('data');

        $updatedDashboard = $this->menuItemByKey($updated, 'dashboard');
        $this->assertSame('Dashboard Managed', $updatedDashboard['label']);
        $this->assertSame([$roleId], $updatedDashboard['role_ids']);

        $this->assertDatabaseHas('role_menus', [
            'role_id' => $roleId,
            'menu_id' => $dashboardMenu['id'],
        ]);
        $this->assertDatabaseHas('admin_permission_cache_versions', [
            'admin_user_id' => 'adm_central',
            'scope_id' => 'scp_central',
            'version' => 2,
        ]);

        $auditPayload = json_decode((string) DB::table('audit_logs')->where('action', 'menu.changed')->value('payload_redacted_json'), true);
        $this->assertSame('[REDACTED]', $auditPayload['payload']['password']);
        $this->assertStringNotContainsString('super-secret', json_encode($auditPayload, JSON_THROW_ON_ERROR));
    }

    public function test_AdminMenu_management_rejects_cross_scope_tree_bad_roles_and_duplicate_ordering(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['menu.manage']);
        $this->createPartner();
        $this->createTenant('ten_auth');
        $tenantRoleId = $this->insertRole('tenant', 'ten_auth', 'tenant_menu_role', 'Tenant Menu Role', ['menu.manage']);
        $centralDashboardMenuId = (string) DB::table('admin_menus')->where('scope_type', 'central')->where('code', 'dashboard')->value('id');
        $centralGamesMenuId = (string) DB::table('admin_menus')->where('scope_type', 'central')->where('code', 'games')->value('id');
        $tenantDashboardMenuId = (string) DB::table('admin_menus')->where('scope_type', 'tenant')->where('code', 'dashboard')->value('id');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [[
                    'id' => $tenantDashboardMenuId,
                    'key' => 'dashboard',
                    'label' => 'Wrong Scope Dashboard',
                    'children' => [],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'cross-scope-menu',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [[
                    'id' => $centralDashboardMenuId,
                    'key' => 'dashboard',
                    'label' => 'Dashboard',
                    'role_ids' => [$tenantRoleId],
                    'children' => [],
                ]],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'bad-menu-role',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->withToken($login['access_token'])
            ->putJson('/api/v1/admin/central/menu-management', [
                'items' => [
                    [
                        'id' => $centralDashboardMenuId,
                        'key' => 'dashboard',
                        'label' => 'Dashboard',
                        'sort_order' => 10,
                        'children' => [],
                    ],
                    [
                        'id' => $centralGamesMenuId,
                        'key' => 'games',
                        'label' => 'Games',
                        'sort_order' => 10,
                        'children' => [],
                    ],
                ],
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'duplicate-menu-order',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');
    }

    public function test_AuditLog_lists_are_permissioned_redacted_and_tenant_isolated(): void
    {
        $this->seedDefaultRbac();
        $centralLogin = $this->createCentralSession(['audit.view']);
        $tenantLogin = $this->createTenantSession(['audit.view']);
        $this->createTenant('ten_other');

        app(AuditLogger::class)->logAdminWrite(
            actorId: 'adm_central',
            scopeType: 'central',
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: 'scp_central',
            payload: [
                'password' => 'central-secret',
                'token_hash' => 'central-token-hash',
                'invitation_url' => 'https://admin.example.test/invitations/central-raw',
                'invitation_code' => 'CENTRAL-INVITE-CODE',
                'invite_link' => 'https://admin.example.test/invite-link/central-raw',
            ],
        );

        app(AuditLogger::class)->logAdminWrite(
            actorId: 'adm_tenant',
            scopeType: 'tenant',
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: 'scp_tenant',
            payload: [
                'password_hash' => 'tenant-password-hash',
                'secret' => 'tenant-secret',
                'invitation_material' => [
                    'invitation_url' => 'https://tenant.example.test/invitations/tenant-raw',
                    'invitation_code' => 'TENANT-INVITE-CODE',
                    'invite_link' => 'https://tenant.example.test/invite-link/tenant-raw',
                ],
            ],
            tenantId: 'ten_auth',
        );

        app(AuditLogger::class)->logAdminWrite(
            actorId: 'adm_other',
            scopeType: 'tenant',
            action: 'menu.changed',
            targetType: 'admin_menu_tree',
            targetId: 'scp_other',
            payload: ['secret' => 'other-secret'],
            tenantId: 'ten_other',
        );

        $centralLogs = $this->withToken($centralLogin['access_token'])
            ->getJson('/api/v1/admin/central/audit-logs?action=menu.changed&limit=10', ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertCount(1, $centralLogs);
        $this->assertSame('central', $centralLogs[0]['scope']);
        $this->assertNull($centralLogs[0]['tenant_id']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['password']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['token_hash']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['invitation_url']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['invitation_code']);
        $this->assertSame('[REDACTED]', $centralLogs[0]['payload']['invite_link']);
        $this->assertStringNotContainsString('central-raw', json_encode($centralLogs, JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('CENTRAL-INVITE-CODE', json_encode($centralLogs, JSON_THROW_ON_ERROR));

        $tenantLogs = $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/audit-logs?action=menu.changed&limit=10', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_auth',
            ])
            ->assertOk()
            ->assertJsonPath('meta.has_more', false)
            ->json('data');

        $this->assertCount(1, $tenantLogs);
        $this->assertSame('ten_auth', $tenantLogs[0]['tenant_id']);
        $this->assertSame('[REDACTED]', $tenantLogs[0]['payload']['password_hash']);
        $this->assertSame('[REDACTED]', $tenantLogs[0]['payload']['invitation_material']);
        $this->assertStringNotContainsString('tenant-raw', json_encode($tenantLogs, JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('TENANT-INVITE-CODE', json_encode($tenantLogs, JSON_THROW_ON_ERROR));
        $this->assertStringNotContainsString('other-secret', json_encode($tenantLogs, JSON_THROW_ON_ERROR));

        $this->withToken($tenantLogin['access_token'])
            ->getJson('/api/v1/admin/tenant/audit-logs?action=menu.changed', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_other',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    public function test_AuditLog_defaults_to_deny_without_audit_view(): void
    {
        $this->seedDefaultRbac();
        $login = $this->createCentralSession(['dashboard.view']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/admin/central/audit-logs', ['X-Admin-Scope' => 'central'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createCentralSession(
        array $permissions,
        string $adminId = 'adm_central',
        string $email = 'central@example.test',
        string $roleCode = 'central_ops',
    ): array
    {
        $scopeId = $adminId === 'adm_central' ? 'scp_central' : 'scp_'.$adminId;

        $this->createAdmin($adminId, $email);
        $this->createAdminScope($scopeId, 'central');
        $this->assignRoleWithPermissions($adminId, $scopeId, 'central', null, $permissions, $roleCode);

        return $this->loginAdmin([
            'email' => $email,
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function createTenantSession(array $permissions): array
    {
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_tenant', 'tenant@example.test');
        $this->createAdminScope('scp_tenant', 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions('adm_tenant', 'scp_tenant', 'tenant', 'ten_auth', $permissions, 'tenant_ops');

        return $this->loginAdmin([
            'email' => 'tenant@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_auth',
        ]);
    }

    /**
     * @param array<int, array<string, mixed>> $items
     * @return array<string, mixed>|null
     */
    private function menuItemByKey(array $items, string $key): ?array
    {
        foreach ($items as $item) {
            if (($item['key'] ?? null) === $key) {
                return $item;
            }

            $found = $this->menuItemByKey($item['children'] ?? [], $key);

            if ($found !== null) {
                return $found;
            }
        }

        return null;
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
}
