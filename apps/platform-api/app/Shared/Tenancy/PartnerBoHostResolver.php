<?php

namespace App\Shared\Tenancy;

use App\Models\PartnerTenantDomain;
use Illuminate\Http\Request;

class PartnerBoHostResolver
{
    /**
     * @return array{context: array<string, mixed>|null, error: array{status: int, code: string, message: string}|null}
     */
    public function resolve(Request $request): array
    {
        $boHost = $this->hostFromRequest($request);

        if (! str_starts_with($boHost, 'bo.') || strlen($boHost) <= 3) {
            return ['context' => null, 'error' => null];
        }

        $storefrontHost = substr($boHost, 3);
        $record = PartnerTenantDomain::query()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'partner_tenant_domains.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenant_domains.partner_id')
            ->where('partner_tenant_domains.host', $storefrontHost)
            ->select([
                'partner_tenant_domains.id as domain_id',
                'partner_tenant_domains.host as storefront_host',
                'partner_tenant_domains.type as domain_type',
                'partner_tenant_domains.status as domain_status',
                'partner_tenants.id as tenant_id',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
                'partner_tenants.status as tenant_status',
                'partners.id as partner_id',
                'partners.code as partner_code',
                'partners.name as partner_name',
                'partners.status as partner_status',
            ])
            ->first();

        if ($record === null) {
            return [
                'context' => null,
                'error' => ['status' => 404, 'code' => 'tenant_not_found', 'message' => 'Tenant domain was not found.'],
            ];
        }

        if ($record->domain_status !== config('platform.tenant_resolution.active_domain_status', 'active')) {
            return [
                'context' => null,
                'error' => ['status' => 409, 'code' => 'domain_not_active', 'message' => 'Tenant domain is not active.'],
            ];
        }

        if (
            $record->tenant_status !== config('platform.tenant_resolution.active_tenant_status', 'active')
            || $record->partner_status !== config('platform.tenant_resolution.active_partner_status', 'active')
        ) {
            return [
                'context' => null,
                'error' => ['status' => 409, 'code' => 'tenant_inactive', 'message' => 'Tenant is not active.'],
            ];
        }

        return [
            'context' => [
                'mode' => 'partner',
                'partner_id' => (string) $record->partner_id,
                'partner_code' => (string) $record->partner_code,
                'partner_name' => (string) $record->partner_name,
                'tenant_id' => (string) $record->tenant_id,
                'tenant_code' => (string) $record->tenant_code,
                'tenant_name' => (string) $record->tenant_name,
                'domain_id' => (string) $record->domain_id,
                'domain_type' => (string) $record->domain_type,
                'domain_status' => (string) $record->domain_status,
                'storefront_host' => (string) $record->storefront_host,
                'bo_host' => $boHost,
            ],
            'error' => null,
        ];
    }

    public function isPartnerBoHost(Request $request): bool
    {
        $host = $this->hostFromRequest($request);

        return str_starts_with($host, 'bo.') && strlen($host) > 3;
    }

    private function hostFromRequest(Request $request): string
    {
        return $this->normalizeHost((string) ($request->headers->get('Host') ?: $request->getHost()));
    }

    private function normalizeHost(string $host): string
    {
        return strtolower(preg_replace('/:\d+$/', '', trim($host)) ?? $host);
    }
}
