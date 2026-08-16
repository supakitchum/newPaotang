<?php

namespace Tests\Feature;

use App\Jobs\FanoutCustomerNotificationRecipientsJob;
use App\Jobs\FanoutCustomerPushInstallationsJob;
use App\Models\CustomerNotificationDelivery;
use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use App\Modules\CustomerNotifications\Services\FirebaseCloudMessagingClient;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Queue;
use Illuminate\Support\Facades\Storage;
use Mockery\MockInterface;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class CustomerCommunicationCampaignTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    protected function setUp(): void
    {
        parent::setUp();

        config([
            'app.key' => 'base64:'.base64_encode(str_repeat('c', 32)),
            'services.firebase_cloud_messaging.project_id' => '',
        ]);
        $this->app->forgetInstance('encrypter');
        Queue::fake();
        Storage::fake('lottery_images');
    }

    public function test_scheduled_broadcast_is_idempotent_and_only_fans_out_to_active_customers(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_customer_comms',
            'ten_customer_comms',
            'customer-comms.example.test',
        );
        $this->issueCustomerToken('ten_customer_comms', 'cus_customer_comms_1');
        $this->issueCustomerToken('ten_customer_comms', 'cus_customer_comms_2');
        $this->issueCustomerToken('ten_customer_comms', 'cus_customer_comms_suspended');
        DB::table('customers')->where('id', 'cus_customer_comms_suspended')->update(['status' => 'suspended']);
        $admin = $this->createTenantSession(
            'ten_customer_comms',
            'par_customer_comms',
            ['customer_notification.view', 'customer_notification.send'],
            'adm_customer_comms',
            'customer-comms@example.test',
        );
        $headers = [
            'X-Admin-Scope' => 'tenant',
            'X-Tenant-Id' => 'ten_customer_comms',
            'Idempotency-Key' => 'customer-comms-scheduled-broadcast',
        ];
        $request = [
            'payload' => json_encode([
                'name' => 'August public relations',
                'audience_type' => 'all_customers',
                'title' => ['th-TH' => 'ข่าวประชาสัมพันธ์', 'en-US' => 'Public relations update'],
                'body' => ['th-TH' => 'ติดตามข่าวล่าสุดได้แล้ววันนี้', 'en-US' => 'See the latest update today.'],
                'action_key' => 'home',
                'delivery_mode' => 'scheduled',
                'scheduled_at' => now()->addMinutes(10)->toISOString(),
            ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
        ];

        $created = $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', $request, $headers)
            ->assertCreated()
            ->assertJsonPath('status', 'scheduled')
            ->assertJsonPath('audience_type', 'all_customers')
            ->json();

        $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', $request, $headers)
            ->assertCreated()
            ->assertJsonPath('id', $created['id']);

        $this->assertDatabaseCount('customer_communication_campaigns', 1);
        $this->assertDatabaseCount('customer_notifications', 0);
        Queue::assertNotPushed(FanoutCustomerNotificationRecipientsJob::class);

        DB::table('customer_communication_campaigns')->where('id', $created['id'])->update([
            'scheduled_at' => now()->subMinute(),
            'updated_at' => now(),
        ]);

        $this->artisan('customer-communications:publish-due --limit=25')
            ->expectsOutput('Customer communication campaigns: selected=1 published=1 failed=0')
            ->assertSuccessful();

        $this->assertDatabaseHas('customer_communication_campaigns', [
            'id' => $created['id'],
            'status' => 'published',
        ]);
        $this->assertDatabaseHas('customer_notifications', [
            'tenant_id' => 'ten_customer_comms',
            'event_key' => 'admin.communication_campaign',
            'subject_type' => 'customer_communication_campaign',
            'subject_id' => $created['id'],
        ]);
        Queue::assertPushed(FanoutCustomerNotificationRecipientsJob::class, 1);

        $notificationId = (string) DB::table('customer_notifications')->value('id');
        $notifications = app(CustomerNotificationService::class);
        $notifications->fanOutTenantChunk($notificationId);
        $notifications->fanOutTenantChunk($notificationId);

        $this->assertDatabaseCount('customer_notification_recipients', 2);
        $this->assertDatabaseMissing('customer_notification_recipients', [
            'customer_id' => 'cus_customer_comms_suspended',
        ]);

        $this->artisan('customer-communications:publish-due --limit=25')
            ->expectsOutput('Customer communication campaigns: selected=0 published=0 failed=0')
            ->assertSuccessful();
        $this->assertDatabaseCount('customer_notifications', 1);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms',
            ])
            ->assertOk()
            ->assertJsonPath('data.0.id', $created['id'])
            ->assertJsonPath('data.0.stats.recipient_count', 2)
            ->assertJsonPath('meta.campaign_counts.total', 1)
            ->assertJsonPath('meta.campaign_counts.published', 1);

        $readRecipientId = DB::table('customer_notification_recipients')
            ->where('notification_id', $notificationId)
            ->orderBy('id')
            ->value('id');
        DB::table('customer_notification_recipients')
            ->where('id', $readRecipientId)
            ->update(['read_at' => now(), 'updated_at' => now()]);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/customer-notifications/campaigns/'.$created['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms',
            ])
            ->assertOk()
            ->assertJsonPath('id', $created['id'])
            ->assertJsonPath('delivery_mode', 'scheduled')
            ->assertJsonPath('stats.recipient_count', 2)
            ->assertJsonPath('stats.read_count', 1)
            ->assertJsonPath('stats.unread_count', 1)
            ->assertJsonPath('delivery_breakdown.statuses', [])
            ->assertJsonPath('delivery_breakdown.platforms', []);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/customer-notifications/campaigns?q=august&audience_type=all_customers', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms',
            ])
            ->assertOk()
            ->assertJsonCount(1, 'data')
            ->assertJsonPath('data.0.id', $created['id']);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/customer-notifications/campaigns/ccp_missing', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms',
            ])
            ->assertNotFound();
    }

    public function test_scheduled_campaign_preserves_the_requested_instant_with_a_bangkok_database_session(): void
    {
        $this->useBangkokClock('2026-08-16T12:00:00+07:00');
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_comms_timezone',
            'ten_comms_timezone',
            'customer-comms-timezone.example.test',
        );
        $this->issueCustomerToken('ten_comms_timezone', 'cus_comms_timezone');
        $admin = $this->createTenantSession(
            'ten_comms_timezone',
            'par_comms_timezone',
            ['customer_notification.view', 'customer_notification.send'],
            'adm_comms_timezone',
            'customer-comms-timezone@example.test',
        );
        $scheduledAt = '2026-08-16T06:40:00Z';

        $created = $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'payload' => $this->scheduledPayload($scheduledAt, 'Bangkok persistence'),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_comms_timezone',
                'Idempotency-Key' => 'customer-comms-timezone-persistence',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'scheduled')
            ->json();

        $expectedTimestamp = Carbon::parse($scheduledAt)->timestamp;
        $stored = DB::selectOne(
            'SELECT EXTRACT(EPOCH FROM scheduled_at)::bigint AS epoch, scheduled_at::text AS local_value FROM customer_communication_campaigns WHERE id = ?',
            [$created['id']],
        );
        $this->assertNotNull($stored);
        $this->assertSame('Asia/Bangkok', (string) DB::selectOne("SELECT current_setting('TIMEZONE') AS timezone")->timezone);
        $this->assertSame($expectedTimestamp, (int) $stored->epoch);
        $this->assertStringStartsWith('2026-08-16 13:40:00+07', (string) $stored->local_value);
        $this->assertSame(Carbon::parse($scheduledAt)->toISOString(), (string) $created['scheduled_at']);
        $this->assertSame($expectedTimestamp, Carbon::parse((string) $created['scheduled_at'])->timestamp);

        Carbon::setTestNow(Carbon::parse('2026-08-16T13:39:59+07:00'));
        $this->artisan('customer-communications:publish-due --limit=25')
            ->expectsOutput('Customer communication campaigns: selected=0 published=0 failed=0')
            ->assertSuccessful();
        $this->assertDatabaseCount('customer_notifications', 0);

        Carbon::setTestNow(Carbon::parse('2026-08-16T13:40:00+07:00'));
        $this->artisan('customer-communications:publish-due --limit=25')
            ->expectsOutput('Customer communication campaigns: selected=1 published=1 failed=0')
            ->assertSuccessful();
        $this->assertDatabaseCount('customer_notifications', 1);

        $this->artisan('customer-communications:publish-due --limit=25')
            ->expectsOutput('Customer communication campaigns: selected=0 published=0 failed=0')
            ->assertSuccessful();
        $this->assertDatabaseCount('customer_notifications', 1);
    }

    public function test_scheduled_campaign_requires_an_offset_and_round_trips_supported_offsets(): void
    {
        $this->useBangkokClock('2026-08-16T12:00:00+07:00');
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_comms_offsets',
            'ten_comms_offsets',
            'customer-comms-offsets.example.test',
        );
        $admin = $this->createTenantSession(
            'ten_comms_offsets',
            'par_comms_offsets',
            ['customer_notification.view', 'customer_notification.send'],
            'adm_comms_offsets',
            'customer-comms-offsets@example.test',
        );
        $expectedTimestamp = Carbon::parse('2026-08-16T06:40:00Z')->timestamp;
        $variants = [
            'utc' => '2026-08-16T06:40:00Z',
            'bangkok' => '2026-08-16T13:40:00+07:00',
            'negative' => '2026-08-16T02:40:00-04:00',
        ];

        foreach ($variants as $key => $scheduledAt) {
            $created = $this->withToken($admin['access_token'])
                ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                    'payload' => $this->scheduledPayload($scheduledAt, 'Offset '.$key),
                ], [
                    'X-Admin-Scope' => 'tenant',
                    'X-Tenant-Id' => 'ten_comms_offsets',
                    'Idempotency-Key' => 'customer-comms-offset-'.$key,
                ])
                ->assertCreated()
                ->assertJsonPath('status', 'scheduled')
                ->json();

            $storedEpoch = DB::table('customer_communication_campaigns')
                ->where('id', $created['id'])
                ->selectRaw('EXTRACT(EPOCH FROM scheduled_at)::bigint AS epoch')
                ->value('epoch');
            $this->assertSame($expectedTimestamp, (int) $storedEpoch, 'Stored instant changed for '.$scheduledAt);
            $this->assertSame(
                $expectedTimestamp,
                Carbon::parse((string) $created['scheduled_at'])->timestamp,
                'Response instant changed for '.$scheduledAt,
            );
            $this->assertSame(
                Carbon::parse($scheduledAt)->toISOString(),
                (string) $created['scheduled_at'],
                'Response was not canonical UTC for '.$scheduledAt,
            );
        }

        $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'payload' => $this->scheduledPayload('2026-08-16T13:40:00', 'Missing offset'),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_comms_offsets',
                'Idempotency-Key' => 'customer-comms-missing-offset',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath(
                'error.details.fields.scheduled_at.0',
                'Enter a valid campaign date and time with a timezone offset.',
            );

        $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'payload' => $this->scheduledPayload('2026-08-16T12:01:00+07:00', 'Too soon'),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_comms_offsets',
                'Idempotency-Key' => 'customer-comms-too-soon',
            ])
            ->assertUnprocessable()
            ->assertJsonPath(
                'error.details.fields.scheduled_at.0',
                'Schedule the campaign at least one minute in the future.',
            );

        $this->assertDatabaseCount('customer_communication_campaigns', count($variants));
        $this->assertDatabaseCount('customer_notifications', 0);
    }

    public function test_image_campaign_reaches_inbox_and_native_push_with_the_exact_content(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_customer_comms_image',
            'ten_customer_comms_image',
            'customer-comms-image.example.test',
        );
        $customerToken = $this->issueCustomerToken('ten_customer_comms_image', 'cus_customer_comms_image');
        app(CustomerNotificationService::class)->registerDevice(
            'ten_customer_comms_image',
            'cus_customer_comms_image',
            [
                'installation_id' => 'install_customer_comms_image',
                'platform' => 'android',
                'fcm_token' => str_repeat('customer-comms-image-token-', 8),
                'locale' => 'th-TH',
            ],
        );
        $admin = $this->createTenantSession(
            'ten_customer_comms_image',
            'par_customer_comms_image',
            ['customer_notification.view', 'customer_notification.send'],
            'adm_customer_comms_image',
            'customer-comms-image@example.test',
        );
        $payload = json_encode([
            'name' => 'Rich image message',
            'audience_type' => 'customer',
            'customer_id' => 'cus_customer_comms_image',
            'title' => ['th-TH' => 'โปรโมชั่นพิเศษ'],
            'body' => ['th-TH' => 'รับสิทธิ์ได้ถึงเที่ยงคืนนี้'],
            'action_key' => 'wallet',
            'delivery_mode' => 'now',
        ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
        $png = base64_decode(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAusB9Wl2n3cAAAAASUVORK5CYII=',
            true,
        );

        $created = $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'payload' => $payload,
                'file' => UploadedFile::fake()->createWithContent('campaign.png', (string) $png),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms_image',
                'Idempotency-Key' => 'customer-comms-image-now',
            ])
            ->assertCreated()
            ->assertJsonPath('status', 'published')
            ->json();

        $this->assertNotEmpty($created['image']['url'] ?? null);
        $this->assertNotEmpty($created['image']['thumb_url'] ?? null);
        $this->assertDatabaseCount('platform_assets', 2);
        $this->assertDatabaseHas('platform_assets', [
            'tenant_id' => 'ten_customer_comms_image',
            'purpose' => 'customer_communication_image',
            'status' => 'committed',
        ]);
        $imagePath = (string) parse_url((string) $created['image']['url'], PHP_URL_PATH);
        $imageResponse = $this->get($imagePath)->assertOk();
        $this->assertStringStartsWith('image/', (string) $imageResponse->headers->get('Content-Type'));

        $this->withToken($customerToken)
            ->getJson('http://customer-comms-image.example.test/api/v1/customer/notifications')
            ->assertOk()
            ->assertJsonPath('data.0.title', 'โปรโมชั่นพิเศษ')
            ->assertJsonPath('data.0.body', 'รับสิทธิ์ได้ถึงเที่ยงคืนนี้')
            ->assertJsonPath('data.0.image_url', $created['image']['url'])
            ->assertJsonPath('data.0.image_thumb_url', $created['image']['thumb_url']);

        $sentMessage = null;
        $this->mock(FirebaseCloudMessagingClient::class, function (MockInterface $mock) use (&$sentMessage): void {
            $mock->shouldReceive('send')
                ->once()
                ->with(\Mockery::on(function (array $message) use (&$sentMessage): bool {
                    $sentMessage = $message;

                    return true;
                }))
                ->andReturn(['ok' => true, 'message_id' => 'projects/test/messages/customer-comms-image']);
        });
        $this->app->forgetInstance(CustomerNotificationService::class);
        app(CustomerNotificationService::class)->processDelivery(
            (string) CustomerNotificationDelivery::query()->value('id'),
        );

        $this->assertIsArray($sentMessage);
        $this->assertSame('โปรโมชั่นพิเศษ', $sentMessage['notification']['title'] ?? null);
        $this->assertSame('รับสิทธิ์ได้ถึงเที่ยงคืนนี้', $sentMessage['notification']['body'] ?? null);
        $this->assertSame($created['image']['url'], $sentMessage['notification']['image'] ?? null);
        $this->assertSame($created['image']['url'], $sentMessage['android']['notification']['image'] ?? null);
        $this->assertSame($created['image']['url'], $sentMessage['apns']['fcm_options']['image'] ?? null);
        $this->assertSame($created['image']['url'], $sentMessage['data']['image_url'] ?? null);
    }

    public function test_campaign_rejects_a_file_that_only_claims_to_be_an_image(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_customer_comms_invalid',
            'ten_customer_comms_invalid',
            'customer-comms-invalid.example.test',
        );
        $admin = $this->createTenantSession(
            'ten_customer_comms_invalid',
            'par_customer_comms_invalid',
            ['customer_notification.view', 'customer_notification.send'],
            'adm_customer_comms_invalid',
            'customer-comms-invalid@example.test',
        );

        $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'payload' => json_encode([
                    'audience_type' => 'all_customers',
                    'title' => ['th-TH' => 'ข่าวประชาสัมพันธ์'],
                    'body' => ['th-TH' => 'รายละเอียดข่าวประชาสัมพันธ์'],
                    'action_key' => 'home',
                    'delivery_mode' => 'now',
                ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
                'file' => UploadedFile::fake()->createWithContent('not-an-image.png', '<script>alert(1)</script>'),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms_invalid',
                'Idempotency-Key' => 'customer-comms-invalid-image',
            ])
            ->assertUnprocessable()
            ->assertJsonPath('error.code', 'validation_failed')
            ->assertJsonPath('error.details.fields.file.0', 'The image must be a valid JPG, PNG, or WebP file.');

        $this->assertDatabaseCount('customer_communication_campaigns', 0);
        $this->assertDatabaseCount('platform_assets', 0);
        $this->assertDatabaseCount('customer_notifications', 0);
    }

    public function test_installation_audiences_send_push_without_creating_customer_inbox_rows(): void
    {
        $this->seedDefaultRbac();
        $this->insertActivePartnerTenantWithDomain(
            'par_customer_comms_installs',
            'ten_customer_comms_installs',
            'customer-comms-installs.example.test',
        );
        $this->issueCustomerToken('ten_customer_comms_installs', 'cus_customer_comms_installs');
        $notifications = app(CustomerNotificationService::class);
        $notifications->registerDevice(
            'ten_customer_comms_installs',
            'cus_customer_comms_installs',
            [
                'installation_id' => 'install_customer_comms_logged_in',
                'installation_secret' => 'secret_customer_comms_logged_in_123456',
                'platform' => 'android',
                'fcm_token' => str_repeat('customer-comms-logged-in-token-', 8),
                'locale' => 'th-TH',
            ],
        );
        $notifications->registerAnonymousInstallation('ten_customer_comms_installs', [
            'installation_id' => 'install_customer_comms_anonymous',
            'installation_secret' => 'secret_customer_comms_anonymous_123456',
            'platform' => 'ios',
            'fcm_token' => str_repeat('customer-comms-anonymous-token-', 8),
            'locale' => 'en-US',
        ]);
        $admin = $this->createTenantSession(
            'ten_customer_comms_installs',
            'par_customer_comms_installs',
            ['customer_notification.view', 'customer_notification.send'],
            'adm_comms_installs',
            'customer-comms-installs@example.test',
        );

        $created = $this->withToken($admin['access_token'])
            ->post('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'payload' => json_encode([
                    'name' => 'All app installations',
                    'audience_type' => 'all_installations',
                    'title' => ['th-TH' => 'ข่าวสำหรับทุกเครื่อง', 'en-US' => 'Every installation'],
                    'body' => ['th-TH' => 'เปิดแอปเพื่อดูรายละเอียด', 'en-US' => 'Open the app for details.'],
                    'action_key' => 'home',
                    'delivery_mode' => 'now',
                ], JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES),
            ], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms_installs',
                'Idempotency-Key' => 'customer-comms-all-installations',
            ])
            ->assertCreated()
            ->assertJsonPath('audience_type', 'all_installations')
            ->assertJsonPath('status', 'published')
            ->json();

        Queue::assertPushed(FanoutCustomerPushInstallationsJob::class, 1);
        $notificationId = (string) $created['notification_id'];
        $notifications->fanOutInstallationChunk($notificationId, 'all_installations');
        $this->assertDatabaseCount('customer_notification_recipients', 0);
        $this->assertDatabaseCount('customer_notification_deliveries', 2);
        $this->assertDatabaseHas('customer_notification_deliveries', [
            'notification_id' => $notificationId,
            'recipient_id' => null,
        ]);

        $sentMessages = [];
        $this->mock(FirebaseCloudMessagingClient::class, function (MockInterface $mock) use (&$sentMessages): void {
            $mock->shouldReceive('send')
                ->twice()
                ->with(\Mockery::on(function (array $message) use (&$sentMessages): bool {
                    $sentMessages[] = $message;
                    return true;
                }))
                ->andReturn(['ok' => true, 'message_id' => 'projects/test/messages/install-campaign']);
        });
        $this->app->forgetInstance(CustomerNotificationService::class);
        $deliveryIds = CustomerNotificationDelivery::query()->orderBy('id')->pluck('id');
        foreach ($deliveryIds as $deliveryId) {
            app(CustomerNotificationService::class)->processDelivery((string) $deliveryId);
        }

        $this->assertCount(2, $sentMessages);
        $this->assertSame(['', ''], array_column(array_column($sentMessages, 'data'), 'notification_id'));
        $this->assertSame(
            ['installation', 'installation'],
            array_column(array_column($sentMessages, 'data'), 'delivery_scope'),
        );

        $anonymousNotificationId = app(CustomerNotificationService::class)->createForInstallationAudience(
            'ten_customer_comms_installs',
            'anonymous_installations',
            'admin.communication_campaign',
            [
                'category' => 'admin',
                'title' => 'Anonymous only',
                'body' => 'Open the app to get started.',
                'action_key' => 'home',
            ],
            ['dedupe_key' => 'customer-comms-anonymous-only'],
        );
        app(CustomerNotificationService::class)->fanOutInstallationChunk(
            (string) $anonymousNotificationId,
            'anonymous_installations',
        );
        $this->assertSame(1, CustomerNotificationDelivery::query()
            ->where('notification_id', $anonymousNotificationId)
            ->count());
        $this->assertDatabaseHas('customer_notification_deliveries', [
            'notification_id' => $anonymousNotificationId,
            'device_id' => DB::table('customer_push_devices')
                ->whereNull('customer_id')
                ->value('id'),
        ]);

        $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/customer-notifications/campaigns', [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms_installs',
            ])
            ->assertOk()
            ->assertJsonPath('meta.active_installation_count', 2)
            ->assertJsonPath('meta.anonymous_installation_count', 1)
            ->assertJsonPath('data.0.stats.target_count', 2)
            ->assertJsonPath('data.0.stats.installation_count', 2)
            ->assertJsonPath('data.0.stats.recipient_count', 0);

        $detail = $this->withToken($admin['access_token'])
            ->getJson('/api/v1/admin/tenant/customer-notifications/campaigns/'.$created['id'], [
                'X-Admin-Scope' => 'tenant',
                'X-Tenant-Id' => 'ten_customer_comms_installs',
            ])
            ->assertOk()
            ->assertJsonPath('stats.target_count', 2)
            ->assertJsonPath('delivery_breakdown.statuses.0.status', 'sent')
            ->assertJsonPath('delivery_breakdown.statuses.0.count', 2)
            ->assertJsonPath('delivery_breakdown.platforms.0.platform', 'android')
            ->assertJsonPath('delivery_breakdown.platforms.0.sent_count', 1)
            ->assertJsonPath('delivery_breakdown.platforms.1.platform', 'ios')
            ->assertJsonPath('delivery_breakdown.platforms.1.sent_count', 1);
        $this->assertNotEmpty($detail->json('delivery_breakdown.last_activity_at'));
    }

    private function useBangkokClock(string $now): void
    {
        $originalTimezone = date_default_timezone_get();
        date_default_timezone_set('Asia/Bangkok');
        config([
            'app.timezone' => 'Asia/Bangkok',
            'database.connections.pgsql.timezone' => 'Asia/Bangkok',
        ]);
        DB::statement("SET TIME ZONE 'Asia/Bangkok'");
        Carbon::setTestNow(Carbon::parse($now));

        $this->beforeApplicationDestroyed(static function () use ($originalTimezone): void {
            Carbon::setTestNow();
            date_default_timezone_set($originalTimezone);
        });
    }

    private function scheduledPayload(string $scheduledAt, string $name): string
    {
        return json_encode([
            'name' => $name,
            'audience_type' => 'all_customers',
            'title' => ['th-TH' => 'ข่าวประชาสัมพันธ์'],
            'body' => ['th-TH' => 'รายละเอียดข่าวประชาสัมพันธ์'],
            'action_key' => 'home',
            'delivery_mode' => 'scheduled',
            'scheduled_at' => $scheduledAt,
        ], JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
    }
}
