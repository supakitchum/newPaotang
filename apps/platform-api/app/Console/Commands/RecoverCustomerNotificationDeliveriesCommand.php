<?php

namespace App\Console\Commands;

use App\Modules\CustomerNotifications\Services\CustomerNotificationService;
use Illuminate\Console\Command;

class RecoverCustomerNotificationDeliveriesCommand extends Command
{
    protected $signature = 'customer-notifications:recover-deliveries
        {--limit=100 : Maximum deliveries to inspect in one run}
        {--queued-minutes=2 : Grace period before recovering a never-dispatched delivery}
        {--stale-minutes=10 : Lease timeout for a worker left in sending state}
        {--device-limit=100 : Maximum stale push devices to revoke in one run}
        {--device-stale-days= : Override configured device inactivity window; 0 disables cleanup}';

    protected $description = 'Recover customer push deliveries, fan-outs, and stale device registrations.';

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
        $staleDaysOption = $this->option('device-stale-days');
        $staleDeviceCount = $notifications->revokeStaleDevices(
            (int) $this->option('device-limit'),
            is_numeric($staleDaysOption) ? (int) $staleDaysOption : null,
        );

        $this->info('Recovered customer push deliveries: '.$count);
        $this->info('Recovered customer notification fan-outs: '.$fanoutCount);
        $this->info('Revoked stale customer push devices: '.$staleDeviceCount);

        return self::SUCCESS;
    }
}
