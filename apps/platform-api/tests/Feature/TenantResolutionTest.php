<?php

namespace Tests\Feature;

use App\Shared\Tenancy\Http\Middleware\ResolveTenantByHost;
use App\Shared\Tenancy\TenantContext;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class TenantResolutionTest extends TestCase
{
    use RefreshDatabase;

    public function test_unknown_host_returns_safe_tenant_not_found_error(): void
    {
        $request = Request::create('/probe', 'GET', [], [], [], ['HTTP_HOST' => 'missing.example.test']);
        $response = app(ResolveTenantByHost::class)->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(404, $response->getStatusCode());
        $this->assertSame('tenant_not_found', $response->getData(true)['error']['code']);
    }

    public function test_inactive_domain_returns_safe_domain_error(): void
    {
        $this->seedTenant(domainStatus: 'suspended');

        $request = Request::create('/probe', 'GET', [], [], [], ['HTTP_HOST' => 'tenant.example.test']);
        $response = app(ResolveTenantByHost::class)->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(409, $response->getStatusCode());
        $this->assertSame('domain_not_active', $response->getData(true)['error']['code']);
    }

    public function test_inactive_tenant_returns_safe_tenant_inactive_error(): void
    {
        $this->seedTenant(tenantStatus: 'suspended');

        $request = Request::create('/probe', 'GET', [], [], [], ['HTTP_HOST' => 'tenant.example.test']);
        $response = app(ResolveTenantByHost::class)->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(409, $response->getStatusCode());
        $this->assertSame('tenant_inactive', $response->getData(true)['error']['code']);
    }

    public function test_inactive_partner_returns_safe_tenant_inactive_error(): void
    {
        $this->seedTenant(partnerStatus: 'suspended');

        $request = Request::create('/probe', 'GET', [], [], [], ['HTTP_HOST' => 'tenant.example.test']);
        $response = app(ResolveTenantByHost::class)->handle($request, fn () => response()->json(['ok' => true]));

        $this->assertSame(409, $response->getStatusCode());
        $this->assertSame('tenant_inactive', $response->getData(true)['error']['code']);
    }

    public function test_maintenance_tenant_status_still_sets_tenant_context(): void
    {
        $this->seedTenant(tenantStatus: 'maintenance');

        $request = Request::create('/probe', 'GET', [], [], [], ['HTTP_HOST' => 'tenant.example.test']);
        $response = app(ResolveTenantByHost::class)->handle($request, function () {
            return response()->json([
                'tenant_id' => app(TenantContext::class)->tenantId(),
                'partner_id' => app(TenantContext::class)->partnerId(),
            ]);
        });

        $this->assertSame(200, $response->getStatusCode());
        $this->assertSame('ten_test', $response->getData(true)['tenant_id']);
        $this->assertSame('par_test', $response->getData(true)['partner_id']);
    }

    public function test_active_host_sets_tenant_context(): void
    {
        $this->seedTenant();

        $request = Request::create('/probe', 'GET', [], [], [], ['HTTP_HOST' => 'tenant.example.test']);
        $response = app(ResolveTenantByHost::class)->handle($request, function () {
            return response()->json([
                'tenant_id' => app(TenantContext::class)->tenantId(),
                'partner_id' => app(TenantContext::class)->partnerId(),
            ]);
        });

        $this->assertSame(200, $response->getStatusCode());
        $this->assertSame('ten_test', $response->getData(true)['tenant_id']);
        $this->assertSame('par_test', $response->getData(true)['partner_id']);
    }

    private function seedTenant(
        string $domainStatus = 'active',
        string $tenantStatus = 'active',
        string $partnerStatus = 'active',
    ): void
    {
        DB::table('partners')->insert([
            'id' => 'par_test',
            'code' => 'partner-test',
            'name' => 'Partner Test',
            'type' => 'partner_store',
            'status' => $partnerStatus,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenants')->insert([
            'id' => 'ten_test',
            'partner_id' => 'par_test',
            'code' => 'tenant-test',
            'name' => 'Tenant Test',
            'status' => $tenantStatus,
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        DB::table('partner_tenant_domains')->insert([
            'id' => 'dom_test',
            'partner_id' => 'par_test',
            'tenant_id' => 'ten_test',
            'host' => 'tenant.example.test',
            'type' => 'subdomain',
            'status' => $domainStatus,
            'is_primary' => true,
            'created_at' => now(),
            'updated_at' => now(),
        ]);
    }
}
