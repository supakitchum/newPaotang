<?php

namespace App\Modules\AdminOperations\Http\Controllers;

use App\Modules\AdminOperations\Services\BoMenuCompletionService;
use App\Modules\Rbac\Services\PermissionService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class BoMenuCompletionController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly BoMenuCompletionService $completion,
        private readonly RequestHeaderValidator $headers,
        private readonly IdempotencyService $idempotency,
    ) {
    }

    public function partnerMonitoringIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.monitoring.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listPartnerMonitoring($request->query()))
            : $context;
    }

    public function partnerMonitoringShow(Request $request, string $monitoring_profile_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.monitoring.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findPartnerMonitoring($monitoring_profile_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function partnerMonitoringUpdate(Request $request, string $monitoring_profile_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.monitoring.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.partner-monitoring.patch:'.$monitoring_profile_id,
            'partner.monitoring.manage',
            fn (array $payload): array => $this->completion->updatePartnerMonitoring($monitoring_profile_id, $payload, $context, $request),
        );
    }

    public function partnerUsageIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.usage.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listPartnerUsage($request->query()))
            : $context;
    }

    public function partnerUsageShow(Request $request, string $usage_meter_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.usage.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findPartnerUsage($usage_meter_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function partnerUsageUpdate(Request $request, string $usage_meter_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.usage.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.partner-usage.patch:'.$usage_meter_id,
            'partner.usage.manage',
            fn (array $payload): array => $this->completion->updatePartnerUsage($usage_meter_id, $payload, $context, $request),
        );
    }

    public function billingPlansIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listBillingPlans($request->query()))
            : $context;
    }

    public function billingPlansStore(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.billing-plans.store',
            'partner.billing.manage',
            fn (array $payload): array => $this->completion->createBillingPlan($payload, $context, $request),
            201,
        );
    }

    public function billingPlansShow(Request $request, string $billing_plan_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findBillingPlan($billing_plan_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function billingPlansUpdate(Request $request, string $billing_plan_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.billing-plans.patch:'.$billing_plan_id,
            'partner.billing.manage',
            fn (array $payload): array => $this->completion->updateBillingPlan($billing_plan_id, $payload, $context, $request),
        );
    }

    public function billingBindingsIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listBillingBindings($request->query()))
            : $context;
    }

    public function billingBindingsShow(Request $request, string $billing_binding_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findBillingBinding($billing_binding_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function billingBindingsUpdate(Request $request, string $billing_binding_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.billing.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.billing-bindings.patch:'.$billing_binding_id,
            'partner.billing.manage',
            fn (array $payload): array => $this->completion->updateBillingBinding($billing_binding_id, $payload, $context, $request),
        );
    }

    public function alertPoliciesIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listAlertPolicies($request->query()))
            : $context;
    }

    public function alertPoliciesStore(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.alert-policies.store',
            'partner.alert.manage',
            fn (array $payload): array => $this->completion->createAlertPolicy($payload, $context, $request),
            201,
        );
    }

    public function alertPoliciesShow(Request $request, string $alert_policy_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findAlertPolicy($alert_policy_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function alertPoliciesUpdate(Request $request, string $alert_policy_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.alert-policies.patch:'.$alert_policy_id,
            'partner.alert.manage',
            fn (array $payload): array => $this->completion->updateAlertPolicy($alert_policy_id, $payload, $context, $request),
        );
    }

    public function alertEventsIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listAlertEvents($request->query()))
            : $context;
    }

    public function alertEventsShow(Request $request, string $alert_event_id): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findAlertEvent($alert_event_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function alertEventsAcknowledge(Request $request, string $alert_event_id): JsonResponse
    {
        return $this->changeAlertEvent($request, $alert_event_id, 'acknowledged');
    }

    public function alertEventsResolve(Request $request, string $alert_event_id): JsonResponse
    {
        return $this->changeAlertEvent($request, $alert_event_id, 'resolved');
    }

    public function systemSettingsShow(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'system.settings.manage');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->systemSettings())
            : $context;
    }

    public function systemSettingsUpdate(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'system.settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.system-settings.patch',
            'system.settings.manage',
            fn (array $payload): array => $this->completion->updateSystemSettings($payload, $context, $request),
        );
    }

    public function webhookLogsIndex(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'audit.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listWebhookLogs($request->query()))
            : $context;
    }

    public function webhookLogsShow(Request $request, string $webhook_log_id): JsonResponse
    {
        $context = $this->centralContext($request, 'audit.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findWebhookLog($webhook_log_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function centralSyncLogs(Request $request): JsonResponse
    {
        $context = $this->centralContext($request, 'audit.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listSyncLogs(null, $request->query()))
            : $context;
    }

    public function priceRulesIndex(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'price_rule.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listPriceRules((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function priceRuleGames(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'price_rule.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listPriceRuleGames((string) $context->activeTenantId()))
            : $context;
    }

    public function priceRulesStore(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.price-rules.store',
            'price_rule.manage',
            fn (array $payload): array => $this->completion->createPriceRule($tenantId, $payload, $context, $request),
            201,
        );
    }

    public function priceRulesShow(Request $request, string $price_rule_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'price_rule.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findPriceRule((string) $context->activeTenantId(), $price_rule_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function priceRulesUpdate(Request $request, string $price_rule_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.price-rules.patch:'.$price_rule_id,
            'price_rule.manage',
            fn (array $payload): array => $this->completion->updatePriceRule($tenantId, $price_rule_id, $payload, $context, $request),
        );
    }

    public function priceRulesDestroy(Request $request, string $price_rule_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'price_rule.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.price-rules.delete:'.$price_rule_id,
            'price_rule.manage',
            fn (array $payload): array => $this->completion->archivePriceRule($tenantId, $price_rule_id, $payload, $context, $request),
            204,
        );
    }

    public function domainsIndex(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'settings.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listTenantDomains((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function domainsStore(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.domains.store',
            'settings.manage',
            fn (array $payload): array => $this->completion->createTenantDomain($tenantId, $payload, $context, $request),
            201,
        );
    }

    public function domainsShow(Request $request, string $domain_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'settings.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findTenantDomain((string) $context->activeTenantId(), $domain_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function domainsUpdate(Request $request, string $domain_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.domains.patch:'.$domain_id,
            'settings.manage',
            fn (array $payload): array => $this->completion->updateTenantDomain($tenantId, $domain_id, $payload, $context, $request),
        );
    }

    public function domainsDestroy(Request $request, string $domain_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.domains.delete:'.$domain_id,
            'settings.manage',
            fn (array $payload): array => $this->completion->removeTenantDomain($tenantId, $domain_id, $payload, $context, $request),
            204,
        );
    }

    public function domainsVerify(Request $request, string $domain_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'settings.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.domains.verify:'.$domain_id,
            'settings.manage',
            fn (array $payload): array => $this->completion->verifyTenantDomain($tenantId, $domain_id, $payload, $context, $request),
        );
    }

    public function membersIndex(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listMembers((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function membersStore(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer.create');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.members.store',
            'customer.create',
            fn (array $payload): array => $this->completion->createMember($tenantId, $payload, $context, $request),
            201,
        );
    }

    public function membersShow(Request $request, string $member_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->completion->findMember((string) $context->activeTenantId(), $member_id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function membersUpdate(Request $request, string $member_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.members.patch:'.$member_id,
            'customer.update',
            fn (array $payload): array => $this->completion->updateMember($tenantId, $member_id, $payload, $context, $request),
        );
    }

    public function membersStatus(Request $request, string $member_id): JsonResponse
    {
        $context = $this->tenantContext($request, 'customer.suspend');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $tenantId = (string) $context->activeTenantId();

        return $this->writeWithIdempotency(
            $request,
            $context,
            $tenantId,
            'tenant_admin',
            'admin.tenant.members.status:'.$member_id,
            'customer.suspend',
            fn (array $payload): array => $this->completion->changeMemberStatus($tenantId, $member_id, $payload, $context, $request),
        );
    }

    public function tenantMonitoring(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'monitoring.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->tenantMonitoring((string) $context->activeTenantId()))
            : $context;
    }

    public function tenantUsage(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'usage.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->tenantUsage((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    public function tenantSyncLogs(Request $request): JsonResponse
    {
        $context = $this->tenantContext($request, 'sync_log.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->completion->listSyncLogs((string) $context->activeTenantId(), $request->query()))
            : $context;
    }

    private function changeAlertEvent(Request $request, string $alertEventId, string $status): JsonResponse
    {
        $context = $this->centralContext($request, 'partner.alert.manage');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency(
            $request,
            $context,
            null,
            'central_admin',
            'admin.central.alert-events.'.$status.':'.$alertEventId,
            'partner.alert.manage',
            fn (array $payload): array => $this->completion->changeAlertEventStatus($alertEventId, $status, $payload, $context, $request),
        );
    }

    private function centralContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        return $this->authorizedContext($request, 'central', $permissionCode, null);
    }

    private function tenantContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if ($context instanceof AdminSessionContext && ($context->activeTenantId() === null || $context->activeTenantId() === '')) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $this->authorizedContext($request, 'tenant', $permissionCode, $context instanceof AdminSessionContext ? $context->activeTenantId() : null);
    }

    private function authorizedContext(Request $request, string $scopeType, string $permissionCode, ?string $tenantId): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($context->activeScope() !== $scopeType) {
            return ApiErrorResponse::permissionDenied($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            $scopeType,
            $context->activeScopeId(),
            $permissionCode,
            $tenantId,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    private function writeWithIdempotency(
        Request $request,
        AdminSessionContext $context,
        ?string $tenantId,
        string $actorType,
        string $routeKey,
        string $permissionCode,
        callable $callback,
        int $defaultStatus = 200,
    ): JsonResponse {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $replay = $this->idempotency->replayOrConflict(
            $tenantId,
            $actorType,
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
            $permissionCode,
            true,
        );

        if (is_array($replay)) {
            return response()->json($replay['body'] ?? [], $replay['status']);
        }

        if ($replay === 'idempotency_conflict') {
            return ApiErrorResponse::idempotencyConflict($request);
        }

        if ($replay === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        $result = $callback($payload);

        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        if (($result['error'] ?? null) === 'not_found') {
            return ApiErrorResponse::notFound($request);
        }

        $status = $result['status'] ?? $defaultStatus;
        $resource = $result['resource'] ?? [];

        $this->idempotency->storeResponse(
            $tenantId,
            $actorType,
            (string) $context->adminUser['id'],
            $routeKey,
            $idempotencyKey,
            $payload,
            $status,
            $resource,
            $permissionCode,
        );

        return response()->json($resource, $status);
    }
}
