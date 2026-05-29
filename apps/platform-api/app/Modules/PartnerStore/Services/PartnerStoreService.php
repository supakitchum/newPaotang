<?php

namespace App\Modules\PartnerStore\Services;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantMaintenanceBypass;
use App\Models\StockReservation;
use App\Models\StockReservationItem;
use App\Models\SupportImpersonationSession;
use App\Models\SyncOutbox;
use App\Models\TenantStockExportJob;
use App\Modules\Pricing\Services\LotterySalePriceService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use App\Modules\Maintenance\Services\MaintenanceService;
use App\Shared\Tenancy\TenantHostNormalizer;
use App\Support\CustomerNo;
use App\Support\PublicUrl;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class PartnerStoreService
{
    private const RESERVATION_STATUSES = ['active', 'released', 'expired', 'converted', 'cancelled'];
    private const ACTIVE_ALLOCATION_PAIR_STATUSES = ['pending', 'processing', 'allocated', 'partially_allocated'];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly MaintenanceService $maintenance,
        private readonly VirtualStockService $virtualStock,
        private readonly LotterySalePriceService $salePrices,
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
            ->whereIn('partner_tenant_domains.host', TenantHostNormalizer::variants($host))
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
        $partnerId = $this->partnerIdForTenant($tenantId);

        if ($partnerId === null) {
            return null;
        }

        $game = $this->saleOpenGameQuery($partnerId)
            ->whereIn('games.id', $this->tenantAllocatedGameIdsQuery($partnerId, $tenantId))
            ->orderBy('games.draw_at')
            ->first();

        if ($game === null) {
            $game = $this->saleOpenGameQuery($partnerId)
                ->orderBy('games.draw_at')
                ->first();
        }

        if ($game === null) {
            $game = Game::query()
                ->where('games.status', 'open')
                ->whereIn('games.id', $this->tenantAllocatedGameIdsQuery($partnerId, $tenantId))
                ->select('games.*')
                ->orderByDesc('games.draw_at')
                ->first();
        }

        if ($game === null) {
            $game = Game::query()
                ->where('games.status', 'open')
                ->select('games.*')
                ->orderByDesc('games.draw_at')
                ->first();
        }

        if ($game === null) {
            $game = Game::query()
                ->whereIn('games.id', $this->tenantAllocatedGameIdsQuery($partnerId, $tenantId))
                ->select('games.*')
                ->orderByDesc('games.draw_at')
                ->first();
        }

        if ($game === null) {
            $game = Game::query()
                ->select('games.*')
                ->orderByDesc('games.draw_at')
                ->first();
        }

        return $game === null ? null : $this->gameResource($game);
    }

    private function tenantAllocatedGameIdsQuery(string $partnerId, string $tenantId): \Illuminate\Database\Query\Builder
    {
        return DB::table('partner_stock_allocations')
            ->join('stock_supply_profiles', 'stock_supply_profiles.game_id', '=', 'partner_stock_allocations.game_id')
            ->where('partner_stock_allocations.partner_id', $partnerId)
            ->where('partner_stock_allocations.tenant_id', $tenantId)
            ->whereIn('partner_stock_allocations.status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->where('partner_stock_allocations.allocated_count', '>', 0)
            ->where('stock_supply_profiles.status', 'active')
            ->select('partner_stock_allocations.game_id');
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function tenantStockGames(string $tenantId): array
    {
        $partnerId = $this->partnerIdForTenant($tenantId);

        if ($partnerId === null) {
            return ['data' => [], 'meta' => ['default_game_id' => null]];
        }

        $games = [];
        $virtualRows = DB::table('partner_stock_allocations')
            ->join('games', 'games.id', '=', 'partner_stock_allocations.game_id')
            ->join('stock_supply_profiles', 'stock_supply_profiles.game_id', '=', 'partner_stock_allocations.game_id')
            ->where('partner_stock_allocations.partner_id', $partnerId)
            ->where('partner_stock_allocations.tenant_id', $tenantId)
            ->whereIn('partner_stock_allocations.status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->where('partner_stock_allocations.allocated_count', '>', 0)
            ->where('stock_supply_profiles.status', 'active')
            ->groupBy('games.id', 'games.code', 'games.name', 'games.status', 'games.sale_start_at', 'games.draw_at', 'games.close_at')
            ->get([
                'games.id',
                'games.code',
                'games.name',
                'games.status',
                'games.sale_start_at',
                'games.draw_at',
                'games.close_at',
                DB::raw('SUM(partner_stock_allocations.allocated_count) as allocated_count'),
                DB::raw('MAX(partner_stock_allocations.created_at) as latest_stock_at'),
            ]);

        foreach ($virtualRows as $row) {
            $games[(string) $row->id] = $this->tenantStockGameResource($row, 'virtual');
        }

        $rows = array_values($games);
        usort($rows, fn (array $a, array $b): int => $this->tenantStockGameSortValue($b) <=> $this->tenantStockGameSortValue($a));
        $defaultGameId = $rows[0]['id'] ?? null;

        foreach ($rows as &$row) {
            $row['is_default'] = $row['id'] === $defaultGameId;
        }
        unset($row);

        return [
            'data' => $rows,
            'meta' => [
                'default_game_id' => $defaultGameId,
            ],
        ];
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

        foreach (range(1, 6) as $position) {
            $field = 'd'.$position;

            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $value = trim((string) $queryParams[$field]);

                if (! preg_match('/^[0-9]$/', $value)) {
                    $errors[$field][] = 'The '.$field.' field must be a single digit.';
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
        $gameId = trim((string) $queryParams['game_id']);
        $partnerId = $this->partnerIdForTenant($tenantId);

        if ($partnerId === null || ! $this->gameSaleOpenForPartner($partnerId, $gameId)) {
            return [
                'data' => [],
                'meta' => [
                    'next_cursor' => null,
                    'has_more' => false,
                ],
            ];
        }

        $virtualResult = $this->virtualStock->searchLocalStock($tenantId, $partnerId, $queryParams, $limit);

        if ($virtualResult !== null) {
            return $virtualResult;
        }

        return [
            'data' => [],
            'meta' => [
                'game_id' => $gameId,
                'next_cursor' => null,
                'has_more' => false,
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
        $partnerId = $this->partnerIdForTenant($tenantId);
        $status = trim((string) ($queryParams['status'] ?? ''));

        if ($partnerId === null) {
            return [
                'data' => [],
                'meta' => [
                    'next_cursor' => null,
                    'has_more' => false,
                ],
            ];
        }

        if ($status === '' || $status === 'available') {
            $virtualResult = $this->virtualStock->listTenantStock($tenantId, $partnerId, $queryParams, $limit);

            if ($virtualResult !== null) {
                return $virtualResult;
            }
        }

        $sort = $this->resolveTenantStockSort($queryParams);
        $query = LocalStockItem::query()
            ->forTenant($tenantId)
            ->whereNotNull('virtual_stock_ref')
            ->limit($limit + 1);

        foreach (['game_id', 'status'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['number'] ?? null) !== null && trim((string) $queryParams['number']) !== '') {
            $query->where('full_number', trim((string) $queryParams['number']));
        }

        if ($sort === null) {
            $query->orderBy('id');
        } else {
            $this->applyTenantStockOrder($query, $sort);
        }

        if ($sort === null && ($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        } elseif ($sort !== null) {
            $this->applyTenantStockCursor($query, $queryParams['cursor'] ?? null, $sort);
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $stock): array => $this->tenantStockResource($stock), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? ($sort === null ? (string) end($rows)->id : $this->tenantStockCursor(end($rows), $sort)) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{key: string, column: string, direction: string}|null
     */
    private function resolveTenantStockSort(array $queryParams): ?array
    {
        $key = trim((string) ($queryParams['sort_by'] ?? ''));
        if ($key === '') {
            return null;
        }

        $allowed = [
            'id' => 'id',
            'game_id' => 'game_id',
            'stock_item_id' => 'stock_item_id',
            'full_number' => 'full_number',
            'front3' => 'front3',
            'back3' => 'back3',
            'back2' => 'back2',
            'status' => 'status',
            'partner_id' => 'partner_id',
            'tenant_id' => 'tenant_id',
            'allocation_id' => 'allocation_id',
            'created_at' => 'created_at',
            'updated_at' => 'updated_at',
            'synced_at' => 'synced_at',
            'reserved_at' => 'reserved_at',
        ];

        if (! isset($allowed[$key])) {
            return null;
        }

        return [
            'key' => $key,
            'column' => $allowed[$key],
            'direction' => strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc',
        ];
    }

    private function applyTenantStockOrder(mixed $query, array $sort): void
    {
        $query->orderBy($sort['column'], $sort['direction']);

        if ($sort['column'] !== 'id') {
            $query->orderBy('id');
        }
    }

    private function applyTenantStockCursor(mixed $query, mixed $rawCursor, array $sort): void
    {
        $cursor = $this->decodeTenantStockCursor($rawCursor, $sort);
        if ($cursor === null) {
            return;
        }

        $operator = $sort['direction'] === 'desc' ? '<' : '>';
        $query->where(function ($nested) use ($cursor, $operator, $sort): void {
            $nested
                ->where($sort['column'], $operator, $cursor['value'])
                ->orWhere(function ($sameValue) use ($cursor, $sort): void {
                    $sameValue
                        ->where($sort['column'], $cursor['value'])
                        ->where('id', '>', $cursor['id']);
                });
        });
    }

    private function tenantStockCursor(object $stock, array $sort): string
    {
        return base64_encode(json_encode([
            'sort_by' => $sort['key'],
            'sort_dir' => $sort['direction'],
            'value' => $stock->{$sort['column']} ?? null,
            'id' => (string) $stock->id,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * @return array{value: mixed, id: string}|null
     */
    private function decodeTenantStockCursor(mixed $cursor, array $sort): ?array
    {
        if ($cursor === null || trim((string) $cursor) === '') {
            return null;
        }

        try {
            $decoded = json_decode((string) base64_decode((string) $cursor, true), true, flags: JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            return null;
        }

        if (! is_array($decoded)
            || ($decoded['sort_by'] ?? null) !== $sort['key']
            || ($decoded['sort_dir'] ?? null) !== $sort['direction']
            || ! array_key_exists('value', $decoded)
            || ! isset($decoded['id'])) {
            return null;
        }

        return [
            'value' => $decoded['value'],
            'id' => (string) $decoded['id'],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findTenantStock(string $tenantId, string $stockItemId): ?array
    {
        $stock = LocalStockItem::query()
            ->forTenant($tenantId)
            ->whereNotNull('virtual_stock_ref')
            ->where(function ($query) use ($stockItemId): void {
                $query->where('id', $stockItemId)
                    ->orWhere('virtual_stock_ref', $stockItemId);
            })
            ->first();

        if ($stock !== null) {
            return $this->tenantStockResource($stock);
        }

        $partnerId = $this->partnerIdForTenant($tenantId);

        return $partnerId === null ? null : $this->virtualStock->findTenantStock($tenantId, $partnerId, $stockItemId);
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
        } elseif (array_filter(array_map('strval', $itemIds), fn (string $itemId): bool => ! str_starts_with($itemId, 'vstock:')) !== []) {
            $errors['local_stock_item_ids'][] = 'The local_stock_item_ids field must contain virtual stock references.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function createReservation(string $tenantId, string $partnerId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $gameId = trim((string) ($payload['game_id'] ?? ''));

        if (! $this->gameSaleOpenForPartner($partnerId, $gameId)) {
            return ['error' => 'reservation_unavailable'];
        }

        $virtualReservation = $this->virtualStock->createReservation($tenantId, $partnerId, $customer, $payload, $request);

        if ($virtualReservation !== null) {
            return $virtualReservation;
        }

        return ['error' => 'reservation_unavailable'];
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
        $query = StockReservation::query()
            ->select('stock_reservations.*')
            ->leftJoin('customers', function ($join) use ($tenantId): void {
                $join->on('customers.id', '=', 'stock_reservations.customer_id')
                    ->where('customers.tenant_id', '=', $tenantId);
            })
            ->forTenant($tenantId);

        foreach (['status', 'customer_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where('stock_reservations.'.$field, trim((string) $queryParams[$field]));
            }
        }

        $customerNo = trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no'] ?? ''));

        if ($customerNo !== '') {
            $query->where('customers.customer_no', 'ilike', '%'.$customerNo.'%');
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('stock_reservations.id', '>', trim((string) $queryParams['cursor']));
        }

        $this->applyReservationSort($query, $queryParams);
        $query->limit($limit + 1);

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
     * @return array<string, mixed>|null
     */
    public function adminReservation(string $tenantId, string $reservationId): ?array
    {
        $reservation = StockReservation::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $reservationId)
            ->first();

        return $reservation === null ? null : $this->adminReservationResource($reservation);
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyReservationSort(mixed $query, array $queryParams): void
    {
        $sortBy = (string) ($queryParams['sort_by'] ?? 'created_at');
        $defaultDirection = $sortBy === 'created_at' ? 'desc' : 'asc';
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? $defaultDirection)) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'stock_reservations.id',
            'customer_no' => 'customers.customer_no',
            'member_no' => 'customers.customer_no',
            'customer_id' => 'stock_reservations.customer_id',
            'status' => 'stock_reservations.status',
            'created_at' => 'stock_reservations.created_at',
            'expires_at' => 'stock_reservations.expires_at',
            'expires' => 'stock_reservations.expires_at',
        ];
        $column = $columns[$sortBy] ?? 'stock_reservations.created_at';

        $query->reorder($column, $direction);

        if ($column !== 'stock_reservations.id') {
            $query->orderBy('stock_reservations.id', $direction);
        }
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

    public function expireCustomerReservations(string $tenantId, string $customerId, int $limit = 100): int
    {
        $reservationIds = StockReservation::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
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
            $this->virtualStock->releaseReservationCounters(
                reservation: $reservation,
                tenantId: $tenantId,
                partnerId: $partnerId,
                customerId: (string) $reservation->customer_id,
            );

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
            'sale_start_at' => $game->sale_start_at,
            'draw_at' => $game->draw_at,
            'close_at' => $game->close_at,
            'server_time' => now()->toISOString(),
            'status' => (string) $game->status,
        ];
    }

    private function gameSaleOpenForPartner(string $partnerId, string $gameId): bool
    {
        return $this->saleOpenGameQuery($partnerId, $gameId)->exists();
    }

    private function saleOpenGameQuery(string $partnerId, ?string $gameId = null): \Illuminate\Database\Eloquent\Builder
    {
        $now = now();
        $query = Game::query()
            ->where('games.status', 'open')
            ->where('games.sale_start_at', '<=', $now)
            ->where('games.close_at', '>', $now)
            ->select('games.*');

        if ($gameId !== null && $gameId !== '') {
            $query->where('games.id', $gameId);
        }

        return $query;
    }

    /**
     * @return array<string, mixed>
     */
    private function localStockResource(object $stock, bool $includeStockMode = true): array
    {
        $price = $this->salePrices->effectivePrice((string) $stock->tenant_id, (string) $stock->game_id, 1);
        $resource = [
            'id' => (string) $stock->id,
            'game_id' => (string) $stock->game_id,
            'full_number' => (string) $stock->full_number,
            'front3' => $stock->front3,
            'back3' => $stock->back3,
            'back2' => $stock->back2,
            'status' => (string) $stock->status,
            'stock_ref' => $stock->virtual_stock_ref,
            'virtual_copy_index' => $stock->virtual_copy_index,
            'remaining_count' => null,
            'availability_status' => (string) $stock->status,
            'price' => ['amount' => (int) $price['amount'], 'currency' => (string) $price['currency']],
            'price_rule_summary' => $this->salePrices->summary($price),
            'image_thumb_url' => PublicUrl::normalizeAssetUrl($stock->image_thumb_url),
            'image_url' => PublicUrl::normalizeAssetUrl($stock->image_url),
        ];

        if ($includeStockMode) {
            $resource['stock_mode'] = $stock->virtual_stock_ref === null ? 'physical' : 'virtual';
        }

        return $resource;
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantStockResource(object $stock): array
    {
        $ownerCustomerId = $this->tenantStockOwnerCustomerId($stock);

        return array_merge($this->localStockResource($stock), [
            'tenant_id' => (string) $stock->tenant_id,
            'partner_id' => (string) $stock->partner_id,
            'stock_item_id' => (string) $stock->stock_item_id,
            'allocation_id' => $stock->allocation_id,
            'owner_customer_id' => $ownerCustomerId,
            'owner' => $ownerCustomerId,
            'created_at' => $stock->created_at,
            'updated_at' => $stock->updated_at,
            'synced_at' => $stock->synced_at,
            'reserved_at' => $stock->reserved_at,
            'sold_at' => $stock->sold_at ?? null,
        ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantStockGameResource(object $game, string $stockMode): array
    {
        $code = (string) ($game->code ?? '');
        $name = (string) ($game->name ?? $game->id);

        return [
            'id' => (string) $game->id,
            'game_id' => (string) $game->id,
            'code' => $code,
            'name' => $name,
            'label' => trim(($code !== '' ? $code.' - ' : '').$name).($game->status === 'open' ? ' (Current)' : ''),
            'status' => (string) $game->status,
            'is_current' => (string) $game->status === 'open',
            'allocated_count' => (int) ($game->allocated_count ?? 0),
            'stock_modes' => [$stockMode],
            'latest_stock_at' => $game->latest_stock_at,
            'sale_start_at' => $game->sale_start_at,
            'draw_at' => $game->draw_at,
            'close_at' => $game->close_at,
        ];
    }

    private function tenantStockGameSortValue(array $game): int
    {
        $statusScore = ($game['status'] ?? '') === 'open' ? 9_000_000_000_000 : 0;
        $timestamp = strtotime((string) ($game['draw_at'] ?? $game['latest_stock_at'] ?? '')) ?: 0;

        return $statusScore + $timestamp;
    }

    private function tenantStockOwnerCustomerId(object $stock): ?string
    {
        if (! in_array((string) $stock->status, ['reserved', 'sold'], true)) {
            return null;
        }

        $customerId = DB::table('stock_reservation_items')
            ->join('stock_reservations', 'stock_reservations.id', '=', 'stock_reservation_items.reservation_id')
            ->where('stock_reservation_items.tenant_id', (string) $stock->tenant_id)
            ->where('stock_reservation_items.local_stock_item_id', (string) $stock->id)
            ->whereIn('stock_reservation_items.status', ['active', 'converted'])
            ->whereIn('stock_reservations.status', ['active', 'converted'])
            ->orderByDesc('stock_reservation_items.updated_at')
            ->value('stock_reservations.customer_id');

        return $customerId === null ? null : (string) $customerId;
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
        $customerNo = $this->customerNoForId((string) $reservation->tenant_id, (string) $reservation->customer_id);

        return [
            'id' => (string) $reservation->id,
            'game_id' => (string) $reservation->game_id,
            'status' => (string) $reservation->status,
            'expires_at' => $this->dateTimeIso($reservation->expires_at),
            'expires_in_seconds' => $this->remainingSeconds($reservation->expires_at),
            'server_time' => now()->toISOString(),
            'items' => array_map(fn (object $stock): array => $this->localStockResource($stock, false), $items),
            'tenant_id' => (string) $reservation->tenant_id,
            'customer_id' => (string) $reservation->customer_id,
            'customer_no' => $customerNo,
            'member_no' => $customerNo,
            'created_at' => $reservation->created_at,
            'updated_at' => $reservation->updated_at,
        ];
    }

    private function dateTimeIso(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        return Carbon::parse((string) $value)->toISOString();
    }

    private function customerNoForId(string $tenantId, string $customerId): ?string
    {
        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->first(['id', 'customer_no']);

        return $customer === null ? null : CustomerNo::display($customer->customer_no ?? null, (string) $customer->id);
    }

    private function remainingSeconds(mixed $expiresAt): int
    {
        if ($expiresAt === null || $expiresAt === '') {
            return 0;
        }

        return max(0, Carbon::parse((string) $expiresAt)->getTimestamp() - now()->getTimestamp());
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
        return TenantHostNormalizer::normalize($host);
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

}
