<?php

namespace Tests\Feature;

use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Tests\Support\PartnerStoreFixtures;
use Tests\TestCase;

class IdempotencyServiceTest extends TestCase
{
    use PartnerStoreFixtures;
    use RefreshDatabase;

    public function test_IdempotencyService_replays_same_payload_and_conflicts_different_payload(): void
    {
        $this->insertActivePartnerTenantWithDomain('par_idem_m5', 'ten_idem_m5', 'idem.m5.test');
        $service = $this->app->make(IdempotencyService::class);

        $service->storeResponse(
            'ten_idem_m5',
            'customer',
            'cus_idem',
            'customer.checkout',
            'idem-key-main',
            ['reservation_id' => 'res_1', 'payment_method' => 'wallet'],
            201,
            ['id' => 'ord_1', 'status' => 'paid'],
        );

        $replay = $service->replayOrConflict(
            'ten_idem_m5',
            'customer',
            'cus_idem',
            'customer.checkout',
            'idem-key-main',
            ['payment_method' => 'wallet', 'reservation_id' => 'res_1'],
        );

        $this->assertSame(201, $replay['status']);
        $this->assertSame('ord_1', $replay['body']['id']);

        $conflict = $service->replayOrConflict(
            'ten_idem_m5',
            'customer',
            'cus_idem',
            'customer.checkout',
            'idem-key-main',
            ['reservation_id' => 'res_2', 'payment_method' => 'wallet'],
        );

        $this->assertSame('idempotency_conflict', $conflict);
    }
}
