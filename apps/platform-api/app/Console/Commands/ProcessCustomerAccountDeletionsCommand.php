<?php

namespace App\Console\Commands;

use App\Modules\Auth\Services\CustomerAccountDeletionService;
use Illuminate\Console\Command;

class ProcessCustomerAccountDeletionsCommand extends Command
{
    protected $signature = 'customer-accounts:process-deletions {--limit=100}';

    protected $description = 'Send deletion reminders and finalize due customer account deletion requests.';

    public function handle(CustomerAccountDeletionService $deletions): int
    {
        $reminders = $deletions->sendDueReminders((int) $this->option('limit'));
        $result = $deletions->processDue((int) $this->option('limit'));
        $this->info(sprintf(
            'Reminders: %d | Selected: %d | Completed: %d | Blocked: %d',
            $reminders,
            $result['selected'],
            $result['completed'],
            $result['blocked'],
        ));

        return self::SUCCESS;
    }
}
