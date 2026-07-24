<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Crypt;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
return new class extends Migration
{
    /**
     * @var array<int, array{table: string, legacy: string, encrypted: string}>
     */
    private array $targets = [
        [
            'table' => 'affiliate_payouts',
            'legacy' => 'bank_account_json',
            'encrypted' => 'bank_account_encrypted',
        ],
        [
            'table' => 'affiliate_accounts',
            'legacy' => 'payout_profile_json',
            'encrypted' => 'payout_profile_encrypted',
        ],
        [
            'table' => 'customers',
            'legacy' => 'reward_payout_bank_account_json',
            'encrypted' => 'reward_payout_bank_account_encrypted',
        ],
    ];

    public function up(): void
    {
        foreach ($this->targets as $target) {
            if (
                ! Schema::hasTable($target['table'])
                || ! Schema::hasColumn($target['table'], $target['legacy'])
            ) {
                continue;
            }

            if (! Schema::hasColumn($target['table'], $target['encrypted'])) {
                Schema::table($target['table'], function (Blueprint $table) use ($target): void {
                    $table->text($target['encrypted'])->nullable();
                });
            }

            $this->encryptLegacyRows(
                $target['table'],
                $target['legacy'],
                $target['encrypted'],
            );

            DB::table($target['table'])
                ->whereNotNull($target['legacy'])
                ->update([$target['legacy'] => null]);
        }
    }

    public function down(): void
    {
        foreach (array_reverse($this->targets) as $target) {
            if (
                ! Schema::hasTable($target['table'])
                || ! Schema::hasColumn($target['table'], $target['legacy'])
                || ! Schema::hasColumn($target['table'], $target['encrypted'])
            ) {
                continue;
            }

            $this->restoreLegacyRows(
                $target['table'],
                $target['legacy'],
                $target['encrypted'],
            );

            Schema::table($target['table'], function (Blueprint $table) use ($target): void {
                $table->dropColumn($target['encrypted']);
            });
        }
    }

    private function encryptLegacyRows(string $table, string $legacyColumn, string $encryptedColumn): void
    {
        DB::table($table)
            ->select(['id', $legacyColumn, $encryptedColumn])
            ->whereNull($encryptedColumn)
            ->whereNotNull($legacyColumn)
            ->orderBy('id')
            ->chunkById(100, function ($rows) use ($table, $legacyColumn, $encryptedColumn): void {
                foreach ($rows as $row) {
                    $payload = $this->decodeLegacy($row->{$legacyColumn});
                    $encrypted = $payload === []
                        ? null
                        : Crypt::encryptString(json_encode(
                            $payload,
                            JSON_THROW_ON_ERROR | JSON_UNESCAPED_UNICODE | JSON_UNESCAPED_SLASHES,
                        ));

                    DB::table($table)
                        ->where('id', $row->id)
                        ->update([$encryptedColumn => $encrypted]);
                }
            }, 'id');
    }

    private function restoreLegacyRows(string $table, string $legacyColumn, string $encryptedColumn): void
    {
        DB::table($table)
            ->select(['id', $legacyColumn, $encryptedColumn])
            ->whereNotNull($encryptedColumn)
            ->orderBy('id')
            ->chunkById(100, function ($rows) use ($table, $legacyColumn, $encryptedColumn): void {
                foreach ($rows as $row) {
                    try {
                        $plain = Crypt::decryptString((string) $row->{$encryptedColumn});
                        $payload = json_decode($plain, true, flags: JSON_THROW_ON_ERROR);
                    } catch (\Throwable $exception) {
                        throw new RuntimeException(
                            sprintf('Cannot restore encrypted payload for %s row %s.', $table, $row->id),
                            previous: $exception,
                        );
                    }

                    if (! is_array($payload)) {
                        throw new RuntimeException(
                            sprintf('Encrypted payload for %s row %s is not an object.', $table, $row->id),
                        );
                    }

                    DB::table($table)
                        ->where('id', $row->id)
                        ->update([
                            $legacyColumn => $payload === []
                                ? null
                                : json_encode($payload, JSON_THROW_ON_ERROR),
                        ]);
                }
            }, 'id');
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeLegacy(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        if ($value === null || $value === '') {
            return [];
        }

        $decoded = json_decode((string) $value, true, flags: JSON_THROW_ON_ERROR);
        if (! is_array($decoded)) {
            throw new RuntimeException('Legacy bank payload must decode to an object.');
        }

        return $decoded;
    }
};
