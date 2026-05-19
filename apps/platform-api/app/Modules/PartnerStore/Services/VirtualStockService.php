<?php

namespace App\Modules\PartnerStore\Services;

use App\Jobs\GeneratePartnerLotteryImageJob;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\PartnerQuota;
use App\Models\PartnerTenant;
use App\Models\StockGenerationBatch;
use App\Models\StockItem;
use App\Models\StockReservation;
use App\Models\StockReservationItem;
use App\Modules\CentralStock\Services\StockCoverageRealtimeService;
use App\Modules\PartnerStore\Events\StockAvailabilityUpdated;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class VirtualStockService
{
    private const MAX_BP = 10000;
    private const UNLIMITED = 2147483647;
    private const STOCK_PATTERN_COVERAGE_SETTING_KEY = 'stock_pattern_coverage_default';

    public function __construct(
        private readonly StockCoverageRealtimeService $coverageRealtime,
        private readonly AuditLogger $auditLogger,
    ) {
    }

    public function isGeneratePayload(array $payload): bool
    {
        $mode = (string) ($payload['generation_mode'] ?? '');

        if (in_array($mode, ['quota_random', 'quota', 'physical'], true)) {
            return false;
        }

        return $mode === 'virtual_profile'
            || ($payload['stock_mode'] ?? null) === 'virtual'
            || array_key_exists('set_distribution', $payload);
    }

    public function isEnabledForGame(string $gameId): bool
    {
        return DB::table('stock_supply_profiles')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->exists();
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function validateGeneratePayload(array $payload): array
    {
        $errors = $this->retiredGenerationFieldErrors($payload);
        $gameId = trim((string) ($payload['game_id'] ?? ''));
        $mode = trim((string) ($payload['generation_mode'] ?? ''));

        if ($mode !== 'virtual_profile') {
            $errors['generation_mode'][] = 'The generation_mode field must be virtual_profile.';
        }

        if ($gameId === '' || ! Game::where('id', $gameId)->where('status', 'open')->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an open game.';
        }

        if ($this->currentBaseCount() < 1) {
            $errors['base_lottery_numbers'][] = 'Base lottery numbers must be seeded before generating virtual stock.';
        }

        $distribution = $this->normalizeSetDistribution($payload['set_distribution'] ?? []);
        $totalBp = array_sum(array_column($distribution, 'percent_basis_points'));
        $partnerDistribution = $this->normalizePartnerDistribution($payload['partner_distribution'] ?? []);
        $partnerDistributionBp = array_sum(array_column($partnerDistribution, 'percent_basis_points'));

        if ($totalBp > self::MAX_BP) {
            $errors['set_distribution'][] = 'The set distribution total percent may not exceed 100.';
        }

        if ($partnerDistributionBp > self::MAX_BP) {
            $errors['partner_distribution'][] = 'The partner distribution total percent may not exceed 100.';
        }

        foreach ($distribution as $index => $row) {
            if ($row['set_size'] < 1 || $row['set_size'] > 99) {
                $errors['set_distribution.'.$index.'.set_size'][] = 'The set size must be between 1 and 99.';
            }

            if ($row['percent_basis_points'] < 0) {
                $errors['set_distribution.'.$index.'.percent'][] = 'The percent must be zero or greater.';
            }
        }

        foreach ($partnerDistribution as $index => $row) {
            if (! DB::table('partners')->where('id', $row['partner_id'])->exists()) {
                $errors['partner_distribution.'.$index.'.partner_id'][] = 'The partner_id field must reference an existing partner.';
            }

            if ($row['percent_basis_points'] < 1) {
                $errors['partner_distribution.'.$index.'.percent'][] = 'The percent must be greater than zero.';
            }
        }

        foreach ($this->normalizePartnerLimits($payload['partner_limits'] ?? []) as $index => $row) {
            if (! DB::table('partners')->where('id', $row['partner_id'])->exists()) {
                $errors['partner_limits.'.$index.'.partner_id'][] = 'The partner_id field must reference an existing partner.';
            }

            foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
                $centralLimit = $this->normalizeLimitRow($payload['central_limits'] ?? [])[$field];
                if ($centralLimit !== null && $row[$field] !== null && $row[$field] > $centralLimit) {
                    $errors['partner_limits.'.$index.'.'.$field][] = 'The '.$field.' field may not exceed the central effective limit of '.$centralLimit.'.';
                }
            }
        }

        return $errors;
    }

    /**
     * @return array<string, mixed>
     */
    public function generateProfile(array $payload, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($payload, $actor, $request): array {
            $gameId = trim((string) $payload['game_id']);
            $idempotencyKey = (string) $request->header('Idempotency-Key');
            $distribution = $this->normalizeSetDistribution($payload['set_distribution'] ?? []);
            $partnerDistribution = $this->normalizePartnerDistribution($payload['partner_distribution'] ?? []);
            $coverageDefaults = $this->stockPatternCoverageDefaults();
            $hasCentralLimits = array_key_exists('central_limits', $payload);
            $centralLimits = $hasCentralLimits
                ? $this->normalizeLimitRow($payload['central_limits'] ?? $coverageDefaults['central'])
                : ['back2_limit' => null, 'back3_limit' => null, 'front3_limit' => null];
            if ($hasCentralLimits && ! $this->hasAnyLimit($centralLimits)) {
                $centralLimits = $this->normalizeLimitRow($coverageDefaults['central']);
            }
            $partnerLimits = $this->normalizePartnerLimits($payload['partner_limits'] ?? []);
            $payloadForHash = [
                'game_id' => $gameId,
                'generation_mode' => 'virtual_profile',
                'set_distribution' => $distribution,
                'partner_distribution' => $partnerDistribution,
                'central_limits' => $centralLimits,
                'partner_limits' => $partnerLimits,
            ];
            $payloadHash = $this->payloadHash($payloadForHash);
            $batchId = $this->stableId('stb', 'virtual-profile:'.$actor->adminUser['id'].':'.$idempotencyKey.':'.$payloadHash);
            $existing = $idempotencyKey !== ''
                ? StockGenerationBatch::query()
                    ->where('type', 'virtual_profile')
                    ->where('created_by_admin_id', $actor->adminUser['id'])
                    ->where('idempotency_key', $idempotencyKey)
                    ->first()
                : null;

            if ($existing !== null) {
                if ((string) $existing->payload_hash !== $payloadHash) {
                    return ['error' => 'idempotency_conflict'];
                }

                return $this->batchResource($existing);
            }

            $now = now();
            $baseCount = $this->currentBaseCount();
            $baseRange = $this->baseLotteryRange();
            $layerCapacity = $this->profileTotalCapacity($distribution, $baseCount);
            $game = Game::query()->where('id', $gameId)->where('status', 'open')->lockForUpdate()->first();

            if ($game === null) {
                return ['error' => 'resource_conflict'];
            }

            $profile = DB::table('stock_supply_profiles')
                ->where('game_id', $gameId)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();
            $isTopUp = $profile !== null;
            $profileId = $profile === null
                ? $this->stableId('vsp', 'virtual-profile:'.$gameId.':'.$batchId)
                : (string) $profile->id;
            $profileSeed = $profile === null
                ? $this->internalSeed('profile', $gameId.':'.$batchId)
                : (string) $profile->seed;
            $layerId = $this->stableId('vsl', 'virtual-layer:'.$batchId);
            $layerSeed = $this->internalSeed('layer', $batchId.':'.$payloadHash);

            if ($profile === null) {
                DB::table('stock_supply_profiles')->insert([
                    'id' => $profileId,
                    'game_id' => $gameId,
                    'status' => 'active',
                    'seed' => $profileSeed,
                    'base_count' => $baseCount,
                    'total_capacity' => 0,
                    'set_distribution_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }

            $this->replaceVirtualStockSettings($gameId, $partnerDistribution, $centralLimits, $partnerLimits, $now);

            StockGenerationBatch::query()->insert([
                'id' => $batchId,
                'game_id' => $gameId,
                'type' => 'virtual_profile',
                'status' => 'completed',
                'requested_count' => $layerCapacity,
                'generated_count' => $layerCapacity,
                'total_rounds' => 0,
                'processed_rounds' => 0,
                'chunk_rounds' => 0,
                'range_start' => $baseRange['min'],
                'range_end' => $baseRange['max'],
                'number_digits' => 6,
                'idempotency_key' => $idempotencyKey,
                'payload_hash' => $payloadHash,
                'created_by_admin_id' => $actor->adminUser['id'],
                'payload_json' => json_encode($payloadForHash + [
                    'profile_id' => $profileId,
                    'layer_id' => $layerId,
                    'base_count' => $baseCount,
                    'layer_capacity' => $layerCapacity,
                    'top_up' => $isTopUp,
                ], JSON_THROW_ON_ERROR),
                'started_at' => $now,
                'completed_at' => $now,
                'failed_at' => null,
                'failure_reason' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            DB::table('virtual_stock_supply_layers')->insert([
                'id' => $layerId,
                'profile_id' => $profileId,
                'batch_id' => $batchId,
                'game_id' => $gameId,
                'status' => 'active',
                'layer_seed' => $layerSeed,
                'base_count' => $baseCount,
                'total_capacity' => $layerCapacity,
                'set_distribution_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
                'created_by_admin_id' => $actor->adminUser['id'],
                'created_at' => $now,
                'updated_at' => $now,
            ]);

            $combinedCapacity = (int) DB::table('virtual_stock_supply_layers')
                ->where('profile_id', $profileId)
                ->where('status', 'active')
                ->sum('total_capacity');

            DB::table('stock_supply_profiles')->where('id', $profileId)->update([
                'base_count' => $baseCount,
                'total_capacity' => $combinedCapacity,
                'set_distribution_json' => json_encode($distribution, JSON_THROW_ON_ERROR),
                'updated_at' => $now,
            ]);

            StockGenerationBatch::query()->where('id', $batchId)->update([
                'payload_json' => json_encode($payloadForHash + [
                    'profile_id' => $profileId,
                    'layer_id' => $layerId,
                    'base_count' => $baseCount,
                    'layer_capacity' => $layerCapacity,
                    'total_capacity' => $combinedCapacity,
                    'top_up' => $isTopUp,
                ], JSON_THROW_ON_ERROR),
                'updated_at' => $now,
            ]);

            $this->auditLogger->logAdminWrite(
                actorId: $actor->adminUser['id'],
                scopeType: 'central',
                action: 'stock.generated',
                targetType: 'stock_generation_batch',
                targetId: $batchId,
                payload: [
                    'idempotency_key' => $idempotencyKey,
                    'payload' => $payload,
                    'profile_id' => $profileId,
                    'layer_id' => $layerId,
                    'layer_capacity' => $layerCapacity,
                    'total_capacity' => $combinedCapacity,
                    'top_up' => $isTopUp,
                ],
                requestId: (string) ($request->header('X-Request-Id') ?: ''),
                ipAddress: $request->ip(),
                userAgent: $request->userAgent(),
            );

            $this->coverageRealtime->broadcastGameSupplyChangedAfterCommit($gameId);

            return $this->batchResource(StockGenerationBatch::where('id', $batchId)->first());
        });
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}|null
     */
    public function searchLocalStock(string $tenantId, string $partnerId, array $queryParams, int $limit): ?array
    {
        $gameId = trim((string) ($queryParams['game_id'] ?? ''));
        $profile = $this->activeProfile($gameId);

        if ($profile === null) {
            return null;
        }

        $number = preg_replace('/\D+/', '', trim((string) ($queryParams['number'] ?? ''))) ?? '';
        $cursor = max(0, (int) preg_replace('/\D+/', '', (string) ($queryParams['cursor'] ?? '0')));
        $mode = (string) ($queryParams['mode'] ?? 'search');
        $rows = [];
        $visited = 0;
        $offset = $cursor;

        foreach ($this->candidateNumbers($queryParams, $number, $mode, $cursor) as $candidate) {
            $visited++;
            $offset++;
            $availability = $this->availabilityForNumber($tenantId, $partnerId, $gameId, $candidate, $profile);

            if ($availability['remaining_count'] <= 0) {
                if ($visited > 50000 && $rows !== []) {
                    break;
                }

                continue;
            }

            $copyIndexes = $this->availableCopyIndexes($partnerId, $candidate, $availability);

            foreach ($copyIndexes as $copyIndex) {
                $rows[] = $this->virtualStockResource($tenantId, $partnerId, $gameId, $candidate, $copyIndex, $availability);

                if (count($rows) >= $limit + 1) {
                    break 2;
                }
            }

            if ($visited > 50000 && $rows !== []) {
                break;
            }
        }

        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => $rows,
            'meta' => [
                'game_id' => $gameId,
                'stock_mode' => 'virtual',
                'next_cursor' => $hasMore ? (string) $offset : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array{resource?: array<string, mixed>, error?: string}|null
     */
    public function createReservation(string $tenantId, string $partnerId, CustomerSessionContext $customer, array $payload, Request $request): ?array
    {
        $itemIds = array_values(array_map('strval', $payload['local_stock_item_ids'] ?? []));
        sort($itemIds);

        if ($itemIds === [] || ! $this->containsVirtualRefs($itemIds)) {
            return null;
        }

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
            if ((string) $existing->payload_hash !== $payloadHash) {
                return ['error' => 'idempotency_conflict'];
            }

            return ['resource' => $this->reservationResourceById((string) $existing->id)];
        }

        return DB::transaction(function () use ($tenantId, $partnerId, $customer, $request, $itemIds, $normalizedPayload, $payloadHash, $idempotencyKey): array {
            $gameId = $normalizedPayload['game_id'];
            $profile = $this->activeProfile($gameId);

            if ($profile === null || count($itemIds) !== count(array_unique($itemIds))) {
                return ['error' => 'reservation_unavailable'];
            }

            $game = Game::query()->where('id', $gameId)->where('status', 'open')->lockForUpdate()->first();

            if ($game === null) {
                return ['error' => 'reservation_unavailable'];
            }

            $now = now();
            $reservationId = 'res_'.Str::ulid()->toBase32();
            $expiresAt = $now->copy()->addMinutes(15);
            $localIds = [];
            $events = [];

            foreach ($itemIds as $itemId) {
                $ref = $this->parseVirtualRef($itemId);

                if ($ref === null || $ref['tenant_id'] !== $tenantId || $ref['game_id'] !== $gameId) {
                    return ['error' => 'reservation_unavailable'];
                }

                $availability = $this->lockedAvailabilityForNumber($tenantId, $partnerId, $gameId, $ref['full_number'], $profile);

                if ($availability['remaining_count'] <= 0 || ! in_array($ref['copy_index'], $this->availableCopyIndexes($partnerId, $ref['full_number'], $availability), true)) {
                    return ['error' => 'reservation_unavailable'];
                }

                $localIds[] = $this->materializeVirtualStock(
                    tenantId: $tenantId,
                    partnerId: $partnerId,
                    gameId: $gameId,
                    fullNumber: $ref['full_number'],
                    copyIndex: $ref['copy_index'],
                    stockRef: $itemId,
                    now: $now,
                );

                $this->incrementVirtualCounters($gameId, $tenantId, $partnerId, $ref['full_number'], reservedDelta: 1, soldDelta: 0);
                $this->coverageRealtime->broadcastNumberChangedAfterCommit($gameId, $partnerId, $ref['full_number']);
                $events[] = $this->availabilityPayload($tenantId, $partnerId, $gameId, $ref['full_number'], $customer->customerId());
            }

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

            StockReservationItem::query()->insert(array_map(fn (string $localId): array => [
                'reservation_id' => $reservationId,
                'local_stock_item_id' => $localId,
                'tenant_id' => $tenantId,
                'game_id' => $gameId,
                'status' => 'active',
                'created_at' => $now,
                'updated_at' => $now,
            ], $localIds));

            foreach ($localIds as $localId) {
                GeneratePartnerLotteryImageJob::dispatch($localId)->afterCommit();
            }

            $this->broadcastAfterCommit($events);

            return ['resource' => $this->reservationResourceById($reservationId)];
        });
    }

    public function releaseReservationCounters(object $reservation, string $tenantId, string $partnerId, ?string $customerId = null): void
    {
        $rows = $this->virtualReservationRows((string) $reservation->id, $tenantId);
        $events = [];

        foreach ($rows as $row) {
            $this->incrementVirtualCounters((string) $reservation->game_id, $tenantId, $partnerId, (string) $row->full_number, reservedDelta: -1, soldDelta: 0);
            $this->coverageRealtime->broadcastNumberChangedAfterCommit((string) $reservation->game_id, $partnerId, (string) $row->full_number);
            $events[] = $this->availabilityPayload($tenantId, $partnerId, (string) $reservation->game_id, (string) $row->full_number, $customerId);
        }

        $this->broadcastAfterCommit($events);
    }

    /**
     * @param array<int, object> $stockRows
     */
    public function convertReservedRowsToSold(array $stockRows, string $tenantId, string $partnerId, string $gameId, ?string $customerId = null): void
    {
        $events = [];

        foreach ($stockRows as $row) {
            if (($row->virtual_stock_ref ?? null) === null) {
                continue;
            }

            $this->incrementVirtualCounters($gameId, $tenantId, $partnerId, (string) $row->full_number, reservedDelta: -1, soldDelta: 1);
            $this->coverageRealtime->broadcastNumberChangedAfterCommit($gameId, $partnerId, (string) $row->full_number);
            $events[] = $this->availabilityPayload($tenantId, $partnerId, $gameId, (string) $row->full_number, $customerId);
        }

        $this->broadcastAfterCommit($events);
    }

    /**
     * @param array<int, string> $itemIds
     */
    private function containsVirtualRefs(array $itemIds): bool
    {
        foreach ($itemIds as $itemId) {
            if (str_starts_with($itemId, 'vstock:')) {
                return true;
            }
        }

        return false;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function activeProfile(string $gameId): ?array
    {
        if ($gameId === '') {
            return null;
        }

        $profile = DB::table('stock_supply_profiles')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->first();

        if ($profile === null) {
            return null;
        }

        return [
            'id' => (string) $profile->id,
            'game_id' => (string) $profile->game_id,
            'seed' => (string) $profile->seed,
            'set_distribution' => $this->decodeJsonArray($profile->set_distribution_json),
            'base_count' => (int) $profile->base_count,
            'total_capacity' => (int) $profile->total_capacity,
            'layers' => $this->activeLayersForProfile($profile),
        ];
    }

    /**
     * @return array<int, array{id: string, seed: string, set_distribution: array<int|string, mixed>, total_capacity: int}>
     */
    private function activeLayersForProfile(object $profile): array
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
                'set_distribution' => $this->decodeJsonArray($profile->set_distribution_json),
                'total_capacity' => (int) $profile->total_capacity,
            ]];
        }

        return $rows->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'seed' => (string) $row->layer_seed,
            'set_distribution' => $this->decodeJsonArray($row->set_distribution_json),
            'total_capacity' => (int) $row->total_capacity,
        ])->all();
    }

    /**
     * @return array<int, string>
     */
    private function candidateNumbers(array $queryParams, string $number, string $mode, int $cursor): \Generator
    {
        $front3 = preg_replace('/\D+/', '', (string) ($queryParams['front3'] ?? '')) ?? '';
        $back3 = preg_replace('/\D+/', '', (string) ($queryParams['back3'] ?? '')) ?? '';
        $back2 = preg_replace('/\D+/', '', (string) ($queryParams['back2'] ?? '')) ?? '';

        if (strlen($number) >= 6) {
            $fullNumber = substr($number, 0, 6);
            $exists = DB::table('base_lottery_numbers')
                ->where('full_number', $fullNumber)
                ->when($front3 !== '', fn ($query) => $query->where('front3', substr($front3, 0, 3)))
                ->when($back3 !== '', fn ($query) => $query->where('back3', substr($back3, 0, 3)))
                ->when($back2 !== '', fn ($query) => $query->where('back2', substr($back2, 0, 2)))
                ->exists();

            if ($exists) {
                yield $fullNumber;
            }

            return;
        }

        $query = DB::table('base_lottery_numbers')->select('full_number');

        if ($front3 !== '') {
            $query->where('front3', substr($front3, 0, 3));
        }

        if ($back3 !== '') {
            $query->where('back3', substr($back3, 0, 3));
        }

        if ($back2 !== '') {
            $query->where('back2', substr($back2, 0, 2));
        }

        if ($number !== '') {
            $query->where('full_number', 'like', '%'.$number.'%');
        }

        if ($mode === 'random') {
            $randomSeed = trim((string) ($queryParams['random_seed'] ?? $queryParams['game_id'] ?? 'virtual-stock'));
            $query->orderByRaw('md5(full_number || ?)', [$randomSeed]);
        } else {
            $query->orderBy('full_number');
        }

        foreach ($query->offset(max(0, $cursor))->limit(50001)->get() as $row) {
            yield (string) $row->full_number;
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function availabilityForNumber(string $tenantId, string $partnerId, string $gameId, string $fullNumber, array $profile): array
    {
        $capacity = $this->capacityForNumber($fullNumber, $profile);
        $assignedCopyIndexes = $this->partnerCopyIndexes($partnerId, $gameId, $fullNumber, $capacity);
        $assigned = count($assignedCopyIndexes);
        $fullUsed = $this->counterUsed($gameId, 'partner', $partnerId, 'full_number', $fullNumber);
        $front3 = substr($fullNumber, 0, 3);
        $back3 = substr($fullNumber, -3);
        $back2 = substr($fullNumber, -2);
        $centralLimits = $this->limitSettings($gameId, 'central', 'central');
        $partnerLimits = $this->limitSettings($gameId, 'partner', $partnerId);
        $remaining = min(
            max(0, $assigned - $fullUsed),
            $this->remainingForPattern($gameId, 'central', 'central', 'front3', $front3, $centralLimits['front3_limit']),
            $this->remainingForPattern($gameId, 'central', 'central', 'back3', $back3, $centralLimits['back3_limit']),
            $this->remainingForPattern($gameId, 'central', 'central', 'back2', $back2, $centralLimits['back2_limit']),
            $this->remainingForPattern($gameId, 'partner', $partnerId, 'front3', $front3, $partnerLimits['front3_limit']),
            $this->remainingForPattern($gameId, 'partner', $partnerId, 'back3', $back3, $partnerLimits['back3_limit']),
            $this->remainingForPattern($gameId, 'partner', $partnerId, 'back2', $back2, $partnerLimits['back2_limit']),
        );

        return [
            'capacity' => $capacity,
            'partner_assigned_count' => $assigned,
            'partner_copy_indexes' => $assignedCopyIndexes,
            'partner_full_used_count' => $fullUsed,
            'remaining_count' => max(0, $remaining),
            'availability_status' => $remaining > 0 ? 'available' : 'sold_out',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function lockedAvailabilityForNumber(string $tenantId, string $partnerId, string $gameId, string $fullNumber, array $profile): array
    {
        $this->lockCounterRows($gameId, $partnerId, $fullNumber);

        return $this->availabilityForNumber($tenantId, $partnerId, $gameId, $fullNumber, $profile);
    }

    /**
     * @return array<int, int>
     */
    private function availableCopyIndexes(string $partnerId, string $fullNumber, array $availability): array
    {
        $skip = (int) $availability['partner_full_used_count'];
        $remaining = (int) $availability['remaining_count'];
        $copyIndexes = array_values($availability['partner_copy_indexes']);

        return array_slice($copyIndexes, $skip, $remaining);
    }

    private function materializeVirtualStock(string $tenantId, string $partnerId, string $gameId, string $fullNumber, int $copyIndex, string $stockRef, mixed $now): string
    {
        $stockId = $this->stableId('stk', $stockRef);
        $localId = $this->stableId('lsi', $tenantId.':'.$stockRef);
        $numberParts = [
            'front3' => substr($fullNumber, 0, 3),
            'back3' => substr($fullNumber, -3),
            'back2' => substr($fullNumber, -2),
        ];
        $existing = LocalStockItem::query()->where('tenant_id', $tenantId)->where('id', $localId)->lockForUpdate()->first();

        if ($existing !== null && $existing->status !== 'available') {
            throw new \RuntimeException('virtual stock item is not available');
        }

        StockItem::query()->updateOrInsert(
            ['id' => $stockId],
            [
                'game_id' => $gameId,
                'batch_id' => null,
                'full_number' => $fullNumber,
                'front3' => $numberParts['front3'],
                'back3' => $numberParts['back3'],
                'back2' => $numberParts['back2'],
                'status' => 'allocated',
                'partner_id' => $partnerId,
                'tenant_id' => $tenantId,
                'allocation_id' => null,
                'virtual_stock_ref' => $stockRef,
                'virtual_copy_index' => $copyIndex,
                'recall_reason' => null,
                'recalled_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        LocalStockItem::query()->updateOrInsert(
            ['id' => $localId],
            [
                'tenant_id' => $tenantId,
                'partner_id' => $partnerId,
                'store_id' => $tenantId,
                'game_id' => $gameId,
                'stock_item_id' => $stockId,
                'allocation_id' => null,
                'virtual_stock_ref' => $stockRef,
                'virtual_copy_index' => $copyIndex,
                'full_number' => $fullNumber,
                'front3' => $numberParts['front3'],
                'back3' => $numberParts['back3'],
                'back2' => $numberParts['back2'],
                'status' => 'reserved',
                'reserved_at' => $now,
                'sold_at' => null,
                'synced_at' => $now,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        return $localId;
    }

    private function incrementVirtualCounters(string $gameId, string $tenantId, string $partnerId, string $fullNumber, int $reservedDelta, int $soldDelta): void
    {
        $dimensions = [
            ['central', 'central', 'full_number', $fullNumber],
            ['central', 'central', 'front3', substr($fullNumber, 0, 3)],
            ['central', 'central', 'back3', substr($fullNumber, -3)],
            ['central', 'central', 'back2', substr($fullNumber, -2)],
            ['partner', $partnerId, 'full_number', $fullNumber],
            ['partner', $partnerId, 'front3', substr($fullNumber, 0, 3)],
            ['partner', $partnerId, 'back3', substr($fullNumber, -3)],
            ['partner', $partnerId, 'back2', substr($fullNumber, -2)],
        ];

        foreach ($dimensions as [$scopeType, $scopeId, $dimension, $value]) {
            $row = $this->ensureCounterRow($gameId, $scopeType, $scopeId, $dimension, $value);
            DB::table('virtual_stock_counters')->where('id', $row->id)->update([
                'reserved_count' => max(0, (int) $row->reserved_count + $reservedDelta),
                'sold_count' => max(0, (int) $row->sold_count + $soldDelta),
                'updated_at' => now(),
            ]);
        }
    }

    private function lockCounterRows(string $gameId, string $partnerId, string $fullNumber): void
    {
        $keys = [
            ['central', 'central', 'full_number', $fullNumber],
            ['central', 'central', 'front3', substr($fullNumber, 0, 3)],
            ['central', 'central', 'back3', substr($fullNumber, -3)],
            ['central', 'central', 'back2', substr($fullNumber, -2)],
            ['partner', $partnerId, 'full_number', $fullNumber],
            ['partner', $partnerId, 'front3', substr($fullNumber, 0, 3)],
            ['partner', $partnerId, 'back3', substr($fullNumber, -3)],
            ['partner', $partnerId, 'back2', substr($fullNumber, -2)],
        ];

        usort($keys, fn (array $left, array $right): int => strcmp(implode(':', $left), implode(':', $right)));

        foreach ($keys as [$scopeType, $scopeId, $dimension, $value]) {
            $this->ensureCounterRow($gameId, $scopeType, $scopeId, $dimension, $value);
        }
    }

    private function ensureCounterRow(string $gameId, string $scopeType, string $scopeId, string $dimension, string $value): object
    {
        $id = $this->stableId('vsc', $gameId.':'.$scopeType.':'.$scopeId.':'.$dimension.':'.$value);
        $now = now();

        DB::table('virtual_stock_counters')->updateOrInsert(
            ['id' => $id],
            [
                'game_id' => $gameId,
                'scope_type' => $scopeType,
                'scope_id' => $scopeId,
                'dimension' => $dimension,
                'value' => $value,
                'created_at' => $now,
                'updated_at' => $now,
            ],
        );

        return DB::table('virtual_stock_counters')->where('id', $id)->lockForUpdate()->first();
    }

    private function counterUsed(string $gameId, string $scopeType, string $scopeId, string $dimension, string $value): int
    {
        $row = DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->where('value', $value)
            ->first();

        return $row === null ? 0 : (int) $row->reserved_count + (int) $row->sold_count;
    }

    private function remainingForPattern(string $gameId, string $scopeType, string $scopeId, string $dimension, string $value, int $limit): int
    {
        $effectiveLimit = $this->effectiveLimit($gameId, $scopeType, $scopeId, $dimension, $value, $limit);

        if ($effectiveLimit >= self::UNLIMITED) {
            return self::UNLIMITED;
        }

        return max(0, $effectiveLimit - $this->counterUsed($gameId, $scopeType, $scopeId, $dimension, $value));
    }

    private function effectiveLimit(string $gameId, string $scopeType, string $scopeId, string $dimension, string $value, int $defaultLimit): int
    {
        $override = DB::table('stock_sale_limit_overrides')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->where('value', $value)
            ->value('limit');

        return $override === null ? $defaultLimit : (int) $override;
    }

    /**
     * @return array{back2_limit: int, back3_limit: int, front3_limit: int}
     */
    private function limitSettings(string $gameId, string $scopeType, string $scopeId): array
    {
        $fallback = $this->stockPatternCoverageDefaults()[$scopeType === 'partner' ? 'partner' : 'central'];
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
     * @return array{central: array{back2_limit: int, back3_limit: int, front3_limit: int}, partner: array{back2_limit: int, back3_limit: int, front3_limit: int}}
     */
    private function stockPatternCoverageDefaults(): array
    {
        $defaults = [
            'central' => ['back2_limit' => 500, 'back3_limit' => 300, 'front3_limit' => 200],
            'partner' => ['back2_limit' => 200, 'back3_limit' => 100, 'front3_limit' => 80],
        ];
        $value = DB::table('platform_system_settings')
            ->where('key', self::STOCK_PATTERN_COVERAGE_SETTING_KEY)
            ->value('value_json');
        $decoded = is_string($value) ? json_decode($value, true) : null;

        if (! is_array($decoded)) {
            return $defaults;
        }

        foreach (['central', 'partner'] as $scope) {
            if (! is_array($decoded[$scope] ?? null)) {
                continue;
            }

            foreach (['back2_limit', 'back3_limit', 'front3_limit'] as $field) {
                if (array_key_exists($field, $decoded[$scope]) && $decoded[$scope][$field] !== null && $decoded[$scope][$field] !== '') {
                    $defaults[$scope][$field] = max(0, (int) $decoded[$scope][$field]);
                }
            }
        }

        return $defaults;
    }

    /**
     * @return array<int, int>
     */
    private function partnerCopyIndexes(string $partnerId, string $gameId, string $fullNumber, int $capacity): array
    {
        $rows = $this->partnerDistributionRows($gameId, $partnerId);
        $copyIndexes = [];

        for ($copyIndex = 0; $copyIndex < $capacity; $copyIndex++) {
            $owner = $this->ownerPartnerForCopy($rows, $fullNumber, $copyIndex);

            if ($owner === $partnerId) {
                $copyIndexes[] = $copyIndex;
            }
        }

        return $copyIndexes;
    }

    /**
     * @return array<int, array{partner_id: string, bp: int}>
     */
    private function partnerDistributionRows(string $gameId, string $fallbackPartnerId): array
    {
        $rows = DB::table('stock_partner_distributions')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->where('percent_basis_points', '>', 0)
            ->orderBy('partner_id')
            ->get()
            ->map(fn (object $row): array => ['partner_id' => (string) $row->partner_id, 'bp' => (int) $row->percent_basis_points])
            ->all();

        if ($rows !== []) {
            return $rows;
        }

        $quotaRows = PartnerQuota::query()
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->where('quota_count', '>', 0)
            ->orderBy('partner_id')
            ->get(['partner_id', 'quota_count'])
            ->all();

        $total = array_sum(array_map(fn (object $row): int => (int) $row->quota_count, $quotaRows));

        if ($total > 0) {
            return array_map(fn (object $row): array => [
                'partner_id' => (string) $row->partner_id,
                'bp' => max(1, (int) floor(((int) $row->quota_count / $total) * self::MAX_BP)),
            ], $quotaRows);
        }

        return [['partner_id' => $fallbackPartnerId, 'bp' => self::MAX_BP]];
    }

    /**
     * @param array<int, array{partner_id: string, bp: int}> $rows
     */
    private function ownerPartnerForCopy(array $rows, string $fullNumber, int $copyIndex): ?string
    {
        $total = max(1, array_sum(array_column($rows, 'bp')));
        $score = $this->hashScore($fullNumber.':'.$copyIndex.':partner') % $total;
        $cursor = 0;

        foreach ($rows as $row) {
            $cursor += $row['bp'];

            if ($score < $cursor) {
                return $row['partner_id'];
            }
        }

        return $rows[0]['partner_id'] ?? null;
    }

    private function capacityForNumber(string $fullNumber, array $profile): int
    {
        $layers = $profile['layers'] ?? [];
        $capacity = 0;

        foreach ($layers as $layer) {
            if (! is_array($layer)) {
                continue;
            }

            $capacity += $this->capacityForLayer(
                $fullNumber,
                (string) ($layer['seed'] ?? $profile['seed']),
                is_array($layer['set_distribution'] ?? null) ? $layer['set_distribution'] : [],
            );
        }

        return max(0, $capacity);
    }

    /**
     * @param array<int|string, mixed> $distribution
     */
    private function capacityForLayer(string $fullNumber, string $seed, array $distribution): int
    {
        $score = $this->hashScore($seed.':'.$fullNumber.':set') % self::MAX_BP;
        $cursor = 0;

        foreach ($distribution as $row) {
            if (! is_array($row)) {
                continue;
            }

            $cursor += (int) ($row['percent_basis_points'] ?? 0);

            if ($score < $cursor) {
                return max(1, (int) ($row['set_size'] ?? 1));
            }
        }

        return 1;
    }

    /**
     * @return array<int, array{set_size: int, percent_basis_points: int}>
     */
    private function normalizeSetDistribution(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $rows = [];

        foreach ($value as $row) {
            if (! is_array($row)) {
                continue;
            }

            $percent = $row['percent_basis_points'] ?? $row['percent'] ?? 0;
            $basisPoints = is_numeric($percent) && (float) $percent <= 100
                ? (int) round(((float) $percent) * 100)
                : (int) $percent;

            $rows[] = [
                'set_size' => max(1, (int) ($row['set_size'] ?? $row['size'] ?? 1)),
                'percent_basis_points' => max(0, $basisPoints),
            ];
        }

        usort($rows, fn (array $left, array $right): int => $left['set_size'] <=> $right['set_size']);

        return $rows;
    }

    /**
     * @return array<int, array{partner_id: string, percent_basis_points: int}>
     */
    private function normalizePartnerDistribution(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $rows = [];

        foreach ($value as $row) {
            if (! is_array($row)) {
                continue;
            }

            $partnerId = trim((string) ($row['partner_id'] ?? ''));
            if ($partnerId === '') {
                continue;
            }

            $rows[] = [
                'partner_id' => $partnerId,
                'percent_basis_points' => $this->percentBasisPoints($row['percent_basis_points'] ?? $row['percent'] ?? 0),
            ];
        }

        return $rows;
    }

    /**
     * @return array{back2_limit: ?int, back3_limit: ?int, front3_limit: ?int}
     */
    private function normalizeLimitRow(mixed $value): array
    {
        if (! is_array($value)) {
            $value = [];
        }

        return [
            'back2_limit' => $this->nullablePositiveInteger($value['back2_limit'] ?? $value['back2'] ?? null),
            'back3_limit' => $this->nullablePositiveInteger($value['back3_limit'] ?? $value['back3'] ?? null),
            'front3_limit' => $this->nullablePositiveInteger($value['front3_limit'] ?? $value['front3'] ?? null),
        ];
    }

    /**
     * @return array<int, array{partner_id: string, back2_limit: ?int, back3_limit: ?int, front3_limit: ?int}>
     */
    private function normalizePartnerLimits(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $rows = [];

        foreach ($value as $row) {
            if (! is_array($row)) {
                continue;
            }

            $partnerId = trim((string) ($row['partner_id'] ?? ''));
            if ($partnerId === '') {
                continue;
            }

            $limits = $this->normalizeLimitRow($row);
            if (! $this->hasAnyLimit($limits)) {
                continue;
            }

            $rows[] = ['partner_id' => $partnerId] + $limits;
        }

        return $rows;
    }

    /**
     * @param array<int, array{partner_id: string, percent_basis_points: int}> $partnerDistribution
     * @param array{back2_limit: ?int, back3_limit: ?int, front3_limit: ?int} $centralLimits
     * @param array<int, array{partner_id: string, back2_limit: ?int, back3_limit: ?int, front3_limit: ?int}> $partnerLimits
     */
    private function replaceVirtualStockSettings(string $gameId, array $partnerDistribution, array $centralLimits, array $partnerLimits, mixed $now): void
    {
        if ($partnerDistribution !== []) {
            DB::table('stock_partner_distributions')->where('game_id', $gameId)->delete();

            foreach ($partnerDistribution as $row) {
                DB::table('stock_partner_distributions')->insert([
                    'id' => $this->stableId('spd', $gameId.':'.$row['partner_id']),
                    'game_id' => $gameId,
                    'partner_id' => $row['partner_id'],
                    'tenant_id' => $this->tenantIdForPartner($row['partner_id']),
                    'percent_basis_points' => $row['percent_basis_points'],
                    'status' => 'active',
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            }
        }

        if ($this->hasAnyLimit($centralLimits)) {
            DB::table('stock_sale_limit_settings')->updateOrInsert(
                ['id' => $this->stableId('ssl', $gameId.':central:central')],
                [
                    'game_id' => $gameId,
                    'scope_type' => 'central',
                    'scope_id' => 'central',
                    'back2_limit' => $centralLimits['back2_limit'],
                    'back3_limit' => $centralLimits['back3_limit'],
                    'front3_limit' => $centralLimits['front3_limit'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }

        foreach ($partnerLimits as $row) {
            DB::table('stock_sale_limit_settings')->updateOrInsert(
                ['id' => $this->stableId('ssl', $gameId.':partner:'.$row['partner_id'])],
                [
                    'game_id' => $gameId,
                    'scope_type' => 'partner',
                    'scope_id' => $row['partner_id'],
                    'back2_limit' => $row['back2_limit'],
                    'back3_limit' => $row['back3_limit'],
                    'front3_limit' => $row['front3_limit'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ],
            );
        }
    }

    private function percentBasisPoints(mixed $percent): int
    {
        return is_numeric($percent) && (float) $percent <= 100
            ? max(0, (int) round(((float) $percent) * 100))
            : max(0, (int) $percent);
    }

    private function nullablePositiveInteger(mixed $value): ?int
    {
        if ($value === null || $value === '') {
            return null;
        }

        return max(0, (int) $value);
    }

    /**
     * @param array{back2_limit: ?int, back3_limit: ?int, front3_limit: ?int} $limits
     */
    private function hasAnyLimit(array $limits): bool
    {
        return $limits['back2_limit'] !== null
            || $limits['back3_limit'] !== null
            || $limits['front3_limit'] !== null;
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function retiredGenerationFieldErrors(array $payload): array
    {
        $errors = [];
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

    private function tenantIdForPartner(string $partnerId): ?string
    {
        $tenantId = DB::table('partner_tenants')
            ->where('partner_id', $partnerId)
            ->orderBy('id')
            ->value('id');

        return $tenantId === null ? null : (string) $tenantId;
    }

    private function currentBaseCount(): int
    {
        return (int) DB::table('base_lottery_numbers')->count();
    }

    /**
     * @return array{min: ?string, max: ?string}
     */
    private function baseLotteryRange(): array
    {
        return [
            'min' => DB::table('base_lottery_numbers')->min('full_number'),
            'max' => DB::table('base_lottery_numbers')->max('full_number'),
        ];
    }

    private function profileTotalCapacity(array $distribution, int $baseCount): int
    {
        $usedBp = 0;
        $capacity = 0;

        foreach ($distribution as $row) {
            $bp = min(self::MAX_BP - $usedBp, (int) $row['percent_basis_points']);
            $count = (int) floor($baseCount * ($bp / self::MAX_BP));
            $capacity += $count * max(1, (int) $row['set_size']);
            $usedBp += $bp;
        }

        $capacity += ($baseCount - (int) floor($baseCount * ($usedBp / self::MAX_BP))) * 1;

        return $capacity;
    }

    /**
     * @return array<string, mixed>
     */
    private function virtualStockResource(string $tenantId, string $partnerId, string $gameId, string $fullNumber, int $copyIndex, array $availability): array
    {
        $stockRef = $this->virtualRef($tenantId, $gameId, $fullNumber, $copyIndex);

        return [
            'id' => $stockRef,
            'token' => $stockRef,
            'local_stock_item_id' => $stockRef,
            'stock_ref' => $stockRef,
            'stock_mode' => 'virtual',
            'game_id' => $gameId,
            'full_number' => $fullNumber,
            'front3' => substr($fullNumber, 0, 3),
            'back3' => substr($fullNumber, -3),
            'back2' => substr($fullNumber, -2),
            'virtual_copy_index' => $copyIndex,
            'remaining_count' => (int) $availability['remaining_count'],
            'availability_status' => (string) $availability['availability_status'],
            'status' => (string) $availability['availability_status'],
            'price' => ['amount' => 0, 'currency' => 'THB'],
            'price_rule_summary' => null,
            'image_thumb_url' => null,
            'image_url' => null,
        ];
    }

    private function virtualRef(string $tenantId, string $gameId, string $fullNumber, int $copyIndex): string
    {
        return 'vstock:'.$tenantId.':'.$gameId.':'.$fullNumber.':'.$copyIndex;
    }

    /**
     * @return array{tenant_id: string, game_id: string, full_number: string, copy_index: int}|null
     */
    private function parseVirtualRef(string $ref): ?array
    {
        $parts = explode(':', $ref);

        if (count($parts) !== 5 || $parts[0] !== 'vstock' || ! preg_match('/^[0-9]{6}$/', $parts[3])) {
            return null;
        }

        return [
            'tenant_id' => $parts[1],
            'game_id' => $parts[2],
            'full_number' => $parts[3],
            'copy_index' => max(0, (int) $parts[4]),
        ];
    }

    /**
     * @return array<int, object>
     */
    private function virtualReservationRows(string $reservationId, string $tenantId): array
    {
        return StockReservationItem::query()
            ->join('local_stock_items', 'local_stock_items.id', '=', 'stock_reservation_items.local_stock_item_id')
            ->where('stock_reservation_items.reservation_id', $reservationId)
            ->where('stock_reservation_items.tenant_id', $tenantId)
            ->whereNotNull('local_stock_items.virtual_stock_ref')
            ->select('local_stock_items.*')
            ->lockForUpdate()
            ->get()
            ->all();
    }

    /**
     * @return array<string, mixed>
     */
    private function availabilityPayload(string $tenantId, string $partnerId, string $gameId, string $fullNumber, ?string $customerId = null): array
    {
        $profile = $this->activeProfile($gameId);
        $availability = $profile === null
            ? ['remaining_count' => 0, 'availability_status' => 'sold_out']
            : $this->availabilityForNumber($tenantId, $partnerId, $gameId, $fullNumber, $profile);

        return [
            'tenant_id' => $tenantId,
            'partner_id' => $partnerId,
            'customer_id' => $customerId,
            'game_id' => $gameId,
            'full_number' => $fullNumber,
            'front3' => substr($fullNumber, 0, 3),
            'back3' => substr($fullNumber, -3),
            'back2' => substr($fullNumber, -2),
            'remaining_count' => (int) $availability['remaining_count'],
            'status' => (string) $availability['availability_status'],
            'stock_mode' => 'virtual',
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $events
     */
    private function broadcastAfterCommit(array $events): void
    {
        if ($events === []) {
            return;
        }

        DB::afterCommit(function () use ($events): void {
            foreach ($events as $payload) {
                try {
                    StockAvailabilityUpdated::dispatch($payload);
                } catch (\Throwable $exception) {
                    Log::warning('Stock availability realtime broadcast failed.', [
                        'game_id' => $payload['game_id'] ?? null,
                        'full_number' => $payload['full_number'] ?? null,
                        'message' => $exception->getMessage(),
                    ]);
                }
            }
        });
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
            'items' => array_map(fn (object $stock): array => [
                'id' => (string) $stock->id,
                'game_id' => (string) $stock->game_id,
                'full_number' => (string) $stock->full_number,
                'front3' => $stock->front3,
                'back3' => $stock->back3,
                'back2' => $stock->back2,
                'status' => (string) $stock->status,
                'stock_ref' => $stock->virtual_stock_ref,
                'stock_mode' => $stock->virtual_stock_ref === null ? 'physical' : 'virtual',
                'remaining_count' => null,
                'availability_status' => (string) $stock->status,
                'price' => ['amount' => 0, 'currency' => 'THB'],
                'price_rule_summary' => null,
                'image_thumb_url' => $stock->image_thumb_url,
                'image_url' => $stock->image_url,
            ], $items),
            'tenant_id' => (string) $reservation->tenant_id,
            'customer_id' => (string) $reservation->customer_id,
            'created_at' => $reservation->created_at,
            'updated_at' => $reservation->updated_at,
        ];
    }

    private function batchResource(?object $batch): array
    {
        if ($batch === null) {
            return [];
        }

        $payload = $this->decodeJsonArray($batch->payload_json ?? null);
        $requestedCount = (int) $batch->requested_count;
        $generatedCount = (int) $batch->generated_count;

        if ((string) $batch->type === 'virtual_profile' && (string) $batch->status === 'completed') {
            $generatedCount = max($generatedCount, $requestedCount);
        }

        return [
            'id' => (string) $batch->id,
            'game_id' => (string) $batch->game_id,
            'type' => (string) $batch->type,
            'status' => (string) $batch->status,
            'requested_count' => $requestedCount,
            'generated_count' => $generatedCount,
            'range_start' => $batch->range_start,
            'range_end' => $batch->range_end,
            'number_digits' => (int) $batch->number_digits,
            'stock_mode' => 'virtual',
            'profile_id' => $payload['profile_id'] ?? null,
            'layer_id' => $payload['layer_id'] ?? null,
            'layer_capacity' => (int) ($payload['layer_capacity'] ?? $batch->requested_count),
            'top_up' => (bool) ($payload['top_up'] ?? false),
            'total_capacity' => (int) ($payload['total_capacity'] ?? $payload['layer_capacity'] ?? $batch->requested_count),
            'created_at' => $batch->created_at,
            'updated_at' => $batch->updated_at,
            'completed_at' => $batch->completed_at,
        ];
    }

    /**
     * @return array<int|string, mixed>
     */
    private function decodeJsonArray(mixed $json): array
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

    private function hashScore(string $seed): int
    {
        return (int) hexdec(substr(hash('sha256', $seed), 0, 8));
    }

    private function payloadHash(array $payload): string
    {
        ksort($payload);

        return hash('sha256', json_encode($payload, JSON_THROW_ON_ERROR));
    }

    private function internalSeed(string $scope, string $value): string
    {
        return hash('sha256', 'virtual-stock:'.$scope.':'.$value);
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
}
