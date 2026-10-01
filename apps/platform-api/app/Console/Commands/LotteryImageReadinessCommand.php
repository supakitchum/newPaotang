<?php

namespace App\Console\Commands;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use Illuminate\Console\Command;

class LotteryImageReadinessCommand extends Command
{
    protected $signature = 'lottery-images:readiness {--game_id=} {--batch_id=} {--background-version=} {--format=table}';

    protected $description = 'Report lottery image object storage, queue, runtime, and optional game background readiness.';

    public function handle(LotteryImageOperationsService $operations): int
    {
        $format = strtolower((string) $this->option('format'));
        $gameId = trim((string) $this->option('game_id'));
        $report = $gameId === ''
            ? $operations->productionReadiness()
            : $operations->readiness([
                'game_id' => $gameId,
                'batch_id' => $this->option('batch_id'),
                'version' => $this->option('background-version'),
            ]);

        if (($report['error'] ?? null) === 'validation_failed') {
            $this->error(json_encode($report['errors'] ?? [], JSON_PRETTY_PRINT));

            return self::FAILURE;
        }

        if ($format === 'json') {
            $this->line(json_encode($report, JSON_PRETTY_PRINT | JSON_UNESCAPED_SLASHES));

            return self::SUCCESS;
        }

        if ($gameId === '') {
            $this->line('Production ready: '.($report['production_ready'] ? 'yes' : 'no'));
            $this->line('Disk: '.$report['disk'].' ('.$report['disk_driver'].')');
            $this->line('Runtime WebP ready: '.($report['runtime_webp_ready'] ? 'yes' : 'no'));
            $this->line('Queue configured: '.($report['queue_configured'] ? 'yes' : 'no'));
            $this->line('Blocking reasons: '.implode(', ', $report['blocking_reasons'] ?? []));

            return self::SUCCESS;
        }

        $this->line('Game: '.$report['game_id']);
        $this->line('Version: '.$report['version']);
        $this->line('Missing set types: '.implode(', ', $report['missing_set_types'] ?? []));
        $this->line('Pending central: '.$report['pending_assets']['central']);
        $this->line('Pending partner: '.$report['pending_assets']['partner']);
        $this->line('Failed central: '.$report['failed_generation']['central']);
        $this->line('Failed partner: '.$report['failed_generation']['partner']);

        return self::SUCCESS;
    }
}
