<?php

namespace App\Console\Commands;

use App\Modules\Commerce\Services\CommerceService;
use Illuminate\Console\Command;

class PruneTopupSlipsCommand extends Command
{
    protected $signature = 'topups:slips:prune {--limit=100 : Maximum expired slip assets to prune in one run}';

    protected $description = 'Delete expired topup slip images after their retention window.';

    public function handle(CommerceService $commerce): int
    {
        $count = $commerce->pruneExpiredTopupSlips((int) $this->option('limit'));

        $this->line('Pruned topup slips: '.$count);

        return self::SUCCESS;
    }
}
