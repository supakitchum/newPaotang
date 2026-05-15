<?php

namespace App\Shared\Auth;

use App\Modules\Auth\Services\AdminAuthService;
use App\Models\AdminAuthSession;
use App\Models\AdminUser;

class AdminSessionResolver
{
    /**
     * @var array{code: string, message: string}|null
     */
    private ?array $failure = null;

    public function __construct(private readonly AdminAuthService $authService)
    {
    }

    public function resolveAccessToken(?string $accessToken): ?AdminSessionContext
    {
        $this->failure = null;

        if ($accessToken === null || $accessToken === '') {
            return null;
        }

        $accessTokenHash = hash('sha256', $accessToken);
        $session = AdminAuthSession::where('access_token_hash', $accessTokenHash)
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>', now())
            ->first();

        if ($session === null) {
            $revokedSession = AdminAuthSession::query()
                ->where('access_token_hash', $accessTokenHash)
                ->whereNotNull('revoked_at')
                ->first();

            if ($revokedSession !== null && $revokedSession->revoked_reason === AdminAuthService::REVOKED_REASON_REPLACED_BY_NEW_LOGIN) {
                $this->failure = [
                    'code' => 'admin_session_replaced',
                    'message' => 'มีการเข้าสู่ระบบจากอุปกรณ์อื่น กรุณาเข้าสู่ระบบใหม่',
                ];
            }

            return null;
        }

        $adminUser = AdminUser::whereKey($session->admin_user_id)
            ->where('status', 'active')
            ->first();

        if ($adminUser === null) {
            return null;
        }

        if (! $this->authService->sessionScopeIsUsable((string) $session->scope_type, $session->scope_id, $session->tenant_id)) {
            AdminAuthSession::query()
                ->where('id', $session->id)
                ->update([
                    'revoked_at' => now(),
                    'updated_at' => now(),
                ]);

            return null;
        }

        AdminAuthSession::query()
            ->where('id', $session->id)
            ->update([
                'last_used_at' => now(),
                'updated_at' => now(),
            ]);

        return new AdminSessionContext(
            session: [
                'id' => (string) $session->id,
                'admin_user_id' => (string) $session->admin_user_id,
                'scope_type' => (string) $session->scope_type,
                'scope_id' => $session->scope_id,
                'tenant_id' => $session->tenant_id,
            ],
            adminUser: [
                'id' => (string) $adminUser->id,
                'name' => $adminUser->name !== null && $adminUser->name !== '' ? (string) $adminUser->name : (string) $adminUser->email,
                'email' => (string) $adminUser->email,
                'phone' => $adminUser->phone,
                'status' => (string) $adminUser->status,
                'two_factor_enabled' => (bool) $adminUser->two_factor_enabled,
            ],
            scopes: $this->authService->scopesForAdmin((string) $adminUser->id),
        );
    }

    /**
     * @return array{code: string, message: string}|null
     */
    public function failure(): ?array
    {
        return $this->failure;
    }
}
