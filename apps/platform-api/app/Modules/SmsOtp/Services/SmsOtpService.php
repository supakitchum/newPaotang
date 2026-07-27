<?php

namespace App\Modules\SmsOtp\Services;

use App\Models\OtpVerification;
use App\Models\SmsDeliveryLog;
use App\Models\TenantSmsProvider;
use App\Modules\SmsOtp\Contracts\SmsOtpProviderInterface;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class SmsOtpService
{
    public const PURPOSE_REGISTER = 'register';
    public const PURPOSE_LOGIN = 'login';
    public const PURPOSE_PASSWORD_RESET = 'password_reset';
    public const PURPOSE_PIN_RESET = 'pin_reset';

    private const OTP_TTL_SECONDS = 300;
    private const OTP_COOLDOWN_SECONDS = 60;
    private const OTP_MAX_ATTEMPTS = 5;
    private const TOKEN_TTL_SECONDS = 600;
    private const OTP_RATE_WINDOW_SECONDS = 3600;
    private const OTP_PHONE_RATE_LIMIT = 5;
    private const OTP_IP_RATE_LIMIT = 30;
    private const OTP_DEVICE_RATE_LIMIT = 30;

    public function __construct(private readonly ThaiBulkSmsOtpProvider $thaiBulk)
    {
    }

    public function storageReady(): bool
    {
        try {
            return Schema::hasTable('tenant_sms_providers')
                && Schema::hasTable('otp_verifications')
                && Schema::hasTable('sms_delivery_logs');
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * @return array<string, mixed>
     */
    public function settings(string $tenantId, array $query = []): array
    {
        $provider = $this->providerForTenant($tenantId);

        return [
            'connection' => $this->providerResource($provider, $tenantId),
            'providers' => $this->providerRows($tenantId),
            'deliveries' => $this->deliveryLogs($tenantId, $query),
            'otps' => $this->otpLogs($tenantId, $query),
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, mixed>, message?: string, details?: array<string, mixed>}
     */
    public function updateProvider(string $tenantId, array $payload): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $existing = $this->providerForTenant($tenantId);
        $provider = trim((string) ($payload['provider'] ?? 'thaibulk')) ?: 'thaibulk';
        $status = in_array(($payload['status'] ?? 'active'), ['active', 'inactive'], true) ? (string) $payload['status'] : 'active';
        $apiKey = $this->connectionSecret($existing, $payload, 'api_key', 'api_key_encrypted');
        $apiSecret = $this->connectionSecret($existing, $payload, 'api_secret', 'api_secret_encrypted');
        $sender = trim((string) ($payload['sender_name'] ?? ($existing?->sender_name ?? '')));
        $errors = [];

        if ($provider !== 'thaibulk') {
            $errors['provider'][] = 'Only ThaiBulkSMS is supported in this version.';
        }

        if ($apiKey === '') {
            $errors['api_key'][] = 'The API key field is required.';
        }

        if ($apiSecret === '') {
            $errors['api_secret'][] = 'The API secret field is required.';
        }

        if ($sender !== '' && ! ThaiBulkSmsOtpProvider::isValidSenderName($sender)) {
            $errors['sender_name'][] = ThaiBulkSmsOtpProvider::invalidSenderMessage();
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        try {
            $encrypted = [
                'api_key_encrypted' => Crypt::encryptString($apiKey),
                'api_secret_encrypted' => Crypt::encryptString($apiSecret),
            ];
        } catch (\Throwable) {
            return [
                'error' => 'sms_encryption_failed',
                'message' => 'เกิดข้อผิดพลาดในการบันทึก SMS OTP กรุณากด Save ใหม่อีกครั้ง',
                'details' => ['fields' => ['connection' => ['Unable to encrypt SMS credentials.']]],
            ];
        }

        DB::transaction(function () use ($tenantId, $provider, $existing, $status, $encrypted, $sender): void {
            if ($status === 'active') {
                $this->deactivateOtherProviders($tenantId, $existing?->id);
            }

            TenantSmsProvider::query()->updateOrCreate(
                ['tenant_id' => $tenantId, 'provider' => $provider],
                [
                    'id' => $existing?->id ?: 'tsp_'.Str::ulid()->toBase32(),
                    'status' => $status,
                    ...$encrypted,
                    'sender_name' => $sender !== '' ? $sender : null,
                    'updated_at' => now(),
                ],
            );
        });

        return ['resource' => $this->settings($tenantId)];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, mixed>, status?: int, message?: string}
     */
    public function updateProviderStatus(string $tenantId, string $providerId, array $payload): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $status = trim((string) ($payload['status'] ?? ''));

        if (! in_array($status, ['active', 'inactive'], true)) {
            return ['error' => 'validation_failed', 'errors' => ['status' => ['The status field must be active or inactive.']]];
        }

        $provider = TenantSmsProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $providerId)
            ->first();

        if (! $provider instanceof TenantSmsProvider) {
            return ['error' => 'not_found', 'status' => 404, 'message' => 'SMS OTP provider was not found.'];
        }

        if ($status === 'active' && (! $provider->api_key_encrypted || ! $provider->api_secret_encrypted)) {
            return [
                'error' => 'validation_failed',
                'errors' => ['provider' => ['Save API key and API secret before activating this provider.']],
            ];
        }

        DB::transaction(function () use ($tenantId, $providerId, $status): void {
            if ($status === 'active') {
                $this->deactivateOtherProviders($tenantId, $providerId);
            }

            TenantSmsProvider::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $providerId)
                ->update([
                    'status' => $status,
                    'updated_at' => now(),
                ]);
        });

        return ['resource' => $this->settings($tenantId)];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, mixed>, status?: int, message?: string}
     */
    public function testSend(string $tenantId, array $payload): array
    {
        $phone = $this->normalizePhone($payload['phone'] ?? null);
        if ($phone === null) {
            return ['error' => 'validation_failed', 'errors' => ['phone' => ['The phone field is required.']]];
        }

        $provider = $this->providerForTenant($tenantId);
        if (! $provider instanceof TenantSmsProvider) {
            return ['error' => 'provider_not_configured', 'status' => 409, 'message' => 'SMS OTP provider is not configured for this tenant.'];
        }

        $result = $this->requestWithProvider($provider, self::PURPOSE_REGISTER, $phone, [
            'test' => true,
            'provider_operation' => 'otp.request',
        ]);

        TenantSmsProvider::query()
            ->where('id', $provider->id)
            ->update([
                'verified_at' => ($result['ok'] ?? false) ? now() : $provider->verified_at,
                'last_tested_at' => now(),
                'last_test_status' => ($result['ok'] ?? false) ? 'sent' : 'failed',
                'last_test_message' => ($result['ok'] ?? false) ? 'Test SMS sent.' : ($result['message'] ?? 'SMS send failed.'),
                'updated_at' => now(),
            ]);

        return ($result['ok'] ?? false)
            ? ['resource' => ['status' => 'sent', 'message' => 'Test SMS sent.']]
            : [
                'error' => 'sms_test_failed',
                'status' => ((int) ($result['status'] ?? 0)) === 422 ? 422 : 503,
                'message' => (string) ($result['message'] ?? 'SMS send failed.'),
            ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, mixed>, status?: int, message?: string, details?: array<string, mixed>}
     */
    public function requestOtp(string $tenantId, array $payload, Request $request, ?string $forcedPurpose = null, ?string $forcedPhone = null): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $purpose = $forcedPurpose ?: $this->normalizePurpose($payload['purpose'] ?? null);
        $phone = $this->normalizePhone($forcedPhone ?? ($payload['phone'] ?? null));
        $errors = [];

        if ($purpose === null) {
            $errors['purpose'][] = 'The purpose field is invalid.';
        }

        if ($phone === null) {
            $errors['phone'][] = 'The phone field is required.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $provider = $this->activeProviderForTenant($tenantId);
        if (! $provider instanceof TenantSmsProvider) {
            return [
                'error' => 'provider_not_configured',
                'status' => 409,
                'message' => 'SMS OTP provider is not configured for this tenant.',
                'details' => ['provider_required' => $purpose !== self::PURPOSE_REGISTER],
            ];
        }

        $cooldown = OtpVerification::query()
            ->where('tenant_id', $tenantId)
            ->where('phone_normalized', $phone)
            ->where('purpose', $purpose)
            ->where('status', 'pending')
            ->where('cooldown_until', '>', now())
            ->orderByDesc('created_at')
            ->first();

        if ($cooldown instanceof OtpVerification) {
            return [
                'error' => 'otp_cooldown',
                'status' => 429,
                'message' => 'Please wait before requesting another OTP.',
                'details' => ['retry_after_seconds' => max(1, now()->diffInSeconds($cooldown->cooldown_until, false))],
            ];
        }

        $rateLimit = $this->rateLimitRequest($tenantId, $purpose, $phone, $request);
        if ($rateLimit !== null) {
            return $rateLimit;
        }

        $now = now();
        $verificationId = 'otp_'.Str::ulid()->toBase32();
        $metadata = ['user_agent_hash' => hash('sha256', (string) $request->userAgent())];

        OtpVerification::query()->insert([
            'id' => $verificationId,
            'tenant_id' => $tenantId,
            'provider_id' => (string) $provider->id,
            'provider' => (string) $provider->provider,
            'purpose' => $purpose,
            'phone' => $phone,
            'phone_normalized' => $phone,
            'otp_hash' => Hash::make('provider-managed:'.$verificationId),
            'verification_token_hash' => null,
            'status' => 'pending',
            'attempts' => 0,
            'max_attempts' => self::OTP_MAX_ATTEMPTS,
            'expires_at' => $now->copy()->addSeconds(self::OTP_TTL_SECONDS),
            'cooldown_until' => $now->copy()->addSeconds(self::OTP_COOLDOWN_SECONDS),
            'verified_at' => null,
            'consumed_at' => null,
            'requested_ip' => $request->ip(),
            'requested_user_agent' => $request->userAgent(),
            'metadata_json' => json_encode($metadata, JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $result = $this->requestWithProvider($provider, $purpose, $phone, [
            'otp_verification_id' => $verificationId,
            'provider_operation' => 'otp.request',
        ]);

        if (($result['ok'] ?? false) !== true) {
            OtpVerification::query()->where('id', $verificationId)->update([
                'status' => 'failed',
                'updated_at' => now(),
            ]);

            return [
                'error' => 'sms_send_failed',
                'status' => 503,
                'message' => (string) ($result['message'] ?? 'SMS OTP could not be sent.'),
            ];
        }

        $providerMetadata = $this->providerRequestMetadata($metadata, $result);
        OtpVerification::query()->where('id', $verificationId)->update([
            'metadata_json' => json_encode($providerMetadata, JSON_THROW_ON_ERROR),
            'updated_at' => now(),
        ]);

        return [
            'resource' => [
                'otp_id' => $verificationId,
                'status' => 'sent',
                'purpose' => $purpose,
                'phone_masked' => $this->maskPhone($phone),
                'refno' => $result['provider_refno'] ?? null,
                'expires_in_seconds' => self::OTP_TTL_SECONDS,
                'resend_after_seconds' => self::OTP_COOLDOWN_SECONDS,
            ],
            'status' => 202,
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, mixed>, status?: int, message?: string, details?: array<string, mixed>}
     */
    public function verifyOtp(string $tenantId, array $payload, ?string $forcedPurpose = null, ?string $forcedPhone = null): array
    {
        if (! $this->storageReady()) {
            return $this->storageUnavailable();
        }

        $purpose = $forcedPurpose ?: $this->normalizePurpose($payload['purpose'] ?? null);
        $phone = $this->normalizePhone($forcedPhone ?? ($payload['phone'] ?? null));
        $code = preg_replace('/\D+/', '', (string) ($payload['otp'] ?? $payload['code'] ?? '')) ?: '';
        $errors = [];

        if ($purpose === null) {
            $errors['purpose'][] = 'The purpose field is invalid.';
        }

        if ($phone === null) {
            $errors['phone'][] = 'The phone field is required.';
        }

        if (! preg_match('/^\d{6}$/', $code)) {
            $errors['otp'][] = 'The OTP field must contain exactly 6 digits.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($tenantId, $purpose, $phone, $code): array {
            $verification = OtpVerification::query()
                ->where('tenant_id', $tenantId)
                ->where('phone_normalized', $phone)
                ->where('purpose', $purpose)
                ->where('status', 'pending')
                ->where('expires_at', '>', now())
                ->orderByDesc('created_at')
                ->lockForUpdate()
                ->first();

            if (! $verification instanceof OtpVerification) {
                return ['error' => 'otp_invalid', 'status' => 422, 'message' => 'OTP is invalid or expired.'];
            }

            if ((int) $verification->attempts >= (int) $verification->max_attempts) {
                return ['error' => 'otp_attempts_exceeded', 'status' => 429, 'message' => 'OTP verification attempts exceeded.'];
            }

            $provider = $this->providerForVerification($verification);
            if (! $provider instanceof TenantSmsProvider) {
                return [
                    'error' => 'provider_not_configured',
                    'status' => 409,
                    'message' => 'SMS OTP provider is not configured for this tenant.',
                ];
            }

            $providerToken = $this->providerTokenForVerification($verification);
            if ($providerToken === '') {
                return ['error' => 'otp_invalid', 'status' => 422, 'message' => 'OTP is invalid or expired.'];
            }

            $result = $this->providerForName((string) $verification->provider)->verifyOtp($provider, $providerToken, $code);
            if (($result['ok'] ?? false) !== true) {
                if ($this->isProviderUnavailable($result)) {
                    return [
                        'error' => 'sms_verify_failed',
                        'status' => 503,
                        'message' => (string) ($result['message'] ?? 'SMS OTP could not be verified.'),
                    ];
                }

                return $this->recordFailedVerificationAttempt($verification, (string) ($result['message'] ?? 'OTP is incorrect.'));
            }

            $token = 'otpv_'.bin2hex(random_bytes(32));
            OtpVerification::query()->where('id', $verification->id)->update([
                'verification_token_hash' => hash('sha256', $token),
                'status' => 'verified',
                'verified_at' => now(),
                'updated_at' => now(),
            ]);

            return [
                'resource' => [
                    'otp_verification_token' => $token,
                    'purpose' => $purpose,
                    'phone_masked' => $this->maskPhone($phone),
                    'expires_in_seconds' => self::TOKEN_TTL_SECONDS,
                ],
                'status' => 200,
            ];
        });
    }

    public function providerRequiredForRegister(string $tenantId): bool
    {
        return $this->activeProviderForTenant($tenantId) instanceof TenantSmsProvider;
    }

    public function providerRequiredForLogin(string $tenantId): bool
    {
        return $this->activeProviderForTenant($tenantId) instanceof TenantSmsProvider;
    }

    public function maskedPhone(string $phone): string
    {
        return $this->maskPhone($phone);
    }

    /**
     * @return array{ok: bool, error?: string}
     */
    public function consumeVerifiedToken(string $tenantId, string $phone, string $purpose, string $token): array
    {
        $phone = $this->normalizePhone($phone) ?? '';
        $purpose = $this->normalizePurpose($purpose) ?? '';
        $tokenHash = hash('sha256', trim($token));

        if ($phone === '' || $purpose === '' || trim($token) === '') {
            return ['ok' => false, 'error' => 'otp_required'];
        }

        return DB::transaction(function () use ($tenantId, $phone, $purpose, $tokenHash): array {
            $verification = OtpVerification::query()
                ->where('tenant_id', $tenantId)
                ->where('phone_normalized', $phone)
                ->where('purpose', $purpose)
                ->where('verification_token_hash', $tokenHash)
                ->where('status', 'verified')
                ->whereNull('consumed_at')
                ->where('verified_at', '>', now()->subSeconds(self::TOKEN_TTL_SECONDS))
                ->lockForUpdate()
                ->first();

            if (! $verification instanceof OtpVerification) {
                return ['ok' => false, 'error' => 'otp_invalid'];
            }

            OtpVerification::query()->where('id', $verification->id)->update([
                'status' => 'consumed',
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);

            return ['ok' => true];
        });
    }

    public function activeProviderForTenant(string $tenantId): ?TenantSmsProvider
    {
        if (! $this->storageReady()) {
            return null;
        }

        return TenantSmsProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', 'thaibulk')
            ->where('status', 'active')
            ->first();
    }

    public function normalizePhone(mixed $value): ?string
    {
        $phone = preg_replace('/\D+/', '', (string) $value);

        if (! is_string($phone) || $phone === '') {
            return null;
        }

        if (str_starts_with($phone, '66') && strlen($phone) === 11) {
            $phone = '0'.substr($phone, 2);
        }

        return strlen($phone) >= 9 && strlen($phone) <= 10 ? $phone : null;
    }

    private function providerForTenant(string $tenantId): ?TenantSmsProvider
    {
        if (! $this->storageReady()) {
            return null;
        }

        return TenantSmsProvider::query()
            ->where('tenant_id', $tenantId)
            ->where('provider', 'thaibulk')
            ->first();
    }

    private function providerForName(string $provider): SmsOtpProviderInterface
    {
        return match ($provider) {
            'thaibulk' => $this->thaiBulk,
            default => $this->thaiBulk,
        };
    }

    private function deactivateOtherProviders(string $tenantId, ?string $exceptProviderId): void
    {
        TenantSmsProvider::query()
            ->where('tenant_id', $tenantId)
            ->when($exceptProviderId !== null && $exceptProviderId !== '', fn ($query) => $query->where('id', '!=', $exceptProviderId))
            ->update([
                'status' => 'inactive',
                'updated_at' => now(),
            ]);
    }

    /**
     * @param array<string, mixed> $metadata
     * @return array<string, mixed>
     */
    private function requestWithProvider(TenantSmsProvider $provider, string $purpose, string $phone, array $metadata): array
    {
        $result = $this->providerForName((string) $provider->provider)->requestOtp($provider, $phone);

        SmsDeliveryLog::query()->insert([
            'id' => 'sdl_'.Str::ulid()->toBase32(),
            'tenant_id' => (string) $provider->tenant_id,
            'provider_id' => (string) $provider->id,
            'provider' => (string) $provider->provider,
            'purpose' => $purpose,
            'phone_masked' => $this->maskPhone($phone),
            'status' => ($result['ok'] ?? false) ? 'sent' : 'failed',
            'http_status' => $result['status'] ?? null,
            'latency_ms' => $result['latency_ms'] ?? null,
            'provider_message_id' => $result['provider_message_id'] ?? null,
            'error_message' => $result['message'] ?? null,
            'request_json' => json_encode($metadata, JSON_THROW_ON_ERROR),
            'response_json' => isset($result['response']) ? json_encode($result['response'], JSON_THROW_ON_ERROR) : null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $result;
    }

    private function normalizePurpose(mixed $value): ?string
    {
        $purpose = trim((string) $value);

        return in_array($purpose, [self::PURPOSE_REGISTER, self::PURPOSE_LOGIN, self::PURPOSE_PASSWORD_RESET, self::PURPOSE_PIN_RESET], true)
            ? $purpose
            : null;
    }

    /**
     * @return array{error: string, status: int, message: string, details: array<string, int|string>}|null
     */
    private function rateLimitRequest(string $tenantId, string $purpose, string $phone, Request $request): ?array
    {
        $ip = trim((string) $request->ip());
        $device = hash('sha256', (string) $request->userAgent());
        $limits = [
            ['phone', $phone, self::OTP_PHONE_RATE_LIMIT],
            ['ip', $ip !== '' ? hash('sha256', $ip) : 'unknown', self::OTP_IP_RATE_LIMIT],
            ['device', $device, self::OTP_DEVICE_RATE_LIMIT],
        ];

        foreach ($limits as [$scope, $value, $limit]) {
            $key = "sms_otp:rate:{$tenantId}:{$purpose}:{$scope}:{$value}";
            Cache::add($key, 0, now()->addSeconds(self::OTP_RATE_WINDOW_SECONDS));
            $count = (int) Cache::increment($key);

            if ($count > $limit) {
                return [
                    'error' => 'otp_rate_limited',
                    'status' => 429,
                    'message' => 'Too many OTP requests. Please try again later.',
                    'details' => [
                        'scope' => (string) $scope,
                        'retry_after_seconds' => self::OTP_RATE_WINDOW_SECONDS,
                    ],
                ];
            }
        }

        return null;
    }

    private function providerForVerification(OtpVerification $verification): ?TenantSmsProvider
    {
        $providerId = trim((string) $verification->provider_id);
        $query = TenantSmsProvider::query()
            ->where('tenant_id', (string) $verification->tenant_id)
            ->where('provider', (string) $verification->provider);

        if ($providerId !== '') {
            $query->where('id', $providerId);
        }

        return $query->first();
    }

    private function providerTokenForVerification(OtpVerification $verification): string
    {
        $metadata = is_array($verification->metadata_json) ? $verification->metadata_json : [];
        $encrypted = trim((string) ($metadata['provider_token_encrypted'] ?? ''));

        if ($encrypted === '') {
            return '';
        }

        try {
            return trim(Crypt::decryptString($encrypted));
        } catch (\Throwable) {
            return '';
        }
    }

    /**
     * @param array<string, mixed> $metadata
     * @param array<string, mixed> $result
     * @return array<string, mixed>
     */
    private function providerRequestMetadata(array $metadata, array $result): array
    {
        $providerToken = trim((string) ($result['provider_token'] ?? ''));

        if ($providerToken !== '') {
            $metadata['provider_token_encrypted'] = Crypt::encryptString($providerToken);
        }

        $providerRefno = trim((string) ($result['provider_refno'] ?? ''));
        if ($providerRefno !== '') {
            $metadata['provider_refno'] = $providerRefno;
        }

        return $metadata;
    }

    /**
     * @param array<string, mixed> $result
     */
    private function isProviderUnavailable(array $result): bool
    {
        $status = $result['status'] ?? null;

        return $status === null || in_array((int) $status, [401, 403], true) || (int) $status >= 500;
    }

    /**
     * @return array{error: string, status: int, message: string}
     */
    private function recordFailedVerificationAttempt(OtpVerification $verification, string $message): array
    {
        $attempts = ((int) $verification->attempts) + 1;
        OtpVerification::query()->where('id', $verification->id)->update([
            'attempts' => $attempts,
            'status' => $attempts >= (int) $verification->max_attempts ? 'locked' : 'pending',
            'updated_at' => now(),
        ]);

        return ['error' => 'otp_invalid', 'status' => 422, 'message' => $message !== '' ? $message : 'OTP is incorrect.'];
    }

    private function maskPhone(string $phone): string
    {
        $digits = preg_replace('/\D+/', '', $phone) ?: '';
        if (strlen($digits) <= 4) {
            return $digits;
        }

        return substr($digits, 0, 3).'xxxx'.substr($digits, -3);
    }

    private function connectionSecret(?TenantSmsProvider $provider, array $payload, string $payloadKey, string $encryptedField): string
    {
        $value = trim((string) ($payload[$payloadKey] ?? ''));
        if ($value !== '') {
            return $value;
        }

        $encrypted = trim((string) ($provider?->{$encryptedField} ?? ''));
        if ($encrypted === '') {
            return '';
        }

        try {
            return Crypt::decryptString($encrypted);
        } catch (\Throwable) {
            return '';
        }
    }

    private function providerResource(?TenantSmsProvider $provider, string $tenantId): array
    {
        return [
            'id' => $provider?->id,
            'tenant_id' => $tenantId,
            'provider' => $provider?->provider ?? 'thaibulk',
            'provider_label' => $this->providerLabel($provider?->provider ?? 'thaibulk'),
            'status' => $provider?->status ?? 'inactive',
            'sender_name' => $provider?->sender_name,
            'api_key_configured' => $provider !== null && $provider->api_key_encrypted !== null,
            'api_secret_configured' => $provider !== null && $provider->api_secret_encrypted !== null,
            'api_key_masked' => $this->maskedSecret($provider?->api_key_encrypted),
            'verified_at' => $provider?->verified_at?->toIso8601String(),
            'last_tested_at' => $provider?->last_tested_at?->toIso8601String(),
            'last_test_status' => $provider?->last_test_status,
            'last_test_message' => $provider?->last_test_message,
            'configured' => $provider !== null && $provider->api_key_encrypted !== null && $provider->api_secret_encrypted !== null,
            'ready' => $provider !== null && $provider->status === 'active' && $provider->api_key_encrypted !== null && $provider->api_secret_encrypted !== null,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function providerRows(string $tenantId): array
    {
        if (! $this->storageReady()) {
            return [];
        }

        return TenantSmsProvider::query()
            ->where('tenant_id', $tenantId)
            ->orderByRaw("case when status = 'active' then 0 else 1 end")
            ->orderBy('provider')
            ->orderByDesc('updated_at')
            ->get()
            ->map(fn (TenantSmsProvider $provider): array => $this->providerResource($provider, $tenantId))
            ->all();
    }

    private function providerLabel(string $provider): string
    {
        return match ($provider) {
            'thaibulk' => 'ThaiBulkSMS',
            default => Str::headline($provider),
        };
    }

    private function maskedSecret(mixed $encrypted): ?string
    {
        $value = trim((string) $encrypted);
        if ($value === '') {
            return null;
        }

        try {
            $plain = Crypt::decryptString($value);
        } catch (\Throwable) {
            return '••••';
        }

        return strlen($plain) <= 8 ? '••••' : substr($plain, 0, 4).'••••'.substr($plain, -4);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function deliveryLogs(string $tenantId, array $query): array
    {
        if (! $this->storageReady()) {
            return [];
        }

        return SmsDeliveryLog::query()
            ->where('tenant_id', $tenantId)
            ->orderByDesc('created_at')
            ->limit(max(1, min(100, (int) ($query['limit'] ?? 50))))
            ->get()
            ->map(fn (SmsDeliveryLog $log): array => [
                'id' => (string) $log->id,
                'provider' => (string) $log->provider,
                'purpose' => (string) $log->purpose,
                'phone_masked' => $log->phone_masked,
                'status' => (string) $log->status,
                'http_status' => $log->http_status,
                'latency_ms' => $log->latency_ms,
                'error_message' => $log->error_message,
                'created_at' => $log->created_at?->toIso8601String(),
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function otpLogs(string $tenantId, array $query): array
    {
        if (! $this->storageReady()) {
            return [];
        }

        return OtpVerification::query()
            ->where('tenant_id', $tenantId)
            ->orderByDesc('created_at')
            ->limit(max(1, min(100, (int) ($query['limit'] ?? 50))))
            ->get()
            ->map(fn (OtpVerification $otp): array => [
                'id' => (string) $otp->id,
                'purpose' => (string) $otp->purpose,
                'phone_masked' => $this->maskPhone((string) $otp->phone),
                'status' => (string) $otp->status,
                'attempts' => (int) $otp->attempts,
                'expires_at' => $otp->expires_at?->toIso8601String(),
                'verified_at' => $otp->verified_at?->toIso8601String(),
                'consumed_at' => $otp->consumed_at?->toIso8601String(),
                'created_at' => $otp->created_at?->toIso8601String(),
            ])
            ->all();
    }

    /**
     * @return array{error: string, status: int, message: string, details: array<string, string>}
     */
    private function storageUnavailable(): array
    {
        return [
            'error' => 'storage_unavailable',
            'status' => 503,
            'message' => 'SMS OTP storage is not ready. Please run database migrations.',
            'details' => [
                'resource' => 'tenant_sms_providers',
                'reason' => 'sms_otp_storage_not_migrated',
            ],
        ];
    }
}
