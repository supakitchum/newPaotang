<?php

namespace App\Jobs;

use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class SendTelegramNotificationJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 1;

    public function __construct(public readonly string $deliveryId)
    {
        $this->onQueue('default');
    }

    public function handle(CentralTelegramNotificationService $notifications): void
    {
        $notifications->processDelivery($this->deliveryId);
    }
}
