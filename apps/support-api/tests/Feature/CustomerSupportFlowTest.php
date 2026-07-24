<?php

namespace Tests\Feature;

use App\Auth\SupportActorContext;
use App\Models\SupportActor;
use App\Models\SupportCategory;
use App\Models\SupportFaq;
use App\Models\SupportOutbox;
use App\Models\SupportTicket;
use App\Services\SupportIdempotencyService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\UploadedFile;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Storage;
use Tests\TestCase;

class CustomerSupportFlowTest extends TestCase
{
    use RefreshDatabase;

    public function test_runtime_cors_allows_configured_customer_origin(): void
    {
        config()->set('cors.allowed_origins', ['https://customer.example.test']);

        $this->withHeaders([
            'Origin' => 'https://customer.example.test',
            'Access-Control-Request-Method' => 'GET',
            'Access-Control-Request-Headers' => 'authorization',
        ])->options('/v1/customer/bootstrap')
            ->assertNoContent()
            ->assertHeader(
                'Access-Control-Allow-Origin',
                'https://customer.example.test',
            );
    }

    public function test_runtime_cors_allows_tenant_origin_matching_runtime_pattern(): void
    {
        config()->set('cors.allowed_origins', []);
        config()->set('cors.allowed_origins_patterns', [
            '~^https?://([a-z0-9-]+\.)*localhost(:[0-9]+)?$~',
        ]);

        $this->withHeaders([
            'Origin' => 'http://xn--42cl1cp5p.localhost',
            'Access-Control-Request-Method' => 'POST',
            'Access-Control-Request-Headers' => 'authorization,idempotency-key',
        ])->options('/v1/customer/tickets')
            ->assertNoContent()
            ->assertHeader(
                'Access-Control-Allow-Origin',
                'http://xn--42cl1cp5p.localhost',
            );
    }

    public function test_concurrent_idempotency_begin_returns_in_progress_then_replays_completed_response(): void
    {
        $customer = $this->supportToken('customer', 'customer-idempotency-race');
        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk();
        $actor = SupportActor::query()
            ->where('external_id', 'customer-idempotency-race')
            ->firstOrFail();
        $context = new SupportActorContext($actor, [
            'tenant_id' => 'tenant_test_one',
            'actor_type' => 'customer',
        ]);
        $idempotency = app(SupportIdempotencyService::class);
        $payload = ['ticket_id' => 'stk_race', 'sequence' => 4];

        $this->assertNull($idempotency->begin(
            $context,
            'customer.ticket.read',
            'idempotency-race',
            $payload,
        ));
        try {
            $idempotency->begin(
                $context,
                'customer.ticket.read',
                'idempotency-race',
                $payload,
            );
            $this->fail('An unfinished concurrent request must not execute twice.');
        } catch (\RuntimeException $exception) {
            $this->assertSame('idempotency_in_progress', $exception->getMessage());
        }

        $idempotency->finish(
            $context,
            'customer.ticket.read',
            'idempotency-race',
            200,
            ['last_read_sequence' => 4],
        );
        $this->assertSame(
            [
                'status' => 200,
                'body' => ['last_read_sequence' => 4],
            ],
            $idempotency->begin(
                $context,
                'customer.ticket.read',
                'idempotency-race',
                $payload,
            ),
        );
    }

    public function test_attachment_is_normalized_private_and_downloaded_only_by_signed_url(): void
    {
        Storage::fake('local');
        $customer = $this->supportToken('customer', 'customer-attachment');
        $file = UploadedFile::fake()->image('evidence.png', 320, 240);

        $ticketId = $this->withHeaders($this->supportHeaders($customer, 'attachment-ticket'))
            ->post('/v1/customer/tickets', [
                'subject' => 'แนบหลักฐาน',
                'message' => 'กรุณาตรวจสอบรูป',
                'attachments' => [$file],
            ])
            ->assertCreated()
            ->json('ticket.id');

        $attachment = DB::table('support_attachments')->first();
        $this->assertNotNull($attachment);
        $this->assertSame('image/webp', $attachment->mime_type);
        $this->assertSame(320, $attachment->width);
        $this->assertSame(240, $attachment->height);
        $this->assertSame(64, strlen((string) $attachment->checksum_sha256));
        Storage::disk('local')->assertExists((string) $attachment->storage_path);

        $url = $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/tickets/'.$ticketId.'/messages')
            ->assertOk()
            ->json('data.0.attachments.0.url');
        $this->get((string) $url)
            ->assertOk()
            ->assertHeader('content-type', 'image/webp');
        $this->get('/v1/attachments/'.$attachment->id)->assertForbidden();
    }

    public function test_customer_attachment_validation_uses_tenant_runtime_limits(): void
    {
        $customer = $this->supportToken('customer', 'customer-attachment-limit');
        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk();
        DB::table('support_settings')
            ->where('tenant_id', 'tenant_test_one')
            ->update([
                'max_attachments_per_message' => 1,
                'max_attachment_bytes' => 1024,
            ]);

        $this->withHeaders($this->supportHeaders($customer, 'attachment-too-large'))
            ->post('/v1/customer/tickets', [
                'subject' => 'รูปใหญ่เกินกำหนด',
                'message' => 'ไม่ควรสร้าง Ticket',
                'attachments' => [
                    UploadedFile::fake()->image('large.png')->size(2),
                ],
            ])
            ->assertUnprocessable()
            ->assertJsonValidationErrors(['attachments.0']);

        $this->assertDatabaseCount('support_tickets', 0);
    }

    public function test_customer_is_blocked_by_runtime_setting_but_admin_can_reenable_support(): void
    {
        $customer = $this->supportToken('customer', 'customer-disabled-support');
        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk();
        DB::table('support_settings')
            ->where('tenant_id', 'tenant_test_one')
            ->update(['enabled' => false]);

        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/bootstrap')
            ->assertStatus(503)
            ->assertJsonPath('error.code', 'support_unavailable');

        $master = $this->supportToken('admin', 'support-settings-master', permissions: [
            'support_agent.manage',
        ]);
        $this->withHeaders($this->supportHeaders($master))
            ->getJson('/v1/admin/settings')
            ->assertOk()
            ->assertJsonPath('settings.enabled', false);
        $this->withHeaders($this->supportHeaders($master, 'support-reenable'))
            ->putJson('/v1/admin/settings', [
                'enabled' => true,
                'default_agent_capacity' => 3,
                'max_attachments_per_message' => 4,
                'max_attachment_bytes' => 8388608,
            ])
            ->assertOk()
            ->assertJsonPath('settings.enabled', true);

        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk()
            ->assertJsonPath('enabled', true);
    }

    public function test_bootstrap_provisions_other_category_without_overwriting_admin_changes(): void
    {
        $token = $this->supportToken('customer', 'customer-category');

        $this->withHeaders($this->supportHeaders($token))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk()
            ->assertJsonPath('categories.0.code', 'other')
            ->assertJsonPath('categories.0.name', 'อื่นๆ');

        $category = SupportCategory::query()
            ->where('tenant_id', 'tenant_test_one')
            ->where('code', 'other')
            ->firstOrFail();
        $category->update([
            'name_json' => ['th-TH' => 'เรื่องอื่น', 'en-US' => 'Something else'],
            'sort_order' => 5,
        ]);

        $this->withHeaders($this->supportHeaders($token))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk()
            ->assertJsonPath('categories.0.name', 'เรื่องอื่น');

        $this->assertDatabaseCount('support_categories', 1);
        $this->assertSame(5, $category->fresh()->sort_order);
    }

    public function test_customer_can_submit_idempotent_faq_feedback(): void
    {
        $token = $this->supportToken('customer', 'customer-feedback');
        $this->withHeaders($this->supportHeaders($token))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk();
        SupportCategory::query()->create([
            'id' => 'scat_feedback',
            'tenant_id' => 'tenant_test_one',
            'code' => 'general',
            'name_json' => ['th-TH' => 'ทั่วไป', 'en-US' => 'General'],
            'status' => 'active',
        ]);
        SupportFaq::query()->create([
            'id' => 'sfaq_feedback',
            'tenant_id' => 'tenant_test_one',
            'category_id' => 'scat_feedback',
            'question_json' => ['th-TH' => 'ต้องทำอย่างไร'],
            'answer_json' => ['th-TH' => 'ทำตามขั้นตอน'],
            'status' => 'published',
            'published_at' => now(),
        ]);

        $headers = $this->supportHeaders($token, 'faq-feedback-1');
        $this->withHeaders($headers)
            ->postJson('/v1/customer/faqs/sfaq_feedback/feedback', ['helpful' => true])
            ->assertOk()
            ->assertJsonPath('helpful', true);
        $this->withHeaders($headers)
            ->postJson('/v1/customer/faqs/sfaq_feedback/feedback', ['helpful' => true])
            ->assertOk()
            ->assertJsonPath('faq_id', 'sfaq_feedback');

        $this->assertDatabaseCount('support_faq_feedback', 1);
    }

    public function test_customer_can_open_only_one_ticket_and_idempotent_retry_replays_it(): void
    {
        $token = $this->supportToken('customer', 'customer-one');
        $payload = [
            'subject' => 'ชำระเงินไม่สำเร็จ',
            'message' => 'กดยืนยันแล้วระบบไม่ไปหน้าถัดไป',
        ];

        $first = $this->withHeaders($this->supportHeaders($token, 'ticket-create-1'))
            ->postJson('/v1/customer/tickets', $payload)
            ->assertCreated()
            ->assertJsonPath('ticket.subject', $payload['subject'])
            ->assertJsonPath('ticket.queue_position', 1)
            ->assertJsonPath('existing', false);

        $ticketId = $first->json('ticket.id');
        $this->withHeaders($this->supportHeaders($token, 'ticket-create-1'))
            ->postJson('/v1/customer/tickets', $payload)
            ->assertCreated()
            ->assertJsonPath('ticket.id', $ticketId)
            ->assertJsonPath('existing', false);

        $this->withHeaders($this->supportHeaders($token, 'ticket-create-2'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'หัวข้อใหม่',
                'message' => 'รายละเอียดใหม่',
            ])
            ->assertCreated()
            ->assertJsonPath('ticket.id', $ticketId)
            ->assertJsonPath('existing', true);

        $this->assertDatabaseCount('support_tickets', 1);
        $this->assertDatabaseCount('support_messages', 2);
        $this->assertDatabaseHas('support_messages', [
            'ticket_id' => $ticketId,
            'sequence' => 2,
            'sender_type' => 'system',
            'message_type' => 'system',
            'body' => 'ยินดีต้อนรับสู่ศูนย์ช่วยเหลือ เราได้รับเรื่องของคุณแล้ว ขณะนี้คุณอยู่ในคิวลำดับที่ 1 คุณสามารถส่งรายละเอียดเพิ่มเติมระหว่างรอเจ้าหน้าที่ได้',
        ]);
    }

    public function test_ticket_welcome_message_uses_tenant_runtime_content(): void
    {
        $token = $this->supportToken('customer', 'customer-runtime-welcome');
        $this->withHeaders($this->supportHeaders($token))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk();
        DB::table('support_settings')
            ->where('tenant_id', 'tenant_test_one')
            ->update([
                'content_json' => json_encode([
                    'messages' => [
                        'ticket_created' => [
                            'th-TH' => 'รับเรื่องแล้ว ลำดับคิวของคุณคือ {queue_position}',
                        ],
                    ],
                ], JSON_UNESCAPED_UNICODE),
            ]);

        $ticketId = $this->withHeaders($this->supportHeaders($token, 'runtime-welcome-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'ตรวจข้อความต้อนรับ',
                'message' => 'ใช้ข้อความของ tenant',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $this->assertDatabaseHas('support_messages', [
            'ticket_id' => $ticketId,
            'sender_type' => 'system',
            'body' => 'รับเรื่องแล้ว ลำดับคิวของคุณคือ 1',
        ]);
    }

    public function test_idempotency_key_rejects_a_different_payload(): void
    {
        $token = $this->supportToken('customer', 'customer-one');
        $headers = $this->supportHeaders($token, 'ticket-conflict');

        $this->withHeaders($headers)->postJson('/v1/customer/tickets', [
            'subject' => 'หัวข้อแรก',
            'message' => 'รายละเอียดแรก',
        ])->assertCreated();

        $this->withHeaders($headers)->postJson('/v1/customer/tickets', [
            'subject' => 'หัวข้อที่เปลี่ยน',
            'message' => 'รายละเอียดแรก',
        ])->assertConflict()->assertJsonPath('error.code', 'idempotency_conflict');
    }

    public function test_customer_cannot_read_a_ticket_from_another_tenant(): void
    {
        $owner = $this->supportToken('customer', 'customer-one', 'tenant_one');
        $ticketId = $this->withHeaders($this->supportHeaders($owner, 'tenant-one-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'Tenant one ticket',
                'message' => 'Private tenant data',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $otherTenant = $this->supportToken('customer', 'customer-one', 'tenant_two');
        $this->withHeaders($this->supportHeaders($otherTenant))
            ->getJson('/v1/customer/tickets/'.$ticketId)
            ->assertNotFound();
    }

    public function test_stale_mark_read_request_cannot_reduce_read_progress(): void
    {
        $token = $this->supportToken('customer', 'customer-read-progress');
        $ticketId = $this->withHeaders($this->supportHeaders($token, 'read-progress-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'ตรวจสถานะอ่านข้อความ',
                'message' => 'ข้อความแรก',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $this->withHeaders($this->supportHeaders($token, 'read-progress-new'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/read', ['sequence' => 1])
            ->assertOk()
            ->assertJsonPath('last_read_sequence', 1);

        $this->withHeaders($this->supportHeaders($token, 'read-progress-stale'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/read', ['sequence' => 0])
            ->assertOk()
            ->assertJsonPath('last_read_sequence', 1);

        $this->assertDatabaseHas('support_read_receipts', [
            'ticket_id' => $ticketId,
            'last_read_sequence' => 1,
        ]);
    }

    public function test_unread_count_excludes_customer_messages(): void
    {
        $customer = $this->supportToken('customer', 'customer-unread');
        $ticketId = $this->withHeaders($this->supportHeaders($customer, 'unread-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'ตรวจ unread',
                'message' => 'ข้อความของลูกค้า',
            ])
            ->assertCreated()
            ->assertJsonPath('ticket.unread_count', 1)
            ->json('ticket.id');

        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/unread-count')
            ->assertOk()
            ->assertJsonPath('unread_count', 1);

        $this->withHeaders($this->supportHeaders($customer, 'read-welcome-message'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/read', ['sequence' => 2])
            ->assertOk()
            ->assertJsonPath('unread_count', 0);

        $agent = $this->supportToken('admin', 'support-unread', permissions: [
            'support_ticket.view_all',
            'support_ticket.reply_assigned',
        ]);
        $this->withHeaders($this->supportHeaders($agent, 'unread-agent-message'))
            ->postJson('/v1/admin/tickets/'.$ticketId.'/messages', [
                'body' => 'ข้อความจากเจ้าหน้าที่',
            ])
            ->assertCreated();

        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/unread-count')
            ->assertOk()
            ->assertJsonPath('unread_count', 1);
    }

    public function test_closed_ticket_is_read_only_and_can_be_rated_once(): void
    {
        $token = $this->supportToken('customer', 'customer-one');
        $ticketId = $this->withHeaders($this->supportHeaders($token, 'close-flow-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'ต้องการปิดรายการ',
                'message' => 'ปัญหาได้รับการแก้ไขแล้ว',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $this->withHeaders($this->supportHeaders($token, 'close-flow-close'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/close', [])
            ->assertOk()
            ->assertJsonPath('ticket.status', 'closed');

        $this->withHeaders($this->supportHeaders($token, 'closed-message'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/messages', ['body' => 'ส่งเพิ่ม'])
            ->assertConflict()
            ->assertJsonPath('error.code', 'ticket_closed');

        $this->withHeaders($this->supportHeaders($token, 'close-flow-rating'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/rating', [
                'stars' => 5,
                'comment' => 'ช่วยเหลือได้ดี',
            ])
            ->assertCreated()
            ->assertJsonPath('rating.stars', 5);

        $this->withHeaders($this->supportHeaders($token, 'close-flow-rating-2'))
            ->postJson('/v1/customer/tickets/'.$ticketId.'/rating', [
                'stars' => 1,
                'comment' => 'แก้คะแนน',
            ])
            ->assertCreated()
            ->assertJsonPath('rating.stars', 5);

        $this->assertDatabaseCount('support_ratings', 1);
        $this->assertNull(SupportTicket::query()->findOrFail($ticketId)->active_slot);
        $this->assertDatabaseHas('support_audit_logs', [
            'action' => 'customer.ticket.close',
            'subject_id' => $ticketId,
        ]);
        $this->assertDatabaseHas('support_audit_logs', [
            'action' => 'customer.ticket.rate',
            'subject_id' => $ticketId,
        ]);
    }

    public function test_notification_outbox_uses_localized_defaults_for_dotted_event_key(): void
    {
        $customer = $this->supportToken('customer', 'customer-notification-default');
        $ticketId = $this->withHeaders($this->supportHeaders($customer, 'notification-ticket'))
            ->postJson('/v1/customer/tickets', [
                'subject' => 'ต้องการความช่วยเหลือ',
                'message' => 'ข้อความแรก',
            ])
            ->assertCreated()
            ->json('ticket.id');

        $agent = $this->supportToken('admin', 'support-notification-default', permissions: [
            'support_ticket.view_all',
            'support_ticket.reply_assigned',
        ]);
        $this->withHeaders($this->supportHeaders($agent, 'notification-message'))
            ->postJson('/v1/admin/tickets/'.$ticketId.'/messages', [
                'body' => 'กำลังตรวจสอบให้ครับ',
            ])
            ->assertCreated();

        $outbox = SupportOutbox::query()
            ->where('event_key', 'support.message.created')
            ->firstOrFail();
        $this->assertSame(
            'ข้อความใหม่จากศูนย์ช่วยเหลือ',
            data_get($outbox->payload_json, 'title.th-TH'),
        );
        $this->assertSame(
            'กำลังตรวจสอบให้ครับ',
            data_get($outbox->payload_json, 'body.th-TH'),
        );
    }
}
