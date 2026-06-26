<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerBiometricAuthService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerBiometricAuthController extends Controller
{
    public function __construct(private readonly CustomerBiometricAuthService $biometrics)
    {
    }

    public function devices(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? response()->json($this->biometrics->devices($context))
            : $context;
    }

    public function storeDevice(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? $this->writeResult($request, $this->biometrics->registerDevice($context, $request->all()), 201)
            : $context;
    }

    public function revokeDevice(Request $request, string $device_id): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? $this->writeResult($request, $this->biometrics->revokeDevice($context, $device_id))
            : $context;
    }

    public function challenge(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? $this->writeResult($request, $this->biometrics->challenge($context, $request->all()))
            : $context;
    }

    public function verify(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? $this->writeResult($request, $this->biometrics->verify($context, $request->all()))
            : $context;
    }

    public function securityEvent(Request $request): JsonResponse
    {
        $context = $this->context($request);

        return $context instanceof CustomerSessionContext
            ? $this->writeResult($request, $this->biometrics->logSecurityEvent($context, $request->all()))
            : $context;
    }

    private function context(Request $request): CustomerSessionContext|JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        return $context instanceof CustomerSessionContext
            ? $context
            : ApiErrorResponse::authenticationRequired($request);
    }

    /**
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, retry_after_seconds?: int|null, errors?: array<string, array<int, string>>} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            'pin_setup_required' => ApiErrorResponse::customerPinSetupRequired($request),
            'pin_required' => ApiErrorResponse::customerPinRequired($request),
            'pin_locked' => ApiErrorResponse::customerPinLocked($request, $result['retry_after_seconds'] ?? null),
            'pin_invalid' => ApiErrorResponse::make($request, 422, 'pin_invalid', 'The customer PIN is incorrect.'),
            'pin_assertion_invalid' => ApiErrorResponse::make($request, 403, 'pin_assertion_invalid', 'The biometric PIN assertion is invalid or expired.'),
            'biometric_challenge_invalid' => ApiErrorResponse::make($request, 403, 'biometric_challenge_invalid', 'The biometric challenge is invalid or expired.'),
            'biometric_signature_invalid' => ApiErrorResponse::make($request, 403, 'biometric_signature_invalid', 'The biometric signature is invalid.'),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
