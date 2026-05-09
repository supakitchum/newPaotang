<?php

namespace App\Modules\Webhook\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Commerce\Services\CommerceService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class WebhookController extends Controller
{
    public function __construct(private readonly CommerceService $commerce)
    {
    }

    public function payment(Request $request, string $provider): JsonResponse
    {
        return $this->accepted($request, $this->commerce->acceptWebhook('payments', $provider, $request->all(), $request));
    }

    public function topup(Request $request, string $provider): JsonResponse
    {
        return $this->accepted($request, $this->commerce->acceptWebhook('topups', $provider, $request->all(), $request));
    }

    /**
     * @param array{resource?: array<string, mixed>, status?: int, error?: string} $result
     */
    private function accepted(Request $request, array $result): JsonResponse
    {
        if (($result['error'] ?? null) === 'resource_conflict') {
            return ApiErrorResponse::resourceConflict($request);
        }

        return response()->json($result['resource'] ?? ['accepted' => true, 'duplicate' => false], $result['status'] ?? 202);
    }
}
