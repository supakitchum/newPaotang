<?php

namespace App\Modules\Auth\Services;

use App\Models\AdminAuthSession;
use App\Models\AdminScope;
use App\Models\AdminTwoFactorChallenge;
use App\Models\AdminTwoFactorSetting;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Tenancy\PartnerBoHostResolver;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class AdminAuthService
{
    private const ACCESS_TOKEN_TTL_SECONDS = 28800;
    private const REFRESH_TOKEN_TTL_SECONDS = 604800;
    private const REVOKED_REASON_LOGOUT = 'logout';
    private const REVOKED_REASON_REFRESHED = 'refreshed';
    public const REVOKED_REASON_REPLACED_BY_NEW_LOGIN = 'replaced_by_new_login';

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly PermissionService $permissions,
        private readonly PartnerBoHostResolver $partnerBoHosts,
    ) {
    }

    /**
     * @param array{email?: string, password?: string, scope?: string|null, tenant_id?: string|null} $payload
     * @return array<string, mixed>|null
     */
    public function login(array $payload, Request $request, ?array $partnerBoContext = null): ?array
    {
        $email = strtolower(trim((string) ($payload['email'] ?? '')));
        $password = (string) ($payload['password'] ?? '');

        if ($email === '' || $password === '') {
            return null;
        }

        $adminUser = AdminUser::where('email', $email)
            ->where('status', 'active')
            ->first();

        if ($adminUser === null || ! Hash::check($password, (string) $adminUser->password_hash)) {
            return null;
        }

        $admin = $this->adminToArray($adminUser);
        $scopes = $this->scopesForAdmin($admin['id']);
        $payload = $this->partnerBoLoginPayload($payload, $partnerBoContext);

        if ($payload === null) {
            return null;
        }

        $activeScope = $this->chooseActiveScope($scopes, $payload['scope'] ?? null, $payload['tenant_id'] ?? null);

        if ($activeScope === null || ! $this->activeScopeMatchesPartnerBo($activeScope, $partnerBoContext)) {
            return null;
        }

        $visibleScopes = $this->visibleScopesForPartnerBo($scopes, $partnerBoContext);

        if ((bool) $adminUser->two_factor_enabled) {
            return $this->issueTwoFactorChallenge($admin, $visibleScopes, $activeScope, $request);
        }

        $response = $this->issueSession($admin, $visibleScopes, $activeScope);

        $this->auditLogger->logAdminWrite(
            actorId: $admin['id'],
            scopeType: $activeScope['scope'],
            action: 'admin.login',
            targetType: 'admin_auth_session',
            targetId: $response['session_id'],
            payload: [
                'email' => $email,
                'scope' => $activeScope['scope'],
                'tenant_id' => $activeScope['tenant_id'],
                'password' => $password,
                'access_token' => $response['access_token'],
                'refresh_token' => $response['refresh_token'],
                'revoked_other_sessions_count' => $response['revoked_other_sessions_count'],
            ],
            tenantId: $activeScope['tenant_id'],
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        unset($response['session_id']);

        return $response;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function issueSessionForChallenge(AdminUser $adminUser, object $challenge, ?Request $request = null): ?array
    {
        $admin = $this->adminToArray($adminUser);
        $scopes = $this->scopesForAdmin($admin['id']);
        $activeScope = $this->scopeFromChallenge($scopes, $challenge);
        $partnerBoContext = null;

        if ($request !== null) {
            $resolved = $this->partnerBoHosts->resolve($request);

            if ($resolved['error'] !== null) {
                return null;
            }

            $partnerBoContext = $resolved['context'];
        }

        if ($activeScope === null || ! $this->activeScopeMatchesPartnerBo($activeScope, $partnerBoContext)) {
            return null;
        }

        $response = $this->issueSession($admin, $this->visibleScopesForPartnerBo($scopes, $partnerBoContext), $activeScope);
        unset($response['session_id']);

        return $response;
    }

    /**
     * @return array<string, mixed>|null
     */
    public function refresh(string $refreshToken, ?array $partnerBoContext = null): ?array
    {
        if ($refreshToken === '') {
            return null;
        }

        return DB::transaction(function () use ($refreshToken, $partnerBoContext): ?array {
            $oldSession = AdminAuthSession::query()
                ->where('refresh_token_hash', $this->tokenHash($refreshToken))
                ->whereNull('revoked_at')
                ->where('refresh_expires_at', '>', now())
                ->lockForUpdate()
                ->first();

            if ($oldSession === null) {
                return null;
            }

            if ($partnerBoContext !== null && ! $this->sessionMatchesPartnerBo($oldSession, $partnerBoContext)) {
                return null;
            }

            $adminUser = AdminUser::whereKey($oldSession->admin_user_id)
                ->where('status', 'active')
                ->first();

            if ($adminUser === null) {
                AdminAuthSession::query()
                    ->where('id', $oldSession->id)
                    ->update([
                        'revoked_at' => now(),
                        'revoked_reason' => self::REVOKED_REASON_REFRESHED,
                        'updated_at' => now(),
                    ]);

                return null;
            }

            AdminAuthSession::query()
                ->where('id', $oldSession->id)
                ->update([
                    'revoked_at' => now(),
                    'revoked_reason' => self::REVOKED_REASON_REFRESHED,
                    'updated_at' => now(),
                ]);

            $admin = $this->adminToArray($adminUser);
            $scopes = $this->scopesForAdmin($admin['id']);
            $activeScope = $this->scopeFromSession($scopes, $oldSession);

            if ($activeScope === null || ! $this->activeScopeMatchesPartnerBo($activeScope, $partnerBoContext)) {
                return null;
            }

            $response = $this->issueSession(
                $admin,
                $this->visibleScopesForPartnerBo($scopes, $partnerBoContext),
                $activeScope,
                (string) $oldSession->id,
            );
            unset($response['session_id']);

            return $response;
        });
    }

    public function revoke(AdminSessionContext $context, Request $request): void
    {
        AdminAuthSession::query()
            ->where('id', $context->session['id'])
            ->whereNull('revoked_at')
            ->update([
                'revoked_at' => now(),
                'revoked_reason' => self::REVOKED_REASON_LOGOUT,
                'updated_at' => now(),
            ]);

        $this->auditLogger->logAdminWrite(
            actorId: $context->adminUser['id'],
            scopeType: $context->activeScope(),
            action: 'admin.logout',
            targetType: 'admin_auth_session',
            targetId: $context->session['id'],
            payload: [
                'scope' => $context->activeScope(),
                'tenant_id' => $context->activeTenantId(),
                'authorization' => $request->header('Authorization'),
            ],
            tenantId: $context->activeTenantId(),
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    /**
     * @return array<string, mixed>|null
     */
    public function sessionProfile(AdminSessionContext $context, ?array $partnerBoContext = null): ?array
    {
        if ($partnerBoContext !== null && ! $this->contextMatchesPartnerBo($context, $partnerBoContext)) {
            return null;
        }

        return [
            'user' => $this->profileFromAdmin($context->adminUser),
            'scopes' => $this->visibleScopesForPartnerBo($context->scopes, $partnerBoContext),
            'active_scope' => $context->activeScope(),
            'active_tenant_id' => $context->activeTenantId(),
        ];
    }

    /**
     * @param array<string, mixed> $admin
     * @param array<int, array<string, mixed>> $scopes
     * @param array<string, mixed> $activeScope
     * @return array<string, mixed>
     */
    private function issueSession(array $admin, array $scopes, array $activeScope, ?string $refreshedFromId = null): array
    {
        $accessToken = $this->newToken('npa_at');
        $refreshToken = $this->newToken('npa_rt');
        $sessionId = 'ads_'.Str::ulid()->toBase32();
        $revokedOtherSessionsCount = $this->revokeOtherActiveSessions($admin['id']);

        AdminAuthSession::query()->insert([
            'id' => $sessionId,
            'admin_user_id' => $admin['id'],
            'access_token_hash' => $this->tokenHash($accessToken),
            'refresh_token_hash' => $this->tokenHash($refreshToken),
            'scope_type' => $activeScope['scope'],
            'scope_id' => $activeScope['scope_id'],
            'tenant_id' => $activeScope['tenant_id'],
            'access_expires_at' => now()->addSeconds(self::ACCESS_TOKEN_TTL_SECONDS),
            'refresh_expires_at' => now()->addSeconds(self::REFRESH_TOKEN_TTL_SECONDS),
            'revoked_at' => null,
            'revoked_reason' => null,
            'refreshed_from_id' => $refreshedFromId,
            'last_used_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return [
            'session_id' => $sessionId,
            'access_token' => $accessToken,
            'refresh_token' => $refreshToken,
            'expires_in' => self::ACCESS_TOKEN_TTL_SECONDS,
            'revoked_other_sessions_count' => $revokedOtherSessionsCount,
            'message' => $revokedOtherSessionsCount > 0
                ? 'A previous admin session was signed out because this account signed in on another device.'
                : null,
            'requires_2fa' => false,
            'challenge_token' => null,
            'user' => $this->profileFromAdmin($admin),
            'scopes' => $scopes,
        ];
    }

    /**
     * @param array<string, mixed> $admin
     * @param array<int, array<string, mixed>> $scopes
     * @param array<string, mixed> $activeScope
     * @return array<string, mixed>|null
     */
    private function issueTwoFactorChallenge(array $admin, array $scopes, array $activeScope, Request $request): ?array
    {
        $setting = AdminTwoFactorSetting::query()
            ->where('admin_user_id', $admin['id'])
            ->where('status', 'active')
            ->whereNotNull('secret_encrypted')
            ->first();

        if ($setting === null) {
            return null;
        }

        $challengeToken = $this->newToken('npa_2fa');
        $challengeId = 'tfc_'.Str::ulid()->toBase32();

        AdminTwoFactorChallenge::query()->insert([
            'id' => $challengeId,
            'admin_user_id' => $admin['id'],
            'challenge_token_hash' => $this->tokenHash($challengeToken),
            'scope_type' => $activeScope['scope'],
            'scope_id' => $activeScope['scope_id'],
            'tenant_id' => $activeScope['tenant_id'],
            'status' => 'pending',
            'expires_at' => now()->addMinutes(5),
            'consumed_at' => null,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->auditLogger->logAdminWrite(
            actorId: $admin['id'],
            scopeType: $activeScope['scope'],
            action: 'admin.2fa.challenge_created',
            targetType: 'admin_two_factor_challenge',
            targetId: $challengeId,
            payload: [
                'email' => $admin['email'],
                'scope' => $activeScope['scope'],
                'tenant_id' => $activeScope['tenant_id'],
                'challenge_token' => $challengeToken,
            ],
            tenantId: $activeScope['tenant_id'],
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return [
            'access_token' => '',
            'refresh_token' => '',
            'expires_in' => 0,
            'requires_2fa' => true,
            'challenge_token' => $challengeToken,
            'user' => $this->profileFromAdmin($admin),
            'scopes' => $scopes,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function scopesForAdmin(string $adminUserId): array
    {
        $scopeRows = AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'admin_scopes.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->where('admin_user_roles.admin_user_id', $adminUserId)
            ->select(
                'admin_scopes.id',
                'admin_scopes.scope_type',
                'admin_scopes.tenant_id',
                'partner_tenants.name as tenant_name',
                'partner_tenants.status as tenant_status',
                'partners.status as partner_status',
            )
            ->distinct()
            ->orderBy('admin_scopes.scope_type')
            ->orderBy('admin_scopes.tenant_id')
            ->get();

        $scopes = [];

        foreach ($scopeRows as $scopeRow) {
            if (! $this->scopeRowIsUsable($scopeRow)) {
                continue;
            }

            $tenantId = $scopeRow->scope_type === 'tenant' ? $scopeRow->tenant_id : null;
            $scopeId = (string) $scopeRow->id;

            $scopes[] = [
                'scope' => (string) $scopeRow->scope_type,
                'scope_id' => $scopeId,
                'tenant_id' => $tenantId,
                'tenant_name' => $scopeRow->scope_type === 'tenant' ? $scopeRow->tenant_name : null,
                'permissions' => $this->permissions->permissionsForAdminScope(
                    $adminUserId,
                    (string) $scopeRow->scope_type,
                    $scopeId,
                    $tenantId,
                ),
            ];
        }

        return $scopes;
    }

    public function sessionScopeIsUsable(string $scopeType, ?string $scopeId, ?string $tenantId): bool
    {
        if ($scopeType === 'central') {
            return true;
        }

        if ($scopeType !== 'tenant' || $scopeId === null || $scopeId === '' || $tenantId === null || $tenantId === '') {
            return false;
        }

        $record = AdminScope::query()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'admin_scopes.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->where('admin_scopes.id', $scopeId)
            ->where('admin_scopes.scope_type', 'tenant')
            ->where('admin_scopes.tenant_id', $tenantId)
            ->select('partner_tenants.status as tenant_status', 'partners.status as partner_status')
            ->first();

        if ($record === null) {
            return false;
        }

        return $this->tenantAndPartnerAreActive((string) $record->tenant_status, (string) $record->partner_status);
    }

    /**
     * @param array<int, array<string, mixed>> $scopes
     * @return array<int, array<string, mixed>>
     */
    public function visibleScopesForPartnerBo(array $scopes, ?array $partnerBoContext): array
    {
        if ($partnerBoContext === null) {
            return $scopes;
        }

        return array_values(array_filter(
            $scopes,
            fn (array $scope): bool => $this->activeScopeMatchesPartnerBo($scope, $partnerBoContext),
        ));
    }

    /**
     * @param array<string, mixed> $partnerBoContext
     */
    public function contextMatchesPartnerBo(AdminSessionContext $context, array $partnerBoContext): bool
    {
        return $context->activeScope() === 'tenant'
            && $context->activeTenantId() === $partnerBoContext['tenant_id'];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    private function partnerBoLoginPayload(array $payload, ?array $partnerBoContext): ?array
    {
        if ($partnerBoContext === null) {
            return $payload;
        }

        if (($payload['scope'] ?? null) === 'central') {
            return null;
        }

        $requestedTenantId = trim((string) ($payload['tenant_id'] ?? ''));

        if ($requestedTenantId !== '' && $requestedTenantId !== $partnerBoContext['tenant_id']) {
            return null;
        }

        $payload['scope'] = 'tenant';
        $payload['tenant_id'] = $partnerBoContext['tenant_id'];

        return $payload;
    }

    /**
     * @param array<string, mixed> $activeScope
     */
    private function activeScopeMatchesPartnerBo(array $activeScope, ?array $partnerBoContext): bool
    {
        if ($partnerBoContext === null) {
            return true;
        }

        return ($activeScope['scope'] ?? null) === 'tenant'
            && ($activeScope['tenant_id'] ?? null) === $partnerBoContext['tenant_id'];
    }

    private function sessionMatchesPartnerBo(object $session, array $partnerBoContext): bool
    {
        return (string) $session->scope_type === 'tenant'
            && (string) $session->tenant_id === $partnerBoContext['tenant_id'];
    }

    /**
     * @param array<int, array<string, mixed>> $scopes
     * @return array<string, mixed>|null
     */
    private function chooseActiveScope(array $scopes, ?string $requestedScope, ?string $tenantId): ?array
    {
        if ($requestedScope !== null && ! in_array($requestedScope, ['central', 'tenant'], true)) {
            return null;
        }

        if ($requestedScope === 'tenant' && ($tenantId === null || $tenantId === '')) {
            return null;
        }

        if ($requestedScope === 'central') {
            return $this->firstScope($scopes, 'central');
        }

        if ($requestedScope === 'tenant') {
            return $this->firstScope($scopes, 'tenant', $tenantId);
        }

        if ($tenantId !== null && $tenantId !== '') {
            return $this->firstScope($scopes, 'tenant', $tenantId);
        }

        return $this->firstScope($scopes, 'central');
    }

    /**
     * @param array<int, array<string, mixed>> $scopes
     * @return array<string, mixed>|null
     */
    private function firstScope(array $scopes, string $scopeType, ?string $tenantId = null): ?array
    {
        foreach ($scopes as $scope) {
            if ($scope['scope'] !== $scopeType) {
                continue;
            }

            if ($scopeType === 'tenant' && $scope['tenant_id'] !== $tenantId) {
                continue;
            }

            return $scope;
        }

        return null;
    }

    /**
     * @param array<int, array<string, mixed>> $scopes
     * @return array<string, mixed>|null
     */
    private function scopeFromSession(array $scopes, object $session): ?array
    {
        foreach ($scopes as $scope) {
            if ($scope['scope'] !== $session->scope_type) {
                continue;
            }

            if ($scope['scope_id'] !== $session->scope_id) {
                continue;
            }

            if ($scope['scope'] === 'tenant' && $scope['tenant_id'] !== $session->tenant_id) {
                continue;
            }

            return $scope;
        }

        return null;
    }

    /**
     * @param array<int, array<string, mixed>> $scopes
     * @return array<string, mixed>|null
     */
    private function scopeFromChallenge(array $scopes, object $challenge): ?array
    {
        foreach ($scopes as $scope) {
            if ($scope['scope'] !== $challenge->scope_type) {
                continue;
            }

            if ($scope['scope_id'] !== $challenge->scope_id) {
                continue;
            }

            if ($scope['scope'] === 'tenant' && $scope['tenant_id'] !== $challenge->tenant_id) {
                continue;
            }

            return $scope;
        }

        return null;
    }

    private function scopeRowIsUsable(object $scopeRow): bool
    {
        if ($scopeRow->scope_type === 'central') {
            return true;
        }

        if ($scopeRow->scope_type !== 'tenant') {
            return false;
        }

        if ($scopeRow->tenant_id === null || $scopeRow->tenant_status === null || $scopeRow->partner_status === null) {
            return false;
        }

        return $this->tenantAndPartnerAreActive((string) $scopeRow->tenant_status, (string) $scopeRow->partner_status);
    }

    private function tenantAndPartnerAreActive(string $tenantStatus, string $partnerStatus): bool
    {
        return $tenantStatus === config('platform.tenant_resolution.active_tenant_status', 'active')
            && $partnerStatus === config('platform.tenant_resolution.active_partner_status', 'active');
    }

    /**
     * @return array<string, mixed>
     */
    private function adminToArray(object $adminUser): array
    {
        return [
            'id' => (string) $adminUser->id,
            'name' => $adminUser->name !== null && $adminUser->name !== '' ? (string) $adminUser->name : (string) $adminUser->email,
            'email' => (string) $adminUser->email,
            'phone' => $adminUser->phone,
            'status' => (string) $adminUser->status,
            'two_factor_enabled' => (bool) $adminUser->two_factor_enabled,
        ];
    }

    /**
     * @param array<string, mixed> $admin
     * @return array<string, mixed>
     */
    private function profileFromAdmin(array $admin): array
    {
        return [
            'id' => $admin['id'],
            'name' => $admin['name'],
            'email' => $admin['email'],
            'phone' => $admin['phone'],
            'status' => $admin['status'],
            'two_factor_enabled' => $admin['two_factor_enabled'],
        ];
    }

    private function newToken(string $prefix): string
    {
        return $prefix.'_'.bin2hex(random_bytes(32));
    }

    private function revokeOtherActiveSessions(string $adminUserId): int
    {
        return AdminAuthSession::query()
            ->where('admin_user_id', $adminUserId)
            ->whereNull('revoked_at')
            ->update([
                'revoked_at' => now(),
                'revoked_reason' => self::REVOKED_REASON_REPLACED_BY_NEW_LOGIN,
                'updated_at' => now(),
            ]);
    }

    private function tokenHash(string $token): string
    {
        return hash('sha256', $token);
    }
}
