<?php

namespace App\Modules\CustomerSupport\Http\Controllers;

use App\Models\PartnerTenant;
use App\Models\PartnerTenantFeatureFlag;
use App\Modules\CustomerSupport\Services\SupportSessionTokenService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerSupportSessionController extends Controller
{
    public function __construct(private readonly SupportSessionTokenService $tokens)
    {
    }

    public function store(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');
        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }
        $tenant = PartnerTenant::query()->find($context->tenantId());
        if ($tenant === null) {
            return ApiErrorResponse::notFound($request);
        }
        if (! $this->enabled($context->tenantId())) {
            return ApiErrorResponse::make($request, 503, 'support_unavailable', 'Customer support is currently unavailable.');
        }
        $customer = $context->customer;
        $locale = trim((string) ($customer['preferred_locale'] ?? $request->header('Accept-Language', 'th-TH'))) ?: 'th-TH';
        $name = trim((string) ($customer['name'] ?? ''));
        if ($name === '') {
            $name = trim(implode(' ', array_filter([
                (string) ($customer['first_name'] ?? ''),
                (string) ($customer['last_name'] ?? ''),
            ])));
        }
        $session = $this->tokens->issue([
            'sub' => $context->customerId(),
            'tenant_id' => $context->tenantId(),
            'actor_type' => 'customer',
            'name' => $name,
            'member_code' => $customer['customer_no'] ?? null,
            'tenant_name' => (string) $tenant->name,
            'locale' => $locale,
            'support_enabled' => true,
            'permissions' => [],
        ]);

        return response()->json([
            ...$session,
            'api_url' => (string) config('support.api_url'),
            'realtime' => [
                'url' => (string) config('support.realtime_url'),
                'key' => (string) config('support.realtime_key'),
                'auth_path' => '/customer/realtime/auth',
                'channel_prefix' => 'private-support.tenant.'.$context->tenantId(),
                'channels' => [
                    'private-support.tenant.'.$context->tenantId().'.customer.'.$context->customerId(),
                ],
            ],
        ]);
    }

    private function enabled(string $tenantId): bool
    {
        $value = PartnerTenantFeatureFlag::query()
            ->where('tenant_id', $tenantId)
            ->where('feature_key', 'customer_support')
            ->value('enabled');

        return $value === null ? (bool) config('support.enabled_by_default', false) : (bool) $value;
    }
}
