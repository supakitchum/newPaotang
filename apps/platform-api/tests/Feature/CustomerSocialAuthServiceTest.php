<?php

namespace Tests\Feature;

use App\Modules\Auth\Http\Controllers\CustomerSocialAuthController;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Auth\Services\CustomerRealtimeAuthService;
use App\Modules\Auth\Services\TenantSocialAuthService;
use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use App\Modules\Partner\Services\PartnerProvisioningService;
use App\Modules\Tenancy\Services\TenantConfigurationService;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
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

    public function test_google_callback_exchange_creates_social_link_handoff(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');
        Http::fake([
            'https://oauth2.googleapis.com/token' => Http::response([
                'access_token' => 'google-access-token',
                'token_type' => 'Bearer',
            ]),
            'https://openidconnect.googleapis.com/v1/userinfo' => Http::response([
                'sub' => 'google-user-1',
                'name' => 'Google Customer',
                'email' => 'google@example.test',
                'picture' => 'https://images.example.test/google-user-1.jpg',
            ]),
        ]);

        $login = $this->loginResponse('google', 'social-store.test');
        parse_str((string) parse_url((string) ($login['url'] ?? ''), PHP_URL_QUERY), $loginQuery);
        $response = $this->callbackResponse('google', 'social-store.test', [
            'code' => 'google-code',
            'state' => $loginQuery['state'] ?? '',
        ]);
        $payload = json_decode((string) $response->getContent(), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(200, $response->getStatusCode(), (string) $response->getContent());
        $this->assertTrue((bool) ($payload['social_link_required'] ?? false));
        $this->assertSame('google', $payload['provider'] ?? null);
        $this->assertSame('Google Customer', $payload['profile']['display_name'] ?? null);
        $this->assertSame('google@example.test', $payload['profile']['email'] ?? null);
        $this->assertNotEmpty($payload['link_token'] ?? null);
    }

    public function test_social_onboarding_rejects_invalid_otp_without_creating_customer(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedSocialLinkToken(
            provider: 'google',
            providerUserId: 'google-new-customer-invalid',
            plainToken: 'social-link-invalid-otp',
        );

        $this->postJson('http://social-store.test/api/v1/customer/auth/social/google/link-phone', [
            'link_token' => 'social-link-invalid-otp',
            'phone' => '0812345678',
            'first_name' => 'Ada',
            'last_name' => 'Lovelace',
            'password' => 'secret1234',
            'password_confirmation' => 'secret1234',
            'otp_verification_token' => 'invalid-social-otp',
            'accepted_terms' => true,
        ])->assertStatus(422)
            ->assertJsonPath('error.code', 'otp_invalid');

        $this->assertDatabaseMissing('customers', [
            'tenant_id' => 'ten_social',
            'phone' => '0812345678',
        ]);
        $this->assertDatabaseHas('customer_line_link_tokens', [
            'tenant_id' => 'ten_social',
            'token_hash' => hash('sha256', 'social-link-invalid-otp'),
            'status' => 'pending',
            'consumed_at' => null,
        ]);
    }

    public function test_social_onboarding_requires_verified_phone_and_complete_member_profile(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedSocialLinkToken(
            provider: 'google',
            providerUserId: 'google-new-customer',
            plainToken: 'social-link-valid',
        );
        $this->seedVerifiedOtp('0812345678', 'verified-social-otp');

        $this->postJson('http://social-store.test/api/v1/customer/auth/social/google/link-phone', [
            'link_token' => 'social-link-valid',
            'phone' => '0812345678',
            'first_name' => 'Ada',
            'last_name' => 'Lovelace',
            'password' => 'secret1234',
            'password_confirmation' => 'secret1234',
            'otp_verification_token' => 'verified-social-otp',
            'accepted_terms' => true,
        ])->assertOk()
            ->assertJsonPath('session_activation_required', true)
            ->assertJsonPath('user.first_name', 'Ada')
            ->assertJsonPath('user.last_name', 'Lovelace');

        $customer = DB::table('customers')
            ->where('tenant_id', 'ten_social')
            ->where('phone', '0812345678')
            ->first();

        $this->assertNotNull($customer);
        $this->assertSame('Ada', $customer->first_name);
        $this->assertSame('Lovelace', $customer->last_name);
        $this->assertDatabaseHas('customer_social_identities', [
            'tenant_id' => 'ten_social',
            'customer_id' => $customer->id,
            'provider' => 'google',
            'provider_user_id' => 'google-new-customer',
        ]);
        $this->assertDatabaseHas('customer_line_link_tokens', [
            'tenant_id' => 'ten_social',
            'token_hash' => hash('sha256', 'social-link-valid'),
            'status' => 'consumed',
        ]);
        $this->assertNotNull(
            DB::table('otp_verifications')
                ->where('verification_token_hash', hash('sha256', 'verified-social-otp'))
                ->value('consumed_at'),
        );
    }

    public function test_line_social_onboarding_uses_the_same_verified_member_contract(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedSocialLinkToken(
            provider: 'line',
            providerUserId: 'line-new-customer',
            plainToken: 'line-social-link-valid',
        );
        $this->seedVerifiedOtp('0823456789', 'verified-line-social-otp');

        $this->postJson('http://social-store.test/api/v1/customer/auth/social/line/link-phone', [
            'link_token' => 'line-social-link-valid',
            'phone' => '0823456789',
            'first_name' => 'Grace',
            'last_name' => 'Hopper',
            'password' => 'secret1234',
            'password_confirmation' => 'secret1234',
            'otp_verification_token' => 'verified-line-social-otp',
            'accepted_terms' => true,
        ])->assertOk()
            ->assertJsonPath('user.first_name', 'Grace')
            ->assertJsonPath('user.last_name', 'Hopper');

        $customerId = DB::table('customers')
            ->where('tenant_id', 'ten_social')
            ->where('phone', '0823456789')
            ->value('id');

        $this->assertNotNull($customerId);
        $this->assertDatabaseHas('customer_line_identities', [
            'tenant_id' => 'ten_social',
            'customer_id' => $customerId,
            'line_user_id' => 'line-new-customer',
        ]);
    }

    public function test_customer_can_list_and_unlink_own_social_accounts(): void
    {
        $this->seedTenant('social-store.test');
        DB::table('customers')->insert([
            'id' => 'cus_social_accounts',
            'tenant_id' => 'ten_social',
            'phone' => '0899999999',
            'name' => 'Social Account Customer',
            'pin_hash' => Hash::make('123456'),
            'pin_set_at' => now(),
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('customer_social_identities')->insert([
            'id' => 'csi_social_accounts_google',
            'tenant_id' => 'ten_social',
            'customer_id' => 'cus_social_accounts',
            'provider' => 'google',
            'provider_user_id' => 'google-linked-customer',
            'email' => 'linked@example.test',
            'display_name' => 'Linked Google',
            'avatar_url' => null,
            'linked_at' => now(),
            'last_login_at' => now(),
            'metadata_json' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        $session = app(CustomerAuthService::class)->issueSession(
            'ten_social',
            'cus_social_accounts',
            pinVerifiedAt: now()->toISOString(),
        );
        $headers = ['Authorization' => 'Bearer '.$session['token']];

        $this->withHeaders($headers)
            ->getJson('http://social-store.test/api/v1/customer/auth/social/accounts')
            ->assertOk()
            ->assertJsonPath('accounts.1.provider', 'google')
            ->assertJsonPath('accounts.1.linked', true)
            ->assertJsonPath('accounts.1.display_name', 'Linked Google');

        $this->withHeaders($headers)
            ->deleteJson('http://social-store.test/api/v1/customer/auth/social/accounts/google')
            ->assertOk()
            ->assertJsonPath('accounts.1.provider', 'google')
            ->assertJsonPath('accounts.1.linked', false);

        $this->assertDatabaseMissing('customer_social_identities', [
            'tenant_id' => 'ten_social',
            'customer_id' => 'cus_social_accounts',
            'provider' => 'google',
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
        $this->assertArrayNotHasKey('scope', $query);
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

    public function test_apple_callback_exchange_validates_claims_and_creates_social_link_handoff(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('apple');
        $privateKey = openssl_pkey_new([
            'private_key_type' => OPENSSL_KEYTYPE_EC,
            'curve_name' => 'prime256v1',
        ]);
        $this->assertNotFalse($privateKey);
        $exported = openssl_pkey_export($privateKey, $privateKeyPem);
        $this->assertTrue($exported);
        DB::table('tenant_social_auth_providers')
            ->where('tenant_id', 'ten_social')
            ->where('provider', 'apple')
            ->update(['private_key_encrypted' => Crypt::encryptString($privateKeyPem)]);
        Http::fake([
            'https://appleid.apple.com/auth/token' => Http::response([
                'access_token' => 'apple-access-token',
                'token_type' => 'Bearer',
                'id_token' => $this->testJwt([
                    'sub' => 'apple-user-1',
                    'iss' => 'https://appleid.apple.com',
                    'aud' => 'apple-client-id',
                    'exp' => time() + 600,
                    'email' => 'apple@example.test',
                ]),
            ]),
        ]);

        $login = $this->loginResponse('apple', 'social-store.test');
        parse_str((string) parse_url((string) ($login['url'] ?? ''), PHP_URL_QUERY), $loginQuery);
        $response = $this->callbackResponse('apple', 'social-store.test', [
            'code' => 'apple-code',
            'state' => $loginQuery['state'] ?? '',
        ]);
        $payload = json_decode((string) $response->getContent(), true, 512, JSON_THROW_ON_ERROR);

        $this->assertSame(200, $response->getStatusCode(), (string) $response->getContent());
        $this->assertTrue((bool) ($payload['social_link_required'] ?? false));
        $this->assertSame('apple', $payload['provider'] ?? null);
        $this->assertSame('apple@example.test', $payload['profile']['email'] ?? null);
        $this->assertNotEmpty($payload['link_token'] ?? null);
        Http::assertSent(fn ($request): bool => $request->url() === 'https://appleid.apple.com/auth/token'
            && $request['client_id'] === 'apple-client-id'
            && $request['code'] === 'apple-code'
            && count(explode('.', (string) $request['client_secret'])) === 3);
    }

    public function test_facebook_login_and_callback_exchange_use_tenant_credentials(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('facebook');
        Http::fake([
            'https://graph.facebook.com/v25.0/oauth/access_token' => Http::response([
                'access_token' => 'facebook-access-token',
                'token_type' => 'bearer',
            ]),
            'https://graph.facebook.com/v25.0/me*' => Http::response([
                'id' => 'facebook-user-1',
                'name' => 'Facebook Customer',
                'email' => 'facebook@example.test',
                'picture' => ['data' => ['url' => 'https://images.example.test/facebook-user-1.jpg']],
            ]),
        ]);

        $login = $this->loginResponse('facebook', 'social-store.test');
        parse_str((string) parse_url((string) ($login['url'] ?? ''), PHP_URL_QUERY), $loginQuery);

        $this->assertSame('facebook-client-id', $loginQuery['client_id'] ?? null);
        $this->assertSame('http://social-store.test/social/facebook/callback', $loginQuery['redirect_uri'] ?? null);
        $this->assertSame('public_profile,email', $loginQuery['scope'] ?? null);

        $response = $this->callbackResponse('facebook', 'social-store.test', [
            'code' => 'facebook-code',
            'state' => $loginQuery['state'] ?? '',
        ]);

        $this->assertSame(200, $response->getStatusCode(), (string) $response->getContent());
        $payload = json_decode((string) $response->getContent(), true, 512, JSON_THROW_ON_ERROR);
        $this->assertTrue((bool) ($payload['social_link_required'] ?? false));
        $this->assertSame('facebook', $payload['provider'] ?? null);
        $this->assertSame('Facebook Customer', $payload['profile']['display_name'] ?? null);
        $this->assertSame('facebook@example.test', $payload['profile']['email'] ?? null);
        $this->assertNotEmpty($payload['link_token'] ?? null);

        Http::assertSent(fn ($request): bool => $request->url() === 'https://graph.facebook.com/v25.0/oauth/access_token'
            && $request['client_id'] === 'facebook-client-id'
            && $request['client_secret'] === 'facebook-secret'
            && $request['code'] === 'facebook-code');
        Http::assertSent(fn ($request): bool => str_starts_with($request->url(), 'https://graph.facebook.com/v25.0/me')
            && $request['fields'] === 'id,name,email,picture.width(256).height(256)'
            && $request['appsecret_proof'] === hash_hmac('sha256', 'facebook-access-token', 'facebook-secret'));
    }

    public function test_tenant_social_settings_return_storefront_callback_urls(): void
    {
        $this->seedTenant('social-store.test');

        $settings = app(TenantSocialAuthService::class)->settings('ten_social');
        $callbacks = $settings['data']['callback_urls'] ?? [];

        $this->assertSame('http://social-store.test/line/callback', $callbacks['line'] ?? null);
        $this->assertSame('http://social-store.test/social/google/callback', $callbacks['google'] ?? null);
        $this->assertSame('http://social-store.test/social/apple/callback', $callbacks['apple'] ?? null);
        $this->assertSame('http://social-store.test/social/facebook/callback', $callbacks['facebook'] ?? null);
    }

    public function test_mobile_bootstrap_social_flags_follow_enabled_provider_configuration(): void
    {
        $this->seedTenant('social-store.test');
        $this->seedProvider('google');
        $this->seedProvider('facebook');

        $response = $this->getJson('http://social-store.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->json('data.mobile');

        $this->assertSame(['google', 'facebook'], array_column($response['auth_providers'] ?? [], 'provider'));
        $this->assertTrue((bool) ($response['feature_flags']['social_login_google'] ?? false));
        $this->assertFalse((bool) ($response['feature_flags']['social_login_apple'] ?? true));
        $this->assertTrue((bool) ($response['feature_flags']['social_login_facebook'] ?? false));
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
        $this->assertFalse((bool) ($flags['social_login_facebook'] ?? true));
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
            '/profile/social-accounts',
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

    public function test_facebook_provider_settings_encrypt_tenant_app_credentials(): void
    {
        $this->seedTenant('social-store.test');

        $result = app(TenantSocialAuthService::class)->update('ten_social', 'facebook', [
            'status' => 'active',
            'client_id' => 'tenant-facebook-app-id',
            'client_secret' => 'tenant-facebook-app-secret',
            'display_label' => 'Continue with Facebook',
        ]);

        $this->assertArrayNotHasKey('error', $result);
        $record = DB::table('tenant_social_auth_providers')
            ->where('tenant_id', 'ten_social')
            ->where('provider', 'facebook')
            ->first();
        $provider = collect($result['resource']['data']['providers'] ?? [])
            ->firstWhere('provider', 'facebook');
        $metadata = json_decode((string) ($record?->metadata_json ?? '{}'), true, 512, JSON_THROW_ON_ERROR);

        $this->assertNotSame('tenant-facebook-app-id', $record?->client_id_encrypted);
        $this->assertNotSame('tenant-facebook-app-secret', $record?->client_secret_encrypted);
        $this->assertSame('tenant-facebook-app-id', Crypt::decryptString((string) $record?->client_id_encrypted));
        $this->assertSame('tenant-facebook-app-secret', Crypt::decryptString((string) $record?->client_secret_encrypted));
        $this->assertSame(['public_profile', 'email'], $metadata['scopes'] ?? null);
        $this->assertSame('Continue with Facebook', $provider['label'] ?? null);
        $this->assertTrue((bool) ($provider['ready'] ?? false));
        $this->assertArrayNotHasKey('client_secret', $provider);
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

    public function test_line_login_credentials_are_managed_from_social_login_without_configuring_messaging(): void
    {
        $this->seedTenant('social-store.test');

        $result = app(TenantSocialAuthService::class)->update('ten_social', 'line', [
            'login_channel_id' => 'tenant-line-login-id',
            'login_channel_secret' => 'tenant-line-login-secret',
            'liff_id' => '1234567890-AbCdEf',
            'display_label' => 'Continue with LINE',
        ]);

        $this->assertArrayNotHasKey('error', $result);
        $channel = DB::table('tenant_line_channels')->where('tenant_id', 'ten_social')->first();
        $provider = collect($result['resource']['data']['providers'] ?? [])->firstWhere('provider', 'line');
        $notificationSettings = app(TenantLineNotificationService::class)->showSettings('ten_social');

        $this->assertNotSame('tenant-line-login-id', $channel?->login_channel_id_encrypted);
        $this->assertSame('tenant-line-login-id', Crypt::decryptString((string) $channel?->login_channel_id_encrypted));
        $this->assertSame('1234567890-AbCdEf', $provider['liff_id'] ?? null);
        $this->assertTrue((bool) ($provider['configured'] ?? false));
        $this->assertTrue((bool) ($provider['ready'] ?? false));
        $this->assertFalse((bool) ($notificationSettings['connection']['configured'] ?? true));
        $this->assertArrayNotHasKey('login_channel_id_masked', $notificationSettings['connection']);
    }

    public function test_disconnecting_line_login_preserves_messaging_credentials(): void
    {
        $this->seedTenant('social-store.test');
        Http::fake([
            'api.line.me/v2/oauth/verify' => Http::response(['client_id' => 'messaging-channel'], 200),
            'api.line.me/v2/bot/info' => Http::response(['userId' => 'Ubot123', 'basicId' => '@socialstore'], 200),
        ]);

        app(TenantLineNotificationService::class)->updateConnection('ten_social', [
            'messaging_access_token' => 'messaging-token',
            'messaging_channel_secret' => 'messaging-secret',
            'status' => 'active',
        ]);
        app(TenantSocialAuthService::class)->update('ten_social', 'line', [
            'login_channel_id' => 'tenant-line-login-id',
            'login_channel_secret' => 'tenant-line-login-secret',
        ]);

        $result = app(TenantSocialAuthService::class)->disconnect('ten_social', 'line');
        $channel = DB::table('tenant_line_channels')->where('tenant_id', 'ten_social')->first();

        $this->assertArrayNotHasKey('error', $result);
        $this->assertNull($channel?->login_channel_id_encrypted);
        $this->assertNull($channel?->login_channel_secret_encrypted);
        $this->assertNotNull($channel?->messaging_access_token_encrypted);
        $this->assertTrue((bool) (app(TenantLineNotificationService::class)->showSettings('ten_social')['connection']['configured'] ?? false));
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

    /**
     * @param array<string, mixed> $query
     */
    private function callbackResponse(string $provider, string $host, array $query): \Illuminate\Http\JsonResponse
    {
        $request = Request::create(
            '/api/v1/customer/auth/social/'.$provider.'/callback',
            'GET',
            $query,
            [],
            [],
            ['HTTP_HOST' => $host],
        );

        return app(CustomerSocialAuthController::class)->callback($request, $provider);
    }

    /**
     * @param array<string, mixed> $claims
     */
    private function testJwt(array $claims): string
    {
        $encode = static fn (array $value): string => rtrim(strtr(base64_encode(
            json_encode($value, JSON_THROW_ON_ERROR),
        ), '+/', '-_'), '=');

        return $encode(['alg' => 'none']).'.'.$encode($claims).'.test-signature';
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
            'client_secret_encrypted' => match ($provider) {
                'google' => Crypt::encryptString('google-secret'),
                'facebook' => Crypt::encryptString('facebook-secret'),
                default => null,
            },
            'team_id_encrypted' => $provider === 'apple' ? Crypt::encryptString('TEAMID') : null,
            'key_id_encrypted' => $provider === 'apple' ? Crypt::encryptString('KEYID') : null,
            'private_key_encrypted' => $provider === 'apple' ? Crypt::encryptString('private-key') : null,
            'redirect_uri' => null,
            'metadata_json' => json_encode(['test' => true], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function seedSocialLinkToken(
        string $provider,
        string $providerUserId,
        string $plainToken,
    ): void {
        DB::table('customer_line_link_tokens')->insert([
            'id' => 'clt_'.substr(hash('sha256', $plainToken), 0, 20),
            'tenant_id' => 'ten_social',
            'token_hash' => hash('sha256', $plainToken),
            'line_user_id' => $provider === 'line'
                ? $providerUserId
                : $provider.':'.$providerUserId,
            'display_name' => 'New Social Customer',
            'picture_url' => null,
            'friend_flag' => false,
            'status' => 'pending',
            'expires_at' => now()->addMinutes(15),
            'consumed_at' => null,
            'metadata_json' => json_encode([
                'provider' => $provider,
                'profile' => [
                    'id' => $providerUserId,
                    'display_name' => 'New Social Customer',
                    'email' => 'new-social@example.test',
                    'avatar_url' => null,
                ],
            ], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function seedVerifiedOtp(string $phone, string $plainToken): void
    {
        DB::table('otp_verifications')->insert([
            'id' => 'otp_'.substr(hash('sha256', $plainToken), 0, 20),
            'tenant_id' => 'ten_social',
            'provider_id' => null,
            'provider' => 'test',
            'purpose' => 'register',
            'phone' => $phone,
            'phone_normalized' => $phone,
            'otp_hash' => 'not-used-after-verification',
            'verification_token_hash' => hash('sha256', $plainToken),
            'status' => 'verified',
            'attempts' => 1,
            'max_attempts' => 5,
            'expires_at' => now()->addMinutes(10),
            'cooldown_until' => null,
            'verified_at' => now(),
            'consumed_at' => null,
            'requested_ip' => '127.0.0.1',
            'requested_user_agent' => 'social-onboarding-test',
            'metadata_json' => null,
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
