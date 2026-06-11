<?php

namespace App\Console\Commands;

use App\Models\SystemLanguage;
use App\Models\SystemTranslationKey;
use App\Modules\Translations\Services\SystemTranslationService;
use Illuminate\Console\Command;

class SyncStaticTranslationsCommand extends Command
{
    protected $signature = 'translations:sync-static';

    protected $description = 'Sync static translation catalog keys into runtime translation tables.';

    public function handle(SystemTranslationService $translations): int
    {
        $translations->syncCatalog();

        $this->info(sprintf(
            'Synced %d languages and %d translation keys.',
            SystemLanguage::query()->count(),
            SystemTranslationKey::query()->count(),
        ));

        return self::SUCCESS;
    }
}
