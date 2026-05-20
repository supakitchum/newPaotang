<?php

namespace App\Console\Commands;

use App\Modules\PartnerStore\Services\BaseLotteryNumberSeedService;
use Illuminate\Console\Command;

class SeedBaseLotteryNumbersCommand extends Command
{
    protected $signature = 'stock:base-lottery:seed
        {--chunk=5000 : Insert chunk size}
        {--source= : JSON file path. Defaults to BASE_LOTTERY_NUMBERS_PATH}
        {--truncate : Clear base_lottery_numbers before seeding}';

    protected $description = 'Seed the virtual base lottery number universe from an approved JSON number list.';

    public function handle(BaseLotteryNumberSeedService $seeder): int
    {
        $chunkSize = max(100, min(10000, (int) $this->option('chunk')));
        $source = trim((string) ($this->option('source') ?: env('BASE_LOTTERY_NUMBERS_PATH', '')));

        if ($source === '' && $seeder->resolveSource() === null) {
            $this->error('Base lottery JSON source is required. Pass --source=/path/to/number.json, set BASE_LOTTERY_NUMBERS_PATH, or place number.json at storage/app/public/number.json.');

            return self::FAILURE;
        }

        try {
            $result = $seeder->seed(
                source: $source === '' ? null : $source,
                chunkSize: $chunkSize,
                truncate: (bool) $this->option('truncate'),
                warn: function (string $message): void {
                    $this->warn($message);
                },
                progress: function (string $message): void {
                    $this->line($message);
                },
            );
        } catch (\Throwable $exception) {
            $this->error($exception->getMessage());

            return self::FAILURE;
        }

        if ($result['skipped']) {
            $this->error($result['skipped_reason'] ?? 'Base lottery seed skipped.');

            return self::FAILURE;
        }

        $this->info('Base lottery seed completed. Checked '.$result['checked'].' rows, accepted '.$result['accepted'].' unique numbers, skipped '.$result['invalid'].' invalid rows, stored '.$result['stored'].' numbers.');

        return self::SUCCESS;
    }
}
