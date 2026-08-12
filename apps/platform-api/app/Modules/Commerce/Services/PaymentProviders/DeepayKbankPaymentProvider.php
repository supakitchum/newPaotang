<?php

namespace App\Modules\Commerce\Services\PaymentProviders;

use App\Models\TenantPaymentProviderConnection;
use Illuminate\Http\Client\ConnectionException;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;

class DeepayKbankPaymentProvider
{
    public const PROVIDER = 'deepay_kbank';
    public const WEBHOOK_AUTH_MODE = 'manual_reconciliation';

    /**
     * @param array{reference1: string, reference2: string, reference3: string, reference4: string} $references
     * @return array<string, mixed>
     */
    public function createTopupBill(
        TenantPaymentProviderConnection $connection,
        string $channel,
        array $references,
        int $amountMinor,
    ): array {
        $startedAt = hrtime(true);
        $apiKey = $this->apiKey($connection);
        if ($apiKey === '') {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_not_configured',
                'message' => 'DeePay KBank API key is not configured.',
                'classification' => 'configuration_error',
                'latency_ms' => $this->latencyMs($startedAt),
            ];
        }

        $payload = [
            'amount' => $this->amountBaht($amountMinor),
            'reference1' => $this->providerReferenceValue($references['reference1'] ?? ''),
            'reference2' => $this->providerReferenceValue($references['reference2'] ?? ''),
            'reference3' => $this->providerReferenceValue($references['reference3'] ?? ''),
            'reference4' => $this->providerReferenceValue($references['reference4'] ?? ''),
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
                $providerMessage = $this->redactSecret(
                    $this->errorMessage($data) ?? 'DeePay KBank rejected the payment request.',
                    $apiKey,
                );

                return [
                    'ok' => false,
                    'error_code' => 'payment_provider_failed',
                    'message' => $providerMessage,
                    'http_status' => $response->status(),
                    'provider_code' => $this->providerCode($data),
                    'classification' => $response->status() === 401 ? 'provider_auth_rejected' : 'provider_rejected',
                    'latency_ms' => $this->latencyMs($startedAt),
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
                    'provider_code' => $this->providerCode($data),
                    'classification' => 'invalid_response',
                    'latency_ms' => $this->latencyMs($startedAt),
                ];
            }

            return [
                'ok' => true,
                'qr_code' => $qr,
                'provider_reference' => $providerReference,
                'http_status' => $response->status(),
                'provider_code' => $this->providerCode($data),
                'classification' => 'succeeded',
                'latency_ms' => $this->latencyMs($startedAt),
                'payload' => [
                    'provider' => self::PROVIDER,
                    'request' => [
                        'reference1' => $payload['reference1'],
                        'reference2' => $payload['reference2'],
                        'reference3' => $payload['reference3'],
                        'reference4' => $payload['reference4'],
                    ],
                    'provider_reference' => $providerReference,
                    'qr_code' => $qr,
                ],
            ];
        } catch (ConnectionException) {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_outcome_unknown',
                'message' => 'DeePay KBank did not confirm whether the payment request was accepted.',
                'classification' => 'outcome_unknown',
                'latency_ms' => $this->latencyMs($startedAt),
            ];
        } catch (\Throwable) {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_unavailable',
                'message' => 'DeePay KBank is temporarily unavailable.',
                'classification' => 'transport_failed',
                'latency_ms' => $this->latencyMs($startedAt),
            ];
        }
    }

    /**
     * @return array{ok: bool, error_code?: string, message?: string|null, http_status?: int|null, payload?: array<string, mixed>}
     */
    public function cancel(TenantPaymentProviderConnection $connection, string $providerReference): array
    {
        $startedAt = hrtime(true);
        $apiKey = $this->apiKey($connection);
        if ($apiKey === '' || trim($providerReference) === '') {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_not_configured',
                'classification' => 'configuration_error',
                'latency_ms' => $this->latencyMs($startedAt),
            ];
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

            if (! $response->successful()) {
                return [
                    'ok' => false,
                    'error_code' => 'payment_provider_cancel_failed',
                    'message' => $this->redactSecret($this->errorMessage($data) ?? 'DeePay KBank cancel request failed.', $apiKey),
                    'http_status' => $response->status(),
                    'provider_code' => $this->providerCode($data),
                    'classification' => $response->status() === 401 ? 'provider_auth_rejected' : 'provider_rejected',
                    'latency_ms' => $this->latencyMs($startedAt),
                ];
            }

            return [
                'ok' => true,
                'http_status' => $response->status(),
                'provider_code' => $this->providerCode($data),
                'classification' => 'succeeded',
                'latency_ms' => $this->latencyMs($startedAt),
            ];
        } catch (ConnectionException) {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_outcome_unknown',
                'message' => 'DeePay KBank did not confirm whether the cancellation was accepted.',
                'classification' => 'outcome_unknown',
                'latency_ms' => $this->latencyMs($startedAt),
            ];
        } catch (\Throwable) {
            return [
                'ok' => false,
                'error_code' => 'payment_provider_unavailable',
                'message' => 'DeePay KBank is temporarily unavailable.',
                'classification' => 'transport_failed',
                'latency_ms' => $this->latencyMs($startedAt),
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
        foreach (['message', 'error', 'error.message', 'result.message', 'result.errorDesc'] as $key) {
            $value = data_get($data, $key);
            if (is_string($value) && trim($value) !== '') {
                return $this->sanitizeProviderText($value);
            }
        }

        $validation = [];
        array_walk_recursive($data, function (mixed $value) use (&$validation): void {
            if (is_string($value) && trim($value) !== '') {
                $validation[] = trim($value);
            }
        });

        if ($validation !== []) {
            return $this->sanitizeProviderText(implode(' ', array_slice($validation, 0, 3)));
        }

        return null;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function providerCode(array $data): ?string
    {
        foreach (['code', 'errorCode', 'statusCode', 'result.errorCode', 'result.statusCode'] as $key) {
            $value = data_get($data, $key);
            if (is_string($value) || is_int($value)) {
                $code = $this->sanitizeProviderText((string) $value, 64);

                return $code === '' ? null : $code;
            }
        }

        return null;
    }

    private function providerReferenceValue(string $value): string
    {
        return substr(trim($value), 0, 20);
    }

    private function sanitizeProviderText(string $value, int $limit = 500): string
    {
        $value = strip_tags($value);
        $value = preg_replace('/data:image\/[a-z0-9.+-]+;base64,[a-z0-9+\/=]+/i', '[redacted-image]', $value) ?? '';
        $value = preg_replace('/[a-z0-9+\/]{80,}={0,2}/i', '[redacted-data]', $value) ?? '';
        $value = preg_replace('/\bBearer\s+[^\s]+/i', 'Bearer [redacted]', $value) ?? '';
        $value = preg_replace('/[\x00-\x1F\x7F]+/u', ' ', $value) ?? '';
        $value = preg_replace('/\s+/u', ' ', trim($value)) ?? '';

        return mb_substr($value, 0, $limit);
    }

    private function redactSecret(string $value, string $secret): string
    {
        if ($secret !== '') {
            $value = str_replace($secret, '[redacted]', $value);
        }

        return $this->sanitizeProviderText($value);
    }

    private function latencyMs(int $startedAt): int
    {
        return max(0, (int) round((hrtime(true) - $startedAt) / 1_000_000));
    }
}
