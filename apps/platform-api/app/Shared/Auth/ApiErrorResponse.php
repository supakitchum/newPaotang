<?php

namespace App\Shared\Auth;

use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;

class ApiErrorResponse
{
    /**
     * @param array<string, mixed> $details
     */
    public static function make(Request $request, int $status, string $code, string $message, array $details = []): JsonResponse
    {
        return response()->json([
            'error' => [
                'code' => $code,
                'message' => $message,
                'details' => $details,
                'request_id' => $request->header('X-Request-Id'),
            ],
        ], $status);
    }

    public static function authenticationRequired(Request $request): JsonResponse
    {
        return self::make($request, 401, 'authentication_required', 'Authentication token is missing, invalid, expired, or revoked.');
    }

    public static function permissionDenied(Request $request): JsonResponse
    {
        return self::make($request, 403, 'permission_denied', 'You do not have permission to perform this action.');
    }

    public static function customerPinSetupRequired(Request $request): JsonResponse
    {
        return self::make($request, 403, 'pin_setup_required', 'A 6-digit customer PIN must be set before continuing.');
    }

    public static function customerPinRequired(Request $request): JsonResponse
    {
        return self::make($request, 403, 'pin_required', 'Customer PIN verification is required before continuing.');
    }

    public static function customerPinLocked(Request $request, ?int $retryAfterSeconds = null): JsonResponse
    {
        $response = self::make(
            $request,
            423,
            'pin_locked',
            'Customer PIN verification is temporarily locked. Please try again later.',
            ['retry_after_seconds' => $retryAfterSeconds],
        );

        if ($retryAfterSeconds !== null && $retryAfterSeconds > 0) {
            $response->headers->set('Retry-After', (string) $retryAfterSeconds);
        }

        return $response;
    }

    public static function notFound(Request $request): JsonResponse
    {
        return self::make($request, 404, 'resource_not_found', 'The requested resource was not found.');
    }

    public static function resourceConflict(Request $request): JsonResponse
    {
        return self::make($request, 409, 'resource_conflict', 'The resource conflicts with existing state.');
    }

    public static function idempotencyConflict(Request $request): JsonResponse
    {
        return self::make($request, 409, 'idempotency_conflict', 'The idempotency key was already used with a different payload.');
    }

    public static function reservationUnavailable(Request $request): JsonResponse
    {
        return self::make($request, 409, 'reservation_unavailable', 'The requested stock is no longer available.');
    }

    public static function reservationExpired(Request $request): JsonResponse
    {
        return self::make($request, 409, 'reservation_expired', 'The reservation has expired.');
    }

    public static function walletInsufficientBalance(Request $request): JsonResponse
    {
        return self::make($request, 409, 'wallet_insufficient_balance', 'The wallet balance is insufficient.');
    }

    public static function maintenanceActive(Request $request, ?int $retryAfterSeconds = null): JsonResponse
    {
        $response = self::make($request, 503, 'maintenance_active', 'Tenant maintenance is active.');

        if ($retryAfterSeconds !== null && $retryAfterSeconds > 0) {
            $response->headers->set('Retry-After', (string) $retryAfterSeconds);
        }

        return $response;
    }

    /**
     * @param array<string, array<int, string>> $fields
     */
    public static function validationFailed(Request $request, array $fields): JsonResponse
    {
        return self::make(
            $request,
            422,
            'validation_failed',
            'The request payload is invalid.',
            ['fields' => $fields],
        );
    }
}
