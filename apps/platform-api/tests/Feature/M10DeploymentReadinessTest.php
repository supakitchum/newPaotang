<?php

namespace Tests\Feature;

use Database\Seeders\BaseLotteryNumberSeeder;
use Database\Seeders\DatabaseSeeder;
use Database\Seeders\DemoTenantSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\DB;
use Symfony\Component\Console\Command\Command as SymfonyCommand;
use Tests\TestCase;

class M10DeploymentReadinessTest extends TestCase
{
    use RefreshDatabase;

    public function test_Platform_smoke_command_checks_dependencies_seeded_logins_and_monitoring_defaults(): void
    {
        config(['platform.stock_generation.base_lottery_numbers_path' => $this->baseLotteryFixturePath()]);

        $this->seed([
            DatabaseSeeder::class,
            DemoTenantSeeder::class,
            BaseLotteryNumberSeeder::class,
        ]);

        $this->artisan('platform:smoke')
            ->expectsOutput('app: ok')
            ->expectsOutput('database: ok')
            ->expectsOutput('cache: ok')
            ->expectsOutput('queue: '.config('queue.default'))
            ->expectsOutput('monitoring-defaults: ok')
            ->expectsOutput('base-lottery-numbers: ok')
            ->expectsOutput('seeded-logins: ok')
            ->assertExitCode(SymfonyCommand::SUCCESS);

        foreach (['par_demo_alpha', 'par_demo_beta', 'par_demo_gamma'] as $partnerId) {
            $this->assertDatabaseHas('partner_monitoring_profiles', [
                'partner_id' => $partnerId,
                'status' => 'active',
            ]);

            $this->assertDatabaseHas('partner_alert_policies', [
                'partner_id' => $partnerId,
                'policy_key' => 'default_health',
                'status' => 'active',
            ]);

            $this->assertDatabaseHas('partner_health_checks', [
                'partner_id' => $partnerId,
                'check_key' => 'site_config',
            ]);
        }

        $requiredMeters = [
            'api_requests',
            'booking_requests',
            'checkout_requests',
            'orders',
            'sold_tickets',
            'stock_synced',
            'image_bandwidth_gb',
            'storage_gb',
            'queue_jobs',
            'sync_events',
        ];

        foreach ($requiredMeters as $meter) {
            $this->assertSame(3, DB::table('partner_usage_meters')->where('meter_key', $meter)->count(), $meter.' meter must exist for every demo partner.');
        }
    }

    private function baseLotteryFixturePath(): string
    {
        $dir = storage_path('framework/testing/deployment-readiness-base-lottery');

        if (! is_dir($dir)) {
            mkdir($dir, 0777, true);
        }

        $path = $dir.'/number.json';
        file_put_contents($path, json_encode([
            ['number' => '001100'],
            ['number' => '123456'],
        ], JSON_THROW_ON_ERROR));

        return $path;
    }

    public function test_Root_health_routes_match_openapi_readiness_contract(): void
    {
        $this->getJson('/health')
            ->assertOk()
            ->assertJsonStructure(['status', 'checks']);

        $this->getJson('/health/live')
            ->assertOk()
            ->assertJsonPath('status', 'ok');

        $this->getJson('/health/ready')
            ->assertOk()
            ->assertJsonPath('status', 'ok');
    }

    public function test_Compose_defines_backend_runtime_roles_without_removing_local_frontend_services(): void
    {
        $compose = $this->workspaceFile('compose.yaml');

        $this->assertStringContainsString('platform-api:', $compose);
        $this->assertStringContainsString('platform-api-worker:', $compose);
        $this->assertStringContainsString('platform-api-scheduler:', $compose);
        $this->assertStringContainsString('platform-api-smoke:', $compose);
        $this->assertStringContainsString('php artisan queue:work', $compose);
        $this->assertStringContainsString('php artisan schedule:run', $compose);
        $this->assertStringContainsString('php artisan platform:smoke', $compose);
        $this->assertStringContainsString('postgres:', $compose);
        $this->assertStringContainsString('valkey:', $compose);
        $this->assertStringContainsString('customer:', $compose);
        $this->assertStringContainsString('back-office:', $compose);
    }

    public function test_Env_template_keeps_infrastructure_config_out_of_tenant_config(): void
    {
        $env = file_get_contents(base_path('.env.example'));

        $this->assertIsString($env);

        foreach (['DB_HOST', 'REDIS_HOST', 'QUEUE_CONNECTION', 'CACHE_STORE', 'SESSION_DRIVER', 'CDN_BASE_URL', 'REVERB_HOST', 'PLATFORM_METRICS_ENABLED'] as $key) {
            $this->assertStringContainsString($key.'=', $env);
        }

        foreach (['TENANT_LOGO', 'TENANT_THEME', 'TENANT_PAYMENT', 'TENANT_DOMAIN', 'TENANT_FEATURE', 'LOGO_URL', 'THEME_PRIMARY_COLOR', 'PAYMENT_CHANNEL'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $env, $forbidden.' belongs in tenant database config, not environment templates.');
        }
    }

    public function test_M10_documentation_load_tests_and_ci_guardrails_exist(): void
    {
        $doc = $this->workspaceFile('docs/m10-deployment-monitoring-load-test.md');

        foreach (['Docker-only commands', 'Health And Smoke Checks', 'Load-Test Scaffolding', 'Migration Rehearsal Checklist', 'Cutover Checklist', 'Rollback Checklist', 'Accepted Risks Carried Forward'] as $needle) {
            $this->assertStringContainsString($needle, $doc);
        }

        $scenarios = [
            'partner-tenant-burst-sync.js',
            'customer-stock-search.js',
            'concurrent-booking-same-stock.js',
            'checkout-wallet-consistency.js',
            'reward-publish-spike.js',
            'reward-checking-queue-chunk.js',
            'ticket-image-cdn-spike.js',
        ];

        foreach ($scenarios as $scenario) {
            $contents = $this->workspaceFile('load-tests/k6/'.$scenario);

            $this->assertStringContainsString('export const options', $contents, $scenario.' must be a runnable k6 scaffold.');
            $this->assertStringContainsString('BASE_URL', $contents, $scenario.' must target configurable Docker-hosted services.');
        }

        $workflow = $this->workspaceFile('.github/workflows/platform-api-m10.yml');

        $this->assertStringContainsString('docker compose build platform-api', $workflow);
        $this->assertStringContainsString('docker compose run --rm platform-api php artisan test', $workflow);
    }

    private function workspaceFile(string $path): string
    {
        $workspaceRoots = array_filter([
            env('WORKSPACE_ROOT'),
            '/workspace',
            dirname(base_path(), 2),
        ]);

        foreach ($workspaceRoots as $root) {
            $file = rtrim((string) $root, '/').'/'.$path;

            if (is_file($file)) {
                $contents = file_get_contents($file);

                $this->assertIsString($contents);

                return $contents;
            }
        }

        $this->fail($path.' must exist in the mounted workspace.');
    }
}
