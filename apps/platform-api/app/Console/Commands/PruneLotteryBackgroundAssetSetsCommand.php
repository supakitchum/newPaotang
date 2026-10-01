<?php

namespace App\Console\Commands;

use App\Modules\CentralStock\Services\LotteryImageOperationsService;
use Illuminate\Console\Command;

class PruneLotteryBackgroundAssetSetsCommand extends Command
{
    protected $signature = 'lottery-images:backgrounds:prune
        {--days=40 : Retention days after the game draw date}
        {--limit=100 : Maximum background asset sets to prune in one run}
        {--dry-run : Report eligible sets without deleting rows or storage objects}';

    protected $description = 'Delete lottery background asset sets after the draw retention window.';

    public function handle(LotteryImageOperationsService $operations): int
    {
        $result = $operations->pruneExpiredBackgroundSets(
            (int) $this->option('days'),
            (int) $this->option('limit'),
            (bool) $this->option('dry-run'),
        );

        $this->line('Eligible background sets: '.$result['eligible']);
        $this->line('Pruned background sets: '.$result['pruned']);
        $this->line('Deleted asset records: '.$result['asset_records_deleted']);
        $this->line('Deleted storage objects: '.$result['storage_objects_deleted']);
        $this->line('Cutoff: '.$result['cutoff_at']);

        return self::SUCCESS;
    }
}
