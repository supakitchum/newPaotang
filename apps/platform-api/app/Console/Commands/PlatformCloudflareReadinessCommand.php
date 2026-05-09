<?php

namespace App\Console\Commands;

use App\Shared\Cloudflare\CloudflareReadinessService;
use Illuminate\Console\Command;

class PlatformCloudflareReadinessCommand extends Command
{
    protected $signature = 'platform:cloudflare:readiness {--format=table : Output format: table or json}';

    protected $description = 'Emit the local/dev M10 Cloudflare, HTTPS, WAF, cache, CDN, and R2 readiness report.';

    public function handle(CloudflareReadinessService $readiness): int
    {
        $report = $readiness->report();

        if ($this->option('format') === 'json') {
            $this->line(json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }

        $this->line('status: '.$report['status']);
        $this->line('dry_run: '.($report['boundary']['dry_run'] ? 'true' : 'false'));
        $this->line('domains_total: '.$report['domains']['total']);
        $this->line('unsafe_active_domains: '.$report['domains']['unsafe_active']);
        $this->line('waf_cache_artifacts: '.$report['cache']['status']);
        $this->line('cdn_r2_ticket_images: '.$report['cdn_r2_ticket_images']['status']);
        $this->line('production_approved: false');

        return self::SUCCESS;
    }
}
