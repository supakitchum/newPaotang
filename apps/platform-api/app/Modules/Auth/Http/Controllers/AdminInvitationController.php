<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\AdminAccountSecurityService;
use App\Modules\Rbac\Services\AdminUserInvitationService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class AdminInvitationController extends Controller
{
    public function __construct(
        private readonly AdminUserInvitationService $invitations,
        private readonly AdminAccountSecurityService $security,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function show(Request $request, string $token): JsonResponse
    {
        $invitation = $this->invitations->preview($token);

        return $invitation === null
            ? ApiErrorResponse::notFound($request)
            : response()->json(['invitation' => $invitation]);
    }

    public function accept(Request $request, string $token): JsonResponse
    {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = array_merge($request->all(), ['token' => $token]);
        $errors = $this->security->resetPasswordErrors($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->invitations->accept($token, (string) $payload['password']);

        if ($result['status'] === 'expired') {
            return ApiErrorResponse::make($request, 410, 'admin_invitation_expired', 'This invitation link has expired.');
        }

        if ($result['status'] === 'used') {
            return ApiErrorResponse::make($request, 409, 'admin_invitation_used', 'This invitation link has already been used.');
        }

        if ($result['status'] !== 'accepted') {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json([
            'status' => 'accepted',
            'user' => $result['user'],
            'login_path' => '/login',
        ]);
    }
}
