<?php

namespace App\Jobs;

use App\Models\LocalStockItem;
use App\Models\StockItem;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class GeneratePartnerLotteryImageJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function __construct(
        public readonly string $localStockItemId,
        public readonly bool $force = false,
    ) {
        $this->onQueue((string) config('lottery_images.queues.partner', 'stock-partner-image-generation'));
    }

    public function handle(LotteryImageGenerator $images): void
    {
        $localStock = LocalStockItem::query()->whereKey($this->localStockItemId)->first();

        if ($localStock === null) {
            return;
        }

        if (! $this->force && $localStock->image_generation_status === 'generated' && $localStock->image_generated_at !== null) {
            return;
        }

        if (! $images->enabled()) {
            $this->mark($localStock, 'skipped', 'lottery_image_generation_disabled');
            return;
        }

        $stock = StockItem::query()->whereKey($localStock->stock_item_id)->first();

        if ($stock === null || $stock->batch_id === null || $stock->background_set_type === null || $stock->background_asset_version === null || $stock->background_asset_index === null) {
            $this->mark($localStock, 'skipped', 'central_background_assignment_missing');
            return;
        }

        if (! $images->backgroundReadyForStock($stock)) {
            $this->mark($localStock, 'pending_assets', 'background_set_not_ready:'.$stock->background_set_type);
            return;
        }

        $assetSet = $images->activePartnerAssetSet((string) $localStock->partner_id);

        if ($assetSet === null) {
            $this->mark($localStock, 'pending_assets', 'partner_branding_assets_not_ready');
            return;
        }

        try {
            $fullKey = $images->partnerObjectKey((string) $localStock->game_id, (string) $stock->batch_id, (string) $localStock->partner_id, (string) $stock->id);
            $thumbKey = $images->partnerObjectKey((string) $localStock->game_id, (string) $stock->batch_id, (string) $localStock->partner_id, (string) $stock->id, 'thumb');

            $images->storeObject($fullKey, $images->renderPartnerImage($localStock, $stock, $assetSet, 'full'));
            $images->storeObject($thumbKey, $images->renderPartnerImage($localStock, $stock, $assetSet, 'thumb'));

            LocalStockItem::query()->whereKey($localStock->id)->update([
                'image_url' => $images->publicUrl($fullKey),
                'image_thumb_url' => $images->publicUrl($thumbKey),
                'image_storage_path' => $fullKey,
                'image_thumb_storage_path' => $thumbKey,
                'image_generation_status' => 'generated',
                'image_generation_error' => null,
                'image_generated_at' => now(),
                'updated_at' => now(),
            ]);
        } catch (\Throwable $exception) {
            $this->mark($localStock, 'failed', substr($exception->getMessage(), 0, 1000));
        }
    }

    private function mark(LocalStockItem $localStock, string $status, ?string $error): void
    {
        LocalStockItem::query()->whereKey($localStock->id)->update([
            'image_generation_status' => $status,
            'image_generation_error' => $error,
            'updated_at' => now(),
        ]);
    }
}
