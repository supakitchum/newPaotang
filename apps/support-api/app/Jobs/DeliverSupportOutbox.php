<?php

namespace App\Jobs;

use App\Models\SupportOutbox;
use Illuminate\Contracts\Queue\ShouldQueue;
use Illuminate\Foundation\Queue\Queueable;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Http;

class DeliverSupportOutbox implements ShouldQueue
{
    use Queueable;

    public int $tries = 1;

    public int $timeout = 60;

    public function handle(): void
    {
        $url = trim((string) config('support.platform_notifications.url'));
        $secret = trim((string) config('support.platform_notifications.secret'));
        if ($url === '' || $secret === '' || Cache::get('support-platform-notification-circuit-open') === true) {
            return;
        }

        SupportOutbox::query()
            ->where('status', 'pending')
            ->where('available_at', '<=', now())
            ->orderBy('available_at')
            ->limit(100)
            ->get()
            ->each(function (SupportOutbox $event) use ($url, $secret): void {
                $body = json_encode($event->payload_json, JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES);
                try {
                    $response = Http::timeout((int) config('support.platform_notifications.timeout_seconds', 3))
                        ->withHeaders([
                            'Content-Type' => 'application/json',
                            'X-Support-Event-Id' => (string) $event->id,
                            'X-Support-Signature' => hash_hmac('sha256', (string) $body, $secret),
                        ])
                        ->withBody((string) $body, 'application/json')
                        ->post($url);
                    if ($response->successful() || $response->status() === 409) {
                        $event->fill([
                            'status' => 'delivered',
                            'attempts' => ((int) $event->attempts) + 1,
                            'delivered_at' => now(),
                            'last_error' => null,
                        ])->save();

                        return;
                    }
                    $this->reschedule($event, 'HTTP '.$response->status());
                    if ($response->serverError() && (int) $event->attempts >= 4) {
                        $this->openCircuit();
                    }
                } catch (\Throwable $exception) {
                    $this->reschedule($event, $exception->getMessage());
                    if ((int) $event->attempts >= 4) {
                        $this->openCircuit();
                    }
                }
            });
    }

    private function reschedule(SupportOutbox $event, string $error): void
    {
        $attempts = ((int) $event->attempts) + 1;
        $event->fill([
            'status' => $attempts >= 10 ? 'failed' : 'pending',
            'attempts' => $attempts,
            'available_at' => now()->addSeconds(min(3600, 2 ** min(10, $attempts))),
            'last_error' => mb_substr($error, 0, 500),
        ])->save();
    }

    private function openCircuit(): void
    {
        Cache::put(
            'support-platform-notification-circuit-open',
            true,
            now()->addSeconds(max(15, (int) config(
                'support.platform_notifications.circuit_breaker_seconds',
                60,
            ))),
        );
    }
}
