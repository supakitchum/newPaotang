<?php

namespace App\Modules\Auth\Services;

use App\Models\CustomerBiometricChallenge;
use App\Models\CustomerBiometricDevice;
use App\Models\CustomerPinAssertion;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CustomerBiometricAuthService
{
    private const CHALLENGE_TTL_SECONDS = 120;
    private const ASSERTION_TTL_SECONDS = 180;

    public function __construct(
        private readonly CustomerAuthService $customerAuth,
        private readonly CustomerNotificationDomainEventService $customerNotificationEvents,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function devices(CustomerSessionContext $context): array
    {
        $devices = CustomerBiometricDevice::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_id', $context->customerId())
            ->orderByDesc('updated_at')
            ->get()
            ->map(fn (CustomerBiometricDevice $device): array => $this->deviceResource($device))
            ->all();

        return ['data' => $devices];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null, errors?: array<string, array<int, string>>}
     */
    public function registerDevice(CustomerSessionContext $context, array $payload): array
    {
        $pinResult = $this->customerAuth->verifyPin($context, ['pin' => trim((string) ($payload['pin'] ?? ''))]);

        if (($pinResult['error'] ?? null) !== null) {
            return [
                'error' => $pinResult['error'],
                'retry_after_seconds' => $pinResult['retry_after_seconds'] ?? null,
            ];
        }

        $errors = $this->devicePayloadErrors($payload);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $deviceId = trim((string) $payload['device_id']);
        $platform = $this->normalizePlatform($payload['platform'] ?? '');
        $algorithm = $this->normalizeAlgorithm($payload['algorithm'] ?? 'ES256');
        $publicKey = trim((string) $payload['public_key_pem']);
        $now = now();

        $device = CustomerBiometricDevice::query()->updateOrCreate(
            [
                'tenant_id' => $context->tenantId(),
                'customer_id' => $context->customerId(),
                'device_id' => $deviceId,
            ],
            [
                'id' => (string) (CustomerBiometricDevice::query()
                    ->where('tenant_id', $context->tenantId())
                    ->where('customer_id', $context->customerId())
                    ->where('device_id', $deviceId)
                    ->value('id') ?: 'cbd_'.Str::ulid()->toBase32()),
                'platform' => $platform,
                'device_name' => trim((string) ($payload['device_name'] ?? '')) ?: null,
                'algorithm' => $algorithm,
                'public_key_pem' => $publicKey,
                'status' => 'active',
                'registered_at' => $now,
                'revoked_at' => null,
                'metadata_json' => [
                    'app_version' => $this->nullableString($payload['app_version'] ?? null),
                    'model' => $this->nullableString($payload['model'] ?? null),
                ],
                'updated_at' => $now,
            ],
        );

        $this->audit('biometric.device.registered', $context, $device->id, [
            'platform' => $platform,
            'algorithm' => $algorithm,
        ]);
        $this->customerNotificationEvents->biometricDeviceChanged(
            $context->tenantId(),
            $context->customerId(),
            (string) $device->id,
            'active',
            $now->toISOString(),
        );

        return ['resource' => ['data' => $this->deviceResource($device->refresh())]];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function revokeDevice(CustomerSessionContext $context, string $id): array
    {
        $now = now();
        $updated = CustomerBiometricDevice::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_id', $context->customerId())
            ->where('id', $id)
            ->where('status', 'active')
            ->update([
                'status' => 'revoked',
                'revoked_at' => $now,
                'updated_at' => $now,
            ]);

        if ($updated < 1) {
            return ['error' => 'not_found'];
        }

        $this->audit('biometric.device.revoked', $context, $id);
        $this->customerNotificationEvents->biometricDeviceChanged(
            $context->tenantId(),
            $context->customerId(),
            $id,
            'revoked',
            $now->toISOString(),
        );

        return ['resource' => ['data' => ['revoked' => true]]];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function challenge(CustomerSessionContext $context, array $payload): array
    {
        $deviceId = trim((string) ($payload['device_id'] ?? ''));
        $purpose = $this->normalizePurpose($payload['purpose'] ?? 'pin_unlock');

        if ($deviceId === '') {
            return ['error' => 'validation_failed', 'errors' => ['device_id' => ['The device_id field is required.']]];
        }

        $device = CustomerBiometricDevice::query()
            ->where('tenant_id', $context->tenantId())
            ->where('customer_id', $context->customerId())
            ->where('device_id', $deviceId)
            ->where('status', 'active')
            ->first();

        if (! $device instanceof CustomerBiometricDevice) {
            return ['error' => 'not_found'];
        }

        $challenge = implode('.', [
            'npa_bio_v1',
            $context->tenantId(),
            $context->customerId(),
            (string) $device->id,
            $purpose,
            Str::random(48),
        ]);
        $record = CustomerBiometricChallenge::query()->create([
            'id' => 'cbc_'.Str::ulid()->toBase32(),
            'tenant_id' => $context->tenantId(),
            'customer_id' => $context->customerId(),
            'biometric_device_id' => (string) $device->id,
            'purpose' => $purpose,
            'challenge' => $challenge,
            'status' => 'pending',
            'expires_at' => now()->addSeconds(self::CHALLENGE_TTL_SECONDS),
            'metadata_json' => [
                'platform' => $device->platform,
                'algorithm' => $device->algorithm,
            ],
        ]);

        return [
            'resource' => [
                'data' => [
                    'challenge_id' => (string) $record->id,
                    'challenge' => $challenge,
                    'algorithm' => (string) $device->algorithm,
                    'expires_in' => self::CHALLENGE_TTL_SECONDS,
                ],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function verify(CustomerSessionContext $context, array $payload): array
    {
        $challengeId = trim((string) ($payload['challenge_id'] ?? ''));
        $signature = trim((string) ($payload['signature'] ?? ''));
        $signedPayload = (string) ($payload['signed_payload'] ?? '');

        if ($challengeId === '' || $signature === '' || $signedPayload === '') {
            return [
                'error' => 'validation_failed',
                'errors' => [
                    'challenge_id' => $challengeId === '' ? ['The challenge_id field is required.'] : [],
                    'signature' => $signature === '' ? ['The signature field is required.'] : [],
                    'signed_payload' => $signedPayload === '' ? ['The signed_payload field is required.'] : [],
                ],
            ];
        }

        return DB::transaction(function () use ($context, $challengeId, $signature, $signedPayload): array {
            $challenge = CustomerBiometricChallenge::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->where('id', $challengeId)
                ->where('status', 'pending')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if (! $challenge instanceof CustomerBiometricChallenge) {
                return ['error' => 'biometric_challenge_invalid'];
            }

            $device = CustomerBiometricDevice::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->where('id', $challenge->biometric_device_id)
                ->where('status', 'active')
                ->first();

            if (! $device instanceof CustomerBiometricDevice || ! hash_equals((string) $challenge->challenge, $signedPayload)) {
                return ['error' => 'biometric_challenge_invalid'];
            }

            if (! $this->verifySignature($device, $signedPayload, $signature)) {
                $this->audit('biometric.verify.failed', $context, (string) $device->id);

                return ['error' => 'biometric_signature_invalid'];
            }

            CustomerBiometricChallenge::query()->where('id', $challenge->id)->update([
                'status' => 'verified',
                'verified_at' => now(),
                'updated_at' => now(),
            ]);
            CustomerBiometricDevice::query()->where('id', $device->id)->update([
                'last_used_at' => now(),
                'updated_at' => now(),
            ]);

            $token = 'npa_pin_assert_'.Str::random(72);
            CustomerPinAssertion::query()->create([
                'id' => 'cpa_'.Str::ulid()->toBase32(),
                'tenant_id' => $context->tenantId(),
                'customer_id' => $context->customerId(),
                'source_type' => 'biometric',
                'source_id' => (string) $device->id,
                'token_hash' => hash('sha256', $token),
                'purpose' => (string) $challenge->purpose,
                'status' => 'active',
                'expires_at' => now()->addSeconds(self::ASSERTION_TTL_SECONDS),
                'metadata_json' => [
                    'platform' => $device->platform,
                    'device_id' => $device->device_id,
                ],
            ]);

            $this->audit('biometric.verify.succeeded', $context, (string) $device->id);

            return [
                'resource' => [
                    'data' => [
                        'pin_assertion_token' => $token,
                        'expires_in' => self::ASSERTION_TTL_SECONDS,
                        'purpose' => (string) $challenge->purpose,
                    ],
                ],
            ];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function logSecurityEvent(CustomerSessionContext $context, array $payload): array
    {
        $event = trim((string) ($payload['event'] ?? 'screen_security_violation'));
        $this->audit($event, $context, null, [
            'platform' => $this->nullableString($payload['platform'] ?? null),
            'route' => $this->nullableString($payload['route'] ?? null),
            'reason' => $this->nullableString($payload['reason'] ?? null),
        ]);

        return ['resource' => ['data' => ['logged' => true]]];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string, retry_after_seconds?: int|null}
     */
    public function verifyPinOrAssertion(CustomerSessionContext $context, array $payload, bool $markSessionVerified = false): array
    {
        $assertion = trim((string) ($payload['pin_assertion_token'] ?? ''));

        if ($assertion !== '') {
            return $this->consumePinAssertion($context, $assertion, $markSessionVerified);
        }

        return $this->customerAuth->verifyPin($context, ['pin' => trim((string) ($payload['pin'] ?? ''))]);
    }

    private function consumePinAssertion(CustomerSessionContext $context, string $token, bool $markSessionVerified): array
    {
        return DB::transaction(function () use ($context, $token, $markSessionVerified): array {
            $assertion = CustomerPinAssertion::query()
                ->where('tenant_id', $context->tenantId())
                ->where('customer_id', $context->customerId())
                ->where('token_hash', hash('sha256', $token))
                ->where('status', 'active')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if (! $assertion instanceof CustomerPinAssertion) {
                return ['error' => 'pin_assertion_invalid'];
            }

            if ($markSessionVerified
                && ! $this->customerAuth->markSessionPinVerifiedForAssertion((string) $context->session['id'])) {
                return ['error' => 'customer_session_replaced'];
            }

            CustomerPinAssertion::query()->where('id', $assertion->id)->update([
                'status' => 'consumed',
                'consumed_at' => now(),
                'updated_at' => now(),
            ]);

            return [
                'resource' => [
                    'pin_verified' => true,
                    'pin_assertion_consumed' => true,
                ],
            ];
        });
    }

    /**
     * @return array<string, mixed>
     */
    private function deviceResource(CustomerBiometricDevice $device): array
    {
        return [
            'id' => (string) $device->id,
            'device_id' => (string) $device->device_id,
            'platform' => (string) $device->platform,
            'device_name' => $device->device_name,
            'algorithm' => (string) $device->algorithm,
            'status' => (string) $device->status,
            'registered_at' => $device->registered_at?->toIso8601String(),
            'last_used_at' => $device->last_used_at?->toIso8601String(),
            'revoked_at' => $device->revoked_at?->toIso8601String(),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function devicePayloadErrors(array $payload): array
    {
        $errors = [];

        if (trim((string) ($payload['device_id'] ?? '')) === '') {
            $errors['device_id'][] = 'The device_id field is required.';
        }

        if (! in_array($this->normalizePlatform($payload['platform'] ?? ''), ['ios', 'android'], true)) {
            $errors['platform'][] = 'The platform field must be ios or android.';
        }

        if (! in_array($this->normalizeAlgorithm($payload['algorithm'] ?? 'ES256'), ['ES256', 'RS256'], true)) {
            $errors['algorithm'][] = 'The algorithm field must be ES256 or RS256.';
        }

        $publicKey = trim((string) ($payload['public_key_pem'] ?? ''));
        if ($publicKey === '' || openssl_pkey_get_public($publicKey) === false) {
            $errors['public_key_pem'][] = 'The public_key_pem field must contain a valid PEM public key.';
        }

        return $errors;
    }

    private function verifySignature(CustomerBiometricDevice $device, string $payload, string $signature): bool
    {
        $decoded = base64_decode($signature, true);

        if ($decoded === false) {
            return false;
        }

        $publicKey = openssl_pkey_get_public((string) $device->public_key_pem);

        if ($publicKey === false) {
            return false;
        }

        return openssl_verify($payload, $decoded, $publicKey, OPENSSL_ALGO_SHA256) === 1;
    }

    private function normalizePlatform(mixed $value): string
    {
        return match (strtolower(trim((string) $value))) {
            'ios', 'iphone', 'ipad' => 'ios',
            'android' => 'android',
            default => '',
        };
    }

    private function normalizeAlgorithm(mixed $value): string
    {
        return strtoupper(trim((string) $value ?: 'ES256'));
    }

    private function normalizePurpose(mixed $value): string
    {
        $purpose = strtolower(trim((string) $value));

        return in_array($purpose, ['pin_unlock', 'reward_claim', 'activity_claim', 'profile_update', 'affiliate'], true)
            ? $purpose
            : 'pin_unlock';
    }

    private function nullableString(mixed $value): ?string
    {
        $string = trim((string) $value);

        return $string === '' ? null : $string;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(string $event, CustomerSessionContext $context, ?string $targetId = null, array $payload = []): void
    {
        // Customer security events are written into the shared audit log shape with a customer actor.
        DB::table('audit_logs')->insert([
            'id' => 'aud_'.Str::ulid()->toBase32(),
            'actor_type' => 'customer',
            'actor_id' => $context->customerId(),
            'scope_type' => 'tenant',
            'tenant_id' => $context->tenantId(),
            'partner_id' => null,
            'action' => $event,
            'target_type' => 'customer_biometric_device',
            'target_id' => $targetId,
            'request_id' => null,
            'ip_address' => null,
            'user_agent' => null,
            'payload_redacted_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
