<?php

namespace App\Modules\Reward\Services;

use Illuminate\Support\Facades\Http;

class LottoScraperTriggerClient
{
    /**
     * @return array<string, mixed>
     */
    public function triggerDraw(string $drawCode, ?string $gameId = null, string $reason = 'manual_trigger', string $source = 'all', ?string $drawDate = null): array
    {
        $source = $this->normalizeSource($source);
        $targets = $this->triggerTargets($source);

        if ($targets === []) {
            return [
                'ok' => false,
                'skipped' => true,
                'retryable' => false,
                'source' => $source,
                'message' => $source === 'all'
                    ? 'Lotto scraper trigger URL is not configured.'
                    : 'Lotto scraper trigger URL is not configured for '.$source.'.',
            ];
        }

        $payload = [
            'draw_code' => $drawCode,
            'draw_date' => $drawDate !== null && trim($drawDate) !== '' ? trim($drawDate) : $this->drawDateFromCode($drawCode),
            'game_id' => $gameId,
            'reason' => $reason,
            'force' => true,
        ];
        $secret = (string) config('platform.lotto_scraper.trigger_secret', config('platform.lotto_scraper.hmac_secret'));
        $timeout = (int) config('platform.lotto_scraper.trigger_timeout_seconds', 15);
        $results = [];

        foreach ($targets as $target) {
            $targetPayload = $payload;

            if (($target['source'] ?? null) !== null) {
                $targetPayload['source'] = $target['source'];
            }

            $results[] = $this->triggerUrl($target['url'], $targetPayload, $secret, $timeout, $target['source']);
        }

        $failed = array_values(array_filter($results, fn (array $result): bool => ($result['ok'] ?? false) !== true));
        $ok = $failed === [];
        $retryable = collect($failed)->contains(fn (array $result): bool => ($result['retryable'] ?? false) === true);

        return [
            'ok' => $ok,
            'retryable' => $retryable,
            'source' => $source,
            'status' => $ok ? 202 : ($failed[0]['status'] ?? null),
            'message' => $ok ? 'Lotto scraper trigger accepted.' : (string) ($failed[0]['message'] ?? 'Lotto scraper trigger failed.'),
            'data' => [
                'targets' => $results,
            ],
        ];
    }

    /**
     * @return array<int, array{source: string|null, url: string}>
     */
    private function triggerTargets(string $source): array
    {
        $targets = [];
        $explicitSources = config('platform.lotto_scraper.trigger_source_urls', []);
        $explicitSources = is_array($explicitSources) ? $explicitSources : [];

        foreach ($explicitSources as $sourceName => $url) {
            $sourceName = $this->normalizeSource((string) $sourceName);
            $url = trim((string) $url);

            if ($sourceName === 'all' || $url === '') {
                continue;
            }

            $targets[] = ['source' => $sourceName, 'url' => $url];
        }

        $configured = config('platform.lotto_scraper.trigger_urls', []);
        $urls = is_array($configured) ? $configured : [];

        if ($urls === []) {
            $urls[] = config('platform.lotto_scraper.trigger_url', '');
        }

        $urls = array_values(array_unique(array_filter(array_map(
            static fn (mixed $url): string => trim((string) $url),
            $urls,
        ))));

        foreach ($urls as $url) {
            $targets[] = ['source' => $this->inferSourceFromUrl($url), 'url' => $url];
        }

        $seen = [];
        $targets = array_values(array_filter($targets, static function (array $target) use (&$seen): bool {
            $key = ($target['source'] ?? '').'|'.$target['url'];
            if (isset($seen[$key])) {
                return false;
            }
            $seen[$key] = true;

            return true;
        }));

        if ($source === 'all') {
            return $targets;
        }

        $filtered = array_values(array_filter($targets, fn (array $target): bool => ($target['source'] ?? null) === $source));

        if ($filtered !== []) {
            return $filtered;
        }

        return [];
    }

    /**
     * @return array<string, mixed>
     */
    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function triggerUrl(string $url, array $payload, string $secret, int $timeout, ?string $source): array
    {
        $body = json_encode($payload, JSON_THROW_ON_ERROR);
        $timestamp = (string) now()->timestamp;
        $signature = 'sha256='.hash_hmac('sha256', $timestamp.'.'.$body, $secret);

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
                'url' => $url,
                'ok' => false,
                'retryable' => true,
                'message' => $exception->getMessage(),
            ];
        }

        $responseBody = $response->json();
        $data = is_array($responseBody) ? $responseBody : [];
        $ok = $response->successful() && ($data['ok'] ?? false) === true;

        return [
            'source' => $source,
            'url' => $url,
            'ok' => $ok,
            'retryable' => $response->serverError() || $response->status() === 429,
            'status' => $response->status(),
            'message' => $ok ? 'Lotto scraper trigger accepted.' : (string) ($data['message'] ?? $response->body()),
            'data' => $data,
        ];
    }

    private function normalizeSource(string $source): string
    {
        $source = strtolower(trim($source));

        return match ($source) {
            'sanook' => 'sanook',
            'thairath', 'thai_rath', 'thai-rath' => 'thairath',
            default => 'all',
        };
    }

    private function inferSourceFromUrl(string $url): ?string
    {
        $lower = strtolower($url);

        if (str_contains($lower, 'thairath')) {
            return 'thairath';
        }

        if (str_contains($lower, 'sanook') || str_contains($lower, 'lotto-scraper:')) {
            return 'sanook';
        }

        return null;
    }

    private function drawDateFromCode(string $drawCode): ?string
    {
        if (! preg_match('/^[0-9]{8}$/', $drawCode)) {
            return null;
        }

        $day = (int) substr($drawCode, 0, 2);
        $month = (int) substr($drawCode, 2, 2);
        $year = (int) substr($drawCode, 4, 4) - 543;

        if (! checkdate($month, $day, $year)) {
            return null;
        }

        return sprintf('%04d-%02d-%02d', $year, $month, $day);
    }
}
