<?php

namespace App\Jobs;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendCustomerPushNotificationJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 4;

    /** @var array<int, int> */
    public array $backoff = [30, 120, 600, 1800];

    public function __construct(public readonly string $deliveryId)
    {
        $this->onQueue('notification');
    }

    public function handle(CustomerNotificationService $notifications): void
    {
        $notifications->processDelivery($this->deliveryId);
    }
}
