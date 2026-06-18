<?php

namespace App\Modules\Auth\Services;

use App\Models\AdminAuthSession;
use App\Models\AdminPasswordResetToken;
use App\Models\AdminTwoFactorChallenge;
use App\Models\AdminTwoFactorRecoveryCode;
use App\Models\AdminTwoFactorSetting;
use App\Models\AdminUser;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class AdminAccountSecurityService
{
    private const PASSWORD_RESET_TTL_MINUTES = 30;
    private const TWO_FACTOR_RECOVERY_CODE_COUNT = 8;
    private const PASSWORD_POLICY_VERSION = 'm10-local';
    private const PASSWORD_RESET_IDEMPOTENCY_ACTOR_ID = 'password_reset';

    public function __construct(
        private readonly AdminAuthService $adminAuth,
        private readonly AuditLogger $auditLogger,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function requestPasswordReset(array $payload, Request $request): array
    {
        $email = $this->normalizeEmail($payload['email'] ?? null);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $emailHash = hash('sha256', $email);
        $replay = $this->idempotency->replayOrConflict(null, 'admin_password_reset', $emailHash, 'auth.admin.password.forgot', $idempotencyKey, ['email_hash' => $emailHash]);

        if (is_array($replay)) {
            return ['status' => 202];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        DB::transaction(function () use ($email, $emailHash, $request, $idempotencyKey): void {
            $admin = AdminUser::query()
                ->where('email', $email)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if ($admin !== null) {
                AdminPasswordResetToken::query()
                    ->where('admin_user_id', $admin->id)
                    ->where('status', 'pending')
                    ->whereNull('consumed_at')
                    ->update([
                        'status' => 'expired',
                        'updated_at' => now(),
                    ]);

                $token = $this->newToken('npa_prt');
                $tokenId = 'prt_'.Str::ulid()->toBase32();

                AdminPasswordResetToken::query()->insert([
                    'id' => $tokenId,
                    'admin_user_id' => (string) $admin->id,
                    'email_hash' => $emailHash,
                    'token_hash' => $this->hashToken($token),
                    'status' => 'pending',
                    'expires_at' => now()->addMinutes(self::PASSWORD_RESET_TTL_MINUTES),
                    'consumed_at' => null,
                    'requested_ip' => $request->ip(),
                    'requested_user_agent' => $request->userAgent(),
                    'created_at' => now(),
                    'updated_at' => now(),
                ]);

                $this->auditLogger->logAdminWrite(
                    actorId: (string) $admin->id,
                    scopeType: 'central',
                    action: 'admin.password_reset_requested',
                    targetType: 'admin_password_reset_token',
                    targetId: $tokenId,
                    payload: [
                        'email' => $email,
                        'reset_token' => $token,
                        'mail_delivery_status' => 'not_configured_local_dev_boundary',
                    ],
                    requestId: $request->header('X-Request-Id'),
                    ipAddress: $request->ip(),
                    userAgent: $request->userAgent(),
                );
            } else {
                $this->auditLogger->logAdminWrite(
                    actorId: 'system',
                    scopeType: 'central',
                    action: 'admin.password_reset_requested',
                    targetType: 'admin_password_reset_token',
                    targetId: null,
                    payload: [
                        'email' => $email,
                        'mail_delivery_status' => 'not_configured_local_dev_boundary',
                        'matched_admin' => false,
                    ],
                    requestId: $request->header('X-Request-Id'),
                    ipAddress: $request->ip(),
                    userAgent: $request->userAgent(),
                );
            }

            $this->idempotency->storeResponse(null, 'admin_password_reset', $emailHash, 'auth.admin.password.forgot', $idempotencyKey, ['email_hash' => $emailHash], 202, null);
        });

        return ['status' => 202];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function resetPassword(array $payload, Request $request): array
    {
        $token = trim((string) ($payload['token'] ?? ''));
        $tokenHash = $this->hashToken($token);
        $normalized = $this->passwordResetIdempotencyPayload($token, $payload);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(null, 'admin_password_reset', self::PASSWORD_RESET_IDEMPOTENCY_ACTOR_ID, 'auth.admin.password.reset', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['status' => 204];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        $password = (string) ($payload['password'] ?? '');

        return DB::transaction(function () use ($request, $tokenHash, $password, $idempotencyKey, $normalized, $payload): array {
            $reset = AdminPasswordResetToken::query()
                ->where('token_hash', $tokenHash)
                ->where('status', 'pending')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if ($reset === null) {
                return ['error' => 'authentication_required'];
            }

            $admin = AdminUser::query()
                ->whereKey($reset->admin_user_id)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if ($admin === null) {
                return ['error' => 'authentication_required'];
            }

            AdminUser::query()
                ->where('id', $admin->id)
                ->update([
                    'password_hash' => Hash::make($password),
                    'updated_at' => now(),
                ]);

            AdminPasswordResetToken::query()
                ->where('id', $reset->id)
                ->update([
                    'status' => 'consumed',
                    'consumed_at' => now(),
                    'updated_at' => now(),
                ]);

            $this->revokeAdminSessions((string) $admin->id);

            $this->auditLogger->logAdminWrite(
                actorId: (string) $admin->id,
                scopeType: 'central',
                action: 'admin.password_reset',
                targetType: 'admin_user',
                targetId: (string) $admin->id,
                payload: $payload + ['token_hash' => $tokenHash, 'sessions_revoked' => true],
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            $this->idempotency->storeResponse(null, 'admin_password_reset', self::PASSWORD_RESET_IDEMPOTENCY_ACTOR_ID, 'auth.admin.password.reset', $idempotencyKey, $normalized, 204, null);

            return ['status' => 204];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function changePassword(AdminSessionContext $context, array $payload, Request $request): array
    {
        $normalized = $this->passwordChangeIdempotencyPayload($context, $payload);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.password.change', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['status' => 204];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        $admin = AdminUser::query()
            ->whereKey($context->adminUser['id'])
            ->where('status', 'active')
            ->first();

        if ($admin === null || ! Hash::check((string) ($payload['current_password'] ?? ''), (string) $admin->password_hash)) {
            return ['error' => 'authentication_required'];
        }

        $updates = [
            'password_hash' => Hash::make((string) $payload['new_password']),
            'updated_at' => now(),
        ];

        if (Schema::hasColumn('admin_users', 'must_change_password')) {
            $updates['must_change_password'] = false;
        }

        if (Schema::hasColumn('admin_users', 'password_changed_at')) {
            $updates['password_changed_at'] = now();
        }

        AdminUser::query()
            ->where('id', $admin->id)
            ->update($updates);

        $this->revokeAdminSessions((string) $admin->id);

        $this->auditLogger->logAdminWrite(
            actorId: (string) $admin->id,
            scopeType: $context->activeScope(),
            action: 'admin.password_changed',
            targetType: 'admin_user',
            targetId: (string) $admin->id,
            payload: $payload + ['sessions_revoked' => true],
            tenantId: $context->activeTenantId(),
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        $this->idempotency->storeResponse($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.password.change', $idempotencyKey, $normalized, 204, null);

        return ['status' => 204];
    }

    /**
     * @return array<string, mixed>
     */
    public function twoFactorStatus(AdminSessionContext $context): array
    {
        $setting = AdminTwoFactorSetting::query()
            ->where('admin_user_id', $context->adminUser['id'])
            ->first();

        return [
            'id' => $context->adminUser['id'],
            'two_factor_enabled' => (bool) $context->adminUser['two_factor_enabled'],
            'two_factor_status' => $setting?->status ?? 'disabled',
            'recovery_codes_remaining' => AdminTwoFactorRecoveryCode::query()
                ->where('admin_user_id', $context->adminUser['id'])
                ->whereNull('used_at')
                ->count(),
            'secret_configured' => $setting !== null && $setting->secret_encrypted !== null,
            'recovery_codes_display_once' => false,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function setupTwoFactor(AdminSessionContext $context, array $payload, Request $request): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $normalized = ['admin_user_id' => $context->adminUser['id'], 'action' => 'setup_2fa'];
        $replay = $this->idempotency->replayOrConflict($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.2fa.setup', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        $secret = $this->generateBase32Secret();
        $recoveryCodes = $this->generateRecoveryCodes();
        $settingId = 'tfs_'.Str::ulid()->toBase32();

        DB::transaction(function () use ($context, $secret, $recoveryCodes, $payload, $request, $settingId): void {
            AdminTwoFactorSetting::query()->updateOrCreate(
                ['admin_user_id' => $context->adminUser['id']],
                [
                    'id' => $settingId,
                    'status' => 'pending',
                    'secret_encrypted' => $this->encryptSecret($secret),
                    'secret_version' => 1,
                    'enabled_at' => null,
                    'disabled_at' => null,
                    'metadata_json' => ['issuer' => 'NewPaotang'],
                    'updated_at' => now(),
                    'created_at' => now(),
                ],
            );

            AdminTwoFactorRecoveryCode::query()
                ->where('admin_user_id', $context->adminUser['id'])
                ->delete();

            $this->insertRecoveryCodes($context->adminUser['id'], $recoveryCodes);

            $this->auditLogger->logAdminWrite(
                actorId: $context->adminUser['id'],
                scopeType: $context->activeScope(),
                action: 'admin.2fa.setup_started',
                targetType: 'admin_two_factor_setting',
                targetId: $settingId,
                payload: $payload + [
                    'totp_secret' => $secret,
                    'recovery_codes' => $recoveryCodes,
                ],
                tenantId: $context->activeTenantId(),
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );
        });

        $resource = $this->twoFactorSetupResource($context, $secret, $recoveryCodes);
        $this->storeRedactedIdempotencyResponse($context, 'auth.admin.2fa.setup', $idempotencyKey, $normalized, 200, $resource);

        return ['resource' => $resource, 'status' => 200];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function enableTwoFactor(AdminSessionContext $context, array $payload, Request $request): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $normalized = $this->twoFactorCodeIdempotencyPayload($context, $payload, 'enable_2fa');
        $replay = $this->idempotency->replayOrConflict($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.2fa.enable', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        return DB::transaction(function () use ($context, $payload, $request, $idempotencyKey, $normalized): array {
            $setting = $this->activeOrPendingTwoFactorSetting($context->adminUser['id'], true);

            if ($setting === null || ! $this->verifyTotpCode($setting, (string) ($payload['code'] ?? ''))) {
                return ['error' => 'resource_conflict'];
            }

            AdminTwoFactorSetting::query()
                ->where('id', $setting->id)
                ->update([
                    'status' => 'active',
                    'enabled_at' => now(),
                    'disabled_at' => null,
                    'last_verified_at' => now(),
                    'updated_at' => now(),
                ]);

            AdminUser::query()
                ->where('id', $context->adminUser['id'])
                ->update([
                    'two_factor_enabled' => true,
                    'updated_at' => now(),
                ]);

            $this->revokeAdminSessions($context->adminUser['id'], $context->session['id']);
            $resource = array_merge($this->twoFactorStatus($context), [
                'two_factor_enabled' => true,
                'two_factor_status' => 'active',
            ]);

            $this->auditLogger->logAdminWrite(
                actorId: $context->adminUser['id'],
                scopeType: $context->activeScope(),
                action: 'admin.2fa.enabled',
                targetType: 'admin_two_factor_setting',
                targetId: (string) $setting->id,
                payload: $this->twoFactorAuditPayload($payload, ['other_sessions_revoked' => true]),
                tenantId: $context->activeTenantId(),
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            $this->idempotency->storeResponse($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.2fa.enable', $idempotencyKey, $normalized, 200, $resource);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function rotateRecoveryCodes(AdminSessionContext $context, array $payload, Request $request): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $normalized = $this->twoFactorCodeIdempotencyPayload($context, $payload, 'rotate_recovery_codes', includeCurrentPassword: true);
        $replay = $this->idempotency->replayOrConflict($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.2fa.recovery-codes', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['resource' => $replay['body'] ?? [], 'status' => $replay['status']];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        return DB::transaction(function () use ($context, $payload, $request, $idempotencyKey, $normalized): array {
            $setting = $this->activeOrPendingTwoFactorSetting($context->adminUser['id']);
            $admin = AdminUser::query()->whereKey($context->adminUser['id'])->first();

            if ($setting === null || $admin === null || ! Hash::check((string) ($payload['current_password'] ?? ''), (string) $admin->password_hash) || ! $this->verifyTotpCode($setting, (string) ($payload['code'] ?? ''))) {
                return ['error' => 'authentication_required'];
            }

            $recoveryCodes = $this->generateRecoveryCodes();

            AdminTwoFactorRecoveryCode::query()
                ->where('admin_user_id', $context->adminUser['id'])
                ->delete();

            $this->insertRecoveryCodes($context->adminUser['id'], $recoveryCodes);
            $this->revokeAdminSessions($context->adminUser['id'], $context->session['id']);

            $resource = [
                'id' => $context->adminUser['id'],
                'two_factor_enabled' => true,
                'two_factor_status' => 'active',
                'recovery_codes' => $recoveryCodes,
                'recovery_codes_display_once' => true,
            ];

            $this->auditLogger->logAdminWrite(
                actorId: $context->adminUser['id'],
                scopeType: $context->activeScope(),
                action: 'admin.2fa.recovery_codes_rotated',
                targetType: 'admin_two_factor_recovery_code',
                targetId: $context->adminUser['id'],
                payload: $this->twoFactorAuditPayload($payload, ['recovery_codes' => $recoveryCodes, 'other_sessions_revoked' => true]),
                tenantId: $context->activeTenantId(),
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            $this->storeRedactedIdempotencyResponse($context, 'auth.admin.2fa.recovery-codes', $idempotencyKey, $normalized, 200, $resource);

            return ['resource' => $resource, 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function disableTwoFactor(AdminSessionContext $context, array $payload, Request $request): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $normalized = $this->twoFactorCodeIdempotencyPayload($context, $payload, 'disable_2fa', includeCurrentPassword: true);
        $replay = $this->idempotency->replayOrConflict($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.2fa.disable', $idempotencyKey, $normalized);

        if (is_array($replay)) {
            return ['status' => 204];
        }

        if ($replay !== null) {
            return ['error' => $replay];
        }

        return DB::transaction(function () use ($context, $payload, $request, $idempotencyKey, $normalized): array {
            $setting = $this->activeOrPendingTwoFactorSetting($context->adminUser['id']);
            $admin = AdminUser::query()->whereKey($context->adminUser['id'])->first();

            if ($setting === null || $admin === null || ! Hash::check((string) ($payload['current_password'] ?? ''), (string) $admin->password_hash) || ! $this->verifyTotpCode($setting, (string) ($payload['code'] ?? ''))) {
                return ['error' => 'authentication_required'];
            }

            AdminTwoFactorSetting::query()
                ->where('id', $setting->id)
                ->update([
                    'status' => 'disabled',
                    'secret_encrypted' => null,
                    'disabled_at' => now(),
                    'updated_at' => now(),
                ]);

            AdminTwoFactorRecoveryCode::query()
                ->where('admin_user_id', $context->adminUser['id'])
                ->delete();

            AdminUser::query()
                ->where('id', $context->adminUser['id'])
                ->update([
                    'two_factor_enabled' => false,
                    'updated_at' => now(),
                ]);

            $this->revokeAdminSessions($context->adminUser['id'], $context->session['id']);

            $this->auditLogger->logAdminWrite(
                actorId: $context->adminUser['id'],
                scopeType: $context->activeScope(),
                action: 'admin.2fa.disabled',
                targetType: 'admin_two_factor_setting',
                targetId: (string) $setting->id,
                payload: $this->twoFactorAuditPayload($payload, ['other_sessions_revoked' => true]),
                tenantId: $context->activeTenantId(),
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            $this->idempotency->storeResponse($context->activeTenantId(), 'admin', $context->adminUser['id'], 'auth.admin.2fa.disable', $idempotencyKey, $normalized, 204, null);

            return ['status' => 204];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{status?: int, error?: string, resource?: array<string, mixed>}
     */
    public function verifyTwoFactorChallenge(array $payload, Request $request): array
    {
        $challengeToken = trim((string) ($payload['challenge_token'] ?? ''));
        $challengeHash = $this->hashToken($challengeToken);

        return DB::transaction(function () use ($challengeHash, $payload, $request): array {
            $challenge = AdminTwoFactorChallenge::query()
                ->where('challenge_token_hash', $challengeHash)
                ->where('status', 'pending')
                ->whereNull('consumed_at')
                ->where('expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if ($challenge === null) {
                return ['error' => 'authentication_required'];
            }

            $admin = AdminUser::query()
                ->whereKey($challenge->admin_user_id)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            $setting = $admin === null ? null : $this->activeOrPendingTwoFactorSetting((string) $admin->id);
            $valid = $admin !== null
                && $setting !== null
                && ((bool) $admin->two_factor_enabled)
                && ($this->verifyTotpCode($setting, (string) ($payload['code'] ?? '')) || $this->consumeRecoveryCode((string) $admin->id, (string) ($payload['code'] ?? '')));

            AdminTwoFactorChallenge::query()
                ->where('id', $challenge->id)
                ->update([
                    'status' => $valid ? 'consumed' : 'failed',
                    'consumed_at' => now(),
                    'updated_at' => now(),
                ]);

            if (! $valid || $admin === null) {
                return ['error' => 'authentication_required'];
            }

            AdminTwoFactorSetting::query()
                ->where('id', $setting->id)
                ->update([
                    'last_verified_at' => now(),
                    'updated_at' => now(),
                ]);

            $response = $this->adminAuth->issueSessionForChallenge($admin, $challenge, $request);

            if ($response === null) {
                return ['error' => 'authentication_required'];
            }

            $this->auditLogger->logAdminWrite(
                actorId: (string) $admin->id,
                scopeType: (string) $challenge->scope_type,
                action: 'admin.2fa.verified',
                targetType: 'admin_two_factor_challenge',
                targetId: (string) $challenge->id,
                payload: $this->twoFactorAuditPayload($payload),
                tenantId: $challenge->tenant_id,
                requestId: $request->header('X-Request-Id'),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            return ['resource' => $response, 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function passwordResetRequestErrors(array $payload): array
    {
        return $this->requiredEmailErrors($payload);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function resetPasswordErrors(array $payload): array
    {
        $errors = [];

        foreach (['token', 'password', 'password_confirmation'] as $field) {
            if (trim((string) ($payload[$field] ?? '')) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        $this->passwordPolicyErrors($errors, 'password', (string) ($payload['password'] ?? ''));

        if (($payload['password'] ?? null) !== ($payload['password_confirmation'] ?? null)) {
            $errors['password_confirmation'][] = 'The password confirmation does not match.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function changePasswordErrors(array $payload): array
    {
        $errors = [];

        foreach (['current_password', 'new_password', 'new_password_confirmation'] as $field) {
            if (trim((string) ($payload[$field] ?? '')) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        $this->passwordPolicyErrors($errors, 'new_password', (string) ($payload['new_password'] ?? ''));

        if (($payload['new_password'] ?? null) !== ($payload['new_password_confirmation'] ?? null)) {
            $errors['new_password_confirmation'][] = 'The new password confirmation does not match.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function twoFactorCodeErrors(array $payload, bool $requireCurrentPassword = false): array
    {
        $errors = [];

        if (trim((string) ($payload['code'] ?? '')) === '') {
            $errors['code'][] = 'The code field is required.';
        }

        if ($requireCurrentPassword && trim((string) ($payload['current_password'] ?? '')) === '') {
            $errors['current_password'][] = 'The current_password field is required.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function twoFactorVerifyErrors(array $payload): array
    {
        $errors = [];

        foreach (['challenge_token', 'code'] as $field) {
            if (trim((string) ($payload[$field] ?? '')) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, array<int, string>> $errors
     */
    private function passwordPolicyErrors(array &$errors, string $field, string $password): void
    {
        if (strlen($password) < 8) {
            $errors[$field][] = 'The '.$field.' field must be at least 8 characters.';
        }
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function requiredEmailErrors(array $payload): array
    {
        $email = $this->normalizeEmail($payload['email'] ?? null);

        if ($email === '' || ! filter_var($email, FILTER_VALIDATE_EMAIL)) {
            return ['email' => ['The email field must be a valid email address.']];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, string>
     */
    private function passwordResetIdempotencyPayload(string $token, array $payload): array
    {
        return [
            'reset_token_fingerprint' => $this->sensitiveFingerprint('password_reset.token', $token),
            'password_fingerprint' => $this->sensitiveFingerprint('password_reset.password', (string) ($payload['password'] ?? '')),
            'password_confirmation_fingerprint' => $this->sensitiveFingerprint('password_reset.password_confirmation', (string) ($payload['password_confirmation'] ?? '')),
            'password_policy_version' => self::PASSWORD_POLICY_VERSION,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, string>
     */
    private function passwordChangeIdempotencyPayload(AdminSessionContext $context, array $payload): array
    {
        return [
            'admin_user_id' => $context->adminUser['id'],
            'current_password_fingerprint' => $this->sensitiveFingerprint('password_change.current_password', (string) ($payload['current_password'] ?? '')),
            'new_password_fingerprint' => $this->sensitiveFingerprint('password_change.new_password', (string) ($payload['new_password'] ?? '')),
            'new_password_confirmation_fingerprint' => $this->sensitiveFingerprint('password_change.new_password_confirmation', (string) ($payload['new_password_confirmation'] ?? '')),
            'password_policy_version' => self::PASSWORD_POLICY_VERSION,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, string>
     */
    private function twoFactorCodeIdempotencyPayload(AdminSessionContext $context, array $payload, string $action, bool $includeCurrentPassword = false): array
    {
        $normalized = [
            'admin_user_id' => $context->adminUser['id'],
            'action' => $action,
            'totp_code_fingerprint' => $this->sensitiveFingerprint('admin_2fa.'.$action.'.code', $this->normalizeTotpCode((string) ($payload['code'] ?? ''))),
        ];

        if ($includeCurrentPassword) {
            $normalized['current_password_fingerprint'] = $this->sensitiveFingerprint('admin_2fa.'.$action.'.current_password', (string) ($payload['current_password'] ?? ''));
        }

        return $normalized;
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $extra
     * @return array<string, mixed>
     */
    private function twoFactorAuditPayload(array $payload, array $extra = []): array
    {
        $auditPayload = $payload;

        if (array_key_exists('code', $auditPayload)) {
            $auditPayload['totp_secret_code'] = $auditPayload['code'];
            unset($auditPayload['code']);
        }

        return $auditPayload + $extra;
    }

    private function sensitiveFingerprint(string $purpose, string $value): string
    {
        return hash_hmac('sha256', $purpose.'|'.$value, $this->localSecretKey());
    }

    private function activeOrPendingTwoFactorSetting(string $adminUserId, bool $allowPending = false): ?AdminTwoFactorSetting
    {
        $statuses = $allowPending ? ['pending', 'active'] : ['active'];

        return AdminTwoFactorSetting::query()
            ->where('admin_user_id', $adminUserId)
            ->whereIn('status', $statuses)
            ->whereNotNull('secret_encrypted')
            ->lockForUpdate()
            ->first();
    }

    private function verifyTotpCode(AdminTwoFactorSetting $setting, string $code): bool
    {
        $code = $this->normalizeTotpCode($code);

        if ($code === '' || strlen($code) !== 6 || $setting->secret_encrypted === null) {
            return false;
        }

        $secret = $this->decryptSecret((string) $setting->secret_encrypted);
        $counter = intdiv(time(), 30);

        foreach ([-1, 0, 1] as $offset) {
            if (hash_equals($this->totpCode($secret, $counter + $offset), $code)) {
                return true;
            }
        }

        return false;
    }

    private function consumeRecoveryCode(string $adminUserId, string $code): bool
    {
        $codeHash = hash('sha256', $this->normalizeRecoveryCode($code));
        $recoveryCode = AdminTwoFactorRecoveryCode::query()
            ->where('admin_user_id', $adminUserId)
            ->where('code_hash', $codeHash)
            ->whereNull('used_at')
            ->lockForUpdate()
            ->first();

        if ($recoveryCode === null) {
            return false;
        }

        AdminTwoFactorRecoveryCode::query()
            ->where('id', $recoveryCode->id)
            ->update([
                'used_at' => now(),
                'updated_at' => now(),
            ]);

        return true;
    }

    private function totpCode(string $secret, int $counter): string
    {
        $key = $this->base32Decode($secret);
        $binaryCounter = pack('N2', intdiv($counter, 4294967296), $counter % 4294967296);
        $hash = hash_hmac('sha1', $binaryCounter, $key, true);
        $offset = ord($hash[19]) & 0x0f;
        $value = ((ord($hash[$offset]) & 0x7f) << 24)
            | ((ord($hash[$offset + 1]) & 0xff) << 16)
            | ((ord($hash[$offset + 2]) & 0xff) << 8)
            | (ord($hash[$offset + 3]) & 0xff);

        return str_pad((string) ($value % 1000000), 6, '0', STR_PAD_LEFT);
    }

    private function generateBase32Secret(): string
    {
        return $this->base32Encode(random_bytes(20));
    }

    private function base32Encode(string $bytes): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $bits = '';

        foreach (str_split($bytes) as $byte) {
            $bits .= str_pad(decbin(ord($byte)), 8, '0', STR_PAD_LEFT);
        }

        $output = '';

        foreach (str_split($bits, 5) as $chunk) {
            $output .= $alphabet[bindec(str_pad($chunk, 5, '0', STR_PAD_RIGHT))];
        }

        return $output;
    }

    private function base32Decode(string $secret): string
    {
        $alphabet = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ234567';
        $secret = preg_replace('/[^A-Z2-7]/', '', strtoupper($secret)) ?? '';
        $bits = '';

        foreach (str_split($secret) as $char) {
            $position = strpos($alphabet, $char);

            if ($position === false) {
                continue;
            }

            $bits .= str_pad(decbin($position), 5, '0', STR_PAD_LEFT);
        }

        $bytes = '';

        foreach (str_split($bits, 8) as $chunk) {
            if (strlen($chunk) === 8) {
                $bytes .= chr(bindec($chunk));
            }
        }

        return $bytes;
    }

    /**
     * @return array<int, string>
     */
    private function generateRecoveryCodes(): array
    {
        $codes = [];

        for ($i = 0; $i < self::TWO_FACTOR_RECOVERY_CODE_COUNT; $i++) {
            $raw = substr($this->base32Encode(random_bytes(8)), 0, 12);
            $codes[] = substr($raw, 0, 4).'-'.substr($raw, 4, 4).'-'.substr($raw, 8, 4);
        }

        return $codes;
    }

    /**
     * @param array<int, string> $recoveryCodes
     */
    private function insertRecoveryCodes(string $adminUserId, array $recoveryCodes): void
    {
        AdminTwoFactorRecoveryCode::query()->insert(array_map(fn (string $code): array => [
            'id' => 'tfr_'.Str::ulid()->toBase32(),
            'admin_user_id' => $adminUserId,
            'code_hash' => hash('sha256', $this->normalizeRecoveryCode($code)),
            'used_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ], $recoveryCodes));
    }

    /**
     * @param array<int, string> $recoveryCodes
     * @return array<string, mixed>
     */
    private function twoFactorSetupResource(AdminSessionContext $context, string $secret, array $recoveryCodes): array
    {
        return [
            'id' => $context->adminUser['id'],
            'two_factor_enabled' => false,
            'two_factor_status' => 'pending',
            'secret' => $secret,
            'otpauth_url' => $this->otpauthUrl((string) $context->adminUser['email'], $secret),
            'recovery_codes' => $recoveryCodes,
            'recovery_codes_display_once' => true,
        ];
    }

    private function otpauthUrl(string $email, string $secret): string
    {
        $issuer = 'NewPaotang';
        $label = rawurlencode($issuer.':'.$email);

        return 'otpauth://totp/'.$label.'?secret='.$secret.'&issuer='.rawurlencode($issuer).'&digits=6&period=30';
    }

    /**
     * @param array<string, mixed> $resource
     * @return array<string, mixed>
     */
    private function redactedDisplayOnceResource(array $resource): array
    {
        $redacted = $resource;

        foreach (['secret', 'otpauth_url'] as $field) {
            if (array_key_exists($field, $redacted)) {
                $redacted[$field] = '[REDACTED_DISPLAY_ONCE]';
            }
        }

        if (array_key_exists('recovery_codes', $redacted)) {
            $redacted['recovery_codes'] = [];
        }

        $redacted['recovery_codes_display_once'] = false;

        return $redacted;
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, mixed> $resource
     */
    private function storeRedactedIdempotencyResponse(AdminSessionContext $context, string $routeKey, string $idempotencyKey, array $payload, int $status, array $resource): void
    {
        $this->idempotency->storeResponse(
            $context->activeTenantId(),
            'admin',
            $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
            $status,
            $this->redactedDisplayOnceResource($resource),
        );
    }

    private function revokeAdminSessions(string $adminUserId, ?string $exceptSessionId = null): void
    {
        $query = AdminAuthSession::query()
            ->where('admin_user_id', $adminUserId)
            ->whereNull('revoked_at');

        if ($exceptSessionId !== null) {
            $query->where('id', '!=', $exceptSessionId);
        }

        $query->update([
            'revoked_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function normalizeEmail(mixed $email): string
    {
        return strtolower(trim((string) $email));
    }

    private function encryptSecret(string $secret): string
    {
        $iv = random_bytes(16);
        $ciphertext = openssl_encrypt($secret, 'AES-256-CBC', $this->localSecretKey(), OPENSSL_RAW_DATA, $iv);

        return base64_encode($iv.($ciphertext === false ? '' : $ciphertext));
    }

    private function decryptSecret(string $encrypted): string
    {
        $payload = base64_decode($encrypted, true);

        if ($payload === false || strlen($payload) <= 16) {
            return '';
        }

        $iv = substr($payload, 0, 16);
        $ciphertext = substr($payload, 16);
        $secret = openssl_decrypt($ciphertext, 'AES-256-CBC', $this->localSecretKey(), OPENSSL_RAW_DATA, $iv);

        return $secret === false ? '' : $secret;
    }

    private function localSecretKey(): string
    {
        return hash('sha256', (string) config('app.key', 'newpaotang-local-dev-secret-key'), true);
    }

    private function normalizeRecoveryCode(string $code): string
    {
        return preg_replace('/[^A-Z0-9]/', '', strtoupper($code)) ?? '';
    }

    private function normalizeTotpCode(string $code): string
    {
        return preg_replace('/\D+/', '', $code) ?? '';
    }

    private function newToken(string $prefix): string
    {
        return $prefix.'_'.bin2hex(random_bytes(32));
    }

    private function hashToken(string $token): string
    {
        return hash('sha256', $token);
    }
}
