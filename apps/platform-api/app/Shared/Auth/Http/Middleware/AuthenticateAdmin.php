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
            return ApiErrorResponse::authenticationRequired($request);
        }

        $request->attributes->set('admin_session', $context);

        return $next($request);
    }
}
