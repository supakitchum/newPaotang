<?php

namespace App\Modules\CentralStock\Http\Controllers;

use App\Jobs\ImportLotteryBackgroundZipJob;
use App\Jobs\ProcessStockAllocationJob;
use App\Models\LotteryImageBackgroundZipImport;
use App\Models\StockAllocationJob;
use App\Modules\CentralStock\Services\CentralStockService;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\ApiErrorResponse;
use App\Modules\Rbac\Services\PermissionService;
use Illuminate\Http\JsonResponse;
use Illuminate\Http\Request;
use Illuminate\Routing\Controller;

class QueueProcessController extends Controller
{
    public function __construct(
        private readonly PermissionService $permissions,
        private readonly CentralStockService $centralStock,
    ) {
    }

    public function index(Request $request): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $type = trim((string) $request->query('type', ''));
        $status = trim((string) $request->query('status', ''));
        $gameId = trim((string) $request->query('game_id', ''));
        $limit = max(1, min(100, (int) $request->query('limit', 30)));
        $rows = [];

        if ($type === '' || $type === 'zip_import') {
            $rows = array_merge($rows, LotteryImageBackgroundZipImport::query()
                ->when($status !== '', fn ($query) => $query->where('status', $status))
                ->when($gameId !== '', fn ($query) => $query->where('game_id', $gameId))
                ->orderByDesc('created_at')
                ->limit($limit)
                ->get()
                ->map(fn (LotteryImageBackgroundZipImport $job): array => $this->zipResource($job))
                ->all());
        }

        if ($type === '' || $type === 'allocation') {
            $rows = array_merge($rows, StockAllocationJob::query()
                ->when($status !== '', fn ($query) => $query->where('status', $status))
                ->when($gameId !== '', fn ($query) => $query->where('game_id', $gameId))
                ->orderByDesc('created_at')
                ->limit($limit)
                ->get()
                ->map(fn (StockAllocationJob $job): array => ['kind' => 'allocation'] + $this->centralStock->allocationJobResource($job))
                ->all());
        }

        usort($rows, fn (array $a, array $b): int => strcmp((string) ($b['created_at'] ?? ''), (string) ($a['created_at'] ?? '')));

        return response()->json(['data' => array_slice($rows, 0, $limit)]);
    }

    public function show(Request $request, string $type, string $id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        $resource = $this->resourceFor($type, $id);

        return $resource === null ? ApiErrorResponse::notFound($request) : response()->json($resource);
    }

    public function retry(Request $request, string $type, string $id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        if ($type === 'zip_import') {
            $job = LotteryImageBackgroundZipImport::query()->whereKey($id)->first();
            if (! $job instanceof LotteryImageBackgroundZipImport) {
                return ApiErrorResponse::notFound($request);
            }
            if (! in_array((string) $job->status, ['failed', 'cancelled'], true)) {
                return ApiErrorResponse::resourceConflict($request);
            }

            $job->update([
                'status' => 'queued',
                'current_step' => 'queued_retry',
                'progress_percent' => 0,
                'attempts' => 0,
                'queued_at' => now(),
                'heartbeat_at' => now(),
                'failed_at' => null,
                'error_code' => null,
                'error_message' => null,
                'error_details_json' => null,
                'updated_at' => now(),
            ]);
            ImportLotteryBackgroundZipJob::dispatch((string) $job->id);

            return response()->json($this->zipResource($job->refresh()), 202);
        }

        if ($type === 'allocation') {
            $job = StockAllocationJob::query()->whereKey($id)->first();
            if (! $job instanceof StockAllocationJob) {
                return ApiErrorResponse::notFound($request);
            }
            if (! in_array((string) $job->status, ['failed', 'cancelled'], true)) {
                return ApiErrorResponse::resourceConflict($request);
            }

            $job->update([
                'status' => 'queued',
                'current_step' => 'queued_retry',
                'progress_percent' => 0,
                'queued_at' => now(),
                'heartbeat_at' => now(),
                'failed_at' => null,
                'error_code' => null,
                'error_message' => null,
                'updated_at' => now(),
            ]);
            ProcessStockAllocationJob::dispatch((string) $job->id);

            return response()->json(['kind' => 'allocation'] + $this->centralStock->allocationJobResource($job->refresh()), 202);
        }

        return ApiErrorResponse::notFound($request);
    }

    public function cancel(Request $request, string $type, string $id): JsonResponse
    {
        $context = $this->authorizedContext($request);

        if (! $context instanceof AdminSessionContext) {
            return $context;
        }

        if ($type === 'zip_import') {
            $job = LotteryImageBackgroundZipImport::query()->whereKey($id)->first();
            if (! $job instanceof LotteryImageBackgroundZipImport) {
                return ApiErrorResponse::notFound($request);
            }
            if (! in_array((string) $job->status, ['queued', 'processing', 'failed'], true)) {
                return ApiErrorResponse::resourceConflict($request);
            }
            $job->update(['status' => 'cancelled', 'current_step' => 'cancelled', 'updated_at' => now()]);

            return response()->json($this->zipResource($job->refresh()));
        }

        if ($type === 'allocation') {
            $job = StockAllocationJob::query()->whereKey($id)->first();
            if (! $job instanceof StockAllocationJob) {
                return ApiErrorResponse::notFound($request);
            }
            if (! in_array((string) $job->status, ['queued', 'processing', 'failed'], true)) {
                return ApiErrorResponse::resourceConflict($request);
            }
            $job->update(['status' => 'cancelled', 'current_step' => 'cancelled', 'cancelled_at' => now(), 'updated_at' => now()]);

            return response()->json(['kind' => 'allocation'] + $this->centralStock->allocationJobResource($job->refresh()));
        }

        return ApiErrorResponse::notFound($request);
    }

    private function resourceFor(string $type, string $id): ?array
    {
        if ($type === 'zip_import') {
            $job = LotteryImageBackgroundZipImport::query()->whereKey($id)->first();

            return $job instanceof LotteryImageBackgroundZipImport ? $this->zipResource($job) : null;
        }

        if ($type === 'allocation') {
            $job = StockAllocationJob::query()->whereKey($id)->first();

            return $job instanceof StockAllocationJob ? ['kind' => 'allocation'] + $this->centralStock->allocationJobResource($job) : null;
        }

        return null;
    }

    private function zipResource(LotteryImageBackgroundZipImport $job): array
    {
        return [
            'kind' => 'zip_import',
            'id' => (string) $job->id,
            'type' => 'zip_import',
            'status' => (string) $job->status,
            'game_id' => (string) $job->game_id,
            'version' => (string) $job->version,
            'set_type' => (string) $job->set_type,
            'progress_current' => (int) $job->processed_count,
            'progress_total' => max(1, (int) $job->detected_count),
            'progress_percent' => (int) $job->progress_percent,
            'created_count' => (int) $job->imported_count,
            'skipped_count' => 0,
            'failed_count' => (string) $job->status === 'failed' ? 1 : 0,
            'current_step' => $job->current_step,
            'error_code' => $job->error_code,
            'error_message' => $job->error_message,
            'queued_at' => $job->queued_at?->toISOString(),
            'started_at' => $job->started_at?->toISOString(),
            'heartbeat_at' => $job->heartbeat_at?->toISOString(),
            'completed_at' => $job->completed_at?->toISOString(),
            'failed_at' => $job->failed_at?->toISOString(),
            'created_at' => $job->created_at?->toISOString(),
            'updated_at' => $job->updated_at?->toISOString(),
        ];
    }

    private function authorizedContext(Request $request): AdminSessionContext|JsonResponse
    {
        $context = $request->attributes->get('admin_session');

        if (! $context instanceof AdminSessionContext) {
            return ApiErrorResponse::authenticationRequired($request);
        }

        $canViewStock = $this->permissions->adminHasPermission($context->adminUser['id'], 'central', $context->activeScopeId(), 'stock.view', null);
        $canManageAssets = $this->permissions->adminHasPermission($context->adminUser['id'], 'central', $context->activeScopeId(), 'asset.manage', null);

        if (! $canViewStock && ! $canManageAssets) {
            return ApiErrorResponse::permissionDenied($request);
        }

        return $context;
    }
}
