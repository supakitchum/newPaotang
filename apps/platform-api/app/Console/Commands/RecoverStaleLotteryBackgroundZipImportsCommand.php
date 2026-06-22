<?php

namespace App\Console\Commands;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use Illuminate\Console\Command;

class RecoverStaleLotteryBackgroundZipImportsCommand extends Command
{
    protected $signature = 'lottery-images:recover-stale-zip-imports {--limit=25}';

    protected $description = 'Recover stale lottery background zip import jobs that lost their worker heartbeat.';

    public function handle(LotteryImageOperationsService $operations): int
    {
        $count = $operations->recoverStaleBackgroundZipImports((int) $this->option('limit'));
        $this->info('Recovered stale background zip imports: '.$count);

        return self::SUCCESS;
    }
}
