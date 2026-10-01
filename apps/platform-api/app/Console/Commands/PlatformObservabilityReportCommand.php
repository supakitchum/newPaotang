<?php

namespace App\Console\Commands;

use App\Shared\Observability\ObservabilityReportService;
use Illuminate\Console\Command;

class PlatformObservabilityReportCommand extends Command
{
    protected $signature = 'platform:observability:report {--format=table : Output format: table or json}';

    protected $description = 'Emit the local/dev M10 observability signal inventory and readiness report.';

    public function handle(ObservabilityReportService $reports): int
    {
        $report = $reports->report();

        if ($this->option('format') === 'json') {
            $this->line(json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }

        $this->line('status: '.$report['status']);
        $this->line('environment: '.$report['environment']['name']);
        $this->line('partners: '.$report['summary']['partners']);
        $this->line('active_alert_policies: '.$report['summary']['active_alert_policies']);
        $this->line('production_approved: false');

        return self::SUCCESS;
    }
}
