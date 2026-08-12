<?php

namespace App\Console\Commands;

use App\Modules\Commerce\Services\CommerceService;
use Illuminate\Console\Command;

class ExpireTopupPaymentsCommand extends Command
{
    protected $signature = 'topups:payments:expire {--limit=100 : Maximum expired provider payments to process}';

    protected $description = 'Cancel provider QR payments after their payment window expires.';

    public function handle(CommerceService $commerce): int
    {
        $expired = $commerce->expireTopupPayments((int) $this->option('limit'));

        $this->line('Expired topup payments: '.$expired);

        return self::SUCCESS;
    }
}
