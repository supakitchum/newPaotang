<?php

namespace App\Jobs;

use App\Modules\Reward\Services\LottoScraperTriggerClient;
use Illuminate\Bus\Queueable;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Bus\Dispatchable;
use Illuminate\Queue\InteractsWithQueue;
use Illuminate\Queue\SerializesModels;
use Illuminate\Support\Facades\Log;
use RuntimeException;

class TriggerLottoScraperPollJob implements ShouldQueue
{
    use Dispatchable;
    use InteractsWithQueue;
    use Queueable;
    use SerializesModels;

    public int $tries = 3;

    /**
     * @var array<int, int>
     */
    public array $backoff = [10, 60, 300];

    public function __construct(
        public readonly string $drawCode,
        public readonly ?string $gameId = null,
        public readonly string $reason = 'manual_trigger',
    ) {
        $this->onQueue('default');
    }

    public function handle(LottoScraperTriggerClient $scraper): void
    {
        $result = $scraper->triggerDraw($this->drawCode, $this->gameId, $this->reason);

        if (($result['ok'] ?? false) === true) {
            Log::info('Lotto scraper trigger accepted.', [
                'draw_code' => $this->drawCode,
                'game_id' => $this->gameId,
                'reason' => $this->reason,
                'status' => $result['status'] ?? null,
            ]);

            return;
        }

        Log::warning('Lotto scraper trigger failed.', [
            'draw_code' => $this->drawCode,
            'game_id' => $this->gameId,
            'reason' => $this->reason,
            'retryable' => $result['retryable'] ?? false,
            'status' => $result['status'] ?? null,
            'message' => $result['message'] ?? null,
        ]);

        if (($result['retryable'] ?? false) === true) {
            throw new RuntimeException((string) ($result['message'] ?? 'Lotto scraper trigger failed.'));
        }
    }
}
