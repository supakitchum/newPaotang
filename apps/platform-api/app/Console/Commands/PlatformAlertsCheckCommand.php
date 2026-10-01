<?php

namespace App\Console\Commands;

use App\Shared\Observability\AlertEvaluationService;
use Illuminate\Console\Command;

class PlatformAlertsCheckCommand extends Command
{
    protected $signature = 'platform:alerts:check {--dry-run : Evaluate without writing local alert events} {--format=table : Output format: table or json}';

    protected $description = 'Evaluate M10 local/dev alert policies and optionally write safe database alert events.';

    public function handle(AlertEvaluationService $alerts): int
    {
        $result = $alerts->evaluate((bool) $this->option('dry-run'));

        if ($this->option('format') === 'json') {
            $this->line(json_encode($result, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }

        $this->line('status: '.$result['status']);
        $this->line('dry_run: '.($result['dry_run'] ? 'true' : 'false'));
        $this->line('partners_evaluated: '.$result['summary']['partners_evaluated']);
        $this->line('policies_evaluated: '.$result['summary']['policies_evaluated']);
        $this->line('alerts_detected: '.$result['summary']['alerts_detected']);
        $this->line('external_delivery_attempted: false');

        return self::SUCCESS;
    }
}
