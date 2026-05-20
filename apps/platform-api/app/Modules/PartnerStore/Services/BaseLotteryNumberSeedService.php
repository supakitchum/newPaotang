<?php

namespace App\Modules\PartnerStore\Services;

use Illuminate\Support\Facades\DB;
use RuntimeException;

class BaseLotteryNumberSeedService
{
    /**
     * @return array{
     *     source: string,
     *     checked: int,
     *     accepted: int,
     *     invalid: int,
     *     stored: int,
     *     skipped: bool,
     *     skipped_reason?: string
     * }
     */
    public function seed(?string $source = null, int $chunkSize = 5000, bool $truncate = false, ?callable $warn = null, ?callable $progress = null): array
    {
        $resolvedSource = $this->resolveSource($source);

        if ($resolvedSource === null) {
            return [
                'source' => '',
                'checked' => 0,
                'accepted' => 0,
                'invalid' => 0,
                'stored' => (int) DB::table('base_lottery_numbers')->count(),
                'skipped' => true,
                'skipped_reason' => 'Base lottery JSON source was not found.',
            ];
        }

        $decoded = json_decode((string) file_get_contents($resolvedSource), true);

        if (! is_array($decoded)) {
            throw new RuntimeException('Base lottery JSON source must be an array of numbers or objects with a number field.');
        }

        if ($truncate) {
            DB::table('base_lottery_numbers')->delete();
        }

        $chunkSize = max(100, min(10000, $chunkSize));
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

                if ($invalid <= 5 && $warn !== null) {
                    $warn('Skipped invalid base lottery number at index '.$index);
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

            if (($valid % ($chunkSize * 20)) === 0 && $progress !== null) {
                $progress('Seeded '.$valid.' valid numbers');
            }
        }

        if ($rows !== []) {
            DB::table('base_lottery_numbers')->insertOrIgnore($rows);
        }

        return [
            'source' => $resolvedSource,
            'checked' => $checked,
            'accepted' => $valid,
            'invalid' => $invalid,
            'stored' => (int) DB::table('base_lottery_numbers')->count(),
            'skipped' => false,
        ];
    }

    public function resolveSource(?string $source = null): ?string
    {
        if ($source !== null && trim($source) !== '') {
            $path = trim($source);

            return is_file($path) && is_readable($path) ? $path : null;
        }

        $candidates = array_values(array_filter([
            config('platform.stock_generation.base_lottery_numbers_path'),
            storage_path('app/public/number.json'),
            storage_path('app/public/number2.json'),
        ], fn (mixed $candidate): bool => is_string($candidate) && trim($candidate) !== ''));

        foreach ($candidates as $candidate) {
            $path = (string) $candidate;

            if (is_file($path) && is_readable($path)) {
                return $path;
            }
        }

        return null;
    }
}
