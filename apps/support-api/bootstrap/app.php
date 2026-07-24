<?php

use App\Http\Middleware\AuthenticateSupportActor;
use Illuminate\Foundation\Application;
use Illuminate\Foundation\Configuration\Exceptions;
use Illuminate\Foundation\Configuration\Middleware;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\Route;

return Application::configure(basePath: dirname(__DIR__))
    ->withRouting(
        api: __DIR__.'/../routes/api.php',
        commands: __DIR__.'/../routes/console.php',
        apiPrefix: 'v1',
        health: null,
        then: fn () => Route::middleware('api')->group(__DIR__.'/../routes/health.php'),
    )
    ->withMiddleware(function (Middleware $middleware): void {
        $middleware->alias([
            'support.auth' => AuthenticateSupportActor::class,
        ]);
    })
    ->withExceptions(function (Exceptions $exceptions): void {
        $exceptions->render(function (\RuntimeException $exception, Request $request) {
            $errors = [
                'ticket_closed' => [409, 'ticket_closed', 'This support ticket is closed.'],
                'ticket_not_closed' => [409, 'ticket_not_closed', 'This support ticket must be closed first.'],
                'permission_denied' => [403, 'support_permission_denied', 'You do not have permission for this support ticket.'],
            ];
            $mapped = $errors[$exception->getMessage()] ?? null;
            if ($mapped === null || ! $request->expectsJson()) {
                return null;
            }

            return response()->json([
                'error' => ['code' => $mapped[1], 'message' => $mapped[2]],
            ], $mapped[0]);
        });
    })
    ->create();
