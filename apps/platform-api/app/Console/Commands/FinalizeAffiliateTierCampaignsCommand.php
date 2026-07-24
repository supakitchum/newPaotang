<?php

namespace App\Console\Commands;

use App\Modules\Growth\Services\AffiliateTierService;
use Illuminate\Console\Command;

class FinalizeAffiliateTierCampaignsCommand extends Command
{
    protected $signature = 'affiliate-tier-campaigns:finalize {--limit=25 : Maximum due campaigns to finalize}';

    protected $description = 'Activate and finalize due affiliate tier campaigns.';

    public function handle(AffiliateTierService $campaigns): int
    {
        $result = $campaigns->finalizeDueCampaignsBatch((int) $this->option('limit'));
        $this->info('Finalized affiliate tier campaigns: '.$result['finalized']);
        $this->line(sprintf(
            'Selected campaigns: %d | Succeeded: %d | Failed: %d',
            $result['selected'],
            $result['succeeded'],
            $result['failed'],
        ));
        foreach ($result['failures'] as $failure) {
            $this->error(sprintf(
                'Campaign %s failed during %s for tenant %s (%s).',
                $failure['campaign_id'],
                $failure['phase'],
                $failure['tenant_id'],
                $failure['exception'],
            ));
        }

        return $result['failed'] === 0 ? self::SUCCESS : self::FAILURE;
    }
}
