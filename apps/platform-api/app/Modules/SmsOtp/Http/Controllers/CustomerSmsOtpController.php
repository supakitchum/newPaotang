<?php

namespace App\Modules\SmsOtp\Http\Controllers;

use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Auth\Services\CustomerPasswordResetService;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\SmsOtp\Services\SmsOtpService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerSmsOtpController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly SmsOtpService $otp,
        private readonly CustomerPasswordResetService $passwordResets,
        private readonly CustomerAuthService $customerAuth,
    ) {
    }

    public function request(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        return $this->writeResult($request, $this->otp->requestOtp((string) $tenant['tenant_id'], $request->all(), $request), 202);
    }

    public function verify(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        return $this->writeResult($request, $this->otp->verifyOtp((string) $tenant['tenant_id'], $request->all()));
    }

    public function resetPassword(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $errors = $this->passwordResets->resetPasswordWithOtpErrors($request->all());
        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $phone = $this->otp->normalizePhone($request->input('phone'));
        $consume = $this->otp->consumeVerifiedToken(
            (string) $tenant['tenant_id'],
            (string) $phone,
            SmsOtpService::PURPOSE_PASSWORD_RESET,
            (string) $request->input('otp_verification_token', ''),
        );

        if (($consume['ok'] ?? false) !== true) {
            return ApiErrorResponse::make($request, 422, (string) ($consume['error'] ?? 'otp_invalid'), 'OTP verification is required.');
        }

        return $this->writeResult(
            $request,
            $this->passwordResets->resetPasswordForVerifiedPhone((string) $tenant['tenant_id'], (string) $phone, $request->all(), $request),
        );
    }

    public function requestPinReset(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $phone = (string) ($context->customer['phone'] ?? '');

        return $this->writeResult(
            $request,
            $this->otp->requestOtp($context->tenantId(), ['purpose' => SmsOtpService::PURPOSE_PIN_RESET], $request, SmsOtpService::PURPOSE_PIN_RESET, $phone),
            202,
        );
    }

    public function verifyPinReset(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return $this->writeResult(
            $request,
            $this->otp->verifyOtp($context->tenantId(), $request->all(), SmsOtpService::PURPOSE_PIN_RESET, (string) ($context->customer['phone'] ?? '')),
        );
    }

    public function confirmPinReset(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $pin = preg_replace('/\D+/', '', (string) $request->input('pin', '')) ?: '';
        if (! preg_match('/^\d{6}$/', $pin)) {
            return ApiErrorResponse::validationFailed($request, ['pin' => ['The pin field must contain exactly 6 digits.']]);
        }

        if ($request->has('pin_confirmation') && $pin !== preg_replace('/\D+/', '', (string) $request->input('pin_confirmation', ''))) {
            return ApiErrorResponse::validationFailed($request, ['pin_confirmation' => ['The pin confirmation does not match.']]);
        }

        $consume = $this->otp->consumeVerifiedToken(
            $context->tenantId(),
            (string) ($context->customer['phone'] ?? ''),
            SmsOtpService::PURPOSE_PIN_RESET,
            (string) $request->input('otp_verification_token', ''),
        );

        if (($consume['ok'] ?? false) !== true) {
            return ApiErrorResponse::make($request, 422, (string) ($consume['error'] ?? 'otp_invalid'), 'OTP verification is required.');
        }

        return $this->writeResult($request, $this->customerAuth->resetPinAfterOtp($context, $pin));
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return ApiErrorResponse::make($request, $result['error']['status'], $result['error']['code'], $result['error']['message']);
        }

        return $result['context'];
    }

    /**
     * @param array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, mixed>, message?: string, details?: array<string, mixed>} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            'provider_not_configured' => ApiErrorResponse::make($request, $result['status'] ?? 409, 'sms_otp_provider_not_configured', $result['message'] ?? 'SMS OTP provider is not configured.', $result['details'] ?? []),
            'otp_cooldown' => ApiErrorResponse::make($request, 429, 'otp_cooldown', $result['message'] ?? 'Please wait before requesting another OTP.', $result['details'] ?? []),
            'otp_rate_limited' => ApiErrorResponse::make($request, 429, 'otp_rate_limited', $result['message'] ?? 'Too many OTP requests. Please try again later.', $result['details'] ?? []),
            'sms_send_failed' => ApiErrorResponse::make($request, 503, 'sms_send_failed', $result['message'] ?? 'SMS OTP could not be sent.'),
            'sms_verify_failed' => ApiErrorResponse::make($request, 503, 'sms_verify_failed', $result['message'] ?? 'SMS OTP could not be verified.'),
            'otp_invalid' => ApiErrorResponse::make($request, $result['status'] ?? 422, 'otp_invalid', $result['message'] ?? 'OTP is invalid or expired.'),
            'otp_attempts_exceeded' => ApiErrorResponse::make($request, 429, 'otp_attempts_exceeded', $result['message'] ?? 'OTP verification attempts exceeded.'),
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'storage_unavailable' => ApiErrorResponse::make($request, 503, 'sms_otp_storage_not_ready', $result['message'] ?? 'SMS OTP storage is not ready.', $result['details'] ?? []),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
