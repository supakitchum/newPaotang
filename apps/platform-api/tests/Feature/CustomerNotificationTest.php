<?php

namespace Tests\Feature;

use App\Jobs\FanoutCustomerNotificationRecipientsJob;
use App\Jobs\SendCustomerPushNotificationJob;
use App\Models\CustomerNotificationDelivery;
use App\Models\CustomerPushDevice;
use App\Modules\Activities\Events\ActivityClaimUpdated;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Commerce\Events\CustomerOrderUpdated;
use App\Modules\Commerce\Events\CustomerTopupUpdated;
use App\Modules\Commerce\Events\CustomerWalletUpdated;
use App\Modules\CustomerNotifications\Events\CustomerNotificationChanged;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\CustomerNotifications\Services\FirebaseCloudMessagingClient;
use App\Modules\Reward\Events\RewardClaimUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Str;
use Mockery\MockInterface;
use Tests\TestCase;

class CustomerNotificationTest extends TestCase
{
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('n', 32)),
            'services.firebase_cloud_messaging.project_id' => '',
        ]);
        $this->app->forgetInstance('encrypter');
        Event::fake([CustomerNotificationChanged::class]);
        Queue::fake();
    }

    public function test_support_outbox_ingress_requires_hmac_and_deduplicates_customer_notification(): void
    {
        $this->seedTenant('par_notify_support', 'ten_notify_support', 'notify-support.test');
        $this->seedCustomer('ten_notify_support', 'cus_notify_support', 'CUS-NOTIFY-SUPPORT');
        config(['support.ingress_secret' => 'support-ingress-test-secret']);
        $payload = [
            'tenant_id' => 'ten_notify_support',
            'customer_id' => 'cus_notify_support',
            'ticket_id' => 'stk_support_01',
            'ticket_no' => 'SUP-260723-ABC123',
            'event_key' => 'support.message.created',
            'title' => [
                'th-TH' => 'ข้อความใหม่จากศูนย์ช่วยเหลือ',
                'en-US' => 'New Help Center message',
            ],
            'body' => [
                'th-TH' => 'เจ้าหน้าที่ตอบกลับแล้ว',
                'en-US' => 'An agent replied.',
            ],
            'message_id' => 'smsg_support_01',
        ];
        $body = json_encode($payload, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $signature = hash_hmac('sha256', $body, 'support-ingress-test-secret');
        $server = [
            'CONTENT_TYPE' => 'application/json',
            'HTTP_X_SUPPORT_SIGNATURE' => $signature,
            'HTTP_X_SUPPORT_EVENT_ID' => 'sob_support_01',
        ];

        $this->call('POST', '/api/v1/internal/customer-support/notifications', [], [], [], $server, $body)
            ->assertCreated()
            ->assertJsonPath('notification.action.key', 'support_ticket')
            ->assertJsonPath('notification.action.entity_id', 'stk_support_01');
        $this->call('POST', '/api/v1/internal/customer-support/notifications', [], [], [], $server, $body)
            ->assertCreated();

        $this->assertDatabaseCount('customer_notifications', 1);
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => 'ten_notify_support',
            'event_key' => 'support.message.created',
            'category' => 'support',
            'action_key' => 'support_ticket',
            'subject_id' => 'stk_support_01',
        ]);

        $this->call('POST', '/api/v1/internal/customer-support/notifications', [], [], [], [
            ...$server,
            'HTTP_X_SUPPORT_SIGNATURE' => 'invalid',
        ], $body)->assertUnauthorized();
    }

    public function test_customer_inbox_is_tenant_scoped_idempotent_and_server_authoritative(): void
    {
        $this->seedTenant('par_notify_a', 'ten_notify_a', 'notify-a.test');
        $this->seedCustomer('ten_notify_a', 'cus_notify_a', 'CUS-NOTIFY-A');
        $this->seedCustomer('ten_notify_a', 'cus_notify_a2', 'CUS-NOTIFY-A2');
        $this->seedTenant('par_notify_b', 'ten_notify_b', 'notify-b.test');
        $this->seedCustomer('ten_notify_b', 'cus_notify_b', 'CUS-NOTIFY-B');

        $service = app(CustomerNotificationService::class);
        $first = $service->createForCustomer(
            'ten_notify_a',
            'cus_notify_a',
            'order.paid',
            [
                'category' => 'order',
                'title' => ['th-TH' => 'ซื้อสลากสำเร็จ', 'en-US' => 'Lottery purchase complete'],
                'body' => ['th-TH' => 'สลากอยู่ในเมนูของฉันแล้ว', 'en-US' => 'Your tickets are ready.'],
                'icon_key' => 'ticket',
                'action_key' => 'tickets',
                'subject_type' => 'order',
                'subject_id' => 'ord_notify_1',
            ],
            ['dedupe_key' => 'order:ord_notify_1:paid'],
        );
        $replayed = $service->createForCustomer(
            'ten_notify_a',
            'cus_notify_a',
            'order.paid',
            [
                'category' => 'order',
                'title' => 'Duplicate request must reuse the first notification',
                'body' => 'Duplicate',
                'action_key' => 'tickets',
                'subject_type' => 'order',
                'subject_id' => 'ord_notify_1',
            ],
            ['dedupe_key' => 'order:ord_notify_1:paid'],
        );

        $this->assertNotNull($first);
        $this->assertSame($first['id'], $replayed['id']);
        $this->assertDatabaseCount('customer_notifications', 1);
        $this->assertDatabaseCount('customer_notification_recipients', 1);

        $tokenA = $this->customerToken('ten_notify_a', 'cus_notify_a');
        $tokenA2 = $this->customerToken('ten_notify_a', 'cus_notify_a2');
        $tokenB = $this->customerToken('ten_notify_b', 'cus_notify_b');

        $this->withToken($tokenA)
            ->getJson('http://notify-a.test/api/v1/customer/notifications?status=unread&limit=10', [
                'Accept-Language' => 'en-US',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $first['id'])
            ->assertJsonPath('data.0.title', 'Lottery purchase complete')
            ->assertJsonPath('data.0.is_read', false)
            ->assertJsonPath('meta.unread_count', 1);

        $this->withToken($tokenA2)
            ->getJson('http://notify-a.test/api/v1/customer/notifications')
            ->assertOk()
            ->assertJsonCount(0, 'data')
            ->assertJsonPath('meta.unread_count', 0);

        $this->withToken($tokenB)
            ->patchJson('http://notify-b.test/api/v1/customer/notifications/'.$first['id'].'/read')
            ->assertNotFound();

        $this->withToken($tokenA)
            ->patchJson('http://notify-a.test/api/v1/customer/notifications/'.$first['id'].'/read')
            ->assertOk()
            ->assertJsonPath('is_read', true);

        $this->withToken($tokenA)
            ->postJson('http://notify-a.test/api/v1/customer/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('unread_count', 0);

        $this->withToken($tokenA)
            ->getJson('http://notify-a.test/api/v1/customer/notifications/unread-count')
            ->assertOk()
            ->assertJsonPath('unread_count', 0);
    }

    public function test_customer_inbox_cursor_filters_and_read_writes_remain_authoritative(): void
    {
        $this->seedTenant('par_notify_cursor', 'ten_notify_cursor', 'notify-cursor.test');
        $this->seedCustomer('ten_notify_cursor', 'cus_notify_cursor', 'CUS-NOTIFY-CURSOR');

        foreach ([1, 2, 3] as $sequence) {
            $suffix = str_pad((string) $sequence, 2, '0', STR_PAD_LEFT);
            $notificationId = 'cnt_notify_cursor_'.$suffix;
            $createdAt = now()->addSeconds($sequence);
            DB::table('customer_notifications')->insert([
                'id' => $notificationId,
                'tenant_id' => 'ten_notify_cursor',
                'event_key' => 'cursor.event.'.$suffix,
                'category' => $sequence === 2 ? 'topup' : 'order',
                'title_json' => json_encode(['th-TH' => 'แจ้งเตือน '.$suffix], JSON_THROW_ON_ERROR),
                'body_json' => json_encode(['th-TH' => 'รายละเอียด '.$suffix], JSON_THROW_ON_ERROR),
                'icon_key' => 'notification',
                'action_key' => 'none',
                'creator_type' => 'system',
                'dedupe_key' => hash('sha256', 'cursor-notification-'.$suffix),
                'published_at' => $createdAt,
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
            DB::table('customer_notification_recipients')->insert([
                'id' => 'cnr_notify_cursor_'.$suffix,
                'tenant_id' => 'ten_notify_cursor',
                'notification_id' => $notificationId,
                'customer_id' => 'cus_notify_cursor',
                'created_at' => $createdAt,
                'updated_at' => $createdAt,
            ]);
        }

        $token = $this->customerToken('ten_notify_cursor', 'cus_notify_cursor');
        $firstPage = $this->withToken($token)
            ->getJson('http://notify-cursor.test/api/v1/customer/notifications?limit=2')
            ->assertOk()
            ->assertJsonPath('data.0.id', 'cnt_notify_cursor_03')
            ->assertJsonPath('data.1.id', 'cnt_notify_cursor_02')
            ->assertJsonPath('meta.next_cursor', 'cnr_notify_cursor_02')
            ->assertJsonPath('meta.has_more', true)
            ->assertJsonPath('meta.unread_count', 3);

        $cursor = (string) $firstPage->json('meta.next_cursor');
        $this->withToken($token)
            ->getJson('http://notify-cursor.test/api/v1/customer/notifications?limit=2&cursor='.$cursor)
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'cnt_notify_cursor_01')
            ->assertJsonPath('meta.next_cursor', null)
            ->assertJsonPath('meta.has_more', false);

        $this->withToken($token)
            ->patchJson('http://notify-cursor.test/api/v1/customer/notifications/cnt_notify_cursor_03/read')
            ->assertOk()
            ->assertJsonPath('is_read', true);
        $readAt = DB::table('customer_notification_recipients')
            ->where('notification_id', 'cnt_notify_cursor_03')
            ->value('read_at');

        $this->travel(5)->seconds();
        $this->withToken($token)
            ->patchJson('http://notify-cursor.test/api/v1/customer/notifications/cnt_notify_cursor_03/read')
            ->assertOk()
            ->assertJsonPath('is_read', true);
        $this->assertSame(
            (string) $readAt,
            (string) DB::table('customer_notification_recipients')
                ->where('notification_id', 'cnt_notify_cursor_03')
                ->value('read_at'),
        );

        $this->withToken($token)
            ->getJson('http://notify-cursor.test/api/v1/customer/notifications?status=unread&category=order')
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', 'cnt_notify_cursor_01')
            ->assertJsonPath('meta.unread_count', 2);

        $this->withToken($token)
            ->postJson('http://notify-cursor.test/api/v1/customer/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('updated_count', 2)
            ->assertJsonPath('unread_count', 0);
        $this->withToken($token)
            ->postJson('http://notify-cursor.test/api/v1/customer/notifications/read-all')
            ->assertOk()
            ->assertJsonPath('updated_count', 0)
            ->assertJsonPath('unread_count', 0);

        Event::assertDispatchedTimes(CustomerNotificationChanged::class, 2);
    }

    public function test_device_registration_encrypts_tokens_and_invalid_token_delivery_revokes_device(): void
    {
        $this->seedTenant('par_notify_device', 'ten_notify_device', 'notify-device.test');
        $this->seedCustomer('ten_notify_device', 'cus_notify_device', 'CUS-NOTIFY-DEVICE');
        $token = $this->customerToken('ten_notify_device', 'cus_notify_device');
        $fcmToken = str_repeat('fcm-token-', 12);

        $this->withToken($token)
            ->postJson('http://notify-device.test/api/v1/customer/notification-devices', [
                'installation_id' => 'install_notify_device_001',
                'platform' => 'android',
                'fcm_token' => $fcmToken,
                'locale' => 'th-TH',
                'app_version' => '1.2.3',
                'device_name' => 'Google Pixel 9',
                'metadata' => [
                    'app_build_number' => '87',
                    'os_name' => 'Android',
                    'os_version' => '16',
                    'os_sdk' => 36,
                    'manufacturer' => 'Google',
                    'device_model' => 'Pixel 9',
                    'is_physical_device' => true,
                ],
            ])
            ->assertCreated()
            ->assertJsonPath('installation_id', 'install_notify_device_001')
            ->assertJsonPath('registered', true);

        $rawToken = (string) DB::table('customer_push_devices')->value('fcm_token_encrypted');
        $this->assertNotSame($fcmToken, $rawToken);
        $device = CustomerPushDevice::query()->firstOrFail();
        $this->assertSame($fcmToken, $device->fcm_token_encrypted);
        $this->assertSame('1.2.3', $device->app_version);
        $this->assertSame('Google Pixel 9', $device->device_name);
        $this->assertEquals([
            'app_build_number' => '87',
            'os_name' => 'Android',
            'os_version' => '16',
            'manufacturer' => 'Google',
            'device_model' => 'Pixel 9',
            'os_sdk' => 36,
            'is_physical_device' => true,
        ], $device->metadata_json);

        app(CustomerNotificationService::class)->createForCustomer(
            'ten_notify_device',
            'cus_notify_device',
            'topup.approved',
            [
                'category' => 'topup',
                'title' => 'เติมเงินสำเร็จ',
                'body' => 'ยอดเงินเข้ากระเป๋าแล้ว',
                'action_key' => 'wallet',
                'subject_type' => 'topup',
                'subject_id' => 'top_notify_device',
            ],
            ['dedupe_key' => 'topup:top_notify_device:approved'],
        );

        Queue::assertPushed(SendCustomerPushNotificationJob::class, 1);
        $delivery = CustomerNotificationDelivery::query()->firstOrFail();

        $this->mock(FirebaseCloudMessagingClient::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->once()->andReturn([
                'ok' => false,
                'error_code' => 'unregistered',
                'retryable' => false,
                'revoke_device' => true,
            ]);
        });

        app(CustomerNotificationService::class)->processDelivery((string) $delivery->id);

        $this->assertDatabaseHas('customer_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'failed',
            'attempts' => 1,
            'last_error_code' => 'unregistered',
        ]);
        $this->assertNotNull(CustomerPushDevice::query()->firstOrFail()->revoked_at);

        $this->withToken($token)
            ->deleteJson('http://notify-device.test/api/v1/customer/notification-devices/install_notify_device_001')
            ->assertNoContent();
    }

    public function test_device_registration_rejects_identifying_or_unbounded_metadata(): void
    {
        $this->seedTenant('par_notify_metadata', 'ten_notify_metadata', 'notify-metadata.test');
        $this->seedCustomer('ten_notify_metadata', 'cus_notify_metadata', 'CUS-NOTIFY-METADATA');
        $token = $this->customerToken('ten_notify_metadata', 'cus_notify_metadata');
        $basePayload = [
            'installation_id' => 'install_notify_metadata_001',
            'platform' => 'android',
            'fcm_token' => str_repeat('metadata-fcm-token-', 10),
            'locale' => 'th-TH',
        ];

        $this->withToken($token)
            ->postJson('http://notify-metadata.test/api/v1/customer/notification-devices', [
                ...$basePayload,
                'metadata' => ['hardware_id' => 'must-not-be-collected'],
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonStructure(['error' => ['details' => ['fields' => ['metadata']]]]);

        $this->withToken($token)
            ->postJson('http://notify-metadata.test/api/v1/customer/notification-devices', [
                ...$basePayload,
                'metadata' => ['device_model' => str_repeat('x', 161)],
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed');

        $this->assertDatabaseCount('customer_push_devices', 0);
    }

    public function test_device_installation_and_token_move_to_the_latest_customer_without_payload_error_revocation(): void
    {
        $this->seedTenant('par_notify_move_a', 'ten_notify_move_a', 'notify-move-a.test');
        $this->seedCustomer('ten_notify_move_a', 'cus_notify_move_a', 'CUS-NOTIFY-MOVE-A');
        $this->seedTenant('par_notify_move_b', 'ten_notify_move_b', 'notify-move-b.test');
        $this->seedCustomer('ten_notify_move_b', 'cus_notify_move_b', 'CUS-NOTIFY-MOVE-B');
        $service = app(CustomerNotificationService::class);
        $firstToken = str_repeat('first-fcm-token-', 10);
        $refreshedToken = str_repeat('refreshed-fcm-token-', 10);

        $service->registerDevice('ten_notify_move_a', 'cus_notify_move_a', [
            'installation_id' => 'install_notify_shared',
            'platform' => 'android',
            'fcm_token' => $firstToken,
            'locale' => 'th-TH',
        ]);
        $service->registerDevice('ten_notify_move_b', 'cus_notify_move_b', [
            'installation_id' => 'install_notify_shared',
            'platform' => 'android',
            'fcm_token' => $refreshedToken,
            'locale' => 'en-US',
        ]);

        $this->assertNotNull(CustomerPushDevice::query()
            ->where('customer_id', 'cus_notify_move_a')
            ->firstOrFail()
            ->revoked_at);
        $activeDevice = CustomerPushDevice::query()
            ->where('customer_id', 'cus_notify_move_b')
            ->firstOrFail();
        $this->assertNull($activeDevice->revoked_at);

        $service->registerDevice('ten_notify_move_a', 'cus_notify_move_a', [
            'installation_id' => 'install_notify_reassigned',
            'platform' => 'android',
            'fcm_token' => $refreshedToken,
            'locale' => 'th-TH',
        ]);
        $this->assertNotNull($activeDevice->refresh()->revoked_at);
        $activeDevice = CustomerPushDevice::query()
            ->where('customer_id', 'cus_notify_move_a')
            ->where('installation_id', 'install_notify_reassigned')
            ->firstOrFail();
        $this->assertNull($activeDevice->revoked_at);

        $service->createForCustomer(
            'ten_notify_move_a',
            'cus_notify_move_a',
            'account.password.changed',
            [
                'category' => 'account',
                'title' => 'Password changed',
                'body' => 'Your password was changed.',
                'action_key' => 'none',
                'subject_type' => 'customer',
                'subject_id' => 'cus_notify_move_a',
            ],
            ['dedupe_key' => 'password-change:payload-validation'],
        );
        $delivery = CustomerNotificationDelivery::query()->firstOrFail();
        $this->mock(FirebaseCloudMessagingClient::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->once()->andReturn([
                'ok' => false,
                'error_code' => 'invalid_payload',
                'retryable' => false,
                'revoke_device' => false,
            ]);
        });

        app(CustomerNotificationService::class)->processDelivery((string) $delivery->id);

        $this->assertDatabaseHas('customer_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'failed',
            'last_error_code' => 'invalid_payload',
        ]);
        $this->assertNull($activeDevice->refresh()->revoked_at);
    }

    public function test_device_revoke_cannot_cross_customer_ownership_after_installation_moves(): void
    {
        $this->seedTenant('par_notify_revoke', 'ten_notify_revoke', 'notify-revoke.test');
        $this->seedCustomer('ten_notify_revoke', 'cus_notify_revoke_a', 'CUS-NOTIFY-REVOKE-A');
        $this->seedCustomer('ten_notify_revoke', 'cus_notify_revoke_b', 'CUS-NOTIFY-REVOKE-B');
        $this->seedCustomer('ten_notify_revoke', 'cus_notify_revoke_c', 'CUS-NOTIFY-REVOKE-C');
        $installationId = 'install_notify_revoke_shared';

        $this->withToken($this->customerToken('ten_notify_revoke', 'cus_notify_revoke_a'))
            ->postJson('http://notify-revoke.test/api/v1/customer/notification-devices', [
                'installation_id' => $installationId,
                'platform' => 'android',
                'fcm_token' => str_repeat('notify-revoke-token-a-', 8),
                'locale' => 'th-TH',
            ])
            ->assertCreated();
        $this->withToken($this->customerToken('ten_notify_revoke', 'cus_notify_revoke_b'))
            ->postJson('http://notify-revoke.test/api/v1/customer/notification-devices', [
                'installation_id' => $installationId,
                'platform' => 'android',
                'fcm_token' => str_repeat('notify-revoke-token-b-', 8),
                'locale' => 'th-TH',
            ])
            ->assertCreated();

        $activeDevice = CustomerPushDevice::query()
            ->where('customer_id', 'cus_notify_revoke_b')
            ->where('installation_id', $installationId)
            ->firstOrFail();
        $this->assertNull($activeDevice->revoked_at);

        $this->withToken($this->customerToken('ten_notify_revoke', 'cus_notify_revoke_c'))
            ->deleteJson('http://notify-revoke.test/api/v1/customer/notification-devices/'.$installationId)
            ->assertNotFound();
        $this->assertNull($activeDevice->refresh()->revoked_at);

        $this->withToken($this->customerToken('ten_notify_revoke', 'cus_notify_revoke_a'))
            ->deleteJson('http://notify-revoke.test/api/v1/customer/notification-devices/'.$installationId)
            ->assertNoContent();
        $this->assertNull($activeDevice->refresh()->revoked_at);

        $this->withToken($this->customerToken('ten_notify_revoke', 'cus_notify_revoke_b'))
            ->deleteJson('http://notify-revoke.test/api/v1/customer/notification-devices/'.$installationId)
            ->assertNoContent();
        $this->assertNotNull($activeDevice->refresh()->revoked_at);
    }

    public function test_delivery_claim_prevents_duplicate_send_and_recovers_a_stale_worker(): void
    {
        $this->seedTenant('par_notify_lease', 'ten_notify_lease', 'notify-lease.test');
        $this->seedCustomer('ten_notify_lease', 'cus_notify_lease', 'CUS-NOTIFY-LEASE');
        $service = app(CustomerNotificationService::class);
        $service->registerDevice('ten_notify_lease', 'cus_notify_lease', [
            'installation_id' => 'install_notify_lease',
            'platform' => 'android',
            'fcm_token' => str_repeat('lease-fcm-token-', 10),
            'locale' => 'th-TH',
        ]);
        $service->createForCustomer(
            'ten_notify_lease',
            'cus_notify_lease',
            'account.password.changed',
            [
                'category' => 'account',
                'title' => 'Password changed',
                'body' => 'Your password was changed.',
                'action_key' => 'none',
                'subject_type' => 'customer',
                'subject_id' => 'cus_notify_lease',
            ],
            ['dedupe_key' => 'password-change:delivery-lease'],
        );

        $delivery = CustomerNotificationDelivery::query()->firstOrFail();
        $delivery->forceFill([
            'status' => 'sending',
            'attempts' => 1,
            'updated_at' => now(),
        ])->save();

        $this->mock(FirebaseCloudMessagingClient::class, function (MockInterface $mock): void {
            $mock->shouldReceive('send')->once()->andReturn([
                'ok' => true,
                'message_id' => 'projects/test/messages/lease-recovered',
            ]);
        });
        $this->app->forgetInstance(CustomerNotificationService::class);
        $service = app(CustomerNotificationService::class);

        $service->processDelivery((string) $delivery->id);
        $this->assertDatabaseHas('customer_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'sending',
            'attempts' => 1,
        ]);

        $delivery->forceFill(['updated_at' => now()->subMinutes(11)])->save();
        $service->processDelivery((string) $delivery->id);

        $this->assertDatabaseHas('customer_notification_deliveries', [
            'id' => $delivery->id,
            'status' => 'sent',
            'attempts' => 2,
            'provider_message_id' => 'projects/test/messages/lease-recovered',
        ]);
    }

    public function test_recovery_command_redispatches_missed_and_stale_deliveries_only(): void
    {
        $this->seedTenant('par_notify_recover', 'ten_notify_recover', 'notify-recover.test');
        $this->seedCustomer('ten_notify_recover', 'cus_notify_recover', 'CUS-NOTIFY-RECOVER');
        $service = app(CustomerNotificationService::class);
        $service->registerDevice('ten_notify_recover', 'cus_notify_recover', [
            'installation_id' => 'install_notify_recover',
            'platform' => 'ios',
            'fcm_token' => str_repeat('recover-fcm-token-', 10),
            'locale' => 'th-TH',
        ]);

        foreach (['missed', 'stale', 'fresh'] as $transition) {
            $service->createForCustomer(
                'ten_notify_recover',
                'cus_notify_recover',
                'account.pin.changed',
                [
                    'category' => 'account',
                    'title' => 'PIN changed',
                    'body' => 'Your PIN was changed.',
                    'action_key' => 'none',
                    'subject_type' => 'customer',
                    'subject_id' => 'cus_notify_recover',
                ],
                ['dedupe_key' => 'pin-change:delivery-'.$transition],
            );
        }

        $deliveries = CustomerNotificationDelivery::query()->orderBy('created_at')->orderBy('id')->get();
        $this->assertCount(3, $deliveries);
        $deliveries[0]->forceFill([
            'status' => 'queued',
            'attempts' => 0,
            'next_retry_at' => null,
            'created_at' => now()->subMinutes(5),
            'updated_at' => now()->subMinutes(5),
        ])->save();
        $deliveries[1]->forceFill([
            'status' => 'sending',
            'attempts' => 1,
            'next_retry_at' => null,
            'updated_at' => now()->subMinutes(11),
        ])->save();
        $deliveries[2]->forceFill([
            'status' => 'queued',
            'attempts' => 0,
            'next_retry_at' => null,
            'updated_at' => now(),
        ])->save();
        $fanoutNotificationId = 'cnt_'.Str::ulid()->toBase32();
        DB::table('customer_notifications')->insert([
            'id' => $fanoutNotificationId,
            'tenant_id' => 'ten_notify_recover',
            'event_key' => 'content.news.published',
            'category' => 'news',
            'title_json' => json_encode(['th-TH' => 'ข่าวใหม่'], JSON_THROW_ON_ERROR),
            'body_json' => json_encode(['th-TH' => 'อ่านข่าวใหม่'], JSON_THROW_ON_ERROR),
            'icon_key' => 'news',
            'action_key' => 'news',
            'action_entity_id' => 'news-recovery',
            'subject_type' => 'tenant_announcement',
            'subject_id' => 'ann_notify_recover',
            'creator_type' => 'system',
            'creator_id' => null,
            'dedupe_key' => hash('sha256', 'notify-recover-fanout'),
            'metadata_json' => json_encode(['audience' => 'tenant'], JSON_THROW_ON_ERROR),
            'published_at' => now()->subMinutes(5),
            'created_at' => now()->subMinutes(5),
            'updated_at' => now()->subMinutes(5),
        ]);
        Queue::fake();

        $this->artisan('customer-notifications:recover-deliveries --limit=100')
            ->expectsOutput('Recovered customer push deliveries: 2')
            ->expectsOutput('Recovered customer notification fan-outs: 1')
            ->assertSuccessful();

        Queue::assertPushed(SendCustomerPushNotificationJob::class, 2);
        Queue::assertPushed(
            FanoutCustomerNotificationRecipientsJob::class,
            fn (FanoutCustomerNotificationRecipientsJob $job): bool => $job->notificationId === $fanoutNotificationId
                && $job->afterCustomerId === null,
        );
        $this->assertNotNull($deliveries[0]->refresh()->next_retry_at);
        $this->assertDatabaseHas('customer_notification_deliveries', [
            'id' => $deliveries[1]->id,
            'status' => 'queued',
            'attempts' => 1,
            'last_error_code' => 'worker_stale_requeued',
        ]);
        $this->assertNull($deliveries[2]->refresh()->next_retry_at);
    }

    public function test_recovery_command_revokes_only_stale_active_push_devices(): void
    {
        $this->seedTenant('par_notify_stale', 'ten_notify_stale', 'notify-stale.test');
        $this->seedCustomer('ten_notify_stale', 'cus_notify_stale', 'CUS-NOTIFY-STALE');
        $service = app(CustomerNotificationService::class);

        foreach (['stale', 'fresh', 'revoked', 'disabled'] as $suffix) {
            $service->registerDevice('ten_notify_stale', 'cus_notify_stale', [
                'installation_id' => 'install_notify_'.$suffix,
                'platform' => 'android',
                'fcm_token' => str_repeat($suffix.'-fcm-token-', 10),
                'locale' => 'th-TH',
            ]);
        }

        CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_stale')
            ->update(['last_seen_at' => now()->subDays(271)]);
        CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_fresh')
            ->update(['last_seen_at' => now()->subDays(269)]);
        CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_revoked')
            ->update([
                'last_seen_at' => now()->subDays(271),
                'revoked_at' => now()->subDay(),
            ]);
        CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_disabled')
            ->update(['last_seen_at' => now()->subDays(365)]);

        $this->artisan('customer-notifications:recover-deliveries --limit=100 --device-limit=2 --device-stale-days=270')
            ->expectsOutput('Recovered customer push deliveries: 0')
            ->expectsOutput('Recovered customer notification fan-outs: 0')
            ->expectsOutput('Revoked stale customer push devices: 2')
            ->assertSuccessful();

        $this->assertNotNull(CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_stale')
            ->firstOrFail()
            ->revoked_at);
        $this->assertNull(CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_fresh')
            ->firstOrFail()
            ->revoked_at);
        $this->assertNotNull(CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_revoked')
            ->firstOrFail()
            ->revoked_at);
        $this->assertNotNull(CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_disabled')
            ->firstOrFail()
            ->revoked_at);

        $service->registerDevice('ten_notify_stale', 'cus_notify_stale', [
            'installation_id' => 'install_notify_disabled',
            'platform' => 'android',
            'fcm_token' => str_repeat('disabled-fcm-token-', 10),
            'locale' => 'th-TH',
        ]);
        CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_disabled')
            ->update(['last_seen_at' => now()->subDays(365)]);

        $this->artisan('customer-notifications:recover-deliveries --device-stale-days=0')
            ->expectsOutput('Revoked stale customer push devices: 0')
            ->assertSuccessful();
        $this->assertNull(CustomerPushDevice::query()
            ->where('installation_id', 'install_notify_disabled')
            ->firstOrFail()
            ->revoked_at);
    }

    public function test_fcm_failure_classification_only_revokes_token_specific_invalid_arguments(): void
    {
        $genericInvalid = FirebaseCloudMessagingClient::classifyFailure(400, [
            'status' => 'INVALID_ARGUMENT',
            'details' => [[
                '@type' => 'type.googleapis.com/google.rpc.BadRequest',
                'fieldViolations' => [['field' => 'message.notification.title']],
            ]],
        ]);
        $tokenInvalid = FirebaseCloudMessagingClient::classifyFailure(400, [
            'status' => 'INVALID_ARGUMENT',
            'details' => [[
                '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                'errorCode' => 'INVALID_ARGUMENT',
            ]],
        ]);
        $unregistered = FirebaseCloudMessagingClient::classifyFailure(404, [
            'status' => 'NOT_FOUND',
            'details' => [[
                '@type' => 'type.googleapis.com/google.firebase.fcm.v1.FcmError',
                'errorCode' => 'UNREGISTERED',
            ]],
        ]);

        $this->assertSame('invalid_payload', $genericInvalid['error_code']);
        $this->assertFalse($genericInvalid['revoke_device']);
        $this->assertSame('invalid_argument', $tokenInvalid['error_code']);
        $this->assertTrue($tokenInvalid['revoke_device']);
        $this->assertSame('unregistered', $unregistered['error_code']);
        $this->assertTrue($unregistered['revoke_device']);
    }

    public function test_tenant_fanout_is_chunked_idempotent_and_excludes_inactive_customers(): void
    {
        $this->seedTenant('par_notify_fanout', 'ten_notify_fanout', 'notify-fanout.test');
        $this->seedCustomer('ten_notify_fanout', 'cus_notify_fanout_1', 'CUS-NOTIFY-FANOUT-1');
        $this->seedCustomer('ten_notify_fanout', 'cus_notify_fanout_2', 'CUS-NOTIFY-FANOUT-2');
        $this->seedCustomer('ten_notify_fanout', 'cus_notify_fanout_3', 'CUS-NOTIFY-FANOUT-3', 'suspended');

        $service = app(CustomerNotificationService::class);
        $notificationId = $service->createForTenantAudience(
            'ten_notify_fanout',
            'content.news.published',
            [
                'category' => 'news',
                'title' => ['th-TH' => 'ข่าวใหม่', 'en-US' => 'New announcement'],
                'body' => ['th-TH' => 'อ่านรายละเอียดข่าว', 'en-US' => 'Read the announcement'],
                'action_key' => 'news',
                'action_entity_id' => 'new-announcement',
                'subject_type' => 'tenant_announcement',
                'subject_id' => 'ann_notify_fanout',
            ],
            ['dedupe_key' => 'news:ann_notify_fanout:published:v1'],
        );
        $replayedId = $service->createForTenantAudience(
            'ten_notify_fanout',
            'content.news.published',
            [
                'category' => 'news',
                'title' => 'Duplicate',
                'body' => 'Duplicate',
                'action_key' => 'news',
                'action_entity_id' => 'new-announcement',
                'subject_type' => 'tenant_announcement',
                'subject_id' => 'ann_notify_fanout',
            ],
            ['dedupe_key' => 'news:ann_notify_fanout:published:v1'],
        );

        $this->assertNotNull($notificationId);
        $this->assertSame($notificationId, $replayedId);
        Queue::assertPushed(FanoutCustomerNotificationRecipientsJob::class, 1);

        $service->fanOutTenantChunk((string) $notificationId);
        $service->fanOutTenantChunk((string) $notificationId);

        $this->assertDatabaseCount('customer_notifications', 1);
        $this->assertDatabaseCount('customer_notification_recipients', 2);
        $this->assertDatabaseMissing('customer_notification_recipients', [
            'customer_id' => 'cus_notify_fanout_3',
        ]);
    }

    public function test_direct_admin_send_rejects_cross_tenant_customer(): void
    {
        $this->seedTenant('par_notify_admin_a', 'ten_notify_admin_a', 'notify-admin-a.test');
        $this->seedTenant('par_notify_admin_b', 'ten_notify_admin_b', 'notify-admin-b.test');
        $this->seedCustomer('ten_notify_admin_b', 'cus_notify_admin_b', 'CUS-NOTIFY-ADMIN-B');

        $actor = new AdminSessionContext(
            ['scope_type' => 'tenant', 'scope_id' => 'scp_notify_admin', 'tenant_id' => 'ten_notify_admin_a'],
            ['id' => 'adm_notify_admin'],
            [],
        );
        $request = Request::create('/api/v1/admin/tenant/customer-notifications', 'POST');

        $result = app(CustomerNotificationService::class)->sendFromAdmin(
            'ten_notify_admin_a',
            $actor,
            [
                'customer_id' => 'cus_notify_admin_b',
                'title' => ['th-TH' => 'ข้อความจากร้าน'],
                'body' => ['th-TH' => 'รายละเอียด'],
                'action_key' => 'home',
            ],
            $request,
            'notify-admin-cross-tenant',
        );

        $this->assertSame('validation_failed', $result['error'] ?? null);
        $this->assertArrayHasKey('customer_id', $result['errors'] ?? []);
        $this->assertDatabaseCount('customer_notifications', 0);
    }

    public function test_admin_composer_options_search_and_history_are_tenant_scoped(): void
    {
        $this->seedTenant('par_notify_composer_a', 'ten_notify_composer_a', 'notify-composer-a.test');
        $this->seedCustomer('ten_notify_composer_a', 'cus_notify_composer_a', 'CUS-COMPOSER-A');
        $this->seedCustomer('ten_notify_composer_a', 'cus_notify_composer_suspended', 'CUS-COMPOSER-S', 'suspended');
        $this->seedTenant('par_notify_composer_b', 'ten_notify_composer_b', 'notify-composer-b.test');
        $this->seedCustomer('ten_notify_composer_b', 'cus_notify_composer_b', 'CUS-COMPOSER-B');
        foreach ([
            ['id' => 'ann_notify_composer_a', 'tenant_id' => 'ten_notify_composer_a', 'slug' => 'announcement-2026'],
            ['id' => 'ann_notify_composer_b', 'tenant_id' => 'ten_notify_composer_b', 'slug' => 'other-tenant-announcement'],
        ] as $announcement) {
            DB::table('tenant_announcements')->insert([
                ...$announcement,
                'title' => 'Notification announcement',
                'status' => 'active',
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
        DB::table('admin_users')->insert([
            'id' => 'adm_notify_composer',
            'email' => 'notify-composer@example.test',
            'username' => 'notify-composer',
            'name' => 'Notification Operator',
            'password_hash' => Hash::make('password'),
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $service = app(CustomerNotificationService::class);
        $options = $service->adminCustomerOptions('ten_notify_composer_a', ['q' => 'COMPOSER']);

        $this->assertCount(1, $options['data']);
        $this->assertSame('cus_notify_composer_a', $options['data'][0]['id']);
        $this->assertNotContains('cus_notify_composer_b', array_column($options['data'], 'id'));
        $newsAction = collect($options['meta']['action_options'])->firstWhere('key', 'news');
        $this->assertSame(true, $newsAction['entity_required'] ?? null);
        $adminActionKeys = array_column($options['meta']['action_options'], 'key');
        $this->assertNotContains('order', $adminActionKeys);
        $this->assertNotContains('checkout_pending', $adminActionKeys);

        $actor = new AdminSessionContext(
            ['scope_type' => 'tenant', 'scope_id' => 'scp_notify_composer', 'tenant_id' => 'ten_notify_composer_a'],
            ['id' => 'adm_notify_composer'],
            [],
        );
        $request = Request::create('/api/v1/admin/tenant/customer-notifications', 'POST');
        $request->headers->set('X-Request-Id', 'req-notify-composer-valid');
        $missingEntity = $service->sendFromAdmin(
            'ten_notify_composer_a',
            $actor,
            [
                'customer_id' => 'cus_notify_composer_a',
                'title' => ['th-TH' => 'ข่าวสำคัญ'],
                'body' => ['th-TH' => 'อ่านรายละเอียดข่าว'],
                'action_key' => 'news',
            ],
            $request,
            'notify-composer-missing-entity',
        );
        $externalEntity = $service->sendFromAdmin(
            'ten_notify_composer_a',
            $actor,
            [
                'customer_id' => 'cus_notify_composer_a',
                'title' => ['th-TH' => 'ข่าวสำคัญ'],
                'body' => ['th-TH' => 'อ่านรายละเอียดข่าว'],
                'action_key' => 'news',
                'action_entity_id' => 'https://external.example.test/news',
            ],
            $request,
            'notify-composer-external-entity',
        );
        $crossTenantEntity = $service->sendFromAdmin(
            'ten_notify_composer_a',
            $actor,
            [
                'customer_id' => 'cus_notify_composer_a',
                'title' => ['th-TH' => 'ข่าวสำคัญ'],
                'body' => ['th-TH' => 'อ่านรายละเอียดข่าว'],
                'action_key' => 'news',
                'action_entity_id' => 'other-tenant-announcement',
            ],
            $request,
            'notify-composer-cross-tenant-entity',
        );

        $this->assertArrayHasKey('action_entity_id', $missingEntity['errors'] ?? []);
        $this->assertArrayHasKey('action_entity_id', $externalEntity['errors'] ?? []);
        $this->assertArrayHasKey('action_entity_id', $crossTenantEntity['errors'] ?? []);

        $sent = $service->sendFromAdmin(
            'ten_notify_composer_a',
            $actor,
            [
                'customer_id' => 'cus_notify_composer_a',
                'title' => ['th-TH' => 'ข่าวสำคัญ', 'en-US' => 'Important news'],
                'body' => ['th-TH' => 'อ่านรายละเอียดข่าว', 'en-US' => 'Read the news detail'],
                'action_key' => 'news',
                'action_entity_id' => 'announcement-2026',
            ],
            $request,
            'notify-composer-valid',
        );

        $this->assertArrayHasKey('resource', $sent);
        $history = $service->adminList('ten_notify_composer_a', ['creator_type' => 'tenant_admin']);
        $this->assertCount(1, $history['data']);
        $this->assertSame('Notification Operator', $history['data'][0]['creator']['name']);
        $this->assertSame('cus_notify_composer_a', $history['data'][0]['recipients'][0]['customer']['id']);
        $this->assertSame('not_registered', $history['data'][0]['recipients'][0]['push']['status']);

        $audit = DB::table('audit_logs')
            ->where('action', 'customer_notification.sent')
            ->where('tenant_id', 'ten_notify_composer_a')
            ->first();
        $this->assertNotNull($audit);
        $this->assertSame('adm_notify_composer', $audit->actor_id);
        $this->assertSame('customer', $audit->target_type);
        $this->assertSame('cus_notify_composer_a', $audit->target_id);
        $this->assertSame('req-notify-composer-valid', $audit->request_id);
        $auditPayload = json_decode((string) $audit->payload_redacted_json, true, flags: JSON_THROW_ON_ERROR);
        $this->assertSame('accepted', $auditPayload['outcome']);
        $this->assertSame('news', $auditPayload['destination']['action_key']);
        $this->assertSame('announcement-2026', $auditPayload['destination']['action_entity_id']);
        $this->assertSame(
            hash('sha256', json_encode([
                ['th-TH' => 'ข่าวสำคัญ', 'en-US' => 'Important news'],
                ['th-TH' => 'อ่านรายละเอียดข่าว', 'en-US' => 'Read the news detail'],
            ], JSON_THROW_ON_ERROR)),
            $auditPayload['content_fingerprint'],
        );
        $this->assertStringNotContainsString('ข่าวสำคัญ', (string) $audit->payload_redacted_json);
        $this->assertStringNotContainsString('Read the news detail', (string) $audit->payload_redacted_json);
    }

    public function test_admin_send_rolls_back_durable_records_when_audit_write_fails(): void
    {
        $this->seedTenant('par_notify_audit_fail', 'ten_notify_audit_fail', 'notify-audit-fail.test');
        $this->seedCustomer('ten_notify_audit_fail', 'cus_notify_audit_fail', 'CUS-NOTIFY-AUDIT-FAIL');

        $this->mock(AuditLogger::class, function (MockInterface $mock): void {
            $mock->shouldReceive('logAdminWrite')
                ->once()
                ->andThrow(new \RuntimeException('simulated audit storage failure'));
        });

        $actor = new AdminSessionContext(
            ['scope_type' => 'tenant', 'scope_id' => 'scp_notify_audit_fail', 'tenant_id' => 'ten_notify_audit_fail'],
            ['id' => 'adm_notify_audit_fail'],
            [],
        );
        $request = Request::create('/api/v1/admin/tenant/customer-notifications', 'POST');

        try {
            app(CustomerNotificationService::class)->sendFromAdmin(
                'ten_notify_audit_fail',
                $actor,
                [
                    'customer_id' => 'cus_notify_audit_fail',
                    'title' => ['th-TH' => 'ข้อความทดสอบ'],
                    'body' => ['th-TH' => 'ต้องไม่ถูกบันทึกถ้า audit ล้ม'],
                    'action_key' => 'home',
                ],
                $request,
                'notify-audit-failure',
            );
            $this->fail('The simulated audit failure was not raised.');
        } catch (\RuntimeException $exception) {
            $this->assertSame('simulated audit storage failure', $exception->getMessage());
        }

        $this->assertDatabaseCount('customer_notifications', 0);
        $this->assertDatabaseCount('customer_notification_recipients', 0);
        $this->assertDatabaseCount('customer_notification_deliveries', 0);
        Event::assertNotDispatched(CustomerNotificationChanged::class);
    }

    public function test_admin_direct_push_masks_message_content_but_keeps_inbox_detail(): void
    {
        $this->seedTenant('par_notify_private_push', 'ten_notify_private_push', 'notify-private-push.test');
        $this->seedCustomer('ten_notify_private_push', 'cus_notify_private_push', 'CUS-NOTIFY-PRIVATE-PUSH');
        $service = app(CustomerNotificationService::class);
        $service->registerDevice('ten_notify_private_push', 'cus_notify_private_push', [
            'installation_id' => 'install_notify_private_push',
            'platform' => 'android',
            'fcm_token' => str_repeat('private-push-token-', 10),
            'locale' => 'th-TH',
        ]);
        $actor = new AdminSessionContext(
            ['scope_type' => 'tenant', 'scope_id' => 'scp_notify_private_push', 'tenant_id' => 'ten_notify_private_push'],
            ['id' => 'adm_notify_private_push'],
            [],
        );
        $request = Request::create('/api/v1/admin/tenant/customer-notifications', 'POST');
        $result = $service->sendFromAdmin(
            'ten_notify_private_push',
            $actor,
            [
                'customer_id' => 'cus_notify_private_push',
                'title' => ['th-TH' => 'OTP 123456 สำหรับบัญชี 0123456789'],
                'body' => ['th-TH' => 'ยอดเงิน 9,999.00 บาท'],
                'action_key' => 'wallet',
            ],
            $request,
            'notify-private-push',
        );

        $this->assertSame('OTP 123456 สำหรับบัญชี 0123456789', $result['resource']['title'] ?? null);
        $this->assertSame('ยอดเงิน 9,999.00 บาท', $result['resource']['body'] ?? null);

        $sentMessage = null;
        $this->mock(FirebaseCloudMessagingClient::class, function (MockInterface $mock) use (&$sentMessage): void {
            $mock->shouldReceive('send')
                ->once()
                ->with(\Mockery::on(function (array $message) use (&$sentMessage): bool {
                    $sentMessage = $message;

                    return true;
                }))
                ->andReturn([
                    'ok' => true,
                    'message_id' => 'projects/test/messages/private-preview',
                ]);
        });
        $this->app->forgetInstance(CustomerNotificationService::class);
        app(CustomerNotificationService::class)->processDelivery(
            (string) CustomerNotificationDelivery::query()->value('id'),
        );

        $this->assertIsArray($sentMessage);
        $this->assertSame('มีข้อความใหม่', $sentMessage['notification']['title'] ?? null);
        $this->assertSame('เปิดแอปเพื่อดูรายละเอียดข้อความ', $sentMessage['notification']['body'] ?? null);
        $this->assertSame('wallet', $sentMessage['data']['action_key'] ?? null);
        $pushPreview = json_encode($sentMessage['notification'] ?? [], JSON_THROW_ON_ERROR);
        $this->assertStringNotContainsString('123456', $pushPreview);
        $this->assertStringNotContainsString('0123456789', $pushPreview);
        $this->assertStringNotContainsString('9,999.00', $pushPreview);
    }

    public function test_admin_history_reports_partial_delivery_across_customer_devices(): void
    {
        $this->seedTenant('par_notify_history', 'ten_notify_history', 'notify-history.test');
        $this->seedCustomer('ten_notify_history', 'cus_notify_history', 'CUS-NOTIFY-HISTORY');
        $service = app(CustomerNotificationService::class);

        foreach (['phone', 'tablet'] as $suffix) {
            $service->registerDevice('ten_notify_history', 'cus_notify_history', [
                'installation_id' => 'install_notify_history_'.$suffix,
                'platform' => 'android',
                'fcm_token' => str_repeat($suffix.'-history-token-', 10),
                'locale' => 'th-TH',
            ]);
        }
        $service->createForCustomer(
            'ten_notify_history',
            'cus_notify_history',
            'admin.direct_message',
            [
                'category' => 'admin',
                'title' => ['th-TH' => 'ข้อความทดสอบ'],
                'body' => ['th-TH' => 'ตรวจสอบสถานะการส่ง'],
                'action_key' => 'none',
                'subject_type' => 'admin_message',
                'subject_id' => 'history-partial',
            ],
            [
                'creator_type' => 'tenant_admin',
                'dedupe_key' => 'history-partial',
            ],
        );

        $deliveries = CustomerNotificationDelivery::query()->orderBy('id')->get();
        $this->assertCount(2, $deliveries);
        $deliveries[0]->forceFill([
            'status' => 'sent',
            'sent_at' => now()->subMinute(),
            'updated_at' => now()->subMinute(),
        ])->save();
        $deliveries[1]->forceFill([
            'status' => 'failed',
            'last_error_code' => 'provider_auth_failed',
            'failed_at' => now(),
            'updated_at' => now(),
        ])->save();

        $history = $service->adminList('ten_notify_history', ['creator_type' => 'tenant_admin']);
        $push = $history['data'][0]['recipients'][0]['push'];
        $this->assertSame('partial', $push['status']);
        $this->assertSame(2, $push['total_count']);
        $this->assertSame(1, $push['sent_count']);
        $this->assertSame(0, $push['pending_count']);
        $this->assertSame(1, $push['failed_count']);
        $this->assertSame('provider_auth_failed', $push['last_error_code']);
    }

    public function test_domain_events_create_deduplicated_notifications_and_suppress_derived_wallet_entries(): void
    {
        $this->seedTenant('par_notify_domain', 'ten_notify_domain', 'notify-domain.test');
        $this->seedCustomer('ten_notify_domain', 'cus_notify_domain', 'CUS-NOTIFY-DOMAIN');

        $paidOrder = [
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'order_id' => 'ord_notify_domain',
            'game_id' => 'gam_notify_domain',
            'status' => 'paid',
            'payment_status' => 'paid',
        ];
        CustomerOrderUpdated::dispatch($paidOrder);
        CustomerOrderUpdated::dispatch($paidOrder);

        $pendingTopup = [
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'topup_id' => 'top_notify_domain',
            'source_status' => 'pending',
            'topup' => ['status' => 'pending_review'],
        ];
        CustomerTopupUpdated::dispatch($pendingTopup);
        CustomerTopupUpdated::dispatch($pendingTopup);
        CustomerTopupUpdated::dispatch([
            ...$pendingTopup,
            'source_status' => 'succeeded',
            'topup' => ['status' => 'approved'],
        ]);

        CustomerWalletUpdated::dispatch([
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'wallet_id' => 'wal_notify_domain',
            'ledger_id' => 'wle_notify_topup',
            'entry_type' => 'credit',
            'amount' => 10000,
            'reference_type' => 'topup',
            'reference_id' => 'top_notify_domain',
        ]);
        foreach (['affiliate_payout', 'refund'] as $referenceType) {
            CustomerWalletUpdated::dispatch([
                'tenant_id' => 'ten_notify_domain',
                'customer_id' => 'cus_notify_domain',
                'wallet_id' => 'wal_notify_domain',
                'ledger_id' => 'wle_notify_'.$referenceType,
                'entry_type' => 'credit',
                'amount' => 10000,
                'reference_type' => $referenceType,
                'reference_id' => 'ref_notify_'.$referenceType,
            ]);
        }
        CustomerWalletUpdated::dispatch([
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'wallet_id' => 'wal_notify_domain',
            'ledger_id' => 'wle_notify_adjustment',
            'entry_type' => 'adjustment',
            'amount' => 500,
            'reference_type' => 'admin_wallet_adjust',
            'reference_id' => 'wal_notify_domain',
        ]);

        RewardClaimUpdated::dispatch([
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'claim_id' => 'rcl_notify_domain',
            'claim' => ['id' => 'rcl_notify_domain', 'status' => 'submitted'],
        ]);
        RewardClaimUpdated::dispatch([
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'claim_id' => 'rcl_notify_domain',
            'claim' => ['id' => 'rcl_notify_domain', 'status' => 'approved'],
        ]);
        ActivityClaimUpdated::dispatch([
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'claim_id' => 'acl_notify_domain',
            'claim' => ['id' => 'acl_notify_domain', 'status' => 'submitted'],
        ]);
        ActivityClaimUpdated::dispatch([
            'tenant_id' => 'ten_notify_domain',
            'customer_id' => 'cus_notify_domain',
            'claim_id' => 'acl_notify_domain',
            'claim' => ['id' => 'acl_notify_domain', 'status' => 'paid'],
        ]);

        $this->assertDatabaseCount('customer_notifications', 8);
        $this->assertDatabaseCount('customer_notification_recipients', 8);
        $this->assertDatabaseMissing('customer_notifications', ['subject_id' => 'wle_notify_topup']);
        $this->assertDatabaseMissing('customer_notifications', ['subject_id' => 'wle_notify_affiliate_payout']);
        $this->assertDatabaseMissing('customer_notifications', ['subject_id' => 'wle_notify_refund']);
        foreach ([
            'order.paid',
            'topup.submitted',
            'topup.succeeded',
            'wallet.credited',
            'reward_claim.submitted',
            'reward_claim.approved',
            'activity_claim.submitted',
            'activity_claim.paid',
        ] as $eventKey) {
            $this->assertDatabaseHas('customer_notifications', [
                'tenant_id' => 'ten_notify_domain',
                'event_key' => $eventKey,
            ]);
        }
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'order.paid',
            'action_key' => 'tickets',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'topup.succeeded',
            'action_key' => 'topup',
            'action_entity_id' => 'top_notify_domain',
        ]);
    }

    public function test_order_and_topup_catalog_preserves_customer_destinations_and_business_statuses(): void
    {
        $this->seedTenant('par_notify_catalog', 'ten_notify_catalog', 'notify-catalog.test');
        $this->seedCustomer('ten_notify_catalog', 'cus_notify_catalog', 'CUS-NOTIFY-CATALOG');
        $events = app(CustomerNotificationDomainEventService::class);

        foreach (['pending_payment', 'failed', 'cancelled', 'expired', 'refunded'] as $status) {
            $events->orderUpdated([
                'tenant_id' => 'ten_notify_catalog',
                'customer_id' => 'cus_notify_catalog',
                'order_id' => 'ord_notify_'.$status,
                'status' => $status,
                'payment_status' => $status === 'refunded' ? 'refunded' : 'pending',
            ]);
        }

        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'order.waiting_payment',
            'action_key' => 'checkout_pending',
            'action_entity_id' => 'ord_notify_pending_payment',
        ]);
        foreach (['failed', 'cancelled', 'expired', 'refunded'] as $status) {
            $this->assertDatabaseHas('customer_notifications', [
                'event_key' => 'order.'.$status,
                'action_key' => 'order',
                'action_entity_id' => 'ord_notify_'.$status,
            ]);
        }

        foreach (['pending', 'succeeded', 'approved', 'failed', 'rejected', 'cancelled', 'expired', 'reversed'] as $status) {
            $events->topupUpdated([
                'tenant_id' => 'ten_notify_catalog',
                'customer_id' => 'cus_notify_catalog',
                'topup_id' => 'top_notify_'.$status,
                'source_status' => $status,
            ]);
        }
        foreach (['submitted', 'succeeded', 'approved', 'failed', 'rejected', 'cancelled', 'expired', 'reversed'] as $transition) {
            $this->assertDatabaseHas('customer_notifications', [
                'event_key' => 'topup.'.$transition,
                'action_key' => 'topup',
            ]);
        }
    }

    public function test_claim_affiliate_activity_and_security_catalog_has_every_safe_transition(): void
    {
        $this->seedTenant('par_notify_full_catalog', 'ten_notify_full_catalog', 'notify-full-catalog.test');
        $this->seedCustomer('ten_notify_full_catalog', 'cus_notify_full_catalog', 'CUS-NOTIFY-FULL-CATALOG');
        $events = app(CustomerNotificationDomainEventService::class);
        $now = now();

        foreach (['submitted', 'under_review', 'approved', 'rejected', 'cancelled', 'paid'] as $status) {
            $events->rewardClaimUpdated([
                'tenant_id' => 'ten_notify_full_catalog',
                'customer_id' => 'cus_notify_full_catalog',
                'claim_id' => 'rcl_notify_'.$status,
                'claim' => ['id' => 'rcl_notify_'.$status, 'status' => $status],
            ]);
            $events->activityClaimUpdated([
                'tenant_id' => 'ten_notify_full_catalog',
                'customer_id' => 'cus_notify_full_catalog',
                'claim_id' => 'acl_notify_'.$status,
                'claim' => ['id' => 'acl_notify_'.$status, 'status' => $status],
            ]);
        }

        $events->activityEntrySubmitted(
            'ten_notify_full_catalog',
            'cus_notify_full_catalog',
            'aen_notify_catalog',
            'act_notify_catalog',
            'activity-notify-catalog',
        );
        $events->activityAwardGranted(
            'ten_notify_full_catalog',
            'cus_notify_full_catalog',
            'awa_notify_catalog',
            'act_notify_catalog',
            'activity-notify-catalog',
        );

        DB::table('affiliate_accounts')->insert([
            'id' => 'aff_notify_catalog',
            'tenant_id' => 'ten_notify_full_catalog',
            'customer_id' => 'cus_notify_full_catalog',
            'code' => 'AFF-NOTIFY-CATALOG',
            'name' => 'Notification Affiliate',
            'status' => 'active',
            'wallet_balance_amount' => 0,
            'currency' => 'THB',
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        DB::table('affiliate_payouts')->insert([
            'id' => 'pyo_notify_catalog',
            'tenant_id' => 'ten_notify_full_catalog',
            'affiliate_account_id' => 'aff_notify_catalog',
            'status' => 'pending',
            'payout_method' => 'bank_transfer',
            'amount' => 10000,
            'currency' => 'THB',
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        $events->affiliateRegistered('ten_notify_full_catalog', 'cus_notify_full_catalog', 'aff_notify_catalog');
        $events->affiliateCommissionAvailable('ten_notify_full_catalog', 'aff_notify_catalog', 'ctx_notify_catalog');
        foreach (['pending', 'approved', 'rejected', 'cancelled', 'paid'] as $status) {
            DB::table('affiliate_payouts')->where('id', 'pyo_notify_catalog')->update([
                'status' => $status,
                'updated_at' => now(),
            ]);
            $events->affiliatePayoutUpdated('ten_notify_full_catalog', 'pyo_notify_catalog');
        }

        $events->pinChanged('ten_notify_full_catalog', 'cus_notify_full_catalog', 'pin-transition');
        $events->passwordChanged('ten_notify_full_catalog', 'cus_notify_full_catalog', 'password-transition');
        $events->biometricDeviceChanged(
            'ten_notify_full_catalog',
            'cus_notify_full_catalog',
            'cbd_notify_catalog',
            'active',
            'biometric-added-transition',
        );
        $events->biometricDeviceChanged(
            'ten_notify_full_catalog',
            'cus_notify_full_catalog',
            'cbd_notify_catalog',
            'revoked',
            'biometric-revoked-transition',
        );
        $events->accountStatusChanged(
            'ten_notify_full_catalog',
            'cus_notify_full_catalog',
            'suspended',
            'account-suspended-transition',
        );
        $events->accountStatusChanged(
            'ten_notify_full_catalog',
            'cus_notify_full_catalog',
            'active',
            'account-restored-transition',
        );

        foreach (['submitted', 'under_review', 'approved', 'rejected', 'cancelled', 'paid'] as $status) {
            $this->assertDatabaseHas('customer_notifications', [
                'event_key' => 'reward_claim.'.$status,
                'action_key' => 'reward_claim',
                'action_entity_id' => 'rcl_notify_'.$status,
            ]);
            $this->assertDatabaseHas('customer_notifications', [
                'event_key' => 'activity_claim.'.$status,
                'action_key' => 'activity_claim',
                'action_entity_id' => 'acl_notify_'.$status,
            ]);
        }
        foreach ([
            'activity.entry.submitted',
            'activity.award.granted',
            'affiliate.registration.completed',
            'affiliate.commission.available',
            'affiliate.payout.submitted',
            'affiliate.payout.approved',
            'affiliate.payout.rejected',
            'affiliate.payout.cancelled',
            'affiliate.payout.paid',
            'account.pin.changed',
            'account.password.changed',
            'account.biometric.added',
            'account.biometric.revoked',
            'account.suspended',
            'account.restored',
        ] as $eventKey) {
            $this->assertDatabaseHas('customer_notifications', [
                'tenant_id' => 'ten_notify_full_catalog',
                'event_key' => $eventKey,
            ]);
        }
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'activity.entry.submitted',
            'action_key' => 'activity',
            'action_entity_id' => 'activity-notify-catalog',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'affiliate.payout.paid',
            'action_key' => 'affiliate',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'account.password.changed',
            'action_key' => 'none',
            'subject_id' => 'cus_notify_full_catalog',
        ]);
    }

    public function test_domain_notification_failures_do_not_escape_and_suspended_accounts_keep_security_inbox_events(): void
    {
        $this->seedTenant('par_notify_failure', 'ten_notify_failure', 'notify-failure.test');
        $this->seedCustomer('ten_notify_failure', 'cus_notify_suspended', 'CUS-NOTIFY-SUSPENDED', 'suspended');

        app(CustomerNotificationDomainEventService::class)->accountStatusChanged(
            'ten_notify_failure',
            'cus_notify_suspended',
            'suspended',
            'status-transition-1',
        );
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => 'ten_notify_failure',
            'event_key' => 'account.suspended',
            'subject_id' => 'cus_notify_suspended',
        ]);

        $this->mock(CustomerNotificationService::class, function (MockInterface $mock): void {
            $mock->shouldReceive('createForCustomer')->once()->andThrow(new \RuntimeException('notification storage unavailable'));
        });
        $this->app->forgetInstance(CustomerNotificationDomainEventService::class);

        app(CustomerNotificationDomainEventService::class)->orderUpdated([
            'tenant_id' => 'ten_notify_failure',
            'customer_id' => 'cus_notify_suspended',
            'order_id' => 'ord_notify_failure',
            'status' => 'failed',
            'payment_status' => 'failed',
        ]);

        $this->assertTrue(true);
    }

    public function test_reward_result_fanout_notifies_each_owner_once_and_routes_winners_to_their_ticket(): void
    {
        $this->seedTenant('par_notify_result', 'ten_notify_result', 'notify-result.test');
        $this->seedCustomer('ten_notify_result', 'cus_notify_winner', 'CUS-NOTIFY-WINNER');
        $this->seedCustomer('ten_notify_result', 'cus_notify_non_winner', 'CUS-NOTIFY-NON-WINNER');
        $now = now();

        DB::table('games')->insert([
            'id' => 'gam_notify_result',
            'code' => 'NOTIFY-RESULT',
            'name' => 'Notification Draw',
            'draw_at' => $now,
            'status' => 'reward_published',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        foreach ([
            ['suffix' => 'winner', 'customer_id' => 'cus_notify_winner', 'number' => '123456'],
            ['suffix' => 'non_winner', 'customer_id' => 'cus_notify_non_winner', 'number' => '654321'],
        ] as $owner) {
            DB::table('stock_items')->insert([
                'id' => 'stk_notify_'.$owner['suffix'],
                'game_id' => 'gam_notify_result',
                'full_number' => $owner['number'],
                'status' => 'sold',
                'partner_id' => 'par_notify_result',
                'tenant_id' => 'ten_notify_result',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('local_stock_items')->insert([
                'id' => 'lst_notify_'.$owner['suffix'],
                'tenant_id' => 'ten_notify_result',
                'partner_id' => 'par_notify_result',
                'game_id' => 'gam_notify_result',
                'stock_item_id' => 'stk_notify_'.$owner['suffix'],
                'full_number' => $owner['number'],
                'status' => 'sold',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('stock_reservations')->insert([
                'id' => 'res_notify_'.$owner['suffix'],
                'tenant_id' => 'ten_notify_result',
                'customer_id' => $owner['customer_id'],
                'game_id' => 'gam_notify_result',
                'status' => 'converted',
                'expires_at' => $now->copy()->addHour(),
                'converted_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('orders')->insert([
                'id' => 'ord_notify_'.$owner['suffix'],
                'tenant_id' => 'ten_notify_result',
                'customer_id' => $owner['customer_id'],
                'reservation_id' => 'res_notify_'.$owner['suffix'],
                'game_id' => 'gam_notify_result',
                'payment_method' => 'wallet',
                'status' => 'paid',
                'payment_status' => 'paid',
                'total_amount' => 8000,
                'currency' => 'THB',
                'paid_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
            DB::table('tickets')->insert([
                'id' => 'tic_notify_'.$owner['suffix'],
                'tenant_id' => 'ten_notify_result',
                'customer_id' => $owner['customer_id'],
                'order_id' => 'ord_notify_'.$owner['suffix'],
                'local_stock_item_id' => 'lst_notify_'.$owner['suffix'],
                'game_id' => 'gam_notify_result',
                'full_number' => $owner['number'],
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }

        DB::table('reward_results')->insert([
            'id' => 'rrs_notify_result',
            'game_id' => 'gam_notify_result',
            'status' => 'published',
            'version' => 3,
            'published_at' => $now,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        DB::table('reward_prizes')->insert([
            'id' => 'rpr_notify_result',
            'reward_result_id' => 'rrs_notify_result',
            'game_id' => 'gam_notify_result',
            'prize_type' => 'first_prize',
            'prize_number' => '123456',
            'amount' => 600000000,
            'currency' => 'THB',
            'sort_order' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        DB::table('winning_tickets')->insert([
            'id' => 'wti_notify_result',
            'tenant_id' => 'ten_notify_result',
            'game_id' => 'gam_notify_result',
            'ticket_id' => 'tic_notify_winner',
            'reward_result_id' => 'rrs_notify_result',
            'reward_prize_id' => 'rpr_notify_result',
            'prize_type' => 'first_prize',
            'prize_number' => '123456',
            'amount' => 600000000,
            'currency' => 'THB',
            'status' => 'verified',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $service = app(CustomerNotificationDomainEventService::class);
        $service->fanOutRewardResultChunk('rrs_notify_result');
        $service->fanOutRewardResultChunk('rrs_notify_result');

        $this->assertDatabaseCount('customer_notifications', 2);
        $this->assertDatabaseCount('customer_notification_recipients', 2);
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'lottery.result.winning',
            'action_key' => 'ticket',
            'action_entity_id' => 'tic_notify_winner',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'event_key' => 'lottery.result.published',
            'action_key' => 'tickets',
            'action_entity_id' => null,
        ]);
    }

    private function customerToken(string $tenantId, string $customerId): string
    {
        $session = app(CustomerAuthService::class)->issueSession(
            $tenantId,
            $customerId,
            null,
            now()->toDateTimeString(),
        );

        return (string) $session['token'];
    }

    private function seedTenant(string $partnerId, string $tenantId, string $host): void
    {
        DB::table('partners')->insert([
            'id' => $partnerId,
            'code' => $partnerId,
            'name' => 'Notification Partner',
            'type' => 'partner_store',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('partner_tenants')->insert([
            'id' => $tenantId,
            'partner_id' => $partnerId,
            'code' => $tenantId,
            'name' => 'Notification Tenant',
            'status' => 'active',
            'created_at' => now(),
            'updated_at' => now(),
        ]);
        DB::table('partner_tenant_domains')->insert([
            'id' => 'ptd_'.substr(sha1($tenantId), 0, 20),
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
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

    private function seedCustomer(
        string $tenantId,
        string $customerId,
        string $customerNo,
        string $status = 'active',
    ): void {
        DB::table('customers')->insert([
            'id' => $customerId,
            'tenant_id' => $tenantId,
            'customer_no' => $customerNo,
            'phone' => '08'.substr(sha1($customerId), 0, 8),
            'name' => 'Notification Customer',
            'pin_hash' => Hash::make('123456'),
            'pin_set_at' => now(),
            'pin_changed_at' => now(),
            'pin_failed_attempts' => 0,
            'status' => $status,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
