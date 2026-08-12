<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\AdminAuthService;
use App\Modules\Maintenance\Services\MaintenanceService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Shared\Tenancy\PartnerBoHostResolver;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class AdminAuthController extends Controller
{
    public function __construct(
        private readonly AdminAuthService $auth,
        private readonly RequestHeaderValidator $headers,
        private readonly PartnerBoHostResolver $partnerBoHosts,
        private readonly MaintenanceService $maintenance,
    ) {
    }

    public function login(Request $request): JsonResponse
    {
        $partnerBo = $this->partnerBoContextOrError($request);

        if ($partnerBo instanceof JsonResponse) {
            return $partnerBo;
        }

        $response = $this->auth->login([
            'email' => $request->input('email'),
            'password' => $request->input('password'),
            'scope' => $request->input('scope'),
            'tenant_id' => $request->input('tenant_id'),
        ], $request, $partnerBo);

        if ($response === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return response()->json($response);
    }

    public function refresh(Request $request): JsonResponse
    {
        $partnerBo = $this->partnerBoContextOrError($request);

        if ($partnerBo instanceof JsonResponse) {
            return $partnerBo;
        }

        $response = $this->auth->refresh((string) $request->input('refresh_token', ''), $partnerBo);

        if ($response === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return response()->json($response);
    }

    public function logout(Request $request): Response
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $this->auth->revoke($context, $request);

        return response()->noContent();
    }

    public function serverTime(Request $request): JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $now = now();

        return response()->json([
            'server_time' => $now->toIso8601String(),
            'timezone' => (string) config('app.timezone', 'UTC'),
            'utc_offset' => $now->format('P'),
        ]);
    }

    public function me(Request $request): JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $partnerBo = $this->partnerBoContextOrError($request);

        if ($partnerBo instanceof JsonResponse) {
            return $partnerBo;
        }

        $profile = $this->auth->sessionProfile($context, $partnerBo);

        if ($profile === null) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return response()->json($profile);
    }

    public function updateMe(Request $request): JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $profile = $this->auth->updatePreferredLocale($context, $request->input('preferred_locale'));

        return $profile === null
            ? ApiErrorResponse::validationFailed($request, ['preferred_locale' => [__('validation.in', [
                'attribute' => __('validation.attributes.preferred_locale'),
                'values' => 'th-TH, en-US',
            ])]])
            : response()->json($profile);
    }

    /**
     * @return array<string, mixed>|null|JsonResponse
     */
    private function partnerBoContextOrError(Request $request): array|null|JsonResponse
    {
        $resolved = $this->partnerBoHosts->resolve($request);

        if ($resolved['error'] !== null) {
            return ApiErrorResponse::make(
                $request,
                $resolved['error']['status'],
                $resolved['error']['code'],
                $resolved['error']['message'],
            );
        }

        $context = $resolved['context'];

        if ($context !== null) {
            $maintenance = $this->maintenance->stateForPartner((string) $context['partner_id']);

            if ((bool) ($maintenance['active'] ?? false)) {
                $retryAfter = $maintenance['retry_after_seconds'] ?? null;

                return ApiErrorResponse::partnerMaintenanceActive($request, $retryAfter === null ? null : (int) $retryAfter);
            }
        }

        return $context;
    }
}
