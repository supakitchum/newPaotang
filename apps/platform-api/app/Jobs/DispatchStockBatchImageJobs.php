<?php

namespace App\Jobs;

use App\Modules\CentralStock\Services\CentralStockService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class DispatchStockBatchImageJobs implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function __construct(
        public readonly string $batchId,
        public readonly ?string $afterStockItemId = null,
        public readonly ?int $chunkSize = null,
    ) {
        $this->onQueue((string) config('platform.stock_generation.queue', 'stock-generation'));
    }

    public function handle(CentralStockService $centralStock): void
    {
        $centralStock->dispatchCompletedBatchImageJobs($this->batchId, $this->afterStockItemId, $this->chunkSize);
    }
}
