<?php

namespace Database\Seeders;

use App\Modules\PartnerStore\Services\BaseLotteryNumberSeedService;
use Illuminate\Database\Seeder;

class BaseLotteryNumberSeeder extends Seeder
{
    public function run(): void
    {
        $result = app(BaseLotteryNumberSeedService::class)->seed(
            source: null,
            chunkSize: (int) config('platform.stock_generation.base_lottery_seed_chunk', 5000),
            truncate: false,
            warn: fn (string $message): bool => $this->command?->warn($message) ?? true,
            progress: fn (string $message): bool => $this->command?->line($message) ?? true,
        );

        if ($result['skipped']) {
            $this->command?->warn(($result['skipped_reason'] ?? 'Base lottery seed skipped.').' Set BASE_LOTTERY_NUMBERS_PATH or place number.json at storage/app/public/number.json.');

            return;
        }

        $this->command?->info('Base lottery seed completed. Checked '.$result['checked'].' rows, accepted '.$result['accepted'].' unique numbers, skipped '.$result['invalid'].' invalid rows, stored '.$result['stored'].' numbers.');
    }
}
