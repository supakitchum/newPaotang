<?php

namespace App\Modules\Partner\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Partner\Services\PartnerProvisioningService;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PartnerProvisioningController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly PartnerProvisioningService $partners,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->partners->listPartners($request->query()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.create');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->partners->validatePartnerPayload($payload, true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->partners->partnerConflictErrors($payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        return response()->json($this->partners->createPartner($payload, $context, $request), 201);
    }

    public function show(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $partner = $this->partners->findPartner($partner_id);

        return $partner === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($partner);
    }

    public function update(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->partners->validatePartnerPayload($payload, false);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->partners->findPartner($partner_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        if ($this->partners->partnerConflictErrors($payload, $partner_id) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $partner = $this->partners->updatePartner($partner_id, $payload, $context, $request);

        return $partner === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($partner);
    }

    public function updateProfile(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->partners->findPartner($partner_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $payload = $request->all();
        $errors = $this->partners->validatePartnerTenantProfilePayload($partner_id, $payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->partners->partnerTenantProfileConflictErrors($partner_id, $payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $partner = $this->partners->updatePartnerTenantProfile($partner_id, $payload, $context, $request);

        return $partner === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($partner);
    }

    public function provision(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.provision');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->partners->findPartner($partner_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $payload = $request->all();
        $errors = $this->partners->validateProvisionPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->partners->provisionConflictErrors($partner_id, $payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $partner = $this->partners->provisionPartner($partner_id, $payload, $context, $request);

        return $partner === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($partner, 202);
    }

    public function suspend(Request $request, string $partner_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'partner.suspend');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $partner = $this->partners->suspendPartner($partner_id, $request->all(), $context, $request);

        return $partner === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($partner);
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'central',
            $context->activeScopeId(),
            $permissionCode,
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
