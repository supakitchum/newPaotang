<?php

namespace App\Console\Commands;

use App\Modules\Reward\Services\RewardService;
use Illuminate\Console\Command;

class ProcessRewardCheckCommand extends Command
{
    protected $signature = 'reward:check {reward_result_id?} {--chunk=100}';

    protected $description = 'Process reward result checks in deterministic chunks.';

    public function handle(RewardService $rewards): int
    {
        $processed = $rewards->processRewardCheck(
            $this->argument('reward_result_id') === null ? null : (string) $this->argument('reward_result_id'),
            (int) $this->option('chunk'),
        );

        $this->info('Processed reward tickets: '.$processed);

        return self::SUCCESS;
    }
}
