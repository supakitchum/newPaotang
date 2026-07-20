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
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Event;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Queue;
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
            ])
            ->assertCreated()
            ->assertJsonPath('installation_id', 'install_notify_device_001')
            ->assertJsonPath('registered', true);

        $rawToken = (string) DB::table('customer_push_devices')->value('fcm_token_encrypted');
        $this->assertNotSame($fcmToken, $rawToken);
        $this->assertSame($fcmToken, CustomerPushDevice::query()->firstOrFail()->fcm_token_encrypted);

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

        $this->assertArrayHasKey('action_entity_id', $missingEntity['errors'] ?? []);
        $this->assertArrayHasKey('action_entity_id', $externalEntity['errors'] ?? []);

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
