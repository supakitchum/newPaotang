<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerAccountDeletionService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerAccountDeletionController extends Controller
{
    public function __construct(private readonly CustomerAccountDeletionService $deletions)
    {
    }

    public function show(Request $request): JsonResponse
    {
        $context = $this->context($request);
        return $context instanceof JsonResponse
            ? $context
            : response()->json($this->deletions->status($context));
    }

    public function eligibility(Request $request): JsonResponse
    {
        $context = $this->context($request);
        return $context instanceof JsonResponse
            ? $context
            : response()->json($this->deletions->eligibility($context->tenantId(), $context->customerId()));
    }

    public function requestOtp(Request $request): JsonResponse
    {
        $context = $this->context($request);
        if ($context instanceof JsonResponse) {
            return $context;
        }
        if (! preg_match('/^\d{6}$/', trim((string) $request->input('pin', '')))) {
            return ApiErrorResponse::validationFailed($request, [
                'pin' => ['The pin field must contain exactly 6 digits.'],
            ]);
        }
        return $this->writeResult($request, $this->deletions->requestOtp($context, $request->all(), $request), 202);
    }

    public function verifyOtp(Request $request): JsonResponse
    {
        $context = $this->context($request);
        if ($context instanceof JsonResponse) {
            return $context;
        }
        return $this->writeResult($request, $this->deletions->verifyOtp($context, $request->all()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->context($request);
        return $context instanceof JsonResponse
            ? $context
            : $this->writeResult($request, $this->deletions->create($context, $request->all(), $request), 201);
    }

    public function cancel(Request $request): JsonResponse
    {
        $context = $this->context($request);
        if ($context instanceof JsonResponse) {
            return $context;
        }
        if (! preg_match('/^\d{6}$/', trim((string) $request->input('pin', '')))) {
            return ApiErrorResponse::validationFailed($request, [
                'pin' => ['The pin field must contain exactly 6 digits.'],
            ]);
        }
        return $this->writeResult($request, $this->deletions->cancel($context, $request->all()));
    }

    private function context(Request $request): CustomerSessionContext|JsonResponse
    {
        $context = $request->attributes->get('customer_session');
        return $context instanceof CustomerSessionContext
            ? $context
            : ApiErrorResponse::authenticationRequired($request);
    }

    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? []),
            'pin_invalid' => ApiErrorResponse::make($request, 422, 'pin_invalid', 'The customer PIN is incorrect.'),
            'pin_locked' => ApiErrorResponse::customerPinLocked($request, $result['retry_after_seconds'] ?? null),
            'pin_setup_required' => ApiErrorResponse::customerPinSetupRequired($request),
            'pin_verification_invalid' => ApiErrorResponse::make($request, 403, 'pin_verification_invalid', 'PIN verification is invalid or expired.'),
            'otp_required' => ApiErrorResponse::make($request, 422, 'otp_required', 'OTP verification is required.'),
            'otp_invalid' => ApiErrorResponse::make($request, 422, 'otp_invalid', $result['message'] ?? 'OTP is invalid or expired.'),
            'otp_attempts_exceeded' => ApiErrorResponse::make($request, 429, 'otp_attempts_exceeded', $result['message'] ?? 'OTP verification attempts exceeded.'),
            'otp_cooldown' => ApiErrorResponse::make($request, 429, 'otp_cooldown', $result['message'] ?? 'Please wait before requesting another OTP.', $result['details'] ?? []),
            'otp_rate_limited' => ApiErrorResponse::make($request, 429, 'otp_rate_limited', $result['message'] ?? 'Too many OTP requests.', $result['details'] ?? []),
            'provider_not_configured' => ApiErrorResponse::make($request, 409, 'sms_otp_provider_not_configured', $result['message'] ?? 'SMS OTP provider is not configured.'),
            'sms_send_failed', 'sms_verify_failed' => ApiErrorResponse::make($request, 503, (string) $result['error'], $result['message'] ?? 'SMS OTP is unavailable.'),
            'storage_unavailable' => ApiErrorResponse::make($request, 503, 'sms_otp_storage_not_ready', $result['message'] ?? 'SMS OTP storage is not ready.'),
            'deletion_request_exists' => ApiErrorResponse::make($request, 409, 'deletion_request_exists', 'An account deletion request is already open.'),
            'deletion_request_not_found' => ApiErrorResponse::make($request, 404, 'deletion_request_not_found', 'No open account deletion request was found.'),
            'deletion_not_eligible' => ApiErrorResponse::make($request, 409, 'deletion_not_eligible', 'Outstanding balances or transactions must be resolved first.', $result['details'] ?? []),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
