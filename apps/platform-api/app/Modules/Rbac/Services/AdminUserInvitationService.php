<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminUser;
use App\Models\AdminUserInvitation;
use App\Models\PartnerTenant;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class AdminUserInvitationService
{
    /**
     * The raw token is returned only when a link is issued. It is never persisted.
     *
     * @return array<string, mixed>
     */
    public function issue(
        AdminUser $adminUser,
        string $scopeType,
        ?string $tenantId,
        ?string $createdByAdminId,
    ): array {
        AdminUserInvitation::query()
            ->where('admin_user_id', $adminUser->id)
            ->where('status', 'pending')
            ->update([
                'status' => 'revoked',
                'updated_at' => now(),
            ]);

        $token = 'adm_inv_'.Str::random(64);
        $expiresAt = now()->addHours(max(1, (int) config('app.admin_invitation_ttl_hours', 168)));

        AdminUserInvitation::query()->create([
            'id' => 'aiv_'.Str::ulid()->toBase32(),
            'admin_user_id' => $adminUser->id,
            'scope_type' => $scopeType,
            'tenant_id' => $scopeType === 'tenant' ? $tenantId : null,
            'token_hash' => hash('sha256', $token),
            'status' => 'pending',
            'expires_at' => $expiresAt,
            'accepted_at' => null,
            'created_by_admin_id' => $createdByAdminId,
        ]);

        $path = '/accept-invitation?token='.rawurlencode($token);
        $backOfficeUrl = rtrim((string) config('app.back_office_url'), '/');

        return [
            'path' => $path,
            'url' => $backOfficeUrl.$path,
            'expires_at' => $expiresAt,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function preview(string $token): ?array
    {
        $invitation = $this->pendingInvitation($token);

        if ($invitation === null) {
            return null;
        }

        $adminUser = AdminUser::query()->find($invitation->admin_user_id);

        if ($adminUser === null || $adminUser->status !== 'invited') {
            return null;
        }

        $tenant = $invitation->tenant_id === null
            ? null
            : PartnerTenant::query()->find($invitation->tenant_id);

        return [
            'name' => (string) $adminUser->name,
            'username' => (string) $adminUser->username,
            'email_masked' => $this->maskEmail((string) $adminUser->email),
            'scope_type' => (string) $invitation->scope_type,
            'tenant_id' => $invitation->tenant_id,
            'tenant_name' => $tenant?->name,
            'expires_at' => $invitation->expires_at,
        ];
    }

    /**
     * @return array{status: string, user?: array<string, mixed>}
     */
    public function accept(string $token, string $password): array
    {
        return DB::transaction(function () use ($token, $password): array {
            $invitation = AdminUserInvitation::query()
                ->where('token_hash', hash('sha256', $token))
                ->lockForUpdate()
                ->first();

            if ($invitation === null) {
                return ['status' => 'invalid'];
            }

            if ($invitation->status === 'accepted') {
                return ['status' => 'used'];
            }

            if ($invitation->status !== 'pending') {
                return ['status' => 'invalid'];
            }

            if ($invitation->expires_at->isPast()) {
                $invitation->update(['status' => 'expired', 'updated_at' => now()]);

                return ['status' => 'expired'];
            }

            $adminUser = AdminUser::query()->whereKey($invitation->admin_user_id)->lockForUpdate()->first();

            if ($adminUser === null || $adminUser->status !== 'invited') {
                return ['status' => 'invalid'];
            }

            $updates = [
                'password_hash' => Hash::make($password),
                'status' => 'active',
                'updated_at' => now(),
            ];

            if (Schema::hasColumn('admin_users', 'must_change_password')) {
                $updates['must_change_password'] = false;
            }

            if (Schema::hasColumn('admin_users', 'password_changed_at')) {
                $updates['password_changed_at'] = now();
            }

            AdminUser::query()->whereKey($adminUser->id)->update($updates);
            $invitation->update([
                'status' => 'accepted',
                'accepted_at' => now(),
                'updated_at' => now(),
            ]);
            AdminUserInvitation::query()
                ->where('admin_user_id', $adminUser->id)
                ->where('id', '!=', $invitation->id)
                ->where('status', 'pending')
                ->update([
                    'status' => 'revoked',
                    'updated_at' => now(),
                ]);

            return [
                'status' => 'accepted',
                'user' => [
                    'id' => (string) $adminUser->id,
                    'username' => (string) $adminUser->username,
                    'scope_type' => (string) $invitation->scope_type,
                    'tenant_id' => $invitation->tenant_id,
                ],
            ];
        });
    }

    public function revokeForUser(string $adminUserId): void
    {
        AdminUserInvitation::query()
            ->where('admin_user_id', $adminUserId)
            ->where('status', 'pending')
            ->update([
                'status' => 'revoked',
                'updated_at' => now(),
            ]);
    }

    private function pendingInvitation(string $token): ?AdminUserInvitation
    {
        $token = trim($token);

        if ($token === '') {
            return null;
        }

        return AdminUserInvitation::query()
            ->where('token_hash', hash('sha256', $token))
            ->where('status', 'pending')
            ->where('expires_at', '>', now())
            ->first();
    }

    private function maskEmail(string $email): string
    {
        [$local, $domain] = array_pad(explode('@', $email, 2), 2, '');
        $visible = mb_substr($local, 0, min(2, mb_strlen($local)));

        return $visible.str_repeat('*', max(3, mb_strlen($local) - mb_strlen($visible))).'@'.$domain;
    }
}
