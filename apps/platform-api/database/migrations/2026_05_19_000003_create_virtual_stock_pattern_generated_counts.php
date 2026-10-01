<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::create('virtual_stock_pattern_generated_counts', function (Blueprint $table): void {
            $table->string('id', 40)->primary();
            $table->string('profile_id', 30);
            $table->string('source_id', 30);
            $table->string('game_id', 30);
            $table->string('scope_type');
            $table->string('scope_id', 30);
            $table->string('dimension', 16);
            $table->string('value', 32);
            $table->unsignedBigInteger('generated_count')->default(0);
            $table->timestampsTz();

            $table->foreign('profile_id')->references('id')->on('stock_supply_profiles')->cascadeOnDelete();
            $table->foreign('game_id')->references('id')->on('games')->cascadeOnDelete();
            $table->unique(['source_id', 'scope_type', 'scope_id', 'dimension', 'value'], 'virtual_stock_generated_counts_unique');
            $table->index(['game_id', 'profile_id', 'scope_type', 'scope_id', 'dimension'], 'virtual_stock_generated_counts_lookup');
        });

        $this->backfillCentralGeneratedCounts();
    }

    public function down(): void
    {
        Schema::dropIfExists('virtual_stock_pattern_generated_counts');
    }

    private function backfillCentralGeneratedCounts(): void
    {
        @set_time_limit(0);

        $profiles = DB::table('stock_supply_profiles')
            ->where('status', 'active')
            ->orderBy('game_id')
            ->get();

        foreach ($profiles as $profile) {
            $layers = DB::table('virtual_stock_supply_layers')
                ->where('profile_id', (string) $profile->id)
                ->where('status', 'active')
                ->orderBy('created_at')
                ->orderBy('id')
                ->get();

            if ($layers->isEmpty()) {
                $this->upsertCentralGeneratedCounts(
                    profileId: (string) $profile->id,
                    sourceId: (string) $profile->id,
                    gameId: (string) $profile->game_id,
                    seed: (string) $profile->seed,
                    distribution: $this->decodeJsonArray($profile->set_distribution_json),
                );

                continue;
            }

            foreach ($layers as $layer) {
                $this->upsertCentralGeneratedCounts(
                    profileId: (string) $profile->id,
                    sourceId: (string) $layer->id,
                    gameId: (string) $profile->game_id,
                    seed: (string) $layer->layer_seed,
                    distribution: $this->decodeJsonArray($layer->set_distribution_json),
                );
            }
        }
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
    private function upsertCentralGeneratedCounts(string $profileId, string $sourceId, string $gameId, string $seed, array $distribution): void
    {
        $now = now();
        $caseSql = $this->capacityCaseSql($distribution);

        DB::statement(
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
                substr(md5(? || ':central:central:' || dimension || ':' || value), 1, 40),
                ?,
                ?,
                ?,
                'central',
                'central',
                dimension,
                value,
                SUM(capacity)::bigint,
                ?::timestamptz,
                ?::timestamptz
            FROM scored
            CROSS JOIN LATERAL (VALUES ('back2', back2), ('back3', back3), ('front3', front3)) AS pattern(dimension, value)
            GROUP BY dimension, value
            ON CONFLICT (source_id, scope_type, scope_id, dimension, value)
            DO UPDATE SET
                generated_count = EXCLUDED.generated_count,
                updated_at = EXCLUDED.updated_at
            SQL,
            [$seed, $sourceId, $profileId, $sourceId, $gameId, $now, $now],
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
