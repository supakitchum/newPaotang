<?php

namespace App\Modules\CentralStock\Http\Controllers;

use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\CentralStock\Services\CentralStockService;
use App\Shared\Http\RequestHeaderValidator;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class CentralGameController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CentralStockService $centralStock,
        private readonly RequestHeaderValidator $headers,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'game.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        return response()->json($this->centralStock->listGames($request->query()));
    }

    public function store(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request, 'game.create');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        $payload = $request->all();
        $errors = $this->centralStock->validateGamePayload($payload, true);

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->centralStock->gameConflictErrors($payload) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        return response()->json($this->centralStock->createGame($payload, $context, $request), 201);
    }

    public function show(Request $request, string $game_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'game.view');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $game = $this->centralStock->findGame($game_id);

        return $game === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($game);
    }

    public function update(Request $request, string $game_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'game.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findGame($game_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $payload = $request->all();
        $errors = array_merge(
            $this->centralStock->validateGamePayload($payload, false),
            $this->centralStock->gameTransitionErrors($game_id, $payload),
        );

        if ($errors !== []) {
            return ApiErrorResponse::validationFailed($request, $errors);
        }

        if ($this->centralStock->gameConflictErrors($payload, $game_id) !== []) {
            return ApiErrorResponse::resourceConflict($request);
        }

        $game = $this->centralStock->updateGame($game_id, $payload, $context, $request);

        return $game === null
            ? ApiErrorResponse::notFound($request)
            : response()->json($game);
    }

    public function close(Request $request, string $game_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'game.close');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findGame($game_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $game = $this->centralStock->closeGame($game_id, $request->all(), $context, $request);

        return $game === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($game);
    }

    public function archive(Request $request, string $game_id): JsonResponse
    {
        $context = $this->authorizedContext($request, 'game.update');

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $headerErrors = $this->headers->idempotencyKeyErrors($request);

        if ($headerErrors !== []) {
            return ApiErrorResponse::validationFailed($request, $headerErrors);
        }

        if ($this->centralStock->findGame($game_id) === null) {
            return ApiErrorResponse::notFound($request);
        }

        $game = $this->centralStock->archiveGame($game_id, $request->all(), $context, $request);

        return $game === null
            ? ApiErrorResponse::resourceConflict($request)
            : response()->json($game);
    }

    /**
     * @return AdminSessionContext|JsonResponse
     */
    private function authorizedContext(Request $request, string $permissionCode): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        if (! $this->permissions->adminHasPermission(
            $context->adminUser['id'],
            'central',
            $context->activeScopeId(),
            $permissionCode,
            null,
        )) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
