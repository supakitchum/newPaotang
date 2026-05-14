<?php

namespace App\Console\Commands;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use Illuminate\Console\Command;

class CheckPendingLotteryBackgroundsCommand extends Command
{
    protected $signature = 'lottery-images:check-pending-backgrounds {--limit=500} {--dry-run} {--game_id=} {--batch_id=} {--background-version=} {--set_type=}';

    protected $description = 'Dispatch lottery image jobs for pending rows whose required backgrounds and partner assets are ready.';

    public function handle(LotteryImageOperationsService $operations): int
    {
        $result = $operations->retryPending([
            'limit' => max(1, (int) $this->option('limit')),
            'dry_run' => (bool) $this->option('dry-run'),
            'game_id' => $this->option('game_id'),
            'batch_id' => $this->option('batch_id'),
            'version' => $this->option('background-version'),
            'set_type' => $this->option('set_type'),
        ]);

        if (($result['error'] ?? null) === 'validation_failed') {
            $this->error(json_encode($result['errors'] ?? [], JSON_PRETTY_PRINT));

            return self::FAILURE;
        }

        $this->line('Pending central ready: '.$result['central']['ready_count']);
        $this->line('Pending central dispatched: '.$result['central']['dispatched_count']);
        $this->line('Pending partner ready: '.$result['partner']['ready_count']);
        $this->line('Pending partner dispatched: '.$result['partner']['dispatched_count']);

        return self::SUCCESS;
    }
}
