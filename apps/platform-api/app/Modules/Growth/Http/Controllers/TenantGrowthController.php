<?php

namespace App\Modules\Growth\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Growth\Services\GrowthService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Growth\Http\Requests\GrowthRequestValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class TenantGrowthController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly GrowthService $growth,
        private readonly RequestHeaderValidator $headers,
        private readonly GrowthRequestValidator $validator,
    ) {
    }

    public function agents(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'agent.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listAgents((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createAgent(Request $request): JsonResponse
    {
        return $this->tenantWrite($request, 'agent.create', fn (AdminSessionContext $context): array => $this->growth->createAgent((string) $context->activeTenantId(), $context, $request->all(), $request), 201);
    }

    public function agent(Request $request, string $agent_id): JsonResponse
    {
        return $this->tenantShow($request, 'agent.view', fn (AdminSessionContext $context): ?array => $this->growth->agent((string) $context->activeTenantId(), $agent_id));
    }

    public function updateAgent(Request $request, string $agent_id): JsonResponse
    {
        return $this->tenantWrite($request, 'agent.update', fn (AdminSessionContext $context): array => $this->growth->updateAgent((string) $context->activeTenantId(), $context, $agent_id, $request->all(), $request));
    }

    public function updateAgentQuotas(Request $request, string $agent_id): JsonResponse
    {
        return $this->tenantWrite($request, 'agent.quota.manage', fn (AdminSessionContext $context): array => $this->growth->updateAgentQuotas((string) $context->activeTenantId(), $context, $agent_id, $request->all(), $request));
    }

    public function affiliatePrograms(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'affiliate_program.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listAffiliatePrograms((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createAffiliateProgram(Request $request): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate_program.manage', fn (AdminSessionContext $context): array => $this->growth->createAffiliateProgram((string) $context->activeTenantId(), $context, $request->all(), $request), 201);
    }

    public function affiliateProgram(Request $request, string $affiliate_program_id): JsonResponse
    {
        return $this->tenantShow($request, 'affiliate_program.view', fn (AdminSessionContext $context): ?array => $this->growth->affiliateProgram((string) $context->activeTenantId(), $affiliate_program_id));
    }

    public function updateAffiliateProgram(Request $request, string $affiliate_program_id): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate_program.manage', fn (AdminSessionContext $context): array => $this->growth->updateAffiliateProgram((string) $context->activeTenantId(), $context, $affiliate_program_id, $request->all(), $request));
    }

    public function archiveAffiliateProgram(Request $request, string $affiliate_program_id): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate_program.manage', fn (AdminSessionContext $context): array => $this->growth->archiveAffiliateProgram((string) $context->activeTenantId(), $context, $affiliate_program_id, $request->all(), $request), 204);
    }

    public function affiliateLinks(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'affiliate_link.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listAffiliateLinks((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createAffiliateLink(Request $request): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate_link.manage', fn (AdminSessionContext $context): array => $this->growth->createAffiliateLink((string) $context->activeTenantId(), $context, $request->all(), $request), 201);
    }

    public function affiliateLink(Request $request, string $affiliate_link_id): JsonResponse
    {
        return $this->tenantShow($request, 'affiliate_link.view', fn (AdminSessionContext $context): ?array => $this->growth->affiliateLink((string) $context->activeTenantId(), $affiliate_link_id));
    }

    public function updateAffiliateLink(Request $request, string $affiliate_link_id): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate_link.manage', fn (AdminSessionContext $context): array => $this->growth->updateAffiliateLink((string) $context->activeTenantId(), $context, $affiliate_link_id, $request->all(), $request));
    }

    public function archiveAffiliateLink(Request $request, string $affiliate_link_id): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate_link.manage', fn (AdminSessionContext $context): array => $this->growth->archiveAffiliateLink((string) $context->activeTenantId(), $context, $affiliate_link_id, $request->all(), $request), 204);
    }

    public function affiliateAttributions(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'affiliate_attribution.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listAffiliateAttributions((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function affiliateAttribution(Request $request, string $attribution_id): JsonResponse
    {
        return $this->tenantShow($request, 'affiliate_attribution.view', fn (AdminSessionContext $context): ?array => $this->growth->affiliateAttribution((string) $context->activeTenantId(), $attribution_id));
    }

    public function affiliates(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'affiliate.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listAffiliateAccounts((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createAffiliate(Request $request): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate.create', fn (AdminSessionContext $context): array => $this->growth->createAffiliateAccount((string) $context->activeTenantId(), $context, $request->all(), $request), 201);
    }

    public function affiliate(Request $request, string $affiliate_id): JsonResponse
    {
        return $this->tenantShow($request, 'affiliate.view', fn (AdminSessionContext $context): ?array => $this->growth->affiliateAccount((string) $context->activeTenantId(), $affiliate_id));
    }

    public function updateAffiliate(Request $request, string $affiliate_id): JsonResponse
    {
        return $this->tenantWrite($request, 'affiliate.update', fn (AdminSessionContext $context): array => $this->growth->updateAffiliateAccount((string) $context->activeTenantId(), $context, $affiliate_id, $request->all(), $request));
    }

    public function commissionRules(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'commission_rule.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listCommissionRules((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createCommissionRule(Request $request): JsonResponse
    {
        return $this->tenantWrite($request, 'commission_rule.manage', fn (AdminSessionContext $context): array => $this->growth->createCommissionRule((string) $context->activeTenantId(), $context, $request->all(), $request), 201);
    }

    public function commissionRule(Request $request, string $commission_rule_id): JsonResponse
    {
        return $this->tenantShow($request, 'commission_rule.view', fn (AdminSessionContext $context): ?array => $this->growth->commissionRule((string) $context->activeTenantId(), $commission_rule_id));
    }

    public function updateCommissionRule(Request $request, string $commission_rule_id): JsonResponse
    {
        return $this->tenantWrite($request, 'commission_rule.manage', fn (AdminSessionContext $context): array => $this->growth->updateCommissionRule((string) $context->activeTenantId(), $context, $commission_rule_id, $request->all(), $request));
    }

    public function archiveCommissionRule(Request $request, string $commission_rule_id): JsonResponse
    {
        return $this->tenantWrite($request, 'commission_rule.manage', fn (AdminSessionContext $context): array => $this->growth->archiveCommissionRule((string) $context->activeTenantId(), $context, $commission_rule_id, $request->all(), $request), 204);
    }

    public function commissionTransactions(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'commission.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listCommissionTransactions((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function commissionTransaction(Request $request, string $commission_id): JsonResponse
    {
        return $this->tenantShow($request, 'commission.view', fn (AdminSessionContext $context): ?array => $this->growth->commissionTransaction((string) $context->activeTenantId(), $commission_id));
    }

    public function approveCommissionTransaction(Request $request, string $commission_id): JsonResponse
    {
        return $this->tenantWrite(
            $request,
            'commission.approve',
            fn (AdminSessionContext $context): array => $this->growth->approveCommissionTransaction((string) $context->activeTenantId(), $context, $commission_id, $request->all(), $request),
            200,
            $this->validator->optionalApprovalReasonErrors($request->all()),
        );
    }

    public function payouts(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'payout.manage');

        return $context instanceof AdminSessionContext
            ? response()->json($this->growth->listPayouts((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function createPayout(Request $request): JsonResponse
    {
        return $this->tenantWrite(
            $request,
            'payout.manage',
            fn (AdminSessionContext $context): array => $this->growth->createPayout((string) $context->activeTenantId(), $context, $request->all(), $request),
            201,
            $this->validator->payoutCreateErrors($request->all()),
        );
    }

    public function approvePayout(Request $request, string $payout_id): JsonResponse
    {
        return $this->tenantWrite(
            $request,
            'payout.manage',
            fn (AdminSessionContext $context): array => $this->growth->approvePayout((string) $context->activeTenantId(), $context, $payout_id, $request->all(), $request),
            200,
            $this->validator->optionalApprovalReasonErrors($request->all()),
        );
    }

    private function tenantShow(Request $request, string $permissionCode, callable $callback): JsonResponse
    {
        $context = $this->authorizedContext($request, $permissionCode);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $callback($context);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    /**
     * @param array<string, array<int, string>> $payloadErrors
     */
    private function tenantWrite(Request $request, string $permissionCode, callable $callback, int $defaultStatus = 200, array $payloadErrors = []): JsonResponse
    {
        $context = $this->authorizedContext($request, $permissionCode);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($payloadErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $payloadErrors);
        }

        return $this->writeResult($request, $callback($context), $defaultStatus);
    }

    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'tenant',
            $context->activeScopeId(),
            $permissionCode,
            $context->activeTenantId(),
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    /**
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            default => ($result['status'] ?? $defaultStatus) === 204
                ? response()->json(null, 204)
                : response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
