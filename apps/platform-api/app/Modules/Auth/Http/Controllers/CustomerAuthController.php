<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class CustomerAuthController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly CustomerAuthService $customerAuth,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function register(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        $errors = $this->registerErrors($request->all()) + $headerErrors;

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->customerAuth->register($tenant, $request->all(), $request);

        return $this->writeResult($request, $result, 201);
    }

    public function login(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $response = $this->customerAuth->login($tenant, $request->all(), $request);

        if ($response === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (isset($response['error']) || isset($response['resource'])) {
            return $this->writeResult($request, $response);
        }

        return response()->json($response);
    }

    public function resendLoginOtp(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);
        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        return $this->writeResult(
            $request,
            $this->customerAuth->resendLoginOtp(
                $tenant,
                (string) $request->input('login_challenge_token', ''),
                $request,
            ),
            202,
        );
    }

    public function verifyLoginOtp(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);
        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        return $this->writeResult(
            $request,
            $this->customerAuth->verifyLoginOtp(
                $tenant,
                (string) $request->input('login_challenge_token', ''),
                (string) $request->input('otp', ''),
            ),
        );
    }

    public function refresh(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $response = $this->customerAuth->refresh($tenant, (string) $request->input('refresh_token', ''));

        if ($response === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return isset($response['error'])
            ? $this->writeResult($request, $response)
            : response()->json($response);
    }

    public function logout(Request $request): Response
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $this->customerAuth->revoke($context);

        return response()->noContent();
    }

    public function me(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $profile = $this->customerAuth->profile($context);

        return $profile === null ? ApiErrorResponse::authenticationRequired($request) : response()->json($profile);
    }

    public function profile(Request $request): JsonResponse
    {
        return $this->me($request);
    }

    public function updateProfile(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $localeErrors = $this->preferredLocaleErrors($payload);
        if ($localeErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $localeErrors);
        }

        if ($this->profileUpdateRequiresPin($payload)) {
            $pinErrors = trim((string) ($payload['pin_assertion_token'] ?? '')) !== ''
                ? []
                : $this->pinErrors($payload);

            if ($pinErrors !== []) {
                return ApiErrorResponse::validationFailed($request, $pinErrors);
            }
        }

        $result = $this->customerAuth->updateProfile($context, $payload, $request);

        return $this->writeResult($request, $result);
    }

    public function pinStatus(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return response()->json($this->customerAuth->pinStatus($context));
    }

    public function setupPin(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $errors = $this->pinErrors($request->all(), 'pin', true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->customerAuth->setupPin($context, $request->all()));
    }

    public function verifyPin(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $payload = $request->all();
        $errors = trim((string) ($payload['pin_assertion_token'] ?? '')) !== ''
            ? []
            : $this->pinErrors($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->customerAuth->verifyPinOrAssertionForContext($context, $payload, true));
    }

    public function changePin(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $errors = $this->pinErrors($request->all(), 'current_pin')
            + $this->pinErrors($request->all(), 'new_pin', true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->customerAuth->changePin($context, $request->all()));
    }

    public function verifyPinResetPassword(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $errors = $this->passwordErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->customerAuth->verifyPinResetPassword($context, $request->all()));
    }

    public function resetPin(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $errors = $this->pinErrors($request->all(), 'pin', true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->customerAuth->resetPin($context, $request->all()));
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return $this->tenantError($request, $result['error']);
        }

        return $result['context'];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function registerErrors(array $payload): array
    {
        $errors = [];

        foreach (['phone', 'password', 'password_confirmation'] as $field) {
            if (trim((string) ($payload[$field] ?? '')) === '') {
                $errors[$field][] = 'The '.$field.' field is required.';
            }
        }

        $hasLegacyName = trim((string) ($payload['name'] ?? '')) !== '';
        if (! $hasLegacyName && trim((string) ($payload['first_name'] ?? '')) === '') {
            $errors['first_name'][] = 'The first_name field is required.';
        }

        if (! $hasLegacyName && trim((string) ($payload['last_name'] ?? '')) === '') {
            $errors['last_name'][] = 'The last_name field is required.';
        }

        if (($payload['password'] ?? null) !== ($payload['password_confirmation'] ?? null)) {
            $errors['password_confirmation'][] = 'The password confirmation does not match.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function pinErrors(array $payload, string $field = 'pin', bool $confirmation = false): array
    {
        $errors = [];
        $value = trim((string) ($payload[$field] ?? ''));

        if (! preg_match('/^\d{6}$/', $value)) {
            $errors[$field][] = 'The '.$field.' field must contain exactly 6 digits.';
        }

        if ($confirmation && array_key_exists($field.'_confirmation', $payload) && $value !== (string) $payload[$field.'_confirmation']) {
            $errors[$field.'_confirmation'][] = 'The '.$field.' confirmation does not match.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function passwordErrors(array $payload): array
    {
        if (trim((string) ($payload['password'] ?? '')) === '') {
            return ['password' => ['The password field is required.']];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function profileUpdateRequiresPin(array $payload): bool
    {
        return array_key_exists('reward_payout_bank_account', $payload)
            || array_key_exists('bank_account', $payload);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function preferredLocaleErrors(array $payload): array
    {
        if (! array_key_exists('preferred_locale', $payload)) {
            return [];
        }

        $locale = str_replace('_', '-', strtolower(trim((string) $payload['preferred_locale'])));

        if (! in_array($locale, ['th', 'th-th', 'en', 'en-us', 'en-gb'], true)) {
            return ['preferred_locale' => [__('validation.in', [
                'attribute' => __('validation.attributes.preferred_locale'),
                'values' => 'th-TH, en-US',
            ])]];
        }

        return [];
    }

    /**
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'customer_session_replaced' => ApiErrorResponse::make(
                $request,
                401,
                'customer_session_replaced',
                'This account signed in on a new device. The previous device was signed out.',
                [
                    'replacement_session_id' => $result['replacement_session_id'] ?? null,
                    'replaced_at' => $result['replaced_at'] ?? null,
                ],
            ),
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'account_reuse_cooldown' => ApiErrorResponse::make(
                $request,
                409,
                'account_reuse_cooldown',
                'This phone number can be registered again after the retention cooldown.',
                $result['details'] ?? [],
            ),
            'pin_setup_required' => ApiErrorResponse::customerPinSetupRequired($request),
            'pin_required' => ApiErrorResponse::customerPinRequired($request),
            'pin_locked' => ApiErrorResponse::customerPinLocked($request, $result['retry_after_seconds'] ?? null),
            'customer_suspended' => ApiErrorResponse::customerSuspended($request, $result['suspension'] ?? []),
            'pin_invalid' => ApiErrorResponse::make($request, 422, 'pin_invalid', 'The customer PIN is incorrect.'),
            'pin_assertion_invalid' => ApiErrorResponse::make($request, 403, 'pin_assertion_invalid', 'The biometric PIN assertion is invalid or expired.'),
            'password_invalid' => ApiErrorResponse::make($request, 422, 'password_invalid', 'The account password is incorrect.'),
            'otp_required' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['otp_verification_token' => ['OTP verification is required.']]),
            'validation_failed' => ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]),
            'provider_not_configured' => ApiErrorResponse::make($request, $result['status'] ?? 409, 'sms_otp_provider_not_configured', $result['message'] ?? 'SMS OTP provider is not configured.', $result['details'] ?? []),
            'otp_cooldown' => ApiErrorResponse::make($request, 429, 'otp_cooldown', $result['message'] ?? 'Please wait before requesting another OTP.', $result['details'] ?? []),
            'otp_rate_limited' => ApiErrorResponse::make($request, 429, 'otp_rate_limited', $result['message'] ?? 'Too many OTP requests. Please try again later.', $result['details'] ?? []),
            'sms_send_failed' => ApiErrorResponse::make($request, 503, 'sms_send_failed', $result['message'] ?? 'SMS OTP could not be sent.'),
            'sms_verify_failed' => ApiErrorResponse::make($request, 503, 'sms_verify_failed', $result['message'] ?? 'SMS OTP could not be verified.'),
            'otp_invalid' => ApiErrorResponse::make($request, $result['status'] ?? 422, 'otp_invalid', $result['message'] ?? 'OTP is invalid or expired.'),
            'otp_attempts_exceeded' => ApiErrorResponse::make($request, 429, 'otp_attempts_exceeded', $result['message'] ?? 'OTP verification attempts exceeded.'),
            'storage_unavailable' => ApiErrorResponse::make($request, 503, 'sms_otp_storage_not_ready', $result['message'] ?? 'SMS OTP storage is not ready.', $result['details'] ?? []),
            'login_otp_challenge_invalid' => ApiErrorResponse::make($request, $result['status'] ?? 422, 'login_otp_challenge_invalid', $result['message'] ?? 'The login OTP challenge is invalid or expired.'),
            'login_otp_phone_missing' => ApiErrorResponse::make($request, $result['status'] ?? 409, 'login_otp_phone_missing', $result['message'] ?? 'This account cannot receive a login OTP.'),
            'pin_reset_not_verified' => ApiErrorResponse::make($request, 403, 'pin_reset_not_verified', 'Please verify the account password before resetting PIN.'),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }

    /**
     * @param array{status: int, code: string, message: string, retry_after_seconds?: int|null} $error
     */
    private function tenantError(Request $request, array $error): JsonResponse
    {
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive($request, $error['retry_after_seconds'] ?? null);
        }

        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }
}
