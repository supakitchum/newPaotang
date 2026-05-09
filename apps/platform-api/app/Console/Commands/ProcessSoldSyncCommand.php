<?php

namespace App\Console\Commands;

use App\Modules\Commerce\Services\CommerceService;
use Illuminate\Console\Command;

class ProcessSoldSyncCommand extends Command
{
    protected $signature = 'stock:sold:sync {--limit=100}';

    protected $description = 'Consume stock.sold.v1 events into Central Stock sold state.';

    public function handle(CommerceService $commerce): int
    {
        $processed = $commerce->processSoldSync((int) $this->option('limit'));

        $this->info('Processed sold events: '.$processed);

        return self::SUCCESS;
    }
}
