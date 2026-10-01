<?php

namespace App\Jobs;

use App\Modules\PartnerStore\Services\VirtualStockService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessVirtualStockProfileGenerationJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $timeout = 300;

    public function __construct(public readonly string $batchId)
    {
        $this->onQueue((string) config('platform.stock_generation.queue', 'stock-generation'));
    }

    public function handle(VirtualStockService $virtualStock): void
    {
        $virtualStock->processQueuedProfileGeneration($this->batchId);
    }
}
