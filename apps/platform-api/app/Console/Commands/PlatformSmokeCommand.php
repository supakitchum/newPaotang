<?php

namespace App\Console\Commands;

use App\Models\AdminUser;
use App\Models\PartnerAlertPolicy;
use App\Models\PartnerHealthCheck;
use App\Models\PartnerMonitoringProfile;
use App\Models\PartnerUsageMeter;
use Illuminate\Console\Command;
use Illuminate\Support\Facades\Cache;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Throwable;

class PlatformSmokeCommand extends Command
{
    protected $signature = 'platform:smoke {--no-seed-login : Skip local seeded admin credential checks}';

    protected $description = 'Run M10 Docker smoke checks for API dependencies, queue config, and bootstrap readiness.';

    public function handle(): int
    {
        $checks = [
            'app' => $this->checkApp(),
            'database' => $this->checkDatabase(),
            'cache' => $this->checkCache(),
            'queue' => $this->checkQueue(),
            'monitoring-defaults' => $this->checkMonitoringDefaults(),
            'base-lottery-numbers' => $this->checkBaseLotteryNumbers(),
        ];

        if (! $this->option('no-seed-login')) {
            $checks['seeded-logins'] = $this->checkSeededLogins();
        }

        foreach ($checks as $name => $result) {
            $this->line($name.': '.$result);
        }

        return in_array('failed', $checks, true) ? self::FAILURE : self::SUCCESS;
    }

    private function checkApp(): string
    {
        return config('app.name') !== null && config('app.env') !== null ? 'ok' : 'failed';
    }

    private function checkDatabase(): string
    {
        try {
            DB::select('select 1');

            return 'ok';
        } catch (Throwable) {
            return 'failed';
        }
    }

    private function checkCache(): string
    {
        try {
            $key = 'platform:smoke:'.substr(sha1((string) microtime(true)), 0, 12);
            Cache::put($key, 'ok', 10);

            return Cache::get($key) === 'ok' ? 'ok' : 'failed';
        } catch (Throwable) {
            return 'failed';
        }
    }

    private function checkQueue(): string
    {
        $connection = (string) config('queue.default');
        $connections = config('queue.connections');

        if ($connection === '' || ! is_array($connections) || ! array_key_exists($connection, $connections)) {
            return 'failed';
        }

        return $connection;
    }

    private function checkMonitoringDefaults(): string
    {
        try {
            if (! DB::table('partners')->exists()) {
                return 'ok';
            }

            $profiles = PartnerMonitoringProfile::where('status', 'active')->count();
            $meters = PartnerUsageMeter::where('status', 'active')->count();
            $policies = PartnerAlertPolicy::where('status', 'active')->count();
            $healthChecks = PartnerHealthCheck::count();

            return $profiles > 0 && $meters > 0 && $policies > 0 && $healthChecks > 0 ? 'ok' : 'failed';
        } catch (Throwable) {
            return 'failed';
        }
    }

    private function checkBaseLotteryNumbers(): string
    {
        try {
            if (! DB::table('partners')->exists() && ! DB::table('games')->exists()) {
                return 'ok';
            }

            if ((string) config('platform.stock_generation.base_lottery_numbers_path', '') === '') {
                return 'ok';
            }

            return DB::table('base_lottery_numbers')->exists() ? 'ok' : 'failed';
        } catch (Throwable) {
            return 'failed';
        }
    }

    private function checkSeededLogins(): string
    {
        try {
            foreach (['superadmin', 'translator', 'result', 'uploader'] as $username) {
                $admin = AdminUser::where('username', $username)->where('status', 'active')->first();

                if ($admin === null || ! Hash::check('1234', (string) $admin->password_hash)) {
                    return 'failed';
                }
            }

            return 'ok';
        } catch (Throwable) {
            return 'failed';
        }
    }
}
