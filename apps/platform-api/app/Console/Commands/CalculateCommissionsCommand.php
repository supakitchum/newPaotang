<?php

namespace App\Console\Commands;

use App\Modules\Growth\Services\GrowthService;
use Illuminate\Console\Command;

class CalculateCommissionsCommand extends Command
{
    protected $signature = 'commission:calculate {order_id?} {--tenant_id=} {--limit=100}';

    protected $description = 'Calculate affiliate commissions from paid orders.';

    public function handle(GrowthService $growth): int
    {
        $processed = $growth->calculateCommissions(
            $this->argument('order_id') === null ? null : (string) $this->argument('order_id'),
            $this->option('tenant_id') === null ? null : (string) $this->option('tenant_id'),
            (int) $this->option('limit'),
        );

        $this->info('Calculated commission transactions: '.$processed);

        return self::SUCCESS;
    }
}
