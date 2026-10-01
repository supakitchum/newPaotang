<?php

namespace App\Modules\Pricing\Events;

use Illuminate\Broadcasting\Channel;
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

    /**
     * @return array<int, Channel|PrivateChannel>
     */
    public function broadcastOn(): array
    {
        $tenantId = trim((string) ($this->payload['tenant_id'] ?? ''));
        $gameId = trim((string) ($this->payload['game_id'] ?? ''));

        if ($tenantId === '' || $gameId === '') {
            return [];
        }

        $channel = 'customer.tenant.'.$tenantId.'.stock.game.'.$gameId;
        $tenantSalePriceChannel = 'customer.tenant.'.$tenantId.'.sale-price';

        return [
            new PrivateChannel($channel),
            new Channel($channel),
            new Channel($tenantSalePriceChannel),
        ];
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
