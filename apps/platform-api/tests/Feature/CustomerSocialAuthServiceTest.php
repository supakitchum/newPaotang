<?php

namespace Tests\Feature;

use App\Modules\Auth\Http\Controllers\CustomerSocialAuthController;
use App\Modules\Auth\Services\CustomerRealtimeAuthService;
use App\Modules\Auth\Services\TenantSocialAuthService;
use App\Modules\Partner\Services\PartnerProvisioningService;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use App\Shared\Auth\CustomerSessionContext;
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

    public function test_mobile_bootstrap_merges_tenant_feature_flags_without_overriding_social_provider_config(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');
        DB::table('partner_tenant_feature_flags')->insert([
            [
                'id' => 'ptff_bio',
                'tenant_id' => 'ten_social',
                'feature_key' => 'native_biometric_unlock',
                'enabled' => false,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'ptff_screen',
                'tenant_id' => 'ten_social',
                'feature_key' => 'screen_security_native',
                'enabled' => false,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'ptff_google',
                'tenant_id' => 'ten_social',
                'feature_key' => 'social_login_google',
                'enabled' => false,
                'created_at' => now(),
                'updated_at' => now(),
            ],
            [
                'id' => 'ptff_custom',
                'tenant_id' => 'ten_social',
                'feature_key' => 'custom_mobile_gate',
                'enabled' => true,
                'created_at' => now(),
                'updated_at' => now(),
            ],
        ]);

        $flags = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile.feature_flags');

        $this->assertFalse((bool) ($flags['native_biometric_unlock'] ?? true));
        $this->assertFalse((bool) ($flags['screen_security_native'] ?? true));
        $this->assertTrue((bool) ($flags['custom_mobile_gate'] ?? false));
        $this->assertTrue((bool) ($flags['social_login_google'] ?? false));
        $this->assertFalse((bool) ($flags['social_login_apple'] ?? true));
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

    public function test_mobile_bootstrap_exposes_runtime_social_provider_appearance(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');
        DB::table('tenant_social_auth_providers')
            ->where('tenant_id', 'ten_social')
            ->where('provider', 'google')
            ->update([
                'metadata_json' => json_encode([
                    'test' => true,
                    'appearance' => [
                        'display_label' => 'Continue with Search Account',
                        'brand_color' => '#123456',
                        'button_background_color' => '#234567',
                        'button_foreground_color' => '#FFFFFF',
                    ],
                ], JSON_THROW_ON_ERROR),
            ]);

        $providers = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile.auth_providers');
        $provider = collect($providers)->firstWhere('provider', 'google');

        $this->assertSame('Continue with Search Account', $provider['label'] ?? null);
        $this->assertSame('#123456', $provider['brand_color'] ?? null);
        $this->assertSame('#234567', $provider['button_background_color'] ?? null);
        $this->assertSame('#FFFFFF', $provider['button_foreground_color'] ?? null);
    }

    public function test_mobile_bootstrap_uses_tenant_realtime_url_and_server_connection_metadata(): void
    {
        config([
            'platform.realtime.customer_public_url' => 'https://global-realtime.example.test/socket',
            'broadcasting.connections.reverb.key' => 'customer-runtime-key',
            'broadcasting.connections.reverb.secret' => 'customer-runtime-secret',
            'platform.realtime.customer_client' => 'customer-mobile-runtime',
            'platform.realtime.customer_auth_endpoint' => '/customer/realtime/auth',
            'platform.realtime.customer_protocol' => 8,
        ]);
        $this->seedTenant('social-store.test');
        $this->seedTenantSettings('wss://tenant-realtime.example.test/reverb');

        $realtime = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile.realtime');

        $this->assertTrue((bool) ($realtime['enabled'] ?? false));
        $this->assertSame('wss://tenant-realtime.example.test/reverb', $realtime['url'] ?? null);
        $this->assertSame('customer-runtime-key', $realtime['key'] ?? null);
        $this->assertSame('customer-mobile-runtime', $realtime['client'] ?? null);
        $this->assertSame('/customer/realtime/auth', $realtime['auth_endpoint'] ?? null);
        $this->assertSame(8, $realtime['protocol'] ?? null);

        $authorization = app(CustomerRealtimeAuthService::class)->authorize(
            new CustomerSessionContext(
                ['tenant_id' => 'ten_social', 'customer_id' => 'cus_social'],
                ['name' => 'Realtime Customer'],
            ),
            [
                'socket_id' => '123.456',
                'channel_name' => 'private-customer.tenant.ten_social.customer.cus_social.orders',
            ],
        );

        $this->assertStringStartsWith('customer-runtime-key:', (string) ($authorization['auth'] ?? ''));
    }

    public function test_mobile_bootstrap_ignores_invalid_tenant_realtime_url_and_uses_safe_global_fallback(): void
    {
        config([
            'platform.realtime.customer_public_url' => 'https://global-realtime.example.test/socket',
            'broadcasting.connections.reverb.key' => 'customer-runtime-key',
        ]);
        $this->seedTenant('social-store.test');
        $this->seedTenantSettings('javascript:alert(1)');

        $realtime = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile.realtime');

        $this->assertTrue((bool) ($realtime['enabled'] ?? false));
        $this->assertSame('https://global-realtime.example.test/socket', $realtime['url'] ?? null);
    }

    public function test_realtime_url_validation_is_shared_by_tenant_profile_and_provisioning_writes(): void
    {
        $invalidUrl = 'wss://user:secret@realtime.example.test/socket#token';

        $tenantErrors = app(TenantConfigurationService::class)->validateSettingsPayload('ten_social', [
            'api' => ['realtime_url' => $invalidUrl],
        ]);
        $profileErrors = app(PartnerProvisioningService::class)->validatePartnerTenantProfilePayload('par_social', [
            'section' => 'settings',
            'settings' => ['api' => ['realtime_url' => $invalidUrl]],
        ]);
        $provisionErrors = app(PartnerProvisioningService::class)->validateProvisionPayload([
            'owner_email' => 'owner@example.test',
            'realtime_url' => $invalidUrl,
        ]);

        $this->assertArrayHasKey('realtime_url', $tenantErrors);
        $this->assertArrayHasKey('realtime_url', $profileErrors);
        $this->assertArrayHasKey('realtime_url', $provisionErrors);

        foreach (['https://realtime.example.test', 'wss://realtime.example.test/socket?cluster=tenant'] as $validUrl) {
            $errors = app(TenantConfigurationService::class)->validateSettingsPayload('ten_social', [
                'api' => ['realtime_url' => $validUrl],
            ]);
            $this->assertArrayNotHasKey('realtime_url', $errors);
        }
    }

    public function test_social_provider_update_preserves_metadata_and_persists_appearance(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');

        $result = app(TenantSocialAuthService::class)->update('ten_social', 'google', [
            'status' => 'active',
            'display_label' => 'Google Customer',
            'brand_color' => '#4285f4',
            'button_background_color' => '#ffffff',
            'button_foreground_color' => '#1f2937',
        ]);

        $this->assertArrayNotHasKey('error', $result);
        $record = DB::table('tenant_social_auth_providers')
            ->where('tenant_id', 'ten_social')
            ->where('provider', 'google')
            ->first();
        $metadata = json_decode((string) ($record?->metadata_json ?? '{}'), true, 512, JSON_THROW_ON_ERROR);

        $this->assertTrue((bool) ($metadata['test'] ?? false));
        $this->assertSame(['openid', 'profile', 'email'], $metadata['scopes'] ?? null);
        $this->assertSame('Google Customer', $metadata['appearance']['display_label'] ?? null);
        $this->assertSame('#4285F4', $metadata['appearance']['brand_color'] ?? null);
        $this->assertSame('#FFFFFF', $metadata['appearance']['button_background_color'] ?? null);
        $this->assertSame('#1F2937', $metadata['appearance']['button_foreground_color'] ?? null);
    }

    public function test_line_customer_appearance_can_be_saved_without_owning_line_credentials(): void
    {
        $this->seedTenant('social-store.test');

        $result = app(TenantSocialAuthService::class)->update('ten_social', 'line', [
            'display_label' => 'LINE Member',
            'brand_color' => '#06c755',
            'button_background_color' => '#06c755',
            'button_foreground_color' => '#ffffff',
        ]);

        $this->assertArrayNotHasKey('error', $result);
        $provider = collect($result['resource']['data']['providers'] ?? [])
            ->firstWhere('provider', 'line');

        $this->assertSame('LINE Member', $provider['label'] ?? null);
        $this->assertSame('#06C755', $provider['brand_color'] ?? null);
        $this->assertFalse((bool) ($provider['configured'] ?? true));
        $this->assertDatabaseHas('tenant_social_auth_providers', [
            'tenant_id' => 'ten_social',
            'provider' => 'line',
            'status' => 'inactive',
        ]);
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

    private function seedTenantSettings(?string $realtimeUrl): void
    {
        DB::table('partner_tenant_settings')->insert([
            'id' => 'pts_social',
            'tenant_id' => 'ten_social',
            'site_name' => 'Social Tenant',
            'realtime_url' => $realtimeUrl,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
