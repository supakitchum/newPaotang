<?php

namespace App\Jobs;

use App\Models\StockItem;
use App\Modules\CentralStock\Services\LotteryImageGenerator;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class GenerateLotteryImageJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public function __construct(
        public readonly string $stockItemId,
        public readonly bool $force = false,
    ) {
        $this->onQueue((string) config('lottery_images.queues.central', 'stock-image-generation'));
    }

    public function handle(LotteryImageGenerator $images): void
    {
        $stock = StockItem::query()->whereKey($this->stockItemId)->first();

        if ($stock === null) {
            return;
        }

        if (! $this->force && $stock->image_generation_status === 'generated' && $stock->image_generated_at !== null) {
            return;
        }

        if (! $images->enabled()) {
            $this->mark($stock, 'skipped', 'lottery_image_generation_disabled');
            return;
        }

        if ($stock->batch_id === null || $stock->background_set_type === null || $stock->background_asset_version === null || $stock->background_asset_index === null) {
            $this->mark($stock, 'skipped', 'background_assignment_missing');
            return;
        }

        if (! $images->backgroundReadyForStock($stock)) {
            $this->mark($stock, 'pending_assets', 'background_set_not_ready:'.$stock->background_set_type);
            return;
        }

        try {
            $fullKey = $images->centralObjectKey((string) $stock->game_id, (string) $stock->batch_id, (string) $stock->id);
            $thumbKey = $images->centralObjectKey((string) $stock->game_id, (string) $stock->batch_id, (string) $stock->id, 'thumb');

            $images->storeObject($fullKey, $images->renderCentralImage($stock, 'full'));
            $images->storeObject($thumbKey, $images->renderCentralImage($stock, 'thumb'));

            StockItem::query()->whereKey($stock->id)->update([
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
            $this->mark($stock, 'failed', substr($exception->getMessage(), 0, 1000));
        }
    }

    private function mark(StockItem $stock, string $status, ?string $error): void
    {
        StockItem::query()->whereKey($stock->id)->update([
            'image_generation_status' => $status,
            'image_generation_error' => $error,
            'updated_at' => now(),
        ]);
    }
}
