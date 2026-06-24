<?php

namespace App\Modules\Commerce\Services\PaymentProviders;

use App\Models\TenantPaymentProviderConnection;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;

class DeepayKbankPaymentProvider
{
    public const PROVIDER = 'deepay_kbank';

    /**
     * @return array{ok: bool, qr_code?: string|null, provider_reference?: string|null, payload?: array<string, mixed>, error_code?: string, message?: string|null, http_status?: int|null}
     */
    public function createTopupBill(
        TenantPaymentProviderConnection $connection,
        string $channel,
        string $tenantId,
        string $topupId,
        int $amountMinor,
    ): array {
        $apiKey = $this->apiKey($connection);
        if ($apiKey === '') {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_not_configured',
                'message' => 'DeePay KBank API key is not configured.',
            ];
        }

        $payload = [
            'amount' => $this->amountBaht($amountMinor),
            'reference1' => $topupId,
            'reference2' => 'wallet',
            'reference3' => $tenantId,
            'reference4' => $channel,
        ];

        $path = $channel === 'credit_card' ? 'billCredit' : 'bill';

        try {
            $response = Http::acceptJson()
                ->asJson()
                ->withHeaders(['x-api-key' => $apiKey])
                ->timeout((int) config('services.deepay_kbank.timeout', 15))
                ->post($this->endpoint($path), $payload);

            $body = $response->json();
            $data = is_array($body) ? $body : ['body' => $response->body()];

            if (! $response->successful()) {
                return [
                    'ok' => false,
                    'error_code' => 'payment_provider_failed',
                    'message' => $this->errorMessage($data) ?? 'DeePay KBank payment provider rejected the request.',
                    'http_status' => $response->status(),
                    'payload' => ['request' => $payload, 'response' => $data],
                ];
            }

            $qr = $this->qrCode($data);
            $providerReference = $this->providerReference($data);

            if ($qr === null || $providerReference === null) {
                return [
                    'ok' => false,
                    'error_code' => 'payment_provider_invalid_response',
                    'message' => 'DeePay KBank response did not include a QR Code or transaction reference.',
                    'http_status' => $response->status(),
                    'payload' => ['request' => $payload, 'response' => $data],
                ];
            }

            return [
                'ok' => true,
                'qr_code' => $qr,
                'provider_reference' => $providerReference,
                'http_status' => $response->status(),
                'payload' => [
                    'provider' => self::PROVIDER,
                    'request' => $payload,
                    'response' => $data,
                    'qr_code' => $qr,
                ],
            ];
        } catch (\Throwable $exception) {
            report($exception);

            return [
                'ok' => false,
                'error_code' => 'payment_provider_unavailable',
                'message' => $exception->getMessage(),
                'payload' => ['request' => $payload],
            ];
        }
    }

    /**
     * @return array{ok: bool, error_code?: string, message?: string|null, http_status?: int|null, payload?: array<string, mixed>}
     */
    public function cancel(TenantPaymentProviderConnection $connection, string $providerReference): array
    {
        $apiKey = $this->apiKey($connection);
        if ($apiKey === '' || trim($providerReference) === '') {
            return ['ok' => false, 'error_code' => 'payment_provider_not_configured'];
        }

        $payload = ['txn_id' => $providerReference];

        try {
            $response = Http::acceptJson()
                ->asJson()
                ->withHeaders(['x-api-key' => $apiKey])
                ->timeout((int) config('services.deepay_kbank.timeout', 15))
                ->post($this->endpoint('cancel'), $payload);

            $body = $response->json();
            $data = is_array($body) ? $body : ['body' => $response->body()];

            return [
                'ok' => $response->successful(),
                'error_code' => $response->successful() ? null : 'payment_provider_cancel_failed',
                'message' => $response->successful() ? null : ($this->errorMessage($data) ?? 'DeePay KBank cancel request failed.'),
                'http_status' => $response->status(),
                'payload' => ['request' => $payload, 'response' => $data],
            ];
        } catch (\Throwable $exception) {
            report($exception);

            return [
                'ok' => false,
                'error_code' => 'payment_provider_unavailable',
                'message' => $exception->getMessage(),
                'payload' => ['request' => $payload],
            ];
        }
    }

    private function endpoint(string $path): string
    {
        $base = rtrim((string) config('services.deepay_kbank.endpoint', 'https://ks-intershop.com/api/v1/payments/kbank'), '/');

        return $base.'/'.ltrim($path, '/');
    }

    private function amountBaht(int $amountMinor): float|int
    {
        $amount = $amountMinor / 100;

        return fmod($amount, 1.0) === 0.0 ? (int) $amount : round($amount, 2);
    }

    private function apiKey(TenantPaymentProviderConnection $connection): string
    {
        $encrypted = trim((string) $connection->api_key_encrypted);
        if ($encrypted === '') {
            return '';
        }

        try {
            return Crypt::decryptString($encrypted);
        } catch (\Throwable) {
            return '';
        }
    }

    /**
     * @param array<string, mixed> $data
     */
    private function qrCode(array $data): ?string
    {
        $qr = data_get($data, 'result.qr')
            ?? data_get($data, 'qr')
            ?? data_get($data, 'result.qr_code')
            ?? data_get($data, 'qr_code');

        $qr = trim((string) $qr);
        if ($qr === '') {
            return null;
        }

        if (str_starts_with($qr, 'data:image/')) {
            return $qr;
        }

        return 'data:image/jpeg;base64,'.$qr;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function providerReference(array $data): ?string
    {
        $reference = data_get($data, 'result.txn.response.partnerTxnUid')
            ?? data_get($data, 'result.partnerTxnUid')
            ?? data_get($data, 'partnerTxnUid')
            ?? data_get($data, 'transaction_id')
            ?? data_get($data, 'result.transaction_id');

        $reference = trim((string) $reference);

        return $reference === '' ? null : $reference;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function errorMessage(array $data): ?string
    {
        foreach (['message', 'error', 'error.message', 'result.message'] as $key) {
            $value = data_get($data, $key);
            if (is_string($value) && trim($value) !== '') {
                return trim($value);
            }
        }

        return null;
    }
}
