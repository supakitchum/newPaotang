<?php

namespace App\Modules\CentralStock\Services;

use App\Jobs\GenerateLotteryImageJob;
use App\Models\Game;
use App\Models\Partner;
use App\Models\PartnerQuota;
use App\Models\PartnerStockAllocation;
use App\Models\PartnerStockAllocationItem;
use App\Models\PartnerTenant;
use App\Models\StockGenerationBatch;
use App\Models\StockItem;
use App\Models\SyncOutbox;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class CentralStockService
{
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
    public function validateGamePayload(array $payload, bool $creating): array
    {
        $errors = [];

        if ($creating || array_key_exists('code', $payload)) {
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

        if ($creating || array_key_exists('draw_at', $payload)) {
            if (! $this->canParseDate($payload['draw_at'] ?? null)) {
                $errors['draw_at'][] = 'The draw_at field must be a valid date-time.';
            }
        }

        if (array_key_exists('close_at', $payload) && $payload['close_at'] !== null && ! $this->canParseDate($payload['close_at'])) {
            $errors['close_at'][] = 'The close_at field must be a valid date-time.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::GAME_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if ($creating && array_key_exists('status', $payload) && ! in_array($payload['status'], ['draft', 'open'], true)) {
            $errors['status'][] = 'A game can only be created as draft or open.';
        }

        return $errors;
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

        return [];
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
                'code' => trim((string) $payload['code']),
                'name' => trim((string) $payload['name']),
                'draw_at' => $this->toTimestamp($payload['draw_at']),
                'close_at' => array_key_exists('close_at', $payload) && $payload['close_at'] !== null
                    ? $this->toTimestamp($payload['close_at'])
                    : null,
                'closed_at' => null,
                'archived_at' => null,
                'status' => $payload['status'] ?? 'draft',
                'metadata_json' => json_encode($this->resourceMetadata($payload), JSON_THROW_ON_ERROR),
                'created_at' => $now,
                'updated_at' => $now,
            ]);

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

            if (array_key_exists('close_at', $payload)) {
                $updates['close_at'] = $payload['close_at'] === null ? null : $this->toTimestamp($payload['close_at']);
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
        $query = StockItem::query()->orderBy('id')->limit($limit + 1);

        foreach (['game_id', 'status'] as $filter) {
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
            'data' => array_map(fn (object $stock): array => $this->stockResource($stock), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
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

        $digits = $this->integerFrom($payload['number_digits'] ?? $payload['digits'] ?? 6);

        if ($digits < 1 || $digits > 12) {
            $errors['number_digits'][] = 'The number_digits field must be between 1 and 12.';
        }

        $count = $this->integerFrom($payload['count'] ?? $payload['requested_count'] ?? null);
        $rangeEnd = $payload['end_number'] ?? $payload['to_number'] ?? $payload['range_end'] ?? null;

        if ($count < 1 && $rangeEnd === null) {
            $errors['count'][] = 'The count field must be at least 1.';
        }

        if ($count > 10000) {
            $errors['count'][] = 'The count field may not be greater than 10000 for synchronous generation.';
        }

        $start = $this->integerFrom($payload['start_number'] ?? $payload['from_number'] ?? $payload['range_start'] ?? 0);
        $end = $rangeEnd === null ? ($count > 0 ? $start + $count - 1 : $start) : $this->integerFrom($rangeEnd);

        if ($start < 0 || $end < $start) {
            $errors['range'][] = 'The requested number range is invalid.';
        }

        if (($end - $start + 1) > 10000) {
            $errors['range'][] = 'The requested range may not include more than 10000 numbers.';
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
            $normalized = $this->normalizedGeneratePayload($payload);
            $batch = $this->ensureStockBatch('generate', $normalized, $actor, $request);
            $now = now();

            $rows = [];
            $stockIds = [];

            foreach ($normalized['numbers'] as $index => $number) {
                $stockIds[$index] = $this->stableId('stk', $normalized['game_id'].':'.$number);
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
                StockItem::query()->insertOrIgnore($rows);
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
            $numbers = array_values(array_unique($this->numbersFromImportPayload($payload)));
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
            $now = now();
            $rows = [];
            $stockIds = [];

            foreach ($normalized['numbers'] as $index => $number) {
                $stockIds[$index] = $this->stableId('stk', $gameId.':'.$number);
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
                StockItem::query()->insertOrIgnore($rows);
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
     * @return array{game_id: string, requested_count: int, range_start: string, range_end: string, number_digits: int, numbers: array<int, string>}
     */
    private function normalizedGeneratePayload(array $payload): array
    {
        $digits = max(1, min(12, $this->integerFrom($payload['number_digits'] ?? $payload['digits'] ?? 6)));
        $start = $this->integerFrom($payload['start_number'] ?? $payload['from_number'] ?? $payload['range_start'] ?? 0);
        $count = $this->integerFrom($payload['count'] ?? $payload['requested_count'] ?? null);
        $rangeEnd = $payload['end_number'] ?? $payload['to_number'] ?? $payload['range_end'] ?? null;
        $end = $rangeEnd === null ? $start + $count - 1 : $this->integerFrom($rangeEnd);
        $numbers = [];

        for ($number = $start; $number <= $end; $number++) {
            $numbers[] = $this->normalizeFullNumber((string) $number, $digits);
        }

        return [
            'game_id' => trim((string) $payload['game_id']),
            'requested_count' => count($numbers),
            'range_start' => $this->normalizeFullNumber((string) $start, $digits),
            'range_end' => $this->normalizeFullNumber((string) $end, $digits),
            'number_digits' => $digits,
            'numbers' => $numbers,
        ];
    }

    /**
     * @param array<string, mixed> $normalized
     * @return array{id: string}
     */
    private function ensureStockBatch(string $type, array $normalized, AdminSessionContext $actor, Request $request): array
    {
        $payloadHash = $this->payloadHash($normalized);
        $batchId = $this->stableId('stb', $type.':'.$payloadHash);
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
        }

        return ['id' => $batchId];
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

    private function toTimestamp(mixed $value): string
    {
        return Carbon::parse((string) $value)->toISOString();
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
