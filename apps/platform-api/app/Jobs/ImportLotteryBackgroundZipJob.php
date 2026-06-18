<?php

namespace App\Jobs;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ImportLotteryBackgroundZipJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $timeout = 300;
    public int $tries = 1;

    public function __construct(public readonly string $importId)
    {
        $this->onQueue((string) config('lottery_images.queues.central', 'stock-image-generation'));
    }

    public function handle(LotteryImageOperationsService $operations): void
    {
        $operations->processBackgroundZipImportJob($this->importId);
    }
}
