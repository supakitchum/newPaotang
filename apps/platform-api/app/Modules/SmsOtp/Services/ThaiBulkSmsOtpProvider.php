<?php

namespace App\Modules\SmsOtp\Services;

use App\Models\TenantSmsProvider;
use App\Modules\SmsOtp\Contracts\SmsOtpProviderInterface;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\Http;

class ThaiBulkSmsOtpProvider implements SmsOtpProviderInterface
{
    public function send(TenantSmsProvider $provider, string $phone, string $message): array
    {
        $apiKey = $this->decrypted($provider->api_key_encrypted);
        $apiSecret = $this->decrypted($provider->api_secret_encrypted);

        if ($apiKey === '' || $apiSecret === '') {
            return ['ok' => false, 'message' => 'ThaiBulkSMS credentials are missing.'];
        }

        $payload = [
            'msisdn' => $this->formatPhoneForProvider($phone),
            'message' => $message,
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
            $endpoint = (string) config('services.thaibulksms.sms_endpoint', 'https://api-v2.thaibulksms.com/sms');
            $response = Http::asForm()
                ->withBasicAuth($apiKey, $apiSecret)
                ->timeout(15)
                ->post($endpoint, $payload);

            $latency = (int) round((microtime(true) - $started) * 1000);
            $body = $response->json();
            $data = is_array($body) ? $body : ['body' => $response->body()];
            $ok = $response->successful();

            return [
                'ok' => $ok,
                'status' => $response->status(),
                'provider_message_id' => $this->providerMessageId($data),
                'message' => $ok ? null : $this->errorMessage($data),
                'response' => $data,
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
    private function providerMessageId(array $data): ?string
    {
        foreach (['message_id', 'messageId', 'id', 'credit_used'] as $key) {
            if (isset($data[$key]) && is_scalar($data[$key])) {
                return (string) $data[$key];
            }
        }

        return null;
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
}
