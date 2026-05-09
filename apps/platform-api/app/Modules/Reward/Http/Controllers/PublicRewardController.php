<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Shared\Auth\ApiErrorResponse;
use App\Modules\PartnerStore\Services\PartnerStoreService;
use App\Modules\Reward\Services\RewardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class PublicRewardController extends Controller
{
    public function __construct(
        private readonly PartnerStoreService $partnerStore,
        private readonly RewardService $rewards,
    ) {
    }

    public function latest(Request $request): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        return $this->publicResult($request, $this->rewards->publicLatestResult());
    }

    public function show(Request $request, string $game_id): JsonResponse
    {
        $tenant = $this->tenantContext($request);

        if ($tenant instanceof JsonResponse) {
            return $tenant;
        }

        return $this->publicResult($request, $this->rewards->publicResultForGame($game_id));
    }

    /**
     * @return array<string, mixed>|JsonResponse
     */
    private function tenantContext(Request $request): array|JsonResponse
    {
        $result = $this->partnerStore->tenantContextForRequest($request, true);

        if (isset($result['error'])) {
            return $this->tenantError($request, $result['error']);
        }

        return $result['context'];
    }

    /**
     * @param array{body: array<string, mixed>|null, etag: string|null} $result
     */
    private function publicResult(Request $request, array $result): JsonResponse
    {
        if ($result['body'] === null) {
            return ApiErrorResponse::notFound($request);
        }

        $response = response()->json($result['body']);

        if ($result['etag'] !== null) {
            $response->headers->set('ETag', $result['etag']);
            $response->headers->set('Cache-Control', 'public, max-age=60');
        }

        return $response;
    }

    /**
     * @param array{status: int, code: string, message: string, retry_after_seconds?: int|null} $error
     */
    private function tenantError(Request $request, array $error): JsonResponse
    {
        if ($error['code'] === 'maintenance_active') {
            return ApiErrorResponse::maintenanceActive($request, $error['retry_after_seconds'] ?? null);
        }

        return ApiErrorResponse::make($request, $error['status'], $error['code'], $error['message']);
    }
}
