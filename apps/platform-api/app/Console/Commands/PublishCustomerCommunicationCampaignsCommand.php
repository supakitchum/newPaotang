<?php

namespace App\Console\Commands;

use App\Modules\CustomerNotifications\Services\CustomerCommunicationCampaignService;
use Illuminate\Console\Command;

class PublishCustomerCommunicationCampaignsCommand extends Command
{
    protected $signature = 'customer-communications:publish-due {--limit=25 : Maximum due campaigns to publish}';

    protected $description = 'Publish due customer public-relations campaigns in bounded batches.';

    public function handle(CustomerCommunicationCampaignService $campaigns): int
    {
        $result = $campaigns->publishDue((int) $this->option('limit'));
        $this->info(sprintf(
            'Customer communication campaigns: selected=%d published=%d failed=%d',
            $result['selected'],
            $result['published'],
            $result['failed'],
        ));

        return self::SUCCESS;
    }
}
