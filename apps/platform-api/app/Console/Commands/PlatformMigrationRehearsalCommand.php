<?php

namespace App\Console\Commands;

use App\Shared\Migration\MigrationRehearsalReadinessService;
use Illuminate\Console\Command;

class PlatformMigrationRehearsalCommand extends Command
{
    protected $signature = 'platform:migration:rehearsal {--dry-run : Inspect local/dev migration rehearsal readiness without mutating data} {--format=table : Output format: table or json}';

    protected $description = 'Emit the local/dev M10 migration rehearsal, cutover, and rollback readiness report.';

    public function handle(MigrationRehearsalReadinessService $readiness): int
    {
        $report = $readiness->report((bool) $this->option('dry-run'));

        if ($this->option('format') === 'json') {
            $this->line(json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }

        $this->line('status: '.$report['status']);
        $this->line('dry_run: '.($report['boundary']['dry_run'] ? 'true' : 'false'));
        $this->line('fixtures: '.$report['rehearsal_fixtures']['status']);
        $this->line('snapshots: '.$report['snapshot_requirements']['status']);
        $this->line('cutover: '.$report['cutover']['status']);
        $this->line('rollback: '.$report['rollback']['status']);
        $this->line('production_approved: false');

        return self::SUCCESS;
    }
}
