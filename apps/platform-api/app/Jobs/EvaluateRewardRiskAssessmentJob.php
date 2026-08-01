<?php

namespace App\Jobs;

use App\Modules\RewardRisk\Services\RewardRiskAssessmentService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\Middleware\WithoutOverlapping;
use Illuminate\Queue\SerializesModels;

class EvaluateRewardRiskAssessmentJob implements ShouldQueue, ShouldBeUnique
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 4;
    public int $timeout = 600;
    public int $uniqueFor = 900;
    public array $backoff = [15, 60, 300, 900];

    public function __construct(
        public readonly string $tenantId,
        public readonly string $rewardResultId,
        public readonly string $phase,
        public readonly string $sourceHash,
    ) {
        $this->onQueue('reward-risk');
    }

    public function uniqueId(): string
    {
        return implode(':', [$this->tenantId, $this->rewardResultId, $this->phase, $this->sourceHash]);
    }

    public function middleware(): array
    {
        return [
            (new WithoutOverlapping(implode(':', ['reward-risk', $this->tenantId, $this->rewardResultId, $this->phase])))
                ->shared()
                ->releaseAfter(15)
                ->expireAfter(1800),
        ];
    }

    public function handle(RewardRiskAssessmentService $service): void
    {
        $service->evaluateTenant($this->tenantId, $this->rewardResultId, $this->phase, $this->sourceHash);
    }
}
