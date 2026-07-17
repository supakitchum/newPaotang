<?php

namespace Tests\Feature;

use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Route;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class M10RemainingOpenApiRouteClosureTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_remaining_safe_route_slice_and_admin_security_line_policy_routes_are_registered(): void
    {
        $routes = collect(Route::getRoutes())->map(fn ($route): string => implode('|', $route->methods()).' '.$route->uri())->all();

        foreach ([
            'POST api/v1/admin/central/assets/uploads',
            'GET|HEAD api/v1/admin/central/assets/{asset_id}',
            'POST api/v1/admin/central/assets/{asset_id}/commit',
            'POST api/v1/admin/central/assets/{asset_id}/local-upload',
            'POST api/v1/admin/tenant/assets/uploads',
            'GET|HEAD api/v1/admin/tenant/assets/{asset_id}',
            'POST api/v1/admin/tenant/assets/{asset_id}/commit',
            'POST api/v1/admin/tenant/assets/{asset_id}/local-upload',
            'GET|HEAD api/v1/admin/tenant/payment-settings',
            'PATCH api/v1/admin/tenant/payment-settings',
            'GET|HEAD api/v1/admin/tenant/payment-channels',
            'POST api/v1/admin/tenant/payment-channels',
            'GET|HEAD api/v1/admin/tenant/payment-channels/{payment_channel_id}',
            'PATCH api/v1/admin/tenant/payment-channels/{payment_channel_id}',
            'DELETE api/v1/admin/tenant/payment-channels/{payment_channel_id}',
            'GET|HEAD api/v1/public/seo/page',
            'GET|HEAD api/v1/public/news',
            'GET|HEAD api/v1/public/news/modal',
            'GET|HEAD api/v1/public/news/{slug}',
            'GET|HEAD api/v1/public/stores',
            'GET|HEAD api/v1/admin/tenant/seo',
            'PATCH api/v1/admin/tenant/seo',
            'GET|HEAD api/v1/admin/tenant/seo/pages',
            'POST api/v1/admin/tenant/seo/pages',
            'PATCH api/v1/admin/tenant/seo/pages/{page_id}',
            'DELETE api/v1/admin/tenant/seo/pages/{page_id}',
            'GET|HEAD api/v1/admin/tenant/redirects',
            'POST api/v1/admin/tenant/redirects',
            'PATCH api/v1/admin/tenant/redirects/{redirect_id}',
            'DELETE api/v1/admin/tenant/redirects/{redirect_id}',
            'GET|HEAD api/v1/admin/tenant/announcements',
            'POST api/v1/admin/tenant/announcements',
            'GET|HEAD api/v1/admin/tenant/announcements/{announcement_id}',
            'PATCH api/v1/admin/tenant/announcements/{announcement_id}',
            'DELETE api/v1/admin/tenant/announcements/{announcement_id}',
            'POST api/v1/admin/tenant/announcements/{announcement_id}/image',
            'POST api/v1/customer/realtime/auth',
        ] as $expected) {
            $this->assertContains($expected, $routes);
        }

        foreach ([
            'POST api/v1/auth/admin/password/forgot',
            'POST api/v1/auth/admin/password/reset',
            'POST api/v1/auth/admin/password/change',
            'GET|HEAD api/v1/auth/admin/2fa',
            'DELETE api/v1/auth/admin/2fa',
            'POST api/v1/auth/admin/2fa/setup',
            'POST api/v1/auth/admin/2fa/enable',
            'POST api/v1/auth/admin/2fa/recovery-codes',
            'POST api/v1/auth/admin/2fa/verify',
            'POST api/v1/customer/auth/line/login',
            'GET|HEAD api/v1/customer/auth/line/callback',
        ] as $expected) {
            $this->assertContains($expected, $routes);
        }
    }

    public function test_asset_upload_intents_are_scoped_idempotent_and_local_dev_guarded(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_asset_m10', 'ten_asset_m10', 'asset.m10.test');

        $central = $this->createCentralSession(['asset.manage'], 'adm_central_asset', 'central-asset@example.test');
        $tenant = $this->createTenantSession('ten_asset_m10', 'par_asset_m10', ['asset.manage'], 'adm_tenant_asset', 'tenant-asset@example.test');

        $centralIntent = $this->withToken($central['access_token'])
            ->postJson('/api/v1/admin/central/assets/uploads', [
                'purpose' => 'admin_attachment',
                'file_name' => 'Central Report.pdf',
                'content_type' => 'application/pdf',
                'size_bytes' => 1024,
            ], [
                'X-Admin-Scope' => 'central',
                'Idempotency-Key' => 'central-asset-upload-m10',
            ])
            ->assertCreated()
            ->assertJsonPath('method', 'PUT')
            ->assertJsonPath('production_storage_ready', false)
            ->json();

        $this->withToken($central['access_token'])
            ->getJson('/api/v1/admin/central/assets/'.$centralIntent['asset_id'], ['X-Admin-Scope' => 'central'])
            ->assertOk()
            ->assertJsonPath('id', $centralIntent['asset_id'])
            ->assertJsonPath('tenant_id', null);

        $tenantIntent = $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/assets/uploads', [
                'purpose' => 'tenant_logo',
                'file_name' => 'logo.png',
                'content_type' => 'image/png',
                'size_bytes' => 2048,
                'metadata' => ['slot' => 'header'],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_asset_m10',
                'Idempotency-Key' => 'tenant-asset-upload-m10',
            ])
            ->assertCreated()
            ->assertJsonPath('storage_mode', 'local_dev_metadata_only')
            ->json();

        $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/assets/'.$tenantIntent['asset_id'].'/commit', [
                'metadata' => ['uploaded_by' => 'test'],
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_asset_m10',
                'Idempotency-Key' => 'tenant-asset-commit-m10',
            ])
            ->assertOk()
            ->assertJsonPath('status', 'committed')
            ->assertJsonPath('production_storage_ready', false)
            ->assertJsonPath('metadata.storage_boundary', 'local_dev_metadata_only');

        $this->assertDatabaseHas('audit_logs', [
            'action' => 'asset.committed_local_dev',
            'target_id' => $tenantIntent['asset_id'],
            'tenant_id' => 'ten_asset_m10',
        ]);
    }

    public function test_tenant_payment_settings_and_channels_redact_secrets_and_enforce_tenant_scope(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_pay_m10', 'ten_pay_m10', 'pay.m10.test');
        $this->insertActivePartnerTenantWithDomain('par_pay_other_m10', 'ten_pay_other_m10', 'pay-other.m10.test');
        $tenant = $this->createTenantSession('ten_pay_m10', 'par_pay_m10', ['payment_settings.view', 'payment_settings.manage'], 'adm_tenant_pay', 'tenant-pay@example.test');
        $otherTenant = $this->createTenantSession('ten_pay_other_m10', 'par_pay_other_m10', ['payment_settings.view'], 'adm_tenant_pay_other', 'tenant-pay-other@example.test');
        $headers = ['X-Admin-Scope' => 'tenant', 'X-Tenant-Id' => 'ten_pay_m10'];

        $providerMissingFields = $this->withToken($tenant['access_token'])
            ->patchJson('/api/v1/admin/tenant/payment-settings', [
                'config' => [
                    'payment_methods' => [
                        'qr' => ['enabled' => true, 'provider' => ''],
                    ],
                ],
            ], $headers + ['Idempotency-Key' => 'payment-settings-provider-required-m10'])
            ->assertUnprocessable()
            ->json('error.details.fields');

        $this->assertSame(
            ['Select a payment provider before enabling this payment method.'],
            $providerMissingFields['config.payment_methods.qr.provider'] ?? null,
        );

        $invalidExternalFields = $this->withToken($tenant['access_token'])
            ->patchJson('/api/v1/admin/tenant/payment-settings', [
                'allow_external_payment' => true,
                'config' => [
                    'checkout' => [
                        'external_payment' => [
                            'provider' => 'provider_test',
                            'redirect_url_template' => 'http://checkout.provider.test/pay?order_id={order_id}',
                        ],
                    ],
                ],
            ], $headers + ['Idempotency-Key' => 'payment-settings-invalid-external-m10'])
            ->assertUnprocessable()
            ->json('error.details.fields');

        $this->assertSame(
            ['The external checkout redirect URL template must be an absolute HTTPS URL without credentials or fragments and must contain {order_id}.'],
            $invalidExternalFields['config.checkout.external_payment.redirect_url_template'] ?? null,
        );

        $settings = $this->withToken($tenant['access_token'])
            ->patchJson('/api/v1/admin/tenant/payment-settings', [
                'provider_mode' => 'external_configured',
                'allow_external_payment' => true,
                'config' => [
                    'display_name' => 'Gateway',
                    'checkout' => [
                        'external_payment' => [
                            'provider' => 'provider_test',
                            'redirect_url_template' => 'https://checkout.provider.test/pay?order_id={order_id}&reference={reference}',
                        ],
                    ],
                    'bank_transfer' => [
                        'bank_code' => 'scb',
                        'account_name' => 'Alpha Co',
                        'account_number' => '123-4-56789-0',
                    ],
                    'secret_token' => 'super-secret',
                    'nested' => ['api_key' => 'secret-key'],
                    'payment_methods' => [
                        'qr' => ['enabled' => false],
                        'credit_card' => ['enabled' => true, 'provider' => 'deepay_kbank'],
                        'bank_transfer' => ['enabled' => true],
                    ],
                ],
            ], $headers + ['Idempotency-Key' => 'payment-settings-m10'])
            ->assertOk()
            ->assertJsonPath('production_provider_ready', false)
            ->assertJsonPath('payment_provider_status', 'blocked_external')
            ->assertJsonPath('config.display_name', 'Gateway')
            ->assertJsonPath('config.checkout.external_payment.provider', 'provider_test')
            ->assertJsonPath('config.bank_transfer.bank_code', 'scb')
            ->assertJsonPath('config.bank_transfer.account_name', 'Alpha Co')
            ->assertJsonPath('payment_methods.qr.enabled', false)
            ->assertJsonPath('payment_methods.credit_card.enabled', true)
            ->assertJsonPath('enabled_payment_methods.0', 'credit_card')
            ->assertJsonPath('bank_transfer.bank_name', 'ธนาคารไทยพาณิชย์')
            ->assertJsonPath('bank_transfer.bank_icon', 'bi-bank')
            ->assertJsonPath('secret_status.secret_token', '[CONFIGURED]')
            ->assertJsonPath('secret_status.nested.api_key', '[CONFIGURED]')
            ->json();

        $this->assertArrayNotHasKey('secret_token', $settings['config']);

        $this->getJson('http://pay.m10.test/api/v1/public/mobile/bootstrap')
            ->assertOk()
            ->assertJsonPath('data.payment.checkout_payment_methods.0', 'wallet')
            ->assertJsonPath('data.payment.checkout_payment_methods.1', 'external_payment')
            ->assertJsonPath('data.payment.checkout_payment_method', 'wallet')
            ->assertJsonPath('data.payment.checkout_payment_method_labels.external_payment', 'Gateway');

        $channel = $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/payment-channels', [
                'code' => 'credit_card',
                'name' => 'Credit card',
                'provider' => 'external_payment',
                'channel_type' => 'card',
                'status' => 'active',
                'config' => ['public_label' => 'Card', 'api_key' => 'card-secret'],
            ], $headers + ['Idempotency-Key' => 'payment-channel-create-m10'])
            ->assertCreated()
            ->assertJsonPath('provider_status', 'blocked_external')
            ->assertJsonPath('config.public_label', 'Card')
            ->assertJsonPath('secret_status.api_key', '[CONFIGURED]')
            ->json();

        $this->withToken($tenant['access_token'])
            ->getJson('/api/v1/admin/tenant/payment-channels/'.$channel['id'], $headers)
            ->assertOk()
            ->assertJsonPath('id', $channel['id']);

        $this->withToken($otherTenant['access_token'])
            ->getJson('/api/v1/admin/tenant/payment-channels/'.$channel['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_pay_other_m10',
            ])
            ->assertNotFound();

        $this->withToken($tenant['access_token'])
            ->deleteJson('/api/v1/admin/tenant/payment-channels/'.$channel['id'], [], $headers + ['Idempotency-Key' => 'payment-channel-delete-m10'])
            ->assertNoContent();

        $this->assertDatabaseHas('tenant_payment_channels', [
            'id' => $channel['id'],
            'tenant_id' => 'ten_pay_m10',
            'status' => 'archived',
        ]);
        $this->assertDatabaseHas('audit_logs', ['action' => 'payment_channel.created', 'target_id' => $channel['id']]);
    }

    public function test_tenant_seo_redirects_and_public_content_use_tenant_sources(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain('par_seo_m10', 'ten_seo_m10', 'seo.m10.test');
        $tenant = $this->createTenantSession('ten_seo_m10', 'par_seo_m10', ['seo.view', 'seo.update', 'seo.redirect.manage'], 'adm_tenant_seo', 'tenant-seo@example.test');
        $headers = ['X-Admin-Scope' => 'tenant', 'X-Tenant-Id' => 'ten_seo_m10'];

        $this->withToken($tenant['access_token'])
            ->patchJson('/api/v1/admin/tenant/seo', [
                'default_title' => 'Default Tenant SEO',
                'default_description' => 'Default description',
                'default_keywords' => ['lottery', 'tenant'],
                'title_template' => '{{title}} | NewPaotang',
            ], $headers + ['Idempotency-Key' => 'seo-settings-m10'])
            ->assertOk()
            ->assertJsonPath('default_title', 'Default Tenant SEO')
            ->assertJsonPath('default_keywords.0', 'lottery');

        $page = $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/seo/pages', [
                'path' => '/promotions',
                'title' => 'Promotions',
                'description' => 'Lucky promotions',
                'robots' => 'index,follow',
            ], $headers + ['Idempotency-Key' => 'seo-page-create-m10'])
            ->assertCreated()
            ->assertJsonPath('path', '/promotions')
            ->json();

        $redirect = $this->withToken($tenant['access_token'])
            ->postJson('/api/v1/admin/tenant/redirects', [
                'source_path' => '/old-promotions',
                'target_url' => 'https://seo.m10.test/promotions',
                'status_code' => 301,
            ], $headers + ['Idempotency-Key' => 'redirect-create-m10'])
            ->assertCreated()
            ->assertJsonPath('source_path', '/old-promotions')
            ->json();

        $this->insertPublicStoreFixture();

        $this->getJson('http://seo.m10.test/api/v1/public/seo/page?path=/promotions')
            ->assertOk()
            ->assertJsonPath('title', 'Promotions | NewPaotang')
            ->assertJsonPath('canonical_url', 'https://seo.m10.test/promotions');

        $this->getJson('http://seo.m10.test/api/v1/public/stores')
            ->assertOk()
            ->assertJsonPath('data.0.id', 'aff_public_store_m10')
            ->assertJsonPath('data.0.name', 'Affiliate Store Alpha')
            ->assertJsonPath('data.0.status', 'active');

        $this->getJson('http://seo.m10.test/api/v1/public/news')
            ->assertOk()
            ->assertJsonPath('data', [])
            ->assertJsonPath('content_source_status', 'empty');

        $this->withToken($tenant['access_token'])
            ->deleteJson('/api/v1/admin/tenant/seo/pages/'.$page['id'], [], $headers + ['Idempotency-Key' => 'seo-page-delete-m10'])
            ->assertNoContent();
        $this->withToken($tenant['access_token'])
            ->deleteJson('/api/v1/admin/tenant/redirects/'.$redirect['id'], [], $headers + ['Idempotency-Key' => 'redirect-delete-m10'])
            ->assertNoContent();

        $this->assertDatabaseMissing('partner_tenant_seo_pages', ['id' => $page['id']]);
        $this->assertDatabaseMissing('partner_tenant_redirects', ['id' => $redirect['id']]);
    }

    public function test_customer_realtime_auth_is_limited_to_authenticated_customer_tenant_channels(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_rt_m10', 'ten_rt_m10', 'rt.m10.test');
        $token = $this->issueCustomerToken('ten_rt_m10', 'cus_rt_m10');

        $this->withToken($token)
            ->postJson('http://rt.m10.test/api/v1/customer/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => 'private-customer.tenant.ten_rt_m10.customer.cus_rt_m10.orders',
            ])
            ->assertOk()
            ->assertJsonStructure(['auth', 'expires_at'])
            ->assertJsonMissingPath('production_realtime_ready');

        $this->withToken($token)
            ->postJson('http://rt.m10.test/api/v1/customer/realtime/auth', [
                'socket_id' => '1234.5678',
                'channel_name' => 'private-customer.tenant.ten_rt_m10.customer.cus_other.orders',
            ])
            ->assertForbidden()
            ->assertJsonPath('error.code', 'permission_denied');
    }

    private function insertPublicStoreFixture(): void
    {
        DB::table('affiliate_accounts')->insert([
            'id' => 'aff_public_store_m10',
            'tenant_id' => 'ten_seo_m10',
            'customer_id' => null,
            'code' => 'PUBM10',
            'name' => 'Affiliate Store Alpha',
            'phone' => null,
            'email' => null,
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'payout_profile_json' => null,
            'metadata_json' => null,
            'created_by_admin_id' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
