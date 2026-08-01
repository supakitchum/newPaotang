<?php

namespace App\Modules\RewardRisk\Events;

use Illuminate\Broadcasting\InteractsWithSockets;
use Illuminate\Broadcasting\PrivateChannel;
use Illuminate\Contracts\Broadcasting\ShouldBroadcastNow;
use Illuminate\Foundation\Events\Dispatchable;
use Illuminate\Queue\SerializesModels;

class RewardRiskAssessmentUpdated implements ShouldBroadcastNow
{
    use Dispatchable;
    use InteractsWithSockets;
    use SerializesModels;

    public function __construct(
        public readonly string $tenantId,
        public readonly string $runId,
        public readonly string $gameId,
        public readonly string $phase,
        public readonly string $status,
        public readonly int $findingCount,
    ) {
    }

    public function broadcastOn(): array
    {
        return [
            new PrivateChannel('admin.tenant.'.$this->tenantId.'.reward-risk'),
            new PrivateChannel('admin.central.reward-risk'),
        ];
    }

    public function broadcastAs(): string
    {
        return 'reward.risk.updated';
    }

    public function broadcastWith(): array
    {
        return [
            'event_type' => 'reward.risk.updated',
            'tenant_id' => $this->tenantId,
            'run_id' => $this->runId,
            'game_id' => $this->gameId,
            'phase' => $this->phase,
            'status' => $this->status,
            'finding_count' => $this->findingCount,
            'updated_at' => now()->toISOString(),
        ];
    }
}
