<?php

namespace App\Modules\Auth\Http\Controllers;

use App\Modules\Auth\Services\CustomerRealtimeAuthService;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CustomerRealtimeController extends Controller
{
    public function __construct(private readonly CustomerRealtimeAuthService $realtime)
    {
    }

    public function authorize(Request $request): JsonResponse
    {
        $context = $request->attributes->get('customer_session');

        if (! $context instanceof CustomerSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $payload = $request->all();
        $errors = $this->realtime->validationErrors($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $authorization = $this->realtime->authorize($context, $payload);

        return $authorization === null
            ? ApiErrorResponse::permissionDenied($request)
            : response()->json($authorization);
    }
}
