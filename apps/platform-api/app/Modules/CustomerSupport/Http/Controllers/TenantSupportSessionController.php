<?php

namespace App\Modules\CustomerSupport\Http\Controllers;

use App\Models\PartnerTenant;
use App\Modules\CustomerSupport\Services\SupportSessionTokenService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantSupportSessionController extends Controller
{
    private const SUPPORT_PERMISSIONS = [
        'support_ticket.view_assigned',
        'support_ticket.reply_assigned',
        'support_ticket.close_assigned',
        'support_ticket.view_all',
        'support_ticket.assign',
        'support_agent.manage',
        'support_faq.view',
        'support_faq.manage',
        'support_report.view',
    ];

    public function __construct(
        private readonly SupportSessionTokenService $tokens,
        private readonly PermissionService $permissions,
    ) {
    }

    public function store(Request $request): JsonResponse
    {
        $context = $request->attributes->get('admin_session');
        if (! $context instanceof AdminSessionContext || $context->activeScope() !== 'tenant' || $context->activeTenantId() === null) {
            return ApiErrorResponse::permissionDenied($request);
        }
        $tenantId = (string) $context->activeTenantId();
        $permissions = array_values(array_intersect(
            self::SUPPORT_PERMISSIONS,
            $this->permissions->permissionsForAdminScope(
                (string) $context->adminUser['id'],
                'tenant',
                $context->activeScopeId(),
                $tenantId,
            ),
        ));
        if ($permissions === []) {
            return ApiErrorResponse::permissionDenied($request);
        }
        $tenant = PartnerTenant::query()->find($tenantId);
        if ($tenant === null) {
            return ApiErrorResponse::notFound($request);
        }
        $session = $this->tokens->issue([
            'sub' => (string) $context->adminUser['id'],
            'tenant_id' => $tenantId,
            'actor_type' => 'admin',
            'name' => (string) ($context->adminUser['name'] ?? $context->adminUser['username'] ?? ''),
            'tenant_name' => (string) $tenant->name,
            'locale' => (string) ($context->adminUser['preferred_locale'] ?? 'th-TH'),
            'support_enabled' => true,
            'permissions' => $permissions,
        ]);

        return response()->json([
            ...$session,
            'api_url' => (string) config('support.api_url'),
            'realtime' => [
                'url' => (string) config('support.realtime_url'),
                'key' => (string) config('support.realtime_key'),
                'auth_path' => '/admin/realtime/auth',
                'channel_prefix' => 'private-support.tenant.'.$tenantId,
                'channels' => array_values(array_filter([
                    'private-support.tenant.'.$tenantId.'.admin.'.(string) $context->adminUser['id'],
                    in_array('support_ticket.view_all', $permissions, true)
                        ? 'private-support.tenant.'.$tenantId.'.queue'
                        : null,
                ])),
            ],
        ]);
    }
}
