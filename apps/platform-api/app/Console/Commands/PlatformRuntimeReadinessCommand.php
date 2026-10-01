<?php

namespace App\Console\Commands;

use App\Shared\Runtime\RuntimeReadinessService;
use Illuminate\Console\Command;

class PlatformRuntimeReadinessCommand extends Command
{
    protected $signature = 'platform:runtime:readiness {--format=table : Output format: table or json}';

    protected $description = 'Emit the local/dev M10 runtime hardening readiness report for queues, Horizon, Reverb, and scheduler.';

    public function handle(RuntimeReadinessService $readiness): int
    {
        $report = $readiness->report();

        if ($this->option('format') === 'json') {
            $this->line(json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }

        $this->line('status: '.$report['status']);
        $this->line('queue_workers: '.$report['queue_workers']['status']);
        $this->line('horizon: '.$report['horizon']['status']);
        $this->line('reverb: '.$report['reverb']['status']);
        $this->line('scheduler: '.$report['scheduler']['status']);
        $this->line('production_approved: false');

        return self::SUCCESS;
    }
}
