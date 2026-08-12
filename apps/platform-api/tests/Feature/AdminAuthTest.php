<?php

namespace Tests\Feature;

use App\Shared\Tenancy\Http\Middleware\NormalizeRequestHost;
use Illuminate\Http\Request;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Symfony\Component\HttpFoundation\Response;
use Tests\Support\AdminAuthFixtures;
use Tests\TestCase;

class AdminAuthTest extends TestCase
{
    use AdminAuthFixtures;
    use RefreshDatabase;

    public function test_admin_login_returns_auth_response_and_audits_redacted_payload(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $response = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ], ['X-Request-Id' => 'req_login'])
            ->assertOk()
            ->assertJsonStructure([
                'access_token',
                'refresh_token',
                'expires_in',
                'requires_2fa',
                'challenge_token',
                'user' => ['id', 'name', 'email', 'status', 'two_factor_enabled', 'must_change_password', 'password_changed_at'],
                'scopes' => [['scope', 'tenant_id', 'tenant_name', 'permissions']],
            ])
            ->assertJsonPath('user.id', 'adm_central')
            ->assertJsonPath('user.email', 'central@example.test')
            ->assertJsonPath('user.must_change_password', false)
            ->assertJsonPath('scopes.0.scope', 'central')
            ->json();

        $this->assertIsString($response['access_token']);
        $this->assertIsString($response['refresh_token']);
        $this->assertSame(28800, $response['expires_in']);
        $this->assertArrayNotHasKey('session_id', $response);

        $this->assertDatabaseHas('admin_auth_sessions', [
            'admin_user_id' => 'adm_central',
            'access_token_hash' => hash('sha256', $response['access_token']),
            'refresh_token_hash' => hash('sha256', $response['refresh_token']),
            'scope_type' => 'central',
            'scope_id' => 'scp_central',
            'tenant_id' => null,
        ]);

        $audit = DB::table('audit_logs')->where('action', 'admin.login')->first();
        $this->assertNotNull($audit);

        $payload = json_decode($audit->payload_redacted_json, true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('[REDACTED]', $payload['password']);
        $this->assertSame('[REDACTED]', $payload['access_token']);
        $this->assertSame('[REDACTED]', $payload['refresh_token']);
    }

    public function test_admin_with_forced_password_change_is_limited_until_password_is_changed(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_forced', 'forced@example.test', mustChangePassword: true);
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_forced', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $login = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'forced@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('user.must_change_password', true)
            ->assertJsonPath('user.password_changed_at', null)
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertOk()
            ->assertJsonPath('user.must_change_password', true);

        $this->withToken($login['access_token'])
            ->patchJson('/api/v1/auth/admin/me', ['preferred_locale' => 'en-US'])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'admin_password_change_required');

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/auth/admin/password/change', [
                'current_password' => 'secret-password',
                'new_password' => 'better-secret-password',
                'new_password_confirmation' => 'better-secret-password',
            ], ['Idempotency-Key' => 'forced-change-001'])
            ->assertNoContent();

        $this->assertDatabaseHas('admin_users', [
            'id' => 'adm_forced',
            'must_change_password' => false,
        ]);

        $this->assertNotNull(DB::table('admin_users')->where('id', 'adm_forced')->value('password_changed_at'));

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertUnauthorized();
    }

    public function test_invalid_admin_credentials_use_safe_auth_error(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');

        $response = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'central@example.test',
            'password' => 'wrong-password',
            'scope' => 'central',
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $body = $response->getContent();

        $this->assertStringNotContainsString('password_hash', $body);
        $this->assertStringNotContainsString('wrong-password', $body);
        $this->assertStringNotContainsString('access_token', $body);
        $this->assertStringNotContainsString('refresh_token', $body);
    }

    public function test_refresh_issues_new_tokens_from_valid_refresh_token(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $login = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $refresh = $this->postJson('/api/v1/auth/admin/refresh', [
            'refresh_token' => $login['refresh_token'],
        ])
            ->assertOk()
            ->json();

        $this->assertNotSame($login['access_token'], $refresh['access_token']);
        $this->assertNotSame($login['refresh_token'], $refresh['refresh_token']);

        $this->assertNotNull(DB::table('admin_auth_sessions')
            ->where('refresh_token_hash', hash('sha256', $login['refresh_token']))
            ->where('revoked_reason', 'refreshed')
            ->whereNotNull('revoked_at')
            ->first());
    }

    public function test_second_admin_login_revokes_previous_session_with_device_message(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $first = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $second = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ])
            ->assertOk()
            ->assertJsonPath('revoked_other_sessions_count', 1)
            ->assertJsonPath('message', 'A previous admin session was signed out because this account signed in on another device.')
            ->json();

        $this->assertDatabaseHas('admin_auth_sessions', [
            'access_token_hash' => hash('sha256', $first['access_token']),
            'revoked_reason' => 'replaced_by_new_login',
        ]);

        $this->withToken($first['access_token'])
            ->getJson('/api/v1/auth/admin/me', ['Accept-Language' => 'th-TH'])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'admin_session_replaced')
            ->assertJsonPath('error.message', 'มีการเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่');

        $this->withToken($second['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertOk();
    }

    public function test_logout_revokes_current_session_and_blocks_me(): void
    {
        $login = $this->createCentralAdminSession();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/auth/admin/logout', [], ['Idempotency-Key' => 'logout-001'])
            ->assertNoContent();

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertUnauthorized();

        $this->assertDatabaseHas('audit_logs', [
            'actor_id' => 'adm_central',
            'action' => 'admin.logout',
            'target_type' => 'admin_auth_session',
        ]);
    }

    public function test_logout_rejects_missing_idempotency_key_without_revoking_session(): void
    {
        $login = $this->createCentralAdminSession();

        $response = $this->withToken($login['access_token'])
            ->postJson('/api/v1/auth/admin/logout')
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.Idempotency-Key.0', 'The Idempotency-Key header must be between 8 and 128 characters.');

        $this->assertStringNotContainsString($login['access_token'], $response->getContent());
        $this->assertStringNotContainsString($login['refresh_token'], $response->getContent());
        $this->assertActiveAccessToken($login['access_token']);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertOk();
    }

    public function test_logout_rejects_too_short_idempotency_key_without_revoking_session(): void
    {
        $login = $this->createCentralAdminSession();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/auth/admin/logout', [], ['Idempotency-Key' => 'short'])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->assertActiveAccessToken($login['access_token']);
    }

    public function test_logout_rejects_too_long_idempotency_key_without_revoking_session(): void
    {
        $login = $this->createCentralAdminSession();

        $this->withToken($login['access_token'])
            ->postJson('/api/v1/auth/admin/logout', [], ['Idempotency-Key' => str_repeat('k', 129)])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->assertActiveAccessToken($login['access_token']);
    }

    public function test_me_returns_current_admin_session_profile(): void
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $login = $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $this->withToken($login['access_token'])
            ->getJson('/api/v1/auth/admin/me')
            ->assertOk()
            ->assertJsonPath('user.id', 'adm_central')
            ->assertJsonPath('user.must_change_password', false)
            ->assertJsonPath('active_scope', 'central')
            ->assertJsonPath('active_tenant_id', null)
            ->assertJsonPath('scopes.0.permissions.0', 'dashboard.view');
    }

    public function test_server_time_requires_authentication_and_returns_application_clock(): void
    {
        $this->getJson('/api/v1/auth/admin/server-time')
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $login = $this->createCentralAdminSession();

        $response = $this->withToken($login['access_token'])
            ->getJson('/api/v1/auth/admin/server-time')
            ->assertOk()
            ->assertJsonStructure(['server_time', 'timezone', 'utc_offset'])
            ->assertJsonPath('timezone', (string) config('app.timezone'))
            ->json();

        $this->assertNotFalse(strtotime((string) $response['server_time']));
        $this->assertMatchesRegularExpression('/^[+-]\d{2}:\d{2}$/', (string) $response['utc_offset']);
    }

    public function test_central_admin_cannot_login_with_tenant_scope_without_tenant_access(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_auth',
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->assertDatabaseCount('admin_auth_sessions', 0);
    }

    public function test_tenant_admin_can_login_on_central_host_without_tenant_id(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner();
        $this->createTenant('ten_auth');
        $this->createAdmin('adm_tenant', 'tenant@example.test');
        $this->createAdminScope('scp_tenant', 'tenant', 'ten_auth', 'par_auth');
        $this->assignRoleWithPermissions('adm_tenant', 'scp_tenant', 'tenant', 'ten_auth', ['dashboard.view'], 'tenant_dashboard');

        $response = $this->postJson('/api/v1/auth/admin/login', [
            'email' => 'tenant@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
        ])
            ->assertOk()
            ->assertJsonPath('scopes.0.scope', 'tenant')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_auth')
            ->json();

        $this->assertDatabaseHas('admin_auth_sessions', [
            'admin_user_id' => 'adm_tenant',
            'access_token_hash' => hash('sha256', $response['access_token']),
            'scope_type' => 'tenant',
            'scope_id' => 'scp_tenant',
            'tenant_id' => 'ten_auth',
        ]);
    }

    public function test_partner_bo_admin_site_config_resolves_tenant_brand_and_domain(): void
    {
        $this->seedPartnerBoAuthGraph();

        $this->getJson('http://bo.partner-a.test/api/v1/public/admin-site-config')
            ->assertOk()
            ->assertJsonPath('mode', 'partner')
            ->assertJsonPath('partner.id', 'par_partner_a')
            ->assertJsonPath('partner.code', 'partner-a')
            ->assertJsonPath('partner.name', 'Partner A')
            ->assertJsonPath('tenant.id', 'ten_partner_a')
            ->assertJsonPath('tenant.code', 'partner-a')
            ->assertJsonPath('tenant.name', 'Partner A Tenant')
            ->assertJsonPath('domain.storefront_host', 'partner-a.test')
            ->assertJsonPath('domain.bo_host', 'bo.partner-a.test')
            ->assertJsonPath('brand.logo_url', 'https://cdn.partner-a.test/logo.png')
            ->assertJsonPath('brand.favicon_url', 'https://cdn.partner-a.test/favicon.ico')
            ->assertJsonPath('site.display_name', 'Partner A BO');

        $this->getJson('http://localhost/api/v1/public/admin-site-config')
            ->assertOk()
            ->assertJsonPath('mode', 'central')
            ->assertJsonPath('partner', null)
            ->assertJsonPath('tenant', null)
            ->assertJsonPath('site.display_name', 'Siamblend Back Office');
    }

    public function test_partner_bo_and_storefront_resolve_idn_domains_from_punycode_hosts(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner('par_lucky_th', 'lucky-th', 'พบโชค');
        $this->createTenant('ten_lucky_th', 'par_lucky_th', 'lucky-th', 'พบโชค Tenant');
        $this->createTenantDomain('dom_lucky_th', 'par_lucky_th', 'ten_lucky_th', 'พบโชค.localhost');
        $this->createTenantSettings('ten_lucky_th', 'พบโชค', 'พบโชค BO');
        $this->createTenantTheme('ten_lucky_th', 'https://cdn.example.test/logo.png', 'https://cdn.example.test/favicon.ico');

        $punycodeHost = 'xn--42cl1cp5p.localhost';

        $this->getJson('http://'.$punycodeHost.'/api/v1/public/site-config')
            ->assertOk()
            ->assertJsonPath('data.partner_id', 'par_lucky_th')
            ->assertJsonPath('data.tenant_id', 'ten_lucky_th');

        $this->getJson('http://bo.'.$punycodeHost.'/api/v1/public/admin-site-config')
            ->assertOk()
            ->assertJsonPath('mode', 'partner')
            ->assertJsonPath('partner.id', 'par_lucky_th')
            ->assertJsonPath('tenant.id', 'ten_lucky_th')
            ->assertJsonPath('domain.storefront_host', 'พบโชค.localhost')
            ->assertJsonPath('domain.bo_host', 'bo.'.$punycodeHost);

        $request = Request::create('/api/v1/public/site-config', 'GET', server: [
            'HTTP_HOST' => 'พบโชค.localhost',
        ]);
        (new NormalizeRequestHost())->handle($request, fn (Request $request): Response => new Response());

        $this->assertSame($punycodeHost, $request->headers->get('host'));
        $this->assertSame($punycodeHost, $request->server->get('HTTP_HOST'));

        $boRequest = Request::create('/api/v1/public/admin-site-config', 'GET', server: [
            'HTTP_HOST' => 'bo.พบโชค.localhost',
        ]);
        (new NormalizeRequestHost())->handle($boRequest, fn (Request $request): Response => new Response());

        $this->assertSame('bo.'.$punycodeHost, $boRequest->headers->get('host'));
        $this->assertSame('bo.'.$punycodeHost, $boRequest->server->get('HTTP_HOST'));
    }

    public function test_partner_bo_login_infers_tenant_and_rejects_central_or_cross_partner_access(): void
    {
        $this->seedPartnerBoAuthGraph();

        $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/login', [
            'email' => 'owner-a@example.test',
            'password' => 'secret-password',
        ])
            ->assertOk()
            ->assertJsonCount(1, 'scopes')
            ->assertJsonPath('scopes.0.scope', 'tenant')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_partner_a');

        $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/login', [
            'email' => 'central-only@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/login', [
            'email' => 'owner-a@example.test',
            'password' => 'secret-password',
            'scope' => 'tenant',
            'tenant_id' => 'ten_partner_b',
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');

        $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/login', [
            'email' => 'owner-b@example.test',
            'password' => 'secret-password',
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');
    }

    public function test_partner_bo_me_and_refresh_require_host_tenant_and_filter_scopes(): void
    {
        $this->seedPartnerBoAuthGraph();

        $login = $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/login', [
            'email' => 'multi-scope@example.test',
            'password' => 'secret-password',
        ])
            ->assertOk()
            ->assertJsonCount(1, 'scopes')
            ->assertJsonPath('scopes.0.scope', 'tenant')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_partner_a')
            ->json();

        $this->withToken($login['access_token'])
            ->getJson('http://bo.partner-a.test/api/v1/auth/admin/me')
            ->assertOk()
            ->assertJsonPath('active_scope', 'tenant')
            ->assertJsonPath('active_tenant_id', 'ten_partner_a')
            ->assertJsonCount(1, 'scopes')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_partner_a');

        $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/refresh', [
            'refresh_token' => $login['refresh_token'],
        ])
            ->assertOk()
            ->assertJsonCount(1, 'scopes')
            ->assertJsonPath('scopes.0.tenant_id', 'ten_partner_a');

        $central = $this->loginAdmin([
            'email' => 'central-only@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);

        $this->withToken($central['access_token'])
            ->getJson('http://bo.partner-a.test/api/v1/auth/admin/me')
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');

        $this->postJson('http://bo.partner-a.test/api/v1/auth/admin/refresh', [
            'refresh_token' => $central['refresh_token'],
        ])
            ->assertUnauthorized()
            ->assertJsonPath('error.code', 'authentication_required');
    }

    /**
     * @return array<string, mixed>
     */
    private function createCentralAdminSession(): array
    {
        $this->seedDefaultRbac();
        $this->createAdmin('adm_central', 'central@example.test');
        $this->createAdminScope('scp_central', 'central');
        $this->assignRoleWithPermissions('adm_central', 'scp_central', 'central', null, ['dashboard.view'], 'central_dashboard');

        return $this->loginAdmin([
            'email' => 'central@example.test',
            'password' => 'secret-password',
            'scope' => 'central',
        ]);
    }

    private function assertActiveAccessToken(string $accessToken): void
    {
        $this->assertDatabaseHas('admin_auth_sessions', [
            'access_token_hash' => hash('sha256', $accessToken),
            'revoked_at' => null,
        ]);
    }

    private function seedPartnerBoAuthGraph(): void
    {
        $this->seedDefaultRbac();
        $this->createPartner('par_partner_a', 'partner-a', 'Partner A');
        $this->createTenant('ten_partner_a', 'par_partner_a', 'partner-a', 'Partner A Tenant');
        $this->createTenantDomain('dom_partner_a', 'par_partner_a', 'ten_partner_a', 'partner-a.test');
        $this->createTenantSettings('ten_partner_a', 'Partner A Lucky', 'Partner A BO');
        $this->createTenantTheme(
            'ten_partner_a',
            'https://cdn.partner-a.test/logo.png',
            'https://cdn.partner-a.test/favicon.ico',
        );

        $this->createPartner('par_partner_b', 'partner-b', 'Partner B');
        $this->createTenant('ten_partner_b', 'par_partner_b', 'partner-b', 'Partner B Tenant');
        $this->createTenantDomain('dom_partner_b', 'par_partner_b', 'ten_partner_b', 'partner-b.test');

        $this->createAdmin('adm_owner_a', 'owner-a@example.test');
        $this->createAdminScope('scp_partner_a', 'tenant', 'ten_partner_a', 'par_partner_a');
        $this->assignRoleWithPermissions(
            'adm_owner_a',
            'scp_partner_a',
            'tenant',
            'ten_partner_a',
            ['dashboard.view', 'order.view'],
            'partner_a_owner',
        );

        $this->createAdmin('adm_owner_b', 'owner-b@example.test');
        $this->createAdminScope('scp_partner_b', 'tenant', 'ten_partner_b', 'par_partner_b');
        $this->assignRoleWithPermissions(
            'adm_owner_b',
            'scp_partner_b',
            'tenant',
            'ten_partner_b',
            ['dashboard.view'],
            'partner_b_owner',
        );

        $this->createAdmin('adm_central_only', 'central-only@example.test');
        $this->createAdminScope('scp_central_only', 'central');
        $this->assignRoleWithPermissions(
            'adm_central_only',
            'scp_central_only',
            'central',
            null,
            ['dashboard.view'],
            'central_only',
        );

        $this->createAdmin('adm_multi_scope', 'multi-scope@example.test');
        $this->createAdminScope('scp_multi_central', 'central');
        $this->createAdminScope('scp_multi_partner_a', 'tenant', 'ten_partner_a', 'par_partner_a');
        $this->createAdminScope('scp_multi_partner_b', 'tenant', 'ten_partner_b', 'par_partner_b');
        $this->assignRoleWithPermissions(
            'adm_multi_scope',
            'scp_multi_central',
            'central',
            null,
            ['dashboard.view'],
            'multi_central',
        );
        $this->assignRoleWithPermissions(
            'adm_multi_scope',
            'scp_multi_partner_a',
            'tenant',
            'ten_partner_a',
            ['dashboard.view', 'order.view'],
            'multi_partner_a',
        );
        $this->assignRoleWithPermissions(
            'adm_multi_scope',
            'scp_multi_partner_b',
            'tenant',
            'ten_partner_b',
            ['dashboard.view'],
            'multi_partner_b',
        );
    }
}
