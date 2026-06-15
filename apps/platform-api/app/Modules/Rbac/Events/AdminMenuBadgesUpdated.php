<?php

namespace App\Modules\Rbac\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class AdminMenuBadgesUpdated implements ShouldBroadcastNow
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(
        public readonly string $scopeType,
        public readonly ?string $tenantId = null,
        public readonly string $source = 'admin_menu',
    ) {
    }

    /**
     * @return array<int, PrivateChannel>
     */
    public function broadcastOn(): array
    {
        if ($this->scopeType === 'central') {
            return [new PrivateChannel('admin.central.menu')];
        }

        $tenantId = trim((string) $this->tenantId);

        return $tenantId === ''
            ? []
            : [new PrivateChannel('admin.tenant.'.$tenantId.'.menu')];
    }

    public function broadcastAs(): string
    {
        return 'admin.menu.badges.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return [
            'event_type' => 'admin.menu.badges.updated',
            'scope_type' => $this->scopeType,
            'tenant_id' => $this->tenantId,
            'source' => $this->source,
            'updated_at' => now()->toISOString(),
        ];
    }
}
