<?php

namespace App\Modules\CentralStock\Services;

use App\Modules\CentralStock\Events\StockCoverageUpdated;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;

class StockCoverageRealtimeService
{
    private const MAX_BP = 10000;
    private const UNLIMITED = 2147483647;
    private const STOCK_PATTERN_COVERAGE_SETTING_KEY = 'stock_pattern_coverage_default';

    public function broadcastGameSupplyChangedAfterCommit(string $gameId): void
    {
        $this->broadcastRowsAfterCommit($gameId, 'central', 'central');

        foreach ($this->partnerScopeIdsForGame($gameId) as $partnerId) {
            $this->broadcastRowsAfterCommit($gameId, 'partner', $partnerId);
        }
    }

    public function broadcastLimitSettingsChangedAfterCommit(string $gameId, string $scopeType, string $scopeId): void
    {
        $this->broadcastRowsAfterCommit($gameId, $scopeType, $scopeId);
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
    }

    public function broadcastNumberChangedAfterCommit(string $gameId, string $partnerId, string $fullNumber): void
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
            $this->broadcastRowsAfterCommit($gameId, 'partner', $partnerId, $dimension, $dimensionValues);
        }
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
    ): void {
        $gameId = trim($gameId);

        if ($gameId === '') {
            return;
        }

        $this->afterCommit(function () use ($gameId, $scopeType, $scopeId, $dimension, $values): void {
            foreach ($this->coverageRows($gameId, $scopeType, $scopeId, $dimension, $values) as $payload) {
                try {
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
            $counts = $this->generatedCountsForDimension($gameId, $currentDimension, $scopeType, $scopeId);
            $valueList = $values === null
                ? $this->dimensionValues($currentDimension)
                : array_values(array_unique(array_map(fn (string $value): string => $this->normalizeDimensionValue($currentDimension, $value), $values)));
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
    private function generatedCountsForDimension(string $gameId, string $dimension, string $scopeType, string $scopeId): array
    {
        $profile = $this->activeProfile($gameId);

        if ($profile === null) {
            return [];
        }

        $layers = $this->activeLayers($profile);
        $partnerRows = $scopeType === 'partner' ? $this->partnerDistributionRows($gameId, $scopeId) : [];
        $counts = [];

        foreach (DB::table('base_lottery_numbers')->get(['full_number', $dimension.' as value']) as $number) {
            $capacity = $this->capacityForNumber((string) $number->full_number, $layers);

            if ($scopeType === 'partner') {
                $assigned = 0;

                for ($copyIndex = 0; $copyIndex < $capacity; $copyIndex++) {
                    if ($this->ownerPartnerForCopy($partnerRows, (string) $number->full_number, $copyIndex) === $scopeId) {
                        $assigned++;
                    }
                }

                $capacity = $assigned;
            }

            $value = (string) $number->value;
            $counts[$value] = ($counts[$value] ?? 0) + $capacity;
        }

        return $counts;
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

        return $rows === [] ? [['partner_id' => $fallbackPartnerId, 'bp' => self::MAX_BP]] : $rows;
    }

    /**
     * @param array<int, array{partner_id: string, bp: int}> $rows
     */
    private function ownerPartnerForCopy(array $rows, string $fullNumber, int $copyIndex): ?string
    {
        $total = max(1, array_sum(array_column($rows, 'bp')));
        $score = (int) hexdec(substr(hash('sha256', $fullNumber.':'.$copyIndex.':partner'), 0, 8)) % $total;
        $cursor = 0;

        foreach ($rows as $row) {
            $cursor += $row['bp'];

            if ($score < $cursor) {
                return $row['partner_id'];
            }
        }

        return $rows[0]['partner_id'] ?? null;
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
     * @return array<int, string>
     */
    private function partnerScopeIdsForGame(string $gameId): array
    {
        $partnerIds = [];

        foreach (['stock_partner_distributions', 'stock_sale_limit_settings', 'partner_quotas'] as $table) {
            $query = DB::table($table)->where('game_id', $gameId);

            if ($table === 'stock_sale_limit_settings') {
                $query->where('scope_type', 'partner');
                $column = 'scope_id';
            } else {
                $column = 'partner_id';
            }

            foreach ($query->pluck($column)->all() as $partnerId) {
                if ($partnerId !== null && $partnerId !== '') {
                    $partnerIds[] = (string) $partnerId;
                }
            }
        }

        return array_values(array_unique($partnerIds));
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
