<?php

namespace App\Modules\CustomerNotifications\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CustomerNotificationChanged implements ShouldBroadcastNow
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    /**
     * @param array<string, mixed> $payload
     */
    public function __construct(
        public readonly string $eventName,
        public readonly array $payload,
    ) {
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
            : [new PrivateChannel('customer.tenant.'.$tenantId.'.customer.'.$customerId.'.notifications')];
    }

    public function broadcastAs(): string
    {
        return in_array($this->eventName, ['customer.notification.created', 'customer.notification.read'], true)
            ? $this->eventName
            : 'customer.notification.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
