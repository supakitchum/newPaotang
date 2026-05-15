<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
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
                'user' => ['id', 'name', 'email', 'status', 'two_factor_enabled'],
                'scopes' => [['scope', 'tenant_id', 'tenant_name', 'permissions']],
            ])
            ->assertJsonPath('user.id', 'adm_central')
            ->assertJsonPath('user.email', 'central@example.test')
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
            ->getJson('/api/v1/auth/admin/me')
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
            ->assertJsonPath('active_scope', 'central')
            ->assertJsonPath('active_tenant_id', null)
            ->assertJsonPath('scopes.0.permissions.0', 'dashboard.view');
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

        $this->assertDatabaseCount('admin_auth_sessions', 0);
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
}
