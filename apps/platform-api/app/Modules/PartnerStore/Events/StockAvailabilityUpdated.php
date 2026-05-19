<?php

namespace App\Modules\PartnerStore\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class StockAvailabilityUpdated implements ShouldBroadcastNow
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    /**
     * @param array<string, mixed> $payload
     */
    public function __construct(public readonly array $payload)
    {
    }

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        $channels = [];
        $tenantId = trim((string) ($this->payload['tenant_id'] ?? ''));
        $gameId = trim((string) ($this->payload['game_id'] ?? ''));
        $customerId = trim((string) ($this->payload['customer_id'] ?? ''));

        if ($tenantId !== '' && $gameId !== '') {
            $channels[] = new PrivateChannel('customer.tenant.'.$tenantId.'.stock.game.'.$gameId);
        }

        if ($tenantId !== '' && $customerId !== '') {
            $channels[] = new PrivateChannel('customer.tenant.'.$tenantId.'.customer.'.$customerId.'.cart');
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'stock.availability.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
