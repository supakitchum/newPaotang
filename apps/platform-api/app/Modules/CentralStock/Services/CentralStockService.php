<?php

namespace App\Modules\CentralStock\Services;

use App\Jobs\GenerateLotteryImageJob;
use App\Models\Game;
use App\Models\Partner;
use App\Models\PartnerQuota;
use App\Models\PartnerStockAllocation;
use App\Models\PartnerStockAllocationItem;
use App\Models\PartnerTenant;
use App\Models\RewardPrize;
use App\Models\RewardResult;
use App\Models\StockGenerationBatch;
use App\Models\StockItem;
use App\Models\SyncOutbox;
use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CentralStockService
{
    private const GENERATE_NUMBER_DIGITS = 6;
    private const GENERATE_BASE_COUNT = 1000;
    private const GENERATE_MAX_SYNC_COUNT = 10000;

    private const GAME_STATUSES = [
        'draft',
        'open',
        'closed',
        'reward_recorded',
        'reward_checking',
        'reward_verified',
        'reward_published',
        'archived',
    ];

    private const STOCK_STATUSES = ['available', 'allocated', 'sold', 'recalled', 'voided'];
    private const QUOTA_STATUSES = ['active', 'inactive', 'archived'];
    private const BUSINESS_TIMEZONE = 'Asia/Bangkok';
    private const ALLOCATION_STATUSES = [
        'draft',
        'pending',
        'processing',
        'allocated',
        'partially_allocated',
        'failed',
        'recalled',
        'cancelled',
    ];
    private const CANCELLABLE_ALLOCATION_STATUSES = ['draft', 'pending', 'processing', 'partially_allocated', 'failed'];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly LotteryImageGenerator $lotteryImages,
    ) {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>}
     */
    public function listGames(array $queryParams): array
    {
        $query = Game::query()->orderByDesc('draw_at')->orderBy('code');

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        return [
            'data' => array_map(
                fn (object $game): array => $this->gameResource($game),
                $query->limit($this->limit($queryParams['limit'] ?? null))->get()->all(),
            ),
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findGame(string $gameId): ?array
    {
        $game = Game::where('id', $gameId)->first();

        return $game === null ? null : $this->gameResource($game);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateGamePayload(array $payload, bool $creating, ?string $gameId = null): array
    {
        $errors = [];
        $existingGame = ! $creating && $gameId !== null ? Game::whereKey($gameId)->first() : null;

        if (! $creating && array_key_exists('code', $payload)) {
            $code = trim((string) ($payload['code'] ?? ''));

            if ($code === '' || ! preg_match('/^[a-z0-9][a-z0-9_-]*$/', $code)) {
                $errors['code'][] = 'The code field must use lowercase letters, numbers, underscores, or hyphens.';
            }
        }

        if ($creating || array_key_exists('name', $payload)) {
            $name = trim((string) ($payload['name'] ?? ''));

            if ($name === '') {
                $errors['name'][] = 'The name field is required.';
            }
        }

        if ($creating || array_key_exists('sale_start_at', $payload)) {
            if (! $this->canParseDate($payload['sale_start_at'] ?? null)) {
                $errors['sale_start_at'][] = 'The sale_start_at field must be a valid date-time.';
            }
        }

        if ($creating || array_key_exists('draw_at', $payload)) {
            if (! $this->canParseDate($payload['draw_at'] ?? null)) {
                $errors['draw_at'][] = 'The draw_at field must be a valid date-time.';
            }
        }

        if ($creating || array_key_exists('close_at', $payload)) {
            if (! $this->canParseDate($payload['close_at'] ?? null)) {
                $errors['close_at'][] = 'The close_at field must be a valid date-time.';
            }
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::GAME_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if ($creating && array_key_exists('status', $payload) && ! in_array($payload['status'], ['draft', 'open'], true)) {
            $errors['status'][] = 'A game can only be created as draft or open.';
        }

        if (! isset($errors['sale_start_at']) && ! isset($errors['draw_at']) && ! isset($errors['close_at'])) {
            $saleStartAt = $this->dateFromPayloadOrModel($payload, 'sale_start_at', $existingGame);
            $drawAt = $this->dateFromPayloadOrModel($payload, 'draw_at', $existingGame);
            $closeAt = $this->dateFromPayloadOrModel($payload, 'close_at', $existingGame);
            $targetStatus = (string) ($payload['status'] ?? $existingGame?->status ?? '');

            if ($targetStatus === 'open' && $saleStartAt === null) {
                $errors['sale_start_at'][] = 'The sale_start_at field is required before opening a game.';
            }

            if ($targetStatus === 'open' && $closeAt === null) {
                $errors['close_at'][] = 'The close_at field is required before opening a game.';
            }

            if ($saleStartAt !== null && $closeAt !== null && ! $closeAt->greaterThan($saleStartAt)) {
                $errors['close_at'][] = 'The close_at field must be after sale_start_at.';
            }

            if ($drawAt !== null && $closeAt !== null && ! $drawAt->greaterThan($closeAt)) {
                $errors['close_at'][] = 'The close_at field must be before draw_at.';
            }

            if ($gameId !== null && ($saleStartAt !== null || $closeAt !== null)) {
                $errors = $this->mergeFieldErrors($errors, $this->partnerQuotaWindowErrorsForGame($gameId, $saleStartAt, $closeAt));
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function withGeneratedGameCode(array $payload): array
    {
        unset($payload['code']);

        if ($this->canParseDate($payload['draw_at'] ?? null)) {
            $payload['code'] = $this->gameCodeFromDrawAt($payload['draw_at']);
        }

        return $payload;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function gameConflictErrors(array $payload, ?string $ignoreGameId = null): array
    {
        if (! array_key_exists('code', $payload)) {
            return [];
        }

        $code = trim((string) $payload['code']);

        if ($code === '') {
            return [];
        }

        $query = Game::query()->where('code', $code);

        if ($ignoreGameId !== null) {
            $query->where('id', '!=', $ignoreGameId);
        }

        return $query->exists() ? ['code' => ['The game code already exists.']] : [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function gameTransitionErrors(string $gameId, array $payload): array
    {
        if (! array_key_exists('status', $payload)) {
            return [];
        }

        $currentStatus = Game::where('id', $gameId)->value('status');

        if ($currentStatus === null || $currentStatus === $payload['status']) {
            return [];
        }

        $allowed = [
            'draft' => ['open'],
            'closed' => ['reward_recorded'],
            'reward_recorded' => ['reward_checking'],
            'reward_checking' => ['reward_verified'],
            'reward_verified' => ['reward_published'],
        ];

        if (! in_array((string) $payload['status'], $allowed[(string) $currentStatus] ?? [], true)) {
            return ['status' => ['The requested game status transition is not allowed.']];
        }

        return (string) $payload['status'] === 'open'
            ? $this->gameOpeningErrors($gameId, $payload)
            : [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function gameOpeningErrors(?string $gameId, array $payload): array
    {
        if (($payload['status'] ?? null) !== 'open') {
            return [];
        }

        $game = $gameId === null ? null : Game::whereKey($gameId)->first();
        $drawAt = $this->dateFromPayloadOrModel($payload, 'draw_at', $game);

        $openQuery = Game::query()->where('status', 'open');

        if ($gameId !== null) {
            $openQuery->where('id', '!=', $gameId);
        }

        $errors = [];

        if ($openQuery->exists()) {
            $errors['status'][] = 'Another game is already open for sale. Close it and record results before opening a new game.';
        }

        $previousQuery = Game::query()
            ->where('status', '!=', 'archived')
            ->orderByDesc('draw_at');

        if ($gameId !== null) {
            $previousQuery->where('id', '!=', $gameId);
        }

        if ($drawAt !== null) {
            $previousQuery->where('draw_at', '<', $drawAt);
        }

        $previousGame = $previousQuery->first();

        if (
            $previousGame !== null
            && (
                $previousGame->closed_at === null
                || ! RewardResult::where('game_id', $previousGame->id)->where('status', '!=', 'draft')->exists()
            )
        ) {
            $errors['status'][] = 'The previous game must be closed and have recorded reward results before opening a new game.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createGame(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $gameId = 'gam_'.Str::ulid()->toBase32();
            $now = now();

            Game::query()->insert([
                'id' => $gameId,
                'code' => $this->gameCodeFromDrawAt($payload['draw_at']),
                'name' => trim((string) $payload['name']),
                'sale_start_at' => $this->toTimestamp($payload['sale_start_at']),
                'draw_at' => $this->toTimestamp($payload['draw_at']),
                'close_at' => $this->toTimestamp($payload['close_at']),
                'closed_at' => null,
                'archived_at' => null,
                'status' => $payload['status'] ?? 'draft',
                'metadata_json' => json_encode($this->resourceMetadata($payload), JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->createDraftRewardForGame($gameId, $actor->adminUser['id'], $now);
            $this->auditGameChange($actor, $request, $gameId, 'created', $payload);

            return $this->findGame($gameId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateGame(string $gameId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($gameId, $payload, $actor, $request): ?array {
            $game = Game::query()->where('id', $gameId)->lockForUpdate()->first();

            if ($game === null) {
                return null;
            }

            $updates = ['updated_at' => now()];

            foreach (['code', 'name', 'status'] as $field) {
                if (array_key_exists($field, $payload)) {
                    $updates[$field] = is_string($payload[$field]) ? trim($payload[$field]) : $payload[$field];
                }
            }

            if (array_key_exists('draw_at', $payload)) {
                $updates['draw_at'] = $this->toTimestamp($payload['draw_at']);
            }

            if (array_key_exists('sale_start_at', $payload)) {
                $updates['sale_start_at'] = $this->toTimestamp($payload['sale_start_at']);
            }

            if (array_key_exists('close_at', $payload)) {
                $updates['close_at'] = $this->toTimestamp($payload['close_at']);
            }

            $metadata = array_merge($this->decodeJsonObject($game->metadata_json), $this->resourceMetadata($payload));
            $updates['metadata_json'] = json_encode($metadata, JSON_THROW_ON_ERROR);

            Game::query()->where('id', $gameId)->update($updates);

            $this->auditGameChange($actor, $request, $gameId, 'updated', $payload);

            return $this->findGame($gameId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function closeGame(string $gameId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($gameId, $payload, $actor, $request): ?array {
            $game = Game::query()->where('id', $gameId)->lockForUpdate()->first();

            if ($game === null || $game->status !== 'open') {
                return null;
            }

            $closedAt = now();

            Game::query()->where('id', $gameId)->update([
                'status' => 'closed',
                'closed_at' => $closedAt,
                'updated_at' => $closedAt,
            ]);

            $this->insertOutboxEvent(
                eventType: 'game.closed.v1',
                producer: 'central_stock',
                tenantId: null,
                partnerId: null,
                gameId: $gameId,
                aggregateType: 'game',
                aggregateId: $gameId,
                idempotencyKey: $request->header('Idempotency-Key'),
                correlationId: $request->header('X-Request-Id'),
                payload: [
                    'game_id' => $gameId,
                    'closed_at' => $closedAt->toISOString(),
                    'reason' => $payload['reason'] ?? 'manual_close',
                ],
            );

            $this->auditGameChange($actor, $request, $gameId, 'closed', $payload);

            return $this->findGame($gameId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function archiveGame(string $gameId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($gameId, $payload, $actor, $request): ?array {
            $game = Game::query()->where('id', $gameId)->lockForUpdate()->first();

            if ($game === null || ! $this->canArchiveStatus((string) $game->status)) {
                return null;
            }

            Game::query()->where('id', $gameId)->update([
                'status' => 'archived',
                'archived_at' => now(),
                'updated_at' => now(),
            ]);

            $this->auditGameChange($actor, $request, $gameId, 'archived', $payload);

            return $this->findGame($gameId);
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listStock(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $grouped = filter_var($queryParams['grouped'] ?? false, FILTER_VALIDATE_BOOLEAN);

        if ($grouped) {
            return $this->listStockGroups($queryParams, $limit);
        }

        $sort = $this->resolveStockSort($queryParams);
        $query = StockItem::query()->limit($limit + 1);
        $this->applyStockFilters($query, $queryParams);

        if ($sort === null) {
            $query->orderBy('id');
        } else {
            $this->applyStockOrder($query, $sort);
        }

        if ($sort === null && ($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        } elseif ($sort !== null) {
            $this->applyStockCursor($query, $queryParams['cursor'] ?? null, $sort);
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $stock): array => $this->stockResource($stock), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? ($sort === null ? (string) end($rows)->id : $this->stockCursor(end($rows), $sort)) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function stockSummary(array $queryParams): array
    {
        $gameId = $this->nullableQueryString($queryParams['game_id'] ?? null);
        $batchId = $this->nullableQueryString($queryParams['batch_id'] ?? null);
        $query = StockItem::query();

        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        }

        if ($batchId !== null) {
            $query->where('batch_id', $batchId);
        }

        $totalCount = (int) (clone $query)->count();

        return [
            'game_id' => $gameId,
            'batch_id' => $batchId,
            'total_count' => $totalCount,
            'status_counts' => $this->stockSummaryStatusCounts($query, $totalCount),
            'number_coverage' => [
                'back2' => $this->stockNumberCoverage($query, 'back2', 100),
                'back3' => $this->stockNumberCoverage($query, 'back3', 1000),
                'front3' => $this->stockNumberCoverage($query, 'front3', 1000),
            ],
            'empty' => $totalCount === 0,
        ];
    }

    /**
     * @param mixed $query
     * @return array<string, int>
     */
    private function stockSummaryStatusCounts(mixed $query, int $totalCount): array
    {
        $counts = array_fill_keys(self::STOCK_STATUSES, 0);
        $rows = (clone $query)
            ->select('status', DB::raw('COUNT(*) as total'))
            ->groupBy('status')
            ->pluck('total', 'status')
            ->all();

        foreach ($rows as $status => $count) {
            if (array_key_exists((string) $status, $counts)) {
                $counts[(string) $status] = (int) $count;
            }
        }

        $counts['total'] = $totalCount;

        return $counts;
    }

    /**
     * @param mixed $query
     * @return array<string, int>
     */
    private function stockNumberCoverage(mixed $query, string $column, int $expectedDistinct): array
    {
        $counts = (clone $query)
            ->whereNotNull($column)
            ->select($column, DB::raw('COUNT(*) as total'))
            ->groupBy($column)
            ->pluck('total', $column)
            ->map(fn (mixed $value): int => (int) $value)
            ->values()
            ->all();
        $distinctCount = count($counts);
        $missingDistinctCount = max(0, $expectedDistinct - $distinctCount);

        return [
            'expected_distinct' => $expectedDistinct,
            'distinct_count' => $distinctCount,
            'missing_distinct_count' => $missingDistinctCount,
            'min_count_per_number' => $counts === [] ? 0 : ($missingDistinctCount > 0 ? 0 : min($counts)),
            'max_count_per_number' => $counts === [] ? 0 : max($counts),
            'total_count' => array_sum($counts),
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function listStockGroups(array $queryParams, int $limit): array
    {
        $sort = $this->resolveStockGroupSort($queryParams);
        $query = StockItem::query()
            ->select([
                'game_id',
                'full_number',
                DB::raw('MIN(id) as sample_stock_item_id'),
                DB::raw('MIN(created_at) as first_created_at'),
                DB::raw('MAX(updated_at) as last_updated_at'),
                DB::raw('COUNT(*) as total_count'),
                DB::raw("SUM(CASE WHEN status = 'available' THEN 1 ELSE 0 END) as available_count"),
                DB::raw("SUM(CASE WHEN status = 'allocated' THEN 1 ELSE 0 END) as allocated_count"),
                DB::raw("SUM(CASE WHEN status = 'sold' THEN 1 ELSE 0 END) as sold_count"),
                DB::raw("SUM(CASE WHEN status = 'recalled' THEN 1 ELSE 0 END) as recalled_count"),
            ])
            ->groupBy('game_id', 'full_number')
            ->limit($limit + 1);

        $this->applyStockFilters($query, $queryParams);

        if ($sort === null) {
            $query->orderBy('game_id')->orderBy('full_number');
        } else {
            $this->applyStockGroupOrder($query, $sort);
        }

        $cursor = $this->decodeStockGroupCursor($queryParams['cursor'] ?? null);
        if ($cursor !== null && $sort === null) {
            $query->where(function ($nested) use ($cursor): void {
                $nested
                    ->where('game_id', '>', $cursor['game_id'])
                    ->orWhere(function ($sameGame) use ($cursor): void {
                        $sameGame
                            ->where('game_id', $cursor['game_id'])
                            ->where('full_number', '>', $cursor['full_number']);
                    });
            });
        } elseif ($sort !== null) {
            $this->applyStockGroupCursor($query, $cursor, $sort);
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->stockGroupResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? $this->stockGroupCursor(end($rows), $sort) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{key: string, column: string, direction: string}|null
     */
    private function resolveStockSort(array $queryParams): ?array
    {
        $key = trim((string) ($queryParams['sort_by'] ?? ''));
        if ($key === '') {
            return null;
        }

        $allowed = [
            'id' => 'id',
            'game_id' => 'game_id',
            'full_number' => 'full_number',
            'front3' => 'front3',
            'back3' => 'back3',
            'back2' => 'back2',
            'status' => 'status',
            'partner_id' => 'partner_id',
            'tenant_id' => 'tenant_id',
            'allocation_id' => 'allocation_id',
            'batch_id' => 'batch_id',
            'created_at' => 'created_at',
            'updated_at' => 'updated_at',
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

    /**
     * @return array{key: string, order: string, expression: string, direction: string}|null
     */
    private function resolveStockGroupSort(array $queryParams): ?array
    {
        $key = trim((string) ($queryParams['sort_by'] ?? ''));
        if ($key === '') {
            return null;
        }

        $allowed = [
            'game_id' => ['order' => 'game_id', 'expression' => 'game_id'],
            'full_number' => ['order' => 'full_number', 'expression' => 'full_number'],
            'total_count' => ['order' => 'total_count', 'expression' => 'COUNT(*)'],
            'available_count' => ['order' => 'available_count', 'expression' => "SUM(CASE WHEN status = 'available' THEN 1 ELSE 0 END)"],
            'allocated_count' => ['order' => 'allocated_count', 'expression' => "SUM(CASE WHEN status = 'allocated' THEN 1 ELSE 0 END)"],
            'sold_count' => ['order' => 'sold_count', 'expression' => "SUM(CASE WHEN status = 'sold' THEN 1 ELSE 0 END)"],
            'recalled_count' => ['order' => 'recalled_count', 'expression' => "SUM(CASE WHEN status = 'recalled' THEN 1 ELSE 0 END)"],
            'first_created_at' => ['order' => 'first_created_at', 'expression' => 'MIN(created_at)'],
            'last_updated_at' => ['order' => 'last_updated_at', 'expression' => 'MAX(updated_at)'],
        ];

        if (! isset($allowed[$key])) {
            return null;
        }

        return [
            'key' => $key,
            'order' => $allowed[$key]['order'],
            'expression' => $allowed[$key]['expression'],
            'direction' => strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc',
        ];
    }

    private function applyStockOrder(mixed $query, array $sort): void
    {
        $query->orderBy($sort['column'], $sort['direction']);

        if ($sort['column'] !== 'id') {
            $query->orderBy('id');
        }
    }

    private function applyStockCursor(mixed $query, mixed $rawCursor, array $sort): void
    {
        $cursor = $this->decodeStockCursor($rawCursor, $sort);
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

    private function stockCursor(object $stock, array $sort): string
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
    private function decodeStockCursor(mixed $cursor, array $sort): ?array
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

    private function applyStockGroupOrder(mixed $query, array $sort): void
    {
        $query->orderBy($sort['order'], $sort['direction']);

        foreach (['game_id', 'full_number'] as $column) {
            if ($sort['key'] !== $column) {
                $query->orderBy($column);
            }
        }
    }

    private function applyStockGroupCursor(mixed $query, ?array $cursor, array $sort): void
    {
        if ($cursor === null
            || ($cursor['sort_by'] ?? null) !== $sort['key']
            || ($cursor['sort_dir'] ?? null) !== $sort['direction']
            || ! array_key_exists('value', $cursor)) {
            return;
        }

        $operator = $sort['direction'] === 'desc' ? '<' : '>';
        $tieColumns = array_values(array_filter(['game_id', 'full_number'], fn (string $column): bool => $column !== $sort['key']));
        $bindings = [$cursor['value'], $cursor['value']];

        if ($tieColumns === ['game_id', 'full_number']) {
            $tieSql = '(game_id > ? OR (game_id = ? AND full_number > ?))';
            array_push($bindings, $cursor['game_id'], $cursor['game_id'], $cursor['full_number']);
        } else {
            $tieSql = $tieColumns[0].' > ?';
            $bindings[] = $cursor[$tieColumns[0]];
        }

        $query->havingRaw($sort['expression'].' '.$operator.' ? OR ('.$sort['expression'].' = ? AND '.$tieSql.')', $bindings);
    }

    /**
     * @param mixed $query
     * @param array<string, mixed> $queryParams
     */
    private function applyStockFilters(mixed $query, array $queryParams): void
    {
        foreach (['game_id', 'status', 'partner_id', 'tenant_id', 'allocation_id'] as $filter) {
            if (($queryParams[$filter] ?? null) !== null && trim((string) $queryParams[$filter]) !== '') {
                $query->where($filter, trim((string) $queryParams[$filter]));
            }
        }

        $number = trim((string) ($queryParams['number'] ?? $queryParams['full_number'] ?? ''));
        if ($number !== '') {
            $query->where('full_number', 'like', '%'.$number.'%');
        }

        foreach (['front3', 'back3', 'back2'] as $filter) {
            if (($queryParams[$filter] ?? null) !== null && trim((string) $queryParams[$filter]) !== '') {
                $query->where($filter, trim((string) $queryParams[$filter]));
            }
        }
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findStock(string $stockItemId): ?array
    {
        return $this->stockResourceById($stockItemId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateGeneratePayload(array $payload): array
    {
        $errors = $this->validateOpenGamePayload($payload);
        $legacyFields = [
            'start_number',
            'from_number',
            'range_start',
            'end_number',
            'to_number',
            'range_end',
            'count',
            'requested_count',
            'number_digits',
            'digits',
        ];

        foreach ($legacyFields as $field) {
            if (array_key_exists($field, $payload) && $payload[$field] !== null && $payload[$field] !== '') {
                $errors[$field][] = 'This field is no longer supported for stock generation. Use quota-based generation fields instead.';
            }
        }

        $hasTotalCount = $this->hasPayloadValue($payload, 'total_count');
        $hasAnyQuotaCount = $this->hasPayloadValue($payload, 'back2_count_per_number')
            || $this->hasPayloadValue($payload, 'back3_count_per_number')
            || $this->hasPayloadValue($payload, 'front3_count_per_number');
        $totalCount = $this->quotaCountFromPayload($payload, 'total_count', $errors, false);
        $back2Count = null;
        $back3Count = null;
        $front3Count = null;

        if (! $hasTotalCount || $hasAnyQuotaCount) {
            $back2Count = $this->quotaCountFromPayload($payload, 'back2_count_per_number', $errors);
            $back3Count = $this->quotaCountFromPayload($payload, 'back3_count_per_number', $errors);
            $front3Count = $this->quotaCountFromPayload($payload, 'front3_count_per_number', $errors);
        }

        if ($hasTotalCount && $totalCount !== null) {
            if ($totalCount < self::GENERATE_BASE_COUNT) {
                $errors['total_count'][] = 'The total_count field must be at least 1000.';
            }

            if ($totalCount > self::GENERATE_MAX_SYNC_COUNT) {
                $errors['total_count'][] = 'The total_count field may not be greater than 10000 for synchronous generation.';
            }

            if (($totalCount % self::GENERATE_BASE_COUNT) !== 0) {
                $errors['total_count'][] = 'The total_count field must be divisible by 1000.';
            }
        }

        if ($back3Count !== null && ($back3Count * self::GENERATE_BASE_COUNT) > self::GENERATE_MAX_SYNC_COUNT) {
            $errors['back3_count_per_number'][] = 'The back3_count_per_number field may not create more than 10000 stock items for synchronous generation.';
        }

        if ($back2Count !== null && $back3Count !== null && $back2Count !== ($back3Count * 10)) {
            $errors['back2_count_per_number'][] = 'The back2_count_per_number field must equal 10 times back3_count_per_number.';
        }

        if ($front3Count !== null && $back3Count !== null && $front3Count !== $back3Count) {
            $errors['front3_count_per_number'][] = 'The front3_count_per_number field must equal back3_count_per_number.';
        }

        if ($hasTotalCount && $hasAnyQuotaCount && $totalCount !== null && $back3Count !== null && $totalCount !== ($back3Count * self::GENERATE_BASE_COUNT)) {
            $errors['total_count'][] = 'The total_count field must equal 1000 times back3_count_per_number.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function generateStock(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $normalized = $this->normalizedGeneratePayload($payload, (string) $request->header('Idempotency-Key'));
            $batch = $this->ensureStockBatch('generate', $normalized, $actor, $request);

            if (! $batch['created']) {
                return $this->batchResourceById($batch['id']);
            }

            $now = now();

            $rows = [];
            $stockIds = [];

            foreach ($normalized['numbers'] as $index => $number) {
                $stockIds[$index] = $this->stableId('stk', $batch['id'].':'.$index.':'.$number);
            }

            $imageAssignments = $this->lotteryImages->assignmentsForStockIds(
                $normalized['game_id'],
                $batch['id'],
                array_values($stockIds),
                (string) $request->header('Idempotency-Key'),
            );

            foreach ($normalized['numbers'] as $index => $number) {
                $stockId = $stockIds[$index];
                $rows[] = array_merge(
                    $this->stockInsertPayload((string) $number, $normalized['game_id'], $batch['id'], $now, $imageAssignments[$stockId] ?? null),
                    ['id' => $stockId],
                );
            }

            if ($rows !== []) {
                StockItem::query()->insert($rows);
                $this->dispatchCentralImageJobs(array_values($stockIds));
            }

            $generatedCount = StockItem::where('batch_id', $batch['id'])->count();

            StockGenerationBatch::query()->where('id', $batch['id'])->update([
                'status' => 'completed',
                'generated_count' => $generatedCount,
                'completed_at' => now(),
                'updated_at' => now(),
            ]);

            $this->auditStockChange($actor, $request, $batch['id'], 'stock.generated', $payload);

            return $this->batchResourceById($batch['id']);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateImportPayload(array $payload): array
    {
        $errors = $this->validateOpenGamePayload($payload);
        $numbers = $this->numbersFromImportPayload($payload);

        if ($numbers === []) {
            $errors['items'][] = 'The items field must include at least one stock number.';
        }

        foreach ($numbers as $number) {
            if (! preg_match('/^[0-9]{1,32}$/', $number)) {
                $errors['items'][] = 'Each imported stock number must contain digits only.';
                break;
            }
        }

        if (count($numbers) > 10000) {
            $errors['items'][] = 'A synchronous import may not include more than 10000 numbers.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function importStock(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $numbers = $this->numbersFromImportPayload($payload);
            $gameId = trim((string) $payload['game_id']);
            $digits = max(1, min(12, $this->integerFrom($payload['number_digits'] ?? $payload['digits'] ?? 6)));
            $normalized = [
                'game_id' => $gameId,
                'numbers' => array_map(fn (string $number): string => $this->normalizeFullNumber($number, $digits), $numbers),
                'requested_count' => count($numbers),
                'range_start' => $numbers[0] ?? null,
                'range_end' => $numbers === [] ? null : $numbers[count($numbers) - 1],
                'number_digits' => $digits,
            ];
            $batch = $this->ensureStockBatch('import', $normalized, $actor, $request);

            if (! $batch['created']) {
                return $this->batchResourceById($batch['id']);
            }

            $now = now();
            $rows = [];
            $stockIds = [];

            foreach ($normalized['numbers'] as $index => $number) {
                $stockIds[$index] = $this->stableId('stk', $batch['id'].':'.$index.':'.$number);
            }

            $imageAssignments = $this->lotteryImages->assignmentsForStockIds(
                $gameId,
                $batch['id'],
                array_values($stockIds),
                (string) $request->header('Idempotency-Key'),
            );

            foreach ($normalized['numbers'] as $index => $number) {
                $stockId = $stockIds[$index];
                $rows[] = array_merge(
                    $this->stockInsertPayload((string) $number, $gameId, $batch['id'], $now, $imageAssignments[$stockId] ?? null),
                    ['id' => $stockId],
                );
            }

            if ($rows !== []) {
                StockItem::query()->insert($rows);
                $this->dispatchCentralImageJobs(array_values($stockIds));
            }

            $generatedCount = StockItem::where('batch_id', $batch['id'])->count();

            StockGenerationBatch::query()->where('id', $batch['id'])->update([
                'status' => 'completed',
                'generated_count' => $generatedCount,
                'completed_at' => now(),
                'updated_at' => now(),
            ]);

            $this->auditStockChange($actor, $request, $batch['id'], 'stock.imported', $payload);

            return $this->batchResourceById($batch['id']);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateExportPayload(array $payload): array
    {
        $errors = [];
        $gameId = trim((string) ($payload['game_id'] ?? ''));

        if ($gameId === '' || ! Game::where('id', $gameId)->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createStockExport(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $gameId = trim((string) $payload['game_id']);
            $hash = $this->payloadHash([
                'game_id' => $gameId,
                'filters' => $payload['filters'] ?? [],
                'idempotency_key' => $request->header('Idempotency-Key'),
                'actor_id' => $actor->adminUser['id'],
            ]);
            $batchId = $this->stableId('stb', 'export:'.$hash);
            $now = now();

            if (! StockGenerationBatch::where('id', $batchId)->exists()) {
                StockGenerationBatch::query()->insert([
                    'id' => $batchId,
                    'game_id' => $gameId,
                    'type' => 'export',
                    'status' => 'pending',
                    'requested_count' => 0,
                    'generated_count' => StockItem::where('game_id', $gameId)->count(),
                    'range_start' => null,
                    'range_end' => null,
                    'number_digits' => 6,
                    'idempotency_key' => $request->header('Idempotency-Key'),
                    'payload_hash' => $hash,
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
                    'completed_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            $this->auditStockChange($actor, $request, $batchId, 'stock.export_requested', $payload);

            return $this->batchResourceById($batchId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function recallStock(string $stockItemId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($stockItemId, $payload, $actor, $request): ?array {
            $stock = StockItem::query()->where('id', $stockItemId)->lockForUpdate()->first();

            if ($stock === null || ! in_array($stock->status, ['available', 'allocated'], true)) {
                return null;
            }

            $now = now();
            $reason = trim((string) ($payload['reason'] ?? 'manual_recall'));

            StockItem::query()->where('id', $stockItemId)->update([
                'status' => 'recalled',
                'recall_reason' => $reason,
                'recalled_at' => $now,
                'updated_at' => $now,
            ]);

            if ($stock->status === 'allocated' && $stock->allocation_id !== null) {
                $this->markAllocationItemRecalled((string) $stock->allocation_id, $stockItemId, $reason, $request);
            }

            $this->auditStockChange($actor, $request, $stockItemId, 'stock.recalled', $payload, $stock->partner_id, $stock->tenant_id);

            return $this->stockResourceById($stockItemId);
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listQuotas(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerQuota::query()->orderBy('id')->limit($limit + 1);

        foreach (['partner_id', 'game_id', 'status'] as $filter) {
            if (($queryParams[$filter] ?? null) !== null && trim((string) $queryParams[$filter]) !== '') {
                $query->where($filter, trim((string) $queryParams[$filter]));
            }
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $quota): array => $this->quotaResource($quota), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findQuota(string $quotaId): ?array
    {
        return $this->quotaResourceById($quotaId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateQuotaPayload(array $payload, bool $creating, ?string $quotaId = null): array
    {
        $errors = [];

        if ($creating || array_key_exists('partner_id', $payload)) {
            $partnerId = trim((string) ($payload['partner_id'] ?? ''));

            if ($partnerId === '' || ! Partner::where('id', $partnerId)->where('status', 'active')->exists()) {
                $errors['partner_id'][] = 'The partner_id field must reference an active partner.';
            }
        }

        if ($creating || array_key_exists('game_id', $payload)) {
            $gameId = trim((string) ($payload['game_id'] ?? ''));

            if ($gameId === '' || ! Game::whereKey($gameId)->whereIn('status', ['draft', 'open'])->exists()) {
                $errors['game_id'][] = 'The game_id field must reference an active game.';
            }
        }

        if ($creating || array_key_exists('quota_count', $payload)) {
            $quotaCount = $this->integerFrom($payload['quota_count'] ?? null);

            if ($quotaCount < 1) {
                $errors['quota_count'][] = 'The quota_count field must be at least 1.';
            }

            if ($quotaId !== null) {
                $allocatedCount = (int) PartnerQuota::where('id', $quotaId)->value('allocated_count');

                if ($quotaCount < $allocatedCount) {
                    $errors['quota_count'][] = 'The quota_count field cannot be below the allocated count.';
                }
            }
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::QUOTA_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        foreach (['sale_start_at' => 'sale_start_at', 'sale_close_at' => 'sale_close_at'] as $field => $label) {
            if (array_key_exists($field, $payload) && $payload[$field] !== null && trim((string) $payload[$field]) !== '' && ! $this->canParseDate($payload[$field])) {
                $errors[$field][] = 'The '.$label.' field must be a valid date-time.';
            }
        }

        if (! isset($errors['game_id']) && ! isset($errors['sale_start_at']) && ! isset($errors['sale_close_at'])) {
            $errors = $this->mergeFieldErrors($errors, $this->quotaSaleWindowErrors($payload, $quotaId));
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function quotaConflictErrors(array $payload, ?string $ignoreQuotaId = null): array
    {
        if (! array_key_exists('partner_id', $payload) || ! array_key_exists('game_id', $payload)) {
            return [];
        }

        $query = PartnerQuota::query()
            ->where('partner_id', trim((string) $payload['partner_id']))
            ->where('game_id', trim((string) $payload['game_id']));

        if ($ignoreQuotaId !== null) {
            $query->where('id', '!=', $ignoreQuotaId);
        }

        return $query->exists() ? ['partner_id' => ['A quota already exists for this partner and game.']] : [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function createQuota(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $quotaId = $this->stableId('pqt', trim((string) $payload['partner_id']).':'.trim((string) $payload['game_id']));
            $now = now();

            PartnerQuota::query()->insert([
                'id' => $quotaId,
                'partner_id' => trim((string) $payload['partner_id']),
                'game_id' => trim((string) $payload['game_id']),
                'quota_count' => $this->integerFrom($payload['quota_count']),
                'allocated_count' => 0,
                'sale_start_at' => $this->nullableTimestamp($payload['sale_start_at'] ?? null),
                'sale_close_at' => $this->nullableTimestamp($payload['sale_close_at'] ?? null),
                'status' => $payload['status'] ?? 'active',
                'created_by_admin_id' => $actor->adminUser['id'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $this->auditQuotaChange($actor, $request, $quotaId, 'created', $payload);

            return $this->quotaResourceById($quotaId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updateQuota(string $quotaId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($quotaId, $payload, $actor, $request): ?array {
            $quota = PartnerQuota::query()->where('id', $quotaId)->lockForUpdate()->first();

            if ($quota === null) {
                return null;
            }

            $updates = ['updated_at' => now()];

            foreach (['partner_id', 'game_id', 'status'] as $field) {
                if (array_key_exists($field, $payload)) {
                    $updates[$field] = is_string($payload[$field]) ? trim($payload[$field]) : $payload[$field];
                }
            }

            if (array_key_exists('quota_count', $payload)) {
                $updates['quota_count'] = $this->integerFrom($payload['quota_count']);
            }

            if (array_key_exists('sale_start_at', $payload)) {
                $updates['sale_start_at'] = $this->nullableTimestamp($payload['sale_start_at']);
            }

            if (array_key_exists('sale_close_at', $payload)) {
                $updates['sale_close_at'] = $this->nullableTimestamp($payload['sale_close_at']);
            }

            PartnerQuota::query()->where('id', $quotaId)->update($updates);

            $this->auditQuotaChange($actor, $request, $quotaId, 'updated', $payload);

            return $this->quotaResourceById($quotaId);
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listAllocations(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $query = PartnerStockAllocation::query()->orderBy('id')->limit($limit + 1);

        foreach (['partner_id', 'tenant_id', 'game_id', 'status'] as $filter) {
            if (($queryParams[$filter] ?? null) !== null && trim((string) $queryParams[$filter]) !== '') {
                $query->where($filter, trim((string) $queryParams[$filter]));
            }
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $allocation): array => $this->allocationResource($allocation), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findAllocation(string $allocationId): ?array
    {
        $allocation = PartnerStockAllocation::where('id', $allocationId)->first();

        return $allocation === null ? null : $this->allocationResource($allocation);
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findAllocationReplay(AdminSessionContext $actor, Request $request): ?array
    {
        $idempotencyKey = $request->header('Idempotency-Key');

        if ($idempotencyKey === null || $idempotencyKey === '') {
            return null;
        }

        $existing = PartnerStockAllocation::query()
            ->where('created_by_admin_id', $actor->adminUser['id'])
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        return $existing === null ? null : $this->allocationResource($existing);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateAllocationPayload(array $payload): array
    {
        $errors = [];
        $partnerId = trim((string) ($payload['partner_id'] ?? ''));
        $tenantId = trim((string) ($payload['tenant_id'] ?? ''));
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $requestedCount = $this->integerFrom($payload['requested_count'] ?? null);

        if ($partnerId === '' || $tenantId === '' || ! $this->activeTenantForPartnerExists($partnerId, $tenantId)) {
            $errors['tenant_id'][] = 'The tenant_id field must reference an active tenant for an active partner.';
        }

        if ($gameId === '' || ! Game::where('id', $gameId)->where('status', 'open')->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an open game.';
        }

        if ($requestedCount < 1) {
            $errors['requested_count'][] = 'The requested_count field must be at least 1.';
        }

        if ($requestedCount > 10000) {
            $errors['requested_count'][] = 'The requested_count field may not be greater than 10000.';
        }

        if ($partnerId !== '' && $gameId !== '' && $requestedCount > 0) {
            $quota = PartnerQuota::where('partner_id', $partnerId)
                ->where('game_id', $gameId)
                ->where('status', 'active')
                ->first();

            if ($quota === null) {
                $errors['quota'][] = 'An active partner quota is required for this game.';
            } elseif (((int) $quota->quota_count - (int) $quota->allocated_count) < $requestedCount) {
                $errors['requested_count'][] = 'The requested_count exceeds the active partner quota.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function createAllocation(array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        $replay = $this->findAllocationReplay($actor, $request);

        if ($replay !== null) {
            return $replay;
        }

        return DB::transaction(function () use ($payload, $actor, $request): ?array {
            $partnerId = trim((string) $payload['partner_id']);
            $tenantId = trim((string) $payload['tenant_id']);
            $gameId = trim((string) $payload['game_id']);
            $requestedCount = $this->integerFrom($payload['requested_count']);
            $now = now();

            if (! Game::query()->where('id', $gameId)->where('status', 'open')->lockForUpdate()->exists()) {
                return null;
            }

            if (! $this->activeTenantForPartnerExists($partnerId, $tenantId)) {
                return null;
            }

            $quota = PartnerQuota::query()
                ->where('partner_id', $partnerId)
                ->where('game_id', $gameId)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();

            if ($quota === null || ((int) $quota->quota_count - (int) $quota->allocated_count) < $requestedCount) {
                return null;
            }

            $stockRows = StockItem::query()
                ->where('game_id', $gameId)
                ->where('status', 'available')
                ->orderBy('id')
                ->limit($requestedCount)
                ->lockForUpdate()
                ->get()
                ->all();

            if (count($stockRows) < $requestedCount) {
                return null;
            }

            $allocationId = 'alc_'.Str::ulid()->toBase32();
            $stockIds = array_map(fn (object $stock): string => (string) $stock->id, $stockRows);

            PartnerStockAllocation::query()->insert([
                'id' => $allocationId,
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'quota_id' => $quota->id,
                'status' => 'pending',
                'requested_count' => $requestedCount,
                'allocated_count' => count($stockRows),
                'idempotency_key' => $request->header('Idempotency-Key'),
                'created_by_admin_id' => $actor->adminUser['id'],
                'reason' => $payload['reason'] ?? null,
                'cancelled_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            StockItem::query()->whereIn('id', $stockIds)->update([
                'status' => 'allocated',
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'allocation_id' => $allocationId,
                'updated_at' => $now,
            ]);

            PartnerStockAllocationItem::query()->insert(array_map(fn (string $stockId): array => [
                'allocation_id' => $allocationId,
                'stock_item_id' => $stockId,
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'allocated',
                'created_at' => $now,
                'updated_at' => $now,
            ], $stockIds));

            PartnerQuota::query()->where('id', $quota->id)->update([
                'allocated_count' => (int) $quota->allocated_count + count($stockRows),
                'updated_at' => $now,
            ]);

            $this->insertOutboxEvent(
                eventType: 'stock.allocated.v1',
                producer: 'central_stock',
                tenantId: $tenantId,
                partnerId: $partnerId,
                gameId: $gameId,
                aggregateType: 'partner_stock_allocation',
                aggregateId: $allocationId,
                idempotencyKey: $request->header('Idempotency-Key'),
                correlationId: $request->header('X-Request-Id'),
                payload: [
                    'allocation_id' => $allocationId,
                    'partner_id' => $partnerId,
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'cursor' => $allocationId,
                    'item_count' => count($stockRows),
                    'chunk_size' => 5000,
                ],
            );

            $this->auditAllocationChange($actor, $request, $allocationId, 'stock.allocated', $payload, $partnerId, $tenantId);

            return $this->findAllocation($allocationId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function cancelAllocation(string $allocationId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($allocationId, $payload, $actor, $request): ?array {
            $allocation = PartnerStockAllocation::query()->where('id', $allocationId)->lockForUpdate()->first();

            if ($allocation === null || ! in_array($allocation->status, self::CANCELLABLE_ALLOCATION_STATUSES, true)) {
                return null;
            }

            $now = now();
            $stockIds = PartnerStockAllocationItem::query()
                ->where('allocation_id', $allocationId)
                ->where('status', 'allocated')
                ->pluck('stock_item_id')
                ->all();

            if ($stockIds !== []) {
                StockItem::query()
                    ->whereIn('id', $stockIds)
                    ->where('allocation_id', $allocationId)
                    ->where('status', 'allocated')
                    ->update([
                        'status' => 'available',
                        'partner_id' => null,
                        'tenant_id' => null,
                        'allocation_id' => null,
                        'updated_at' => $now,
                    ]);

                PartnerStockAllocationItem::query()
                    ->where('allocation_id', $allocationId)
                    ->whereIn('stock_item_id', $stockIds)
                    ->update([
                        'status' => 'released',
                        'updated_at' => $now,
                    ]);
            }

            $releasedCount = count($stockIds);

            if ($allocation->quota_id !== null && $releasedCount > 0) {
                $quota = PartnerQuota::query()->where('id', $allocation->quota_id)->lockForUpdate()->first();

                if ($quota !== null) {
                    PartnerQuota::query()->where('id', $quota->id)->update([
                        'allocated_count' => max(0, (int) $quota->allocated_count - $releasedCount),
                        'updated_at' => $now,
                    ]);
                }
            }

            PartnerStockAllocation::query()->where('id', $allocationId)->update([
                'status' => 'cancelled',
                'allocated_count' => 0,
                'reason' => $payload['reason'] ?? $allocation->reason,
                'cancelled_at' => $now,
                'updated_at' => $now,
            ]);

            $this->auditAllocationChange(
                $actor,
                $request,
                $allocationId,
                'stock.allocation_cancelled',
                $payload,
                (string) $allocation->partner_id,
                (string) $allocation->tenant_id,
            );

            return $this->findAllocation($allocationId);
        });
    }

    private function markAllocationItemRecalled(string $allocationId, string $stockItemId, string $reason, Request $request): void
    {
        $allocation = PartnerStockAllocation::query()->where('id', $allocationId)->lockForUpdate()->first();

        if ($allocation === null) {
            return;
        }

        $now = now();

        PartnerStockAllocationItem::query()
            ->where('allocation_id', $allocationId)
            ->where('stock_item_id', $stockItemId)
            ->update([
                'status' => 'recalled',
                'updated_at' => $now,
            ]);

        $remainingAllocated = PartnerStockAllocationItem::where('allocation_id', $allocationId)
            ->where('status', 'allocated')
            ->count();

        PartnerStockAllocation::query()->where('id', $allocationId)->update([
            'status' => $remainingAllocated === 0 ? 'recalled' : 'partially_allocated',
            'allocated_count' => $remainingAllocated,
            'updated_at' => $now,
        ]);

        if ($allocation->quota_id !== null) {
            $quota = PartnerQuota::query()->where('id', $allocation->quota_id)->lockForUpdate()->first();

            if ($quota !== null) {
                PartnerQuota::query()->where('id', $quota->id)->update([
                    'allocated_count' => max(0, (int) $quota->allocated_count - 1),
                    'updated_at' => $now,
                ]);
            }
        }

        $recallId = 'rec_'.Str::ulid()->toBase32();

        $this->insertOutboxEvent(
            eventType: 'stock.recalled.v1',
            producer: 'central_stock',
            tenantId: (string) $allocation->tenant_id,
            partnerId: (string) $allocation->partner_id,
            gameId: (string) $allocation->game_id,
            aggregateType: 'stock_item',
            aggregateId: $stockItemId,
            idempotencyKey: $request->header('Idempotency-Key'),
            correlationId: $request->header('X-Request-Id'),
            payload: [
                'recall_id' => $recallId,
                'allocation_id' => $allocationId,
                'partner_id' => (string) $allocation->partner_id,
                'tenant_id' => (string) $allocation->tenant_id,
                'game_id' => (string) $allocation->game_id,
                'reason' => $reason,
            ],
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function validateOpenGamePayload(array $payload): array
    {
        $gameId = trim((string) ($payload['game_id'] ?? ''));

        if ($gameId === '' || ! Game::where('id', $gameId)->where('status', 'open')->exists()) {
            return ['game_id' => ['The game_id field must reference an open game.']];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{game_id: string, requested_count: int, range_start: string, range_end: string, number_digits: int, generation_mode: string, generation_input_mode: string, total_count: int, back2_count_per_number: int, back3_count_per_number: int, front3_count_per_number: int, numbers: array<int, string>}
     */
    private function normalizedGeneratePayload(array $payload, string $idempotencyKey): array
    {
        $gameId = trim((string) $payload['game_id']);
        $quota = $this->normalizedGenerateQuotaCounts($payload);
        $back2Count = $quota['back2_count_per_number'];
        $back3Count = $quota['back3_count_per_number'];
        $front3Count = $quota['front3_count_per_number'];
        $numbers = $this->quotaGeneratedNumbers($gameId, $idempotencyKey, $back3Count);

        return [
            'game_id' => $gameId,
            'requested_count' => count($numbers),
            'range_start' => '000000',
            'range_end' => '999999',
            'number_digits' => self::GENERATE_NUMBER_DIGITS,
            'generation_mode' => 'quota_random',
            'generation_input_mode' => $quota['input_mode'],
            'total_count' => $quota['total_count'],
            'back2_count_per_number' => $back2Count,
            'back3_count_per_number' => $back3Count,
            'front3_count_per_number' => $front3Count,
            'numbers' => $numbers,
        ];
    }

    /**
     * @param array<string, mixed> $normalized
     * @return array{id: string, created: bool}
     */
    private function ensureStockBatch(string $type, array $normalized, AdminSessionContext $actor, Request $request): array
    {
        $payloadHash = $this->payloadHash($normalized);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $batchId = $this->stableId('stb', $type.':'.$idempotencyKey.':'.$payloadHash);
        $now = now();

        if (! StockGenerationBatch::where('id', $batchId)->exists()) {
            StockGenerationBatch::query()->insert([
                'id' => $batchId,
                'game_id' => $normalized['game_id'],
                'type' => $type,
                'status' => 'processing',
                'requested_count' => $normalized['requested_count'],
                'generated_count' => 0,
                'range_start' => $normalized['range_start'],
                'range_end' => $normalized['range_end'],
                'number_digits' => $normalized['number_digits'],
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload_hash' => $payloadHash,
                'created_by_admin_id' => $actor->adminUser['id'],
                'payload_json' => json_encode($normalized, JSON_THROW_ON_ERROR),
                'completed_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            return ['id' => $batchId, 'created' => true];
        }

        return ['id' => $batchId, 'created' => false];
    }

    /**
     * @return array<int, string>
     */
    private function numbersFromImportPayload(array $payload): array
    {
        $items = $payload['items'] ?? $payload['numbers'] ?? $payload['full_numbers'] ?? [];

        if (! is_array($items)) {
            return [];
        }

        $numbers = [];

        foreach ($items as $item) {
            if (is_array($item)) {
                $value = $item['full_number'] ?? $item['number'] ?? null;
            } else {
                $value = $item;
            }

            if ($value === null) {
                continue;
            }

            $number = trim((string) $value);

            if ($number !== '') {
                $numbers[] = $number;
            }
        }

        return $numbers;
    }

    /**
     * @return array<string, mixed>
     */
    private function stockInsertPayload(string $number, string $gameId, string $batchId, mixed $now, ?array $imageAssignment = null): array
    {
        return array_merge([
            'game_id' => $gameId,
            'batch_id' => $batchId,
            'full_number' => $number,
            'front3' => strlen($number) >= 3 ? substr($number, 0, 3) : null,
            'back3' => strlen($number) >= 3 ? substr($number, -3) : null,
            'back2' => strlen($number) >= 2 ? substr($number, -2) : null,
            'status' => 'available',
            'partner_id' => null,
            'tenant_id' => null,
            'allocation_id' => null,
            'recall_reason' => null,
            'recalled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ], $imageAssignment ?? []);
    }

    /**
     * @param array<int, string> $stockIds
     */
    private function dispatchCentralImageJobs(array $stockIds): void
    {
        foreach ($stockIds as $stockId) {
            GenerateLotteryImageJob::dispatch((string) $stockId)->afterCommit();
        }
    }

    private function activeTenantForPartnerExists(string $partnerId, string $tenantId): bool
    {
        return PartnerTenant::query()
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->where('partner_tenants.id', $tenantId)
            ->where('partner_tenants.partner_id', $partnerId)
            ->where('partner_tenants.status', 'active')
            ->where('partners.status', 'active')
            ->exists();
    }

    private function canArchiveStatus(string $status): bool
    {
        return in_array($status, ['closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published'], true);
    }

    private function createDraftRewardForGame(string $gameId, mixed $createdByAdminId, Carbon $now): void
    {
        if (RewardResult::query()->where('game_id', $gameId)->exists()) {
            return;
        }

        $rewardResultId = 'rew_'.Str::ulid()->toBase32();

        RewardResult::query()->insert([
            'id' => $rewardResultId,
            'game_id' => $gameId,
            'status' => 'draft',
            'version' => 1,
            'summary_json' => null,
            'created_by_admin_id' => $createdByAdminId === null ? null : (string) $createdByAdminId,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $rows = [];

        foreach (ThaiGovernmentLotteryRewardTemplate::draftPrizes() as $index => $prize) {
            $rows[] = [
                'id' => 'rpr_'.Str::ulid()->toBase32(),
                'reward_result_id' => $rewardResultId,
                'game_id' => $gameId,
                'prize_type' => $prize['prize_type'],
                'prize_number' => $prize['prize_number'],
                'amount' => $prize['amount']['amount'],
                'currency' => $prize['amount']['currency'],
                'sort_order' => $index,
                'created_at' => $now,
                'updated_at' => $now,
            ];
        }

        RewardPrize::query()->insert($rows);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function quotaSaleWindowErrors(array $payload, ?string $quotaId): array
    {
        $quota = $quotaId === null ? null : PartnerQuota::whereKey($quotaId)->first();
        $gameId = trim((string) ($payload['game_id'] ?? $quota?->game_id ?? ''));

        if ($gameId === '') {
            return [];
        }

        $game = Game::whereKey($gameId)->first();

        if ($game === null) {
            return [];
        }

        $centralStartAt = $this->dateFromModelValue($game->sale_start_at);
        $centralCloseAt = $this->dateFromModelValue($game->close_at);

        if ($centralStartAt === null || $centralCloseAt === null) {
            return ['game_id' => ['The game must define sale_start_at and close_at before partner sale windows can be configured.']];
        }

        $partnerStartAt = $this->dateFromPayloadOrModel($payload, 'sale_start_at', $quota);
        $partnerCloseAt = $this->dateFromPayloadOrModel($payload, 'sale_close_at', $quota);
        $effectiveStartAt = $partnerStartAt ?? $centralStartAt;
        $effectiveCloseAt = $partnerCloseAt ?? $centralCloseAt;
        $errors = [];

        if ($partnerStartAt !== null && $partnerStartAt->lessThan($centralStartAt)) {
            $errors['sale_start_at'][] = 'Partner sale_start_at cannot be before the central sale_start_at.';
        }

        if ($partnerCloseAt !== null && $partnerCloseAt->greaterThan($centralCloseAt)) {
            $errors['sale_close_at'][] = 'Partner sale_close_at cannot be after the central close_at.';
        }

        if (! $effectiveCloseAt->greaterThan($effectiveStartAt)) {
            $errors['sale_close_at'][] = 'Partner sale_close_at must be after the effective sale_start_at.';
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function partnerQuotaWindowErrorsForGame(string $gameId, ?Carbon $saleStartAt, ?Carbon $closeAt): array
    {
        $errors = [];

        if (
            $saleStartAt !== null
            && PartnerQuota::query()
                ->where('game_id', $gameId)
                ->whereNotNull('sale_start_at')
                ->where('sale_start_at', '<', $saleStartAt)
                ->exists()
        ) {
            $errors['sale_start_at'][] = 'Existing partner sale_start_at overrides cannot be before the central sale_start_at.';
        }

        if (
            $closeAt !== null
            && PartnerQuota::query()
                ->where('game_id', $gameId)
                ->whereNotNull('sale_close_at')
                ->where('sale_close_at', '>', $closeAt)
                ->exists()
        ) {
            $errors['close_at'][] = 'Existing partner sale_close_at overrides cannot be after the central close_at.';
        }

        if (
            $saleStartAt !== null
            && PartnerQuota::query()
                ->where('game_id', $gameId)
                ->whereNotNull('sale_close_at')
                ->where('sale_close_at', '<=', $saleStartAt)
                ->exists()
        ) {
            $errors['sale_start_at'][] = 'Existing partner sale_close_at overrides must remain after the central sale_start_at.';
        }

        if (
            $closeAt !== null
            && PartnerQuota::query()
                ->where('game_id', $gameId)
                ->whereNotNull('sale_start_at')
                ->where('sale_start_at', '>=', $closeAt)
                ->exists()
        ) {
            $errors['close_at'][] = 'Existing partner sale_start_at overrides must remain before the central close_at.';
        }

        return $errors;
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
            'closed_at' => $game->closed_at,
            'archived_at' => $game->archived_at,
            'created_at' => $game->created_at,
            'updated_at' => $game->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function stockResource(object $stock): array
    {
        return [
            'id' => (string) $stock->id,
            'tenant_id' => $stock->tenant_id,
            'status' => (string) $stock->status,
            'created_at' => $stock->created_at,
            'updated_at' => $stock->updated_at,
            'game_id' => (string) $stock->game_id,
            'batch_id' => $stock->batch_id,
            'full_number' => (string) $stock->full_number,
            'front3' => $stock->front3,
            'back3' => $stock->back3,
            'back2' => $stock->back2,
            'partner_id' => $stock->partner_id,
            'allocation_id' => $stock->allocation_id,
            'recall_reason' => $stock->recall_reason,
            'recalled_at' => $stock->recalled_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function stockGroupResource(object $stock): array
    {
        return [
            'id' => (string) $stock->game_id.':'.(string) $stock->full_number,
            'game_id' => (string) $stock->game_id,
            'full_number' => (string) $stock->full_number,
            'sample_stock_item_id' => (string) $stock->sample_stock_item_id,
            'total_count' => (int) $stock->total_count,
            'available_count' => (int) $stock->available_count,
            'allocated_count' => (int) $stock->allocated_count,
            'sold_count' => (int) $stock->sold_count,
            'recalled_count' => (int) $stock->recalled_count,
            'first_created_at' => $stock->first_created_at,
            'last_updated_at' => $stock->last_updated_at,
        ];
    }

    private function stockGroupCursor(object $stock, ?array $sort = null): string
    {
        $cursor = [
            'game_id' => (string) $stock->game_id,
            'full_number' => (string) $stock->full_number,
        ];

        if ($sort !== null) {
            $cursor['sort_by'] = $sort['key'];
            $cursor['sort_dir'] = $sort['direction'];
            $cursor['value'] = $stock->{$sort['key']} ?? null;
        }

        return base64_encode(json_encode($cursor, JSON_THROW_ON_ERROR));
    }

    /**
     * @return array<string, mixed>|null
     */
    private function decodeStockGroupCursor(mixed $cursor): ?array
    {
        if ($cursor === null || trim((string) $cursor) === '') {
            return null;
        }

        try {
            $decoded = json_decode((string) base64_decode((string) $cursor, true), true, flags: JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            return null;
        }

        if (! is_array($decoded) || ! isset($decoded['game_id'], $decoded['full_number'])) {
            return null;
        }

        return [
            'game_id' => (string) $decoded['game_id'],
            'full_number' => (string) $decoded['full_number'],
            'sort_by' => $decoded['sort_by'] ?? null,
            'sort_dir' => $decoded['sort_dir'] ?? null,
            'value' => $decoded['value'] ?? null,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function stockResourceById(string $stockItemId): ?array
    {
        $stock = StockItem::where('id', $stockItemId)->first();

        return $stock === null ? null : $this->stockResource($stock);
    }

    /**
     * @return array<string, mixed>
     */
    private function batchResource(object $batch): array
    {
        return [
            'id' => (string) $batch->id,
            'tenant_id' => null,
            'status' => (string) $batch->status,
            'created_at' => $batch->created_at,
            'updated_at' => $batch->updated_at,
            'game_id' => (string) $batch->game_id,
            'type' => (string) $batch->type,
            'requested_count' => (int) $batch->requested_count,
            'generated_count' => (int) $batch->generated_count,
            'range_start' => $batch->range_start,
            'range_end' => $batch->range_end,
            'number_digits' => (int) $batch->number_digits,
            'completed_at' => $batch->completed_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function batchResourceById(string $batchId): array
    {
        return $this->batchResource(StockGenerationBatch::where('id', $batchId)->first());
    }

    /**
     * @return array<string, mixed>
     */
    private function quotaResource(object $quota): array
    {
        $game = Game::whereKey($quota->game_id)->first(['sale_start_at', 'close_at']);

        return [
            'id' => (string) $quota->id,
            'tenant_id' => null,
            'status' => (string) $quota->status,
            'created_at' => $quota->created_at,
            'updated_at' => $quota->updated_at,
            'partner_id' => (string) $quota->partner_id,
            'game_id' => (string) $quota->game_id,
            'quota_count' => (int) $quota->quota_count,
            'allocated_count' => (int) $quota->allocated_count,
            'remaining_count' => max(0, (int) $quota->quota_count - (int) $quota->allocated_count),
            'central_sale_start_at' => $game?->sale_start_at,
            'central_sale_close_at' => $game?->close_at,
            'sale_start_override_at' => $quota->sale_start_at,
            'sale_close_override_at' => $quota->sale_close_at,
            'sale_start_at' => $quota->sale_start_at ?? $game?->sale_start_at,
            'sale_close_at' => $quota->sale_close_at ?? $game?->close_at,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function quotaResourceById(string $quotaId): ?array
    {
        $quota = PartnerQuota::where('id', $quotaId)->first();

        return $quota === null ? null : $this->quotaResource($quota);
    }

    /**
     * @return array<string, mixed>
     */
    private function allocationResource(object $allocation): array
    {
        return [
            'id' => (string) $allocation->id,
            'partner_id' => (string) $allocation->partner_id,
            'tenant_id' => (string) $allocation->tenant_id,
            'game_id' => (string) $allocation->game_id,
            'status' => (string) $allocation->status,
            'requested_count' => (int) $allocation->requested_count,
            'allocated_count' => (int) $allocation->allocated_count,
            'quota_id' => $allocation->quota_id,
            'created_at' => $allocation->created_at,
            'updated_at' => $allocation->updated_at,
            'cancelled_at' => $allocation->cancelled_at,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditGameChange(AdminSessionContext $actor, Request $request, string $gameId, string $changeType, array $payload): void
    {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'game.'.$changeType,
            targetType: 'game',
            targetId: $gameId,
            payload: [
                'change_type' => $changeType,
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditStockChange(
        AdminSessionContext $actor,
        Request $request,
        string $targetId,
        string $action,
        array $payload,
        ?string $partnerId = null,
        ?string $tenantId = null,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: $action,
            targetType: str_contains($action, 'recalled') ? 'stock_item' : 'stock_generation_batch',
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

    /**
     * @param array<string, mixed> $payload
     */
    private function auditQuotaChange(AdminSessionContext $actor, Request $request, string $quotaId, string $changeType, array $payload): void
    {
        $partnerId = PartnerQuota::where('id', $quotaId)->value('partner_id');

        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'partner_quota.'.$changeType,
            targetType: 'partner_quota',
            targetId: $quotaId,
            payload: [
                'change_type' => $changeType,
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditAllocationChange(
        AdminSessionContext $actor,
        Request $request,
        string $allocationId,
        string $action,
        array $payload,
        string $partnerId,
        string $tenantId,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: $action,
            targetType: 'partner_stock_allocation',
            targetId: $allocationId,
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

    /**
     * @param array<string, mixed> $payload
     */
    private function insertOutboxEvent(
        string $eventType,
        string $producer,
        ?string $tenantId,
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
            'producer' => $producer,
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

    private function canParseDate(mixed $value): bool
    {
        if (! is_string($value) || trim($value) === '') {
            return false;
        }

        try {
            Carbon::parse($value);

            return true;
        } catch (\Throwable) {
            return false;
        }
    }

    private function dateFromPayloadOrModel(array $payload, string $field, ?object $model): ?Carbon
    {
        if (array_key_exists($field, $payload)) {
            if ($payload[$field] === null || trim((string) $payload[$field]) === '' || ! $this->canParseDate($payload[$field])) {
                return null;
            }

            return Carbon::parse((string) $payload[$field]);
        }

        return $this->dateFromModelValue($model?->{$field} ?? null);
    }

    private function dateFromModelValue(mixed $value): ?Carbon
    {
        if ($value === null || trim((string) $value) === '') {
            return null;
        }

        return Carbon::parse((string) $value);
    }

    private function toTimestamp(mixed $value): string
    {
        return Carbon::parse((string) $value)->toISOString();
    }

    private function gameCodeFromDrawAt(mixed $value): string
    {
        $drawAt = Carbon::parse((string) $value)->copy()->setTimezone(self::BUSINESS_TIMEZONE);
        $buddhistYear = (int) $drawAt->format('Y') + 543;

        return $drawAt->format('dm').$buddhistYear;
    }

    private function nullableTimestamp(mixed $value): ?string
    {
        if ($value === null || trim((string) $value) === '') {
            return null;
        }

        return $this->toTimestamp($value);
    }

    /**
     * @param array<string, array<int, string>> $base
     * @param array<string, array<int, string>> $incoming
     * @return array<string, array<int, string>>
     */
    private function mergeFieldErrors(array $base, array $incoming): array
    {
        foreach ($incoming as $field => $messages) {
            $base[$field] = array_values(array_merge($base[$field] ?? [], $messages));
        }

        return $base;
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<string, array<int, string>> $errors
     */
    private function quotaCountFromPayload(array $payload, string $field, array &$errors, bool $required = true): ?int
    {
        if (! array_key_exists($field, $payload) || $payload[$field] === null || $payload[$field] === '') {
            if ($required) {
                $errors[$field][] = 'The '.$field.' field is required.';
            }

            return null;
        }

        $value = filter_var($payload[$field], FILTER_VALIDATE_INT);

        if ($value === false) {
            $errors[$field][] = 'The '.$field.' field must be an integer.';

            return null;
        }

        $value = (int) $value;

        if ($value < 1) {
            $errors[$field][] = 'The '.$field.' field must be at least 1.';

            return null;
        }

        return $value;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{input_mode: string, total_count: int, back2_count_per_number: int, back3_count_per_number: int, front3_count_per_number: int}
     */
    private function normalizedGenerateQuotaCounts(array $payload): array
    {
        if (! $this->hasPayloadValue($payload, 'back2_count_per_number')
            && ! $this->hasPayloadValue($payload, 'back3_count_per_number')
            && ! $this->hasPayloadValue($payload, 'front3_count_per_number')
            && $this->hasPayloadValue($payload, 'total_count')) {
            $totalCount = $this->integerFrom($payload['total_count']);
            $back3Count = intdiv($totalCount, self::GENERATE_BASE_COUNT);

            return [
                'input_mode' => 'total_count',
                'total_count' => $totalCount,
                'back2_count_per_number' => $back3Count * 10,
                'back3_count_per_number' => $back3Count,
                'front3_count_per_number' => $back3Count,
            ];
        }

        $back3Count = $this->integerFrom($payload['back3_count_per_number']);

        return [
            'input_mode' => $this->hasPayloadValue($payload, 'total_count') ? 'quota_with_total_check' : 'quota_fields',
            'total_count' => $back3Count * self::GENERATE_BASE_COUNT,
            'back2_count_per_number' => $this->integerFrom($payload['back2_count_per_number']),
            'back3_count_per_number' => $back3Count,
            'front3_count_per_number' => $this->integerFrom($payload['front3_count_per_number']),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function hasPayloadValue(array $payload, string $field): bool
    {
        return array_key_exists($field, $payload) && $payload[$field] !== null && $payload[$field] !== '';
    }

    /**
     * @return array<int, string>
     */
    private function quotaGeneratedNumbers(string $gameId, string $idempotencyKey, int $rounds): array
    {
        $numbers = [];

        for ($round = 0; $round < $rounds; $round++) {
            $back3Numbers = $this->shuffledBack3Numbers($gameId, $idempotencyKey, $round);

            for ($front = 0; $front < self::GENERATE_BASE_COUNT; $front++) {
                $front3 = str_pad((string) $front, 3, '0', STR_PAD_LEFT);
                $numbers[] = $front3.$back3Numbers[$front];
            }
        }

        return $numbers;
    }

    /**
     * @return array<int, string>
     */
    private function shuffledBack3Numbers(string $gameId, string $idempotencyKey, int $round): array
    {
        $seed = $gameId.':'.$idempotencyKey.':'.$round;
        $weighted = [];

        for ($number = 0; $number < self::GENERATE_BASE_COUNT; $number++) {
            $back3 = str_pad((string) $number, 3, '0', STR_PAD_LEFT);
            $weighted[] = [
                'number' => $back3,
                'weight' => hash('sha256', $seed.':'.$back3),
            ];
        }

        usort($weighted, function (array $left, array $right): int {
            $weightCompare = strcmp($left['weight'], $right['weight']);

            return $weightCompare !== 0 ? $weightCompare : strcmp($left['number'], $right['number']);
        });

        return array_column($weighted, 'number');
    }

    private function normalizeFullNumber(string $number, int $digits): string
    {
        return str_pad($number, $digits, '0', STR_PAD_LEFT);
    }

    private function integerFrom(mixed $value): int
    {
        $integer = filter_var($value, FILTER_VALIDATE_INT);

        return $integer === false ? 0 : (int) $integer;
    }

    private function nullableQueryString(mixed $value): ?string
    {
        if ($value === null) {
            return null;
        }

        $normalized = trim((string) $value);

        return $normalized === '' ? null : $normalized;
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
     * @return array<string, mixed>
     */
    private function resourceMetadata(array $payload): array
    {
        $metadata = $payload['metadata'] ?? [];

        return is_array($metadata) ? $metadata : [];
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

    /**
     * @param array<string, mixed> $payload
     */
    private function payloadHash(array $payload): string
    {
        ksort($payload);

        return hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR));
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
}
