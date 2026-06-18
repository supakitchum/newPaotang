<?php

namespace App\Console\Commands;

use App\Modules\CentralStock\Services\CentralStockService;
use Illuminate\Console\Command;

class AutoCloseExpiredGamesCommand extends Command
{
    protected $signature = 'games:auto-close-expired {--limit=100}';

    protected $description = 'Automatically close open games 30 minutes after their sale close time.';

    public function handle(CentralStockService $centralStock): int
    {
        $result = $centralStock->autoCloseExpiredGames((int) $this->option('limit'));

        $this->info('Auto-closed games: '.$result['closed_count']);

        foreach ($result['closed_games'] as $game) {
            $this->line(sprintf(
                '- %s (%s) at %s',
                $game['code'] ?? $game['id'],
                $game['id'],
                $game['closed_at'],
            ));
        }

        return self::SUCCESS;
    }
}
