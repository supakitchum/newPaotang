<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\AdminAuthService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;
use Symfony\Component\HttpFoundation\Response;

class AdminAuthController extends Controller
{
    public function __construct(
        private readonly AdminAuthService $auth,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function login(Request $request): JsonResponse
    {
        $response = $this->auth->login([
            'email' => $request->input('email'),
            'password' => $request->input('password'),
            'scope' => $request->input('scope'),
            'tenant_id' => $request->input('tenant_id'),
        ], $request);

        if ($response === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return response()->json($response);
    }

    public function refresh(Request $request): JsonResponse
    {
        $response = $this->auth->refresh((string) $request->input('refresh_token', ''));

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

    public function me(Request $request): JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        return response()->json($this->auth->sessionProfile($context));
    }
}
