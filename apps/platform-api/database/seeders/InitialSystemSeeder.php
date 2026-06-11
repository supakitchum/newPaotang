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

        app(SystemTranslationService::class)->syncCatalog();
    }
}
