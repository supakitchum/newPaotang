<?php

namespace App\Modules\CentralStock\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Support\Facades\DB;
use Illuminate\Queue\SerializesModels;

class StockCoverageUpdated implements ShouldBroadcastNow
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
        $gameId = trim((string) ($this->payload['game_id'] ?? ''));

        if ($gameId === '') {
            return [];
        }

        $channels = [new PrivateChannel('admin.central.stock.coverage.game.'.$gameId)];

        foreach ($this->tenantChannelIds($gameId) as $tenantId) {
            $channels[] = new PrivateChannel('admin.tenant.'.$tenantId.'.stock.coverage.game.'.$gameId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'stock.coverage.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }

    /**
     * @return array<int, string>
     */
    private function tenantChannelIds(string $gameId): array
    {
        $tenantId = trim((string) ($this->payload['tenant_id'] ?? ''));

        if ($tenantId !== '') {
            return [$tenantId];
        }

        $scopeType = trim((string) ($this->payload['scope_type'] ?? ''));
        $scopeId = trim((string) ($this->payload['scope_id'] ?? ''));

        if ($scopeType === 'partner' && $scopeId !== '') {
            return DB::table('partner_tenants')
                ->where('partner_id', $scopeId)
                ->where('status', 'active')
                ->orderBy('id')
                ->pluck('id')
                ->map(fn (mixed $id): string => (string) $id)
                ->all();
        }

        if (($this->payload['refresh_required'] ?? false) === true) {
            return DB::table('partner_stock_allocations')
                ->where('game_id', $gameId)
                ->whereIn('status', ['pending', 'processing', 'allocated', 'partially_allocated'])
                ->whereNotNull('tenant_id')
                ->distinct()
                ->orderBy('tenant_id')
                ->pluck('tenant_id')
                ->map(fn (mixed $id): string => (string) $id)
                ->all();
        }

        return [];
    }
}
