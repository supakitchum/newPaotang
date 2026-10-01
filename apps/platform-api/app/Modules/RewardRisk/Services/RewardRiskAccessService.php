<?php

namespace App\Modules\RewardRisk\Services;

use App\Models\AdminUserRole;
use App\Shared\Auth\AdminSessionContext;

class RewardRiskAccessService
{
    public function isTenantOwner(AdminSessionContext $context): bool
    {
        if ($context->activeScope() !== 'tenant' || $context->activeScopeId() === null || $context->activeTenantId() === null) {
            return false;
        }

        return $this->hasRole($context, ['owner', 'owner_partner']);
    }

    public function isCentralSuperAdmin(AdminSessionContext $context): bool
    {
        return $context->activeScope() === 'central' && $this->hasRole($context, ['super_admin']);
    }

    private function hasRole(AdminSessionContext $context, array $codes): bool
    {
        $query = AdminUserRole::query()
            ->join('admin_scopes', 'admin_scopes.id', '=', 'admin_user_roles.scope_id')
            ->join('roles', 'roles.id', '=', 'admin_user_roles.role_id')
            ->where('admin_user_roles.admin_user_id', (string) $context->adminUser['id'])
            ->where('admin_scopes.id', $context->activeScopeId())
            ->where('admin_scopes.scope_type', $context->activeScope())
            ->where('roles.scope_type', $context->activeScope())
            ->where('roles.status', 'active')
            ->whereIn('roles.code', $codes);

        if ($context->activeScope() === 'tenant') {
            $query->where('admin_scopes.tenant_id', $context->activeTenantId())
                ->where('roles.tenant_id', $context->activeTenantId());
        }

        return $query->exists();
    }
}
