<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Modules\Reward\Services\RewardService;
use App\Shared\Auth\ApiErrorResponse;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class InternalRewardIngestController extends Controller
{
    public function __construct(private readonly RewardService $rewards)
    {
    }

    public function sanook(Request $request): JsonResponse
    {
        return $this->ingest($request, 'sanook');
    }

    public function thairath(Request $request): JsonResponse
    {
        return $this->ingest($request, 'thairath');
    }

    private function ingest(Request $request, string $source): JsonResponse
    {
        if (! $this->hasValidSignature($request)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        $payload = $request->all();
        $payload['source'] = trim((string) ($payload['source'] ?? '')) === '' ? $source : $payload['source'];

        if ($payload['source'] !== $source) {
            return ApiErrorResponse::validationFailed($request, [
                'source' => ['The source field must match the ingest endpoint.'],
            ]);
        }

        $errors = $this->rewards->validateLiveIngestPayload($payload);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        $result = $this->rewards->ingestLiveResult($payload, $request);

        return match ($result['error'] ?? null) {
            'not_found' => ApiErrorResponse::notFound($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            default => response()->json($result['resource'] ?? []),
        };
    }

    private function hasValidSignature(Request $request): bool
    {
        $secret = trim((string) config('platform.lotto_scraper.hmac_secret'));
        $timestamp = trim((string) $request->header('X-Lotto-Scraper-Timestamp', ''));
        $signature = trim((string) $request->header('X-Lotto-Scraper-Signature', ''));

        if ($secret === '' || $timestamp === '' || $signature === '') {
            return false;
        }

        if (! ctype_digit($timestamp) || abs(time() - (int) $timestamp) > (int) config('platform.lotto_scraper.signature_ttl_seconds', 300)) {
            return false;
        }

        $expected = 'sha256='.hash_hmac('sha256', $timestamp.'.'.$request->getContent(), $secret);

        return hash_equals($expected, $signature);
    }
}
