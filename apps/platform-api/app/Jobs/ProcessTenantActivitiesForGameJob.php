<?php

namespace App\Jobs;

use App\Modules\Activities\Services\TenantActivityService;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class ProcessTenantActivitiesForGameJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;

    /**
     * @var array<int, int>
     */
    public array $backoff = [60, 300, 900];

    public function __construct(
        public readonly string $gameId,
        public readonly string $mode = 'all',
    ) {
        $this->onQueue('default');
    }

    public function handle(TenantActivityService $activities): void
    {
        $activities->processGame($this->gameId, $this->mode);
    }
}
