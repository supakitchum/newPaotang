<?php

namespace Tests\Feature;

use Database\Seeders\BaseLotteryNumberSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Tests\TestCase;

class BaseLotteryNumberSeederTest extends TestCase
{
    use RefreshDatabase;

    public function test_BaseLotteryNumberSeeder_seeds_base_lottery_numbers_when_source_is_configured(): void
    {
        config(['platform.stock_generation.base_lottery_numbers_path' => $this->fixturePath()]);

        $this->seed(BaseLotteryNumberSeeder::class);

        $this->assertSame(3, DB::table('base_lottery_numbers')->count());
        $this->assertSame('001100', DB::table('base_lottery_numbers')->min('full_number'));
        $this->assertSame('123456', DB::table('base_lottery_numbers')->max('full_number'));
        $this->assertDatabaseHas('base_lottery_numbers', [
            'full_number' => '123456',
            'front3' => '123',
            'back3' => '456',
            'back2' => '56',
        ]);
    }

    public function test_BaseLotteryNumberSeeder_is_idempotent(): void
    {
        config(['platform.stock_generation.base_lottery_numbers_path' => $this->fixturePath()]);

        $this->seed(BaseLotteryNumberSeeder::class);
        $this->seed(BaseLotteryNumberSeeder::class);

        $this->assertSame(3, DB::table('base_lottery_numbers')->count());
    }

    public function test_stock_base_lottery_seed_command_seeds_from_explicit_source(): void
    {
        $path = $this->fixturePath();

        DB::table('base_lottery_numbers')->insert([
            'full_number' => '999999',
            'front3' => '999',
            'back3' => '999',
            'back2' => '99',
            'created_at' => now(),
            'updated_at' => now(),
        ]);

        $this->artisan('stock:base-lottery:seed', [
            '--source' => $path,
            '--truncate' => true,
            '--chunk' => 100,
        ])->assertExitCode(0);

        $this->assertSame(3, DB::table('base_lottery_numbers')->count());
        $this->assertDatabaseMissing('base_lottery_numbers', ['full_number' => '999999']);
        $this->assertDatabaseHas('base_lottery_numbers', ['full_number' => '011200']);
    }

    private function fixturePath(): string
    {
        $dir = storage_path('framework/testing/base-lottery-seeder');

        if (! is_dir($dir)) {
            mkdir($dir, 0777, true);
        }

        $path = $dir.'/number.json';
        file_put_contents($path, json_encode([
            ['number' => '001100'],
            ['number' => '011200'],
            ['number' => '011200'],
            ['full_number' => '123456'],
            ['number' => 'invalid'],
            ['number' => '12345'],
        ], JSON_THROW_ON_ERROR));

        return $path;
    }
}
