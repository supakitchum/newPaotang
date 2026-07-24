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
        $result = $growth->calculateCommissionsBatch(
            $this->argument('order_id') === null ? null : (string) $this->argument('order_id'),
            $this->option('tenant_id') === null ? null : (string) $this->option('tenant_id'),
            (int) $this->option('limit'),
        );

        $this->info('Calculated commission transactions: '.$result['created']);
        $this->line(sprintf(
            'Selected orders: %d | Succeeded: %d | Failed: %d',
            $result['selected'],
            $result['succeeded'],
            $result['failed'],
        ));
        foreach ($result['failures'] as $failure) {
            $this->error(sprintf(
                'Commission failed for tenant %s order %s (%s).',
                $failure['tenant_id'],
                $failure['order_id'],
                $failure['exception'],
            ));
        }

        return $result['failed'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
