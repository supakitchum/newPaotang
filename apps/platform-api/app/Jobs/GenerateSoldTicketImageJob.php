<?php

namespace App\Jobs;

use App\Models\LocalStockItem;
use App\Models\Ticket;
use App\Modules\PartnerStore\Services\VirtualLotteryImageService;
use App\Support\PublicUrl;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;

class GenerateSoldTicketImageJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;

    /**
     * @var array<int, int>
     */
    public array $backoff = [30, 120, 300];

    public function __construct(
        public readonly string $ticketId,
        public readonly bool $force = false,
    ) {
        $this->onQueue((string) config('lottery_images.queues.sold', config('lottery_images.queues.partner', 'stock-partner-image-generation')));
    }

    public function handle(VirtualLotteryImageService $images): void
    {
        $ticket = Ticket::query()->whereKey($this->ticketId)->first();

        if ($ticket === null) {
            return;
        }

        if (! $this->force && $ticket->image_url !== null && $ticket->image_thumb_url !== null && $this->snapshotStatus($ticket) === 'generated') {
            return;
        }

        $localStock = LocalStockItem::query()->whereKey((string) $ticket->local_stock_item_id)->first();

        if ($localStock === null) {
            $this->updateTicketSnapshot($ticket, [
                'ticket_id' => (string) $ticket->id,
                'render_status' => 'failed',
                'render_error' => 'local_stock_item_not_found',
                'rendered_at' => now()->toISOString(),
            ]);

            return;
        }

        $result = $images->renderSoldTicketImages((string) $ticket->id, $localStock);
        $snapshot = $result['snapshot'] === []
            ? [
                'ticket_id' => (string) $ticket->id,
                'render_status' => $result['image_url'] || $result['image_thumb_url'] ? 'generated' : 'skipped',
                'rendered_at' => now()->toISOString(),
            ]
            : $result['snapshot'];

        $updates = [
            'image_render_snapshot_json' => json_encode($snapshot, JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ];

        if ($result['image_url'] !== null) {
            $updates['image_url'] = PublicUrl::normalizeAssetUrl($result['image_url']);
        }

        if ($result['image_thumb_url'] !== null) {
            $updates['image_thumb_url'] = PublicUrl::normalizeAssetUrl($result['image_thumb_url']);
        }

        Ticket::query()->whereKey((string) $ticket->id)->update($updates);

        $error = (string) ($snapshot['render_error'] ?? '');
        if ($this->attempts() < $this->tries && $this->isRetriableError($error)) {
            $this->release($this->backoff[$this->attempts() - 1] ?? 300);
        }
    }

    private function snapshotStatus(Ticket $ticket): string
    {
        $snapshot = is_array($ticket->image_render_snapshot_json) ? $ticket->image_render_snapshot_json : [];

        return (string) ($snapshot['render_status'] ?? '');
    }

    /**
     * @param array<string, mixed> $snapshot
     */
    private function updateTicketSnapshot(Ticket $ticket, array $snapshot): void
    {
        Ticket::query()->whereKey((string) $ticket->id)->update([
            'image_render_snapshot_json' => json_encode($snapshot, JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ]);
    }

    private function isRetriableError(string $error): bool
    {
        return str_starts_with($error, 'background_set_not_ready')
            || str_starts_with($error, 'partner_branding_assets_not_ready');
    }
}
