<?php

namespace App\Jobs;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Contracts\Queue\ShouldBeUnique;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class FanoutCustomerNotificationRecipientsJob implements ShouldBeUnique, ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 4;

    public int $uniqueFor = 300;

    /** @var array<int, int> */
    public array $backoff = [15, 60, 300, 900];

    public function __construct(
        public readonly string $notificationId,
        public readonly ?string $afterCustomerId = null,
    ) {
        $this->onQueue('notification');
    }

    public function handle(CustomerNotificationService $notifications): void
    {
        $notifications->fanOutTenantChunk($this->notificationId, $this->afterCustomerId);
    }

    public function uniqueId(): string
    {
        return $this->notificationId.':'.($this->afterCustomerId ?? 'start');
    }
}
