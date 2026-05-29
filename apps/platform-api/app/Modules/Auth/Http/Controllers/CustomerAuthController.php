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

        $response = $this->customerAuth->login($tenant, $request->all());

        return $response === null
            ? ApiErrorResponse::authenticationRequired($request)
            : response()->json($response);
    }

    public function refresh(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        $response = $this->customerAuth->refresh($tenant, (string) $request->input('refresh_token', ''));

        return $response === null
            ? ApiErrorResponse::authenticationRequired($request)
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

        $result = $this->customerAuth->updateProfile($context, $request->all(), $request);

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

        $errors = $this->pinErrors($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->customerAuth->verifyPin($context, $request->all()));
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
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'authentication_required' => ApiErrorResponse::authenticationRequired($request),
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'pin_setup_required' => ApiErrorResponse::customerPinSetupRequired($request),
            'pin_required' => ApiErrorResponse::customerPinRequired($request),
            'pin_locked' => ApiErrorResponse::customerPinLocked($request, $result['retry_after_seconds'] ?? null),
            'pin_invalid' => ApiErrorResponse::make($request, 422, 'pin_invalid', 'The customer PIN is incorrect.'),
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
