<?php

namespace App\Console\Commands;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use Illuminate\Console\Command;

class RecoverCustomerNotificationDeliveriesCommand extends Command
{
    protected $signature = 'customer-notifications:recover-deliveries
        {--limit=100 : Maximum deliveries to inspect in one run}
        {--queued-minutes=2 : Grace period before recovering a never-dispatched delivery}
        {--stale-minutes=10 : Lease timeout for a worker left in sending state}';

    protected $description = 'Redispatch queued or stale customer push deliveries without duplicating an active send.';

    public function handle(CustomerNotificationService $notifications): int
    {
        $count = $notifications->recoverStaleDeliveries(
            (int) $this->option('limit'),
            (int) $this->option('queued-minutes'),
            (int) $this->option('stale-minutes'),
        );
        $fanoutCount = $notifications->recoverTenantFanouts(
            min(25, (int) $this->option('limit')),
            (int) $this->option('queued-minutes'),
        );

        $this->info('Recovered customer push deliveries: '.$count);
        $this->info('Recovered customer notification fan-outs: '.$fanoutCount);

        return self::SUCCESS;
    }
}
