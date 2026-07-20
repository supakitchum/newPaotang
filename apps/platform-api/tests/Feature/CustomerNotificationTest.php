<?php

namespace Tests\Feature;

use App\Jobs\FanoutCustomerNotificationRecipientsJob;
use App\Jobs\SendCustomerPushNotificationJob;
use App\Models\CustomerNotificationDelivery;
use App\Models\CustomerPushDevice;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\CustomerNotifications\Events\CustomerNotificationChanged;
use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\CustomerNotifications\Services\FirebaseCloudMessagingClient;
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
