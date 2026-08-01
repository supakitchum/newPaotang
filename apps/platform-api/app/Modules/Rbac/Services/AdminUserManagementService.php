<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminScope;
use App\Models\AdminUser;
use App\Models\AdminUserRole;
use App\Models\PartnerTenant;
use App\Models\Role;
use App\Models\RolePermission;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;

class AdminUserManagementService
{
    private const PROTECTED_PLATFORM_ADMIN_IDS = ['adm_platform_owner'];
    private const PROTECTED_PLATFORM_ADMIN_EMAILS = ['superadmin@newpaotang.test'];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly AdminUserInvitationService $invitations,
    ) {
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function listUsers(string $scopeType, ?string $tenantId): array
    {
        $rows = $this->scopedUserQuery($scopeType, $tenantId)
            ->orderBy('admin_users.email')
            ->get($this->userColumns())
            ->all();

        return array_map(fn (object $user): array => $this->userResource($user, $scopeType, $tenantId), $rows);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findUser(string $scopeType, ?string $tenantId, string $adminUserId): ?array
    {
        $user = $this->scopedUserQuery($scopeType, $tenantId)
            ->where('admin_users.id', $adminUserId)
            ->first($this->userColumns());

        if ($user === null) {
            return null;
        }

        return $this->userResource($user, $scopeType, $tenantId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validatePayload(string $scopeType, ?string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        if ($creating || array_key_exists('name', $payload)) {
            $name = trim((string) ($payload['name'] ?? ''));

            if ($name === '') {
                $errors['name'][] = 'The name field is required.';
            }
        }

        if ($creating || array_key_exists('email', $payload)) {
            $email = strtolower(trim((string) ($payload['email'] ?? '')));

            if ($email === '' || filter_var($email, FILTER_VALIDATE_EMAIL) === false) {
                $errors['email'][] = 'The email field must be a valid email address.';
            }
        }

        if ($creating || array_key_exists('username', $payload)) {
            $username = $this->normalizeUsername($payload['username'] ?? '');

            if ($username === '') {
                $errors['username'][] = 'The username field is required.';
            } elseif (preg_match('/\A[a-z0-9][a-z0-9._-]{2,49}\z/', $username) !== 1) {
                $errors['username'][] = 'The username must be 3-50 characters using lowercase letters, numbers, dots, underscores, or hyphens.';
            }
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], ['active', 'invited', 'suspended', 'disabled'], true)) {
            $errors['status'][] = 'The status field must be active, invited, suspended, or disabled.';
        }

        if ($creating && array_key_exists('status', $payload) && $payload['status'] !== 'invited') {
            $errors['status'][] = 'New admin users must activate their account through an invitation link.';
        }

        if (array_key_exists('password', $payload)) {
            $errors['password'][] = 'Admin passwords must be created by the recipient through an invitation link.';
        }

        if ($creating || array_key_exists('role_ids', $payload)) {
            if (! array_key_exists('role_ids', $payload) || ! is_array($payload['role_ids'])) {
                $errors['role_ids'][] = 'The role_ids field must be an array.';
            } elseif ($creating && $payload['role_ids'] === []) {
                $errors['role_ids'][] = 'The role_ids field must contain at least one role.';
            } else {
                foreach ($payload['role_ids'] as $roleId) {
                    if (! is_string($roleId) || trim($roleId) === '') {
                        $errors['role_ids'][] = 'Each role id must be a non-empty string.';
                        break;
                    }
                }

                $invalidRoleIds = $this->invalidRoleIds($scopeType, $tenantId, $payload['role_ids']);

                if ($invalidRoleIds !== []) {
                    $errors['role_ids'][] = 'Invalid role ids for '.$scopeType.' scope: '.implode(', ', $invalidRoleIds).'.';
                }
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function transitionErrors(array $currentUser, array $payload): array
    {
        if (
            ($currentUser['status'] ?? null) === 'invited'
            && ($payload['status'] ?? null) === 'active'
        ) {
            return [
                'status' => ['Invited admin users must activate their account through an invitation link.'],
            ];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function conflictErrors(string $scopeType, ?string $tenantId, array $payload, ?string $adminUserId = null): array
    {
        $errors = [];

        if (array_key_exists('email', $payload)) {
            $email = strtolower(trim((string) $payload['email']));

            if ($email !== '') {
                $query = AdminUser::query()->where('email', $email);

                if ($adminUserId !== null) {
                    $query->where('id', '!=', $adminUserId);
                }

                if ($query->exists()) {
                    $errors['email'][] = 'The email address already exists.';
                }
            }
        }

        if (array_key_exists('username', $payload)) {
            $username = $this->normalizeUsername($payload['username']);

            if ($username !== '') {
                $query = AdminUser::query()->where('username', $username);

                if ($adminUserId !== null) {
                    $query->where('id', '!=', $adminUserId);
                }

                if ($query->exists()) {
                    $errors['username'][] = 'The username already exists.';
                }
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createUser(string $scopeType, ?string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($scopeType, $tenantId, $payload, $actor, $request): array {
            $adminUserId = 'adm_'.Str::ulid()->toBase32();
            $scopeId = $this->scopeIdFor($scopeType, $tenantId);
            $now = now();

            AdminUser::query()->create(array_merge([
                'id' => $adminUserId,
                'name' => trim((string) $payload['name']),
                'email' => strtolower(trim((string) $payload['email'])),
                'username' => $this->normalizeUsername($payload['username']),
                'phone' => $payload['phone'] ?? null,
                'password_hash' => Hash::make(Str::random(64)),
                'status' => 'invited',
                'two_factor_enabled' => false,
                'created_at' => $now,
                'updated_at' => $now,
            ], $this->forcedPasswordColumns(true, null)));

            $this->syncRoleAssignments($adminUserId, $scopeId, $payload['role_ids']);
            $this->invalidatePermissionCache($adminUserId, $scopeId);
            $this->auditAdminUserChange($actor, $request, $scopeType, $tenantId, $adminUserId, 'created', $payload);

            $user = $this->findUser($scopeType, $tenantId, $adminUserId);
            $invitation = $this->invitations->issue(
                AdminUser::query()->findOrFail($adminUserId),
                $scopeType,
                $tenantId,
                $actor->adminUser['id'],
            );

            return array_merge($user, ['invitation' => $invitation]);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateUser(string $scopeType, ?string $tenantId, string $adminUserId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($scopeType, $tenantId, $adminUserId, $payload, $actor, $request): ?array {
            if ($this->findUser($scopeType, $tenantId, $adminUserId) === null) {
                return null;
            }

            $scopeId = $this->scopeIdFor($scopeType, $tenantId);
            $updates = ['updated_at' => now()];

            foreach (['name', 'phone', 'status'] as $field) {
                if (array_key_exists($field, $payload)) {
                    $updates[$field] = $payload[$field];
                }
            }

            if (array_key_exists('email', $payload)) {
                $updates['email'] = strtolower(trim((string) $payload['email']));
            }

            if (array_key_exists('username', $payload)) {
                $updates['username'] = $this->normalizeUsername($payload['username']);
            }

            AdminUser::query()->whereKey($adminUserId)->update($updates);

            if (array_key_exists('role_ids', $payload)) {
                $this->syncRoleAssignments($adminUserId, $scopeId, $payload['role_ids']);
                $this->invalidatePermissionCache($adminUserId, $scopeId);
            }

            $this->auditAdminUserChange($actor, $request, $scopeType, $tenantId, $adminUserId, 'updated', $payload);

            return $this->findUser($scopeType, $tenantId, $adminUserId);
        });
    }

    public function disableUser(string $scopeType, ?string $tenantId, string $adminUserId, AdminSessionContext $actor, Request $request): bool
    {
        return DB::transaction(function () use ($scopeType, $tenantId, $adminUserId, $actor, $request): bool {
            if ($this->findUser($scopeType, $tenantId, $adminUserId) === null) {
                return false;
            }

            $scopeId = $this->scopeIdFor($scopeType, $tenantId);

            AdminUserRole::query()
                ->where('admin_user_id', $adminUserId)
                ->where('scope_id', $scopeId)
                ->delete();

            $this->invalidatePermissionCache($adminUserId, $scopeId);
            $this->invitations->revokeForUser($adminUserId);

            if (! AdminUserRole::where('admin_user_id', $adminUserId)->exists()) {
                AdminUser::query()
                    ->whereKey($adminUserId)
                    ->update([
                        'status' => 'disabled',
                        'updated_at' => now(),
                    ]);
            }

            $this->auditAdminUserChange($actor, $request, $scopeType, $tenantId, $adminUserId, 'disabled', []);

            return true;
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function issueInvitation(
        string $scopeType,
        ?string $tenantId,
        string $adminUserId,
        AdminSessionContext $actor,
        Request $request,
    ): ?array {
        return DB::transaction(function () use ($scopeType, $tenantId, $adminUserId, $actor, $request): ?array {
            $user = $this->findUser($scopeType, $tenantId, $adminUserId);

            if ($user === null || $user['status'] !== 'invited') {
                return null;
            }

            $invitation = $this->invitations->issue(
                AdminUser::query()->findOrFail($adminUserId),
                $scopeType,
                $tenantId,
                $actor->adminUser['id'],
            );
            $this->auditAdminUserChange(
                $actor,
                $request,
                $scopeType,
                $tenantId,
                $adminUserId,
                'invitation.issued',
                [],
            );

            return array_merge($user, ['invitation' => $invitation]);
        });
    }

    private function scopedUserQuery(string $scopeType, ?string $tenantId): \Illuminate\Database\Eloquent\Builder
    {
        $query = AdminUser::query()
            ->join('admin_user_roles', 'admin_user_roles.admin_user_id', '=', 'admin_users.id')
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->where('admin_scopes.scope_type', $scopeType)
            ->whereNotIn('admin_users.id', self::PROTECTED_PLATFORM_ADMIN_IDS)
            ->whereNotIn('admin_users.email', self::PROTECTED_PLATFORM_ADMIN_EMAILS)
            ->distinct();

        return $scopeType === 'tenant'
            ? $query->where('admin_scopes.tenant_id', $tenantId)
            : $query->whereNull('admin_scopes.tenant_id');
    }

    /**
     * @return array<int, string>
     */
    private function userColumns(): array
    {
        $columns = [
            'admin_users.id',
            'admin_users.name',
            'admin_users.email',
            'admin_users.username',
            'admin_users.phone',
            'admin_users.status',
            'admin_users.two_factor_enabled',
            'admin_users.created_at',
            'admin_users.updated_at',
        ];

        return $columns;
    }

    /**
     * @param array<int, string> $roleIds
     * @return array<int, string>
     */
    private function invalidRoleIds(string $scopeType, ?string $tenantId, array $roleIds): array
    {
        $ids = array_values(array_unique(array_map(
            fn (mixed $roleId): string => is_string($roleId) ? trim($roleId) : '',
            $roleIds,
        )));

        $ids = array_values(array_filter($ids, fn (string $roleId): bool => $roleId !== ''));

        if ($ids === []) {
            return [];
        }

        $query = Role::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active')
            ->whereIn('id', $ids);

        $scopeType === 'tenant'
            ? $query->where('tenant_id', $tenantId)
            : $query->whereNull('tenant_id');

        $validIds = $query->pluck('id')->all();

        return array_values(array_diff($ids, $validIds));
    }

    /**
     * @param array<int, string> $roleIds
     */
    private function syncRoleAssignments(string $adminUserId, string $scopeId, array $roleIds): void
    {
        AdminUserRole::query()
            ->where('admin_user_id', $adminUserId)
            ->where('scope_id', $scopeId)
            ->delete();

        $roleIds = array_values(array_unique(array_map(fn (string $roleId): string => trim($roleId), $roleIds)));

        if ($roleIds === []) {
            return;
        }

        AdminUserRole::query()->insert(array_map(fn (string $roleId): array => [
            'admin_user_id' => $adminUserId,
            'role_id' => $roleId,
            'scope_id' => $scopeId,
            'created_at' => now(),
            'updated_at' => now(),
        ], $roleIds));
    }

    private function invalidatePermissionCache(string $adminUserId, string $scopeId): void
    {
        $updated = AdminPermissionCacheVersion::query()
            ->where('admin_user_id', $adminUserId)
            ->where('scope_id', $scopeId)
            ->increment('version', 1, ['updated_at' => now()]);

        if ($updated > 0) {
            return;
        }

        AdminPermissionCacheVersion::query()->insert([
            'id' => 'pcv_'.substr(sha1($adminUserId.':'.$scopeId), 0, 20),
            'admin_user_id' => $adminUserId,
            'scope_id' => $scopeId,
            'version' => 2,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }

    private function scopeIdFor(string $scopeType, ?string $tenantId): string
    {
        $query = AdminScope::query()->where('scope_type', $scopeType);
        $scopeType === 'tenant' ? $query->where('tenant_id', $tenantId) : $query->whereNull('tenant_id');

        $scopeId = $query->value('id');

        if ($scopeId !== null) {
            return (string) $scopeId;
        }

        $id = $scopeType === 'tenant'
            ? 'scp_t_'.substr(sha1((string) $tenantId), 0, 20)
            : 'scp_c_default';

        $partnerId = null;

        if ($scopeType === 'tenant') {
            $partnerId = PartnerTenant::whereKey($tenantId)->value('partner_id');
        }

        AdminScope::query()->insert([
            'id' => $id,
            'scope_type' => $scopeType,
            'tenant_id' => $scopeType === 'tenant' ? $tenantId : null,
            'partner_id' => $partnerId,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        return $id;
    }

    /**
     * @return array<string, mixed>
     */
    private function userResource(object $user, string $scopeType, ?string $tenantId): array
    {
        $roles = $this->rolesForUser($user->id, $scopeType, $tenantId);

        $permissions = [];

        foreach ($roles as $role) {
            $permissions = array_merge($permissions, $role['permissions']);
        }

        $permissions = array_values(array_unique($permissions));
        sort($permissions);

        return [
            'id' => (string) $user->id,
            'tenant_id' => $scopeType === 'tenant' ? $tenantId : null,
            'name' => (string) $user->name,
            'email' => (string) $user->email,
            'username' => (string) $user->username,
            'phone' => $user->phone,
            'status' => (string) $user->status,
            'roles' => $roles,
            'permissions' => $permissions,
            'last_login_at' => null,
            'created_at' => $user->created_at,
            'updated_at' => $user->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function forcedPasswordColumns(bool $mustChange, mixed $changedAt): array
    {
        $columns = [];

        if (Schema::hasColumn('admin_users', 'must_change_password')) {
            $columns['must_change_password'] = $mustChange;
        }

        if (Schema::hasColumn('admin_users', 'password_changed_at')) {
            $columns['password_changed_at'] = $changedAt;
        }

        return $columns;
    }

    private function normalizeUsername(mixed $username): string
    {
        return strtolower(trim((string) $username));
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function rolesForUser(string $adminUserId, string $scopeType, ?string $tenantId): array
    {
        $query = AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->where('admin_user_roles.admin_user_id', $adminUserId)
            ->where('admin_scopes.scope_type', $scopeType)
            ->where('roles.scope_type', $scopeType)
            ->select('roles.id', 'roles.tenant_id', 'roles.code', 'roles.name', 'roles.status', 'roles.version', 'roles.created_at', 'roles.updated_at')
            ->orderBy('roles.code');

        if ($scopeType === 'tenant') {
            $query->where('admin_scopes.tenant_id', $tenantId)
                ->where('roles.tenant_id', $tenantId);
        } else {
            $query->whereNull('admin_scopes.tenant_id')
                ->whereNull('roles.tenant_id');
        }

        $roles = $query->get()->all();
        $permissionsByRole = $this->permissionsByRoleIds(array_map(fn (object $role): string => (string) $role->id, $roles));

        return array_map(function (object $role) use ($permissionsByRole): array {
            return [
                'id' => (string) $role->id,
                'tenant_id' => $role->tenant_id,
                'code' => (string) $role->code,
                'name' => (string) $role->name,
                'description' => null,
                'permissions' => $permissionsByRole[(string) $role->id] ?? [],
                'status' => (string) $role->status,
                'version' => (int) $role->version,
                'system_role' => in_array($role->code, ['super_admin', 'admin', 'owner'], true),
                'created_at' => $role->created_at,
                'updated_at' => $role->updated_at,
            ];
        }, $roles);
    }

    /**
     * @param array<int, string> $roleIds
     * @return array<string, array<int, string>>
     */
    private function permissionsByRoleIds(array $roleIds): array
    {
        if ($roleIds === []) {
            return [];
        }

        $rows = RolePermission::query()
            ->join('permissions', 'permissions.id', '=', 'role_permissions.permission_id')
            ->whereIn('role_permissions.role_id', $roleIds)
            ->orderBy('permissions.code')
            ->get(['role_permissions.role_id', 'permissions.code']);

        $permissionsByRole = [];

        foreach ($rows as $row) {
            $permissionsByRole[(string) $row->role_id][] = (string) $row->code;
        }

        return $permissionsByRole;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditAdminUserChange(
        AdminSessionContext $actor,
        Request $request,
        string $scopeType,
        ?string $tenantId,
        string $adminUserId,
        string $changeType,
        array $payload,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: $scopeType,
            action: 'admin_user.changed',
            targetType: 'admin_user',
            targetId: $adminUserId,
            payload: [
                'change_type' => $changeType,
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            tenantId: $tenantId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}
