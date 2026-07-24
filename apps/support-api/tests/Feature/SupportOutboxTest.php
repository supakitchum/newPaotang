<?php

namespace Tests\Feature;

use App\Jobs\DeliverSupportOutbox;
use App\Models\SupportOutbox;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;
use Tests\TestCase;

class SupportOutboxTest extends TestCase
{
    use RefreshDatabase;

    public function test_repeated_platform_server_errors_open_the_delivery_circuit(): void
    {
        $customer = $this->supportToken('customer', 'customer-outbox-circuit');
        $this->withHeaders($this->supportHeaders($customer))
            ->getJson('/v1/customer/bootstrap')
            ->assertOk();
        config([
            'support.platform_notifications.url' => 'https://platform.test/internal/customer-support/notifications',
            'support.platform_notifications.secret' => 'test-secret',
            'support.platform_notifications.circuit_breaker_seconds' => 60,
        ]);
        Cache::forget('support-platform-notification-circuit-open');
        Http::fake([
            '*' => Http::response(['error' => ['code' => 'unavailable']], 503),
        ]);
        $event = SupportOutbox::query()->create([
            'id' => 'sob_circuit_first',
            'tenant_id' => 'tenant_test_one',
            'event_key' => 'support.message.created',
            'aggregate_type' => 'support_ticket',
            'aggregate_id' => 'stk_circuit',
            'dedupe_key' => hash('sha256', 'circuit-first'),
            'payload_json' => [
                'tenant_id' => 'tenant_test_one',
                'customer_id' => 'customer-outbox-circuit',
                'ticket_id' => 'stk_circuit',
                'ticket_no' => 'SUP-CIRCUIT',
                'event_key' => 'support.message.created',
                'title' => ['th-TH' => 'ทดสอบ'],
                'body' => ['th-TH' => 'ทดสอบ'],
            ],
            'status' => 'pending',
            'attempts' => 3,
            'available_at' => now()->subSecond(),
        ]);

        (new DeliverSupportOutbox)->handle();

        $this->assertSame(4, (int) $event->fresh()->attempts);
        $this->assertTrue(Cache::get('support-platform-notification-circuit-open'));
        SupportOutbox::query()->create([
            'id' => 'sob_circuit_second',
            'tenant_id' => 'tenant_test_one',
            'event_key' => 'support.ticket.closed',
            'aggregate_type' => 'support_ticket',
            'aggregate_id' => 'stk_circuit_second',
            'dedupe_key' => hash('sha256', 'circuit-second'),
            'payload_json' => [
                'tenant_id' => 'tenant_test_one',
                'customer_id' => 'customer-outbox-circuit',
                'ticket_id' => 'stk_circuit_second',
                'ticket_no' => 'SUP-CIRCUIT-2',
                'event_key' => 'support.ticket.closed',
                'title' => ['th-TH' => 'ทดสอบ'],
                'body' => ['th-TH' => 'ทดสอบ'],
            ],
            'status' => 'pending',
            'attempts' => 0,
            'available_at' => now()->subSecond(),
        ]);

        (new DeliverSupportOutbox)->handle();

        Http::assertSentCount(1);
        $this->assertDatabaseHas('support_outbox', [
            'id' => 'sob_circuit_second',
            'attempts' => 0,
            'status' => 'pending',
        ]);
    }
}
