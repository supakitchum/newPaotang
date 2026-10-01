<?php

namespace App\Jobs;

use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class FanoutRewardResultCustomerNotificationsJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 4;

    /** @var array<int, int> */
    public array $backoff = [15, 60, 300, 900];

    public function __construct(
        public readonly string $rewardResultId,
        public readonly ?string $afterTenantId = null,
        public readonly ?string $afterCustomerId = null,
    ) {
        $this->onQueue('notification');
    }

    public function handle(CustomerNotificationDomainEventService $notifications): void
    {
        $notifications->fanOutRewardResultChunk(
            $this->rewardResultId,
            $this->afterTenantId,
            $this->afterCustomerId,
        );
    }
}
