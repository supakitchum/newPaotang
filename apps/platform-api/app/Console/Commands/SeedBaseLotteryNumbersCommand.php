<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;
use Illuminate\Support\Facades\DB;

class SeedBaseLotteryNumbersCommand extends Command
{
    protected $signature = 'stock:base-lottery:seed
        {--chunk=5000 : Insert chunk size}
        {--source= : JSON file path. Defaults to BASE_LOTTERY_NUMBERS_PATH}
        {--truncate : Clear base_lottery_numbers before seeding}';

    protected $description = 'Seed the virtual base lottery number universe from an approved JSON number list.';

    public function handle(): int
    {
        $chunkSize = max(100, min(10000, (int) $this->option('chunk')));
        $source = trim((string) ($this->option('source') ?: env('BASE_LOTTERY_NUMBERS_PATH', '')));

        if ($source === '') {
            $this->error('Base lottery JSON source is required. Pass --source=/path/to/number.json or set BASE_LOTTERY_NUMBERS_PATH.');

            return self::FAILURE;
        }

        if (! is_file($source) || ! is_readable($source)) {
            $this->error('Base lottery JSON source cannot be read: '.$source);

            return self::FAILURE;
        }

        $decoded = json_decode((string) file_get_contents($source), true);

        if (! is_array($decoded)) {
            $this->error('Base lottery JSON source must be an array of objects with a number field.');

            return self::FAILURE;
        }

        if ((bool) $this->option('truncate')) {
            DB::table('base_lottery_numbers')->delete();
        }

        $now = now();
        $checked = 0;
        $valid = 0;
        $invalid = 0;
        $rows = [];
        $seen = [];

        foreach ($decoded as $index => $row) {
            $checked++;
            $rawNumber = is_array($row) ? ($row['number'] ?? $row['full_number'] ?? null) : $row;
            $fullNumber = is_scalar($rawNumber) ? trim((string) $rawNumber) : '';

            if (! preg_match('/^[0-9]{6}$/', $fullNumber)) {
                $invalid++;

                if ($invalid <= 5) {
                    $this->warn('Skipped invalid base lottery number at index '.$index);
                }

                continue;
            }

            if (isset($seen[$fullNumber])) {
                continue;
            }

            $seen[$fullNumber] = true;
            $valid++;
            $rows[] = [
                'full_number' => $fullNumber,
                'front3' => substr($fullNumber, 0, 3),
                'back3' => substr($fullNumber, -3),
                'back2' => substr($fullNumber, -2),
                'created_at' => $now,
                'updated_at' => $now,
            ];

            if (count($rows) < $chunkSize) {
                continue;
            }

            DB::table('base_lottery_numbers')->insertOrIgnore($rows);
            $rows = [];

            if (($valid % ($chunkSize * 20)) === 0) {
                $this->line('Seeded '.$valid.' valid numbers');
            }
        }

        if ($rows !== []) {
            DB::table('base_lottery_numbers')->insertOrIgnore($rows);
        }

        $stored = DB::table('base_lottery_numbers')->count();

        $this->info('Base lottery seed completed. Checked '.$checked.' rows, accepted '.$valid.' unique numbers, skipped '.$invalid.' invalid rows, stored '.$stored.' numbers.');

        return self::SUCCESS;
    }
}
