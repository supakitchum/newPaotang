<?php

namespace App\Jobs;

use App\Modules\RewardRisk\Services\RewardRiskAssessmentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class FanoutRewardRiskAssessmentJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;
    public array $backoff = [15, 60, 300];

    public function __construct(
        public readonly string $rewardResultId,
        public readonly string $phase,
        public readonly string $sourceHash,
    ) {
        $this->onQueue('reward-risk');
    }

    public function handle(RewardRiskAssessmentService $service): void
    {
        $service->dispatchEnabledTenants($this->rewardResultId, $this->phase, $this->sourceHash);
    }
}
