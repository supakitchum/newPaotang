<?php

namespace Tests\Feature;

use App\Jobs\SendLineNotificationJob;
use App\Models\LineNotificationDelivery;
use App\Models\TenantLineChannel;
use App\Modules\Auth\Http\Controllers\CustomerLineAuthController;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\LineNotifications\Services\TenantLineNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Schema;
use Tests\TestCase;

class LineNotificationServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['app.key' => 'base64:'.base64_encode(str_repeat('a', 32))]);
        $this->app->forgetInstance('encrypter');
    }

    public function test_connection_verification_encrypts_credentials_and_seeds_templates(): void
    {
        $this->seedTenant();
        Http::fake([
            'api.line.me/v2/oauth/verify' => Http::response(['client_id' => 'login-channel'], 200),
            'api.line.me/v2/bot/info' => Http::response([
                'userId' => 'Ubot123',
                'basicId' => '@luckyshop',
                'displayName' => 'Lucky Shop OA',
            ], 200),
        ]);

        $result = $this->lineService()->updateConnection('ten_line', [
            'messaging_access_token' => 'messaging-token-secret',
            'messaging_channel_secret' => 'messaging-secret',
            'login_channel_id' => 'login-channel',
            'login_channel_secret' => 'login-secret',
            'liff_id' => '1234567890-AbCdEf',
            'status' => 'active',
        ]);

        $this->assertArrayHasKey('resource', $result);
        $channel = TenantLineChannel::query()->where('tenant_id', 'ten_line')->firstOrFail();
        $this->assertSame('active', $channel->status);
        $this->assertSame('1234567890-AbCdEf', $channel->liff_id);
        $this->assertNotSame('messaging-token-secret', $channel->messaging_access_token_encrypted);
        $this->assertSame('@luckyshop', $channel->bot_basic_id);
        $this->assertSame('1234567890-AbCdEf', $result['resource']['connection']['liff_id'] ?? null);
        $this->assertSame('http://line-store.test/line/callback', $result['resource']['connection']['callback_url'] ?? null);
        $this->assertStringNotContainsString(
            'messaging-token-secret',
            (string) json_encode($result['resource']['connection'], JSON_THROW_ON_ERROR),
        );
        $this->assertDatabaseCount('tenant_line_message_templates', count(TenantLineNotificationService::EVENT_KEYS));

        $updated = $this->lineService()->updateConnection('ten_line', [
            'messaging_access_token' => '',
            'messaging_channel_secret' => '',
            'login_channel_id' => '',
            'login_channel_secret' => '',
            'liff_id' => '',
            'status' => 'inactive',
        ]);

        $this->assertArrayHasKey('resource', $updated);
        $this->assertDatabaseHas('tenant_line_channels', [
            'tenant_id' => 'ten_line',
            'status' => 'inactive',
            'bot_basic_id' => '@luckyshop',
            'liff_id' => null,
        ]);
    }

    public function test_connection_update_returns_retryable_error_when_app_key_is_missing(): void
    {
        $this->seedTenant();
        config(['app.key' => null]);
        $this->app->forgetInstance('encrypter');
        Http::fake([
            'api.line.me/*' => Http::response([], 500),
        ]);

        $result = $this->lineService()->updateConnection('ten_line', [
            'messaging_access_token' => 'messaging-token-secret',
            'messaging_channel_secret' => 'messaging-secret',
            'login_channel_id' => 'login-channel',
            'login_channel_secret' => 'login-secret',
            'liff_id' => '1234567890-AbCdEf',
            'status' => 'active',
        ]);

        $this->assertSame('line_encryption_not_configured', $result['error'] ?? null);
        $this->assertStringContainsString('กด Save ใหม่อีกครั้ง', (string) ($result['message'] ?? ''));
        $this->assertDatabaseMissing('tenant_line_channels', [
            'tenant_id' => 'ten_line',
        ]);
        Http::assertNothingSent();
    }

    public function test_connection_update_returns_retryable_error_when_liff_column_is_missing(): void
    {
        $this->seedTenant();
        Schema::table('tenant_line_channels', function ($table): void {
            $table->dropColumn('liff_id');
        });

        Http::fake([
            'api.line.me/*' => Http::response([], 500),
        ]);

        $result = $this->lineService()->updateConnection('ten_line', [
            'messaging_access_token' => 'messaging-token-secret',
            'messaging_channel_secret' => 'messaging-secret',
            'login_channel_id' => 'login-channel',
            'login_channel_secret' => 'login-secret',
            'liff_id' => '1234567890-AbCdEf',
            'status' => 'active',
        ]);

        $this->assertSame('line_schema_not_ready', $result['error'] ?? null);
        $this->assertStringContainsString('database migration', (string) ($result['message'] ?? ''));
        $this->assertDatabaseMissing('tenant_line_channels', [
            'tenant_id' => 'ten_line',
        ]);
        Http::assertNothingSent();
    }

    public function test_line_callback_links_authenticated_customer_without_phone_link(): void
    {
        $this->seedTenant();
        $this->seedLineChannel();

        DB::table('customers')->insert([
            'id' => 'cus_current',
            'tenant_id' => 'ten_line',
            'customer_no' => 'CUS-LINE-002',
            'phone' => '0899999999',
            'name' => 'Current Customer',
            'password_hash' => Hash::make('secret123'),
            'pin_hash' => Hash::make('123456'),
            'pin_set_at' => now(),
            'pin_changed_at' => now(),
            'pin_failed_attempts' => 0,
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $session = app(CustomerAuthService::class)->issueSession(
            'ten_line',
            'cus_current',
            null,
            now()->toDateTimeString(),
        );
        $controller = app(CustomerLineAuthController::class);
        $loginRequest = Request::create('/api/v1/customer/auth/line/login', 'POST', ['store_id' => null], [], [], [
            'HTTP_HOST' => 'line-store.test',
            'HTTP_AUTHORIZATION' => 'Bearer '.$session['token'],
        ]);
        $loginResult = $controller->login($loginRequest);
        $this->assertSame(200, $loginResult->getStatusCode(), (string) $loginResult->getContent());
        $loginResponse = json_decode((string) $loginResult->getContent(), true, 512, JSON_THROW_ON_ERROR);
        parse_str((string) parse_url((string) ($loginResponse['url'] ?? ''), PHP_URL_QUERY), $loginQuery);

        Http::fake([
            'api.line.me/oauth2/v2.1/token' => Http::response(['access_token' => 'line-access-token'], 200),
            'api.line.me/v2/profile' => Http::response([
                'userId' => 'UcurrentLine',
                'displayName' => 'Current LINE',
                'pictureUrl' => 'https://line.test/current.jpg',
            ], 200),
            'api.line.me/friendship/v1/status' => Http::response(['friendFlag' => true], 200),
        ]);

        $callbackRequest = Request::create('/api/v1/customer/auth/line/callback', 'GET', [
                'code' => 'line-code',
                'state' => (string) ($loginQuery['state'] ?? ''),
            ], [], [], [
                'HTTP_HOST' => 'line-store.test',
                'HTTP_AUTHORIZATION' => 'Bearer '.$session['token'],
            ]);
        $callbackResult = $controller->callback($callbackRequest);
        $this->assertSame(200, $callbackResult->getStatusCode(), (string) $callbackResult->getContent());
        $callbackResponse = json_decode((string) $callbackResult->getContent(), true, 512, JSON_THROW_ON_ERROR);
        $this->assertTrue((bool) ($callbackResponse['line_linked'] ?? false));
        $this->assertFalse((bool) ($callbackResponse['pin_required'] ?? true));
        $this->assertSame('cus_current', $callbackResponse['user']['id'] ?? null);

        $this->assertDatabaseHas('customer_line_identities', [
            'tenant_id' => 'ten_line',
            'customer_id' => 'cus_current',
            'line_user_id' => 'UcurrentLine',
            'notification_enabled' => true,
            'friend_flag' => true,
        ]);

        $this->assertDatabaseMissing('customer_line_link_tokens', [
            'tenant_id' => 'ten_line',
            'line_user_id' => 'UcurrentLine',
            'status' => 'pending',
        ]);
    }

    public function test_line_login_uses_https_callback_for_production_storefront_hosts(): void
    {
        $this->seedTenant();
        DB::table('partner_tenant_domains')
            ->where('id', 'ptd_line')
            ->update(['host' => 'line-store.example.com']);
        $this->seedLineChannel();

        $controller = app(CustomerLineAuthController::class);
        $loginRequest = Request::create('/api/v1/customer/auth/line/login', 'POST', ['store_id' => null], [], [], [
            'HTTP_HOST' => 'line-store.example.com',
        ]);
        $loginResult = $controller->login($loginRequest);

        $this->assertSame(200, $loginResult->getStatusCode(), (string) $loginResult->getContent());

        $loginResponse = json_decode((string) $loginResult->getContent(), true, 512, JSON_THROW_ON_ERROR);
        parse_str((string) parse_url((string) ($loginResponse['url'] ?? ''), PHP_URL_QUERY), $loginQuery);

        $this->assertSame('https://line-store.example.com/line/callback', $loginQuery['redirect_uri'] ?? null);
    }

    public function test_line_login_on_api_host_uses_tenant_host_callback_url(): void
    {
        $this->seedTenant();
        DB::table('partner_tenant_domains')
            ->where('id', 'ptd_line')
            ->update(['host' => 'line-store.example.com']);
        $this->seedLineChannel();

        $controller = app(CustomerLineAuthController::class);
        $loginRequest = Request::create('/api/v1/customer/auth/line/login', 'POST', ['store_id' => null], [], [], [
            'HTTP_HOST' => 'api.newpaotang.example.com',
            'HTTP_X_TENANT_HOST' => 'line-store.example.com',
        ]);
        $loginResult = $controller->login($loginRequest);

        $this->assertSame(200, $loginResult->getStatusCode(), (string) $loginResult->getContent());

        $loginResponse = json_decode((string) $loginResult->getContent(), true, 512, JSON_THROW_ON_ERROR);
        parse_str((string) parse_url((string) ($loginResponse['url'] ?? ''), PHP_URL_QUERY), $loginQuery);

        $this->assertSame('https://line-store.example.com/line/callback', $loginQuery['redirect_uri'] ?? null);
        $this->assertDatabaseHas('customer_external_auth_states', [
            'tenant_id' => 'ten_line',
            'provider' => 'line',
            'redirect_uri' => 'https://line-store.example.com/line/callback',
            'status' => 'pending',
        ]);
    }

    public function test_connection_disconnect_removes_channel_without_wiping_templates_or_customer_links(): void
    {
        $this->seedTenant();
        $this->seedLineChannelAndCustomer();

        $result = $this->lineService()->disconnectConnection('ten_line');

        $this->assertFalse((bool) ($result['resource']['connection']['configured'] ?? true));
        $this->assertDatabaseMissing('tenant_line_channels', [
            'tenant_id' => 'ten_line',
        ]);
        $this->assertDatabaseHas('customer_line_identities', [
            'tenant_id' => 'ten_line',
            'customer_id' => 'cus_line',
            'line_user_id' => 'Uline123',
        ]);
        $this->assertDatabaseCount('tenant_line_message_templates', count(TenantLineNotificationService::EVENT_KEYS));
    }

    public function test_enqueue_is_idempotent_and_delivery_push_marks_sent(): void
    {
        $this->seedTenant();
        $this->seedLineChannelAndCustomer();
        Queue::fake();

        $service = $this->lineService();
        $service->enqueue('ten_line', 'cus_line', 'topup.created', 'topup', 'top_123', [
            'customer_name' => 'สมชาย',
            'amount_baht' => '500.00 บาท',
            'status_label' => 'รอตรวจสอบ',
        ]);
        $service->enqueue('ten_line', 'cus_line', 'topup.created', 'topup', 'top_123', [
            'customer_name' => 'สมชาย',
            'amount_baht' => '500.00 บาท',
            'status_label' => 'รอตรวจสอบ',
        ]);

        Queue::assertPushed(SendLineNotificationJob::class, 1);
        $this->assertDatabaseCount('line_notification_deliveries', 1);

        Http::fake([
            'api.line.me/v2/bot/message/push' => Http::response([], 200),
        ]);

        $delivery = LineNotificationDelivery::query()->firstOrFail();
        $service->processDelivery((string) $delivery->id);

        $this->assertDatabaseHas('line_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'sent',
            'attempts' => 1,
        ]);
        Http::assertSent(function ($request): bool {
            $retryKey = (string) ($request->header('X-Line-Retry-Key')[0] ?? '');

            return (bool) preg_match(
                '/^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i',
                $retryKey,
            );
        });
    }

    public function test_legacy_default_text_template_renders_as_readable_multiline_message(): void
    {
        $this->seedTenant();
        $this->seedLineChannelAndCustomer();

        $template = \App\Models\TenantLineMessageTemplate::query()
            ->where('tenant_id', 'ten_line')
            ->where('event_key', 'topup.status_updated')
            ->firstOrFail();
        $template->fill([
            'message_type' => 'text',
            'body_text' => 'รายการเติมเงิน {{topup.reference}} เป็นสถานะ {{topup.status_label}} {{topup.reason}}',
            'updated_at' => now(),
        ])->save();

        $messages = $this->lineService()->renderMessages($template->refresh(), [
            'event' => ['title' => 'เติมเงิน'],
            'tenant' => ['name' => 'Line Tenant'],
            'customer' => ['name' => 'สมชาย', 'phone' => '0812345678'],
            'topup' => [
                'reference' => 'TOP123',
                'amount_baht' => '500.00',
                'status_label' => 'อนุมัติแล้ว',
                'reason' => '',
            ],
        ]);

        $this->assertSame('text', $messages[0]['type'] ?? null);
        $this->assertSame(
            "อัปเดตรายการเติมเงิน\nสถานะ: อนุมัติแล้ว\nยอด: 500.00 บาท\nเลขอ้างอิง: TOP123",
            $messages[0]['text'] ?? null,
        );
    }

    public function test_delivery_reports_missing_app_key_as_specific_line_error(): void
    {
        $this->seedTenant();
        $this->seedLineChannelAndCustomer();
        Queue::fake();

        $service = $this->lineService();
        $service->enqueue('ten_line', 'cus_line', 'topup.created', 'topup', 'top_123', [
            'topup' => ['reference' => 'TOP123', 'amount_baht' => '500.00', 'status_label' => 'รอตรวจสอบ', 'reason' => ''],
            'tenant' => ['name' => 'Line Tenant'],
            'event' => ['title' => 'เติมเงิน'],
        ]);

        config(['app.key' => null]);
        $this->app->forgetInstance('encrypter');

        $delivery = LineNotificationDelivery::query()->firstOrFail();
        $service->processDelivery((string) $delivery->id);

        $this->assertDatabaseHas('line_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'failed',
            'last_error' => 'line_app_key_missing: Application encryption key is missing; LINE credentials cannot be decrypted.',
        ]);
    }

    public function test_requeue_recoverable_delivery_dispatches_after_connection_is_ready(): void
    {
        $this->seedTenant();
        $this->seedLineChannelAndCustomer();
        Queue::fake();

        $service = $this->lineService();
        $service->enqueue('ten_line', 'cus_line', 'topup.created', 'topup', 'top_123', [
            'topup' => ['reference' => 'TOP123', 'amount_baht' => '500.00', 'status_label' => 'รอตรวจสอบ', 'reason' => ''],
            'tenant' => ['name' => 'Line Tenant'],
            'event' => ['title' => 'เติมเงิน'],
        ]);

        $delivery = LineNotificationDelivery::query()->firstOrFail();
        $delivery->fill([
            'status' => 'failed',
            'last_error' => 'Missing LINE channel, recipient, or message payload.',
            'updated_at' => now(),
        ])->save();

        $this->assertSame(1, $service->requeueRecoverableDeliveries('ten_line'));
        Queue::assertPushed(SendLineNotificationJob::class, 2);
        $this->assertDatabaseHas('line_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'queued',
            'last_error' => null,
        ]);
    }

    public function test_test_send_pushes_to_selected_linked_customer(): void
    {
        $this->seedTenant();
        $this->seedLineChannelAndCustomer();

        Http::fake([
            'api.line.me/v2/bot/message/push' => Http::response([], 200),
        ]);

        $result = $this->lineService()->testSend('ten_line', [
            'customer_id' => 'cus_line',
            'message' => 'ทดสอบ LINE',
        ]);

        $this->assertSame('sent', $result['resource']['status'] ?? null);
        $this->assertDatabaseHas('tenant_line_channels', [
            'tenant_id' => 'ten_line',
            'last_test_status' => 'sent',
        ]);
        Http::assertSent(function ($request): bool {
            $body = $request->data();

            return ($body['to'] ?? null) === 'Uline123'
                && ($body['messages'][0]['type'] ?? null) === 'text'
                && ($body['messages'][0]['text'] ?? null) === 'ทดสอบ LINE';
        });
    }

    private function lineService(): TenantLineNotificationService
    {
        return app(TenantLineNotificationService::class);
    }

    private function seedTenant(): void
    {
        DB::table('partners')->insert([
            'id' => 'par_line',
            'code' => 'par_line',
            'name' => 'Line Partner',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            'id' => 'ten_line',
            'partner_id' => 'par_line',
            'code' => 'line',
            'name' => 'Line Tenant',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenant_domains')->insert([
            'id' => 'ptd_line',
            'partner_id' => 'par_line',
            'tenant_id' => 'ten_line',
            'host' => 'line-store.test',
            'type' => 'subdomain',
            'status' => 'active',
            'is_primary' => true,
            'verified_at' => now(),
            'ssl_ready_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function seedLineChannelAndCustomer(): void
    {
        $this->seedLineChannel();

        DB::table('customers')->insert([
            'id' => 'cus_line',
            'tenant_id' => 'ten_line',
            'customer_no' => 'CUS-LINE-001',
            'phone' => '0812345678',
            'name' => 'สมชาย',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->lineService()->upsertIdentity('ten_line', 'cus_line', [
            'userId' => 'Uline123',
            'displayName' => 'สมชาย LINE',
        ], true);
    }

    private function seedLineChannel(): void
    {
        Http::fake([
            'api.line.me/v2/oauth/verify' => Http::response(['client_id' => 'login-channel'], 200),
            'api.line.me/v2/bot/info' => Http::response(['userId' => 'Ubot123', 'basicId' => '@luckyshop'], 200),
        ]);

        $this->lineService()->updateConnection('ten_line', [
            'messaging_access_token' => 'messaging-token-secret',
            'messaging_channel_secret' => 'messaging-secret',
            'login_channel_id' => 'login-channel',
            'login_channel_secret' => 'login-secret',
            'status' => 'active',
        ]);
    }
}
