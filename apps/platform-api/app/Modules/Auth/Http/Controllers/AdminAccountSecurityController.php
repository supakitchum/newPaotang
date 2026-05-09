<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\AdminAccountSecurityService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class AdminAccountSecurityController extends Controller
{
    public function __construct(
        private readonly AdminAccountSecurityService $security,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function forgotPassword(Request $request): Response
    {
        if ($this->hasSupportImpersonationHeaders($request)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->security->passwordResetRequestErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->requestPasswordReset($request->all(), $request);

        return $this->emptyResult($request, $result, 202);
    }

    public function resetPassword(Request $request): Response
    {
        if ($this->hasSupportImpersonationHeaders($request)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->security->resetPasswordErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->resetPassword($request->all(), $request);

        return $this->emptyResult($request, $result, 204);
    }

    public function changePassword(Request $request): Response
    {
        $context = $this->adminContext($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->security->changePasswordErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->changePassword($context, $request->all(), $request);

        return $this->emptyResult($request, $result, 204);
    }

    public function twoFactorStatus(Request $request): JsonResponse
    {
        $context = $this->adminContext($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        return response()->json($this->security->twoFactorStatus($context));
    }

    public function setupTwoFactor(Request $request): JsonResponse
    {
        $context = $this->adminContext($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->setupTwoFactor($context, $request->all(), $request);

        return $this->jsonResult($request, $result);
    }

    public function enableTwoFactor(Request $request): JsonResponse
    {
        $context = $this->adminContext($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->security->twoFactorCodeErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->enableTwoFactor($context, $request->all(), $request);

        return $this->jsonResult($request, $result);
    }

    public function rotateRecoveryCodes(Request $request): JsonResponse
    {
        $context = $this->adminContext($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->security->twoFactorCodeErrors($request->all(), true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->rotateRecoveryCodes($context, $request->all(), $request);

        return $this->jsonResult($request, $result);
    }

    public function disableTwoFactor(Request $request): Response
    {
        $context = $this->adminContext($request);

        if ($context instanceof JsonResponse) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request)
            + $this->security->twoFactorCodeErrors($request->all(), true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->disableTwoFactor($context, $request->all(), $request);

        return $this->emptyResult($request, $result, 204);
    }

    public function verifyTwoFactor(Request $request): JsonResponse
    {
        if ($this->hasSupportImpersonationHeaders($request)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $errors = $this->security->twoFactorVerifyErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->security->verifyTwoFactorChallenge($request->all(), $request);

        return $this->jsonResult($request, $result);
    }

    private function adminContext(Request $request): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        return $context instanceof AdminSessionContext
            ? $context
            : ApiErrorResponse::authenticationRequired($request);
    }

    private function hasSupportImpersonationHeaders(Request $request): bool
    {
        return $request->header('X-Support-Impersonation-Session-Id') !== null
            || $request->header('X-Support-Impersonation-Token') !== null;
    }

    /**
     * @param array{status?: int, error?: string, resource?: array<string, mixed>} $result
     */
    private function jsonResult(Request $request, array $result): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? 200),
        };
    }

    /**
     * @param array{status?: int, error?: string, resource?: array<string, mixed>} $result
     */
    private function emptyResult(Request $request, array $result, int $defaultStatus): Response
    {
        if (($result['error'] ?? null) !== null) {
            return match ($result['error']) {
                'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
                'resource_conflict' => ApiErrorResponse::resourceConflict($request),
                'authentication_required' => ApiErrorResponse::authenticationRequired($request),
                default => ApiErrorResponse::resourceConflict($request),
            };
        }

        $status = $result['status'] ?? $defaultStatus;

        return $status === 204
            ? response()->noContent()
            : response('', $status);
    }
}
