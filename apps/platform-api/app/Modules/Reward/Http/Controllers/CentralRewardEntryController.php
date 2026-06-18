<?php

namespace App\Modules\Reward\Http\Controllers;

use App\Modules\Rbac\Services\PermissionService;
use App\Modules\Reward\Services\RewardEntryService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Shared\Http\RequestHeaderValidator;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralRewardEntryController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly RewardEntryService $rewardEntries,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function current(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.view');

        return $context instanceof AdminSessionContext
            ? response()->json($this->rewardEntries->currentSession($request->query(), $context))
            : $context;
    }

    public function show(Request $request, string $session_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $session = $this->rewardEntries->session($session_id, $context);

        return $session === null ? ApiErrorResponse::notFound($request) : response()->json(['data' => $session]);
    }

    public function saveSubmission(Request $request, string $session_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.submit');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->rewardEntries->saveSubmission($session_id, $request->all(), $context, $request));
    }

    public function submit(Request $request, string $session_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.submit');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->rewardEntries->submitSubmission($session_id, $request->all(), $context, $request), 202);
    }

    public function ownerQueue(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.resolve');

        return $context instanceof AdminSessionContext
            ? response()->json($this->rewardEntries->ownerQueue())
            : $context;
    }

    public function comparison(Request $request, string $session_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.resolve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $comparison = $this->rewardEntries->comparison($session_id);

        return $comparison === null ? ApiErrorResponse::notFound($request) : response()->json($comparison);
    }

    public function triggerScraper(Request $request, string $session_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->rewardEntries->triggerScraper($session_id, $request->all(), $context, $request), 202);
    }

    public function resolve(Request $request, string $session_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'reward_entry.resolve');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);
        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        return $this->writeResult($request, $this->rewardEntries->resolve($session_id, $request->all(), $context, $request), 202);
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
     * @param array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $result
     */
    private function writeResult(Request $request, array $result, int $defaultStatus = 200): JsonResponse
    {
        if (($result['error'] ?? null) === 'validation_failed') {
            return ApiErrorResponse::validationFailed($request, $result['errors'] ?? ['payload' => ['The request payload is invalid.']]);
        }

        return match ($result['error'] ?? null) {
            'permission_denied' => ApiErrorResponse::permissionDenied($request),
            'idempotency_conflict' => ApiErrorResponse::idempotencyConflict($request),
            'resource_conflict' => ApiErrorResponse::resourceConflict($request),
            'not_found' => ApiErrorResponse::notFound($request),
            default => response()->json($result['resource'] ?? [], $result['status'] ?? $defaultStatus),
        };
    }
}
