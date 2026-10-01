<?php

namespace App\Modules\CentralStock\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class StockAllocationJobUpdated implements ShouldBroadcastNow
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
        $channels = [new PrivateChannel('admin.central.stock-allocation-jobs')];

        $jobId = trim((string) ($this->payload['id'] ?? ''));
        if ($jobId !== '') {
            $channels[] = new PrivateChannel('admin.central.stock-allocation-jobs.'.$jobId);
        }

        $gameId = trim((string) ($this->payload['game_id'] ?? ''));
        if ($gameId !== '') {
            $channels[] = new PrivateChannel('admin.central.stock-allocation-jobs.game.'.$gameId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'stock.allocation_job.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
