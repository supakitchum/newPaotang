<?php

namespace App\Modules\Auth\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class CustomerSessionReplaced implements ShouldBroadcastNow
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(
        public readonly string $tenantId,
        public readonly string $customerId,
        public readonly string $replacementSessionId,
        public readonly string $replacedAt,
    ) {
    }

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        return [
            new PrivateChannel(
                'customer.tenant.'.$this->tenantId.'.customer.'.$this->customerId.'.notifications',
            ),
        ];
    }

    public function broadcastAs(): string
    {
        return 'customer.auth.session-replaced';
    }

    /**
     * @return array<string, string>
     */
    public function broadcastWith(): array
    {
        return [
            'tenant_id' => $this->tenantId,
            'customer_id' => $this->customerId,
            'replacement_session_id' => $this->replacementSessionId,
            'replaced_at' => $this->replacedAt,
        ];
    }
}
