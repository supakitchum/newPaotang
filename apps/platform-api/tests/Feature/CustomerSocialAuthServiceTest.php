<?php

namespace Tests\Feature;

use App\Modules\Auth\Http\Controllers\CustomerSocialAuthController;
use App\Modules\Auth\Services\TenantSocialAuthService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class CustomerSocialAuthServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['app.key' => 'base64:'.base64_encode(str_repeat('b', 32))]);
        $this->app->forgetInstance('encrypter');
    }

    public function test_google_login_uses_storefront_callback_url(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');

        $response = $this->loginResponse('google', 'social-store.test');
        parse_str((string) parse_url((string) ($response['url'] ?? ''), PHP_URL_QUERY), $query);

        $this->assertSame('http://social-store.test/social/google/callback', $query['redirect_uri'] ?? null);
        $this->assertStringNotContainsString('/api/v1/', (string) ($query['redirect_uri'] ?? ''));
        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_social',
            'provider' => 'google',
            'redirect_uri' => 'http://social-store.test/social/google/callback',
            'status' => 'pending',
        ]);
    }

    public function test_google_login_on_api_host_uses_tenant_host_callback_url(): void
    {
        $this->seedTenant('social-store.example.com');
        $this->seedProvider('google');

        $response = $this->loginResponse('google', 'api.newpaotang.example.com', 'social-store.example.com');
        parse_str((string) parse_url((string) ($response['url'] ?? ''), PHP_URL_QUERY), $query);

        $this->assertSame('https://social-store.example.com/social/google/callback', $query['redirect_uri'] ?? null);
        $this->assertStringNotContainsString('api.newpaotang.example.com', (string) ($query['redirect_uri'] ?? ''));
        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_social',
            'provider' => 'google',
            'redirect_uri' => 'https://social-store.example.com/social/google/callback',
            'status' => 'pending',
        ]);
    }

    public function test_apple_login_uses_storefront_callback_url_with_query_response_mode(): void
    {
        $this->seedTenant('social-store.example.com');
        $this->seedProvider('apple');

        $response = $this->loginResponse('apple', 'social-store.example.com');
        parse_str((string) parse_url((string) ($response['url'] ?? ''), PHP_URL_QUERY), $query);

        $this->assertSame('https://social-store.example.com/social/apple/callback', $query['redirect_uri'] ?? null);
        $this->assertSame('query', $query['response_mode'] ?? null);
        $this->assertStringNotContainsString('/api/v1/', (string) ($query['redirect_uri'] ?? ''));
        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_social',
            'provider' => 'apple',
            'redirect_uri' => 'https://social-store.example.com/social/apple/callback',
            'status' => 'pending',
        ]);
    }

    public function test_apple_login_on_api_host_uses_tenant_host_callback_url(): void
    {
        $this->seedTenant('social-store.example.com');
        $this->seedProvider('apple');

        $response = $this->loginResponse('apple', 'api.newpaotang.example.com', 'social-store.example.com');
        parse_str((string) parse_url((string) ($response['url'] ?? ''), PHP_URL_QUERY), $query);

        $this->assertSame('https://social-store.example.com/social/apple/callback', $query['redirect_uri'] ?? null);
        $this->assertSame('query', $query['response_mode'] ?? null);
        $this->assertStringNotContainsString('api.newpaotang.example.com', (string) ($query['redirect_uri'] ?? ''));
        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_social',
            'provider' => 'apple',
            'redirect_uri' => 'https://social-store.example.com/social/apple/callback',
            'status' => 'pending',
        ]);
    }

    public function test_tenant_social_settings_return_storefront_callback_urls(): void
    {
        $this->seedTenant('social-store.test');

        $settings = app(TenantSocialAuthService::class)->settings('ten_social');
        $callbacks = $settings['data']['callback_urls'] ?? [];

        $this->assertSame('http://social-store.test/line/callback', $callbacks['line'] ?? null);
        $this->assertSame('http://social-store.test/social/google/callback', $callbacks['google'] ?? null);
        $this->assertSame('http://social-store.test/social/apple/callback', $callbacks['apple'] ?? null);
    }

    public function test_mobile_bootstrap_social_flags_follow_enabled_provider_configuration(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');

        $response = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile');

        $this->assertSame(['google'], array_column($response['auth_providers'] ?? [], 'provider'));
        $this->assertTrue((bool) ($response['feature_flags']['social_login_google'] ?? false));
        $this->assertFalse((bool) ($response['feature_flags']['social_login_apple'] ?? true));
    }

    public function test_mobile_bootstrap_marks_financial_identity_routes_as_sensitive(): void
    {
        $this->seedTenant('social-store.test');

        $routes = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile.screen_security.sensitive_routes');

        $this->assertIsArray($routes);
        $this->assertEmpty(array_diff([
            '/cart',
            '/checkout',
            '/success',
            '/pin',
            '/tickets',
            '/tickets/history',
            '/tickets/view',
            '/tickets/claim',
            '/my-wallet',
            '/topup',
            '/topup/history',
            '/reward-claims',
            '/activity-claims',
            '/affiliate',
            '/profile',
            '/profile/auto-reward',
            '/profile/biometrics',
            '/profile/line-notifications',
            '/profile/reward-bank',
            '/purchase-history',
        ], $routes));
    }

    /**
     * @return array<string, mixed>
     */
    private function loginResponse(string $provider, string $host, ?string $tenantHost = null): array
    {
        $controller = app(CustomerSocialAuthController::class);
        $server = ['HTTP_HOST' => $host];

        if ($tenantHost !== null) {
            $server['HTTP_X_TENANT_HOST'] = $tenantHost;
        }

        $request = Request::create(
            '/api/v1/customer/auth/social/'.$provider.'/login',
            'POST',
            ['purpose' => 'login'],
            [],
            [],
            $server,
        );
        $result = $controller->login($request, $provider);

        $this->assertSame(200, $result->getStatusCode(), (string) $result->getContent());

        return json_decode((string) $result->getContent(), true, 512, JSON_THROW_ON_ERROR);
    }

    private function seedTenant(string $host): void
    {
        DB::table('partners')->insert([
            'id' => 'par_social',
            'code' => 'par_social',
            'name' => 'Social Partner',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            'id' => 'ten_social',
            'partner_id' => 'par_social',
            'code' => 'social',
            'name' => 'Social Tenant',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenant_domains')->insert([
            'id' => 'ptd_social',
            'partner_id' => 'par_social',
            'tenant_id' => 'ten_social',
            'host' => $host,
            'type' => 'subdomain',
            'status' => 'active',
            'is_primary' => true,
            'verified_at' => now(),
            'ssl_ready_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function seedProvider(string $provider): void
    {
        DB::table('tenant_social_auth_providers')->insert([
            'id' => 'tsa_'.$provider,
            'tenant_id' => 'ten_social',
            'provider' => $provider,
            'status' => 'active',
            'client_id_encrypted' => Crypt::encryptString($provider.'-client-id'),
            'client_secret_encrypted' => $provider === 'google' ? Crypt::encryptString('google-secret') : null,
            'team_id_encrypted' => $provider === 'apple' ? Crypt::encryptString('TEAMID') : null,
            'key_id_encrypted' => $provider === 'apple' ? Crypt::encryptString('KEYID') : null,
            'private_key_encrypted' => $provider === 'apple' ? Crypt::encryptString('private-key') : null,
            'redirect_uri' => null,
            'metadata_json' => json_encode(['test' => true], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
