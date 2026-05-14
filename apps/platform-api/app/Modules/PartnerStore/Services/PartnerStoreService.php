<?php

namespace App\Modules\PartnerStore\Services;

use App\Jobs\GeneratePartnerLotteryImageJob;
use App\Models\CustomerAuthSession;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\PartnerStockAllocationItem;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantMaintenanceBypass;
use App\Models\StockReservation;
use App\Models\StockReservationItem;
use App\Models\StockSyncBatch;
use App\Models\SupportImpersonationSession;
use App\Models\SyncInbox;
use App\Models\SyncOutbox;
use App\Models\TenantStockExportJob;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use App\Modules\Maintenance\Services\MaintenanceService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PartnerStoreService
{
    private const LOCAL_STOCK_STATUSES = ['available', 'reserved', 'sold', 'expired', 'returned', 'recalled', 'unavailable'];
    private const RESERVATION_STATUSES = ['active', 'released', 'expired', 'converted', 'cancelled'];
    private const RESERVATION_TTL_MINUTES = 15;

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly MaintenanceService $maintenance,
    ) {
    }

    public function partnerIdForTenant(?string $tenantId): ?string
    {
        if ($tenantId === null || $tenantId === '') {
            return null;
        }

        return PartnerTenant::whereKey($tenantId)->value('partner_id');
    }

    /**
     * @return array{context?: array<string, mixed>, error?: array{status: int, code: string, message: string, retry_after_seconds?: int|null}}
     */
    public function tenantContextForRequest(Request $request, bool|string $maintenanceOperation): array
    {
        $host = $this->normalizeHost($request->getHost());
        $record = PartnerTenantDomain::query()
            ->join('partner_tenants', 'partner_tenants.id', '=', 'partner_tenant_domains.tenant_id')
            ->join('partners', 'partners.id', '=', 'partner_tenant_domains.partner_id')
            ->where('partner_tenant_domains.host', $host)
            ->select([
                'partner_tenant_domains.id as domain_id',
                'partner_tenant_domains.host',
                'partner_tenant_domains.status as domain_status',
                'partner_tenants.id as tenant_id',
                'partner_tenants.status as tenant_status',
                'partner_tenants.partner_id',
                'partners.id as partner_id',
                'partners.status as partner_status',
            ])
            ->first();

        if ($record === null) {
            return ['error' => ['status' => 404, 'code' => 'tenant_not_found', 'message' => 'Tenant domain was not found.']];
        }

        if ($record->domain_status !== config('platform.tenant_resolution.active_domain_status', 'active')) {
            return ['error' => ['status' => 409, 'code' => 'domain_not_active', 'message' => 'Tenant domain is not active.']];
        }

        if ($record->partner_status !== config('platform.tenant_resolution.active_partner_status', 'active')) {
            return ['error' => ['status' => 409, 'code' => 'tenant_inactive', 'message' => 'Tenant is not active.']];
        }

        if (! in_array((string) $record->tenant_status, ['active', 'maintenance'], true)) {
            return ['error' => ['status' => 409, 'code' => 'tenant_inactive', 'message' => 'Tenant is not active.']];
        }

        $tenantId = (string) $record->tenant_id;
        $maintenance = $this->maintenance->stateForTenant($tenantId, (string) $record->tenant_status);
        $operation = $this->maintenanceOperation($request, $maintenanceOperation);

        if (
            $operation !== null
            && $this->maintenance->shouldBlock($maintenance, $operation)
            && ! $this->hasActiveMaintenanceBypass($tenantId, $request)
        ) {
            return [
                'error' => [
                    'status' => 503,
                    'code' => 'maintenance_active',
                    'message' => 'Tenant maintenance is active.',
                    'retry_after_seconds' => $maintenance['retry_after_seconds'],
                ],
            ];
        }

        return [
            'context' => [
                'partner_id' => (string) $record->partner_id,
                'tenant_id' => $tenantId,
                'domain_id' => (string) $record->domain_id,
                'host' => (string) $record->host,
                'tenant_status' => (string) $record->tenant_status,
                'maintenance' => $maintenance,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function currentGameForTenant(string $tenantId): ?array
    {
        $game = Game::query()
            ->where('status', 'open')
            ->whereIn('id', LocalStockItem::query()
                ->where('tenant_id', $tenantId)
                ->select('game_id'))
            ->orderBy('draw_at')
            ->first();

        if ($game === null) {
            $game = Game::query()
                ->where('status', 'open')
                ->orderBy('draw_at')
                ->first();
        }

        return $game === null ? null : $this->gameResource($game);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, array<int, string>>
     */
    public function validateStockSearch(array $queryParams): array
    {
        $errors = [];
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));

        if ($gameId === '' || ! Game::whereKey($gameId)->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        foreach (['front3' => 3, 'back3' => 3, 'back2' => 2] as $field => $length) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $value = trim((string) $queryParams[$field]);

                if (! preg_match('/^[0-9]{'.$length.'}$/', $value)) {
                    $errors[$field][] = 'The '.$field.' field must be '.$length.' digits.';
                }
            }
        }

        if (($queryParams['number'] ?? null) !== null && trim((string) $queryParams['number']) !== '') {
            $number = trim((string) $queryParams['number']);

            if (! preg_match('/^[0-9]{1,32}$/', $number)) {
                $errors['number'][] = 'The number field must contain digits only.';
            }
        }

        if (($queryParams['mode'] ?? null) !== null && ! in_array((string) $queryParams['mode'], ['search', 'browse', 'random'], true)) {
            $errors['mode'][] = 'The mode field is invalid.';
        }

        if (($queryParams['store_id'] ?? null) !== null && trim((string) $queryParams['store_id']) !== '') {
            $storeId = trim((string) $queryParams['store_id']);

            if (strlen($storeId) > 128) {
                $errors['store_id'][] = 'The store_id field must be 128 characters or fewer.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function searchLocalStock(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = LocalStockItem::query()
            ->where('tenant_id', $tenantId)
            ->where('game_id', trim((string) $queryParams['game_id']))
            ->where('status', 'available')
            ->limit($limit + 1);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        if (($queryParams['store_id'] ?? null) !== null && trim((string) $queryParams['store_id']) !== '') {
            $query->where('store_id', trim((string) $queryParams['store_id']));
        }

        foreach (['front3', 'back3', 'back2'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['number'] ?? null) !== null && trim((string) $queryParams['number']) !== '') {
            $number = trim((string) $queryParams['number']);

            if (strlen($number) >= 6) {
                $query->where('full_number', $number);
            } elseif (strlen($number) === 3) {
                $query->where(function ($nested) use ($number): void {
                    $nested->where('front3', $number)
                        ->orWhere('back3', $number)
                        ->orWhere('full_number', 'like', '%'.$number.'%');
                });
            } elseif (strlen($number) === 2) {
                $query->where(function ($nested) use ($number): void {
                    $nested->where('back2', $number)
                        ->orWhere('full_number', 'like', '%'.$number.'%');
                });
            } else {
                $query->where('full_number', 'like', '%'.$number.'%');
            }
        }

        if (($queryParams['mode'] ?? 'search') === 'random') {
            $query->inRandomOrder();
        } else {
            $query->orderBy('id');
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $stock): array => $this->localStockResource($stock), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listTenantStock(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = LocalStockItem::query()->forTenant($tenantId)->orderBy('id')->limit($limit + 1);

        foreach (['game_id', 'status'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['number'] ?? null) !== null && trim((string) $queryParams['number']) !== '') {
            $query->where('full_number', trim((string) $queryParams['number']));
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $stock): array => $this->tenantStockResource($stock), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findTenantStock(string $tenantId, string $stockItemId): ?array
    {
        $stock = LocalStockItem::query()
            ->forTenant($tenantId)
            ->where('id', $stockItemId)
            ->first();

        return $stock === null ? null : $this->tenantStockResource($stock);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function createStockExport(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $payloadHash = $this->payloadHash($payload);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $existing = TenantStockExportJob::query()
            ->where('tenant_id', $tenantId)
            ->where('requested_by_admin_id', $actor->adminUser['id'])
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if ($existing !== null) {
            if ($existing->payload_hash !== $payloadHash) {
                return ['error' => 'idempotency_conflict'];
            }

            return ['resource' => $this->exportResource($existing)];
        }

        $now = now();
        $jobId = 'exp_'.Str::ulid()->toBase32();

        TenantStockExportJob::query()->insert([
            'id' => $jobId,
            'tenant_id' => $tenantId,
            'status' => 'pending',
            'idempotency_key' => $idempotencyKey,
            'payload_hash' => $payloadHash,
            'requested_by_admin_id' => $actor->adminUser['id'],
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->auditAdminAction($actor, $request, 'stock.export_requested', 'tenant_stock_export_job', $jobId, $payload, $tenantId);

        return ['resource' => $this->exportResource(TenantStockExportJob::where('id', $jobId)->first())];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function createStockSyncBatch(string $tenantId, string $partnerId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $payloadHash = $this->payloadHash($payload);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $existing = StockSyncBatch::query()
            ->where('tenant_id', $tenantId)
            ->where('requested_by_admin_id', $actor->adminUser['id'])
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if ($existing !== null) {
            if ($existing->payload_hash !== $payloadHash) {
                return ['error' => 'idempotency_conflict'];
            }

            return ['resource' => $this->syncBatchResource($existing)];
        }

        return DB::transaction(function () use ($tenantId, $partnerId, $actor, $payload, $request, $payloadHash, $idempotencyKey): array {
            $now = now();
            $batchId = 'syn_'.Str::ulid()->toBase32();

            StockSyncBatch::query()->insert([
                'id' => $batchId,
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
                'allocation_id' => null,
                'status' => 'processing',
                'cursor' => $payload['cursor'] ?? null,
                'processed_count' => 0,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => $payloadHash,
                'requested_by_admin_id' => $actor->adminUser['id'],
                'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
                'started_at' => $now,
                'completed_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $events = $this->pendingAllocationEvents($tenantId, $partnerId, $payload);
            $processedCount = 0;
            $lastCursor = $payload['cursor'] ?? null;
            $lastAllocationId = null;

            foreach ($events as $event) {
                $lastCursor = (string) $event->id;
                $lastAllocationId = $event->aggregate_id;
                $processedCount += $this->consumeAllocatedStockEvent($event, $batchId);
            }

            $completedAt = now();

            StockSyncBatch::query()->where('id', $batchId)->update([
                'status' => 'completed',
                'allocation_id' => $lastAllocationId,
                'cursor' => $lastCursor,
                'processed_count' => $processedCount,
                'completed_at' => $completedAt,
                'updated_at' => $completedAt,
            ]);

            $this->insertOutboxEvent(
                eventType: 'stock.sync_completed.v1',
                tenantId: $tenantId,
                partnerId: $partnerId,
                gameId: $events[0]->game_id ?? null,
                aggregateType: 'stock_sync_batch',
                aggregateId: $batchId,
                idempotencyKey: $idempotencyKey,
                correlationId: $request->header('X-Request-Id'),
                payload: [
                    'sync_batch_id' => $batchId,
                    'allocation_id' => $lastAllocationId,
                    'partner_id' => $partnerId,
                    'tenant_id' => $tenantId,
                    'game_id' => $events[0]->game_id ?? null,
                    'last_cursor' => $lastCursor,
                    'upserted_count' => $processedCount,
                ],
            );

            $this->auditAdminAction($actor, $request, 'stock.sync_completed', 'stock_sync_batch', $batchId, $payload, $tenantId, $partnerId);

            return ['resource' => $this->syncBatchResource(StockSyncBatch::where('id', $batchId)->first())];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listStockSyncBatches(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = StockSyncBatch::query()->forTenant($tenantId)->orderBy('id')->limit($limit + 1);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $batch): array => $this->syncBatchResource($batch), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findStockSyncBatch(string $tenantId, string $batchId): ?array
    {
        $batch = StockSyncBatch::query()
            ->forTenant($tenantId)
            ->where('id', $batchId)
            ->first();

        return $batch === null ? null : $this->syncBatchResource($batch);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateReservationPayload(string $tenantId, CustomerSessionContext $customer, array $payload): array
    {
        $errors = [];
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $itemIds = $payload['local_stock_item_ids'] ?? null;

        if ($customer->tenantId() !== $tenantId) {
            $errors['customer'][] = 'The customer token does not belong to this tenant.';
        }

        if ($gameId === '' || ! Game::whereKey($gameId)->where('status', 'open')->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an open game.';
        }

        if (! is_array($itemIds) || $itemIds === []) {
            $errors['local_stock_item_ids'][] = 'The local_stock_item_ids field must include at least one item.';
        } elseif (count($itemIds) !== count(array_unique(array_map('strval', $itemIds)))) {
            $errors['local_stock_item_ids'][] = 'The local_stock_item_ids field must not contain duplicates.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function createReservation(string $tenantId, string $partnerId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $itemIds = array_values(array_map('strval', $payload['local_stock_item_ids']));
        sort($itemIds);
        $normalizedPayload = [
            'game_id' => trim((string) $payload['game_id']),
            'local_stock_item_ids' => $itemIds,
        ];
        $payloadHash = $this->payloadHash($normalizedPayload);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $existing = StockReservation::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customer->customerId())
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if ($existing !== null) {
            if ($existing->payload_hash !== $payloadHash) {
                return ['error' => 'idempotency_conflict'];
            }

            return ['resource' => $this->reservationResourceById((string) $existing->id)];
        }

        return DB::transaction(function () use ($tenantId, $partnerId, $customer, $normalizedPayload, $itemIds, $request, $payloadHash, $idempotencyKey): array {
            $gameId = $normalizedPayload['game_id'];

            if (! Game::query()->where('id', $gameId)->where('status', 'open')->lockForUpdate()->exists()) {
                return ['error' => 'reservation_unavailable'];
            }

            $stockRows = LocalStockItem::query()
                ->where('tenant_id', $tenantId)
                ->where('game_id', $gameId)
                ->whereIn('id', $itemIds)
                ->orderBy('id')
                ->lockForUpdate()
                ->get()
                ->all();

            if (count($stockRows) !== count($itemIds)) {
                return ['error' => 'reservation_unavailable'];
            }

            foreach ($stockRows as $stock) {
                if ($stock->status !== 'available') {
                    return ['error' => 'reservation_unavailable'];
                }
            }

            $now = now();
            $reservationId = 'res_'.Str::ulid()->toBase32();
            $expiresAt = $now->copy()->addMinutes(self::RESERVATION_TTL_MINUTES);

            StockReservation::query()->insert([
                'id' => $reservationId,
                'tenant_id' => $tenantId,
                'customer_id' => $customer->customerId(),
                'game_id' => $gameId,
                'status' => 'active',
                'expires_at' => $expiresAt,
                'released_at' => null,
                'cancelled_at' => null,
                'converted_at' => null,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => $payloadHash,
                'released_idempotency_key' => null,
                'released_payload_hash' => null,
                'cancelled_idempotency_key' => null,
                'cancelled_payload_hash' => null,
                'cancelled_by_admin_id' => null,
                'cancel_reason' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            StockReservationItem::query()->insert(array_map(fn (string $itemId): array => [
                'reservation_id' => $reservationId,
                'local_stock_item_id' => $itemId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ], $itemIds));

            LocalStockItem::query()
                ->where('tenant_id', $tenantId)
                ->whereIn('id', $itemIds)
                ->update([
                    'status' => 'reserved',
                    'reserved_at' => $now,
                    'updated_at' => $now,
                ]);

            $this->insertOutboxEvent(
                eventType: 'reservation.created.v1',
                tenantId: $tenantId,
                partnerId: $partnerId,
                gameId: $gameId,
                aggregateType: 'stock_reservation',
                aggregateId: $reservationId,
                idempotencyKey: $idempotencyKey,
                correlationId: $request->header('X-Request-Id'),
                payload: [
                    'reservation_id' => $reservationId,
                    'tenant_id' => $tenantId,
                    'customer_id' => $customer->customerId(),
                    'game_id' => $gameId,
                    'local_stock_item_ids' => $itemIds,
                    'expires_at' => $expiresAt->toISOString(),
                ],
            );

            $this->insertOutboxEvent(
                eventType: 'stock.unavailable.v1',
                tenantId: $tenantId,
                partnerId: $partnerId,
                gameId: $gameId,
                aggregateType: 'stock_reservation',
                aggregateId: $reservationId,
                idempotencyKey: $idempotencyKey,
                correlationId: $request->header('X-Request-Id'),
                payload: [
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'local_stock_item_ids' => $itemIds,
                    'reason' => 'reserved_or_sold',
                ],
            );

            return ['resource' => $this->reservationResourceById($reservationId)];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function releaseReservation(string $tenantId, string $partnerId, string $reservationId, CustomerSessionContext $customer, Request $request): array
    {
        $payloadHash = $this->payloadHash(['reservation_id' => $reservationId]);
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $partnerId, $reservationId, $customer, $request, $payloadHash, $idempotencyKey): array {
            $reservation = StockReservation::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customer->customerId())
                ->where('id', $reservationId)
                ->lockForUpdate()
                ->first();

            if ($reservation === null) {
                return ['error' => 'not_found'];
            }

            if ($reservation->status === 'released' && $reservation->released_idempotency_key === $idempotencyKey) {
                if ($reservation->released_payload_hash !== $payloadHash) {
                    return ['error' => 'idempotency_conflict'];
                }

                return ['resource' => $this->reservationResourceById($reservationId)];
            }

            if ($reservation->status !== 'active') {
                return ['error' => 'resource_conflict'];
            }

            return [
                'resource' => $this->releaseReservationRows(
                    reservation: $reservation,
                    tenantId: $tenantId,
                    partnerId: $partnerId,
                    releasedBy: 'customer',
                    idempotencyKey: $idempotencyKey,
                    payloadHash: $payloadHash,
                    request: $request,
                    status: 'released',
                ),
            ];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listReservations(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = StockReservation::query()->forTenant($tenantId)->orderBy('id')->limit($limit + 1);

        foreach (['status', 'customer_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $reservation): array => $this->adminReservationResource($reservation), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function cancelReservation(string $tenantId, string $partnerId, string $reservationId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $payloadHash = $this->payloadHash($payload + ['reservation_id' => $reservationId]);
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $partnerId, $reservationId, $actor, $payload, $request, $payloadHash, $idempotencyKey): array {
            $reservation = StockReservation::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $reservationId)
                ->lockForUpdate()
                ->first();

            if ($reservation === null) {
                return ['error' => 'not_found'];
            }

            if ($reservation->status === 'cancelled' && $reservation->cancelled_idempotency_key === $idempotencyKey) {
                if ($reservation->cancelled_payload_hash !== $payloadHash) {
                    return ['error' => 'idempotency_conflict'];
                }

                return ['resource' => $this->adminReservationResource(StockReservation::where('id', $reservationId)->first())];
            }

            if ($reservation->status !== 'active') {
                return ['error' => 'resource_conflict'];
            }

            $resource = $this->releaseReservationRows(
                reservation: $reservation,
                tenantId: $tenantId,
                partnerId: $partnerId,
                releasedBy: 'admin',
                idempotencyKey: $idempotencyKey,
                payloadHash: $payloadHash,
                request: $request,
                status: 'cancelled',
                adminId: $actor->adminUser['id'],
                reason: $payload['reason'] ?? null,
            );

            $this->auditAdminAction($actor, $request, 'reservation.cancelled', 'stock_reservation', $reservationId, $payload, $tenantId, $partnerId);

            return ['resource' => $this->adminReservationResource(StockReservation::where('id', $resource['id'])->first())];
        });
    }

    public function expireReservations(int $limit = 100): int
    {
        $reservationIds = StockReservation::query()
            ->where('status', 'active')
            ->where('expires_at', '<=', now())
            ->orderBy('expires_at')
            ->limit(max(1, min(500, $limit)))
            ->pluck('id')
            ->all();

        $expired = 0;

        foreach ($reservationIds as $reservationId) {
            if ($this->expireReservation((string) $reservationId)) {
                $expired++;
            }
        }

        return $expired;
    }

    private function expireReservation(string $reservationId): bool
    {
        return DB::transaction(function () use ($reservationId): bool {
            $reservation = StockReservation::query()->where('id', $reservationId)->lockForUpdate()->first();

            if ($reservation === null || $reservation->status !== 'active' || Carbon::parse((string) $reservation->expires_at)->isFuture()) {
                return false;
            }

            $tenant = PartnerTenant::where('id', $reservation->tenant_id)->first();

            if ($tenant === null) {
                return false;
            }

            $this->releaseReservationRows(
                reservation: $reservation,
                tenantId: (string) $reservation->tenant_id,
                partnerId: (string) $tenant->partner_id,
                releasedBy: 'system',
                idempotencyKey: 'reservation-expired-'.$reservationId,
                payloadHash: $this->payloadHash(['reservation_id' => $reservationId, 'expired' => true]),
                request: null,
                status: 'expired',
            );

            return true;
        });
    }

    /**
     * @return array<int, object>
     */
    private function pendingAllocationEvents(string $tenantId, string $partnerId, array $payload): array
    {
        $query = SyncOutbox::query()
            ->where('tenant_id', $tenantId)
            ->where('partner_id', $partnerId)
            ->where('event_type', 'stock.allocated.v1')
            ->where('status', 'pending')
            ->where('available_at', '<=', now())
            ->orderBy('id')
            ->limit($this->limit($payload['event_limit'] ?? $payload['limit'] ?? null))
            ->lockForUpdate();

        if (($payload['cursor'] ?? null) !== null && trim((string) $payload['cursor']) !== '') {
            $query->where('id', '>', trim((string) $payload['cursor']));
        }

        if (($payload['allocation_id'] ?? null) !== null && trim((string) $payload['allocation_id']) !== '') {
            $query->where('aggregate_id', trim((string) $payload['allocation_id']));
        }

        return $query->get()->all();
    }

    private function consumeAllocatedStockEvent(object $event, string $batchId): int
    {
        $payloadHash = $this->hashJsonValue($event->payload_json);
        $now = now();
        $existingInbox = SyncInbox::query()->where('event_id', $event->event_id)->lockForUpdate()->first();

        if ($existingInbox !== null && $existingInbox->status === 'processed') {
            SyncOutbox::query()->where('id', $event->id)->update([
                'status' => 'processed',
                'processed_at' => $now,
                'updated_at' => $now,
            ]);

            return 0;
        }

        if ($existingInbox === null) {
            SyncInbox::query()->insert([
                'id' => 'inb_'.Str::ulid()->toBase32(),
                'event_id' => (string) $event->event_id,
                'event_type' => (string) $event->event_type,
                'event_version' => (int) $event->event_version,
                'consumer' => 'partner_store',
                'tenant_id' => $event->tenant_id,
                'partner_id' => $event->partner_id,
                'game_id' => $event->game_id,
                'idempotency_key' => $event->idempotency_key,
                'payload_hash' => $payloadHash,
                'status' => 'processing',
                'processed_at' => null,
                'last_error' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        } else {
            SyncInbox::query()->where('event_id', $event->event_id)->update([
                'status' => 'processing',
                'updated_at' => $now,
            ]);
        }

        $payload = $this->decodeJsonObject($event->payload_json);
        $allocationId = (string) ($payload['allocation_id'] ?? $event->aggregate_id);
        $storeId = $this->stockStoreIdFromPayload($payload, (string) $event->tenant_id);
        $stockRows = PartnerStockAllocationItem::query()
            ->join('stock_items', 'stock_items.id', '=', 'partner_stock_allocation_items.stock_item_id')
            ->where('partner_stock_allocation_items.allocation_id', $allocationId)
            ->where('partner_stock_allocation_items.status', 'allocated')
            ->select([
                'partner_stock_allocation_items.partner_id',
                'partner_stock_allocation_items.tenant_id',
                'partner_stock_allocation_items.game_id',
                'partner_stock_allocation_items.allocation_id',
                'stock_items.id as stock_item_id',
                'stock_items.full_number',
                'stock_items.front3',
                'stock_items.back3',
                'stock_items.back2',
                'stock_items.image_generation_status as central_image_generation_status',
                'stock_items.image_generation_error as central_image_generation_error',
            ])
            ->orderBy('stock_items.id')
            ->get()
            ->all();

        $inserted = 0;
        $rows = [];

        foreach ($stockRows as $stock) {
            $rows[] = [
                'id' => $this->stableId('lsi', (string) $stock->tenant_id.':'.(string) $stock->stock_item_id),
                'tenant_id' => (string) $stock->tenant_id,
                'partner_id' => (string) $stock->partner_id,
                'store_id' => $storeId,
                'game_id' => (string) $stock->game_id,
                'stock_item_id' => (string) $stock->stock_item_id,
                'allocation_id' => (string) $stock->allocation_id,
                'full_number' => (string) $stock->full_number,
                'front3' => $stock->front3,
                'back3' => $stock->back3,
                'back2' => $stock->back2,
                'image_url' => null,
                'image_thumb_url' => null,
                'image_storage_path' => null,
                'image_thumb_storage_path' => null,
                'image_generation_status' => $stock->central_image_generation_status === 'pending_assets' ? 'pending_assets' : 'pending',
                'image_generation_error' => $stock->central_image_generation_status === 'pending_assets' ? $stock->central_image_generation_error : null,
                'image_generated_at' => null,
                'status' => 'available',
                'synced_at' => $now,
                'reserved_at' => null,
                'sold_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        if ($rows !== []) {
            $inserted = LocalStockItem::query()->insertOrIgnore($rows);
        }

        foreach ($rows as $row) {
            LocalStockItem::query()
                ->where('tenant_id', $row['tenant_id'])
                ->where('stock_item_id', $row['stock_item_id'])
                ->update([
                    'partner_id' => $row['partner_id'],
                    'store_id' => $row['store_id'],
                    'game_id' => $row['game_id'],
                    'allocation_id' => $row['allocation_id'],
                    'full_number' => $row['full_number'],
                    'front3' => $row['front3'],
                    'back3' => $row['back3'],
                    'back2' => $row['back2'],
                    'synced_at' => $now,
                    'updated_at' => $now,
                ]);
        }

        $this->dispatchPartnerImageJobs(array_map(fn (array $row): string => (string) $row['id'], $rows));

        SyncInbox::query()->where('event_id', $event->event_id)->update([
            'status' => 'processed',
            'processed_at' => $now,
            'updated_at' => $now,
        ]);

        SyncOutbox::query()->where('id', $event->id)->update([
            'status' => 'processed',
            'processed_at' => $now,
            'updated_at' => $now,
        ]);

        return $inserted;
    }

    /**
     * @param array<int, string> $localStockItemIds
     */
    private function dispatchPartnerImageJobs(array $localStockItemIds): void
    {
        foreach ($localStockItemIds as $localStockItemId) {
            GeneratePartnerLotteryImageJob::dispatch($localStockItemId)->afterCommit();
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function releaseReservationRows(
        object $reservation,
        string $tenantId,
        string $partnerId,
        string $releasedBy,
        string $idempotencyKey,
        string $payloadHash,
        ?Request $request,
        string $status,
        ?string $adminId = null,
        mixed $reason = null,
    ): array {
        $now = now();
        $itemIds = StockReservationItem::query()
            ->where('reservation_id', $reservation->id)
            ->where('tenant_id', $tenantId)
            ->pluck('local_stock_item_id')
            ->all();

        if ($itemIds !== []) {
            LocalStockItem::query()
                ->where('tenant_id', $tenantId)
                ->whereIn('id', $itemIds)
                ->where('status', 'reserved')
                ->update([
                    'status' => 'available',
                    'reserved_at' => null,
                    'updated_at' => $now,
                ]);

            StockReservationItem::query()
                ->where('reservation_id', $reservation->id)
                ->where('tenant_id', $tenantId)
                ->update([
                    'status' => $status,
                    'updated_at' => $now,
                ]);
        }

        $updates = [
            'status' => $status,
            'updated_at' => $now,
        ];

        if ($status === 'released') {
            $updates['released_at'] = $now;
            $updates['released_idempotency_key'] = $idempotencyKey;
            $updates['released_payload_hash'] = $payloadHash;
        } elseif ($status === 'cancelled') {
            $updates['cancelled_at'] = $now;
            $updates['cancelled_idempotency_key'] = $idempotencyKey;
            $updates['cancelled_payload_hash'] = $payloadHash;
            $updates['cancelled_by_admin_id'] = $adminId;
            $updates['cancel_reason'] = $reason;
        }

        StockReservation::query()->where('id', $reservation->id)->update($updates);

        $eventType = $status === 'expired' ? 'reservation.expired.v1' : 'reservation.released.v1';
        $payload = [
            'reservation_id' => (string) $reservation->id,
            'tenant_id' => $tenantId,
            'customer_id' => (string) $reservation->customer_id,
            'game_id' => (string) $reservation->game_id,
            'released_item_count' => count($itemIds),
        ];

        if ($eventType === 'reservation.released.v1') {
            $payload['released_by'] = $releasedBy;
        }

        $this->insertOutboxEvent(
            eventType: $eventType,
            tenantId: $tenantId,
            partnerId: $partnerId,
            gameId: (string) $reservation->game_id,
            aggregateType: 'stock_reservation',
            aggregateId: (string) $reservation->id,
            idempotencyKey: $idempotencyKey,
            correlationId: $request?->header('X-Request-Id'),
            payload: $payload,
        );

        return $this->reservationResourceById((string) $reservation->id);
    }

    /**
     * @return array<string, mixed>
     */
    private function gameResource(object $game): array
    {
        return [
            'id' => (string) $game->id,
            'code' => (string) $game->code,
            'name' => (string) $game->name,
            'draw_at' => $game->draw_at,
            'close_at' => $game->close_at,
            'server_time' => now()->toISOString(),
            'status' => (string) $game->status,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function localStockResource(object $stock): array
    {
        return [
            'id' => (string) $stock->id,
            'game_id' => (string) $stock->game_id,
            'full_number' => (string) $stock->full_number,
            'front3' => $stock->front3,
            'back3' => $stock->back3,
            'back2' => $stock->back2,
            'status' => (string) $stock->status,
            'price' => ['amount' => 0, 'currency' => 'THB'],
            'price_rule_summary' => null,
            'image_thumb_url' => $stock->image_thumb_url,
            'image_url' => $stock->image_url,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantStockResource(object $stock): array
    {
        return array_merge($this->localStockResource($stock), [
            'tenant_id' => (string) $stock->tenant_id,
            'partner_id' => (string) $stock->partner_id,
            'stock_item_id' => (string) $stock->stock_item_id,
            'allocation_id' => $stock->allocation_id,
            'created_at' => $stock->created_at,
            'updated_at' => $stock->updated_at,
            'synced_at' => $stock->synced_at,
            'reserved_at' => $stock->reserved_at,
        ]);
    }

    /**
     * @return array<string, mixed>|null
     */
    private function reservationResourceById(string $reservationId): ?array
    {
        $reservation = StockReservation::where('id', $reservationId)->first();

        if ($reservation === null) {
            return null;
        }

        $items = StockReservationItem::query()
            ->join('local_stock_items', 'local_stock_items.id', '=', 'stock_reservation_items.local_stock_item_id')
            ->where('stock_reservation_items.reservation_id', $reservationId)
            ->orderBy('local_stock_items.id')
            ->select('local_stock_items.*')
            ->get()
            ->all();

        return [
            'id' => (string) $reservation->id,
            'game_id' => (string) $reservation->game_id,
            'status' => (string) $reservation->status,
            'expires_at' => $reservation->expires_at,
            'server_time' => now()->toISOString(),
            'items' => array_map(fn (object $stock): array => $this->localStockResource($stock), $items),
            'tenant_id' => (string) $reservation->tenant_id,
            'customer_id' => (string) $reservation->customer_id,
            'created_at' => $reservation->created_at,
            'updated_at' => $reservation->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function adminReservationResource(object $reservation): array
    {
        return array_merge($this->reservationResourceById((string) $reservation->id) ?? [], [
            'tenant_id' => (string) $reservation->tenant_id,
            'customer_id' => (string) $reservation->customer_id,
            'released_at' => $reservation->released_at,
            'cancelled_at' => $reservation->cancelled_at,
            'converted_at' => $reservation->converted_at,
            'cancelled_by_admin_id' => $reservation->cancelled_by_admin_id,
            'cancel_reason' => $reservation->cancel_reason,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function syncBatchResource(object $batch): array
    {
        return [
            'id' => (string) $batch->id,
            'tenant_id' => (string) $batch->tenant_id,
            'status' => (string) $batch->status,
            'created_at' => $batch->created_at,
            'updated_at' => $batch->updated_at,
            'partner_id' => (string) $batch->partner_id,
            'allocation_id' => $batch->allocation_id,
            'cursor' => $batch->cursor,
            'processed_count' => (int) $batch->processed_count,
            'started_at' => $batch->started_at,
            'completed_at' => $batch->completed_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function exportResource(object $job): array
    {
        return [
            'id' => (string) $job->id,
            'tenant_id' => (string) $job->tenant_id,
            'status' => (string) $job->status,
            'created_at' => $job->created_at,
            'updated_at' => $job->updated_at,
            'type' => 'tenant_stock_export',
        ];
    }

    private function maintenanceOperation(Request $request, bool|string $maintenanceOperation): ?string
    {
        if ($maintenanceOperation === false) {
            return null;
        }

        if (is_string($maintenanceOperation)) {
            return $maintenanceOperation;
        }

        $path = $request->path();
        $method = $request->method();

        if (str_starts_with($path, 'api/v1/public/')) {
            return 'public_read';
        }

        if (str_starts_with($path, 'api/v1/customer/reservations')) {
            return 'reservation_write';
        }

        if ($path === 'api/v1/customer/checkout') {
            return 'checkout_payment';
        }

        if (str_starts_with($path, 'api/v1/customer/topups') && $method !== 'GET') {
            return 'payment_write';
        }

        if ($path === 'api/v1/customer/profile' && $method !== 'GET') {
            return 'profile_write';
        }

        if (str_starts_with($path, 'api/v1/customer/')) {
            return $method === 'GET' ? 'customer_read' : 'customer_write';
        }

        return 'public_read';
    }

    private function hasActiveMaintenanceBypass(string $tenantId, Request $request): bool
    {
        $token = $request->bearerToken();

        if ($token !== null && $token !== '') {
            $customerSession = CustomerAuthSession::query()
                ->where('tenant_id', $tenantId)
                ->where('access_token_hash', hash('sha256', $token))
                ->whereNull('revoked_at')
                ->where('access_expires_at', '>', now())
                ->first();

            if ($customerSession !== null && $this->bypassExists($tenantId, 'customer', (string) $customerSession->customer_id)) {
                return true;
            }
        }

        $supportSessionId = (string) $request->header('X-Support-Impersonation-Session-Id', '');
        $supportToken = (string) $request->header('X-Support-Impersonation-Token', '');

        if ($supportSessionId !== '' && $supportToken !== '') {
            $supportSession = SupportImpersonationSession::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $supportSessionId)
                ->where('status', 'active')
                ->where('expires_at', '>', now())
                ->where('token_hash', hash('sha256', $supportToken))
                ->first();

            if ($supportSession !== null && $this->bypassExists($tenantId, 'support_session', $supportSessionId)) {
                return true;
            }
        }

        return false;
    }

    private function bypassExists(string $tenantId, string $actorType, string $actorId): bool
    {
        return PartnerTenantMaintenanceBypass::query()
            ->where('tenant_id', $tenantId)
            ->where('actor_type', $actorType)
            ->where('actor_id', $actorId)
            ->where('status', 'active')
            ->where(function ($query): void {
                $query->whereNull('expires_at')->orWhere('expires_at', '>', now());
            })
            ->exists();
    }

    private function auditAdminAction(
        AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetType,
        string $targetId,
        array $payload,
        string $tenantId,
        ?string $partnerId = null,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'tenant',
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: [
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            tenantId: $tenantId,
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    private function insertOutboxEvent(
        string $eventType,
        string $tenantId,
        ?string $partnerId,
        ?string $gameId,
        string $aggregateType,
        string $aggregateId,
        ?string $idempotencyKey,
        ?string $correlationId,
        array $payload,
    ): void {
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => $eventType,
            'event_version' => 1,
            'producer' => 'partner_store',
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'game_id' => $gameId,
            'aggregate_type' => $aggregateType,
            'aggregate_id' => $aggregateId,
            'idempotency_key' => $idempotencyKey,
            'correlation_id' => $correlationId,
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function normalizeHost(string $host): string
    {
        return strtolower(preg_replace('/:\d+$/', '', trim($host)) ?? $host);
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, (int) $limit));
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function payloadHash(array $payload): string
    {
        ksort($payload);

        return hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR));
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJsonObject(mixed $json): array
    {
        if (is_array($json)) {
            return $json;
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $decoded : [];
    }

    private function hashJsonValue(mixed $json): string
    {
        return hash('sha256', is_array($json) ? json_encode($json, JSON_THROW_ON_ERROR) : (string) $json);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function stockStoreIdFromPayload(array $payload, string $tenantId): string
    {
        foreach (['store_id', 'seller_id'] as $field) {
            if (($payload[$field] ?? null) !== null && trim((string) $payload[$field]) !== '') {
                $storeId = trim((string) $payload[$field]);

                return strlen($storeId) <= 128 ? $storeId : $tenantId;
            }
        }

        foreach (['store', 'seller'] as $field) {
            $value = $payload[$field] ?? null;

            if (is_array($value) && ($value['id'] ?? null) !== null && trim((string) $value['id']) !== '') {
                $storeId = trim((string) $value['id']);

                return strlen($storeId) <= 128 ? $storeId : $tenantId;
            }

            if (is_string($value) && trim($value) !== '') {
                $storeId = trim($value);

                return strlen($storeId) <= 128 ? $storeId : $tenantId;
            }
        }

        return $tenantId;
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
}
