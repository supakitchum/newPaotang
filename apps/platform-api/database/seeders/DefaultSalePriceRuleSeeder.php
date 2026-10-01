<?php

namespace Database\Seeders;

use Illuminate\Database\Seeder;
use Illuminate\Support\Facades\DB;

class DefaultSalePriceRuleSeeder extends Seeder
{
    private const MIN_SET_SIZE = 1;
    private const MAX_SET_SIZE = 20;
    private const UNIT_PRICE_AMOUNT = 8000;
    private const CURRENCY = 'THB';

    public function run(): void
    {
        $now = now();

        DB::table('games')
            ->orderBy('id')
            ->select(['id'])
            ->chunk(100, function ($games) use ($now): void {
                $rows = [];

                foreach ($games as $game) {
                    $gameId = (string) $game->id;

                    for ($setSize = self::MIN_SET_SIZE; $setSize <= self::MAX_SET_SIZE; $setSize++) {
                        $rows[] = [
                            'id' => $this->stableId($gameId, $setSize),
                            'game_id' => $gameId,
                            'set_size' => $setSize,
                            'price_amount' => $setSize * self::UNIT_PRICE_AMOUNT,
                            'currency' => self::CURRENCY,
                            'status' => 'active',
                            'created_at' => $now,
                            'updated_at' => $now,
                        ];
                    }
                }

                if ($rows === []) {
                    return;
                }

                DB::table('game_sale_price_rules')->upsert(
                    $rows,
                    ['game_id', 'set_size'],
                    ['price_amount', 'currency', 'status', 'updated_at'],
                );
            });
    }

    private function stableId(string $gameId, int $setSize): string
    {
        return 'gsp_'.substr(sha1('sale-price:'.$gameId.':'.$setSize), 0, 26);
    }
}
