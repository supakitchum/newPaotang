<?php

namespace App\Modules\Pricing\Http\Controllers;

use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Pricing\Services\LotterySalePriceService;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\StreamedResponse;

class PublicSalePriceStreamController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly LotterySalePriceService $prices,
    ) {
    }

    public function stream(Request $request): JsonResponse|StreamedResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $gameId = trim((string) $request->query('game_id', ''));
        $setSize = max(1, min(99, (int) $request->query('set_size', 1)));

        if ($gameId === '') {
            return ApiErrorResponse::validationFailed($request, [
                'game_id' => ['The game_id field is required.'],
            ]);
        }

        $tenantId = (string) $tenant['tenant_id'];
        $once = filter_var($request->query('once', false), FILTER_VALIDATE_BOOLEAN);

        return response()->stream(function () use ($tenantId, $gameId, $setSize, $once): void {
            $lastSignature = null;
            $lastHeartbeatAt = 0;
            $deadline = time() + ($once ? 1 : 300);

            while (! connection_aborted() && time() <= $deadline) {
                $price = $this->prices->effectivePrice($tenantId, $gameId, $setSize);
                $payload = [
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'set_size' => $setSize,
                    'price' => ['amount' => (int) $price['amount'], 'currency' => (string) $price['currency']],
                    'price_rule_summary' => $this->prices->summary($price),
                    'source' => (string) $price['source'],
                ];
                $signature = md5(json_encode($payload, JSON_THROW_ON_ERROR));

                if ($signature !== $lastSignature) {
                    $this->sendEvent('stock.price.updated', $payload);
                    $lastSignature = $signature;
                    $lastHeartbeatAt = time();

                    if ($once) {
                        return;
                    }
                } elseif (time() - $lastHeartbeatAt >= 15) {
                    echo ": heartbeat\n\n";
                    $this->flushStream();
                    $lastHeartbeatAt = time();
                }

                sleep(1);
            }
        }, 200, [
            'Content-Type' => 'text/event-stream',
            'Cache-Control' => 'no-cache, no-transform',
            'Connection' => 'keep-alive',
            'X-Accel-Buffering' => 'no',
        ]);
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return $this->tenantError($request, $result['error']);
        }

        return $result['context'];
    }

    /**
     * @param array{status: int, code: string, message: string, retry_after_seconds?: int|null} $error
     */
    private function tenantError(Request $request, array $error): JsonResponse
    {
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive($request, $error['retry_after_seconds'] ?? null);
        }

        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function sendEvent(string $event, array $payload): void
    {
        echo 'event: '.$event."\n";
        echo 'data: '.json_encode($payload, JSON_UNESCAPED_SLASHES)."\n\n";
        $this->flushStream();
    }

    private function flushStream(): void
    {
        if (ob_get_level() > 0) {
            @ob_flush();
        }

        flush();
    }
}
