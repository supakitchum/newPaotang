<?php

namespace App\Modules\CentralStock\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class StockGenerationProgressUpdated implements ShouldBroadcastNow
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
        $channels = [
            new PrivateChannel('admin.central.stock-generation'),
        ];

        $gameId = trim((string) ($this->payload['game_id'] ?? ''));
        if ($gameId !== '') {
            $channels[] = new PrivateChannel('admin.central.stock-generation.game.'.$gameId);
        }

        $batchId = trim((string) ($this->payload['batch_id'] ?? ''));
        if ($batchId !== '') {
            $channels[] = new PrivateChannel('admin.central.stock-generation.batch.'.$batchId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'stock.generation.progress.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
