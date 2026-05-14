<?php

namespace App\Console\Commands;

use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GeneratePartnerLotteryImageJob;
use App\Models\LocalStockItem;
use App\Models\StockItem;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Console\Command;

class CheckPendingLotteryBackgroundsCommand extends Command
{
    protected $signature = 'lottery-images:check-pending-backgrounds {--limit=500} {--dry-run}';

    protected $description = 'Dispatch lottery image jobs for pending rows whose required backgrounds and partner assets are ready.';

    public function handle(LotteryImageGenerator $images): int
    {
        $limit = max(1, (int) $this->option('limit'));
        $dryRun = (bool) $this->option('dry-run');
        $centralReady = 0;
        $centralDispatched = 0;
        $partnerReady = 0;
        $partnerDispatched = 0;

        $stockRows = StockItem::query()
            ->where('image_generation_status', 'pending_assets')
            ->orderBy('id')
            ->limit($limit)
            ->get();

        foreach ($stockRows as $stock) {
            if (! $images->backgroundReadyForStock($stock)) {
                continue;
            }

            $centralReady++;

            if (! $dryRun) {
                GenerateLotteryImageJob::dispatch((string) $stock->id);
                $centralDispatched++;
            }
        }

        $localRows = LocalStockItem::query()
            ->where('image_generation_status', 'pending_assets')
            ->orderBy('id')
            ->limit($limit)
            ->get();

        foreach ($localRows as $localStock) {
            $stock = StockItem::query()->whereKey($localStock->stock_item_id)->first();

            if ($stock === null || ! $images->backgroundReadyForStock($stock) || $images->activePartnerAssetSet((string) $localStock->partner_id) === null) {
                continue;
            }

            $partnerReady++;

            if (! $dryRun) {
                GeneratePartnerLotteryImageJob::dispatch((string) $localStock->id);
                $partnerDispatched++;
            }
        }

        $this->line('Pending central ready: '.$centralReady);
        $this->line('Pending central dispatched: '.$centralDispatched);
        $this->line('Pending partner ready: '.$partnerReady);
        $this->line('Pending partner dispatched: '.$partnerDispatched);

        return self::SUCCESS;
    }
}
