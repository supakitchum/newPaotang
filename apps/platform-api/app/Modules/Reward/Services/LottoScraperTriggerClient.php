<?php

namespace App\Modules\Reward\Services;

use Illuminate\Support\Facades\Http;

class LottoScraperTriggerClient
{
    /**
     * @return array<string, mixed>
     */
    public function triggerDraw(string $drawCode, ?string $gameId = null, string $reason = 'manual_trigger'): array
    {
        $url = trim((string) config('platform.lotto_scraper.trigger_url', ''));

        if ($url === '') {
            return [
                'ok' => false,
                'skipped' => true,
                'retryable' => false,
                'message' => 'Lotto scraper trigger URL is not configured.',
            ];
        }

        $payload = [
            'draw_code' => $drawCode,
            'game_id' => $gameId,
            'reason' => $reason,
            'force' => true,
        ];
        $body = json_encode($payload, JSON_THROW_ON_ERROR);
        $timestamp = (string) now()->timestamp;
        $secret = (string) config('platform.lotto_scraper.trigger_secret', config('platform.lotto_scraper.hmac_secret'));
        $signature = 'sha256='.hash_hmac('sha256', $timestamp.'.'.$body, $secret);
        $timeout = (int) config('platform.lotto_scraper.trigger_timeout_seconds', 15);

        try {
            $response = Http::acceptJson()
                ->withHeaders([
                    'content-type' => 'application/json',
                    'x-lotto-scraper-timestamp' => $timestamp,
                    'x-lotto-scraper-signature' => $signature,
                    'x-request-id' => 'req_platform_lotto_scraper_'.now()->format('YmdHisv'),
                ])
                ->withBody($body, 'application/json')
                ->timeout($timeout)
                ->post($url);
        } catch (\Throwable $exception) {
            return [
                'ok' => false,
                'retryable' => true,
                'message' => $exception->getMessage(),
            ];
        }

        $responseBody = $response->json();
        $data = is_array($responseBody) ? $responseBody : [];
        $ok = $response->successful() && ($data['ok'] ?? false) === true;

        return [
            'ok' => $ok,
            'retryable' => $response->serverError() || $response->status() === 429,
            'status' => $response->status(),
            'message' => $ok ? 'Lotto scraper trigger accepted.' : (string) ($data['message'] ?? $response->body()),
            'data' => $data,
        ];
    }
}
