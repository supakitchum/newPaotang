<?php

namespace App\Modules\Pricing\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class SalePriceUpdated implements ShouldBroadcastNow
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

    public function broadcastOn(): PrivateChannel
    {
        return new PrivateChannel(
            'customer.tenant.'
            .trim((string) ($this->payload['tenant_id'] ?? ''))
            .'.stock.game.'
            .trim((string) ($this->payload['game_id'] ?? '')),
        );
    }

    public function broadcastAs(): string
    {
        return 'stock.price.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
