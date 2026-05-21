<?php

namespace App\Shared\Tenancy\Http\Middleware;

use App\Models\PartnerTenantDomain;
use App\Shared\Tenancy\TenantContext;
use App\Shared\Tenancy\TenantHostNormalizer;
use Closure;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class ResolveTenantByHost
{
    public function __construct(private readonly TenantContext $tenantContext)
    {
    }

    public function handle(Request $request, Closure $next): Response
    {
        $this->tenantContext->clear();

        $host = $this->normalizeHost($request->getHost());
        $record = PartnerTenantDomain::query()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'partner_tenant_domains.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenant_domains.partner_id')
            ->whereIn('partner_tenant_domains.host', TenantHostNormalizer::variants($host))
            ->select([
                'partner_tenant_domains.id as domain_id',
                'partner_tenant_domains.status as domain_status',
                'partner_tenants.id as tenant_id',
                'partner_tenants.status as tenant_status',
                'partners.id as partner_id',
                'partners.status as partner_status',
            ])
            ->first();

        if ($record === null) {
            return $this->error('tenant_not_found', 'Tenant domain was not found.', 404, $request);
        }

        if ($record->domain_status !== config('platform.tenant_resolution.active_domain_status', 'active')) {
            return $this->error('domain_not_active', 'Tenant domain is not active.', 409, $request);
        }

        if (
            $record->tenant_status !== config('platform.tenant_resolution.active_tenant_status', 'active')
            || $record->partner_status !== config('platform.tenant_resolution.active_partner_status', 'active')
        ) {
            return $this->error('tenant_inactive', 'Tenant is not active.', 409, $request);
        }

        $this->tenantContext->set($record->partner_id, $record->tenant_id, $record->domain_id, $host);
        $request->attributes->set('tenant_context', $this->tenantContext);

        return $next($request);
    }

    private function normalizeHost(string $host): string
    {
        return TenantHostNormalizer::normalize($host);
    }

    private function error(string $code, string $message, int $status, Request $request): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => [],
                'request_id' => $request->headers->get('X-Request-Id', ''),
            ],
        ], $status);
    }
}
