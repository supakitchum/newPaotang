<?php

namespace App\Modules\Auth\Services;

use App\Models\Customer;
use App\Models\CustomerPasskey;
use App\Models\CustomerPasskeyChallenge;
use App\Modules\Auth\Passkeys\CustomerPasskeyConfiguration;
use App\Modules\Auth\Passkeys\GenerateCustomerPasskeyRegistrationOptions;
use App\Modules\Auth\Passkeys\VerifyCustomerPasskey;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Auth\CustomerSuspensionService;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;
use Laravel\Passkeys\Actions\GenerateVerificationOptions;
use Laravel\Passkeys\Actions\StorePasskey;
use Laravel\Passkeys\Exceptions\InvalidPasskeyException;
use Laravel\Passkeys\Support\WebAuthn;
use Throwable;
use Webauthn\PublicKeyCredential;
use Webauthn\PublicKeyCredentialCreationOptions;
use Webauthn\PublicKeyCredentialRequestOptions;

class CustomerPasskeyService
{
    public function __construct(
        private readonly CustomerPasskeyConfiguration $configuration,
        private readonly CustomerAuthService $customerAuth,
        private readonly CustomerSuspensionService $customerSuspensions,
        private readonly IdempotencyService $idempotency,
        private readonly CustomerNotificationDomainEventService $customerNotificationEvents,
    ) {
    }

    /**
     * @param array<string, mixed> $tenant
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function loginOptions(array $tenant, Request $request): array
    {
        $config = $this->configuration->resolve($tenant);
        if (! $config['enabled']) {
            return ['error' => 'passkey_not_available'];
        }

        $this->configuration->apply($config);
        $options = app(GenerateVerificationOptions::class)();
        $challenge = $this->storeChallenge(
            $config,
            'authentication',
            $options,
            null,
            $request,
        );

        return [
            'resource' => [
                'challenge_id' => (string) $challenge->id,
                'options' => WebAuthn::toBrowserArray($options),
                'rp_id' => $config['rp_id'],
                'expires_in' => $config['challenge_ttl_seconds'],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>, errors?: array<string, array<int, string>>}
     */
    public function login(array $tenant, array $payload, Request $request): array
    {
        $config = $this->configuration->resolve($tenant);
        if (! $config['enabled']) {
            return ['error' => 'passkey_not_available'];
        }

        $errors = $this->verificationPayloadErrors($payload);
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $challengeId = trim((string) $payload['challenge_id']);
        $idempotencyKey = trim((string) $request->header('Idempotency-Key'));
        $normalized = [
            'challenge_id' => $challengeId,
            'credential_id' => trim((string) data_get($payload, 'credential.id', '')),
        ];
        $replay = $this->idempotency->replayOrConflict(
            $config['tenant_id'],
            'customer_passkey_login',
            $challengeId,
            'customer.auth.passkeys.login',
            $idempotencyKey,
            $normalized,
        );

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }
        if (is_string($replay)) {
            return ['error' => $replay];
        }

        try {
            return DB::transaction(function () use (
                $config,
                $payload,
                $request,
                $challengeId,
                $idempotencyKey,
                $normalized,
            ): array {
                $challenge = $this->pendingChallenge(
                    $config['tenant_id'],
                    $challengeId,
                    'authentication',
                    null,
                );
                if (! $challenge instanceof CustomerPasskeyChallenge) {
                    return ['error' => 'passkey_challenge_invalid'];
                }

                $this->applyChallengeConfiguration($challenge, $config['timeout']);
                $credential = $this->credential($payload['credential']);
                $options = $this->requestOptions($challenge);
                $passkey = (new VerifyCustomerPasskey($config['tenant_id']))(
                    $credential,
                    $options,
                );
                $customer = $passkey->user;

                if (! $customer instanceof Customer
                    || (string) $customer->tenant_id !== $config['tenant_id']) {
                    return ['error' => 'authentication_required'];
                }

                if ($this->customerSuspensions->isSuspended($customer)) {
                    return [
                        'error' => 'customer_suspended',
                        'details' => $this->customerSuspensions->payload($customer),
                    ];
                }
                if ((string) $customer->status !== 'active') {
                    return ['error' => 'authentication_required'];
                }

                $now = now();
                CustomerPasskeyChallenge::query()->whereKey($challenge->id)->update([
                    'status' => 'consumed',
                    'consumed_at' => $now,
                    'updated_at' => $now,
                ]);
                Customer::query()->whereKey($customer->id)->update([
                    'last_login_at' => $now,
                    'updated_at' => $now,
                ]);
                $this->customerAuth->ensurePrimaryWallet(
                    $config['tenant_id'],
                    (string) $customer->id,
                );

                $response = $this->customerAuth->issueSession(
                    $config['tenant_id'],
                    (string) $customer->id,
                    activationRequired: true,
                );
                $response['passkey_login'] = true;

                $this->idempotency->storeResponse(
                    $config['tenant_id'],
                    'customer_passkey_login',
                    $challengeId,
                    'customer.auth.passkeys.login',
                    $idempotencyKey,
                    $normalized,
                    200,
                    $response,
                );
                $this->audit(
                    'passkey.login.succeeded',
                    $config['tenant_id'],
                    (string) $customer->id,
                    (string) $passkey->id,
                    $request,
                );

                return ['resource' => $response];
            });
        } catch (InvalidPasskeyException $exception) {
            report($exception);

            return ['error' => 'passkey_verification_failed'];
        } catch (Throwable $exception) {
            report($exception);

            return ['error' => 'passkey_verification_failed'];
        }
    }

    /**
     * @param array<string, mixed> $tenant
     * @return array<string, mixed>
     */
    public function index(array $tenant, CustomerSessionContext $context): array
    {
        $config = $this->configuration->resolve($tenant);
        $passkeys = CustomerPasskey::query()
            ->where('tenant_id', $context->tenantId())
            ->where('user_id', $context->customerId())
            ->orderByRaw("CASE WHEN status = 'active' THEN 0 ELSE 1 END")
            ->orderByDesc('updated_at')
            ->get()
            ->map(fn (CustomerPasskey $passkey): array => $this->passkeyResource($passkey))
            ->all();
        $activeCount = collect($passkeys)
            ->where('status', 'active')
            ->count();

        return [
            'data' => $passkeys,
            'enabled' => $config['enabled'],
            'rp_id' => $config['rp_id'],
            'max_passkeys' => $config['max_per_customer'],
            'can_register' => $config['enabled']
                && $context->pinVerified()
                && $activeCount < $config['max_per_customer'],
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function registrationOptions(
        array $tenant,
        CustomerSessionContext $context,
        Request $request,
    ): array {
        $config = $this->configuration->resolve($tenant);
        if (! $config['enabled']) {
            return ['error' => 'passkey_not_available'];
        }
        if (! $context->pinVerified()) {
            return ['error' => 'pin_required'];
        }

        $customer = Customer::query()
            ->where('tenant_id', $context->tenantId())
            ->whereKey($context->customerId())
            ->first();
        if (! $customer instanceof Customer) {
            return ['error' => 'authentication_required'];
        }

        $activeCount = CustomerPasskey::query()
            ->where('tenant_id', $context->tenantId())
            ->where('user_id', $context->customerId())
            ->where('status', 'active')
            ->count();
        if ($activeCount >= $config['max_per_customer']) {
            return ['error' => 'passkey_limit_reached'];
        }

        $this->configuration->apply($config);
        $options = (new GenerateCustomerPasskeyRegistrationOptions(
            $config['rp_id'],
            $config['rp_name'],
        ))($customer);
        $challenge = $this->storeChallenge(
            $config,
            'registration',
            $options,
            $context->customerId(),
            $request,
        );

        return [
            'resource' => [
                'challenge_id' => (string) $challenge->id,
                'options' => WebAuthn::toBrowserArray($options),
                'rp_id' => $config['rp_id'],
                'expires_in' => $config['challenge_ttl_seconds'],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $tenant
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function register(
        array $tenant,
        CustomerSessionContext $context,
        array $payload,
        Request $request,
    ): array {
        if (! $context->pinVerified()) {
            return ['error' => 'pin_required'];
        }

        $config = $this->configuration->resolve($tenant);
        if (! $config['enabled']) {
            return ['error' => 'passkey_not_available'];
        }

        $errors = $this->registrationPayloadErrors($payload);
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $challengeId = trim((string) $payload['challenge_id']);
        $idempotencyKey = trim((string) $request->header('Idempotency-Key'));
        $name = mb_substr(trim((string) ($payload['name'] ?? 'Passkey')), 0, 120);
        $normalized = [
            'challenge_id' => $challengeId,
            'credential_id' => trim((string) data_get($payload, 'credential.id', '')),
            'name' => $name,
        ];
        $replay = $this->idempotency->replayOrConflict(
            $context->tenantId(),
            'customer',
            $context->customerId(),
            'customer.auth.passkeys.register',
            $idempotencyKey,
            $normalized,
        );

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }
        if (is_string($replay)) {
            return ['error' => $replay];
        }

        try {
            return DB::transaction(function () use (
                $config,
                $context,
                $payload,
                $request,
                $challengeId,
                $idempotencyKey,
                $name,
                $normalized,
            ): array {
                $challenge = $this->pendingChallenge(
                    $context->tenantId(),
                    $challengeId,
                    'registration',
                    $context->customerId(),
                );
                if (! $challenge instanceof CustomerPasskeyChallenge) {
                    return ['error' => 'passkey_challenge_invalid'];
                }

                $customer = Customer::query()
                    ->where('tenant_id', $context->tenantId())
                    ->whereKey($context->customerId())
                    ->lockForUpdate()
                    ->first();
                if (! $customer instanceof Customer) {
                    return ['error' => 'authentication_required'];
                }

                $activeCount = CustomerPasskey::query()
                    ->where('tenant_id', $context->tenantId())
                    ->where('user_id', $context->customerId())
                    ->where('status', 'active')
                    ->count();
                if ($activeCount >= $config['max_per_customer']) {
                    return ['error' => 'passkey_limit_reached'];
                }

                $this->applyChallengeConfiguration($challenge, $config['timeout']);
                $credential = $this->credential($payload['credential']);
                $options = $this->creationOptions($challenge);
                $passkey = app(StorePasskey::class)(
                    $customer,
                    $name === '' ? 'Passkey' : $name,
                    $credential,
                    $options,
                );
                $now = now();
                CustomerPasskeyChallenge::query()->whereKey($challenge->id)->update([
                    'status' => 'consumed',
                    'consumed_at' => $now,
                    'updated_at' => $now,
                ]);
                $resource = ['data' => $this->passkeyResource($passkey)];

                $this->idempotency->storeResponse(
                    $context->tenantId(),
                    'customer',
                    $context->customerId(),
                    'customer.auth.passkeys.register',
                    $idempotencyKey,
                    $normalized,
                    201,
                    $resource,
                );
                $this->audit(
                    'passkey.registered',
                    $context->tenantId(),
                    $context->customerId(),
                    (string) $passkey->id,
                    $request,
                );
                DB::afterCommit(fn () => $this->customerNotificationEvents->passkeyChanged(
                    $context->tenantId(),
                    $context->customerId(),
                    (string) $passkey->id,
                    'active',
                    $now->toISOString(),
                ));

                return ['resource' => $resource, 'status' => 201];
            });
        } catch (InvalidPasskeyException $exception) {
            report($exception);

            return ['error' => 'passkey_verification_failed'];
        } catch (Throwable $exception) {
            report($exception);

            return ['error' => 'passkey_verification_failed'];
        }
    }

    /**
     * @param array<string, mixed> $tenant
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function revoke(
        array $tenant,
        CustomerSessionContext $context,
        string $passkeyId,
        Request $request,
    ): array {
        if (! $context->pinVerified()) {
            return ['error' => 'pin_required'];
        }

        $config = $this->configuration->resolve($tenant);
        if (! $config['enabled']) {
            return ['error' => 'passkey_not_available'];
        }

        $passkey = CustomerPasskey::query()
            ->where('tenant_id', $context->tenantId())
            ->where('user_id', $context->customerId())
            ->whereKey($passkeyId)
            ->first();
        if (! $passkey instanceof CustomerPasskey) {
            return ['error' => 'not_found'];
        }
        if ((string) $passkey->status === 'revoked') {
            return ['resource' => ['data' => ['revoked' => true, 'id' => $passkeyId]]];
        }

        $now = now();
        $passkey->forceFill([
            'status' => 'revoked',
            'revoked_at' => $now,
            'updated_at' => $now,
        ])->save();
        $this->audit(
            'passkey.revoked',
            $context->tenantId(),
            $context->customerId(),
            $passkeyId,
            $request,
        );
        $this->customerNotificationEvents->passkeyChanged(
            $context->tenantId(),
            $context->customerId(),
            $passkeyId,
            'revoked',
            $now->toISOString(),
        );

        return ['resource' => ['data' => ['revoked' => true, 'id' => $passkeyId]]];
    }

    /**
     * @param array{
     *   tenant_id: string,
     *   rp_id: string,
     *   allowed_origins: list<string>,
     *   timeout: int,
     *   challenge_ttl_seconds: int
     * } $config
     */
    private function storeChallenge(
        array $config,
        string $ceremony,
        PublicKeyCredentialRequestOptions|PublicKeyCredentialCreationOptions $options,
        ?string $customerId,
        Request $request,
    ): CustomerPasskeyChallenge {
        return CustomerPasskeyChallenge::query()->create([
            'id' => 'cpc_'.Str::ulid()->toBase32(),
            'tenant_id' => $config['tenant_id'],
            'customer_id' => $customerId,
            'ceremony' => $ceremony,
            'rp_id' => $config['rp_id'],
            'allowed_origins_json' => $config['allowed_origins'],
            'options_json' => json_decode(
                WebAuthn::toJson($options),
                true,
                flags: JSON_THROW_ON_ERROR,
            ),
            'status' => 'pending',
            'expires_at' => now()->addSeconds($config['challenge_ttl_seconds']),
            'metadata_json' => [
                'ip_hash' => hash('sha256', (string) $request->ip()),
                'user_agent_hash' => hash('sha256', (string) $request->userAgent()),
            ],
        ]);
    }

    private function pendingChallenge(
        string $tenantId,
        string $challengeId,
        string $ceremony,
        ?string $customerId,
    ): ?CustomerPasskeyChallenge {
        $query = CustomerPasskeyChallenge::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($challengeId)
            ->where('ceremony', $ceremony)
            ->where('status', 'pending')
            ->whereNull('consumed_at')
            ->where('expires_at', '>', now());

        if ($customerId === null) {
            $query->whereNull('customer_id');
        } else {
            $query->where('customer_id', $customerId);
        }

        return $query->lockForUpdate()->first();
    }

    private function applyChallengeConfiguration(
        CustomerPasskeyChallenge $challenge,
        int $timeout,
    ): void {
        $origins = array_values(array_filter(array_map(
            static fn (mixed $value): string => trim((string) $value),
            is_array($challenge->allowed_origins_json)
                ? $challenge->allowed_origins_json
                : [],
        )));
        $this->configuration->apply([
            'rp_id' => (string) $challenge->rp_id,
            'allowed_origins' => $origins,
            'timeout' => $timeout,
        ]);
    }

    private function credential(mixed $payload): PublicKeyCredential
    {
        return WebAuthn::fromJson(
            json_encode($payload, JSON_THROW_ON_ERROR),
            PublicKeyCredential::class,
        );
    }

    private function requestOptions(
        CustomerPasskeyChallenge $challenge,
    ): PublicKeyCredentialRequestOptions {
        return WebAuthn::fromJson(
            json_encode($challenge->options_json, JSON_THROW_ON_ERROR),
            PublicKeyCredentialRequestOptions::class,
        );
    }

    private function creationOptions(
        CustomerPasskeyChallenge $challenge,
    ): PublicKeyCredentialCreationOptions {
        return WebAuthn::fromJson(
            json_encode($challenge->options_json, JSON_THROW_ON_ERROR),
            PublicKeyCredentialCreationOptions::class,
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function verificationPayloadErrors(array $payload): array
    {
        return $this->credentialPayloadErrors($payload);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function registrationPayloadErrors(array $payload): array
    {
        $errors = $this->credentialPayloadErrors($payload);
        $name = trim((string) ($payload['name'] ?? ''));
        if (mb_strlen($name) > 120) {
            $errors['name'][] = 'The name field must not be greater than 120 characters.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function credentialPayloadErrors(array $payload): array
    {
        $errors = [];
        if (trim((string) ($payload['challenge_id'] ?? '')) === '') {
            $errors['challenge_id'][] = 'The challenge_id field is required.';
        }

        $credential = $payload['credential'] ?? null;
        if (! is_array($credential)) {
            $errors['credential'][] = 'The credential field is required.';

            return $errors;
        }
        if (trim((string) ($credential['id'] ?? '')) === '') {
            $errors['credential.id'][] = 'The credential id field is required.';
        }
        if (trim((string) ($credential['rawId'] ?? '')) === '') {
            $errors['credential.rawId'][] = 'The credential rawId field is required.';
        }
        if (($credential['type'] ?? null) !== 'public-key') {
            $errors['credential.type'][] = 'The credential type must be public-key.';
        }
        if (! is_array($credential['response'] ?? null)) {
            $errors['credential.response'][] = 'The credential response field is required.';
        }

        return $errors;
    }

    /**
     * @return array<string, mixed>
     */
    private function passkeyResource(CustomerPasskey $passkey): array
    {
        return [
            'id' => (string) $passkey->id,
            'name' => (string) $passkey->name,
            'authenticator' => $passkey->authenticator,
            'status' => (string) $passkey->status,
            'registered_at' => $passkey->created_at?->toIso8601String(),
            'last_used_at' => $passkey->last_used_at?->toIso8601String(),
            'revoked_at' => $passkey->revoked_at?->toIso8601String(),
        ];
    }

    private function audit(
        string $action,
        string $tenantId,
        string $customerId,
        string $passkeyId,
        Request $request,
    ): void {
        DB::table('audit_logs')->insert([
            'id' => 'aud_'.Str::ulid()->toBase32(),
            'actor_type' => 'customer',
            'actor_id' => $customerId,
            'scope_type' => 'tenant',
            'tenant_id' => $tenantId,
            'partner_id' => null,
            'action' => $action,
            'target_type' => 'customer_passkey',
            'target_id' => $passkeyId,
            'request_id' => $request->header('X-Request-Id'),
            'ip_address' => $request->ip(),
            'user_agent' => $request->userAgent(),
            'payload_redacted_json' => json_encode([], JSON_THROW_ON_ERROR),
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
