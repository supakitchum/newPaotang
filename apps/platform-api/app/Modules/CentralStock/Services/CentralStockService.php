<?php

namespace App\Modules\CentralStock\Services;

use App\Jobs\DispatchStockBatchImageJobs;
use App\Jobs\GenerateLotteryImageJob;
use App\Jobs\GenerateStockBatchChunkJob;
use App\Jobs\TriggerLottoScraperPollJob;
use App\Models\Game;
use App\Models\Partner;
use App\Models\PartnerQuota;
use App\Models\PartnerStockAllocation;
use App\Models\PartnerStockAllocationItem;
use App\Models\PartnerTenant;
use App\Models\RewardPrize;
use App\Models\RewardResult;
use App\Models\StockGenerationBatch;
use App\Models\StockGenerationBatchChunk;
use App\Models\StockItem;
use App\Models\SyncOutbox;
use App\Modules\CentralStock\Events\StockGenerationProgressUpdated;
use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
use App\Modules\PartnerStore\Services\VirtualStockService;
use App\Modules\Pricing\Services\LotterySalePriceService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Support\PublicUrl;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;
use Throwable;

class CentralStockService
{
    private const GENERATE_NUMBER_DIGITS = 6;
    private const GENERATE_BASE_COUNT = 1000;
    private const GENERATE_SYNC_THRESHOLD = 10000;
    private const GENERATE_MAX_REQUEST_COUNT = 2147000000;

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
    private const CLOSED_GAME_STATUSES = ['closed', 'reward_recorded', 'reward_checking', 'reward_verified', 'reward_published'];
    private const RECORDED_REWARD_RESULT_STATUSES = ['recorded', 'checking', 'summary_ready', 'verified', 'published', 'corrected'];

    private const STOCK_STATUSES = ['available', 'allocated', 'sold', 'recalled', 'voided'];
    private const QUOTA_STATUSES = ['active', 'inactive', 'archived'];
    private const GENERATION_BATCH_TYPES = ['generate', 'virtual_profile'];
    private const VIRTUAL_MAX_BP = 10000;
    private const VIRTUAL_UNLIMITED = 2147483647;
    private const STOCK_SET_DISTRIBUTION_SETTING_KEY = 'stock_set_distribution_default';
    private const STOCK_PATTERN_COVERAGE_SETTING_KEY = 'stock_pattern_coverage_default';
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
    private const CANCELLABLE_ALLOCATION_STATUSES = ['draft', 'pending', 'processing', 'allocated', 'partially_allocated', 'failed'];
    private const ACTIVE_ALLOCATION_PAIR_STATUSES = ['pending', 'processing', 'allocated', 'partially_allocated'];

    /** @var array<string, array{code: ?string, name: ?string, label: string}> */
    private array $ownerPartnerLabelCache = [];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly LotteryImageGenerator $lotteryImages,
        private readonly VirtualStockService $virtualStock,
        private readonly StockCoverageRealtimeService $coverageRealtime,
        private readonly LotterySalePriceService $salePrices,
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
                ! $this->gameIsClosedForNextOpening($previousGame)
                || ! $this->gameHasRecordedRewardResult((string) $previousGame->id)
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

            $this->salePrices->seedRulesForNewGameFromPreviousDraw($gameId, $now);
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
            $this->dispatchLottoScraperTriggerAfterCommit($gameId, (string) $game->code, 'game_closed');

            return $this->findGame($gameId);
        });
    }

    /**
     * @return array<string, mixed>|null
     */
    public function triggerRewardScraperForGame(string $gameId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        $game = Game::query()->where('id', $gameId)->first();

        if ($game === null) {
            return null;
        }

        if (! in_array((string) $game->status, self::CLOSED_GAME_STATUSES, true)) {
            return [
                'error' => 'resource_conflict',
                'message' => 'The game must be closed before triggering reward result scraping.',
            ];
        }

        $reason = trim((string) ($payload['reason'] ?? 'manual_trigger')) ?: 'manual_trigger';
        $this->dispatchLottoScraperTriggerAfterCommit($gameId, (string) $game->code, $reason);
        $this->auditGameChange($actor, $request, $gameId, 'reward_scraper_triggered', [
            'draw_code' => (string) $game->code,
            'reason' => $reason,
        ]);

        return [
            'game_id' => $gameId,
            'draw_code' => (string) $game->code,
            'status' => 'queued',
            'reason' => $reason,
        ];
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

    private function dispatchLottoScraperTriggerAfterCommit(string $gameId, string $drawCode, string $reason): void
    {
        $drawCode = trim($drawCode);

        if ($drawCode === '') {
            Log::warning('Skipped lotto scraper trigger because draw code is empty.', [
                'game_id' => $gameId,
                'reason' => $reason,
            ]);

            return;
        }

        $dispatch = static fn (): mixed => TriggerLottoScraperPollJob::dispatch($drawCode, $gameId, $reason);

        if (DB::transactionLevel() > 0) {
            DB::afterCommit($dispatch);

            return;
        }

        $dispatch();
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
        $virtualSummary = $this->virtualStockSummary($gameId, $batchId);
        if ($virtualSummary !== null) {
            return $virtualSummary;
        }

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
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function stockPatternSummary(array $queryParams): array
    {
        $gameId = $this->nullableQueryString($queryParams['game_id'] ?? null);
        $dimension = $this->normalizedLimitDimension($queryParams['dimension'] ?? null) ?? 'back2';
        $limit = $this->limit($queryParams['limit'] ?? null);
        $sort = $this->resolveVirtualPatternSort($queryParams);
        $cursor = $this->decodeVirtualPatternCursor($queryParams['cursor'] ?? null, $dimension, $queryParams, $sort);
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($queryParams);
        $profile = $this->activeVirtualStockProfile($gameId);

        if ($profile === null) {
            return [
                'game_id' => $gameId,
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'stock_mode' => 'virtual',
                'empty' => true,
                'limits' => $this->publicVirtualLimits($this->defaultStockPatternCoverageForScope($scopeType)),
                'central_limits' => $this->publicVirtualLimits(
                    $gameId === null
                        ? $this->defaultStockPatternCoverageForScope('central')
                        : $this->virtualLimits($gameId, 'central', 'central'),
                ),
                'totals' => $this->emptyVirtualPatternTotals(),
                'data' => [],
                'meta' => [
                    'dimension' => $dimension,
                    'next_cursor' => null,
                    'has_more' => false,
                    'sort_by' => $sort['key'],
                    'sort_dir' => $sort['direction'],
                ],
            ];
        }

        $resolvedGameId = (string) $profile->game_id;
        $limits = $this->virtualLimits($resolvedGameId, $scopeType, $scopeId);
        $dimensions = [
            'back2' => $this->virtualPatternRows($resolvedGameId, 'back2', $scopeType, $scopeId, $profile),
            'front3' => $this->virtualPatternRows($resolvedGameId, 'front3', $scopeType, $scopeId, $profile),
            'back3' => $this->virtualPatternRows($resolvedGameId, 'back3', $scopeType, $scopeId, $profile),
        ];
        $rows = $this->filterVirtualPatternRows($dimensions[$dimension], $queryParams['q'] ?? null);
        $this->sortVirtualPatternRows($rows, $sort);
        $offset = max(0, (int) ($cursor['offset'] ?? 0));
        $pageRows = array_slice($rows, $offset, $limit + 1);
        $hasMore = count($pageRows) > $limit;
        $pageRows = array_slice($pageRows, 0, $limit);
        $pageRows = $this->withCentralPatternCeilings($pageRows, $resolvedGameId, $dimension, $scopeType);
        $centralLimits = $this->virtualLimits($resolvedGameId, 'central', 'central');

        return [
            'game_id' => $resolvedGameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'profile_id' => (string) $profile->id,
            'batch_id' => $this->latestVirtualBatchId($resolvedGameId),
            'stock_mode' => 'virtual',
            'empty' => false,
            'limits' => $this->publicVirtualLimits($limits),
            'central_limits' => $this->publicVirtualLimits($centralLimits),
            'totals' => array_map(fn (array $rows): array => $this->virtualPatternTotals($rows), $dimensions),
            'data' => $pageRows,
            'meta' => [
                'dimension' => $dimension,
                'next_cursor' => $hasMore ? $this->virtualPatternCursor($dimension, $queryParams, $sort, $offset + $limit) : null,
                'has_more' => $hasMore,
                'sort_by' => $sort['key'],
                'sort_dir' => $sort['direction'],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function stockLimitOverrides(array $queryParams): array
    {
        $gameId = $this->nullableQueryString($queryParams['game_id'] ?? null);
        $dimension = $this->normalizedLimitDimension($queryParams['dimension'] ?? null) ?? 'back2';
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($queryParams);
        $rows = $gameId === null ? [] : $this->virtualLimitOverrideRows($gameId, $scopeType, $scopeId, $dimension);

        return [
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'dimension' => $dimension,
            'data' => $rows,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function stockSettings(): array
    {
        return $this->stockSettingsResource();
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateStockSettingsPayload(array $payload): array
    {
        $raw = is_array($payload['settings'] ?? null) ? $payload['settings'] : $payload;
        $distribution = $raw[self::STOCK_SET_DISTRIBUTION_SETTING_KEY] ?? $raw['set_distribution'] ?? null;
        $coverage = $raw[self::STOCK_PATTERN_COVERAGE_SETTING_KEY] ?? $raw['stock_pattern_coverage'] ?? null;

        return $this->mergeFieldErrors(
            $this->stockSetDistributionErrors($distribution),
            $this->stockPatternCoverageErrors($coverage),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function updateStockSettings(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $raw = is_array($payload['settings'] ?? null) ? $payload['settings'] : $payload;
        $hasDistribution = array_key_exists(self::STOCK_SET_DISTRIBUTION_SETTING_KEY, $raw) || array_key_exists('set_distribution', $raw);
        $hasCoverage = array_key_exists(self::STOCK_PATTERN_COVERAGE_SETTING_KEY, $raw) || array_key_exists('stock_pattern_coverage', $raw);
        $now = now();

        if ($hasDistribution) {
            $distribution = $this->normalizeStockSetDistribution($raw[self::STOCK_SET_DISTRIBUTION_SETTING_KEY] ?? $raw['set_distribution'] ?? []);

            DB::table('platform_system_settings')->updateOrInsert(
                ['key' => self::STOCK_SET_DISTRIBUTION_SETTING_KEY],
                [
                    'id' => $this->stableId('pss', self::STOCK_SET_DISTRIBUTION_SETTING_KEY),
                    'value_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        if ($hasCoverage) {
            $coverage = $this->normalizeStockPatternCoverage(
                $raw[self::STOCK_PATTERN_COVERAGE_SETTING_KEY] ?? $raw['stock_pattern_coverage'] ?? [],
                $this->currentStockPatternCoverage(),
            );

            DB::table('platform_system_settings')->updateOrInsert(
                ['key' => self::STOCK_PATTERN_COVERAGE_SETTING_KEY],
                [
                    'id' => $this->stableId('pss', self::STOCK_PATTERN_COVERAGE_SETTING_KEY),
                    'value_json' => json_encode($coverage, JSON_THROW_ON_ERROR),
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'stock.settings.updated',
            targetType: 'platform_system_settings',
            targetId: 'stock_settings',
            payload: [
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload' => $payload,
            ],
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        return $this->stockSettingsResource();
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateLimitSettingsPayload(array $payload): array
    {
        $errors = [];
        $gameId = $this->nullableQueryString($payload['game_id'] ?? null);
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($payload);

        if ($gameId === null || ! Game::whereKey($gameId)->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        if ($scopeType === 'partner' && ! Partner::whereKey($scopeId)->exists()) {
            $errors['scope_id'][] = 'The scope_id field must reference an existing partner.';
        }

        foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
            $value = $payload[$field] ?? null;
            if (! array_key_exists($field, $payload) || $value === null || $value === '') {
                $errors[$field][] = 'The '.$field.' field is required and cannot be unlimited.';
                continue;
            }

            $limit = filter_var($value, FILTER_VALIDATE_INT);
            if ($limit === false || (int) $limit < 0) {
                $errors[$field][] = 'The '.$field.' field must be zero or greater.';
            }
        }

        if ($gameId !== null && $scopeType === 'partner') {
            foreach ($this->partnerLimitSettingCeilingErrors($gameId, $payload) as $field => $messages) {
                foreach ($messages as $message) {
                    $errors[$field][] = $message;
                }
            }
        }

        if ($gameId !== null) {
            foreach ($this->limitSettingSupplyErrors($gameId, $scopeType, $scopeId, $payload) as $field => $messages) {
                foreach ($messages as $message) {
                    $errors[$field][] = $message;
                }
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function updateStockLimitSettings(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $gameId = (string) $payload['game_id'];
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($payload);
        $limits = [
            'back2_limit' => $this->nullableLimitFromPayload($payload['back2_limit'] ?? null),
            'back3_limit' => $this->nullableLimitFromPayload($payload['back3_limit'] ?? null),
            'front3_limit' => $this->nullableLimitFromPayload($payload['front3_limit'] ?? null),
        ];
        $now = now();

        $limitQuery = DB::table('stock_sale_limit_settings')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId);
        $limitValues = [
            'back2_limit' => $limits['back2_limit'],
            'back3_limit' => $limits['back3_limit'],
            'front3_limit' => $limits['front3_limit'],
            'updated_at' => $now,
        ];

        if ((clone $limitQuery)->exists()) {
            $limitQuery->update($limitValues);
        } else {
            DB::table('stock_sale_limit_settings')->insert($limitValues + [
                'id' => $this->stableId('ssl', $gameId.':'.$scopeType.':'.$scopeId),
                'game_id' => $gameId,
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'created_at' => $now,
            ]);
        }

        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'stock.limit_settings.updated',
            targetType: 'stock_sale_limit_setting',
            targetId: $gameId.':'.$scopeType.':'.$scopeId,
            payload: [
                'idempotency_key' => (string) $request->header('Idempotency-Key'),
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'limits' => $limits,
            ],
            tenantId: null,
            partnerId: $scopeType === 'partner' ? $scopeId : null,
            requestId: (string) ($request->header('X-Request-Id') ?: ''),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        $this->coverageRealtime->broadcastLimitSettingsChangedAfterCommit($gameId, $scopeType, $scopeId);

        return $this->stockPatternSummary([
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
        ]);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateLimitOverridePayload(array $payload): array
    {
        $errors = [];
        $gameId = $this->nullableQueryString($payload['game_id'] ?? null);
        $dimension = $this->normalizedLimitDimension($payload['dimension'] ?? null);
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($payload);

        if ($gameId === null || ! Game::whereKey($gameId)->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        if ($dimension === null) {
            $errors['dimension'][] = 'The dimension field must be back2, back3, or front3.';
        }

        if ($scopeType === 'partner' && ! Partner::whereKey($scopeId)->exists()) {
            $errors['scope_id'][] = 'The scope_id field must reference an existing partner.';
        }

        $overrides = $payload['overrides'] ?? null;
        if (! is_array($overrides) || $overrides === []) {
            $errors['overrides'][] = 'The overrides field must include at least one row.';
            return $errors;
        }

        $pad = $dimension === 'back2' ? 2 : 3;
        foreach ($overrides as $index => $row) {
            if (! is_array($row)) {
                $errors['overrides.'.$index][] = 'Each override must be an object.';
                continue;
            }

            $value = preg_replace('/\D+/', '', (string) ($row['value'] ?? '')) ?? '';
            if (strlen($value) !== $pad) {
                $errors['overrides.'.$index.'.value'][] = 'The value field must contain exactly '.$pad.' digits.';
            }

            if (($row['limit'] ?? null) !== null && $row['limit'] !== '') {
                $limit = filter_var($row['limit'], FILTER_VALIDATE_INT);
                if ($limit === false || (int) $limit < 0) {
                    $errors['overrides.'.$index.'.limit'][] = 'The limit field must be zero or greater.';
                }
            }
        }

        if ($gameId !== null && $dimension !== null && $scopeType === 'partner') {
            foreach ($this->partnerLimitOverrideCeilingErrors($gameId, $dimension, $overrides) as $field => $messages) {
                foreach ($messages as $message) {
                    $errors[$field][] = $message;
                }
            }
        }

        if ($gameId !== null && $dimension !== null) {
            foreach ($this->limitOverrideSupplyErrors($gameId, $dimension, $scopeType, $scopeId, $overrides) as $field => $messages) {
                foreach ($messages as $message) {
                    $errors[$field][] = $message;
                }
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function updateStockLimitOverrides(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $gameId = (string) $payload['game_id'];
        $dimension = $this->normalizedLimitDimension($payload['dimension'] ?? null) ?? 'back2';
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($payload);
        $now = now();
        $changedValues = [];

        foreach ($payload['overrides'] as $row) {
            $value = preg_replace('/\D+/', '', (string) ($row['value'] ?? '')) ?? '';
            $limit = $row['limit'] ?? null;
            $id = $this->stableId('vso', implode(':', [$gameId, $scopeType, $scopeId, $dimension, $value]));
            $changedValues[] = $value;

            if ($limit === null || $limit === '') {
                DB::table('stock_sale_limit_overrides')->where('id', $id)->delete();
                continue;
            }

            DB::table('stock_sale_limit_overrides')->updateOrInsert(
                ['id' => $id],
                [
                    'game_id' => $gameId,
                    'scope_type' => $scopeType,
                    'scope_id' => $scopeId,
                    'dimension' => $dimension,
                    'value' => $value,
                    'limit' => (int) $limit,
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        $this->auditLogger->logAdminWrite(
            actorId: $actor->adminUser['id'],
            scopeType: 'central',
            action: 'stock.limit_overrides.updated',
            targetType: 'stock_sale_limit_override',
            targetId: $gameId.':'.$scopeType.':'.$scopeId.':'.$dimension,
            payload: [
                'idempotency_key' => (string) $request->header('Idempotency-Key'),
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'dimension' => $dimension,
                'overrides' => $payload['overrides'],
            ],
            tenantId: null,
            partnerId: $scopeType === 'partner' ? $scopeId : null,
            requestId: (string) ($request->header('X-Request-Id') ?: ''),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );

        $this->coverageRealtime->broadcastLimitOverridesChangedAfterCommit($gameId, $scopeType, $scopeId, $dimension, $changedValues);

        return $this->stockPatternSummary([
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
        ]);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listGenerationBatches(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $sort = $this->resolveGenerationBatchSort($queryParams);
        $query = StockGenerationBatch::query()
            ->whereIn('type', self::GENERATION_BATCH_TYPES)
            ->limit($limit + 1);

        foreach (['game_id', 'status'] as $filter) {
            if (($queryParams[$filter] ?? null) !== null && trim((string) $queryParams[$filter]) !== '') {
                $query->where($filter, trim((string) $queryParams[$filter]));
            }
        }

        $this->applyGenerationBatchCursor($query, $queryParams['cursor'] ?? null, $sort);
        $this->applyGenerationBatchOrder($query, $sort);

        $rows = $query->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $batch): array => $this->batchResource($batch), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? $this->generationBatchCursor(end($rows), $sort) : null,
                'has_more' => $hasMore,
                'sort_by' => $sort['key'],
                'sort_dir' => $sort['direction'],
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findGenerationBatch(string $batchId): ?array
    {
        $batch = StockGenerationBatch::query()
            ->whereIn('type', self::GENERATION_BATCH_TYPES)
            ->where('id', $batchId)
            ->first();

        return $batch === null ? null : $this->batchResource($batch, includeChunks: true);
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
     * @return array<string, mixed>|null
     */
    private function virtualStockSummary(?string $gameId, ?string $batchId): ?array
    {
        $profileQuery = DB::table('stock_supply_profiles')->where('status', 'active');

        if ($gameId !== null) {
            $profileQuery->where('game_id', $gameId);
        }

        if ($batchId !== null) {
            $batch = StockGenerationBatch::query()
                ->where('id', $batchId)
                ->where('type', 'virtual_profile')
                ->first();

            if ($batch === null) {
                return null;
            }

            $profileQuery->where('game_id', (string) $batch->game_id);
        }

        $profile = $profileQuery
            ->orderByDesc('updated_at')
            ->orderByDesc('id')
            ->first();

        if ($profile === null) {
            return null;
        }

        $resolvedGameId = (string) $profile->game_id;
        $resolvedBatchId = $batchId ?? $this->latestVirtualBatchId($resolvedGameId);
        $counters = $this->virtualCounterTotals([$resolvedGameId])[$resolvedGameId] ?? ['reserved' => 0, 'sold' => 0];
        $totalCount = (int) $profile->total_capacity;
        $patternRows = [
            'back2' => $this->virtualPatternRows($resolvedGameId, 'back2', profile: $profile),
            'back3' => $this->virtualPatternRows($resolvedGameId, 'back3', profile: $profile),
            'front3' => $this->virtualPatternRows($resolvedGameId, 'front3', profile: $profile),
        ];
        $statusCounts = $this->virtualStockStatusCounts($totalCount, $counters, $patternRows);

        return [
            'game_id' => $resolvedGameId,
            'batch_id' => $resolvedBatchId,
            'stock_mode' => 'virtual',
            'profile_id' => (string) $profile->id,
            'total_count' => $totalCount,
            'status_counts' => $statusCounts,
            'pattern_totals' => array_map(fn (array $rows): array => $this->virtualPatternTotals($rows), $patternRows),
            'number_coverage' => [
                'back2' => $this->virtualNumberCoverage($patternRows['back2'], 100),
                'back3' => $this->virtualNumberCoverage($patternRows['back3'], 1000),
                'front3' => $this->virtualNumberCoverage($patternRows['front3'], 1000),
            ],
            'empty' => false,
        ];
    }

    /**
     * @return array{expected_distinct: int, distinct_count: int, missing_distinct_count: int, min_count_per_number: int, max_count_per_number: int, total_count: int}
     */
    private function virtualNumberCoverage(array $rows, int $expectedDistinct): array
    {
        $usedCounts = array_map(fn (array $row): int => (int) ($row['used_count'] ?? 0), $rows);

        return [
            'expected_distinct' => $expectedDistinct,
            'distinct_count' => count($rows),
            'missing_distinct_count' => 0,
            'min_count_per_number' => $usedCounts === [] ? 0 : min($usedCounts),
            'max_count_per_number' => $usedCounts === [] ? 0 : max($usedCounts),
            'total_count' => array_sum($usedCounts),
        ];
    }

    /**
     * @param array{reserved: int, sold: int} $fullCounters
     * @return array<string, int>
     */
    private function virtualStockStatusCounts(int $totalCount, array $fullCounters, array $patternRows): array
    {
        $reservedCount = min($totalCount, (int) $fullCounters['reserved']);
        $soldCount = min($totalCount, (int) $fullCounters['sold']);
        $usedFullCount = min($totalCount, $reservedCount + $soldCount);
        $availableCount = $totalCount - $usedFullCount;

        foreach (['back2', 'back3', 'front3'] as $dimension) {
            $remainingValues = array_map(fn (array $row): ?int => $row['remaining_limit'] ?? null, $patternRows[$dimension] ?? []);
            if (in_array(null, $remainingValues, true)) {
                continue;
            }

            $availableCount = min($availableCount, array_sum($remainingValues));
        }

        return [
            'available' => max(0, $availableCount),
            'allocated' => $reservedCount,
            'sold' => $soldCount,
            'recalled' => 0,
            'voided' => 0,
            'total' => $totalCount,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function virtualPatternRows(string $gameId, string $dimension, string $scopeType = 'central', string $scopeId = 'central', ?object $profile = null): array
    {
        $expected = $dimension === 'back2' ? 100 : 1000;
        $pad = $dimension === 'back2' ? 2 : 3;
        $limitKey = $dimension.'_limit';
        $defaultLimit = $this->virtualLimits($gameId, $scopeType, $scopeId)[$limitKey];
        $generatedCounts = $this->virtualGeneratedCountsForDimension($gameId, $dimension, $scopeType, $scopeId, $profile);
        $overrides = $this->virtualLimitOverrideRows($gameId, $scopeType, $scopeId, $dimension);
        $counters = DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->get(['value', 'reserved_count', 'sold_count', 'updated_at'])
            ->keyBy(fn (object $row): string => (string) $row->value);
        $rows = [];

        for ($index = 0; $index < $expected; $index++) {
            $value = str_pad((string) $index, $pad, '0', STR_PAD_LEFT);
            $counter = $counters[$value] ?? null;
            $overrideLimit = $overrides[$value]['limit'] ?? null;
            $limit = $overrideLimit ?? $defaultLimit;
            $generatedCount = $generatedCounts[$value] ?? 0;
            $reservedCount = $counter === null ? 0 : (int) $counter->reserved_count;
            $soldCount = $counter === null ? 0 : (int) $counter->sold_count;
            $usedCount = $reservedCount + $soldCount;
            $generatedRemainingCount = max(0, $generatedCount - $usedCount);
            $remainingLimit = $limit >= self::VIRTUAL_UNLIMITED ? null : max(0, $limit - $usedCount);

            $rows[] = [
                'id' => $gameId.':'.$dimension.':'.$value,
                'game_id' => $gameId,
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'dimension' => $dimension,
                'number' => $value,
                'label' => $value,
                'reserved_count' => $reservedCount,
                'sold_count' => $soldCount,
                'used_count' => $usedCount,
                'generated_count' => $generatedCount,
                'generated_remaining_count' => $generatedRemainingCount,
                'default_limit' => $defaultLimit >= self::VIRTUAL_UNLIMITED ? null : $defaultLimit,
                'override_limit' => $overrideLimit,
                'limit' => $limit >= self::VIRTUAL_UNLIMITED ? null : $limit,
                'remaining_limit' => $remainingLimit,
                'sellable_remaining_count' => $remainingLimit === null ? $generatedRemainingCount : min($generatedRemainingCount, $remainingLimit),
                'limit_exceeds_supply' => $limit < self::VIRTUAL_UNLIMITED && $limit > $generatedCount,
                'updated_at' => $counter?->updated_at,
            ];
        }

        return $rows;
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @return array<int, array<string, mixed>>
     */
    private function withCentralPatternCeilings(array $rows, string $gameId, string $dimension, string $scopeType): array
    {
        if ($scopeType !== 'partner' || $rows === []) {
            return $rows;
        }

        $field = $dimension.'_limit';
        $centralDefaultLimit = $this->virtualLimits($gameId, 'central', 'central')[$field];
        $centralOverrides = $this->virtualLimitOverrideRows($gameId, 'central', 'central', $dimension);

        return array_map(function (array $row) use ($centralDefaultLimit, $centralOverrides): array {
            $number = (string) ($row['number'] ?? '');
            $centralLimit = $centralOverrides[$number]['limit'] ?? $centralDefaultLimit;

            return [
                ...$row,
                'central_limit' => $this->publicLimitValue($centralLimit),
            ];
        }, $rows);
    }

    /**
     * @return array<string, int>
     */
    private function virtualGeneratedCountsForDimension(string $gameId, string $dimension, string $scopeType, string $scopeId, ?object $profile): array
    {
        $profile ??= $this->activeVirtualStockProfile($gameId);
        if ($profile === null) {
            return [];
        }

        $layers = $this->virtualSupplyLayers($profile);
        $precomputedCounts = $this->precomputedVirtualGeneratedCountsForDimensions($gameId, $scopeType, $scopeId, $profile, $layers);
        if ($precomputedCounts !== null) {
            return is_array($precomputedCounts[$dimension] ?? null) ? $precomputedCounts[$dimension] : [];
        }

        $partnerRows = $scopeType === 'partner' ? $this->virtualAllocationRowsForCache($gameId) : [];
        $cacheKey = $this->virtualGeneratedCountsCacheKey($gameId, $scopeType, $scopeId, $profile, $layers, $partnerRows);
        $allCounts = Cache::remember(
            $cacheKey,
            now()->addMinutes(30),
            fn (): array => $this->computeVirtualGeneratedCountsForDimensions($gameId, $scopeType, $scopeId, $layers, $partnerRows),
        );

        return is_array($allCounts[$dimension] ?? null) ? $allCounts[$dimension] : [];
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @return array{back2: array<string, int>, back3: array<string, int>, front3: array<string, int>}|null
     */
    private function precomputedVirtualGeneratedCountsForDimensions(string $gameId, string $scopeType, string $scopeId, object $profile, array $layers): ?array
    {
        $sourceIds = array_values(array_filter(array_map(
            fn (array $layer): string => (string) ($layer['id'] ?? ''),
            $layers,
        )));

        if ($sourceIds === []) {
            return null;
        }

        if ($scopeType === 'partner') {
            $sourceIds = $this->virtualAssignedLayerIdsForPartner($gameId, $scopeId, $layers);

            if ($sourceIds === []) {
                return [
                    'back2' => [],
                    'back3' => [],
                    'front3' => [],
                ];
            }
        }

        $existingSourceIds = DB::table('virtual_stock_pattern_generated_counts')
            ->where('game_id', $gameId)
            ->where('profile_id', (string) $profile->id)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->whereIn('source_id', $sourceIds)
            ->distinct()
            ->pluck('source_id')
            ->map(fn (mixed $value): string => (string) $value)
            ->all();

        if (array_diff($sourceIds, $existingSourceIds) !== []) {
            return null;
        }

        $counts = [
            'back2' => [],
            'back3' => [],
            'front3' => [],
        ];

        $rows = DB::table('virtual_stock_pattern_generated_counts')
            ->select(['dimension', 'value'])
            ->selectRaw('SUM(generated_count)::bigint as generated_count')
            ->where('game_id', $gameId)
            ->where('profile_id', (string) $profile->id)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->whereIn('source_id', $sourceIds)
            ->groupBy('dimension', 'value')
            ->get();

        foreach ($rows as $row) {
            $dimension = (string) $row->dimension;
            if (! array_key_exists($dimension, $counts)) {
                continue;
            }

            $counts[$dimension][(string) $row->value] = (int) $row->generated_count;
        }

        return $counts;
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @param array<int, array{partner_id: string, bp: int}> $partnerRows
     * @return array{back2: array<string, int>, back3: array<string, int>, front3: array<string, int>}
     */
    private function computeVirtualGeneratedCountsForDimensions(string $gameId, string $scopeType, string $scopeId, array $layers, array $partnerRows): array
    {
        if ($scopeType === 'central' && $scopeId === 'central') {
            return $this->computeCentralVirtualGeneratedCountsForDimensions($layers);
        }

        $allocationRowsByLayer = $scopeType === 'partner' ? $this->virtualAllocationRowsByLayer($gameId, $layers) : [];
        $counts = [
            'back2' => [],
            'back3' => [],
            'front3' => [],
        ];

        DB::table('base_lottery_numbers')
            ->select(['full_number', 'back2', 'back3', 'front3'])
            ->orderBy('full_number')
            ->chunk(5000, function ($numbers) use (&$counts, $scopeType, $scopeId, $layers, $allocationRowsByLayer): void {
                foreach ($numbers as $row) {
                    $capacity = $this->virtualCapacityForNumberWithLayers((string) $row->full_number, $layers);

                    if ($scopeType === 'partner') {
                        $capacity = count($this->virtualPartnerCopyIndexesForLayers(
                            $scopeId,
                            (string) $row->full_number,
                            $layers,
                            $allocationRowsByLayer,
                        ));
                    }

                    $back2 = (string) $row->back2;
                    $back3 = (string) $row->back3;
                    $front3 = (string) $row->front3;
                    $counts['back2'][$back2] = ($counts['back2'][$back2] ?? 0) + $capacity;
                    $counts['back3'][$back3] = ($counts['back3'][$back3] ?? 0) + $capacity;
                    $counts['front3'][$front3] = ($counts['front3'][$front3] ?? 0) + $capacity;
                }
            });

        return $counts;
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @return array{back2: array<string, int>, back3: array<string, int>, front3: array<string, int>}
     */
    private function computeCentralVirtualGeneratedCountsForDimensions(array $layers): array
    {
        $counts = [
            'back2' => [],
            'back3' => [],
            'front3' => [],
        ];

        foreach ($layers as $layer) {
            $caseSql = $this->virtualCapacityCaseSql($layer['set_distribution']);
            $rows = DB::select(
                <<<SQL
                WITH scored AS (
                    SELECT
                        full_number,
                        back2,
                        back3,
                        front3,
                        {$caseSql} AS capacity
                    FROM (
                        SELECT
                            full_number,
                            back2,
                            back3,
                            front3,
                            ((('x' || substr(encode(sha256((? || ':' || full_number || ':set')::bytea), 'hex'), 1, 8))::bit(32)::bigint) % 10000) AS score
                        FROM base_lottery_numbers
                    ) base_scores
                )
                SELECT
                    dimension,
                    value,
                    SUM(capacity)::bigint AS generated_count
                FROM scored
                CROSS JOIN LATERAL (VALUES ('back2', back2), ('back3', back3), ('front3', front3)) AS pattern(dimension, value)
                GROUP BY dimension, value
                SQL,
                [(string) $layer['seed']],
            );

            foreach ($rows as $row) {
                $dimension = (string) $row->dimension;
                if (! array_key_exists($dimension, $counts)) {
                    continue;
                }

                $value = (string) $row->value;
                $counts[$dimension][$value] = ($counts[$dimension][$value] ?? 0) + (int) $row->generated_count;
            }
        }

        return $counts;
    }

    /**
     * @param array<int|string, mixed> $distribution
     */
    private function virtualCapacityCaseSql(array $distribution): string
    {
        $cursor = 0;
        $clauses = [];

        foreach ($distribution as $row) {
            if (! is_array($row)) {
                continue;
            }

            $basisPoints = max(0, (int) ($row['percent_basis_points'] ?? 0));
            if ($basisPoints < 1) {
                continue;
            }

            $cursor = min(self::VIRTUAL_MAX_BP, $cursor + $basisPoints);
            $setSize = max(1, (int) ($row['set_size'] ?? 1));
            $clauses[] = 'WHEN score < '.$cursor.' THEN '.$setSize;
        }

        return $clauses === [] ? '1' : 'CASE '.implode(' ', $clauses).' ELSE 1 END';
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @param array<int, array{partner_id: string, bp: int}> $partnerRows
     */
    private function virtualGeneratedCountsCacheKey(string $gameId, string $scopeType, string $scopeId, object $profile, array $layers, array $partnerRows): string
    {
        return 'central_stock:virtual_generated_counts:v3:'.sha1(json_encode([
            'game_id' => $gameId,
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'profile_id' => (string) $profile->id,
            'profile_updated_at' => (string) $profile->updated_at,
            'profile_total_capacity' => (int) $profile->total_capacity,
            'layers' => $layers,
            'partner_rows' => $partnerRows,
        ], JSON_THROW_ON_ERROR));
    }

    private function virtualProfileHasVariableCapacity(object $profile): bool
    {
        $distribution = json_decode((string) ($profile->set_distribution_json ?? '[]'), true);

        if (! is_array($distribution)) {
            return false;
        }

        foreach ($distribution as $row) {
            if (is_array($row) && (int) ($row['percent_basis_points'] ?? 0) > 0 && max(1, (int) ($row['set_size'] ?? 1)) !== 1) {
                return true;
            }
        }

        return false;
    }

    private function virtualPartnerBasisPoints(string $gameId, string $partnerId): int
    {
        $basisPoints = DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('partner_id', $partnerId)
            ->where('status', 'active')
            ->value('percent_basis_points');

        if ($basisPoints !== null) {
            return max(0, min(self::VIRTUAL_MAX_BP, (int) $basisPoints));
        }

        $hasDistribution = DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->where('percent_basis_points', '>', 0)
            ->exists();

        return $hasDistribution ? 0 : self::VIRTUAL_MAX_BP;
    }

    /**
     * @return array<string, mixed>
     */
    private function stockSettingsResource(): array
    {
        $distributionRow = DB::table('platform_system_settings')
            ->where('key', self::STOCK_SET_DISTRIBUTION_SETTING_KEY)
            ->first();
        $coverageRow = DB::table('platform_system_settings')
            ->where('key', self::STOCK_PATTERN_COVERAGE_SETTING_KEY)
            ->first();
        $distribution = $this->normalizeStockSetDistribution($this->decodeJsonValue($distributionRow?->value_json));
        $coverage = $this->normalizeStockPatternCoverage($this->decodeJsonValue($coverageRow?->value_json));

        if ($distributionRow === null) {
            $distribution = $this->defaultStockSetDistribution();
        }

        if ($coverageRow === null) {
            $coverage = $this->defaultStockPatternCoverage();
        }

        return [
            'id' => 'stock_settings',
            'tenant_id' => null,
            'status' => 'active',
            'created_at' => $distributionRow?->created_at ?? $coverageRow?->created_at,
            'updated_at' => max((string) ($distributionRow?->updated_at ?? ''), (string) ($coverageRow?->updated_at ?? '')) ?: null,
            'settings' => [
                self::STOCK_SET_DISTRIBUTION_SETTING_KEY => $distribution,
                self::STOCK_PATTERN_COVERAGE_SETTING_KEY => $coverage,
            ],
            self::STOCK_SET_DISTRIBUTION_SETTING_KEY => $distribution,
            self::STOCK_PATTERN_COVERAGE_SETTING_KEY => $coverage,
        ];
    }

    /**
     * @return array<int, array{set_size: int, percent: float|int}>
     */
    private function defaultStockSetDistribution(): array
    {
        return [
            ['set_size' => 2, 'percent' => 10],
            ['set_size' => 3, 'percent' => 15],
        ];
    }

    /**
     * @return array{central: array{back2_limit: int, back3_limit: int, front3_limit: int}, partner: array{back2_limit: int, back3_limit: int, front3_limit: int}}
     */
    private function defaultStockPatternCoverage(): array
    {
        return [
            'central' => ['back2_limit' => 500, 'back3_limit' => 300, 'front3_limit' => 200],
            'partner' => ['back2_limit' => 200, 'back3_limit' => 100, 'front3_limit' => 80],
        ];
    }

    /**
     * @return array{back2_limit: int, back3_limit: int, front3_limit: int}
     */
    private function defaultStockPatternCoverageForScope(string $scopeType): array
    {
        $coverage = $this->currentStockPatternCoverage();

        return $coverage[$scopeType === 'partner' ? 'partner' : 'central'];
    }

    /**
     * @return array{central: array{back2_limit: int, back3_limit: int, front3_limit: int}, partner: array{back2_limit: int, back3_limit: int, front3_limit: int}}
     */
    private function currentStockPatternCoverage(): array
    {
        $row = DB::table('platform_system_settings')
            ->where('key', self::STOCK_PATTERN_COVERAGE_SETTING_KEY)
            ->first();

        return $row === null
            ? $this->defaultStockPatternCoverage()
            : $this->normalizeStockPatternCoverage($this->decodeJsonValue($row->value_json));
    }

    /**
     * @param array{central: array{back2_limit: int, back3_limit: int, front3_limit: int}, partner: array{back2_limit: int, back3_limit: int, front3_limit: int}}|null $base
     * @return array{central: array{back2_limit: int, back3_limit: int, front3_limit: int}, partner: array{back2_limit: int, back3_limit: int, front3_limit: int}}
     */
    private function normalizeStockPatternCoverage(mixed $value, ?array $base = null): array
    {
        $coverage = $base ?? $this->defaultStockPatternCoverage();

        if (! is_array($value)) {
            return $coverage;
        }

        foreach (['central', 'partner'] as $scope) {
            if (! is_array($value[$scope] ?? null)) {
                continue;
            }

            foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
                if (array_key_exists($field, $value[$scope]) && $value[$scope][$field] !== null && $value[$scope][$field] !== '') {
                    $coverage[$scope][$field] = max(0, (int) $value[$scope][$field]);
                }
            }
        }

        return $coverage;
    }

    /**
     * @return array<int, array{set_size: int, percent: float|int}>
     */
    private function normalizeStockSetDistribution(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $rows = [];

        foreach ($value as $row) {
            if (! is_array($row)) {
                continue;
            }

            $setSize = max(1, min(99, (int) ($row['set_size'] ?? $row['size'] ?? 1)));
            $percent = $row['percent'] ?? null;

            if ($percent === null && isset($row['percent_basis_points'])) {
                $percent = ((float) $row['percent_basis_points']) / 100;
            }

            $rows[] = [
                'set_size' => $setSize,
                'percent' => max(0, min(100, (float) $percent)),
            ];
        }

        usort($rows, fn (array $left, array $right): int => $left['set_size'] <=> $right['set_size']);

        return array_values($rows);
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function stockSetDistributionErrors(mixed $value): array
    {
        if ($value === null || $value === '') {
            return [];
        }

        if (! is_array($value)) {
            return [self::STOCK_SET_DISTRIBUTION_SETTING_KEY => ['The set distribution default must be an array.']];
        }

        $errors = [];
        $totalPercent = 0.0;

        foreach ($value as $index => $row) {
            if (! is_array($row)) {
                $errors[self::STOCK_SET_DISTRIBUTION_SETTING_KEY.'.'.$index][] = 'Each set distribution row must be an object.';
                continue;
            }

            $setSize = $row['set_size'] ?? $row['size'] ?? null;
            $percent = $row['percent'] ?? (isset($row['percent_basis_points']) ? ((float) $row['percent_basis_points']) / 100 : null);

            if (! is_numeric($setSize) || (int) $setSize < 1 || (int) $setSize > 99) {
                $errors[self::STOCK_SET_DISTRIBUTION_SETTING_KEY.'.'.$index.'.set_size'][] = 'The set size must be between 1 and 99.';
            }

            if (! is_numeric($percent) || (float) $percent < 0 || (float) $percent > 100) {
                $errors[self::STOCK_SET_DISTRIBUTION_SETTING_KEY.'.'.$index.'.percent'][] = 'The percent must be between 0 and 100.';
                continue;
            }

            $totalPercent += (float) $percent;
        }

        if ($totalPercent > 100) {
            $errors[self::STOCK_SET_DISTRIBUTION_SETTING_KEY][] = 'The set distribution total percent may not exceed 100.';
        }

        return $errors;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function stockPatternCoverageErrors(mixed $value): array
    {
        if ($value === null || $value === '') {
            return [];
        }

        if (! is_array($value)) {
            return [self::STOCK_PATTERN_COVERAGE_SETTING_KEY => ['The stock pattern coverage default must be an object.']];
        }

        $errors = [];
        $current = $this->currentStockPatternCoverage();
        $resolved = $this->normalizeStockPatternCoverage($value, $current);

        foreach (['central', 'partner'] as $scope) {
            if (array_key_exists($scope, $value) && ! is_array($value[$scope])) {
                $errors[self::STOCK_PATTERN_COVERAGE_SETTING_KEY.'.'.$scope][] = 'The '.$scope.' coverage default must be an object.';
                continue;
            }

            foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
                if (! array_key_exists($field, $value[$scope] ?? [])) {
                    continue;
                }

                $raw = $value[$scope][$field];
                if ($raw === null || $raw === '' || filter_var($raw, FILTER_VALIDATE_INT) === false || (int) $raw < 0) {
                    $errors[self::STOCK_PATTERN_COVERAGE_SETTING_KEY.'.'.$scope.'.'.$field][] = 'The '.$field.' default must be zero or greater.';
                }
            }
        }

        foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
            if ($resolved['partner'][$field] > $resolved['central'][$field]) {
                $errors[self::STOCK_PATTERN_COVERAGE_SETTING_KEY.'.partner.'.$field][] = 'The partner '.$field.' default may not exceed the central default of '.$resolved['central'][$field].'.';
            }
        }

        return $errors;
    }

    private function decodeJsonValue(mixed $value): mixed
    {
        if (! is_string($value)) {
            return $value;
        }

        $decoded = json_decode($value, true);

        return json_last_error() === JSON_ERROR_NONE ? $decoded : $value;
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @return array<int, array<string, mixed>>
     */
    private function filterVirtualPatternRows(array $rows, mixed $keyword): array
    {
        $keyword = preg_replace('/\D+/', '', trim((string) ($keyword ?? ''))) ?? '';
        if ($keyword === '') {
            return $rows;
        }

        return array_values(array_filter(
            $rows,
            fn (array $row): bool => str_contains((string) $row['number'], $keyword),
        ));
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     */
    private function sortVirtualPatternRows(array &$rows, array $sort): void
    {
        usort($rows, function (array $left, array $right) use ($sort): int {
            $leftValue = $left[$sort['key']] ?? null;
            $rightValue = $right[$sort['key']] ?? null;
            $compare = $this->compareVirtualPatternValues($leftValue, $rightValue);

            if ($compare === 0) {
                $compare = strcmp((string) $left['number'], (string) $right['number']);
            }

            return $sort['direction'] === 'desc' ? -$compare : $compare;
        });
    }

    private function compareVirtualPatternValues(mixed $left, mixed $right): int
    {
        if ($left === null && $right === null) {
            return 0;
        }

        if ($left === null) {
            return 1;
        }

        if ($right === null) {
            return -1;
        }

        if (is_numeric($left) && is_numeric($right)) {
            return (float) $left <=> (float) $right;
        }

        return strcmp((string) $left, (string) $right);
    }

    /**
     * @return array{key: string, direction: string}
     */
    private function resolveVirtualPatternSort(array $queryParams): array
    {
        $key = trim((string) ($queryParams['sort_by'] ?? 'number'));
        $allowed = [
            'number',
            'generated_count',
            'reserved_count',
            'sold_count',
            'default_limit',
            'override_limit',
            'limit',
            'remaining_limit',
            'sellable_remaining_count',
        ];

        if (! in_array($key, $allowed, true)) {
            $key = 'number';
        }

        return [
            'key' => $key,
            'direction' => strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc',
        ];
    }

    private function virtualPatternCursor(string $dimension, array $queryParams, array $sort, int $offset): string
    {
        return base64_encode(json_encode([
            'dimension' => $dimension,
            'q' => preg_replace('/\D+/', '', trim((string) ($queryParams['q'] ?? ''))) ?? '',
            'sort_by' => $sort['key'],
            'sort_dir' => $sort['direction'],
            'offset' => $offset,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * @return array{offset: int}|null
     */
    private function decodeVirtualPatternCursor(mixed $cursor, string $dimension, array $queryParams, array $sort): ?array
    {
        if ($cursor === null || trim((string) $cursor) === '') {
            return null;
        }

        try {
            $decoded = json_decode((string) base64_decode((string) $cursor, true), true, flags: JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            return null;
        }

        $queryKeyword = preg_replace('/\D+/', '', trim((string) ($queryParams['q'] ?? ''))) ?? '';
        if (! is_array($decoded)
            || ($decoded['dimension'] ?? null) !== $dimension
            || ($decoded['q'] ?? '') !== $queryKeyword
            || ($decoded['sort_by'] ?? null) !== $sort['key']
            || ($decoded['sort_dir'] ?? null) !== $sort['direction']) {
            return null;
        }

        return ['offset' => max(0, (int) ($decoded['offset'] ?? 0))];
    }

    private function virtualPatternUsedTotal(string $gameId, string $dimension): int
    {
        $row = DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', 'central')
            ->where('scope_id', 'central')
            ->where('dimension', $dimension)
            ->select(DB::raw('SUM(reserved_count + sold_count) as used_count'))
            ->first();

        return $row === null ? 0 : (int) $row->used_count;
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @return array<string, int|null>
     */
    private function virtualPatternTotals(array $rows): array
    {
        $limitValues = array_values(array_filter(array_map(fn (array $row): ?int => $row['limit'] ?? null, $rows), fn (?int $value): bool => $value !== null));

        return [
            'pattern_count' => count($rows),
            'reserved_count' => array_sum(array_map(fn (array $row): int => (int) $row['reserved_count'], $rows)),
            'sold_count' => array_sum(array_map(fn (array $row): int => (int) $row['sold_count'], $rows)),
            'used_count' => array_sum(array_map(fn (array $row): int => (int) $row['used_count'], $rows)),
            'generated_count' => array_sum(array_map(fn (array $row): int => (int) ($row['generated_count'] ?? 0), $rows)),
            'generated_remaining_count' => array_sum(array_map(fn (array $row): int => (int) ($row['generated_remaining_count'] ?? 0), $rows)),
            'limit_total' => count($limitValues) === count($rows) ? array_sum($limitValues) : null,
            'remaining_limit' => count($limitValues) === count($rows) ? array_sum(array_map(fn (array $row): int => (int) ($row['remaining_limit'] ?? 0), $rows)) : null,
            'sellable_remaining_count' => array_sum(array_map(fn (array $row): int => (int) ($row['sellable_remaining_count'] ?? 0), $rows)),
            'limit_exceeds_supply_count' => count(array_filter($rows, fn (array $row): bool => (bool) ($row['limit_exceeds_supply'] ?? false))),
        ];
    }

    /**
     * @return array<string, array<string, int>>
     */
    private function emptyVirtualPatternTotals(): array
    {
        $empty = [
            'pattern_count' => 0,
            'reserved_count' => 0,
            'sold_count' => 0,
            'used_count' => 0,
            'generated_count' => 0,
            'generated_remaining_count' => 0,
            'limit_total' => 0,
            'remaining_limit' => 0,
            'sellable_remaining_count' => 0,
            'limit_exceeds_supply_count' => 0,
        ];

        return [
            'back2' => $empty,
            'front3' => $empty,
            'back3' => $empty,
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function listStockGroups(array $queryParams, int $limit): array
    {
        if ($this->activeVirtualStockProfile($this->nullableQueryString($queryParams['game_id'] ?? null)) !== null) {
            return $this->listVirtualStockGroups($queryParams, $limit);
        }

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

        if ($rows === []) {
            return $this->listVirtualStockGroups($queryParams, $limit);
        }

        return [
            'data' => array_map(fn (object $row): array => $this->stockGroupResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? $this->stockGroupCursor(end($rows), $sort) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function listVirtualStockGroups(array $queryParams, int $limit): array
    {
        $gameId = $this->nullableQueryString($queryParams['game_id'] ?? null);
        $profile = $this->activeVirtualStockProfile($gameId);
        $sort = $this->resolveVirtualStockGroupSort($this->resolveStockGroupSort($queryParams));

        if ($profile === null) {
            return ['data' => [], 'meta' => ['next_cursor' => null, 'has_more' => false]];
        }

        $scope = $this->virtualStockListScope($queryParams, $profile);

        if (($scope['valid'] ?? false) !== true) {
            return [
                'data' => [],
                'meta' => [
                    'next_cursor' => null,
                    'has_more' => false,
                    'sort_by' => $sort['key'],
                    'sort_dir' => $sort['direction'],
                    'scope_type' => $scope['scope_type'],
                    'scope_id' => $scope['scope_id'],
                ],
            ];
        }

        if ($sort['key'] === 'total_count') {
            return $this->listVirtualStockGroupsByCapacity($profile, $queryParams, $limit, $sort, $scope);
        }

        $numberQuery = DB::table('base_lottery_numbers')
            ->select([
                'base_lottery_numbers.full_number',
                'base_lottery_numbers.front3',
                'base_lottery_numbers.back3',
                'base_lottery_numbers.back2',
            ])
            ->limit($limit + 1);

        $this->applyVirtualStockGroupSortJoin($numberQuery, $profile, $sort, (string) $scope['scope_type'], (string) $scope['scope_id']);
        $this->applyVirtualNumberFilters($numberQuery, $queryParams);
        $this->applyVirtualStockGroupOrder($numberQuery, $sort);

        $cursor = $this->decodeStockGroupCursor($queryParams['cursor'] ?? null);
        $this->applyVirtualStockGroupCursor($numberQuery, $cursor, $sort);

        $numbers = $numberQuery->get()->all();
        if ($numbers === []) {
            if (DB::table('base_lottery_numbers')->exists()) {
                return [
                    'data' => [],
                    'meta' => [
                        'next_cursor' => null,
                        'has_more' => false,
                        'sort_by' => $sort['key'],
                        'sort_dir' => $sort['direction'],
                    ],
                ];
            }

            return $this->listVirtualStockProfileFallback($profile);
        }

        $hasMore = count($numbers) > $limit;
        $numbers = array_slice($numbers, 0, $limit);
        $counterMap = $this->virtualCounterMap((string) $profile->game_id, $numbers);
        $centralLimits = $this->virtualCentralLimits((string) $profile->game_id);
        $limitOverrides = $this->virtualLimitOverrideMapForNumbers((string) $profile->game_id, 'central', 'central', $numbers);
        $scopedCounterMap = $scope['scope_type'] === 'partner'
            ? $this->virtualCounterMap((string) $profile->game_id, $numbers, 'partner', (string) $scope['scope_id'])
            : null;
        $scopedLimits = $scope['scope_type'] === 'partner'
            ? $this->virtualLimits((string) $profile->game_id, 'partner', (string) $scope['scope_id'])
            : null;
        $scopedLimitOverrides = $scope['scope_type'] === 'partner'
            ? $this->virtualLimitOverrideMapForNumbers((string) $profile->game_id, 'partner', (string) $scope['scope_id'], $numbers)
            : null;
        $batchId = $this->latestVirtualBatchId((string) $profile->game_id);
        $rows = array_values(array_filter(
            array_map(
                fn (object $number): array => $this->virtualStockNumberGroupResource(
                    $profile,
                    $number,
                    $counterMap,
                    $centralLimits,
                    $limitOverrides,
                    $batchId,
                    (string) $scope['scope_type'],
                    (string) $scope['scope_id'],
                    $scopedCounterMap,
                    $scopedLimits,
                    $scopedLimitOverrides,
                    $scope['tenant_id'],
                ),
                $numbers,
            ),
            fn (array $row): bool => $this->virtualStockGroupVisibleForScope($row) && $this->virtualStockGroupMatchesStatus($row, $queryParams),
        ));

        return [
            'data' => $rows,
            'meta' => [
                'next_cursor' => $hasMore && $numbers !== [] ? $this->stockGroupCursor((object) array_merge((array) end($numbers), [
                    'game_id' => (string) $profile->game_id,
                ]), $sort) : null,
                'has_more' => $hasMore,
                'sort_by' => $sort['key'],
                'sort_dir' => $sort['direction'],
                'scope_type' => $scope['scope_type'],
                'scope_id' => $scope['scope_id'],
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function virtualStockGroupVisibleForScope(array $row): bool
    {
        return ($row['scope_type'] ?? 'central') !== 'partner' || (int) ($row['total_count'] ?? 0) > 0;
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{valid: bool, scope_type: string, scope_id: string, tenant_id: ?string}
     */
    private function virtualStockListScope(array $queryParams, object $profile): array
    {
        $gameId = (string) $profile->game_id;
        $allocationId = $this->nullableQueryString($queryParams['allocation_id'] ?? null);
        $tenantId = $this->nullableQueryString($queryParams['tenant_id'] ?? null);

        if ($allocationId !== null) {
            $allocation = PartnerStockAllocation::query()
                ->where('id', $allocationId)
                ->first(['game_id', 'partner_id', 'tenant_id']);

            if ($allocation === null || (string) $allocation->game_id !== $gameId) {
                return ['valid' => false, 'scope_type' => 'partner', 'scope_id' => '', 'tenant_id' => $tenantId];
            }

            return $this->validatedVirtualPartnerScope(
                $gameId,
                (string) $allocation->partner_id,
                (string) $allocation->tenant_id,
            );
        }

        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($queryParams);

        if ($scopeType === 'partner') {
            return $this->validatedVirtualPartnerScope($gameId, $scopeId, $tenantId);
        }

        if ($tenantId !== null) {
            $distribution = DB::table('stock_partner_distributions')
                ->where('game_id', $gameId)
                ->where('tenant_id', $tenantId)
                ->where('status', 'active')
                ->where('percent_basis_points', '>', 0)
                ->first(['partner_id', 'tenant_id']);

            return $distribution === null
                ? ['valid' => false, 'scope_type' => 'partner', 'scope_id' => '', 'tenant_id' => $tenantId]
                : [
                    'valid' => true,
                    'scope_type' => 'partner',
                    'scope_id' => (string) $distribution->partner_id,
                    'tenant_id' => $distribution->tenant_id === null ? $tenantId : (string) $distribution->tenant_id,
                ];
        }

        return ['valid' => true, 'scope_type' => 'central', 'scope_id' => 'central', 'tenant_id' => null];
    }

    /**
     * @return array{valid: bool, scope_type: string, scope_id: string, tenant_id: ?string}
     */
    private function validatedVirtualPartnerScope(string $gameId, string $partnerId, ?string $tenantId): array
    {
        if ($partnerId === '') {
            return ['valid' => false, 'scope_type' => 'partner', 'scope_id' => '', 'tenant_id' => $tenantId];
        }

        $query = DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('partner_id', $partnerId)
            ->where('status', 'active')
            ->where('percent_basis_points', '>', 0);

        if ($tenantId !== null) {
            $query->where('tenant_id', $tenantId);
        }

        $distribution = $query->first(['partner_id', 'tenant_id']);

        return $distribution === null
            ? ['valid' => false, 'scope_type' => 'partner', 'scope_id' => $partnerId, 'tenant_id' => $tenantId]
            : [
                'valid' => true,
                'scope_type' => 'partner',
                'scope_id' => (string) $distribution->partner_id,
                'tenant_id' => $distribution->tenant_id === null ? $tenantId : (string) $distribution->tenant_id,
            ];
    }

    private function activeVirtualStockProfile(?string $gameId): ?object
    {
        $query = DB::table('stock_supply_profiles')
            ->where('status', 'active')
            ->orderByDesc('updated_at')
            ->orderByDesc('id');

        if ($gameId !== null) {
            $query->where('game_id', $gameId);
        }

        return $query->first();
    }

    /**
     * @param mixed $query
     * @param array<string, mixed> $queryParams
     */
    private function applyVirtualNumberFilters(mixed $query, array $queryParams): void
    {
        $number = preg_replace('/\D+/', '', (string) ($queryParams['number'] ?? $queryParams['full_number'] ?? '')) ?? '';
        if ($number !== '') {
            if (strlen($number) >= 6) {
                $query->where('full_number', substr($number, 0, 6));
            } else {
                $query->where('full_number', 'like', '%'.$number.'%');
            }
        }

        foreach (['front3', 'back3', 'back2'] as $filter) {
            $value = preg_replace('/\D+/', '', (string) ($queryParams[$filter] ?? '')) ?? '';
            if ($value !== '') {
                $query->where($filter, substr($value, 0, $filter === 'back2' ? 2 : 3));
            }
        }
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function listVirtualStockProfileFallback(object $profile): array
    {
        $counterTotals = $this->virtualCounterTotals([(string) $profile->game_id]);

        return [
            'data' => [
                $this->virtualStockGroupResource(
                    $profile,
                    $counterTotals[(string) $profile->game_id] ?? ['reserved' => 0, 'sold' => 0],
                    $this->latestVirtualBatchId((string) $profile->game_id),
                ),
            ],
            'meta' => [
                'next_cursor' => null,
                'has_more' => false,
                'base_lottery_seeded' => false,
            ],
        ];
    }

    /**
     * @param array{key: string, direction: string, expression: string, bindings: array<int, mixed>, needs_counter: bool} $sort
     * @param array{valid: bool, scope_type: string, scope_id: string, tenant_id: ?string} $scope
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function listVirtualStockGroupsByCapacity(object $profile, array $queryParams, int $limit, array $sort, array $scope): array
    {
        $numberQuery = DB::table('base_lottery_numbers')
            ->select([
                'base_lottery_numbers.full_number',
                'base_lottery_numbers.front3',
                'base_lottery_numbers.back3',
                'base_lottery_numbers.back2',
            ]);

        $this->applyVirtualNumberFilters($numberQuery, $queryParams);

        $layers = $this->virtualSupplyLayers($profile);
        $cursor = $this->decodeStockGroupCursor($queryParams['cursor'] ?? null);
        $status = $this->nullableQueryString($queryParams['status'] ?? null);
        $centralLimits = $status === null ? [] : $this->virtualCentralLimits((string) $profile->game_id);
        $batchId = $status === null ? null : $this->latestVirtualBatchId((string) $profile->game_id);
        $pageNumbers = [];

        if (! (clone $numberQuery)->exists()) {
            return $this->listVirtualStockProfileFallback($profile);
        }

        foreach ($this->virtualPossibleCapacityTotals($layers, $sort['direction']) as $targetCapacity) {
            $cursorNumber = null;
            if ($cursor !== null && ($cursor['sort_by'] ?? null) === $sort['key'] && ($cursor['sort_dir'] ?? null) === $sort['direction']) {
                $cursorValue = (int) ($cursor['value'] ?? 0);
                if ($sort['direction'] === 'desc' && $targetCapacity > $cursorValue) {
                    continue;
                }
                if ($sort['direction'] === 'asc' && $targetCapacity < $cursorValue) {
                    continue;
                }
                if ($targetCapacity === $cursorValue) {
                    $cursorNumber = (string) ($cursor['full_number'] ?? '');
                }
            }

            $targetQuery = clone $numberQuery;
            if ($cursorNumber !== null && $cursorNumber !== '') {
                $targetQuery->where('base_lottery_numbers.full_number', '>', $cursorNumber);
            }

            $targetQuery
                ->orderBy('base_lottery_numbers.full_number')
                ->chunk(5000, function ($chunk) use (&$pageNumbers, $profile, $layers, $targetCapacity, $queryParams, $status, $centralLimits, $batchId, $limit, $scope): bool {
                    $numbers = [];

                    foreach ($chunk as $number) {
                        $capacity = $this->virtualCapacityForNumberWithLayers((string) $number->full_number, $layers);
                        if ($capacity !== $targetCapacity) {
                            continue;
                        }

                        $number->game_id = (string) $profile->game_id;
                        $number->total_count = $capacity;
                        $numbers[] = $number;
                    }

                    if ($status !== null && $numbers !== []) {
                        $counterMap = $this->virtualCounterMap((string) $profile->game_id, $numbers);
                        $limitOverrides = $this->virtualLimitOverrideMapForNumbers((string) $profile->game_id, 'central', 'central', $numbers);
                        $scopedCounterMap = $scope['scope_type'] === 'partner'
                            ? $this->virtualCounterMap((string) $profile->game_id, $numbers, 'partner', (string) $scope['scope_id'])
                            : null;
                        $scopedLimits = $scope['scope_type'] === 'partner'
                            ? $this->virtualLimits((string) $profile->game_id, 'partner', (string) $scope['scope_id'])
                            : null;
                        $scopedLimitOverrides = $scope['scope_type'] === 'partner'
                            ? $this->virtualLimitOverrideMapForNumbers((string) $profile->game_id, 'partner', (string) $scope['scope_id'], $numbers)
                            : null;
                        $numbers = array_values(array_filter(
                            $numbers,
                            function (object $number) use ($profile, $counterMap, $centralLimits, $limitOverrides, $batchId, $scope, $scopedCounterMap, $scopedLimits, $scopedLimitOverrides, $queryParams): bool {
                                $row = $this->virtualStockNumberGroupResource(
                                    $profile,
                                    $number,
                                    $counterMap,
                                    $centralLimits,
                                    $limitOverrides,
                                    $batchId,
                                    (string) $scope['scope_type'],
                                    (string) $scope['scope_id'],
                                    $scopedCounterMap,
                                    $scopedLimits,
                                    $scopedLimitOverrides,
                                    $scope['tenant_id'],
                                );

                                return $this->virtualStockGroupVisibleForScope($row) && $this->virtualStockGroupMatchesStatus($row, $queryParams);
                            },
                        ));
                    }

                    array_push($pageNumbers, ...$numbers);

                    return count($pageNumbers) < $limit + 1;
                });

            if (count($pageNumbers) >= $limit + 1) {
                break;
            }
        }

        $hasMore = count($pageNumbers) > $limit;
        $pageNumbers = array_slice($pageNumbers, 0, $limit);

        if ($pageNumbers === []) {
            return [
                'data' => [],
                'meta' => [
                    'next_cursor' => null,
                    'has_more' => false,
                    'sort_by' => $sort['key'],
                    'sort_dir' => $sort['direction'],
                ],
            ];
        }

        $counterMap = $this->virtualCounterMap((string) $profile->game_id, $pageNumbers);
        $centralLimits = $this->virtualCentralLimits((string) $profile->game_id);
        $limitOverrides = $this->virtualLimitOverrideMapForNumbers((string) $profile->game_id, 'central', 'central', $pageNumbers);
        $scopedCounterMap = $scope['scope_type'] === 'partner'
            ? $this->virtualCounterMap((string) $profile->game_id, $pageNumbers, 'partner', (string) $scope['scope_id'])
            : null;
        $scopedLimits = $scope['scope_type'] === 'partner'
            ? $this->virtualLimits((string) $profile->game_id, 'partner', (string) $scope['scope_id'])
            : null;
        $scopedLimitOverrides = $scope['scope_type'] === 'partner'
            ? $this->virtualLimitOverrideMapForNumbers((string) $profile->game_id, 'partner', (string) $scope['scope_id'], $pageNumbers)
            : null;
        $batchId = $this->latestVirtualBatchId((string) $profile->game_id);

        return [
            'data' => array_values(array_filter(array_map(
                fn (object $number): array => $this->virtualStockNumberGroupResource(
                    $profile,
                    $number,
                    $counterMap,
                    $centralLimits,
                    $limitOverrides,
                    $batchId,
                    (string) $scope['scope_type'],
                    (string) $scope['scope_id'],
                    $scopedCounterMap,
                    $scopedLimits,
                    $scopedLimitOverrides,
                    $scope['tenant_id'],
                ),
                $pageNumbers,
            ), fn (array $row): bool => $this->virtualStockGroupVisibleForScope($row))),
            'meta' => [
                'next_cursor' => $hasMore ? $this->stockGroupCursor(end($pageNumbers), $sort) : null,
                'has_more' => $hasMore,
                'sort_by' => $sort['key'],
                'sort_dir' => $sort['direction'],
                'scope_type' => $scope['scope_type'],
                'scope_id' => $scope['scope_id'],
            ],
        ];
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @return array<int, int>
     */
    private function virtualPossibleCapacityTotals(array $layers, string $direction): array
    {
        $totals = [0];

        foreach ($layers as $layer) {
            $nextTotals = [];
            foreach ($totals as $total) {
                foreach ($this->virtualLayerCapacityValues($layer['set_distribution']) as $capacity) {
                    $nextTotals[] = $total + $capacity;
                }
            }

            $totals = array_values(array_unique($nextTotals));
        }

        sort($totals, SORT_NUMERIC);
        if ($direction === 'desc') {
            $totals = array_reverse($totals);
        }

        return $totals;
    }

    /**
     * @param array<int|string, mixed> $distribution
     * @return array<int, int>
     */
    private function virtualLayerCapacityValues(array $distribution): array
    {
        $values = [1];

        foreach ($distribution as $row) {
            if (! is_array($row) || (int) ($row['percent_basis_points'] ?? 0) <= 0) {
                continue;
            }

            $values[] = max(1, (int) ($row['set_size'] ?? 1));
        }

        sort($values, SORT_NUMERIC);

        return array_values(array_unique($values));
    }

    /**
     * @param array<int, object> $numbers
     * @param array<string, mixed>|null $cursor
     * @param array{key: string, direction: string, expression: string, bindings: array<int, mixed>, needs_counter: bool} $sort
     * @return array<int, object>
     */
    private function filterVirtualCapacityRowsAfterCursor(array $numbers, ?array $cursor, array $sort): array
    {
        if ($cursor === null
            || ($cursor['sort_by'] ?? null) !== $sort['key']
            || ($cursor['sort_dir'] ?? null) !== $sort['direction']
            || ! array_key_exists('value', $cursor)
            || ($cursor['full_number'] ?? '') === '') {
            return $numbers;
        }

        $cursorValue = (int) $cursor['value'];
        $cursorNumber = (string) $cursor['full_number'];

        return array_values(array_filter($numbers, function (object $number) use ($cursorValue, $cursorNumber, $sort): bool {
            $value = (int) $number->total_count;

            if ($sort['direction'] === 'desc') {
                return $value < $cursorValue || ($value === $cursorValue && strcmp((string) $number->full_number, $cursorNumber) > 0);
            }

            return $value > $cursorValue || ($value === $cursorValue && strcmp((string) $number->full_number, $cursorNumber) > 0);
        }));
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

        $key = match ($key) {
            'tickets' => 'total_count',
            'updated_at' => 'last_updated_at',
            default => $key,
        };

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

    /**
     * @return array{key: string, column: string, direction: string}
     */
    private function resolveGenerationBatchSort(array $queryParams): array
    {
        $key = trim((string) ($queryParams['sort_by'] ?? 'created_at'));
        $allowed = [
            'id' => 'id',
            'game_id' => 'game_id',
            'status' => 'status',
            'type' => 'type',
            'requested_count' => 'requested_count',
            'generated_count' => 'generated_count',
            'created_at' => 'created_at',
            'updated_at' => 'updated_at',
            'completed_at' => 'completed_at',
        ];

        if (! isset($allowed[$key])) {
            $key = 'created_at';
        }

        return [
            'key' => $key,
            'column' => $allowed[$key],
            'direction' => strtolower((string) ($queryParams['sort_dir'] ?? 'desc')) === 'asc' ? 'asc' : 'desc',
        ];
    }

    private function applyGenerationBatchOrder(mixed $query, array $sort): void
    {
        $query->orderBy($sort['column'], $sort['direction']);

        if ($sort['column'] !== 'id') {
            $query->orderBy('id');
        }
    }

    private function applyGenerationBatchCursor(mixed $query, mixed $rawCursor, array $sort): void
    {
        $cursor = $this->decodeGenerationBatchCursor($rawCursor, $sort);
        if ($cursor === null) {
            return;
        }

        if ($sort['column'] === 'id') {
            $query->where('id', $sort['direction'] === 'desc' ? '<' : '>', $cursor['id']);
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

    private function generationBatchCursor(object $batch, array $sort): string
    {
        return base64_encode(json_encode([
            'sort_by' => $sort['key'],
            'sort_dir' => $sort['direction'],
            'value' => $batch->{$sort['column']} ?? null,
            'id' => (string) $batch->id,
        ], JSON_THROW_ON_ERROR));
    }

    /**
     * @return array{value: mixed, id: string}|null
     */
    private function decodeGenerationBatchCursor(mixed $cursor, array $sort): ?array
    {
        if ($cursor === null || trim((string) $cursor) === '') {
            return null;
        }

        try {
            $decoded = json_decode((string) base64_decode((string) $cursor, true), true, flags: JSON_THROW_ON_ERROR);
        } catch (\Throwable) {
            return $sort['column'] === 'id' ? [
                'value' => (string) $cursor,
                'id' => (string) $cursor,
            ] : null;
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
     * @param array{key: string, order: string, expression: string, direction: string}|null $sort
     * @return array{key: string, direction: string, expression: string, bindings: array<int, mixed>, needs_counter: bool}
     */
    private function resolveVirtualStockGroupSort(?array $sort): array
    {
        $direction = $sort['direction'] ?? 'asc';
        $key = $sort['key'] ?? 'full_number';

        return match ($key) {
            'allocated_count' => [
                'key' => 'allocated_count',
                'direction' => $direction,
                'expression' => 'COALESCE(full_counter.reserved_count, 0)',
                'bindings' => [],
                'needs_counter' => true,
            ],
            'sold_count' => [
                'key' => 'sold_count',
                'direction' => $direction,
                'expression' => 'COALESCE(full_counter.sold_count, 0)',
                'bindings' => [],
                'needs_counter' => true,
            ],
            'total_count' => [
                'key' => 'total_count',
                'direction' => $direction,
                'expression' => 'base_lottery_numbers.full_number',
                'bindings' => [],
                'needs_counter' => false,
            ],
            'last_updated_at' => [
                'key' => 'last_updated_at',
                'direction' => $direction,
                'expression' => 'COALESCE(full_counter.updated_at, ?::timestamp)',
                'bindings' => [],
                'needs_counter' => true,
            ],
            default => [
                'key' => 'full_number',
                'direction' => $direction,
                'expression' => 'base_lottery_numbers.full_number',
                'bindings' => [],
                'needs_counter' => false,
            ],
        };
    }

    /**
     * @param array{key: string, direction: string, expression: string, bindings: array<int, mixed>, needs_counter: bool} $sort
     */
    private function applyVirtualStockGroupSortJoin(mixed $query, object $profile, array &$sort, string $scopeType = 'central', string $scopeId = 'central'): void
    {
        if (! $sort['needs_counter']) {
            return;
        }

        $query->leftJoin('virtual_stock_counters as full_counter', function ($join) use ($profile, $scopeType, $scopeId): void {
            $join
                ->on('full_counter.value', '=', 'base_lottery_numbers.full_number')
                ->where('full_counter.game_id', '=', (string) $profile->game_id)
                ->where('full_counter.scope_type', '=', $scopeType)
                ->where('full_counter.scope_id', '=', $scopeId)
                ->where('full_counter.dimension', '=', 'full_number');
        });

        $query
            ->selectRaw('COALESCE(full_counter.reserved_count, 0) as allocated_count')
            ->selectRaw('COALESCE(full_counter.sold_count, 0) as sold_count')
            ->selectRaw('COALESCE(full_counter.updated_at, ?::timestamp) as last_updated_at', [(string) $profile->updated_at]);

        if ($sort['key'] === 'last_updated_at') {
            $sort['bindings'] = [(string) $profile->updated_at];
        }
    }

    /**
     * @param array{key: string, direction: string, expression: string, bindings: array<int, mixed>, needs_counter: bool} $sort
     */
    private function applyVirtualStockGroupOrder(mixed $query, array $sort): void
    {
        $query->orderByRaw($sort['expression'].' '.$sort['direction'], $sort['bindings']);

        if ($sort['key'] !== 'full_number') {
            $query->orderBy('base_lottery_numbers.full_number');
        }
    }

    /**
     * @param array<string, mixed>|null $cursor
     * @param array{key: string, direction: string, expression: string, bindings: array<int, mixed>, needs_counter: bool} $sort
     */
    private function applyVirtualStockGroupCursor(mixed $query, ?array $cursor, array $sort): void
    {
        if ($cursor === null
            || ($cursor['sort_by'] ?? null) !== $sort['key']
            || ($cursor['sort_dir'] ?? null) !== $sort['direction']
            || ($cursor['full_number'] ?? '') === '') {
            return;
        }

        if ($sort['key'] === 'full_number') {
            $operator = $sort['direction'] === 'desc' ? '<' : '>';
            $query->where('base_lottery_numbers.full_number', $operator, (string) $cursor['full_number']);

            return;
        }

        if (! array_key_exists('value', $cursor)) {
            return;
        }

        $operator = $sort['direction'] === 'desc' ? '<' : '>';
        $bindings = [...$sort['bindings'], $cursor['value'], ...$sort['bindings'], $cursor['value'], (string) $cursor['full_number']];

        $query->whereRaw(
            $sort['expression'].' '.$operator.' ? OR ('.$sort['expression'].' = ? AND base_lottery_numbers.full_number > ?)',
            $bindings,
        );
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
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>|null
     */
    public function findStockNumberDetail(string $gameId, string $fullNumber, array $queryParams = []): ?array
    {
        $gameId = trim($gameId);
        $fullNumber = preg_replace('/\D+/', '', $fullNumber) ?? '';

        if ($gameId === '' || $fullNumber === '') {
            return null;
        }

        $profile = $this->activeVirtualStockProfile($gameId);
        if ($profile !== null) {
            $baseNumber = DB::table('base_lottery_numbers')
                ->where('full_number', $fullNumber)
                ->first(['full_number', 'front3', 'back3', 'back2']);

            if ($baseNumber !== null) {
                return $this->virtualStockNumberDetailResource($profile, $baseNumber, $queryParams);
            }
        }

        if (! StockItem::query()->where('game_id', $gameId)->where('full_number', $fullNumber)->exists()
            && ! DB::table('local_stock_items')->where('game_id', $gameId)->where('full_number', $fullNumber)->exists()) {
            return null;
        }

        return $this->materializedStockNumberDetailResource($gameId, $fullNumber, $queryParams);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateGeneratePayload(array $payload): array
    {
        if ($this->virtualStock->isGeneratePayload($payload)) {
            return $this->virtualStock->validateGeneratePayload($payload);
        }

        $errors = $this->validateOpenGamePayload($payload);
        $errors['generation_mode'][] = 'The generation_mode field must be virtual_profile.';
        $retiredFields = [
            'total_count',
            'back2_count_per_number',
            'back3_count_per_number',
            'front3_count_per_number',
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

        foreach ($retiredFields as $field) {
            if (array_key_exists($field, $payload) && $payload[$field] !== null && $payload[$field] !== '') {
                $errors[$field][] = 'This field is retired for stock generation. Use generation_mode=virtual_profile and set_distribution.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function generateStock(array $payload, AdminSessionContext $actor, Request $request): array
    {
        if ($this->virtualStock->isGeneratePayload($payload)) {
            return $this->virtualStock->generateProfile($payload, $actor, $request);
        }

        return ['error' => 'resource_conflict'];

        $result = DB::transaction(function () use ($payload, $actor, $request): array {
            $normalized = $this->normalizedGeneratePayload($payload, (string) $request->header('Idempotency-Key'));
            $batch = $this->ensureStockBatch('generate', $normalized, $actor, $request);

            if (($batch['error'] ?? null) === 'idempotency_conflict') {
                return ['error' => 'idempotency_conflict'];
            }

            if (! $batch['created']) {
                return $this->batchResourceById($batch['id']);
            }

            if ($normalized['requested_count'] > self::GENERATE_SYNC_THRESHOLD) {
                $chunkIds = $this->createGenerationChunks($batch['id'], $normalized);

                return [
                    'batch' => $this->batchResourceById($batch['id']),
                    'chunk_ids' => $chunkIds,
                ];
            }

            $this->generateSynchronousStockBatch($batch['id'], $normalized, $payload, $actor, $request);

            return ['batch' => $this->batchResourceById($batch['id']), 'chunk_ids' => []];
        });

        if (($result['error'] ?? null) === 'idempotency_conflict') {
            return $result;
        }

        if (! array_key_exists('batch', $result)) {
            return $result;
        }

        $batchId = (string) $result['batch']['id'];
        $this->broadcastGenerationProgress(
            $batchId,
            ($result['batch']['status'] ?? null) === 'completed'
                ? 'stock_generation.batch.completed'
                : 'stock_generation.batch.queued',
        );

        foreach ($result['chunk_ids'] ?? [] as $chunkId) {
            GenerateStockBatchChunkJob::dispatch((string) $chunkId);
        }

        return $result['batch'];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizedGeneratePayload(array $payload, string $idempotencyKey): array
    {
        $gameId = trim((string) $payload['game_id']);
        $quota = $this->normalizedGenerateQuotaCounts($payload);
        $back2Count = $quota['back2_count_per_number'];
        $back3Count = $quota['back3_count_per_number'];
        $front3Count = $quota['front3_count_per_number'];
        $chunkRounds = min($back3Count, $this->asyncChunkRounds());

        return [
            'game_id' => $gameId,
            'requested_count' => $quota['total_count'],
            'range_start' => '000000',
            'range_end' => '999999',
            'number_digits' => self::GENERATE_NUMBER_DIGITS,
            'generation_mode' => 'quota_random',
            'generation_input_mode' => $quota['input_mode'],
            'total_count' => $quota['total_count'],
            'total_rounds' => $back3Count,
            'processed_rounds' => 0,
            'chunk_rounds' => $chunkRounds,
            'back2_count_per_number' => $back2Count,
            'back3_count_per_number' => $back3Count,
            'front3_count_per_number' => $front3Count,
            'seed' => $idempotencyKey,
            'generation_config' => [
                'base_count' => self::GENERATE_BASE_COUNT,
                'stock_id_seed' => 'batch_id:global_index:number',
            ],
        ];
    }

    /**
     * @param array<string, mixed> $normalized
     * @param array<string, mixed> $originalPayload
     */
    private function generateSynchronousStockBatch(
        string $batchId,
        array $normalized,
        array $originalPayload,
        AdminSessionContext $actor,
        Request $request,
    ): void {
        [$rows, $stockIds] = $this->stockRowsForRounds(
            $normalized,
            $batchId,
            0,
            (int) $normalized['total_rounds'],
            now(),
        );

        if ($rows !== []) {
            $this->insertStockRows($rows);
            $this->dispatchCentralImageJobs(array_values($stockIds));
        }

        $generatedCount = StockItem::where('batch_id', $batchId)->count();
        $now = now();

        StockGenerationBatch::query()->where('id', $batchId)->update([
            'status' => 'completed',
            'generated_count' => $generatedCount,
            'processed_rounds' => (int) $normalized['total_rounds'],
            'started_at' => $now,
            'completed_at' => $now,
            'updated_at' => $now,
        ]);

        $this->auditStockChange($actor, $request, $batchId, 'stock.generated', $originalPayload);
    }

    /**
     * @param array<string, mixed> $normalized
     * @return array<int, string>
     */
    private function createGenerationChunks(string $batchId, array $normalized): array
    {
        $chunkRoundCount = (int) $normalized['chunk_rounds'];
        $totalRounds = (int) $normalized['total_rounds'];
        $now = now();
        $rows = [];
        $chunkIds = [];
        $chunkIndex = 0;

        for ($startRound = 0; $startRound < $totalRounds; $startRound += $chunkRoundCount) {
            $roundCount = min($chunkRoundCount, $totalRounds - $startRound);
            $chunkId = $this->stableId('sgc', $batchId.':'.$chunkIndex.':'.$startRound.':'.$roundCount);
            $chunkIds[] = $chunkId;
            $rows[] = [
                'id' => $chunkId,
                'batch_id' => $batchId,
                'chunk_index' => $chunkIndex,
                'start_round' => $startRound,
                'round_count' => $roundCount,
                'status' => 'queued',
                'attempt_count' => 0,
                'started_at' => null,
                'completed_at' => null,
                'failed_at' => null,
                'failure_reason' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ];
            $chunkIndex++;
        }

        if ($rows !== []) {
            StockGenerationBatchChunk::query()->insert($rows);
        }

        return $chunkIds;
    }

    public function processGenerationChunk(string $chunkId): void
    {
        try {
            $progress = DB::transaction(function () use ($chunkId): ?array {
                $chunk = StockGenerationBatchChunk::query()->whereKey($chunkId)->lockForUpdate()->first();

                if ($chunk === null || $chunk->status === 'completed') {
                    return null;
                }

                $batch = StockGenerationBatch::query()->whereKey($chunk->batch_id)->lockForUpdate()->first();

                if ($batch === null || in_array((string) $batch->status, ['completed', 'failed', 'cancelled'], true)) {
                    return null;
                }

                $now = now();
                $normalized = $this->decodeJsonObject($batch->payload_json);
                $wasQueued = (string) $batch->status === 'queued' && $batch->started_at === null;
                [$rows] = $this->stockRowsForRounds(
                    $normalized,
                    (string) $batch->id,
                    (int) $chunk->start_round,
                    (int) $chunk->round_count,
                    $now,
                );

                StockGenerationBatchChunk::query()->whereKey($chunk->id)->update([
                    'status' => 'processing',
                    'attempt_count' => (int) $chunk->attempt_count + 1,
                    'started_at' => $chunk->started_at ?? $now,
                    'failed_at' => null,
                    'failure_reason' => null,
                    'updated_at' => $now,
                ]);

                StockGenerationBatch::query()->whereKey($batch->id)->update([
                    'status' => 'processing',
                    'started_at' => $batch->started_at ?? $now,
                    'failed_at' => null,
                    'failure_reason' => null,
                    'updated_at' => $now,
                ]);

                if ($rows !== []) {
                    $this->insertStockRows($rows);
                }

                $processedRounds = min((int) $batch->total_rounds, (int) $batch->processed_rounds + (int) $chunk->round_count);
                $generatedCount = (int) StockItem::query()->where('batch_id', $batch->id)->count();
                $batchUpdates = [
                    'generated_count' => $generatedCount,
                    'processed_rounds' => $processedRounds,
                    'updated_at' => $now,
                ];
                $isComplete = $processedRounds >= (int) $batch->total_rounds;

                if ($isComplete) {
                    $batchUpdates['status'] = 'completed';
                    $batchUpdates['completed_at'] = $now;
                }

                StockGenerationBatchChunk::query()->whereKey($chunk->id)->update([
                    'status' => 'completed',
                    'completed_at' => $now,
                    'updated_at' => $now,
                ]);

                StockGenerationBatch::query()->whereKey($batch->id)->update($batchUpdates);

                return [
                    'batch_id' => (string) $batch->id,
                    'started' => $wasQueued,
                    'completed' => $isComplete,
                ];
            });
        } catch (Throwable $exception) {
            $failedBatchId = $this->markGenerationChunkFailed($chunkId, $exception);

            if ($failedBatchId !== null) {
                $this->broadcastGenerationProgress($failedBatchId, 'stock_generation.batch.failed');
            }

            return;
        }

        if ($progress === null) {
            return;
        }

        if ($progress['started']) {
            $this->broadcastGenerationProgress($progress['batch_id'], 'stock_generation.batch.processing');
        }

        $this->broadcastGenerationProgress($progress['batch_id'], 'stock_generation.chunk.completed');

        if ($progress['completed']) {
            $this->auditCompletedGenerationBatch($progress['batch_id']);
            DispatchStockBatchImageJobs::dispatch($progress['batch_id']);
            $this->broadcastGenerationProgress($progress['batch_id'], 'stock_generation.batch.completed');
        }
    }

    /**
     * @param array<string, mixed> $normalized
     * @return array{0: array<int, array<string, mixed>>, 1: array<int, string>}
     */
    private function stockRowsForRounds(array $normalized, string $batchId, int $startRound, int $roundCount, mixed $now): array
    {
        $gameId = (string) $normalized['game_id'];
        $seed = (string) ($normalized['seed'] ?? '');
        $rows = [];
        $stockIds = [];

        for ($round = $startRound; $round < $startRound + $roundCount; $round++) {
            $back3Numbers = $this->shuffledBack3Numbers($gameId, $seed, $round);

            for ($front = 0; $front < self::GENERATE_BASE_COUNT; $front++) {
                $front3 = str_pad((string) $front, 3, '0', STR_PAD_LEFT);
                $number = $front3.$back3Numbers[$front];
                $globalIndex = ($round * self::GENERATE_BASE_COUNT) + $front;
                $stockId = $this->stableId('stk', $batchId.':'.$globalIndex.':'.$number);
                $stockIds[] = $stockId;
                $rows[$stockId] = $this->stockInsertPayload($number, $gameId, $batchId, $now, null);
                $rows[$stockId]['id'] = $stockId;
            }
        }

        $imageAssignments = $this->lotteryImages->assignmentsForStockIds(
            $gameId,
            $batchId,
            array_values($stockIds),
            $seed.':'.$startRound,
        );

        foreach ($rows as $stockId => $row) {
            $rows[$stockId] = array_merge($row, $imageAssignments[$stockId] ?? []);
        }

        return [array_values($rows), $stockIds];
    }

    public function dispatchCompletedBatchImageJobs(string $batchId, ?string $afterStockItemId = null, ?int $chunkSize = null): void
    {
        $limit = max(1, $chunkSize ?? (int) config('platform.stock_generation.image_dispatch_chunk_size', 500));
        $query = StockItem::query()
            ->where('batch_id', $batchId)
            ->orderBy('id')
            ->limit($limit);

        if ($afterStockItemId !== null && $afterStockItemId !== '') {
            $query->where('id', '>', $afterStockItemId);
        }

        $stockIds = $query->pluck('id')->map(fn (mixed $id): string => (string) $id)->all();

        if ($stockIds === []) {
            return;
        }

        $this->dispatchCentralImageJobs($stockIds, afterCommit: false);

        if (count($stockIds) === $limit) {
            DispatchStockBatchImageJobs::dispatch($batchId, end($stockIds), $limit);
        }
    }

    private function markGenerationChunkFailed(string $chunkId, Throwable $exception): ?string
    {
        return DB::transaction(function () use ($chunkId, $exception): ?string {
            $chunk = StockGenerationBatchChunk::query()->whereKey($chunkId)->lockForUpdate()->first();

            if ($chunk === null || $chunk->status === 'completed') {
                return null;
            }

            $message = substr($exception->getMessage(), 0, 1000);
            $now = now();

            StockGenerationBatchChunk::query()->whereKey($chunk->id)->update([
                'status' => 'failed',
                'failed_at' => $now,
                'failure_reason' => $message,
                'updated_at' => $now,
            ]);

            StockGenerationBatch::query()->whereKey($chunk->batch_id)->update([
                'status' => 'failed',
                'generated_count' => StockItem::query()->where('batch_id', $chunk->batch_id)->count(),
                'failed_at' => $now,
                'failure_reason' => $message,
                'updated_at' => $now,
            ]);

            return (string) $chunk->batch_id;
        });
    }

    private function broadcastGenerationProgress(string $batchId, string $eventType): void
    {
        $batch = StockGenerationBatch::query()->whereKey($batchId)->first();

        if ($batch === null || (string) $batch->type !== 'generate') {
            return;
        }

        try {
            StockGenerationProgressUpdated::dispatch($this->generationProgressPayload($batch, $eventType));
        } catch (Throwable $exception) {
            Log::warning('Stock generation realtime progress broadcast failed.', [
                'batch_id' => (string) $batch->id,
                'event_type' => $eventType,
                'message' => $exception->getMessage(),
            ]);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function generationProgressPayload(object $batch, string $eventType): array
    {
        return [
            'event_type' => $eventType,
            'batch_id' => (string) $batch->id,
            'game_id' => (string) $batch->game_id,
            'status' => (string) $batch->status,
            'requested_count' => (int) $batch->requested_count,
            'generated_count' => (int) $batch->generated_count,
            'total_rounds' => (int) ($batch->total_rounds ?? 0),
            'processed_rounds' => (int) ($batch->processed_rounds ?? 0),
            'chunk_rounds' => (int) ($batch->chunk_rounds ?? 0),
            'started_at' => $this->timestampString($batch->started_at ?? null),
            'completed_at' => $this->timestampString($batch->completed_at ?? null),
            'failed_at' => $this->timestampString($batch->failed_at ?? null),
            'failure_reason' => $batch->failure_reason ?? null,
            'image_dispatch_status' => $this->imageDispatchStatus((string) $batch->status),
        ];
    }

    private function imageDispatchStatus(string $batchStatus): string
    {
        return match ($batchStatus) {
            'completed' => 'queued',
            'failed', 'cancelled' => 'not_started',
            default => 'waiting_for_stock',
        };
    }

    private function timestampString(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        if ($value instanceof Carbon) {
            return $value->toISOString();
        }

        if ($value instanceof \DateTimeInterface) {
            return Carbon::instance($value)->toISOString();
        }

        return Carbon::parse($value)->toISOString();
    }

    private function auditCompletedGenerationBatch(string $batchId): void
    {
        $batch = StockGenerationBatch::query()->whereKey($batchId)->first();

        if ($batch === null || $batch->created_by_admin_id === null) {
            return;
        }

        $payload = $this->decodeJsonObject($batch->payload_json);

        $this->auditLogger->logAdminWrite(
            actorId: (string) $batch->created_by_admin_id,
            scopeType: 'central',
            action: 'stock.generated',
            targetType: 'stock_generation_batch',
            targetId: $batchId,
            payload: [
                'idempotency_key' => $batch->idempotency_key,
                'payload' => $payload,
            ],
            tenantId: null,
            partnerId: null,
            requestId: $payload['request_id'] ?? null,
            ipAddress: null,
            userAgent: null,
        );
    }

    private function asyncChunkRounds(): int
    {
        return max(1, (int) config('platform.stock_generation.chunk_rounds', 5));
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

            if (($batch['error'] ?? null) === 'idempotency_conflict') {
                return ['error' => 'idempotency_conflict'];
            }

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
                $this->insertStockRows($rows);
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

            if (! Game::query()->where('id', (string) $stock->game_id)->where('status', 'open')->exists()) {
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
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function allocationPartnerOptions(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));
        $availableForCreate = $this->allocationAvailableForCreate($queryParams);
        if ($gameId !== '' && ! $this->latestOpenAllocationGameExists($gameId)) {
            return ['data' => [], 'meta' => ['next_cursor' => null, 'has_more' => false]];
        }

        $allocatedTenantIdsByPartner = $availableForCreate && $gameId !== ''
            ? $this->allocatedTenantIdsByPartnerForGame($gameId)
            : [];
        $gameAllocationSnapshot = $gameId === '' ? null : $this->activeAllocationGameSnapshot($gameId);
        $query = Partner::query()
            ->where('status', 'active')
            ->orderBy('code')
            ->limit($limit);

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = strtolower(trim((string) $queryParams['q']));
            $query->where(function ($nested) use ($q): void {
                $nested->whereRaw('LOWER(code) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(name) like ?', ['%'.$q.'%']);
            });
        }

        $rows = $query->get()->map(function (object $partner) use ($gameId, $availableForCreate, $allocatedTenantIdsByPartner, $gameAllocationSnapshot): ?array {
            $tenants = $this->activeTenantRowsForPartner((string) $partner->id);
            $allocatedTenantIds = $allocatedTenantIdsByPartner[(string) $partner->id] ?? [];
            $availableTenants = $availableForCreate && $gameId !== ''
                ? array_values(array_filter(
                    $tenants,
                    fn (object $tenant): bool => ! in_array((string) $tenant->id, $allocatedTenantIds, true),
                ))
                : $tenants;

            if ($availableForCreate && $gameId !== '' && $availableTenants === []) {
                return null;
            }

            $singleTenant = count($availableTenants) === 1 ? $availableTenants[0] : null;
            $distribution = $gameId !== ''
                ? DB::table('stock_partner_distributions')
                    ->where('game_id', $gameId)
                    ->where('partner_id', (string) $partner->id)
                    ->first()
                : null;
            $stockPercentBasisPoints = (int) ($partner->stock_percent_basis_points ?? 0);
            $partnerAllocationSnapshot = $gameId === '' ? null : $this->activePartnerAllocationSnapshot($gameId, (string) $partner->id);
            $allocationPercentBasisPoints = $partnerAllocationSnapshot['basis_points'] ?? (
                $distribution === null ? null : (int) $distribution->percent_basis_points
            );
            $targetAllocationCount = $partnerAllocationSnapshot['allocated_count'] ?? (
                $gameId !== '' && $allocationPercentBasisPoints !== null
                    ? $this->allocationTargetCountForPercent($gameId, $allocationPercentBasisPoints)
                    : null
            );
            $usedCount = $gameId !== '' && $allocationPercentBasisPoints !== null
                ? $this->partnerUsedVirtualCount($gameId, (string) $partner->id)
                : null;

            return [
                'id' => (string) $partner->id,
                'partner_id' => (string) $partner->id,
                'code' => (string) $partner->code,
                'name' => (string) $partner->name,
                'label' => trim((string) $partner->code.' - '.(string) $partner->name),
                'status' => (string) $partner->status,
                'active_tenant_count' => count($availableTenants),
                'total_active_tenant_count' => count($tenants),
                'allocated_tenant_count' => count($allocatedTenantIds),
                'single_tenant_id' => $singleTenant === null ? null : (string) $singleTenant->id,
                'single_tenant_code' => $singleTenant === null ? null : (string) $singleTenant->code,
                'single_tenant_name' => $singleTenant === null ? null : (string) $singleTenant->name,
                'stock_percent' => $this->percentFromBasisPoints($stockPercentBasisPoints),
                'stock_percent_basis_points' => $stockPercentBasisPoints,
                'default_allocation_percent' => $this->percentFromBasisPoints($stockPercentBasisPoints),
                'default_allocation_percent_basis_points' => $stockPercentBasisPoints,
                'allocation_percent' => $allocationPercentBasisPoints === null ? null : $this->percentFromBasisPoints($allocationPercentBasisPoints),
                'allocation_percent_basis_points' => $allocationPercentBasisPoints,
                'target_allocation_count' => $targetAllocationCount,
                'used_count' => $usedCount,
                'remaining_count' => $targetAllocationCount === null || $usedCount === null
                    ? null
                    : max(0, $targetAllocationCount - $usedCount),
                'existing_allocation_percent' => $gameAllocationSnapshot === null ? null : $this->percentFromBasisPoints($gameAllocationSnapshot['basis_points']),
                'existing_allocation_percent_basis_points' => $gameAllocationSnapshot['basis_points'] ?? null,
                'existing_allocated_count' => $gameAllocationSnapshot['allocated_count'] ?? null,
                'existing_remaining_count' => $gameAllocationSnapshot['remaining_count'] ?? null,
            ];
        })->filter()->values()->all();

        return ['data' => $rows, 'meta' => ['next_cursor' => null, 'has_more' => false]];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function allocationTenantOptions(array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));
        $availableForCreate = $this->allocationAvailableForCreate($queryParams);
        if ($gameId !== '' && ! $this->latestOpenAllocationGameExists($gameId)) {
            return ['data' => [], 'meta' => ['next_cursor' => null, 'has_more' => false]];
        }

        $query = PartnerTenant::query()
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->where('partner_tenants.status', 'active')
            ->where('partners.status', 'active')
            ->orderBy('partner_tenants.code')
            ->limit($limit);

        if (($queryParams['partner_id'] ?? null) !== null && trim((string) $queryParams['partner_id']) !== '') {
            $query->where('partner_tenants.partner_id', trim((string) $queryParams['partner_id']));
        }

        if ($availableForCreate && $gameId !== '') {
            $allocatedTenantIds = $this->allocatedTenantIdsForGame($gameId);
            if ($allocatedTenantIds !== []) {
                $query->whereNotIn('partner_tenants.id', $allocatedTenantIds);
            }
        }

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = strtolower(trim((string) $queryParams['q']));
            $query->where(function ($nested) use ($q): void {
                $nested->whereRaw('LOWER(partner_tenants.code) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(partner_tenants.name) like ?', ['%'.$q.'%']);
            });
        }

        $rows = $query->get([
            'partner_tenants.id',
            'partner_tenants.partner_id',
            'partner_tenants.code',
            'partner_tenants.name',
            'partner_tenants.status',
            'partners.code as partner_code',
            'partners.name as partner_name',
        ])->map(fn (object $tenant): array => [
            'id' => (string) $tenant->id,
            'tenant_id' => (string) $tenant->id,
            'partner_id' => (string) $tenant->partner_id,
            'code' => (string) $tenant->code,
            'name' => (string) $tenant->name,
            'label' => trim((string) $tenant->code.' - '.(string) $tenant->name),
            'status' => (string) $tenant->status,
            'partner_code' => (string) $tenant->partner_code,
            'partner_name' => (string) $tenant->partner_name,
        ])->all();

        return ['data' => $rows, 'meta' => ['next_cursor' => null, 'has_more' => false]];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function allocationGameOptions(array $queryParams): array
    {
        $query = Game::query()
            ->where('status', 'open')
            ->orderByDesc('draw_at')
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit(1);

        if (($queryParams['q'] ?? null) !== null && trim((string) $queryParams['q']) !== '') {
            $q = strtolower(trim((string) $queryParams['q']));
            $query->where(function ($nested) use ($q): void {
                $nested->whereRaw('LOWER(code) like ?', ['%'.$q.'%'])
                    ->orWhereRaw('LOWER(name) like ?', ['%'.$q.'%']);
            });
        }

        $rows = $query->get()->map(function (object $game): array {
            $snapshot = $this->activeAllocationGameSnapshot((string) $game->id);

            return [
                'id' => (string) $game->id,
                'game_id' => (string) $game->id,
                'code' => (string) $game->code,
                'name' => (string) $game->name,
                'label' => trim((string) $game->code.' - '.(string) $game->name),
                'status' => (string) $game->status,
                'sale_start_at' => $game->sale_start_at,
                'draw_at' => $game->draw_at,
                'close_at' => $game->close_at,
                'generated_supply_count' => $this->activeVirtualSupplyCount((string) $game->id),
                'existing_allocation_percent' => $this->percentFromBasisPoints($snapshot['basis_points']),
                'existing_allocation_percent_basis_points' => $snapshot['basis_points'],
                'existing_allocated_count' => $snapshot['allocated_count'],
                'existing_remaining_count' => $snapshot['remaining_count'],
            ];
        })->all();

        return ['data' => $rows, 'meta' => ['next_cursor' => null, 'has_more' => false]];
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
    public function findAllocationReplay(AdminSessionContext $actor, Request $request, ?array $payload = null): ?array
    {
        $idempotencyKey = $request->header('Idempotency-Key');

        if ($idempotencyKey === null || $idempotencyKey === '') {
            return null;
        }

        $existing = PartnerStockAllocation::query()
            ->where('created_by_admin_id', $actor->adminUser['id'])
            ->where('idempotency_key', $idempotencyKey)
            ->first();

        if ($existing === null) {
            return null;
        }

        if ($payload !== null && $existing->payload_hash !== null && (string) $existing->payload_hash !== $this->allocationPayloadHash($payload)) {
            return ['error' => 'idempotency_conflict'];
        }

        return $this->allocationResource($existing);
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
        $hasPercent = array_key_exists('allocation_percent', $payload);
        $hasRequestedCount = array_key_exists('requested_count', $payload);
        $percentBasisPoints = $this->percentBasisPointsFrom($payload['allocation_percent'] ?? null);

        if ($partnerId === '' || ! Partner::where('id', $partnerId)->where('status', 'active')->exists()) {
            $errors['partner_id'][] = 'The partner_id field must reference an active partner.';
        }

        $errors = $this->mergeFieldErrors($errors, $this->tenantSelectionErrors($partnerId, $tenantId));

        $errors = $this->mergeFieldErrors($errors, $this->allocationGameSelectionErrors($gameId));

        $resolvedTenantId = null;
        if (! isset($errors['partner_id'], $errors['tenant_id']) && $partnerId !== '') {
            $resolvedTenantId = $this->resolveTenantIdForPartner($partnerId, $tenantId);
        }

        if (
            $hasPercent
            && $gameId !== ''
            && $partnerId !== ''
            && $resolvedTenantId !== null
            && ! isset($errors['game_id'])
            && $this->allocationPairAlreadyConfigured($gameId, $partnerId, $resolvedTenantId)
        ) {
            $errors['tenant_id'][] = 'This partner tenant already has an active allocation for this game.';
        }

        if ($hasRequestedCount) {
            $errors['requested_count'][] = 'The requested_count field is retired for allocation create. Use allocation_percent.';
        }

        if ($hasPercent) {
            if ($percentBasisPoints === null || $percentBasisPoints < 1 || $percentBasisPoints > self::VIRTUAL_MAX_BP) {
                $errors['allocation_percent'][] = 'The allocation_percent field must be greater than 0 and may not exceed 100.';
            }

            if (! isset($errors['game_id'], $errors['partner_id'], $errors['allocation_percent'])) {
                $sumErrors = $this->partnerPercentSumErrors($gameId, $partnerId, (int) $percentBasisPoints);
                $errors = $this->mergeFieldErrors($errors, $sumErrors);

                if ($sumErrors !== []) {
                    return $errors;
                }

                $targetCount = $this->allocationTargetCountForPercent(
                    $gameId,
                    (int) $percentBasisPoints,
                    $this->eligibleSupplyLayerIdsForNewAllocation($gameId),
                );

                if ($targetCount < 1) {
                    $errors['allocation_percent'][] = 'The allocation_percent does not allocate any current virtual stock supply.';
                }

                $errors = $this->mergeFieldErrors($errors, $this->partnerPercentUsageErrors($gameId, $partnerId, $targetCount));
            }
        } else {
            $errors['allocation_percent'][] = 'The allocation_percent field is required.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validateBulkAllocationPayload(array $payload): array
    {
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $errors = $this->allocationGameSelectionErrors($gameId);

        $parsedRows = $this->bulkAllocationRowsFromPayload($payload, $gameId);
        $errors = $this->mergeFieldErrors($errors, $parsedRows['errors']);

        if (! $parsedRows['explicit']) {
            return $errors;
        }

        if ($parsedRows['rows'] === []) {
            $errors['allocations'][] = 'Enter at least one partner allocation percent greater than 0.';

            return $errors;
        }

        if (isset($errors['game_id'])) {
            return $errors;
        }

        $selectedPartnerIds = array_values(array_unique(array_map(
            fn (array $row): string => (string) $row['partner_id'],
            $parsedRows['rows'],
        )));
        $activeSum = (int) DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->when($selectedPartnerIds !== [], fn ($query) => $query->whereNotIn('partner_id', $selectedPartnerIds))
            ->sum('percent_basis_points');
        $newSum = array_sum(array_map(
            fn (array $row): int => (int) $row['allocation_percent_basis_points'],
            $parsedRows['rows'],
        ));

        if ($activeSum + $newSum > self::VIRTUAL_MAX_BP) {
            $errors['allocations'][] = 'The total active partner allocation percent for this game may not exceed 100.';
        }

        $supplyLayerIds = $this->eligibleSupplyLayerIdsForNewAllocation($gameId);

        foreach ($parsedRows['rows'] as $row) {
            $targetCount = $this->allocationTargetCountForPercent(
                $gameId,
                (int) $row['allocation_percent_basis_points'],
                $supplyLayerIds,
            );

            if ($targetCount < 1) {
                $errors['allocations.'.$row['index'].'.allocation_percent'][] = 'The allocation_percent does not allocate any current virtual stock supply.';
            }

            $usageErrors = $this->partnerPercentUsageErrors($gameId, (string) $row['partner_id'], $targetCount);
            if ($usageErrors !== []) {
                $errors['allocations.'.$row['index'].'.allocation_percent'][] = $usageErrors['allocation_percent'][0];
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
        $replay = $this->findAllocationReplay($actor, $request, $payload);

        if ($replay !== null && ($replay['error'] ?? null) !== 'idempotency_conflict') {
            return $replay;
        }

        return DB::transaction(function () use ($payload, $actor, $request): ?array {
            $partnerId = trim((string) $payload['partner_id']);
            $tenantId = $this->resolveTenantIdForPartner($partnerId, trim((string) ($payload['tenant_id'] ?? '')));
            $gameId = trim((string) $payload['game_id']);
            $now = now();

            if ($tenantId === null) {
                return null;
            }

            if (! $this->latestOpenAllocationGameExists($gameId, true)) {
                return null;
            }

            if (! $this->activeTenantForPartnerExists($partnerId, $tenantId)) {
                return null;
            }

            if (array_key_exists('allocation_percent', $payload)) {
                return $this->createPercentAllocation($payload, $actor, $request, $partnerId, $tenantId, $gameId, $now);
            }

            return null;
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    public function openAllocationsForAllPartners(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $reason = trim((string) ($payload['reason'] ?? ''));
        $parsedBulkRows = $this->bulkAllocationRowsFromPayload($payload, $gameId);
        $explicitRows = $parsedBulkRows['explicit'];
        $requestedRowsByPartner = [];

        foreach ($parsedBulkRows['rows'] as $row) {
            $requestedRowsByPartner[(string) $row['partner_id']] = $row;
        }

        return DB::transaction(function () use ($gameId, $reason, $actor, $request, $explicitRows, $requestedRowsByPartner): array {
            if (! $this->latestOpenAllocationGameExists($gameId, true)) {
                return [
                    'status' => 'skipped',
                    'game_id' => $gameId,
                    'created_count' => 0,
                    'skipped_count' => 0,
                    'created' => [],
                    'skipped' => [],
                ];
            }

            DB::table('stock_partner_distributions')->where('game_id', $gameId)->lockForUpdate()->get();

            $created = [];
            $skipped = [];
            $now = now();
            $partnerQuery = Partner::query()
                ->where('status', 'active')
                ->orderBy('code');

            if ($explicitRows) {
                $partnerQuery->whereIn('id', array_keys($requestedRowsByPartner));
            }

            $partners = $partnerQuery->get(['id', 'code', 'name', 'stock_percent_basis_points']);

            foreach ($partners as $partner) {
                $partnerId = (string) $partner->id;
                $partnerLabel = trim((string) $partner->code.' - '.(string) $partner->name);
                $requestedRow = $requestedRowsByPartner[$partnerId] ?? null;
                $tenants = $this->activeTenantRowsForPartner($partnerId);

                if ($tenants === []) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, null, $partnerLabel, 'no_active_tenant');
                    continue;
                }

                if (! $explicitRows && count($tenants) > 1) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, null, $partnerLabel, 'multiple_active_tenants');
                    continue;
                }

                $tenantId = $explicitRows
                    ? (string) ($requestedRow['tenant_id'] ?? '')
                    : (string) $tenants[0]->id;

                if ($tenantId === '' || ! $this->activeTenantForPartnerExists($partnerId, $tenantId)) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, null, $partnerLabel, 'tenant_unavailable');
                    continue;
                }

                if ($this->allocationPairAlreadyConfigured($gameId, $partnerId, $tenantId, true)) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, $tenantId, $partnerLabel, 'already_allocated');
                    continue;
                }

                if ($explicitRows) {
                    $percentBasisPoints = (int) ($requestedRow['allocation_percent_basis_points'] ?? 0);
                } else {
                    $distribution = DB::table('stock_partner_distributions')
                        ->where('game_id', $gameId)
                        ->where('partner_id', $partnerId)
                        ->first(['percent_basis_points', 'status']);
                    $percentBasisPoints = $distribution !== null && (string) $distribution->status === 'active'
                        ? (int) $distribution->percent_basis_points
                        : (int) ($partner->stock_percent_basis_points ?? 0);
                }

                if ($percentBasisPoints < 1) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, $tenantId, $partnerLabel, 'missing_allocation_percent');
                    continue;
                }

                if ($this->partnerPercentSumErrors($gameId, $partnerId, $percentBasisPoints) !== []) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, $tenantId, $partnerLabel, 'allocation_percent_exceeds_remaining');
                    continue;
                }

                $supplyLayerIds = $this->eligibleSupplyLayerIdsForNewAllocation($gameId);
                $targetCount = $this->allocationTargetCountForPercent($gameId, $percentBasisPoints, $supplyLayerIds);

                if ($targetCount < 1) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, $tenantId, $partnerLabel, 'no_allocatable_supply');
                    continue;
                }

                if ($this->partnerUsedVirtualCount($gameId, $partnerId) > $targetCount) {
                    $skipped[] = $this->bulkAllocationSkippedResource($partnerId, $tenantId, $partnerLabel, 'below_reserved_or_sold_stock');
                    continue;
                }

                $allocationId = 'alc_'.Str::ulid()->toBase32();
                $allocationPayload = [
                    'partner_id' => $partnerId,
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'allocation_percent' => $this->percentFromBasisPoints($percentBasisPoints),
                    'reason' => $reason,
                ];

                $allocationIdempotencyKey = $this->bulkAllocationIdempotencyKey($request, $partnerId);

                PartnerStockAllocation::query()->insert([
                    'id' => $allocationId,
                    'partner_id' => $partnerId,
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'quota_id' => null,
                    'status' => 'allocated',
                    'requested_count' => $targetCount,
                    'allocation_percent_basis_points' => $percentBasisPoints,
                    'supply_layer_ids_json' => json_encode($supplyLayerIds, JSON_THROW_ON_ERROR),
                    'allocated_count' => $targetCount,
                    'recalled_count' => 0,
                    'idempotency_key' => $allocationIdempotencyKey,
                    'payload_hash' => $this->allocationPayloadHash($allocationPayload),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'reason' => $reason === '' ? null : $reason,
                    'cancelled_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->upsertPartnerDistribution($gameId, $partnerId, $tenantId, $percentBasisPoints, 'active', $now);

                $this->insertOutboxEvent(
                    eventType: 'stock.allocated.v1',
                    producer: 'central_stock',
                    tenantId: $tenantId,
                    partnerId: $partnerId,
                    gameId: $gameId,
                    aggregateType: 'partner_stock_allocation',
                    aggregateId: $allocationId,
                    idempotencyKey: $allocationIdempotencyKey,
                    correlationId: $request->header('X-Request-Id'),
                    payload: [
                        'allocation_id' => $allocationId,
                        'partner_id' => $partnerId,
                        'tenant_id' => $tenantId,
                        'game_id' => $gameId,
                        'allocation_percent' => $this->percentFromBasisPoints($percentBasisPoints),
                        'allocation_percent_basis_points' => $percentBasisPoints,
                        'cursor' => $allocationId,
                        'item_count' => $targetCount,
                        'chunk_size' => 5000,
                        'stock_mode' => 'virtual',
                    ],
                );

                $this->auditAllocationChange($actor, $request, $allocationId, 'stock.allocated.bulk', $allocationPayload, $partnerId, $tenantId);
                $created[] = $this->allocationResource((object) [
                    'id' => $allocationId,
                    'partner_id' => $partnerId,
                    'tenant_id' => $tenantId,
                    'game_id' => $gameId,
                    'quota_id' => null,
                    'status' => 'allocated',
                    'requested_count' => $targetCount,
                    'allocation_percent_basis_points' => $percentBasisPoints,
                    'allocated_count' => $targetCount,
                    'recalled_count' => 0,
                    'cancelled_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            if ($created !== []) {
                $this->invalidatePartnerDistributionGeneratedCounts($gameId);
                $this->virtualStock->refreshPartnerGeneratedPatternCountsForGame($gameId);
                $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit($gameId);
            }

            return [
                'status' => 'completed',
                'game_id' => $gameId,
                'created_count' => count($created),
                'skipped_count' => count($skipped),
                'created' => $created,
                'skipped' => $skipped,
            ];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    private function createPercentAllocation(
        array $payload,
        AdminSessionContext $actor,
        Request $request,
        string $partnerId,
        string $tenantId,
        string $gameId,
        mixed $now,
    ): ?array {
        $percentBasisPoints = $this->percentBasisPointsFrom($payload['allocation_percent'] ?? null);

        if ($percentBasisPoints === null) {
            return null;
        }

        if ($this->allocationPairAlreadyConfigured($gameId, $partnerId, $tenantId, true)) {
            return null;
        }

        $distributionRows = DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->lockForUpdate()
            ->get();
        $sum = $distributionRows
            ->filter(fn (object $row): bool => (string) $row->partner_id !== $partnerId && (string) $row->status === 'active')
            ->sum(fn (object $row): int => max(0, (int) $row->percent_basis_points));

        if ($sum + $percentBasisPoints > self::VIRTUAL_MAX_BP) {
            return null;
        }

        $supplyLayerIds = $this->eligibleSupplyLayerIdsForNewAllocation($gameId);
        $targetCount = $this->allocationTargetCountForPercent($gameId, $percentBasisPoints, $supplyLayerIds);

        if ($targetCount < 1 || $this->partnerUsedVirtualCount($gameId, $partnerId) > $targetCount) {
            return null;
        }

        $allocationId = 'alc_'.Str::ulid()->toBase32();

        PartnerStockAllocation::query()->insert([
            'id' => $allocationId,
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'quota_id' => null,
            'status' => 'allocated',
            'requested_count' => $targetCount,
            'allocation_percent_basis_points' => $percentBasisPoints,
            'supply_layer_ids_json' => json_encode($supplyLayerIds, JSON_THROW_ON_ERROR),
            'allocated_count' => $targetCount,
            'recalled_count' => 0,
            'idempotency_key' => $request->header('Idempotency-Key'),
            'payload_hash' => $this->allocationPayloadHash($payload),
            'created_by_admin_id' => $actor->adminUser['id'],
            'reason' => $payload['reason'] ?? null,
            'cancelled_at' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $this->upsertPartnerDistribution($gameId, $partnerId, $tenantId, $percentBasisPoints, 'active', $now);
        $this->invalidatePartnerDistributionGeneratedCounts($gameId);
        $this->virtualStock->refreshPartnerGeneratedPatternCountsForGame($gameId);

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
                'allocation_percent' => $this->percentFromBasisPoints($percentBasisPoints),
                'allocation_percent_basis_points' => $percentBasisPoints,
                'cursor' => $allocationId,
                'item_count' => $targetCount,
                'chunk_size' => 5000,
                'stock_mode' => 'virtual',
            ],
        );

        $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit($gameId);
        $this->auditAllocationChange($actor, $request, $allocationId, 'stock.allocated', $payload, $partnerId, $tenantId);

        return $this->findAllocation($allocationId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    public function validatePartnerPercentPayload(array $payload): array
    {
        $errors = [];
        $partnerId = trim((string) ($payload['partner_id'] ?? ''));
        $tenantId = trim((string) ($payload['tenant_id'] ?? ''));
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $percentBasisPoints = $this->percentBasisPointsFrom($payload['allocation_percent'] ?? null);

        if ($partnerId === '' || ! Partner::where('id', $partnerId)->where('status', 'active')->exists()) {
            $errors['partner_id'][] = 'The partner_id field must reference an active partner.';
        }

        $errors = $this->mergeFieldErrors($errors, $this->tenantSelectionErrors($partnerId, $tenantId));

        $errors = $this->mergeFieldErrors($errors, $this->allocationGameSelectionErrors($gameId));

        if ($percentBasisPoints === null || $percentBasisPoints < 1 || $percentBasisPoints > self::VIRTUAL_MAX_BP) {
            $errors['allocation_percent'][] = 'The allocation_percent field must be greater than 0 and may not exceed 100.';
        }

        if (! isset($errors['game_id'], $errors['partner_id'], $errors['allocation_percent'])) {
            $targetCount = $this->allocationTargetCountForPercent($gameId, (int) $percentBasisPoints);

            if ($targetCount < 1) {
                $errors['allocation_percent'][] = 'The allocation_percent does not allocate any current virtual stock supply.';
            }

            $errors = $this->mergeFieldErrors($errors, $this->partnerPercentSumErrors($gameId, $partnerId, (int) $percentBasisPoints));
            $errors = $this->mergeFieldErrors($errors, $this->partnerPercentUsageErrors($gameId, $partnerId, $targetCount));
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function updatePartnerPercent(array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($payload, $actor, $request): ?array {
            $partnerId = trim((string) $payload['partner_id']);
            $tenantId = $this->resolveTenantIdForPartner($partnerId, trim((string) ($payload['tenant_id'] ?? '')));
            $gameId = trim((string) $payload['game_id']);
            $percentBasisPoints = $this->percentBasisPointsFrom($payload['allocation_percent'] ?? null);
            $now = now();

            if ($tenantId === null || $percentBasisPoints === null) {
                return null;
            }

            if (! $this->latestOpenAllocationGameExists($gameId, true)) {
                return null;
            }

            DB::table('stock_partner_distributions')->where('game_id', $gameId)->lockForUpdate()->get();

            if ($this->partnerPercentSumErrors($gameId, $partnerId, $percentBasisPoints) !== []) {
                return null;
            }

            $targetCount = $this->allocationTargetCountForPercent($gameId, $percentBasisPoints);

            if ($targetCount < 1 || $this->partnerUsedVirtualCount($gameId, $partnerId) > $targetCount) {
                return null;
            }

            $this->upsertPartnerDistribution($gameId, $partnerId, $tenantId, $percentBasisPoints, 'active', $now);
            $this->invalidatePartnerDistributionGeneratedCounts($gameId);
            $this->virtualStock->refreshPartnerGeneratedPatternCountsForGame($gameId);
            $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit($gameId);

            $this->auditAllocationChange(
                $actor,
                $request,
                $this->stableId('spd', $gameId.':'.$partnerId),
                'stock.partner_percent_updated',
                $payload,
                $partnerId,
                $tenantId,
            );

            return $this->partnerStockPercentResource($gameId, $partnerId);
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
            $isPercentAllocation = $allocation->allocation_percent_basis_points !== null;

            if (
                $isPercentAllocation
                && $this->partnerUsedVirtualCount((string) $allocation->game_id, (string) $allocation->partner_id) > 0
            ) {
                return null;
            }

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

            if ($isPercentAllocation) {
                $this->upsertPartnerDistribution(
                    (string) $allocation->game_id,
                    (string) $allocation->partner_id,
                    (string) $allocation->tenant_id,
                    0,
                    'cancelled',
                    $now,
                );
                $this->invalidatePartnerDistributionGeneratedCounts((string) $allocation->game_id);
                $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit((string) $allocation->game_id);
            }

            PartnerStockAllocation::query()->where('id', $allocationId)->update([
                'status' => 'cancelled',
                'allocated_count' => 0,
                'reason' => $payload['reason'] ?? $allocation->reason,
                'cancelled_at' => $now,
                'updated_at' => $now,
            ]);

            if ($isPercentAllocation) {
                $this->virtualStock->refreshPartnerGeneratedPatternCountsForGame((string) $allocation->game_id);
            }

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

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function recallAllAllocation(string $allocationId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($allocationId, $payload, $actor, $request): ?array {
            $allocation = PartnerStockAllocation::query()->where('id', $allocationId)->lockForUpdate()->first();

            if ($allocation === null || (string) $allocation->status === 'cancelled') {
                return null;
            }

            if ((string) $allocation->status === 'recalled') {
                return $this->findAllocation($allocationId);
            }

            $now = now();
            $reason = trim((string) ($payload['reason'] ?? 'recall_all'));
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
                        'status' => 'recalled',
                        'recall_reason' => $reason,
                        'recalled_at' => $now,
                        'updated_at' => $now,
                    ]);

                PartnerStockAllocationItem::query()
                    ->where('allocation_id', $allocationId)
                    ->whereIn('stock_item_id', $stockIds)
                    ->update([
                        'status' => 'recalled',
                        'updated_at' => $now,
                    ]);
            }

            $recalledCount = $stockIds === [] ? (int) $allocation->allocated_count : count($stockIds);

            if ($allocation->quota_id !== null && $recalledCount > 0) {
                $quota = PartnerQuota::query()->where('id', $allocation->quota_id)->lockForUpdate()->first();

                if ($quota !== null) {
                    PartnerQuota::query()->where('id', $quota->id)->update([
                        'allocated_count' => max(0, (int) $quota->allocated_count - $recalledCount),
                        'updated_at' => $now,
                    ]);
                }
            }

            if ($allocation->allocation_percent_basis_points !== null) {
                $this->upsertPartnerDistribution(
                    (string) $allocation->game_id,
                    (string) $allocation->partner_id,
                    (string) $allocation->tenant_id,
                    0,
                    'recalled',
                    $now,
                );
                $this->invalidatePartnerDistributionGeneratedCounts((string) $allocation->game_id);
                $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit((string) $allocation->game_id);
            }

            PartnerStockAllocation::query()->where('id', $allocationId)->update([
                'status' => 'recalled',
                'allocated_count' => $stockIds === [] ? (int) $allocation->allocated_count : 0,
                'recalled_count' => min((int) $allocation->requested_count, (int) $allocation->recalled_count + $recalledCount),
                'reason' => $reason,
                'updated_at' => $now,
            ]);

            if ($allocation->allocation_percent_basis_points !== null) {
                $this->virtualStock->refreshPartnerGeneratedPatternCountsForGame((string) $allocation->game_id);
            }

            $recallId = 'rec_'.Str::ulid()->toBase32();
            $this->insertOutboxEvent(
                eventType: 'stock.recalled.v1',
                producer: 'central_stock',
                tenantId: (string) $allocation->tenant_id,
                partnerId: (string) $allocation->partner_id,
                gameId: (string) $allocation->game_id,
                aggregateType: 'partner_stock_allocation',
                aggregateId: $allocationId,
                idempotencyKey: $request->header('Idempotency-Key'),
                correlationId: $request->header('X-Request-Id'),
                payload: [
                    'recall_id' => $recallId,
                    'allocation_id' => $allocationId,
                    'partner_id' => (string) $allocation->partner_id,
                    'tenant_id' => (string) $allocation->tenant_id,
                    'game_id' => (string) $allocation->game_id,
                    'reason' => $reason,
                    'recalled_count' => $recalledCount,
                    'stock_mode' => $allocation->allocation_percent_basis_points === null ? 'materialized' : 'virtual',
                ],
            );

            $this->auditAllocationChange(
                $actor,
                $request,
                $allocationId,
                'stock.allocation_recalled_all',
                $payload,
                (string) $allocation->partner_id,
                (string) $allocation->tenant_id,
            );

            return $this->findAllocation($allocationId);
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>|null
     */
    public function redistributeAllocation(string $allocationId, array $payload, AdminSessionContext $actor, Request $request): ?array
    {
        return DB::transaction(function () use ($allocationId, $payload, $actor, $request): ?array {
            $allocation = PartnerStockAllocation::query()->where('id', $allocationId)->lockForUpdate()->first();

            if ($allocation === null || (string) $allocation->status !== 'recalled' || $allocation->allocation_percent_basis_points === null) {
                return null;
            }

            $gameId = (string) $allocation->game_id;
            $partnerId = (string) $allocation->partner_id;
            $tenantId = (string) $allocation->tenant_id;
            $percentBasisPoints = (int) $allocation->allocation_percent_basis_points;
            $supplyLayerIds = $this->eligibleSupplyLayerIdsForNewAllocation($gameId);
            $targetCount = $this->allocationTargetCountForPercent($gameId, $percentBasisPoints, $supplyLayerIds);

            DB::table('stock_partner_distributions')->where('game_id', $gameId)->lockForUpdate()->get();

            if ($targetCount < 1 || $this->partnerPercentSumErrors($gameId, $partnerId, $percentBasisPoints) !== []) {
                return null;
            }

            if ($this->partnerUsedVirtualCount($gameId, $partnerId) > $targetCount) {
                return null;
            }

            $now = now();
            $this->upsertPartnerDistribution($gameId, $partnerId, $tenantId, $percentBasisPoints, 'active', $now);
            $this->invalidatePartnerDistributionGeneratedCounts($gameId);

            PartnerStockAllocation::query()->where('id', $allocationId)->update([
                'status' => 'allocated',
                'requested_count' => $targetCount,
                'supply_layer_ids_json' => json_encode($supplyLayerIds, JSON_THROW_ON_ERROR),
                'allocated_count' => $targetCount,
                'recalled_count' => 0,
                'reason' => $payload['reason'] ?? $allocation->reason,
                'updated_at' => $now,
            ]);
            $this->virtualStock->refreshPartnerGeneratedPatternCountsForGame($gameId);

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
                    'allocation_percent' => $this->percentFromBasisPoints($percentBasisPoints),
                    'allocation_percent_basis_points' => $percentBasisPoints,
                    'cursor' => $allocationId,
                    'item_count' => $targetCount,
                    'chunk_size' => 5000,
                    'stock_mode' => 'virtual',
                    'redistributed' => true,
                ],
            );

            $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit($gameId);
            $this->auditAllocationChange($actor, $request, $allocationId, 'stock.allocation_redistributed', $payload, $partnerId, $tenantId);

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
            'recalled_count' => DB::raw('recalled_count + 1'),
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
     * @param array<string, mixed> $normalized
     * @return array{id?: string, created?: bool, error?: string}
     */
    private function ensureStockBatch(string $type, array $normalized, AdminSessionContext $actor, Request $request): array
    {
        $payloadHash = $this->payloadHash($normalized);
        $idempotencyKey = (string) $request->header('Idempotency-Key');
        $batchId = $this->stableId('stb', $type.':'.$idempotencyKey.':'.$payloadHash);
        $now = now();
        $existing = StockGenerationBatch::query()
            ->where('type', $type)
            ->where('created_by_admin_id', $actor->adminUser['id'])
            ->where('idempotency_key', $idempotencyKey)
            ->orderBy('created_at')
            ->first();

        if ($existing !== null) {
            if ((string) $existing->payload_hash !== $payloadHash) {
                return ['error' => 'idempotency_conflict'];
            }

            return ['id' => (string) $existing->id, 'created' => false];
        }

        if (! StockGenerationBatch::query()->where('id', $batchId)->exists()) {
            StockGenerationBatch::query()->insert([
                'id' => $batchId,
                'game_id' => $normalized['game_id'],
                'type' => $type,
                'status' => $type === 'generate' && (int) $normalized['requested_count'] > self::GENERATE_SYNC_THRESHOLD ? 'queued' : 'processing',
                'requested_count' => $normalized['requested_count'],
                'generated_count' => 0,
                'total_rounds' => (int) ($normalized['total_rounds'] ?? 0),
                'processed_rounds' => 0,
                'chunk_rounds' => (int) ($normalized['chunk_rounds'] ?? 0),
                'range_start' => $normalized['range_start'],
                'range_end' => $normalized['range_end'],
                'number_digits' => $normalized['number_digits'],
                'idempotency_key' => $request->header('Idempotency-Key'),
                'payload_hash' => $payloadHash,
                'created_by_admin_id' => $actor->adminUser['id'],
                'payload_json' => json_encode($normalized, JSON_THROW_ON_ERROR),
                'started_at' => $type === 'generate' && (int) $normalized['requested_count'] > self::GENERATE_SYNC_THRESHOLD ? null : $now,
                'completed_at' => null,
                'failed_at' => null,
                'failure_reason' => null,
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
     * @param array<int, array<string, mixed>> $rows
     */
    private function insertStockRows(array $rows): void
    {
        if ($rows === []) {
            return;
        }

        $columnCount = max(1, count($rows[0]));
        $maxRowsPerInsert = max(1, intdiv(60000, $columnCount));

        foreach (array_chunk($rows, $maxRowsPerInsert) as $chunk) {
            StockItem::query()->insert($chunk);
        }
    }

    /**
     * @param array<int, string> $stockIds
     */
    private function dispatchCentralImageJobs(array $stockIds, bool $afterCommit = true): void
    {
        foreach ($stockIds as $stockId) {
            $dispatch = GenerateLotteryImageJob::dispatch((string) $stockId);

            if ($afterCommit) {
                $dispatch->afterCommit();
            }
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

    /**
     * @return array<int, object>
     */
    private function activeTenantRowsForPartner(string $partnerId): array
    {
        if ($partnerId === '') {
            return [];
        }

        return PartnerTenant::query()
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->where('partner_tenants.partner_id', $partnerId)
            ->where('partner_tenants.status', 'active')
            ->where('partners.status', 'active')
            ->orderBy('partner_tenants.code')
            ->get(['partner_tenants.id', 'partner_tenants.code', 'partner_tenants.name'])
            ->all();
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function allocationAvailableForCreate(array $queryParams): bool
    {
        return filter_var($queryParams['available_for_create'] ?? false, FILTER_VALIDATE_BOOLEAN);
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function allocationGameSelectionErrors(string $gameId): array
    {
        if ($gameId === '' || ! Game::query()->where('id', $gameId)->where('status', 'open')->exists()) {
            return ['game_id' => ['The game_id field must reference an open game.']];
        }

        return $this->latestOpenAllocationGameExists($gameId)
            ? []
            : ['game_id' => ['The game_id field must reference the latest open game.']];
    }

    private function latestOpenAllocationGameExists(string $gameId, bool $lock = false): bool
    {
        if ($gameId === '') {
            return false;
        }

        $query = Game::query()
            ->where('status', 'open')
            ->orderByDesc('draw_at')
            ->orderByDesc('created_at')
            ->orderByDesc('id');

        if ($lock) {
            $query->lockForUpdate();
        }

        $game = $query->first(['id']);

        return $game !== null && (string) $game->id === $gameId;
    }

    /**
     * @return array<int, string>
     */
    private function allocatedTenantIdsForGame(string $gameId): array
    {
        if ($gameId === '') {
            return [];
        }

        return PartnerStockAllocation::query()
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->pluck('tenant_id')
            ->filter()
            ->map(fn (mixed $tenantId): string => (string) $tenantId)
            ->unique()
            ->values()
            ->all();
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function allocatedTenantIdsByPartnerForGame(string $gameId): array
    {
        if ($gameId === '') {
            return [];
        }

        $rows = PartnerStockAllocation::query()
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->get(['partner_id', 'tenant_id']);
        $grouped = [];

        foreach ($rows as $row) {
            $partnerId = (string) $row->partner_id;
            $tenantId = (string) $row->tenant_id;

            if ($partnerId === '' || $tenantId === '') {
                continue;
            }

            $grouped[$partnerId] = array_values(array_unique([
                ...($grouped[$partnerId] ?? []),
                $tenantId,
            ]));
        }

        return $grouped;
    }

    private function allocationPairAlreadyConfigured(string $gameId, string $partnerId, string $tenantId, bool $lock = false): bool
    {
        if ($gameId === '' || $partnerId === '' || $tenantId === '') {
            return false;
        }

        $query = PartnerStockAllocation::query()
            ->where('game_id', $gameId)
            ->where('partner_id', $partnerId)
            ->where('tenant_id', $tenantId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES);

        if ($lock) {
            $query->lockForUpdate();
        }

        return $query->exists();
    }

    /**
     * @return array<string, string|null>
     */
    private function bulkAllocationSkippedResource(string $partnerId, ?string $tenantId, string $partnerLabel, string $reason): array
    {
        return [
            'partner_id' => $partnerId,
            'tenant_id' => $tenantId,
            'partner_label' => $partnerLabel,
            'reason' => $reason,
        ];
    }

    private function bulkAllocationIdempotencyKey(Request $request, string $partnerId): ?string
    {
        $key = trim((string) $request->header('Idempotency-Key'));

        if ($key === '') {
            return null;
        }

        return substr($key.':'.substr(hash('sha256', $partnerId), 0, 12), 0, 128);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{explicit: bool, rows: array<int, array<string, mixed>>, errors: array<string, array<int, string>>}
     */
    private function bulkAllocationRowsFromPayload(array $payload, string $gameId): array
    {
        if (! array_key_exists('allocations', $payload)) {
            return ['explicit' => false, 'rows' => [], 'errors' => []];
        }

        $submittedRows = $payload['allocations'];

        if (! is_array($submittedRows)) {
            return [
                'explicit' => true,
                'rows' => [],
                'errors' => ['allocations' => ['The allocations field must be a list of partner allocation percentages.']],
            ];
        }

        $rows = [];
        $errors = [];
        $seenPartnerIds = [];

        foreach (array_values($submittedRows) as $index => $row) {
            if (! is_array($row)) {
                $errors['allocations.'.$index][] = 'Each allocation row must be an object.';
                continue;
            }

            $rowErrors = [];
            $partnerId = trim((string) ($row['partner_id'] ?? ''));
            $tenantId = trim((string) ($row['tenant_id'] ?? ''));
            $percentBasisPoints = $this->percentBasisPointsFrom($row['allocation_percent'] ?? $row['percent'] ?? null);
            $partnerIsActive = $partnerId !== ''
                && Partner::query()->where('id', $partnerId)->where('status', 'active')->exists();

            if (! $partnerIsActive) {
                $rowErrors['partner_id'][] = 'The partner_id field must reference an active partner.';
            } elseif (isset($seenPartnerIds[$partnerId])) {
                $rowErrors['partner_id'][] = 'Each partner can only be listed once.';
            }

            if ($partnerIsActive) {
                foreach ($this->tenantSelectionErrors($partnerId, $tenantId) as $field => $messages) {
                    $rowErrors[$field] = array_merge($rowErrors[$field] ?? [], $messages);
                }
            }

            $resolvedTenantId = $partnerIsActive
                ? $this->resolveTenantIdForPartner($partnerId, $tenantId)
                : null;

            if (
                $gameId !== ''
                && $partnerIsActive
                && $resolvedTenantId !== null
                && $this->allocationPairAlreadyConfigured($gameId, $partnerId, $resolvedTenantId)
            ) {
                $rowErrors['tenant_id'][] = 'This partner tenant already has an active allocation for this game.';
            }

            if ($percentBasisPoints === null || $percentBasisPoints < 1 || $percentBasisPoints > self::VIRTUAL_MAX_BP) {
                $rowErrors['allocation_percent'][] = 'The allocation_percent field must be greater than 0 and may not exceed 100.';
            }

            if ($rowErrors !== []) {
                foreach ($rowErrors as $field => $messages) {
                    $errors['allocations.'.$index.'.'.$field] = $messages;
                }
                continue;
            }

            $seenPartnerIds[$partnerId] = true;
            $rows[] = [
                'index' => $index,
                'partner_id' => $partnerId,
                'tenant_id' => (string) $resolvedTenantId,
                'allocation_percent_basis_points' => (int) $percentBasisPoints,
                'allocation_percent' => $this->percentFromBasisPoints((int) $percentBasisPoints),
            ];
        }

        return ['explicit' => true, 'rows' => $rows, 'errors' => $errors];
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function tenantSelectionErrors(string $partnerId, string $tenantId): array
    {
        if ($partnerId === '') {
            return [];
        }

        $tenants = $this->activeTenantRowsForPartner($partnerId);

        if ($tenantId === '') {
            if ($tenants === []) {
                return ['tenant_id' => ['The selected partner has no active tenant.']];
            }

            if (count($tenants) > 1) {
                return ['tenant_id' => ['The tenant_id field is required when the selected partner has multiple active tenants.']];
            }

            return [];
        }

        return $this->activeTenantForPartnerExists($partnerId, $tenantId)
            ? []
            : ['tenant_id' => ['The tenant_id field must reference an active tenant for an active partner.']];
    }

    private function resolveTenantIdForPartner(string $partnerId, string $tenantId): ?string
    {
        if ($tenantId !== '') {
            return $this->activeTenantForPartnerExists($partnerId, $tenantId) ? $tenantId : null;
        }

        $tenants = $this->activeTenantRowsForPartner($partnerId);

        return count($tenants) === 1 ? (string) $tenants[0]->id : null;
    }

    private function percentBasisPointsFrom(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        if (! is_numeric($value)) {
            return null;
        }

        return (int) round(((float) $value) * 100);
    }

    private function percentFromBasisPoints(int $basisPoints): float
    {
        return round($basisPoints / 100, 2);
    }

    private function activeVirtualSupplyCount(string $gameId): int
    {
        $profile = DB::table('stock_supply_profiles')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->orderByDesc('created_at')
            ->first();

        if ($profile === null) {
            return 0;
        }

        $layerCapacity = (int) DB::table('virtual_stock_supply_layers')
            ->where('profile_id', (string) $profile->id)
            ->where('status', 'active')
            ->sum('total_capacity');

        return $layerCapacity > 0 ? $layerCapacity : (int) $profile->total_capacity;
    }

    /**
     * @return array{basis_points: int, allocated_count: int, remaining_count: int}
     */
    private function activeAllocationGameSnapshot(string $gameId): array
    {
        $generatedSupply = $this->activeVirtualSupplyCount($gameId);
        $row = DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->selectRaw('COUNT(*) as row_count')
            ->selectRaw('COALESCE(SUM(allocation_percent_basis_points), 0) as basis_points')
            ->selectRaw('COALESCE(SUM(allocated_count), 0) as allocated_count')
            ->first();

        $basisPoints = (int) ($row->basis_points ?? 0);
        $allocatedCount = (int) ($row->allocated_count ?? 0);

        if ((int) ($row->row_count ?? 0) === 0) {
            $basisPoints = (int) DB::table('stock_partner_distributions')
                ->where('game_id', $gameId)
                ->where('status', 'active')
                ->sum('percent_basis_points');
            $allocatedCount = $this->allocationTargetCountForPercent($gameId, $basisPoints);
        }

        return [
            'basis_points' => $basisPoints,
            'allocated_count' => $allocatedCount,
            'remaining_count' => max(0, $generatedSupply - $allocatedCount),
        ];
    }

    /**
     * @return array{basis_points: int, allocated_count: int}|null
     */
    private function activePartnerAllocationSnapshot(string $gameId, string $partnerId): ?array
    {
        $row = DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->where('partner_id', $partnerId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->selectRaw('COUNT(*) as row_count')
            ->selectRaw('COALESCE(SUM(allocation_percent_basis_points), 0) as basis_points')
            ->selectRaw('COALESCE(SUM(allocated_count), 0) as allocated_count')
            ->first();

        if ((int) ($row->row_count ?? 0) < 1) {
            return null;
        }

        return [
            'basis_points' => (int) ($row->basis_points ?? 0),
            'allocated_count' => (int) ($row->allocated_count ?? 0),
        ];
    }

    /**
     * @param array<int, string>|null $supplyLayerIds
     */
    private function allocationTargetCountForPercent(string $gameId, int $basisPoints, ?array $supplyLayerIds = null): int
    {
        $generatedSupply = $supplyLayerIds === null
            ? $this->activeVirtualSupplyCount($gameId)
            : $this->virtualSupplyCountForLayerIds($gameId, $supplyLayerIds);

        if ($generatedSupply < 1 || $basisPoints < 1) {
            return 0;
        }

        return (int) floor(($generatedSupply * $basisPoints) / self::VIRTUAL_MAX_BP);
    }

    /**
     * @return array<int, string>
     */
    private function eligibleSupplyLayerIdsForNewAllocation(string $gameId): array
    {
        $activeLayerIds = $this->activeVirtualSupplyLayerIds($gameId);

        if ($activeLayerIds === []) {
            return [];
        }

        $assignedLayerIds = $this->activeAllocationSnapshotLayerIds($gameId);
        $neverAllocatedLayerIds = array_values(array_diff($activeLayerIds, $assignedLayerIds));

        if ($neverAllocatedLayerIds !== []) {
            return $neverAllocatedLayerIds;
        }

        return $this->activeSupplyLayerIdsWithRemainingPercent($gameId, $activeLayerIds);
    }

    /**
     * @param array<int, string> $activeLayerIds
     * @return array<int, string>
     */
    private function activeSupplyLayerIdsWithRemainingPercent(string $gameId, array $activeLayerIds): array
    {
        $usedBasisPointsByLayer = array_fill_keys($activeLayerIds, 0);
        $rows = DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->where('allocation_percent_basis_points', '>', 0)
            ->get(['allocation_percent_basis_points', 'supply_layer_ids_json']);

        foreach ($rows as $row) {
            foreach (array_intersect($activeLayerIds, $this->snapshotLayerIds($row->supply_layer_ids_json ?? null, $activeLayerIds)) as $layerId) {
                $usedBasisPointsByLayer[$layerId] = min(
                    self::VIRTUAL_MAX_BP,
                    (int) $usedBasisPointsByLayer[$layerId] + max(0, (int) $row->allocation_percent_basis_points),
                );
            }
        }

        return array_values(array_filter(
            $activeLayerIds,
            fn (string $layerId): bool => (int) ($usedBasisPointsByLayer[$layerId] ?? 0) < self::VIRTUAL_MAX_BP,
        ));
    }

    /**
     * @return array<int, string>
     */
    private function activeVirtualSupplyLayerIds(string $gameId): array
    {
        $profile = $this->activeVirtualStockProfile($gameId);

        if ($profile === null) {
            return [];
        }

        return array_values(array_filter(array_map(
            fn (array $layer): string => (string) ($layer['id'] ?? ''),
            $this->virtualSupplyLayers($profile),
        )));
    }

    /**
     * @return array<int, string>
     */
    private function activeAllocationSnapshotLayerIds(string $gameId): array
    {
        $activeLayerIds = $this->activeVirtualSupplyLayerIds($gameId);
        $layerIds = [];
        $rows = DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->get(['supply_layer_ids_json']);

        foreach ($rows as $row) {
            foreach ($this->snapshotLayerIds($row->supply_layer_ids_json ?? null, $activeLayerIds) as $layerId) {
                $layerIds[] = $layerId;
            }
        }

        return array_values(array_unique($layerIds));
    }

    /**
     * @param array<int, string> $supplyLayerIds
     */
    private function virtualSupplyCountForLayerIds(string $gameId, array $supplyLayerIds): int
    {
        $supplyLayerIds = array_values(array_unique(array_filter($supplyLayerIds)));

        if ($supplyLayerIds === []) {
            return 0;
        }

        $profile = $this->activeVirtualStockProfile($gameId);

        if ($profile === null) {
            return 0;
        }

        $total = 0;

        foreach ($this->virtualSupplyLayers($profile) as $layer) {
            if (in_array((string) ($layer['id'] ?? ''), $supplyLayerIds, true)) {
                $total += (int) ($layer['total_capacity'] ?? 0);
            }
        }

        return $total;
    }

    /**
     * @param array<int, string> $fallbackLayerIds
     * @return array<int, string>
     */
    private function snapshotLayerIds(mixed $json, array $fallbackLayerIds): array
    {
        $decoded = $this->decodeJsonObject($json);
        $ids = array_values(array_filter(array_map(
            fn (mixed $value): string => trim((string) $value),
            $decoded,
        )));

        return $ids === [] ? $fallbackLayerIds : $ids;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function partnerPercentSumErrors(string $gameId, string $partnerId, int $basisPoints): array
    {
        $activeSum = (int) DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('partner_id', '!=', $partnerId)
            ->where('status', 'active')
            ->sum('percent_basis_points');

        return $activeSum + $basisPoints > self::VIRTUAL_MAX_BP
            ? ['allocation_percent' => ['The total active partner allocation percent for this game may not exceed 100.']]
            : [];
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function partnerPercentUsageErrors(string $gameId, string $partnerId, int $targetCount): array
    {
        $usedCount = $this->partnerUsedVirtualCount($gameId, $partnerId);

        return $targetCount < $usedCount
            ? ['allocation_percent' => ['The allocation_percent cannot be below already reserved or sold virtual stock for this partner.']]
            : [];
    }

    private function partnerUsedVirtualCount(string $gameId, string $partnerId): int
    {
        $counterUsed = (int) DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', 'partner')
            ->where('scope_id', $partnerId)
            ->where('dimension', 'full_number')
            ->selectRaw('COALESCE(SUM(reserved_count + sold_count), 0) as used_count')
            ->value('used_count');
        $materializedUsed = (int) DB::table('local_stock_items')
            ->where('game_id', $gameId)
            ->where('partner_id', $partnerId)
            ->whereNotNull('virtual_stock_ref')
            ->whereIn('status', ['reserved', 'sold'])
            ->count();

        return max($counterUsed, $materializedUsed);
    }

    private function upsertPartnerDistribution(
        string $gameId,
        string $partnerId,
        string $tenantId,
        int $basisPoints,
        string $status,
        mixed $now,
    ): void {
        DB::table('stock_partner_distributions')->updateOrInsert(
            ['id' => $this->stableId('spd', $gameId.':'.$partnerId)],
            [
                'game_id' => $gameId,
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'percent_basis_points' => max(0, $basisPoints),
                'status' => $status,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );
    }

    private function invalidatePartnerDistributionGeneratedCounts(string $gameId): void
    {
        DB::table('virtual_stock_pattern_generated_counts')
            ->where('game_id', $gameId)
            ->where('scope_type', 'partner')
            ->delete();
    }

    /**
     * @return array<string, mixed>|null
     */
    private function partnerStockPercentResource(string $gameId, string $partnerId): ?array
    {
        $row = DB::table('stock_partner_distributions')
            ->join('partners', 'partners.id', '=', 'stock_partner_distributions.partner_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'stock_partner_distributions.tenant_id')
            ->join('games', 'games.id', '=', 'stock_partner_distributions.game_id')
            ->where('stock_partner_distributions.game_id', $gameId)
            ->where('stock_partner_distributions.partner_id', $partnerId)
            ->first([
                'stock_partner_distributions.*',
                'partners.code as partner_code',
                'partners.name as partner_name',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
                'games.code as game_code',
                'games.name as game_name',
            ]);

        if ($row === null) {
            return null;
        }

        $generatedSupplyCount = $this->activeVirtualSupplyCount((string) $row->game_id);
        $targetAllocationCount = $this->allocationTargetCountForPercent((string) $row->game_id, (int) $row->percent_basis_points);
        $usedCount = $this->partnerUsedVirtualCount((string) $row->game_id, (string) $row->partner_id);

        return [
            'id' => (string) $row->id,
            'game_id' => (string) $row->game_id,
            'game_code' => (string) $row->game_code,
            'game_name' => (string) $row->game_name,
            'partner_id' => (string) $row->partner_id,
            'partner_code' => (string) $row->partner_code,
            'partner_name' => (string) $row->partner_name,
            'tenant_id' => $row->tenant_id,
            'tenant_code' => $row->tenant_code,
            'tenant_name' => $row->tenant_name,
            'allocation_percent' => $this->percentFromBasisPoints((int) $row->percent_basis_points),
            'allocation_percent_basis_points' => (int) $row->percent_basis_points,
            'generated_supply_count' => $generatedSupplyCount,
            'target_allocation_count' => $targetAllocationCount,
            'used_count' => $usedCount,
            'remaining_count' => max(0, $targetAllocationCount - $usedCount),
            'status' => (string) $row->status,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function allocationPayloadHash(array $payload): string
    {
        return $this->payloadHash([
            'partner_id' => trim((string) ($payload['partner_id'] ?? '')),
            'tenant_id' => trim((string) ($payload['tenant_id'] ?? '')),
            'game_id' => trim((string) ($payload['game_id'] ?? '')),
            'allocation_percent_basis_points' => $this->percentBasisPointsFrom($payload['allocation_percent'] ?? null),
            'requested_count' => array_key_exists('requested_count', $payload) ? $this->integerFrom($payload['requested_count']) : null,
            'reason' => trim((string) ($payload['reason'] ?? '')),
        ]);
    }

    private function canArchiveStatus(string $status): bool
    {
        return in_array($status, self::CLOSED_GAME_STATUSES, true);
    }

    private function gameIsClosedForNextOpening(object $game): bool
    {
        return $game->closed_at !== null || in_array((string) $game->status, self::CLOSED_GAME_STATUSES, true);
    }

    private function gameHasRecordedRewardResult(string $gameId): bool
    {
        return RewardResult::query()
            ->where('game_id', $gameId)
            ->whereIn('status', self::RECORDED_REWARD_RESULT_STATUSES)
            ->exists();
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
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    private function virtualStockNumberDetailResource(object $profile, object $number, array $queryParams): array
    {
        $gameId = (string) $profile->game_id;
        $fullNumber = (string) $number->full_number;
        $front3 = (string) $number->front3;
        $back3 = (string) $number->back3;
        $back2 = (string) $number->back2;
        $capacity = $this->virtualCapacityForNumber($fullNumber, $profile);
        $centralCounterMap = $this->virtualScopedCounterMap($gameId, 'central', 'central', $number);
        $centralLimits = $this->virtualLimits($gameId, 'central', 'central');
        $centralOverrides = $this->virtualLimitOverrideMapForNumbers($gameId, 'central', 'central', [$number]);
        $centralLimitDetails = $this->virtualLimitDetails($centralLimits, $centralOverrides, $centralCounterMap, $front3, $back3, $back2);
        $fullCounter = $centralCounterMap['full_number:'.$fullNumber] ?? ['reserved' => 0, 'sold' => 0];
        $reservedCount = min($capacity, (int) $fullCounter['reserved']);
        $soldCount = min($capacity, (int) $fullCounter['sold']);
        $availableCount = min(
            max(0, $capacity - $reservedCount - $soldCount),
            $this->remainingFromLimitDetail($centralLimitDetails['front3']),
            $this->remainingFromLimitDetail($centralLimitDetails['back3']),
            $this->remainingFromLimitDetail($centralLimitDetails['back2']),
        );
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($queryParams);
        $stockItems = $this->stockTicketDetailRows($gameId, $fullNumber);
        $localItems = $this->localStockTicketDetailRows($gameId, $fullNumber, $scopeType === 'partner' ? $scopeId : null);
        $virtualCopies = $this->virtualCopyDetailRows($gameId, $fullNumber, $capacity, $stockItems, $localItems);
        $partnerLimits = null;

        if ($scopeType === 'partner') {
            $partnerCounterMap = $this->virtualScopedCounterMap($gameId, 'partner', $scopeId, $number);
            $partnerDefaultLimits = $this->virtualLimits($gameId, 'partner', $scopeId);
            $partnerOverrides = $this->virtualLimitOverrideMapForNumbers($gameId, 'partner', $scopeId, [$number]);
            $partnerLimitDetails = $this->virtualLimitDetails($partnerDefaultLimits, $partnerOverrides, $partnerCounterMap, $front3, $back3, $back2);
            $copyIndexes = $this->virtualPartnerCopyIndexes($scopeId, $gameId, $fullNumber, $capacity);
            $partnerFullCounter = $partnerCounterMap['full_number:'.$fullNumber] ?? ['reserved' => 0, 'sold' => 0];
            $partnerUsed = (int) $partnerFullCounter['reserved'] + (int) $partnerFullCounter['sold'];
            $partnerAvailable = min(
                max(0, count($copyIndexes) - $partnerUsed),
                $this->remainingFromLimitDetail($centralLimitDetails['front3']),
                $this->remainingFromLimitDetail($centralLimitDetails['back3']),
                $this->remainingFromLimitDetail($centralLimitDetails['back2']),
                $this->remainingFromLimitDetail($partnerLimitDetails['front3']),
                $this->remainingFromLimitDetail($partnerLimitDetails['back3']),
                $this->remainingFromLimitDetail($partnerLimitDetails['back2']),
            );
            $partnerLimits = [
                'scope_type' => 'partner',
                'scope_id' => $scopeId,
                'assigned_capacity' => count($copyIndexes),
                'available_count' => max(0, $partnerAvailable),
                'reserved_count' => (int) $partnerFullCounter['reserved'],
                'sold_count' => (int) $partnerFullCounter['sold'],
                'copy_indexes' => $copyIndexes,
                'limits' => $partnerLimitDetails,
            ];
        }

        return [
            'id' => $gameId.':'.$fullNumber,
            'stock_mode' => 'virtual',
            'profile_id' => (string) $profile->id,
            'batch_id' => $this->latestVirtualBatchId($gameId),
            'game_id' => $gameId,
            'full_number' => $fullNumber,
            'front3' => $front3,
            'back3' => $back3,
            'back2' => $back2,
            'generated_capacity' => $capacity,
            'total_count' => $capacity,
            'available_count' => max(0, $availableCount),
            'reserved_count' => $reservedCount,
            'allocated_count' => $reservedCount,
            'sold_count' => $soldCount,
            'materialized_stock_count' => count($stockItems),
            'materialized_local_stock_count' => count($localItems),
            'unmaterialized_capacity_count' => max(0, $capacity - count($stockItems)),
            'central_limits' => [
                'scope_type' => 'central',
                'scope_id' => 'central',
                'limits' => $centralLimitDetails,
            ],
            'partner_limits' => $partnerLimits,
            'virtual_copies' => $virtualCopies,
            'stock_items' => $stockItems,
            'local_stock_items' => $localItems,
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    private function materializedStockNumberDetailResource(string $gameId, string $fullNumber, array $queryParams): array
    {
        [$scopeType, $scopeId] = $this->virtualScopeFromQuery($queryParams);
        $stockItems = $this->stockTicketDetailRows($gameId, $fullNumber);
        $localItems = $this->localStockTicketDetailRows($gameId, $fullNumber, $scopeType === 'partner' ? $scopeId : null);
        $counts = ['available' => 0, 'allocated' => 0, 'sold' => 0, 'recalled' => 0, 'voided' => 0];

        foreach ($stockItems as $item) {
            $status = (string) ($item['status'] ?? '');
            if (array_key_exists($status, $counts)) {
                $counts[$status]++;
            }
        }

        return [
            'id' => $gameId.':'.$fullNumber,
            'stock_mode' => 'materialized',
            'profile_id' => null,
            'batch_id' => $stockItems[0]['batch_id'] ?? null,
            'game_id' => $gameId,
            'full_number' => $fullNumber,
            'front3' => $stockItems[0]['front3'] ?? substr($fullNumber, 0, 3),
            'back3' => $stockItems[0]['back3'] ?? substr($fullNumber, -3),
            'back2' => $stockItems[0]['back2'] ?? substr($fullNumber, -2),
            'generated_capacity' => count($stockItems),
            'total_count' => count($stockItems),
            'available_count' => $counts['available'],
            'reserved_count' => 0,
            'allocated_count' => $counts['allocated'],
            'sold_count' => $counts['sold'],
            'materialized_stock_count' => count($stockItems),
            'materialized_local_stock_count' => count($localItems),
            'unmaterialized_capacity_count' => 0,
            'central_limits' => null,
            'partner_limits' => null,
            'stock_items' => $stockItems,
            'local_stock_items' => $localItems,
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function stockTicketDetailRows(string $gameId, string $fullNumber): array
    {
        return StockItem::query()
            ->where('game_id', $gameId)
            ->where('full_number', $fullNumber)
            ->orderBy('virtual_copy_index')
            ->orderBy('id')
            ->get()
            ->map(fn (object $stock): array => [
                'id' => (string) $stock->id,
                'game_id' => (string) $stock->game_id,
                'batch_id' => $stock->batch_id,
                'full_number' => (string) $stock->full_number,
                'front3' => $stock->front3,
                'back3' => $stock->back3,
                'back2' => $stock->back2,
                'status' => (string) $stock->status,
                'partner_id' => $stock->partner_id,
                'tenant_id' => $stock->tenant_id,
                'owner' => $this->ownershipResource($stock->partner_id, $stock->tenant_id, null),
                'allocation_id' => $stock->allocation_id,
                'virtual_stock_ref' => $stock->virtual_stock_ref,
                'virtual_copy_index' => $stock->virtual_copy_index === null ? null : (int) $stock->virtual_copy_index,
                'image_url' => PublicUrl::normalizeAssetUrl($stock->image_url ?? null),
                'image_thumb_url' => PublicUrl::normalizeAssetUrl($stock->image_thumb_url ?? null),
                'image_generation_status' => $stock->image_generation_status ?? null,
                'image_generation_error' => $stock->image_generation_error ?? null,
                'image_generated_at' => $stock->image_generated_at ?? null,
                'created_at' => $stock->created_at,
                'updated_at' => $stock->updated_at,
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function localStockTicketDetailRows(string $gameId, string $fullNumber, ?string $partnerId): array
    {
        $query = DB::table('local_stock_items')
            ->where('game_id', $gameId)
            ->where('full_number', $fullNumber);

        if ($partnerId !== null) {
            $query->where('partner_id', $partnerId);
        }

        return $query
            ->orderBy('virtual_copy_index')
            ->orderBy('id')
            ->get()
            ->map(fn (object $stock): array => [
                'id' => (string) $stock->id,
                'tenant_id' => (string) $stock->tenant_id,
                'partner_id' => (string) $stock->partner_id,
                'owner' => $this->ownershipResource($stock->partner_id, $stock->tenant_id, null),
                'store_id' => $stock->store_id,
                'game_id' => (string) $stock->game_id,
                'stock_item_id' => (string) $stock->stock_item_id,
                'allocation_id' => $stock->allocation_id,
                'virtual_stock_ref' => $stock->virtual_stock_ref,
                'virtual_copy_index' => $stock->virtual_copy_index === null ? null : (int) $stock->virtual_copy_index,
                'full_number' => (string) $stock->full_number,
                'front3' => $stock->front3,
                'back3' => $stock->back3,
                'back2' => $stock->back2,
                'status' => (string) $stock->status,
                'image_url' => PublicUrl::normalizeAssetUrl($stock->image_url ?? null),
                'image_thumb_url' => PublicUrl::normalizeAssetUrl($stock->image_thumb_url ?? null),
                'image_generation_status' => $stock->image_generation_status ?? null,
                'image_generation_error' => $stock->image_generation_error ?? null,
                'image_generated_at' => $stock->image_generated_at ?? null,
                'synced_at' => $stock->synced_at,
                'reserved_at' => $stock->reserved_at,
                'sold_at' => $stock->sold_at,
                'created_at' => $stock->created_at,
                'updated_at' => $stock->updated_at,
            ])
            ->all();
    }

    /**
     * @param array<int, array<string, mixed>> $stockItems
     * @param array<int, array<string, mixed>> $localItems
     * @return array<int, array<string, mixed>>
     */
    private function virtualCopyDetailRows(string $gameId, string $fullNumber, int $capacity, array $stockItems, array $localItems): array
    {
        $stockByCopy = [];
        $localByCopy = [];

        foreach ($stockItems as $stock) {
            if (($stock['virtual_copy_index'] ?? null) !== null) {
                $stockByCopy[(int) $stock['virtual_copy_index']] = $stock;
            }
        }

        foreach ($localItems as $stock) {
            if (($stock['virtual_copy_index'] ?? null) !== null) {
                $localByCopy[(int) $stock['virtual_copy_index']] = $stock;
            }
        }

        $copies = [];
        $profile = $this->activeVirtualStockProfile($gameId);
        $layers = $profile === null ? [] : $this->virtualSupplyLayers($profile);
        $allocationRowsByLayer = $layers === [] ? [] : $this->virtualAllocationRowsByLayer($gameId, $layers);
        $copyIndex = 0;

        foreach ($layers as $layer) {
            $layerId = (string) ($layer['id'] ?? '');
            $layerCapacity = $this->virtualCapacityForLayer(
                $fullNumber,
                (string) ($layer['seed'] ?? ''),
                is_array($layer['set_distribution'] ?? null) ? $layer['set_distribution'] : [],
            );
            $ownerRows = $allocationRowsByLayer[$layerId] ?? [];

            for ($localIndex = 0; $localIndex < $layerCapacity; $localIndex++, $copyIndex++) {
                $copies[] = $this->virtualCopyDetailRow(
                    $gameId,
                    $fullNumber,
                    $copyIndex,
                    $stockByCopy[$copyIndex] ?? null,
                    $localByCopy[$copyIndex] ?? null,
                    $ownerRows,
                );
            }
        }

        for (; $copyIndex < $capacity; $copyIndex++) {
            $copies[] = $this->virtualCopyDetailRow(
                $gameId,
                $fullNumber,
                $copyIndex,
                $stockByCopy[$copyIndex] ?? null,
                $localByCopy[$copyIndex] ?? null,
                [],
            );
        }

        return $copies;
    }

    /**
     * @param array<string, mixed>|null $stock
     * @param array<string, mixed>|null $local
     * @param array<int, array{partner_id: string, tenant_id: ?string, bp: int}> $ownerRows
     * @return array<string, mixed>
     */
    private function virtualCopyDetailRow(string $gameId, string $fullNumber, int $copyIndex, ?array $stock, ?array $local, array $ownerRows): array
    {
        $owner = $stock !== null || $local !== null
            ? $this->ownershipResource($stock['partner_id'] ?? $local['partner_id'] ?? null, $stock['tenant_id'] ?? $local['tenant_id'] ?? null, null)
            : $this->virtualOwnerForCopyResource($ownerRows, $fullNumber, $copyIndex);
        $materialized = $stock !== null || $local !== null;

        return [
            'virtual_copy_index' => $copyIndex,
            'virtual_stock_ref' => $stock['virtual_stock_ref'] ?? $local['virtual_stock_ref'] ?? (
                ($owner['tenant_id'] ?? null) === null ? null : 'vstock:'.$owner['tenant_id'].':'.$gameId.':'.$fullNumber.':'.$copyIndex
            ),
            'owner' => $owner,
            'owner_type' => $owner['type'],
            'owner_label' => $owner['label'],
            'stock_item_id' => $stock['id'] ?? null,
            'local_stock_item_id' => $local['id'] ?? null,
            'status' => $local['status'] ?? $stock['status'] ?? 'available',
            'materialized' => $materialized,
            'image_url' => PublicUrl::normalizeAssetUrl($local['image_url'] ?? $stock['image_url'] ?? null),
            'image_thumb_url' => PublicUrl::normalizeAssetUrl($local['image_thumb_url'] ?? $stock['image_thumb_url'] ?? null),
            'image_generation_status' => $local['image_generation_status'] ?? $stock['image_generation_status'] ?? null,
            'image_generation_error' => $local['image_generation_error'] ?? $stock['image_generation_error'] ?? null,
        ];
    }

    /**
     * @return array<int, array{partner_id: string, tenant_id: ?string, bp: int}>
     */
    private function virtualCentralOwnerRows(string $gameId): array
    {
        $distributionRows = DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->where('percent_basis_points', '>', 0)
            ->orderBy('partner_id')
            ->get(['partner_id', 'tenant_id', 'percent_basis_points'])
            ->map(fn (object $row): array => [
                'partner_id' => (string) $row->partner_id,
                'tenant_id' => $row->tenant_id === null ? null : (string) $row->tenant_id,
                'bp' => (int) $row->percent_basis_points,
            ])
            ->all();

        if ($distributionRows !== []) {
            return $distributionRows;
        }

        return [];
    }

    /**
     * @param array<int, array{partner_id: string, tenant_id: ?string, bp: int}> $rows
     * @return array{type: string, label: string, partner_id: ?string, partner_code: ?string, partner_name: ?string, tenant_id: ?string, agent_id: ?string}
     */
    private function virtualOwnerForCopyResource(array $rows, string $fullNumber, int $copyIndex): array
    {
        if ($rows === []) {
            return $this->ownershipResource(null, null, null);
        }

        $ownerPartnerId = $this->virtualOwnerPartnerForCopy(
            array_map(fn (array $row): array => ['partner_id' => $row['partner_id'], 'bp' => $row['bp']], $rows),
            $fullNumber,
            $copyIndex,
        );

        foreach ($rows as $row) {
            if ($row['partner_id'] === $ownerPartnerId) {
                return $this->ownershipResource($row['partner_id'], $row['tenant_id'], null);
            }
        }

        return $this->ownershipResource(null, null, null);
    }

    /**
     * @return array{type: string, label: string, partner_id: ?string, partner_code: ?string, partner_name: ?string, tenant_id: ?string, agent_id: ?string}
     */
    private function ownershipResource(mixed $partnerId, mixed $tenantId, mixed $agentId): array
    {
        $partnerId = $partnerId === null || $partnerId === '' ? null : (string) $partnerId;
        $tenantId = $tenantId === null || $tenantId === '' ? null : (string) $tenantId;
        $agentId = $agentId === null || $agentId === '' ? null : (string) $agentId;

        if ($agentId !== null) {
            return [
                'type' => 'agent',
                'label' => 'agent',
                'partner_id' => $partnerId,
                'partner_code' => null,
                'partner_name' => null,
                'tenant_id' => $tenantId,
                'agent_id' => $agentId,
            ];
        }

        if ($partnerId !== null || $tenantId !== null) {
            $partnerLabel = $this->ownerPartnerLabel($partnerId);

            return [
                'type' => 'partner',
                'label' => $partnerLabel['label'],
                'partner_id' => $partnerId,
                'partner_code' => $partnerLabel['code'],
                'partner_name' => $partnerLabel['name'],
                'tenant_id' => $tenantId,
                'agent_id' => null,
            ];
        }

        return [
            'type' => 'unassigned',
            'label' => 'no_agent',
            'partner_id' => null,
            'partner_code' => null,
            'partner_name' => null,
            'tenant_id' => null,
            'agent_id' => null,
        ];
    }

    /**
     * @return array{code: ?string, name: ?string, label: string}
     */
    private function ownerPartnerLabel(?string $partnerId): array
    {
        if ($partnerId === null || $partnerId === '') {
            return ['code' => null, 'name' => null, 'label' => 'partner'];
        }

        if (! array_key_exists($partnerId, $this->ownerPartnerLabelCache)) {
            $partner = Partner::query()->whereKey($partnerId)->first(['code', 'name']);
            $name = $partner?->name === null ? null : (string) $partner->name;
            $code = $partner?->code === null ? null : (string) $partner->code;

            $this->ownerPartnerLabelCache[$partnerId] = [
                'code' => $code,
                'name' => $name,
                'label' => $name !== null && $name !== '' ? $name : ($code !== null && $code !== '' ? $code : $partnerId),
            ];
        }

        return $this->ownerPartnerLabelCache[$partnerId];
    }

    private function tenantIdForPartner(string $partnerId): ?string
    {
        $tenantId = DB::table('partner_tenants')
            ->where('partner_id', $partnerId)
            ->orderBy('id')
            ->value('id');

        return $tenantId === null ? null : (string) $tenantId;
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

    /**
     * @param array{reserved: int, sold: int} $counterTotals
     * @return array<string, mixed>
     */
    private function virtualStockGroupResource(object $profile, array $counterTotals, ?string $batchId): array
    {
        $totalCount = (int) $profile->total_capacity;
        $reservedCount = min($totalCount, (int) $counterTotals['reserved']);
        $soldCount = min($totalCount, (int) $counterTotals['sold']);

        return [
            'id' => (string) $profile->id,
            'stock_mode' => 'virtual',
            'profile_id' => (string) $profile->id,
            'batch_id' => $batchId,
            'game_id' => (string) $profile->game_id,
            'full_number' => 'Virtual stock',
            'sample_stock_item_id' => null,
            'total_count' => $totalCount,
            'available_count' => max(0, $totalCount - $reservedCount - $soldCount),
            'allocated_count' => $reservedCount,
            'sold_count' => $soldCount,
            'recalled_count' => 0,
            'first_created_at' => $profile->created_at,
            'last_updated_at' => $profile->updated_at,
        ];
    }

    /**
     * @param array<string, array{reserved: int, sold: int}> $counterMap
     * @param array{back2_limit: int, back3_limit: int, front3_limit: int} $centralLimits
     * @param array<string, int> $limitOverrides
     * @return array<string, mixed>
     */
    private function virtualStockNumberGroupResource(
        object $profile,
        object $number,
        array $counterMap,
        array $centralLimits,
        array $limitOverrides,
        ?string $batchId,
        string $scopeType = 'central',
        string $scopeId = 'central',
        ?array $scopedCounterMap = null,
        ?array $scopedLimits = null,
        ?array $scopedLimitOverrides = null,
        ?string $tenantId = null,
    ): array
    {
        $fullNumber = (string) $number->full_number;
        $front3 = (string) $number->front3;
        $back3 = (string) $number->back3;
        $back2 = (string) $number->back2;
        $generatedCapacity = property_exists($number, 'total_count')
            ? (int) $number->total_count
            : $this->virtualCapacityForNumber($fullNumber, $profile);
        $totalCount = $generatedCapacity;
        $fullCounter = $counterMap['full_number:'.$fullNumber] ?? ['reserved' => 0, 'sold' => 0];
        $reservedCount = min($totalCount, (int) $fullCounter['reserved']);
        $soldCount = min($totalCount, (int) $fullCounter['sold']);
        $usedCount = $reservedCount + $soldCount;
        $availableCount = min(
            max(0, $totalCount - $usedCount),
            $this->virtualRemainingForPattern($counterMap, 'front3', $front3, $this->virtualEffectiveLimit($limitOverrides, 'front3', $front3, $centralLimits['front3_limit'])),
            $this->virtualRemainingForPattern($counterMap, 'back3', $back3, $this->virtualEffectiveLimit($limitOverrides, 'back3', $back3, $centralLimits['back3_limit'])),
            $this->virtualRemainingForPattern($counterMap, 'back2', $back2, $this->virtualEffectiveLimit($limitOverrides, 'back2', $back2, $centralLimits['back2_limit'])),
        );

        if ($scopeType === 'partner') {
            $scopedCounterMap ??= [];
            $scopedLimits ??= $this->virtualLimits((string) $profile->game_id, 'partner', $scopeId);
            $scopedLimitOverrides ??= [];
            $assignedCount = count($this->virtualPartnerCopyIndexes($scopeId, (string) $profile->game_id, $fullNumber, $generatedCapacity));
            $partnerFullCounter = $scopedCounterMap['full_number:'.$fullNumber] ?? ['reserved' => 0, 'sold' => 0];
            $reservedCount = min($assignedCount, (int) $partnerFullCounter['reserved']);
            $soldCount = min($assignedCount, (int) $partnerFullCounter['sold']);
            $usedCount = $reservedCount + $soldCount;
            $availableCount = min(
                max(0, $assignedCount - $usedCount),
                $this->virtualRemainingForPattern($counterMap, 'front3', $front3, $this->virtualEffectiveLimit($limitOverrides, 'front3', $front3, $centralLimits['front3_limit'])),
                $this->virtualRemainingForPattern($counterMap, 'back3', $back3, $this->virtualEffectiveLimit($limitOverrides, 'back3', $back3, $centralLimits['back3_limit'])),
                $this->virtualRemainingForPattern($counterMap, 'back2', $back2, $this->virtualEffectiveLimit($limitOverrides, 'back2', $back2, $centralLimits['back2_limit'])),
                $this->virtualRemainingForPattern($scopedCounterMap, 'front3', $front3, $this->virtualEffectiveLimit($scopedLimitOverrides, 'front3', $front3, $scopedLimits['front3_limit'])),
                $this->virtualRemainingForPattern($scopedCounterMap, 'back3', $back3, $this->virtualEffectiveLimit($scopedLimitOverrides, 'back3', $back3, $scopedLimits['back3_limit'])),
                $this->virtualRemainingForPattern($scopedCounterMap, 'back2', $back2, $this->virtualEffectiveLimit($scopedLimitOverrides, 'back2', $back2, $scopedLimits['back2_limit'])),
            );
            $totalCount = $assignedCount;
        }

        return [
            'id' => $scopeType === 'partner'
                ? (string) $profile->game_id.':'.$scopeId.':'.$fullNumber
                : (string) $profile->game_id.':'.$fullNumber,
            'stock_mode' => 'virtual',
            'scope_type' => $scopeType,
            'scope_id' => $scopeId,
            'partner_id' => $scopeType === 'partner' ? $scopeId : null,
            'tenant_id' => $scopeType === 'partner' ? $tenantId : null,
            'profile_id' => (string) $profile->id,
            'batch_id' => $batchId,
            'game_id' => (string) $profile->game_id,
            'full_number' => $fullNumber,
            'front3' => $front3,
            'back3' => $back3,
            'back2' => $back2,
            'sample_stock_item_id' => null,
            'total_count' => $totalCount,
            'available_count' => max(0, $availableCount),
            'allocated_count' => $reservedCount,
            'sold_count' => $soldCount,
            'recalled_count' => 0,
            'first_created_at' => $profile->created_at,
            'last_updated_at' => $this->virtualLatestCounterUpdatedAt($counterMap, [$fullNumber, $front3, $back3, $back2]) ?? $profile->updated_at,
        ];
    }

    /**
     * @param array<int, string> $gameIds
     * @return array<string, array{reserved: int, sold: int}>
     */
    private function virtualCounterTotals(array $gameIds): array
    {
        $gameIds = array_values(array_unique(array_filter($gameIds)));
        if ($gameIds === []) {
            return [];
        }

        $rows = DB::table('virtual_stock_counters')
            ->whereIn('game_id', $gameIds)
            ->where('dimension', 'full_number')
            ->select('game_id', DB::raw('SUM(reserved_count) as reserved_count'), DB::raw('SUM(sold_count) as sold_count'))
            ->groupBy('game_id')
            ->get();

        $totals = [];
        foreach ($rows as $row) {
            $totals[(string) $row->game_id] = [
                'reserved' => (int) $row->reserved_count,
                'sold' => (int) $row->sold_count,
            ];
        }

        return $totals;
    }

    /**
     * @param array<int, object> $numbers
     * @return array<string, array{reserved: int, sold: int, updated_at?: mixed}>
     */
    private function virtualCounterMap(string $gameId, array $numbers, string $scopeType = 'central', string $scopeId = 'central'): array
    {
        if ($numbers === []) {
            return [];
        }

        $values = [
            'full_number' => [],
            'front3' => [],
            'back3' => [],
            'back2' => [],
        ];

        foreach ($numbers as $number) {
            $values['full_number'][] = (string) $number->full_number;
            $values['front3'][] = (string) $number->front3;
            $values['back3'][] = (string) $number->back3;
            $values['back2'][] = (string) $number->back2;
        }

        $rows = DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where(function ($query) use ($values): void {
                foreach ($values as $dimension => $dimensionValues) {
                    $dimensionValues = array_values(array_unique($dimensionValues));
                    if ($dimensionValues === []) {
                        continue;
                    }

                    $query->orWhere(function ($nested) use ($dimension, $dimensionValues): void {
                        $nested
                            ->where('dimension', $dimension)
                            ->whereIn('value', $dimensionValues);
                    });
                }
            })
            ->get(['dimension', 'value', 'reserved_count', 'sold_count', 'updated_at']);

        $map = [];
        foreach ($rows as $row) {
            $map[(string) $row->dimension.':'.(string) $row->value] = [
                'reserved' => (int) $row->reserved_count,
                'sold' => (int) $row->sold_count,
                'updated_at' => $row->updated_at,
            ];
        }

        return $map;
    }

    /**
     * @return array<string, array{reserved: int, sold: int, updated_at?: mixed}>
     */
    private function virtualScopedCounterMap(string $gameId, string $scopeType, string $scopeId, object $number): array
    {
        $values = [
            'full_number' => (string) $number->full_number,
            'front3' => (string) $number->front3,
            'back3' => (string) $number->back3,
            'back2' => (string) $number->back2,
        ];

        $rows = DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where(function ($query) use ($values): void {
                foreach ($values as $dimension => $value) {
                    $query->orWhere(function ($nested) use ($dimension, $value): void {
                        $nested->where('dimension', $dimension)->where('value', $value);
                    });
                }
            })
            ->get(['dimension', 'value', 'reserved_count', 'sold_count', 'updated_at']);

        $map = [];
        foreach ($rows as $row) {
            $map[(string) $row->dimension.':'.(string) $row->value] = [
                'reserved' => (int) $row->reserved_count,
                'sold' => (int) $row->sold_count,
                'updated_at' => $row->updated_at,
            ];
        }

        return $map;
    }

    /**
     * @return array{back2_limit: int, back3_limit: int, front3_limit: int}
     */
    private function virtualCentralLimits(string $gameId): array
    {
        return $this->virtualLimits($gameId, 'central', 'central');
    }

    /**
     * @return array{back2_limit: int, back3_limit: int, front3_limit: int}
     */
    private function virtualLimits(string $gameId, string $scopeType, string $scopeId): array
    {
        $fallback = $this->defaultStockPatternCoverageForScope($scopeType);
        $row = DB::table('stock_sale_limit_settings')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->first();

        return [
            'back2_limit' => $row?->back2_limit === null ? $fallback['back2_limit'] : (int) $row->back2_limit,
            'back3_limit' => $row?->back3_limit === null ? $fallback['back3_limit'] : (int) $row->back3_limit,
            'front3_limit' => $row?->front3_limit === null ? $fallback['front3_limit'] : (int) $row->front3_limit,
        ];
    }

    /**
     * @return array<string, array{limit: int, updated_at: mixed}>
     */
    private function virtualLimitOverrideRows(string $gameId, string $scopeType, string $scopeId, string $dimension): array
    {
        return DB::table('stock_sale_limit_overrides')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->get(['value', 'limit', 'updated_at'])
            ->mapWithKeys(fn (object $row): array => [
                (string) $row->value => [
                    'limit' => (int) $row->limit,
                    'updated_at' => $row->updated_at,
                ],
            ])
            ->all();
    }

    /**
     * @param array<int, object> $numbers
     * @return array<string, int>
     */
    private function virtualLimitOverrideMapForNumbers(string $gameId, string $scopeType, string $scopeId, array $numbers): array
    {
        $values = [
            'front3' => [],
            'back3' => [],
            'back2' => [],
        ];

        foreach ($numbers as $number) {
            $values['front3'][] = (string) $number->front3;
            $values['back3'][] = (string) $number->back3;
            $values['back2'][] = (string) $number->back2;
        }

        $rows = DB::table('stock_sale_limit_overrides')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where(function ($query) use ($values): void {
                foreach ($values as $dimension => $dimensionValues) {
                    $dimensionValues = array_values(array_unique($dimensionValues));
                    if ($dimensionValues === []) {
                        continue;
                    }

                    $query->orWhere(function ($nested) use ($dimension, $dimensionValues): void {
                        $nested
                            ->where('dimension', $dimension)
                            ->whereIn('value', $dimensionValues);
                    });
                }
            })
            ->get(['dimension', 'value', 'limit']);

        $map = [];
        foreach ($rows as $row) {
            $map[(string) $row->dimension.':'.(string) $row->value] = (int) $row->limit;
        }

        return $map;
    }

    private function virtualEffectiveLimit(array $overrides, string $dimension, string $value, int $defaultLimit): int
    {
        return $overrides[$dimension.':'.$value] ?? $defaultLimit;
    }

    /**
     * @param array{back2_limit: int, back3_limit: int, front3_limit: int} $limits
     * @param array<string, int> $overrides
     * @param array<string, array{reserved: int, sold: int, updated_at?: mixed}> $counterMap
     * @return array<string, array<string, mixed>>
     */
    private function virtualLimitDetails(array $limits, array $overrides, array $counterMap, string $front3, string $back3, string $back2): array
    {
        $values = [
            'front3' => $front3,
            'back3' => $back3,
            'back2' => $back2,
        ];
        $details = [];

        foreach ($values as $dimension => $value) {
            $defaultLimit = $limits[$dimension.'_limit'];
            $overrideLimit = $overrides[$dimension.':'.$value] ?? null;
            $effectiveLimit = $overrideLimit ?? $defaultLimit;
            $counter = $counterMap[$dimension.':'.$value] ?? ['reserved' => 0, 'sold' => 0];
            $usedCount = (int) $counter['reserved'] + (int) $counter['sold'];

            $details[$dimension] = [
                'dimension' => $dimension,
                'value' => $value,
                'default_limit' => $this->publicLimitValue($defaultLimit),
                'override_limit' => $overrideLimit,
                'effective_limit' => $this->publicLimitValue($effectiveLimit),
                'reserved_count' => (int) $counter['reserved'],
                'sold_count' => (int) $counter['sold'],
                'used_count' => $usedCount,
                'remaining_limit' => $effectiveLimit >= self::VIRTUAL_UNLIMITED ? null : max(0, $effectiveLimit - $usedCount),
            ];
        }

        return $details;
    }

    /**
     * @param array<string, mixed> $detail
     */
    private function remainingFromLimitDetail(array $detail): int
    {
        return $detail['remaining_limit'] === null ? self::VIRTUAL_UNLIMITED : (int) $detail['remaining_limit'];
    }

    private function publicLimitValue(int $limit): ?int
    {
        return $limit >= self::VIRTUAL_UNLIMITED ? null : $limit;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{0: string, 1: string}
     */
    private function virtualScopeFromQuery(array $payload): array
    {
        $requestedScopeType = $this->nullableQueryString($payload['scope_type'] ?? null);
        $requestedPartnerId = $this->nullableQueryString($payload['scope_id'] ?? $payload['partner_id'] ?? null);
        $scopeType = $requestedScopeType === 'partner' || ($requestedScopeType === null && $requestedPartnerId !== null)
            ? 'partner'
            : 'central';
        $scopeId = $scopeType === 'partner'
            ? ($requestedPartnerId ?? '')
            : 'central';

        if ($scopeType === 'partner' && $scopeId === '') {
            $scopeType = 'central';
            $scopeId = 'central';
        }

        return [$scopeType, $scopeId];
    }

    private function normalizedLimitDimension(mixed $value): ?string
    {
        $dimension = $this->nullableQueryString($value);

        return in_array($dimension, ['back2', 'back3', 'front3'], true) ? $dimension : null;
    }

    /**
     * @param array{back2_limit: int, back3_limit: int, front3_limit: int} $limits
     * @return array{back2_limit: ?int, back3_limit: ?int, front3_limit: ?int}
     */
    private function publicVirtualLimits(array $limits): array
    {
        return [
            'back2_limit' => $limits['back2_limit'] >= self::VIRTUAL_UNLIMITED ? null : $limits['back2_limit'],
            'back3_limit' => $limits['back3_limit'] >= self::VIRTUAL_UNLIMITED ? null : $limits['back3_limit'],
            'front3_limit' => $limits['front3_limit'] >= self::VIRTUAL_UNLIMITED ? null : $limits['front3_limit'],
        ];
    }

    private function nullableLimitFromPayload(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        return (int) $value;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function partnerLimitSettingCeilingErrors(string $gameId, array $payload): array
    {
        $errors = [];
        $centralLimits = $this->virtualLimits($gameId, 'central', 'central');

        foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
            $limit = $this->nullableLimitFromPayload($payload[$field] ?? null);
            $centralLimit = $centralLimits[$field];

            if ($limit !== null && $centralLimit < self::VIRTUAL_UNLIMITED && $limit > $centralLimit) {
                $errors[$field][] = 'The '.$field.' field may not exceed the central effective limit of '.$centralLimit.'.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function limitSettingSupplyErrors(string $gameId, string $scopeType, string $scopeId, array $payload): array
    {
        $errors = [];
        $fields = [
            'back2_limit' => 'back2',
            'back3_limit' => 'back3',
            'front3_limit' => 'front3',
        ];

        foreach ($fields as $field => $dimension) {
            $limit = filter_var($payload[$field] ?? null, FILTER_VALIDATE_INT);
            if ($limit === false || (int) $limit < 0) {
                continue;
            }

            $supplyCeiling = $this->virtualDefaultLimitSupplyCeiling($gameId, $dimension, $scopeType, $scopeId);
            if ((int) $limit > $supplyCeiling) {
                $errors[$field][] = 'The '.$field.' field may not exceed generated stock of '.$supplyCeiling.'. Generate or top up stock before increasing this limit.';
            }
        }

        return $errors;
    }

    /**
     * @param mixed $overrides
     * @return array<string, array<int, string>>
     */
    private function partnerLimitOverrideCeilingErrors(string $gameId, string $dimension, mixed $overrides): array
    {
        if (! is_array($overrides)) {
            return [];
        }

        $errors = [];
        $field = $dimension.'_limit';
        $centralDefaultLimit = $this->virtualLimits($gameId, 'central', 'central')[$field];
        $centralOverrides = $this->virtualLimitOverrideRows($gameId, 'central', 'central', $dimension);

        foreach ($overrides as $index => $row) {
            if (! is_array($row) || ($row['limit'] ?? null) === null || $row['limit'] === '') {
                continue;
            }

            $limit = filter_var($row['limit'], FILTER_VALIDATE_INT);
            if ($limit === false || (int) $limit < 0) {
                continue;
            }

            $value = preg_replace('/\D+/', '', (string) ($row['value'] ?? '')) ?? '';
            $centralLimit = $centralOverrides[$value]['limit'] ?? $centralDefaultLimit;

            if ($centralLimit < self::VIRTUAL_UNLIMITED && (int) $limit > $centralLimit) {
                $errors['overrides.'.$index.'.limit'][] = 'The override limit may not exceed the central effective limit of '.$centralLimit.'.';
            }
        }

        return $errors;
    }

    /**
     * @param mixed $overrides
     * @return array<string, array<int, string>>
     */
    private function limitOverrideSupplyErrors(string $gameId, string $dimension, string $scopeType, string $scopeId, mixed $overrides): array
    {
        if (! is_array($overrides)) {
            return [];
        }

        $errors = [];
        $pad = $dimension === 'back2' ? 2 : 3;

        foreach ($overrides as $index => $row) {
            if (! is_array($row) || ($row['limit'] ?? null) === null || $row['limit'] === '') {
                continue;
            }

            $limit = filter_var($row['limit'], FILTER_VALIDATE_INT);
            if ($limit === false || (int) $limit < 0) {
                continue;
            }

            $value = preg_replace('/\D+/', '', (string) ($row['value'] ?? '')) ?? '';
            if (strlen($value) !== $pad) {
                continue;
            }

            $generatedCount = $this->virtualGeneratedSupplyForPattern($gameId, $dimension, $value, $scopeType, $scopeId);
            if ((int) $limit > $generatedCount) {
                $errors['overrides.'.$index.'.limit'][] = 'The override limit may not exceed generated stock of '.$generatedCount.'. Generate or top up stock before increasing this limit.';
            }
        }

        return $errors;
    }

    private function virtualDefaultLimitSupplyCeiling(string $gameId, string $dimension, string $scopeType, string $scopeId): int
    {
        $profile = $this->activeVirtualStockProfile($gameId);
        if ($profile === null) {
            return 0;
        }

        $counts = $this->virtualGeneratedCountsForDimension($gameId, $dimension, $scopeType, $scopeId, $profile);
        $positiveCounts = array_values(array_filter($counts, fn (int $count): bool => $count > 0));

        return $positiveCounts === [] ? 0 : min($positiveCounts);
    }

    private function virtualGeneratedSupplyForPattern(string $gameId, string $dimension, string $value, string $scopeType, string $scopeId): int
    {
        $profile = $this->activeVirtualStockProfile($gameId);
        if ($profile === null) {
            return 0;
        }

        $counts = $this->virtualGeneratedCountsForDimension($gameId, $dimension, $scopeType, $scopeId, $profile);

        return (int) ($counts[$value] ?? 0);
    }

    /**
     * @param array<string, array{reserved: int, sold: int, updated_at?: mixed}> $counterMap
     */
    private function virtualRemainingForPattern(array $counterMap, string $dimension, string $value, int $limit): int
    {
        if ($limit >= self::VIRTUAL_UNLIMITED) {
            return self::VIRTUAL_UNLIMITED;
        }

        $counter = $counterMap[$dimension.':'.$value] ?? ['reserved' => 0, 'sold' => 0];

        return max(0, $limit - ((int) $counter['reserved'] + (int) $counter['sold']));
    }

    private function virtualCapacityForNumber(string $fullNumber, object $profile): int
    {
        return $this->virtualCapacityForNumberWithLayers($fullNumber, $this->virtualSupplyLayers($profile));
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     */
    private function virtualCapacityForNumberWithLayers(string $fullNumber, array $layers): int
    {
        $capacity = 0;

        foreach ($layers as $layer) {
            $capacity += $this->virtualCapacityForLayer($fullNumber, $layer['seed'], $layer['set_distribution']);
        }

        return max(0, $capacity);
    }

    /**
     * @return array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}>
     */
    private function virtualSupplyLayers(object $profile): array
    {
        $rows = DB::table('virtual_stock_supply_layers')
            ->where('profile_id', (string) $profile->id)
            ->where('status', 'active')
            ->orderBy('created_at')
            ->orderBy('id')
            ->get();

        if ($rows->isEmpty()) {
            return [[
                'id' => (string) $profile->id,
                'seed' => (string) $profile->seed,
                'set_distribution' => $this->decodeJsonObject($profile->set_distribution_json),
                'total_capacity' => (int) $profile->total_capacity,
            ]];
        }

        return $rows->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'seed' => (string) $row->layer_seed,
            'set_distribution' => $this->decodeJsonObject($row->set_distribution_json),
            'total_capacity' => (int) $row->total_capacity,
        ])->all();
    }

    /**
     * @param array<int|string, mixed> $distribution
     */
    private function virtualCapacityForLayer(string $fullNumber, string $seed, array $distribution): int
    {
        $score = (int) hexdec(substr(hash('sha256', $seed.':'.$fullNumber.':set'), 0, 8)) % self::VIRTUAL_MAX_BP;
        $cursor = 0;

        if (is_array($distribution)) {
            foreach ($distribution as $row) {
                if (! is_array($row)) {
                    continue;
                }

                $cursor += (int) ($row['percent_basis_points'] ?? 0);

                if ($score < $cursor) {
                    return max(1, (int) ($row['set_size'] ?? 1));
                }
            }
        }

        return 1;
    }

    /**
     * @return array<int, int>
     */
    private function virtualPartnerCopyIndexes(string $partnerId, string $gameId, string $fullNumber, int $capacity): array
    {
        $profile = $this->activeVirtualStockProfile($gameId);

        if ($profile === null) {
            return [];
        }

        $layers = $this->virtualSupplyLayers($profile);

        return $this->virtualPartnerCopyIndexesForLayers(
            $partnerId,
            $fullNumber,
            $layers,
            $this->virtualAllocationRowsByLayer($gameId, $layers),
        );
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @param array<string, array<int, array{partner_id: string, tenant_id: ?string, bp: int}>> $allocationRowsByLayer
     * @return array<int, int>
     */
    private function virtualPartnerCopyIndexesForLayers(string $partnerId, string $fullNumber, array $layers, array $allocationRowsByLayer): array
    {
        $copyIndexes = [];
        $offset = 0;

        foreach ($layers as $layer) {
            $layerId = (string) ($layer['id'] ?? '');
            $layerCapacity = $this->virtualCapacityForLayer(
                $fullNumber,
                (string) ($layer['seed'] ?? ''),
                is_array($layer['set_distribution'] ?? null) ? $layer['set_distribution'] : [],
            );
            $rows = $allocationRowsByLayer[$layerId] ?? [];

            for ($localIndex = 0; $localIndex < $layerCapacity; $localIndex++) {
                $copyIndex = $offset + $localIndex;

                if ($this->virtualOwnerPartnerForCopy($rows, $fullNumber, $copyIndex) === $partnerId) {
                    $copyIndexes[] = $copyIndex;
                }
            }

            $offset += $layerCapacity;
        }

        return $copyIndexes;
    }

    /**
     * @return array<int, array{id: string, partner_id: string, tenant_id: ?string, bp: int, layer_ids: array<int, string>}>
     */
    private function virtualAllocationRowsForCache(string $gameId): array
    {
        $layerIds = $this->activeVirtualSupplyLayerIds($gameId);

        return DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->where('allocation_percent_basis_points', '>', 0)
            ->orderBy('partner_id')
            ->orderBy('id')
            ->get(['id', 'partner_id', 'tenant_id', 'allocation_percent_basis_points', 'supply_layer_ids_json'])
            ->map(fn (object $row): array => [
                'id' => (string) $row->id,
                'partner_id' => (string) $row->partner_id,
                'tenant_id' => $row->tenant_id === null ? null : (string) $row->tenant_id,
                'bp' => (int) $row->allocation_percent_basis_points,
                'layer_ids' => $this->snapshotLayerIds($row->supply_layer_ids_json ?? null, $layerIds),
            ])
            ->all();
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @return array<string, array<int, array{partner_id: string, tenant_id: ?string, bp: int}>>
     */
    private function virtualAllocationRowsByLayer(string $gameId, array $layers): array
    {
        $layerIds = array_values(array_filter(array_map(
            fn (array $layer): string => (string) ($layer['id'] ?? ''),
            $layers,
        )));

        if ($layerIds === []) {
            return [];
        }

        $rowsByLayer = array_fill_keys($layerIds, []);
        $rows = DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->where('allocation_percent_basis_points', '>', 0)
            ->orderBy('partner_id')
            ->orderBy('id')
            ->get(['id', 'partner_id', 'tenant_id', 'allocation_percent_basis_points', 'supply_layer_ids_json']);

        foreach ($rows as $row) {
            $snapshotLayerIds = $this->snapshotLayerIds($row->supply_layer_ids_json ?? null, $layerIds);

            foreach (array_values(array_intersect($layerIds, $snapshotLayerIds)) as $layerId) {
                $rowsByLayer[$layerId][] = [
                    'partner_id' => (string) $row->partner_id,
                    'tenant_id' => $row->tenant_id === null ? null : (string) $row->tenant_id,
                    'bp' => (int) $row->allocation_percent_basis_points,
                ];
            }
        }

        return $rowsByLayer;
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}> $layers
     * @return array<int, string>
     */
    private function virtualAssignedLayerIdsForPartner(string $gameId, string $partnerId, array $layers): array
    {
        $layerIds = array_values(array_filter(array_map(
            fn (array $layer): string => (string) ($layer['id'] ?? ''),
            $layers,
        )));

        if ($layerIds === []) {
            return [];
        }

        $assigned = [];
        $rows = DB::table('partner_stock_allocations')
            ->where('game_id', $gameId)
            ->where('partner_id', $partnerId)
            ->whereIn('status', self::ACTIVE_ALLOCATION_PAIR_STATUSES)
            ->whereNotNull('allocation_percent_basis_points')
            ->where('allocation_percent_basis_points', '>', 0)
            ->get(['supply_layer_ids_json']);

        foreach ($rows as $row) {
            foreach (array_intersect($layerIds, $this->snapshotLayerIds($row->supply_layer_ids_json ?? null, $layerIds)) as $layerId) {
                $assigned[] = $layerId;
            }
        }

        return array_values(array_unique($assigned));
    }

    /**
     * @param array<int, array{partner_id: string, bp: int}>|array<int, array{partner_id: string, tenant_id: ?string, bp: int}> $rows
     */
    private function virtualOwnerPartnerForCopy(array $rows, string $fullNumber, int $copyIndex): ?string
    {
        $score = (int) hexdec(substr(hash('sha256', $fullNumber.':'.$copyIndex.':partner'), 0, 8)) % self::VIRTUAL_MAX_BP;
        $cursor = 0;

        foreach ($rows as $row) {
            $cursor = min(self::VIRTUAL_MAX_BP, $cursor + max(0, (int) $row['bp']));

            if ($score < $cursor) {
                return $row['partner_id'];
            }
        }

        return null;
    }

    /**
     * @param array<string, array{reserved: int, sold: int, updated_at?: mixed}> $counterMap
     * @param array<int, string> $values
     */
    private function virtualLatestCounterUpdatedAt(array $counterMap, array $values): mixed
    {
        $latest = null;

        foreach (['full_number', 'front3', 'back3', 'back2'] as $index => $dimension) {
            $entry = $counterMap[$dimension.':'.$values[$index]] ?? null;
            if (($entry['updated_at'] ?? null) !== null && ($latest === null || (string) $entry['updated_at'] > (string) $latest)) {
                $latest = $entry['updated_at'];
            }
        }

        return $latest;
    }

    /**
     * @param array<string, mixed> $row
     * @param array<string, mixed> $queryParams
     */
    private function virtualStockGroupMatchesStatus(array $row, array $queryParams): bool
    {
        $status = $this->nullableQueryString($queryParams['status'] ?? null);
        if ($status === null) {
            return true;
        }

        return match ($status) {
            'available' => (int) $row['available_count'] > 0,
            'allocated' => ($row['scope_type'] ?? 'central') === 'partner'
                ? (int) ($row['total_count'] ?? 0) > 0
                : (int) $row['allocated_count'] > 0,
            'sold' => (int) $row['available_count'] <= 0 || (int) $row['sold_count'] > 0,
            'recalled', 'voided' => false,
            default => true,
        };
    }

    /**
     * @param array<int, string> $gameIds
     * @return array<string, string>
     */
    private function latestVirtualBatchIds(array $gameIds): array
    {
        $gameIds = array_values(array_unique(array_filter($gameIds)));
        if ($gameIds === []) {
            return [];
        }

        $rows = StockGenerationBatch::query()
            ->whereIn('game_id', $gameIds)
            ->where('type', 'virtual_profile')
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->get(['id', 'game_id']);

        $batchIds = [];
        foreach ($rows as $row) {
            $batchIds[(string) $row->game_id] ??= (string) $row->id;
        }

        return $batchIds;
    }

    private function latestVirtualBatchId(string $gameId): ?string
    {
        return $this->latestVirtualBatchIds([$gameId])[$gameId] ?? null;
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
    private function batchResource(object $batch, bool $includeChunks = false): array
    {
        $requestedCount = (int) $batch->requested_count;
        $generatedCount = (int) $batch->generated_count;

        if ((string) $batch->type === 'virtual_profile' && (string) $batch->status === 'completed') {
            $generatedCount = max($generatedCount, $requestedCount);
        }

        $resource = [
            'id' => (string) $batch->id,
            'tenant_id' => null,
            'status' => (string) $batch->status,
            'created_at' => $batch->created_at,
            'updated_at' => $batch->updated_at,
            'game_id' => (string) $batch->game_id,
            'type' => (string) $batch->type,
            'requested_count' => $requestedCount,
            'generated_count' => $generatedCount,
            'total_rounds' => (int) ($batch->total_rounds ?? 0),
            'processed_rounds' => (int) ($batch->processed_rounds ?? 0),
            'chunk_rounds' => (int) ($batch->chunk_rounds ?? 0),
            'range_start' => $batch->range_start,
            'range_end' => $batch->range_end,
            'number_digits' => (int) $batch->number_digits,
            'started_at' => $batch->started_at ?? null,
            'completed_at' => $batch->completed_at,
            'failed_at' => $batch->failed_at ?? null,
            'failure_reason' => $batch->failure_reason ?? null,
            'image_dispatch_status' => (string) $batch->type === 'generate' ? $this->imageDispatchStatus((string) $batch->status) : null,
        ];

        if ($includeChunks) {
            $resource['chunks'] = StockGenerationBatchChunk::query()
                ->where('batch_id', $batch->id)
                ->orderBy('chunk_index')
                ->get()
                ->map(fn (object $chunk): array => [
                    'id' => (string) $chunk->id,
                    'batch_id' => (string) $chunk->batch_id,
                    'chunk_index' => (int) $chunk->chunk_index,
                    'start_round' => (int) $chunk->start_round,
                    'round_count' => (int) $chunk->round_count,
                    'status' => (string) $chunk->status,
                    'attempt_count' => (int) $chunk->attempt_count,
                    'started_at' => $chunk->started_at,
                    'completed_at' => $chunk->completed_at,
                    'failed_at' => $chunk->failed_at,
                    'failure_reason' => $chunk->failure_reason,
                    'created_at' => $chunk->created_at,
                    'updated_at' => $chunk->updated_at,
                ])
                ->all();
        }

        return $resource;
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
        $partner = Partner::where('id', $allocation->partner_id)->first(['code', 'name']);
        $tenant = PartnerTenant::where('id', $allocation->tenant_id)->first(['code', 'name']);
        $game = Game::where('id', $allocation->game_id)->first(['code', 'name']);
        $distribution = DB::table('stock_partner_distributions')
            ->where('game_id', (string) $allocation->game_id)
            ->where('partner_id', (string) $allocation->partner_id)
            ->first();
        $recalledItemCount = (int) PartnerStockAllocationItem::query()
            ->where('allocation_id', (string) $allocation->id)
            ->where('status', 'recalled')
            ->count();
        $remainingItemCount = (int) PartnerStockAllocationItem::query()
            ->where('allocation_id', (string) $allocation->id)
            ->where('status', 'allocated')
            ->count();
        $recalledCount = max((int) ($allocation->recalled_count ?? 0), $recalledItemCount);
        $isPercentAllocation = $allocation->allocation_percent_basis_points !== null;
        $remainingCount = $isPercentAllocation
            ? (((string) $allocation->status === 'recalled' || (string) $allocation->status === 'cancelled')
                ? 0
                : max(0, (int) $allocation->allocated_count - $recalledCount - $this->partnerUsedVirtualCount((string) $allocation->game_id, (string) $allocation->partner_id)))
            : $remainingItemCount;

        return [
            'id' => (string) $allocation->id,
            'partner_id' => (string) $allocation->partner_id,
            'partner_code' => $partner?->code,
            'partner_name' => $partner?->name,
            'tenant_id' => (string) $allocation->tenant_id,
            'tenant_code' => $tenant?->code,
            'tenant_name' => $tenant?->name,
            'game_id' => (string) $allocation->game_id,
            'game_code' => $game?->code,
            'game_name' => $game?->name,
            'status' => (string) $allocation->status,
            'requested_count' => (int) $allocation->requested_count,
            'allocation_percent' => $allocation->allocation_percent_basis_points === null ? null : $this->percentFromBasisPoints((int) $allocation->allocation_percent_basis_points),
            'allocation_percent_basis_points' => $allocation->allocation_percent_basis_points === null ? null : (int) $allocation->allocation_percent_basis_points,
            'active_partner_percent' => $distribution === null ? null : $this->percentFromBasisPoints((int) $distribution->percent_basis_points),
            'active_partner_percent_basis_points' => $distribution === null ? null : (int) $distribution->percent_basis_points,
            'allocated_count' => (int) $allocation->allocated_count,
            'remaining_count' => $remainingCount,
            'recalled_count' => $recalledCount,
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

    private function normalizeFullNumber(string $number, int $digits): string
    {
        return str_pad($number, $digits, '0', STR_PAD_LEFT);
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
