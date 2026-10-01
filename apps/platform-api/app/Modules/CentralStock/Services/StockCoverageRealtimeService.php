<?php

namespace App\Modules\CentralStock\Services;

use App\Modules\CentralStock\Events\StockCoverageUpdated;
use App\Modules\CentralStock\Events\StockTableUpdated;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class StockCoverageRealtimeService
{
    private const MAX_BP = 10000;
    private const UNLIMITED = 2147483647;
    private const STOCK_PATTERN_COVERAGE_SETTING_KEY = 'stock_pattern_coverage_default';

    public function broadcastGameSupplyChangedAfterCommit(string $gameId): void
    {
        $this->broadcastRefreshRequiredAfterCommit($gameId, 'stock_supply_changed');
        $this->broadcastStockTableRefreshAfterCommit($gameId, 'stock_supply_changed');
    }

    public function broadcastLimitSettingsChangedAfterCommit(string $gameId, string $scopeType, string $scopeId): void
    {
        $this->broadcastRefreshRequiredAfterCommit($gameId, 'limit_settings_changed', $scopeType, $scopeId);
        $this->broadcastStockTableRefreshAfterCommit($gameId, 'limit_settings_changed');
    }

    /**
     * @param array<int, string> $values
     */
    public function broadcastLimitOverridesChangedAfterCommit(
        string $gameId,
        string $scopeType,
        string $scopeId,
        string $dimension,
        array $values,
    ): void {
        $this->broadcastRowsAfterCommit($gameId, $scopeType, $scopeId, $dimension, $values);
        $this->broadcastStockTableRefreshAfterCommit($gameId, 'limit_overrides_changed');
    }

    public function broadcastNumberChangedAfterCommit(string $gameId, string $partnerId, string $fullNumber, ?string $tenantId = null): void
    {
        $fullNumber = preg_replace('/\D+/', '', $fullNumber) ?? '';

        if (strlen($fullNumber) !== 6) {
            return;
        }

        $values = [
            'front3' => [substr($fullNumber, 0, 3)],
            'back3' => [substr($fullNumber, -3)],
            'back2' => [substr($fullNumber, -2)],
        ];

        foreach ($values as $dimension => $dimensionValues) {
            $this->broadcastRowsAfterCommit($gameId, 'central', 'central', $dimension, $dimensionValues);
            $this->broadcastRowsAfterCommit($gameId, 'partner', $partnerId, $dimension, $dimensionValues, $tenantId);
        }

        $this->broadcastStockTableRowAfterCommit($gameId, $fullNumber, 'stock_counter_changed');
    }

    public function broadcastStockTableRefreshAfterCommit(string $gameId, string $reason): void
    {
        $gameId = trim($gameId);

        if ($gameId === '') {
            return;
        }

        $this->afterCommit(function () use ($gameId, $reason): void {
            try {
                StockTableUpdated::dispatch([
                    'event_type' => 'stock.table.updated',
                    'game_id' => $gameId,
                    'refresh_required' => true,
                    'reason' => $reason,
                    'updated_at' => now()->toISOString(),
                ]);
            } catch (\Throwable $exception) {
                Log::warning('Stock table realtime refresh broadcast failed.', [
                    'game_id' => $gameId,
                    'reason' => $reason,
                    'message' => $exception->getMessage(),
                ]);
            }
        });
    }

    public function broadcastStockTableRowAfterCommit(string $gameId, string $fullNumber, string $reason): void
    {
        $gameId = trim($gameId);
        $fullNumber = preg_replace('/\D+/', '', $fullNumber) ?? '';

        if ($gameId === '' || strlen($fullNumber) !== 6) {
            return;
        }

        $this->afterCommit(function () use ($gameId, $fullNumber, $reason): void {
            try {
                $row = $this->stockTableRow($gameId, $fullNumber);

                if ($row === null) {
                    StockTableUpdated::dispatch([
                        'event_type' => 'stock.table.updated',
                        'game_id' => $gameId,
                        'refresh_required' => true,
                        'reason' => $reason,
                        'updated_at' => now()->toISOString(),
                    ]);

                    return;
                }

                StockTableUpdated::dispatch([
                    'event_type' => 'stock.table.updated',
                    'game_id' => $gameId,
                    'refresh_required' => false,
                    'reason' => $reason,
                    'row' => $row,
                    'updated_at' => now()->toISOString(),
                ]);
            } catch (\Throwable $exception) {
                Log::warning('Stock table realtime row broadcast failed.', [
                    'game_id' => $gameId,
                    'full_number' => $fullNumber,
                    'reason' => $reason,
                    'message' => $exception->getMessage(),
                ]);
            }
        });
    }

    /**
     * @param array<int, string>|null $values
     */
    private function broadcastRowsAfterCommit(
        string $gameId,
        string $scopeType,
        string $scopeId,
        ?string $dimension = null,
        ?array $values = null,
        ?string $tenantId = null,
    ): void {
        $gameId = trim($gameId);

        if ($gameId === '') {
            return;
        }

        $this->afterCommit(function () use ($gameId, $scopeType, $scopeId, $dimension, $values, $tenantId): void {
            foreach ($this->coverageRows($gameId, $scopeType, $scopeId, $dimension, $values) as $payload) {
                try {
                    if ($tenantId !== null && $tenantId !== '') {
                        $payload['tenant_id'] = $tenantId;
                    }

                    StockCoverageUpdated::dispatch($payload);
                } catch (\Throwable $exception) {
                    Log::warning('Stock coverage realtime broadcast failed.', [
                        'game_id' => $gameId,
                        'scope_type' => $scopeType,
                        'scope_id' => $scopeId,
                        'dimension' => $payload['dimension'] ?? null,
                        'number' => $payload['number'] ?? null,
                        'message' => $exception->getMessage(),
                    ]);
                }
            }
        });
    }

    /**
     * @param array<int, string>|null $values
     * @return array<int, array<string, mixed>>
     */
    private function coverageRows(string $gameId, string $scopeType, string $scopeId, ?string $dimension, ?array $values): array
    {
        $dimensions = $dimension === null ? ['back2', 'back3', 'front3'] : [$dimension];
        $rows = [];

        foreach ($dimensions as $currentDimension) {
            $valueList = $values === null
                ? $this->dimensionValues($currentDimension)
                : array_values(array_unique(array_map(fn (string $value): string => $this->normalizeDimensionValue($currentDimension, $value), $values)));
            $counts = $this->generatedCountsForDimension($gameId, $currentDimension, $scopeType, $scopeId, $valueList);
            $counterRows = $this->counterRows($gameId, $scopeType, $scopeId, $currentDimension, $valueList);
            $overrides = $this->limitOverrideRows($gameId, $scopeType, $scopeId, $currentDimension, $valueList);
            $defaultLimit = $this->limitSettings($gameId, $scopeType, $scopeId)[$currentDimension.'_limit'];

            foreach ($valueList as $value) {
                $counter = $counterRows[$value] ?? ['reserved' => 0, 'sold' => 0, 'updated_at' => null];
                $reservedCount = (int) $counter['reserved'];
                $soldCount = (int) $counter['sold'];
                $usedCount = $reservedCount + $soldCount;
                $generatedCount = (int) ($counts[$value] ?? 0);
                $overrideLimit = $overrides[$value]['limit'] ?? null;
                $limit = $overrideLimit ?? $defaultLimit;
                $generatedRemaining = max(0, $generatedCount - $usedCount);
                $remainingLimit = $limit >= self::UNLIMITED ? null : max(0, $limit - $usedCount);
                $sellable = $remainingLimit === null ? $generatedRemaining : min($generatedRemaining, $remainingLimit);

                $rows[] = [
                    'event_type' => 'stock.coverage.updated',
                    'game_id' => $gameId,
                    'scope_type' => $scopeType,
                    'scope_id' => $scopeId,
                    'dimension' => $currentDimension,
                    'number' => $value,
                    'generated_count' => $generatedCount,
                    'reserved_count' => $reservedCount,
                    'sold_count' => $soldCount,
                    'used_count' => $usedCount,
                    'generated_remaining_count' => $generatedRemaining,
                    'default_limit' => $defaultLimit >= self::UNLIMITED ? null : $defaultLimit,
                    'override_limit' => $overrideLimit,
                    'limit' => $limit >= self::UNLIMITED ? null : $limit,
                    'remaining_limit' => $remainingLimit,
                    'sellable_remaining_count' => $sellable,
                    'limit_exceeds_supply' => $limit < self::UNLIMITED && $limit > $generatedCount,
                    'status' => $sellable > 0 ? 'available' : 'sold_out',
                    'updated_at' => $counter['updated_at'],
                ];
            }
        }

        return $rows;
    }

    /**
     * @return array<string, int>
     */
    private function generatedCountsForDimension(string $gameId, string $dimension, string $scopeType, string $scopeId, array $values): array
    {
        $profile = $this->activeProfile($gameId);

        if ($profile === null) {
            return [];
        }

        $layers = $this->activeLayers($profile);
        $precomputed = $this->precomputedGeneratedCountsForDimension($gameId, $dimension, $scopeType, $scopeId, (string) $profile->id, $layers, $values);

        if ($precomputed !== null) {
            return $precomputed;
        }

        $allocationRowsByLayer = $scopeType === 'partner' ? $this->allocationRowsByLayer($gameId, $layers) : [];
        $counts = [];
        $query = DB::table('base_lottery_numbers');

        if ($values !== []) {
            $query->whereIn($dimension, $values);
        }

        foreach ($query->get(['full_number', $dimension.' as value']) as $number) {
            $capacity = $this->capacityForNumber((string) $number->full_number, $layers);

            if ($scopeType === 'partner') {
                $capacity = count($this->partnerCopyIndexesForLayers(
                    $scopeId,
                    (string) $number->full_number,
                    $layers,
                    $allocationRowsByLayer,
                ));
            }

            $value = (string) $number->value;
            $counts[$value] = ($counts[$value] ?? 0) + $capacity;
        }

        return $counts;
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int, array<string, mixed>>, total_capacity: int}> $layers
     * @param array<int, string> $values
     * @return array<string, int>|null
     */
    private function precomputedGeneratedCountsForDimension(
        string $gameId,
        string $dimension,
        string $scopeType,
        string $scopeId,
        string $profileId,
        array $layers,
        array $values,
    ): ?array {
        $sourceIds = array_values(array_filter(array_map(
            fn (array $layer): string => (string) ($layer['id'] ?? ''),
            $layers,
        )));

        if ($sourceIds === []) {
            return null;
        }

        if ($scopeType === 'partner') {
            $sourceIds = $this->assignedLayerIdsForPartner($gameId, $scopeId, $layers);

            if ($sourceIds === []) {
                return [];
            }
        }

        $existingSourceIds = DB::table('virtual_stock_pattern_generated_counts')
            ->where('game_id', $gameId)
            ->where('profile_id', $profileId)
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

        $query = DB::table('virtual_stock_pattern_generated_counts')
            ->select(['value'])
            ->selectRaw('SUM(generated_count)::bigint as generated_count')
            ->where('game_id', $gameId)
            ->where('profile_id', $profileId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->whereIn('source_id', $sourceIds)
            ->groupBy('value');

        if ($values !== []) {
            $query->whereIn('value', $values);
        }

        return $query->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->value => (int) $row->generated_count])
            ->all();
    }

    private function activeProfile(string $gameId): ?object
    {
        return DB::table('stock_supply_profiles')
            ->where('game_id', $gameId)
            ->where('status', 'active')
            ->first();
    }

    /**
     * @return array<int, array{id: string, seed: string, set_distribution: array<int, array<string, mixed>>, total_capacity: int}>
     */
    private function activeLayers(object $profile): array
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
                'set_distribution' => $this->decodeJsonArray($profile->set_distribution_json ?? null),
                'total_capacity' => (int) $profile->total_capacity,
            ]];
        }

        return $rows->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'seed' => (string) $row->layer_seed,
            'set_distribution' => $this->decodeJsonArray($row->set_distribution_json ?? null),
            'total_capacity' => (int) $row->total_capacity,
        ])->all();
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int, array<string, mixed>>, total_capacity: int}> $layers
     */
    private function capacityForNumber(string $fullNumber, array $layers): int
    {
        $capacity = 0;

        foreach ($layers as $layer) {
            $capacity += $this->layerCapacityForNumber($fullNumber, $layer['seed'], $layer['set_distribution']);
        }

        return $capacity;
    }

    /**
     * @param array<int, array<string, mixed>> $distribution
     */
    private function layerCapacityForNumber(string $fullNumber, string $seed, array $distribution): int
    {
        $score = (int) hexdec(substr(hash('sha256', $seed.':'.$fullNumber.':set'), 0, 8)) % self::MAX_BP;
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
     * @param array<int, array{id: string, seed: string, set_distribution: array<int, array<string, mixed>>, total_capacity: int}> $layers
     * @return array<string, array<int, array{partner_id: string, bp: int}>>
     */
    private function allocationRowsByLayer(string $gameId, array $layers): array
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
            ->whereIn('status', ['pending', 'processing', 'allocated', 'partially_allocated'])
            ->whereNotNull('allocation_percent_basis_points')
            ->where('allocation_percent_basis_points', '>', 0)
            ->orderBy('partner_id')
            ->orderBy('id')
            ->get(['id', 'partner_id', 'allocation_percent_basis_points', 'supply_layer_ids_json']);

        foreach ($rows as $row) {
            $snapshotLayerIds = $this->snapshotLayerIds($row->supply_layer_ids_json ?? null, $layerIds);

            foreach (array_values(array_intersect($layerIds, $snapshotLayerIds)) as $layerId) {
                $rowsByLayer[$layerId][] = [
                    'partner_id' => (string) $row->partner_id,
                    'bp' => (int) $row->allocation_percent_basis_points,
                ];
            }
        }

        return $rowsByLayer;
    }

    /**
     * @param array<int, array{id: string, seed: string, set_distribution: array<int, array<string, mixed>>, total_capacity: int}> $layers
     * @return array<int, string>
     */
    private function assignedLayerIdsForPartner(string $gameId, string $partnerId, array $layers): array
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
            ->whereIn('status', ['pending', 'processing', 'allocated', 'partially_allocated'])
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
     * @param array<int, array{id: string, seed: string, set_distribution: array<int, array<string, mixed>>, total_capacity: int}> $layers
     * @param array<string, array<int, array{partner_id: string, bp: int}>> $allocationRowsByLayer
     * @return array<int, int>
     */
    private function partnerCopyIndexesForLayers(string $partnerId, string $fullNumber, array $layers, array $allocationRowsByLayer): array
    {
        $copyIndexes = [];
        $offset = 0;

        foreach ($layers as $layer) {
            $layerId = (string) ($layer['id'] ?? '');
            $layerCapacity = $this->layerCapacityForNumber(
                $fullNumber,
                (string) ($layer['seed'] ?? ''),
                is_array($layer['set_distribution'] ?? null) ? $layer['set_distribution'] : [],
            );
            $rows = $allocationRowsByLayer[$layerId] ?? [];

            for ($localIndex = 0; $localIndex < $layerCapacity; $localIndex++) {
                $copyIndex = $offset + $localIndex;

                if ($this->ownerPartnerForCopy($rows, $fullNumber, $copyIndex) === $partnerId) {
                    $copyIndexes[] = $copyIndex;
                }
            }

            $offset += $layerCapacity;
        }

        return $copyIndexes;
    }

    /**
     * @param array<int, array{partner_id: string, bp: int}> $rows
     */
    private function ownerPartnerForCopy(array $rows, string $fullNumber, int $copyIndex): ?string
    {
        $score = (int) hexdec(substr(hash('sha256', $fullNumber.':'.$copyIndex.':partner'), 0, 8)) % self::MAX_BP;
        $cursor = 0;

        foreach ($rows as $row) {
            $cursor = min(self::MAX_BP, $cursor + max(0, (int) $row['bp']));

            if ($score < $cursor) {
                return $row['partner_id'];
            }
        }

        return null;
    }

    /**
     * @param array<int, string> $fallbackLayerIds
     * @return array<int, string>
     */
    private function snapshotLayerIds(mixed $json, array $fallbackLayerIds): array
    {
        $decoded = $this->decodeJsonArray($json);
        $ids = array_values(array_filter(array_map(
            fn (mixed $value): string => trim((string) $value),
            $decoded,
        )));

        return $ids === [] ? $fallbackLayerIds : $ids;
    }

    /**
     * @return array<string, array{reserved: int, sold: int, updated_at: mixed}>
     */
    private function counterRows(string $gameId, string $scopeType, string $scopeId, string $dimension, array $values): array
    {
        if ($values === []) {
            return [];
        }

        return DB::table('virtual_stock_counters')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->whereIn('value', $values)
            ->get(['value', 'reserved_count', 'sold_count', 'updated_at'])
            ->mapWithKeys(fn (object $row): array => [
                (string) $row->value => [
                    'reserved' => (int) $row->reserved_count,
                    'sold' => (int) $row->sold_count,
                    'updated_at' => $row->updated_at,
                ],
            ])
            ->all();
    }

    /**
     * @return array<string, array{limit: int, updated_at: mixed}>
     */
    private function limitOverrideRows(string $gameId, string $scopeType, string $scopeId, string $dimension, array $values): array
    {
        if ($values === []) {
            return [];
        }

        return DB::table('stock_sale_limit_overrides')
            ->where('game_id', $gameId)
            ->where('scope_type', $scopeType)
            ->where('scope_id', $scopeId)
            ->where('dimension', $dimension)
            ->whereIn('value', $values)
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
     * @return array<string, mixed>|null
     */
    private function stockTableRow(string $gameId, string $fullNumber): ?array
    {
        $profile = $this->activeProfile($gameId);
        $number = DB::table('base_lottery_numbers')
            ->where('full_number', $fullNumber)
            ->first(['full_number', 'front3', 'back3', 'back2']);

        if ($profile !== null && $number !== null) {
            return $this->virtualStockTableRow($profile, $number);
        }

        return $this->physicalStockTableRow($gameId, $fullNumber);
    }

    /**
     * @return array<string, mixed>
     */
    private function virtualStockTableRow(object $profile, object $number): array
    {
        $gameId = (string) $profile->game_id;
        $fullNumber = (string) $number->full_number;
        $front3 = (string) $number->front3;
        $back3 = (string) $number->back3;
        $back2 = (string) $number->back2;
        $totalCount = $this->capacityForNumber($fullNumber, $this->activeLayers($profile));
        $fullCounter = $this->counterRows($gameId, 'central', 'central', 'full_number', [$fullNumber])[$fullNumber]
            ?? ['reserved' => 0, 'sold' => 0, 'updated_at' => null];
        $reservedCount = min($totalCount, (int) $fullCounter['reserved']);
        $soldCount = min($totalCount, (int) $fullCounter['sold']);
        $usedCount = $reservedCount + $soldCount;
        $limits = $this->limitSettings($gameId, 'central', 'central');
        $availableCount = min(
            max(0, $totalCount - $usedCount),
            $this->remainingForPattern($gameId, 'front3', $front3, $limits['front3_limit']),
            $this->remainingForPattern($gameId, 'back3', $back3, $limits['back3_limit']),
            $this->remainingForPattern($gameId, 'back2', $back2, $limits['back2_limit']),
        );

        return [
            'id' => $gameId.':'.$fullNumber,
            'stock_mode' => 'virtual',
            'game_id' => $gameId,
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
            'status' => $availableCount > 0 ? 'available' : 'sold_out',
            'first_created_at' => $profile->created_at,
            'last_updated_at' => $fullCounter['updated_at'] ?? $profile->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    private function physicalStockTableRow(string $gameId, string $fullNumber): ?array
    {
        $row = DB::table('stock_items')
            ->where('game_id', $gameId)
            ->where('full_number', $fullNumber)
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
            ->first();

        if ($row === null) {
            return null;
        }

        $availableCount = (int) $row->available_count;

        return [
            'id' => (string) $row->game_id.':'.(string) $row->full_number,
            'game_id' => (string) $row->game_id,
            'full_number' => (string) $row->full_number,
            'front3' => substr((string) $row->full_number, 0, 3),
            'back3' => substr((string) $row->full_number, -3),
            'back2' => substr((string) $row->full_number, -2),
            'sample_stock_item_id' => (string) $row->sample_stock_item_id,
            'total_count' => (int) $row->total_count,
            'available_count' => $availableCount,
            'allocated_count' => (int) $row->allocated_count,
            'sold_count' => (int) $row->sold_count,
            'recalled_count' => (int) $row->recalled_count,
            'status' => $availableCount > 0 ? 'available' : 'sold_out',
            'first_created_at' => $row->first_created_at,
            'last_updated_at' => $row->last_updated_at,
        ];
    }

    private function remainingForPattern(string $gameId, string $dimension, string $value, int $defaultLimit): int
    {
        $override = $this->limitOverrideRows($gameId, 'central', 'central', $dimension, [$value])[$value]['limit'] ?? null;
        $limit = $override ?? $defaultLimit;

        if ($limit >= self::UNLIMITED) {
            return self::UNLIMITED;
        }

        $counter = $this->counterRows($gameId, 'central', 'central', $dimension, [$value])[$value]
            ?? ['reserved' => 0, 'sold' => 0];

        return max(0, $limit - (int) $counter['reserved'] - (int) $counter['sold']);
    }

    private function broadcastRefreshRequiredAfterCommit(
        string $gameId,
        string $reason,
        string $scopeType = 'all',
        string $scopeId = 'all',
    ): void {
        $gameId = trim($gameId);

        if ($gameId === '') {
            return;
        }

        $this->afterCommit(function () use ($gameId, $reason, $scopeType, $scopeId): void {
            try {
                StockCoverageUpdated::dispatch([
                    'event_type' => 'stock.coverage.updated',
                    'game_id' => $gameId,
                    'scope_type' => $scopeType,
                    'scope_id' => $scopeId,
                    'refresh_required' => true,
                    'reason' => $reason,
                    'updated_at' => now()->toISOString(),
                ]);
            } catch (\Throwable $exception) {
                Log::warning('Stock coverage realtime refresh broadcast failed.', [
                    'game_id' => $gameId,
                    'scope_type' => $scopeType,
                    'scope_id' => $scopeId,
                    'reason' => $reason,
                    'message' => $exception->getMessage(),
                ]);
            }
        });
    }

    /**
     * @return array<int, string>
     */
    private function dimensionValues(string $dimension): array
    {
        $count = $dimension === 'back2' ? 100 : 1000;
        $pad = $dimension === 'back2' ? 2 : 3;
        $values = [];

        for ($index = 0; $index < $count; $index++) {
            $values[] = str_pad((string) $index, $pad, '0', STR_PAD_LEFT);
        }

        return $values;
    }

    private function normalizeDimensionValue(string $dimension, string $value): string
    {
        $digits = preg_replace('/\D+/', '', $value) ?? '';
        $length = $dimension === 'back2' ? 2 : 3;

        return str_pad(substr($digits, -$length), $length, '0', STR_PAD_LEFT);
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

    private function afterCommit(callable $callback): void
    {
        try {
            DB::afterCommit($callback);
        } catch (\Throwable) {
            $callback();
        }
    }
}
