<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Support\Facades\DB;

return new class extends Migration
{
    public function up(): void
    {
        @set_time_limit(0);

        $profiles = DB::table('stock_supply_profiles')
            ->where('status', 'active')
            ->orderBy('game_id')
            ->get();

        foreach ($profiles as $profile) {
            $gameId = (string) $profile->game_id;
            $profileId = (string) $profile->id;

            DB::table('virtual_stock_pattern_generated_counts')
                ->where('profile_id', $profileId)
                ->where('game_id', $gameId)
                ->where('scope_type', 'partner')
                ->delete();

            $hasPartnerDistribution = DB::table('stock_partner_distributions')
                ->where('game_id', $gameId)
                ->where('status', 'active')
                ->where('percent_basis_points', '>', 0)
                ->exists();

            if (! $hasPartnerDistribution) {
                continue;
            }

            $sources = DB::table('virtual_stock_supply_layers')
                ->where('profile_id', $profileId)
                ->where('status', 'active')
                ->orderBy('created_at')
                ->orderBy('id')
                ->get(['id', 'layer_seed', 'set_distribution_json']);

            if ($sources->isEmpty()) {
                $sources = collect([(object) [
                    'id' => $profileId,
                    'layer_seed' => (string) $profile->seed,
                    'set_distribution_json' => $profile->set_distribution_json,
                ]]);
            }

            foreach ($sources as $source) {
                $this->storePartnerGeneratedPatternCounts(
                    profileId: $profileId,
                    sourceId: (string) $source->id,
                    gameId: $gameId,
                    seed: (string) $source->layer_seed,
                    distribution: $this->decodeJsonArray($source->set_distribution_json),
                    now: now(),
                );
            }
        }
    }

    public function down(): void
    {
        DB::table('virtual_stock_pattern_generated_counts')
            ->where('scope_type', 'partner')
            ->delete();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function decodeJsonArray(mixed $json): array
    {
        if (! is_string($json) || trim($json) === '') {
            return [];
        }

        $decoded = json_decode($json, true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @param array<int, array<string, mixed>> $distribution
     */
    private function storePartnerGeneratedPatternCounts(
        string $profileId,
        string $sourceId,
        string $gameId,
        string $seed,
        array $distribution,
        mixed $now,
    ): void {
        $caseSql = $this->capacityCaseSql($distribution);

        DB::statement(
            <<<SQL
            WITH partner_ranges AS (
                SELECT
                    partner_id,
                    COALESCE(
                        SUM(percent_basis_points) OVER (ORDER BY partner_id ROWS BETWEEN UNBOUNDED PRECEDING AND 1 PRECEDING),
                        0
                    )::bigint AS start_bp,
                    SUM(percent_basis_points) OVER (ORDER BY partner_id ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)::bigint AS end_bp,
                    SUM(percent_basis_points) OVER ()::bigint AS total_bp
                FROM stock_partner_distributions
                WHERE game_id = ?
                  AND status = 'active'
                  AND percent_basis_points > 0
            ),
            scored AS (
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
            ),
            assigned AS (
                SELECT
                    partner_ranges.partner_id,
                    scored.back2,
                    scored.back3,
                    scored.front3
                FROM scored
                JOIN LATERAL generate_series(0, scored.capacity - 1) AS copy(copy_index) ON scored.capacity > 0
                JOIN partner_ranges
                  ON ((('x' || substr(encode(sha256((scored.full_number || ':' || copy.copy_index::text || ':partner')::bytea), 'hex'), 1, 8))::bit(32)::bigint) % partner_ranges.total_bp) >= partner_ranges.start_bp
                 AND ((('x' || substr(encode(sha256((scored.full_number || ':' || copy.copy_index::text || ':partner')::bytea), 'hex'), 1, 8))::bit(32)::bigint) % partner_ranges.total_bp) < partner_ranges.end_bp
            )
            INSERT INTO virtual_stock_pattern_generated_counts (
                id,
                profile_id,
                source_id,
                game_id,
                scope_type,
                scope_id,
                dimension,
                value,
                generated_count,
                created_at,
                updated_at
            )
            SELECT
                substr(md5(? || ':partner:' || partner_id || ':' || dimension || ':' || value), 1, 40),
                ?,
                ?,
                ?,
                'partner',
                partner_id,
                dimension,
                value,
                COUNT(*)::bigint,
                ?::timestamptz,
                ?::timestamptz
            FROM assigned
            CROSS JOIN LATERAL (VALUES ('back2', back2), ('back3', back3), ('front3', front3)) AS pattern(dimension, value)
            GROUP BY partner_id, dimension, value
            ON CONFLICT (source_id, scope_type, scope_id, dimension, value)
            DO UPDATE SET
                generated_count = EXCLUDED.generated_count,
                updated_at = EXCLUDED.updated_at
            SQL,
            [$gameId, $seed, $sourceId, $profileId, $sourceId, $gameId, $now, $now],
        );
    }

    /**
     * @param array<int, array<string, mixed>> $distribution
     */
    private function capacityCaseSql(array $distribution): string
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

            $cursor = min(10000, $cursor + $basisPoints);
            $setSize = max(1, (int) ($row['set_size'] ?? 1));
            $clauses[] = 'WHEN score < '.$cursor.' THEN '.$setSize;
        }

        return $clauses === [] ? '1' : 'CASE '.implode(' ', $clauses).' ELSE 1 END';
    }
};
