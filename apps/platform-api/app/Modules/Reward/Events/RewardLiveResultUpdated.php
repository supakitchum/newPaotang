<?php

namespace App\Modules\Reward\Events;

use Illuminate\Broadcasting\Channel;
use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RewardLiveResultUpdated implements ShouldBroadcastNow
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
     * @return array<int, Channel>
     */
    public function broadcastOn(): array
    {
        $gameId = trim((string) ($this->payload['game_id'] ?? ''));
        $channels = [new Channel('public.results.latest')];

        if ($gameId !== '') {
            $channels[] = new Channel('public.results.game.'.$gameId);
        }

        return $channels;
    }

    public function broadcastAs(): string
    {
        return 'reward.result.live.updated';
    }

    /**
     * @return array<string, mixed>
     */
    public function broadcastWith(): array
    {
        return $this->payload;
    }
}
