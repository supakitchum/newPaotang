<?php

namespace App\Shared\Auth\Http\Middleware;

use App\Shared\Auth\AdminSessionResolver;
use App\Shared\Auth\ApiErrorResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class AuthenticateAdmin
{
    public function __construct(private readonly AdminSessionResolver $sessions)
    {
    }

    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next): Response
    {
        $context = $this->sessions->resolveAccessToken($request->bearerToken());

        if ($context === null) {
            $failure = $this->sessions->failure();

            if ($failure !== null) {
                return ApiErrorResponse::make($request, 401, $failure['code'], $failure['message']);
            }

            return ApiErrorResponse::authenticationRequired($request);
        }

        $request->attributes->set('admin_session', $context);

        if (($context->adminUser['must_change_password'] ?? false) && ! $this->allowsForcedPasswordChangeRequest($request)) {
            return ApiErrorResponse::make(
                $request,
                403,
                'admin_password_change_required',
                'You must change your password before using the Back Office.',
            );
        }

        return $next($request);
    }

    private function allowsForcedPasswordChangeRequest(Request $request): bool
    {
        return ($request->is('api/v1/auth/admin/me') && $request->isMethod('get'))
            || $request->is('api/v1/auth/admin/logout')
            || $request->is('api/v1/auth/admin/password/change');
    }
}
