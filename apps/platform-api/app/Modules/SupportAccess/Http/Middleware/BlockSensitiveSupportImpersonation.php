<?php

namespace App\Modules\SupportAccess\Http\Middleware;

use App\Modules\SupportAccess\Services\SupportAccessService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use Closure;
use Illuminate\Http\Request;
use Symfony\Component\HttpFoundation\Response;

class BlockSensitiveSupportImpersonation
{
    public function __construct(private readonly SupportAccessService $supportAccess)
    {
    }

    /**
     * @param Closure(Request): Response $next
     */
    public function handle(Request $request, Closure $next, string $action): Response
    {
        $sessionId = (string) $request->header('X-Support-Impersonation-Session-Id', '');
        $token = (string) $request->header('X-Support-Impersonation-Token', '');

        if ($sessionId === '' && $token === '') {
            return $next($request);
        }

        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext || $context->activeTenantId() === null) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if ($sessionId === '' || $token === '') {
            return ApiErrorResponse::permissionDenied($request);
        }

        $session = $this->supportAccess->validateSessionToken((string) $context->activeTenantId(), $sessionId, $token);

        if ($session === null) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $this->supportAccess->recordBlockedAction($session, $action, $context, $request);

        return ApiErrorResponse::permissionDenied($request);
    }
}
