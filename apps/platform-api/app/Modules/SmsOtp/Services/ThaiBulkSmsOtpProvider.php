<?php

namespace App\Modules\SmsOtp\Services;

use App\Models\TenantSmsProvider;
use App\Modules\SmsOtp\Contracts\SmsOtpProviderInterface;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;

class ThaiBulkSmsOtpProvider implements SmsOtpProviderInterface
{
    public function requestOtp(TenantSmsProvider $provider, string $phone): array
    {
        $credentials = $this->credentials($provider);

        if ($credentials === null) {
            return ['ok' => false, 'message' => 'ThaiBulkSMS credentials are missing.'];
        }

        $payload = [
            'key' => $credentials['key'],
            'secret' => $credentials['secret'],
            'msisdn' => $this->formatPhoneForProvider($phone),
        ];

        $sender = trim((string) ($provider->sender_name ?? ''));
        if ($sender !== '') {
            if (! self::isValidSenderName($sender)) {
                return [
                    'ok' => false,
                    'status' => 422,
                    'message' => self::invalidSenderMessage(),
                    'response' => [
                        'error' => [
                            'code' => 'invalid_sender_name',
                            'description' => self::invalidSenderMessage(),
                        ],
                    ],
                    'latency_ms' => 0,
                ];
            }

            $payload['sender'] = $sender;
        }

        $started = microtime(true);

        try {
            $endpoint = (string) config('services.thaibulksms.otp_request_endpoint', 'https://otp.thaibulksms.com/v2/otp/request');
            $timeout = (int) config('services.thaibulksms.timeout', 15);
            $response = Http::asForm()
                ->timeout($timeout)
                ->post($endpoint, $payload);

            $latency = (int) round((microtime(true) - $started) * 1000);
            $body = $response->json();
            $data = is_array($body) ? $body : ['body' => $response->body()];
            $token = $this->scalarString($data['token'] ?? null);
            $refno = $this->scalarString($data['refno'] ?? null);
            $ok = $response->successful() && $this->isSuccessStatus($data) && $token !== '';

            return [
                'ok' => $ok,
                'status' => $response->status(),
                'provider_message_id' => $refno,
                'provider_token' => $ok ? $token : null,
                'provider_refno' => $refno,
                'message' => $ok ? null : $this->errorMessage($data),
                'response' => $this->sanitizedResponse($data),
                'latency_ms' => $latency,
            ];
        } catch (\Throwable $e) {
            return [
                'ok' => false,
                'status' => null,
                'message' => $e->getMessage(),
                'response' => null,
                'latency_ms' => (int) round((microtime(true) - $started) * 1000),
            ];
        }
    }

    public function verifyOtp(TenantSmsProvider $provider, string $providerToken, string $pin): array
    {
        $credentials = $this->credentials($provider);

        if ($credentials === null) {
            return ['ok' => false, 'status' => null, 'message' => 'ThaiBulkSMS credentials are missing.'];
        }

        $payload = [
            'key' => $credentials['key'],
            'secret' => $credentials['secret'],
            'token' => trim($providerToken),
            'pin' => preg_replace('/\D+/', '', $pin) ?: '',
        ];

        if ($payload['token'] === '' || $payload['pin'] === '') {
            return ['ok' => false, 'status' => 422, 'message' => 'ThaiBulkSMS OTP token or PIN is missing.'];
        }

        $started = microtime(true);

        try {
            $endpoint = (string) config('services.thaibulksms.otp_verify_endpoint', 'https://otp.thaibulksms.com/v2/otp/verify');
            $timeout = (int) config('services.thaibulksms.timeout', 15);
            $response = Http::asForm()
                ->timeout($timeout)
                ->post($endpoint, $payload);

            $latency = (int) round((microtime(true) - $started) * 1000);
            $body = $response->json();
            $data = is_array($body) ? $body : ['body' => $response->body()];
            $ok = $response->successful() && $this->isSuccessStatus($data);

            return [
                'ok' => $ok,
                'status' => $response->status(),
                'message' => $ok ? null : $this->errorMessage($data),
                'response' => $this->sanitizedResponse($data),
                'latency_ms' => $latency,
            ];
        } catch (\Throwable $e) {
            return [
                'ok' => false,
                'status' => null,
                'message' => $e->getMessage(),
                'response' => null,
                'latency_ms' => (int) round((microtime(true) - $started) * 1000),
            ];
        }
    }

    /**
     * @return array{key: string, secret: string}|null
     */
    private function credentials(TenantSmsProvider $provider): ?array
    {
        $apiKey = $this->decrypted($provider->api_key_encrypted);
        $apiSecret = $this->decrypted($provider->api_secret_encrypted);

        if ($apiKey === '' || $apiSecret === '') {
            return null;
        }

        return ['key' => $apiKey, 'secret' => $apiSecret];
    }

    private function decrypted(mixed $value): string
    {
        $encrypted = trim((string) $value);

        if ($encrypted === '') {
            return '';
        }

        try {
            return Crypt::decryptString($encrypted);
        } catch (\Throwable) {
            return '';
        }
    }

    private function formatPhoneForProvider(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?: '';

        if (str_starts_with($digits, '0')) {
            return '66'.substr($digits, 1);
        }

        return $digits;
    }

    public static function isValidSenderName(string $sender): bool
    {
        $sender = trim($sender);

        return $sender === '' || preg_match('/^[A-Za-z0-9._-]{1,11}$/', $sender) === 1;
    }

    public static function invalidSenderMessage(): string
    {
        return 'ThaiBulkSMS Sender ID is invalid. Use an approved English sender ID with letters, numbers, dot, dash, or underscore only, up to 11 characters, or leave it blank to use the provider default.';
    }

    /**
     * @param array<string, mixed> $data
     */
    private function isSuccessStatus(array $data): bool
    {
        $status = strtolower(trim((string) ($data['status'] ?? '')));

        if ($status === 'success') {
            return true;
        }

        $code = $data['code'] ?? $data['status_code'] ?? null;

        return is_numeric($code) && (int) $code === 0;
    }

    /**
     * @param array<string, mixed> $data
     */
    private function errorMessage(array $data): string
    {
        $message = $data['message'] ?? null;
        if (is_scalar($message) && trim((string) $message) !== '') {
            return (string) $message;
        }

        $error = $data['error'] ?? null;
        if (is_array($error)) {
            $parts = [];
            foreach (['name', 'description', 'message', 'code'] as $key) {
                if (isset($error[$key]) && is_scalar($error[$key]) && trim((string) $error[$key]) !== '') {
                    $parts[] = (string) $error[$key];
                }
            }

            if ($parts !== []) {
                return implode(': ', $parts);
            }
        }

        if (is_scalar($error) && trim((string) $error) !== '') {
            return (string) $error;
        }

        return 'ThaiBulkSMS request failed.';
    }

    private function scalarString(mixed $value): ?string
    {
        if (! is_scalar($value)) {
            return null;
        }

        $text = trim((string) $value);

        return $text === '' ? null : $text;
    }

    /**
     * @param array<string, mixed> $data
     * @return array<string, mixed>
     */
    private function sanitizedResponse(array $data): array
    {
        if (array_key_exists('token', $data)) {
            $data['token'] = 'redacted';
        }

        return $data;
    }
}
