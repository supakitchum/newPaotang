<?php

namespace App\Modules\Commerce\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CustomerTicketsUpdated implements ShouldBroadcastNow
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
        $tenantId = trim((string) ($this->payload['tenant_id'] ?? ''));
        $customerId = trim((string) ($this->payload['customer_id'] ?? ''));

        return $tenantId === '' || $customerId === ''
            ? []
            : [new PrivateChannel('customer.tenant.'.$tenantId.'.customer.'.$customerId.'.tickets')];
    }

    public function broadcastAs(): string
    {
        return 'tickets.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
