<?php

namespace App\Modules\Partner\Http\Controllers;

use App\Modules\Partner\Services\PartnerSyncService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PartnerSyncController extends Controller
{
    public function __construct(
        private readonly PartnerSyncService $partnerSync,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function allocations(Request $request): JsonResponse
    {
        $context = $this->authorizedHeaders($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        return response()->json($this->partnerSync->pullAllocations($context['partner_id'], $context['tenant_id'], $request->query()));
    }

    public function events(Request $request): JsonResponse
    {
        $context = $this->authorizedHeaders($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->partnerSync->validateEventBatch($context['partner_id'], $context['tenant_id'], $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return response()->json(
            $this->partnerSync->acceptEvents($context['partner_id'], $context['tenant_id'], $payload['events']),
            202,
        );
    }

    /**
     * @return array{partner_id: string, tenant_id: string}|JsonResponse
     */
    private function authorizedHeaders(Request $request): array|JsonResponse
    {
        $partnerId = trim((string) $request->header('X-Partner-Id'));
        $tenantId = trim((string) $request->header('X-Tenant-Id'));

        $errors = [];

        if ($partnerId === '') {
            $errors['X-Partner-Id'][] = 'The X-Partner-Id header is required.';
        }

        if ($tenantId === '') {
            $errors['X-Tenant-Id'][] = 'The X-Tenant-Id header is required.';
        }

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $auth = $this->partnerSync->authenticate($request->bearerToken(), $partnerId, $tenantId);

        if (($auth['error'] ?? null) === 'authentication_required') {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (($auth['error'] ?? null) === 'permission_denied') {
            return ApiErrorResponse::permissionDenied($request);
        }

        return [
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
        ];
    }
}
