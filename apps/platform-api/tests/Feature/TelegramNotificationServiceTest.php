<?php

namespace Tests\Feature;

use App\Jobs\SendTelegramNotificationJob;
use App\Models\TelegramNotificationDelivery;
use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Http;
use Illuminate\Support\Facades\Queue;
use Tests\TestCase;

class TelegramNotificationServiceTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config(['app.key' => 'base64:'.base64_encode(str_repeat('b', 32))]);
        $this->app->forgetInstance('encrypter');
    }

    public function test_bot_verification_encrypts_token_and_hides_secret(): void
    {
        Http::fake([
            'api.telegram.org/bottelegram-secret/getMe' => Http::response([
                'ok' => true,
                'result' => [
                    'id' => 123456,
                    'username' => 'newpaotang_ops_bot',
                    'first_name' => 'NewPaotang Ops',
                ],
            ], 200),
        ]);

        $result = $this->service()->updateBot([
            'bot_token' => 'telegram-secret',
            'status' => 'active',
        ]);

        $this->assertArrayHasKey('resource', $result);
        $this->assertDatabaseHas('telegram_bot_connections', [
            'id' => 'tgb_central',
            'status' => 'active',
            'bot_username' => 'newpaotang_ops_bot',
        ]);
        $this->assertStringNotContainsString(
            'telegram-secret',
            json_encode($result['resource'], JSON_THROW_ON_ERROR),
        );
    }

    public function test_sync_chats_discovers_groups_from_get_updates(): void
    {
        $this->seedBot();
        Http::fake([
            'api.telegram.org/bottelegram-secret/getUpdates' => Http::response([
                'ok' => true,
                'result' => [[
                    'update_id' => 700,
                    'message' => [
                        'message_id' => 1,
                        'chat' => [
                            'id' => -1001234567890,
                            'type' => 'supergroup',
                            'title' => 'Alpha Ops',
                        ],
                        'text' => '/bind',
                    ],
                ]],
            ], 200),
        ]);

        $result = $this->service()->syncChats();

        $this->assertSame(1, $result['resource']['synced_count'] ?? null);
        $this->assertDatabaseHas('telegram_chats', [
            'chat_id' => '-1001234567890',
            'chat_type' => 'supergroup',
            'title' => 'Alpha Ops',
        ]);
        $this->assertDatabaseHas('telegram_bot_connections', [
            'id' => 'tgb_central',
            'last_update_id' => 700,
        ]);
    }

    public function test_enqueue_is_idempotent_and_send_escapes_dynamic_values(): void
    {
        $this->seedTenant();
        $this->seedBot();
        $this->seedChatAndRoute('topup.submitted');
        Queue::fake();

        $variables = [
            'event' => ['title' => 'เติมเงิน', 'occurred_at' => '10/06/2026 10:00'],
            'tenant' => ['name' => 'Alpha <Ops>'],
            'customer' => ['name' => '<script>alert(1)</script>', 'phone' => '0812345678'],
            'topup' => ['reference' => 'TOP123', 'amount_baht' => '500.00'],
        ];

        $this->service()->enqueue('ten_telegram', 'topup.submitted', 'topup_request', 'top_123', $variables);
        $this->service()->enqueue('ten_telegram', 'topup.submitted', 'topup_request', 'top_123', $variables);

        Queue::assertPushed(SendTelegramNotificationJob::class, 1);
        $this->assertDatabaseCount('telegram_notification_deliveries', 1);

        Http::fake([
            'api.telegram.org/bottelegram-secret/sendMessage' => Http::response([
                'ok' => true,
                'result' => ['message_id' => 99],
            ], 200),
        ]);

        $delivery = TelegramNotificationDelivery::query()->firstOrFail();
        $this->service()->processDelivery((string) $delivery->id);

        $this->assertDatabaseHas('telegram_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'sent',
            'attempts' => 1,
            'last_error' => null,
        ]);
        Http::assertSent(function ($request): bool {
            $body = $request->data();

            return ($body['chat_id'] ?? null) === '-1001234567890'
                && ($body['parse_mode'] ?? null) === 'HTML'
                && str_contains((string) ($body['text'] ?? ''), '&lt;script&gt;alert(1)&lt;/script&gt;')
                && ! str_contains((string) ($body['text'] ?? ''), '<script>alert(1)</script>');
            });
    }

    public function test_admin_review_event_templates_are_available_and_send_readable_messages(): void
    {
        $this->seedTenant();
        $this->seedBot();
        $this->seedChatAndRoute('topup.status_updated');
        Queue::fake();

        $eventKeys = collect($this->service()->show()['templates'] ?? [])->pluck('event_key')->all();
        $this->assertContains('topup.status_updated', $eventKeys);
        $this->assertContains('commission.status_updated', $eventKeys);
        $this->assertContains('reward_claim.status_updated', $eventKeys);
        $this->assertContains('activity_claim.status_updated', $eventKeys);
        DB::table('telegram_message_templates')->where('event_key', 'topup.status_updated')->delete();

        $this->service()->enqueue('ten_telegram', 'topup.status_updated', 'topup_request', 'top_reviewed', [
            'event' => ['title' => 'ตรวจสอบรายการเติมเงินแล้ว', 'occurred_at' => '12/06/2026 12:00'],
            'tenant' => ['name' => 'Alpha Ops'],
            'customer' => ['name' => 'สมชาย', 'phone' => '0812345678'],
            'topup' => ['reference' => 'TOP456', 'amount_baht' => '500.00', 'status_label' => 'อนุมัติแล้ว', 'reason' => ''],
        ]);

        Queue::assertPushed(SendTelegramNotificationJob::class, 1);

        Http::fake([
            'api.telegram.org/bottelegram-secret/sendMessage' => Http::response([
                'ok' => true,
                'result' => ['message_id' => 100],
            ], 200),
        ]);

        $delivery = TelegramNotificationDelivery::query()->firstOrFail();
        $this->service()->processDelivery((string) $delivery->id);

        Http::assertSent(function ($request): bool {
            $text = (string) ($request->data()['text'] ?? '');

            return str_contains($text, 'ตรวจสอบรายการเติมเงินแล้ว')
                && str_contains($text, 'สถานะ: อนุมัติแล้ว')
                && str_contains($text, 'เลขอ้างอิง: TOP456')
                && ! str_contains($text, "\n\n");
        });
    }

    public function test_route_validation_requires_existing_chat_when_enabled(): void
    {
        $this->seedTenant();

        $result = $this->service()->updateRoutes([
            'routes' => [[
                'tenant_id' => 'ten_telegram',
                'event_key' => 'order.paid',
                'chat_id' => '-100000',
                'enabled' => true,
            ]],
        ]);

        $this->assertSame('validation_failed', $result['error'] ?? null);
        $this->assertArrayHasKey('routes.0.chat_id', $result['errors'] ?? []);
    }

    public function test_test_send_posts_to_selected_discovered_chat(): void
    {
        $this->seedTenant();
        $this->seedBot();
        $this->seedChatAndRoute('order.paid');

        Http::fake([
            'api.telegram.org/bottelegram-secret/sendMessage' => Http::response([
                'ok' => true,
                'result' => ['message_id' => 777],
            ], 200),
        ]);

        $result = $this->service()->testSend([
            'chat_id' => '-1001234567890',
            'message' => 'ทดสอบ <b>Telegram</b>',
        ]);

        $this->assertSame('sent', $result['resource']['status'] ?? null);
        $this->assertDatabaseHas('telegram_bot_connections', [
            'id' => 'tgb_central',
            'last_test_status' => 'sent',
        ]);
        Http::assertSent(function ($request): bool {
            $body = $request->data();

            return ($body['chat_id'] ?? null) === '-1001234567890'
                && str_contains((string) ($body['text'] ?? ''), '&lt;b&gt;Telegram&lt;/b&gt;');
        });
    }

    private function service(): CentralTelegramNotificationService
    {
        return app(CentralTelegramNotificationService::class);
    }

    private function seedTenant(): void
    {
        DB::table('partners')->insert([
            'id' => 'par_telegram',
            'code' => 'par_telegram',
            'name' => 'Telegram Partner',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            'id' => 'ten_telegram',
            'partner_id' => 'par_telegram',
            'code' => 'telegram',
            'name' => 'Telegram Tenant',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function seedBot(): void
    {
        Http::fake([
            'api.telegram.org/bottelegram-secret/getMe' => Http::response([
                'ok' => true,
                'result' => [
                    'id' => 123456,
                    'username' => 'newpaotang_ops_bot',
                    'first_name' => 'NewPaotang Ops',
                ],
            ], 200),
        ]);

        $this->service()->updateBot([
            'bot_token' => 'telegram-secret',
            'status' => 'active',
        ]);
    }

    private function seedChatAndRoute(string $eventKey): void
    {
        DB::table('telegram_chats')->insert([
            'id' => 'tgc_test',
            'chat_id' => '-1001234567890',
            'chat_type' => 'supergroup',
            'title' => 'Alpha Ops',
            'last_seen_at' => now(),
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('tenant_telegram_notification_routes')->insert([
            'id' => 'tgr_test',
            'tenant_id' => 'ten_telegram',
            'event_key' => $eventKey,
            'chat_id' => '-1001234567890',
            'enabled' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->service()->ensureDefaultTemplates();
    }
}
