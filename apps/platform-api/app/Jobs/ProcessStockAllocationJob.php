<?php

namespace App\Jobs;

use App\Modules\CentralStock\Services\CentralStockService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessStockAllocationJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $timeout = 900;
    public int $tries = 1;

    public function __construct(public readonly string $jobId)
    {
        $this->onQueue('stock-allocation');
    }

    public function handle(CentralStockService $centralStock): void
    {
        $centralStock->processAllocationJob($this->jobId);
    }
}
