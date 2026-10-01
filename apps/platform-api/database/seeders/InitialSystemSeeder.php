<?php

namespace Database\Seeders;

use App\Modules\Translations\Services\SystemTranslationService;
use Illuminate\Database\Seeder;

class InitialSystemSeeder extends Seeder
{
    public function run(): void
    {
        $this->call([
            DefaultRbacMenuSeeder::class,
            BootstrapAdminSeeder::class,
        ]);

        if ((bool) config('platform.stock_generation.seed_base_lottery_on_initial_seed', false)) {
            $this->call(BaseLotteryNumberSeeder::class);
        }

        app(SystemTranslationService::class)->syncCatalog();
    }
}
