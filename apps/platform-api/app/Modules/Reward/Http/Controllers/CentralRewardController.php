<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Reward\Services\RewardService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralRewardController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly RewardService $rewards,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->rewards->listRewardResults($request->query()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.create');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request) + $this->rewards->validateRewardPayload($request->all());

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->rewards->createRewardResult($request->all(), $context, $request), 202);
    }

    public function show(Request $request, string $reward_result_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $result = $this->rewards->rewardResult($reward_result_id);

        return $result === null ? ApiErrorResponse::notFound($request) : response()->json($result);
    }

    public function update(Request $request, string $reward_result_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.create');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $errors = $this->headers->idempotencyKeyErrors($request) + $this->rewards->validateRewardPayload($request->all(), false);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        return $this->writeResult($request, $this->rewards->updateRewardResult($reward_result_id, $request->all(), $context, $request));
    }

    public function checkBatches(Request $request, string $reward_result_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.audit');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        if ($this->rewards->rewardResult($reward_result_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        return response()->json($this->rewards->checkBatches($reward_result_id));
    }

    public function verify(Request $request, string $reward_result_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.verify');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency($request, fn (): array => $this->rewards->verifyRewardResult($reward_result_id, $request->all(), $context, $request));
    }

    public function publish(Request $request, string $reward_result_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.publish');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency($request, fn (): array => $this->rewards->publishRewardResult($reward_result_id, $request->all(), $context, $request));
    }

    public function correct(Request $request, string $reward_result_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward.correct');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return $this->writeWithIdempotency($request, fn (): array => $this->rewards->correctRewardResult($reward_result_id, $request->all(), $context, $request), 202);
    }

    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission($context->adminUser['id'], 'central', $context->activeScopeId(), $permissionCode)) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }

    /**
     * @param callable(): array{resource?: array<string, mixed>|null, status?: int, error?: string} $callback
     */
    private function writeWithIdempotency(Request $request, callable $callback, int $defaultStatus = 200): JsonResponse
    {
        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $callback(), $defaultStatus);
    }

    /**
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        return match ($result['error'] ?? null) {
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            'validation_failed' => ApiErrorResponse::validationFailed($request, ['payload' => ['The request payload is invalid.']]),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
