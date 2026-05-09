<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminUserRole;
use Illuminate\Support\Facades\DB;

class PermissionService
{
    public function adminHasPermission(
        string $adminUserId,
        string $scopeType,
        ?string $scopeId,
        string $permissionCode,
        ?string $tenantId = null,
    ): bool {
        if ($adminUserId === '' || $permissionCode === '' || ! in_array($scopeType, ['central', 'tenant'], true)) {
            return false;
        }

        if ($scopeType === 'tenant' && ($scopeId === null || $tenantId === null)) {
            return false;
        }

        $query = AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->join('role_permissions', 'role_permissions.role_id', '=', 'roles.id')
            ->join('permissions', 'permissions.id', '=', 'role_permissions.permission_id')
            ->where('admin_user_roles.admin_user_id', $adminUserId)
            ->where('admin_scopes.scope_type', $scopeType)
            ->where('roles.scope_type', $scopeType)
            ->where('permissions.scope_type', $scopeType)
            ->where('roles.status', 'active')
            ->where('permissions.status', 'active')
            ->where('permissions.code', $permissionCode);

        if ($scopeId !== null) {
            $query->where('admin_scopes.id', $scopeId);
        }

        if ($scopeType === 'tenant') {
            $query->where('admin_scopes.tenant_id', $tenantId)
                ->where('roles.tenant_id', $tenantId);
        }

        return $query->exists();
    }

    /**
     * @return array<int, string>
     */
    public function permissionsForAdminScope(
        string $adminUserId,
        string $scopeType,
        ?string $scopeId,
        ?string $tenantId = null,
    ): array {
        if ($adminUserId === '' || ! in_array($scopeType, ['central', 'tenant'], true)) {
            return [];
        }

        if ($scopeType === 'tenant' && ($scopeId === null || $tenantId === null)) {
            return [];
        }

        $query = AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->join('role_permissions', 'role_permissions.role_id', '=', 'roles.id')
            ->join('permissions', 'permissions.id', '=', 'role_permissions.permission_id')
            ->where('admin_user_roles.admin_user_id', $adminUserId)
            ->where('admin_scopes.scope_type', $scopeType)
            ->where('roles.scope_type', $scopeType)
            ->where('permissions.scope_type', $scopeType)
            ->where('roles.status', 'active')
            ->where('permissions.status', 'active')
            ->select('permissions.code')
            ->distinct()
            ->orderBy('permissions.code');

        if ($scopeId !== null) {
            $query->where('admin_scopes.id', $scopeId);
        }

        if ($scopeType === 'tenant') {
            $query->where('admin_scopes.tenant_id', $tenantId)
                ->where('roles.tenant_id', $tenantId);
        }

        return $query->pluck('permissions.code')->all();
    }
}
