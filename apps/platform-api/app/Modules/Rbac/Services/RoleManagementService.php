<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminPermissionCacheVersion;
use App\Models\AdminUserRole;
use App\Models\Permission;
use App\Models\Role;
use App\Models\RolePermission;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Database\Eloquent\Builder as EloquentBuilder;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class RoleManagementService
{
    public function __construct(private readonly AuditLogger $auditLogger)
    {
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function listRoles(string $scopeType, ?string $tenantId): array
    {
        $query = Role::query()
            ->where('scope_type', $scopeType)
            ->orderBy('code');

        $scopeType === 'tenant'
            ? $query->where('tenant_id', $tenantId)
            : $query->whereNull('tenant_id');

        return $this->hydrateRoles($query->get()->all());
    }

    /**
     * @return array<int, array{code: string, name: string}>
     */
    public function listAvailablePermissions(string $scopeType): array
    {
        return Permission::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active')
            ->orderBy('code')
            ->get(['code', 'name'])
            ->map(fn (Permission $permission): array => [
                'code' => (string) $permission->code,
                'name' => (string) $permission->name,
            ])
            ->all();
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validatePayload(string $scopeType, array $payload, bool $creating): array
    {
        $errors = [];

        if ($creating || array_key_exists('name', $payload)) {
            $name = trim((string) ($payload['name'] ?? ''));

            if ($name === '') {
                $errors['name'][] = 'The name field is required.';
            }
        }

        if (array_key_exists('code', $payload)) {
            $code = trim((string) $payload['code']);

            if ($code === '' || ! preg_match('/^[a-z0-9_]+$/', $code)) {
                $errors['code'][] = 'The code field must use lowercase letters, numbers, and underscores only.';
            }
        }

        if ($creating || array_key_exists('permissions', $payload)) {
            if (! array_key_exists('permissions', $payload) || ! is_array($payload['permissions'])) {
                $errors['permissions'][] = 'The permissions field must be an array.';
            } else {
                foreach ($payload['permissions'] as $permission) {
                    if (! is_string($permission) || trim($permission) === '') {
                        $errors['permissions'][] = 'Each permission must be a non-empty string.';
                        break;
                    }
                }

                $invalidPermissions = $this->invalidPermissionCodes($scopeType, $payload['permissions']);

                if ($invalidPermissions !== []) {
                    $errors['permissions'][] = 'Invalid permission codes for '.$scopeType.' scope: '.implode(', ', $invalidPermissions).'.';
                }
            }
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], ['active', 'archived'], true)) {
            $errors['status'][] = 'The status field must be active or archived.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function conflictErrors(string $scopeType, ?string $tenantId, array $payload, ?string $ignoreRoleId = null): array
    {
        $errors = [];

        if (array_key_exists('name', $payload)) {
            $name = trim((string) $payload['name']);

            if ($name !== '' && $this->roleExists($scopeType, $tenantId, 'name', $name, $ignoreRoleId)) {
                $errors['name'][] = 'The role name already exists in this scope.';
            }
        }

        $code = null;

        if (array_key_exists('code', $payload)) {
            $code = trim((string) $payload['code']);
        } elseif ($ignoreRoleId === null && array_key_exists('name', $payload)) {
            $code = $this->codeFromName((string) $payload['name']);
        }

        if ($code !== null && $code !== '' && $this->roleExists($scopeType, $tenantId, 'code', $code, $ignoreRoleId)) {
            $errors['code'][] = 'The role code already exists in this scope.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createRole(string $scopeType, ?string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($scopeType, $tenantId, $payload, $actor, $request): array {
            $roleId = 'rol_'.Str::ulid()->toBase32();
            $now = now();
            $permissionIds = $this->permissionIds($scopeType, $payload['permissions']);

            Role::query()->insert([
                'id' => $roleId,
                'scope_type' => $scopeType,
                'tenant_id' => $scopeType === 'tenant' ? $tenantId : null,
                'code' => $payload['code'] ?? $this->codeFromName((string) $payload['name']),
                'name' => trim((string) $payload['name']),
                'status' => $payload['status'] ?? 'active',
                'version' => 1,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->syncRolePermissions($roleId, $permissionIds);

            $this->auditRoleChange($actor, $request, $scopeType, $tenantId, $roleId, 'created', $payload);

            return $this->findRole($scopeType, $tenantId, $roleId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateRole(string $scopeType, ?string $tenantId, string $roleId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($scopeType, $tenantId, $roleId, $payload, $actor, $request): ?array {
            $role = $this->roleQuery($scopeType, $tenantId)
                ->where('id', $roleId)
                ->lockForUpdate()
                ->first();

            if ($role === null) {
                return null;
            }

            $updates = ['updated_at' => now(), 'version' => ((int) $role->version) + 1];

            if (array_key_exists('name', $payload)) {
                $updates['name'] = trim((string) $payload['name']);
            }

            if (array_key_exists('code', $payload)) {
                $updates['code'] = trim((string) $payload['code']);
            }

            if (array_key_exists('status', $payload)) {
                $updates['status'] = $payload['status'];
            }

            Role::query()->where('id', $roleId)->update($updates);

            if (array_key_exists('permissions', $payload)) {
                $this->syncRolePermissions($roleId, $this->permissionIds($scopeType, $payload['permissions']));
            }

            $this->invalidateAssignedAdminPermissionCaches($roleId);
            $this->auditRoleChange($actor, $request, $scopeType, $tenantId, $roleId, 'updated', $payload);

            return $this->findRole($scopeType, $tenantId, $roleId);
        });
    }

    public function archiveRole(string $scopeType, ?string $tenantId, string $roleId, AdminSessionContext $actor, Request $request): bool
    {
        return DB::transaction(function () use ($scopeType, $tenantId, $roleId, $actor, $request): bool {
            $role = $this->roleQuery($scopeType, $tenantId)
                ->where('id', $roleId)
                ->lockForUpdate()
                ->first();

            if ($role === null) {
                return false;
            }

            Role::query()
                ->where('id', $roleId)
                ->update([
                    'status' => 'archived',
                    'version' => ((int) $role->version) + 1,
                    'updated_at' => now(),
                ]);

            $this->invalidateAssignedAdminPermissionCaches($roleId);
            $this->auditRoleChange($actor, $request, $scopeType, $tenantId, $roleId, 'archived', []);

            return true;
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findRole(string $scopeType, ?string $tenantId, string $roleId): ?array
    {
        $role = $this->roleQuery($scopeType, $tenantId)
            ->where('id', $roleId)
            ->first();

        if ($role === null) {
            return null;
        }

        return $this->roleResource($role, $this->permissionsByRoleIds([$roleId])[$roleId] ?? []);
    }

    /**
     * @param array<int, object> $roles
     * @return array<int, array<string, mixed>>
     */
    private function hydrateRoles(array $roles): array
    {
        $permissionsByRole = $this->permissionsByRoleIds(array_map(fn (object $role): string => (string) $role->id, $roles));

        return array_map(
            fn (object $role): array => $this->roleResource($role, $permissionsByRole[(string) $role->id] ?? []),
            $roles,
        );
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
     * @param array<int, string> $permissions
     * @return array<int, string>
     */
    private function invalidPermissionCodes(string $scopeType, array $permissions): array
    {
        $codes = array_values(array_unique(array_map(
            fn (mixed $permission): string => is_string($permission) ? trim($permission) : '',
            $permissions,
        )));

        $codes = array_values(array_filter($codes, fn (string $code): bool => $code !== ''));

        if ($codes === []) {
            return [];
        }

        $validCodes = Permission::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active')
            ->whereIn('code', $codes)
            ->pluck('code')
            ->all();

        return array_values(array_diff($codes, $validCodes));
    }

    /**
     * @param array<int, string> $permissions
     * @return array<int, string>
     */
    private function permissionIds(string $scopeType, array $permissions): array
    {
        $codes = array_values(array_unique(array_map(fn (string $permission): string => trim($permission), $permissions)));
        sort($codes);

        return Permission::query()
            ->where('scope_type', $scopeType)
            ->where('status', 'active')
            ->whereIn('code', $codes)
            ->orderBy('code')
            ->pluck('id')
            ->all();
    }

    /**
     * @param array<int, string> $permissionIds
     */
    private function syncRolePermissions(string $roleId, array $permissionIds): void
    {
        RolePermission::query()->where('role_id', $roleId)->delete();

        if ($permissionIds === []) {
            return;
        }

        RolePermission::query()->insert(array_map(fn (string $permissionId): array => [
            'role_id' => $roleId,
            'permission_id' => $permissionId,
            'created_at' => now(),
            'updated_at' => now(),
        ], $permissionIds));
    }

    private function invalidateAssignedAdminPermissionCaches(string $roleId): void
    {
        $assignments = AdminUserRole::query()
            ->where('role_id', $roleId)
            ->get(['admin_user_id', 'scope_id']);

        foreach ($assignments as $assignment) {
            $updated = AdminPermissionCacheVersion::query()
                ->where('admin_user_id', $assignment->admin_user_id)
                ->where('scope_id', $assignment->scope_id)
                ->increment('version', 1, ['updated_at' => now()]);

            if ($updated > 0) {
                continue;
            }

            AdminPermissionCacheVersion::query()->insert([
                'id' => 'pcv_'.substr(sha1($assignment->admin_user_id.':'.$assignment->scope_id), 0, 20),
                'admin_user_id' => $assignment->admin_user_id,
                'scope_id' => $assignment->scope_id,
                'version' => 2,
                'created_at' => now(),
                'updated_at' => now(),
            ]);
        }
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditRoleChange(
        AdminSessionContext $actor,
        Request $request,
        string $scopeType,
        ?string $tenantId,
        string $roleId,
        string $changeType,
        array $payload,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: $scopeType,
            action: 'role.changed',
            targetType: 'role',
            targetId: $roleId,
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

    private function roleQuery(string $scopeType, ?string $tenantId): EloquentBuilder
    {
        $query = Role::query()->where('scope_type', $scopeType);

        return $scopeType === 'tenant'
            ? $query->where('tenant_id', $tenantId)
            : $query->whereNull('tenant_id');
    }

    private function roleExists(string $scopeType, ?string $tenantId, string $column, string $value, ?string $ignoreRoleId = null): bool
    {
        $query = $this->roleQuery($scopeType, $tenantId)
            ->where($column, $value);

        if ($ignoreRoleId !== null) {
            $query->where('id', '!=', $ignoreRoleId);
        }

        return $query->exists();
    }

    /**
     * @param array<int, string> $permissions
     * @return array<string, mixed>
     */
    private function roleResource(object $role, array $permissions): array
    {
        return [
            'id' => (string) $role->id,
            'tenant_id' => $role->tenant_id,
            'code' => (string) $role->code,
            'name' => (string) $role->name,
            'description' => null,
            'permissions' => $permissions,
            'status' => (string) $role->status,
            'version' => (int) $role->version,
            'system_role' => in_array($role->code, ['super_admin', 'admin', 'owner'], true),
            'created_at' => $role->created_at,
            'updated_at' => $role->updated_at,
        ];
    }

    private function codeFromName(string $name): string
    {
        $code = trim((string) preg_replace('/[^a-z0-9]+/', '_', strtolower($name)), '_');

        return $code !== '' ? $code : 'role';
    }
}
