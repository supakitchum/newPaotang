<?php

namespace App\Modules\Rbac\Services;

use App\Models\AdminUserRole;

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

        if ($this->tenantOwnerRewardClaimPermission($adminUserId, $scopeType, $scopeId, $permissionCode, $tenantId)) {
            return true;
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

        $permissions = $query->pluck('permissions.code')->all();

        foreach (['reward_claim.view', 'reward_claim.approve', 'reward_claim.reject'] as $permissionCode) {
            if ($this->tenantOwnerRewardClaimPermission($adminUserId, $scopeType, $scopeId, $permissionCode, $tenantId)) {
                $permissions[] = $permissionCode;
            }
        }

        $permissions = array_values(array_unique($permissions));
        sort($permissions);

        return $permissions;
    }

    private function tenantOwnerRewardClaimPermission(
        string $adminUserId,
        string $scopeType,
        ?string $scopeId,
        string $permissionCode,
        ?string $tenantId,
    ): bool {
        if ($scopeType !== 'tenant' || ! in_array($permissionCode, ['reward_claim.view', 'reward_claim.approve', 'reward_claim.reject'], true) || $scopeId === null || $tenantId === null) {
            return false;
        }

        return AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->where('admin_user_roles.admin_user_id', $adminUserId)
            ->where('admin_scopes.id', $scopeId)
            ->where('admin_scopes.scope_type', 'tenant')
            ->where('admin_scopes.tenant_id', $tenantId)
            ->where('roles.scope_type', 'tenant')
            ->where('roles.tenant_id', $tenantId)
            ->where('roles.status', 'active')
            ->whereIn('roles.code', ['owner', 'owner_partner'])
            ->exists();
    }
}
