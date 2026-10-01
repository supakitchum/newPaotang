<?php

namespace App\Console\Commands;

use App\Modules\PartnerStore\Services\PartnerStoreService;
use Illuminate\Console\Command;

class ExpireStockReservationsCommand extends Command
{
    protected $signature = 'stock:reservations:expire {--limit=100}';

    protected $description = 'Expire active stock reservations past expires_at.';

    public function handle(PartnerStoreService $partnerStore): int
    {
        $expired = $partnerStore->expireReservations((int) $this->option('limit'));

        $this->info('Expired reservations: '.$expired);

        return self::SUCCESS;
    }
}
