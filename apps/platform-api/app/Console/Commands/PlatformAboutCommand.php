<?php

namespace App\Console\Commands;

use Illuminate\Console\Command;

class PlatformAboutCommand extends Command
{
    protected $signature = 'platform:about';

    protected $description = 'Show the platform API name.';

    public function handle(): int
    {
        $this->info('NewPaotang Platform API');

        return self::SUCCESS;
    }
}
