<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerPasskeyService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class CustomerPasskeyController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly CustomerPasskeyService $passkeys,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function loginOptions(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        return $tenant instanceof JsonResponse
            ? $tenant
            : $this->result($request, $this->passkeys->loginOptions($tenant, $request));
    }

    public function login(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);
        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->result(
            $request,
            $this->passkeys->login($tenant, $request->all(), $request),
        );
    }

    public function index(Request $request): JsonResponse
    {
        $resolved = $this->authenticatedContext($request);
        if ($resolved instanceof JsonResponse) {
            return $resolved;
        }

        return response()->json($this->passkeys->index($resolved['tenant'], $resolved['context']));
    }

    public function registrationOptions(Request $request): JsonResponse
    {
        $resolved = $this->authenticatedContext($request);
        if ($resolved instanceof JsonResponse) {
            return $resolved;
        }

        return $this->result(
            $request,
            $this->passkeys->registrationOptions(
                $resolved['tenant'],
                $resolved['context'],
                $request,
            ),
        );
    }

    public function store(Request $request): JsonResponse
    {
        $resolved = $this->authenticatedContext($request);
        if ($resolved instanceof JsonResponse) {
            return $resolved;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->result(
            $request,
            $this->passkeys->register(
                $resolved['tenant'],
                $resolved['context'],
                $request->all(),
                $request,
            ),
            201,
        );
    }

    public function destroy(Request $request, string $passkey_id): Response
    {
        $resolved = $this->authenticatedContext($request);
        if ($resolved instanceof JsonResponse) {
            return $resolved;
        }

        return $this->result(
            $request,
            $this->passkeys->revoke(
                $resolved['tenant'],
                $resolved['context'],
                $passkey_id,
                $request,
            ),
        );
    }

    /**
     * @return array{context: CustomerSessionContext, tenant: array<string, mixed>}|JsonResponse
     */
    private function authenticatedContext(Request $request): array|JsonResponse
    {
        $context = $request->attributes->get('customer_session');
        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $tenant = $this->tenantContext($request);
        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }
        if ((string) $tenant['tenant_id'] !== $context->tenantId()) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return ['context' => $context, 'tenant' => $tenant];
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);
        if (! isset($result['error'])) {
            return $result['context'];
        }

        $error = $result['error'];
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive(
                $request,
                $error['retry_after_seconds'] ?? null,
            );
        }

        return ApiErrorResponse::make(
            $request,
            $error['status'],
            $error['code'],
            $error['message'],
        );
    }

    /**
     * @param array{resource?: array<string, mixed>, status?: int, error?: string, details?: array<string, mixed>, errors?: array<string, array<int, string>>} $result
     */
    private function result(
        Request $request,
        array $result,
        int $defaultStatus = 200,
    ): JsonResponse {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed(
                $request,
                $result['errors'] ?? [],
            ),
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'customer_suspended' => ApiErrorResponse::customerSuspended(
                $request,
                $result['details'] ?? [],
            ),
            'pin_required' => ApiErrorResponse::customerPinRequired($request),
            'not_found', 'passkey_not_available' => ApiErrorResponse::notFound($request),
            'resource_conflict', 'idempotency_conflict', 'passkey_limit_reached' =>
                ApiErrorResponse::make(
                    $request,
                    409,
                    (string) $result['error'],
                    $result['error'] === 'passkey_limit_reached'
                        ? 'The maximum number of passkeys has been reached.'
                        : 'The passkey request conflicts with an existing request.',
                ),
            'passkey_challenge_invalid' => ApiErrorResponse::make(
                $request,
                422,
                'passkey_challenge_invalid',
                'The passkey request expired or has already been used.',
            ),
            'passkey_verification_failed' => ApiErrorResponse::make(
                $request,
                422,
                'passkey_verification_failed',
                'Passkey verification failed.',
            ),
            default => response()->json(
                $result['resource'] ?? [],
                $result['status'] ?? $defaultStatus,
            ),
        };
    }
}
