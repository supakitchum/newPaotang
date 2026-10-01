<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Artisan;
use Illuminate\Support\Facades\Route;
use Symfony\Component\Console\Command\Command as SymfonyCommand;
use Tests\TestCase;

class M10HorizonReverbSchedulerHardeningTest extends TestCase
{
    public function test_Runtime_readiness_command_emits_safe_machine_readable_report(): void
    {
        config([
            'platform.realtime.app_id' => 'reverb-app-id-placeholder',
            'platform.realtime.admin_key' => 'reverb-key-placeholder',
            'platform.realtime.admin_secret' => 'reverb-secret-placeholder',
            'platform.realtime.host' => 'wss://reverb.fake-redaction.test',
            'platform.realtime.port' => '443',
            'platform.realtime.scheme' => 'https',
        ]);

        $exitCode = Artisan::call('platform:runtime:readiness', ['--format' => 'json']);
        $output = Artisan::output();
        $report = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($report);
        $this->assertSame('blocked_external', $report['status']);
        $this->assertFalse($report['production_approved']);
        $this->assertFalse($report['boundary']['production_approved']);
        $this->assertFalse($report['boundary']['external_services_called']);
        $this->assertFalse($report['boundary']['long_lived_processes_started']);
        $this->assertSame('ready_local', $report['queue_workers']['status']);
        $this->assertSame('blocked_external', $report['horizon']['status']);
        $this->assertSame('blocked_external', $report['reverb']['status']);
        $this->assertSame('ready_local', $report['scheduler']['status']);
        $this->assertSame('ready_local', $report['helpers']['status']);
        $this->assertContains('horizon_package_missing', $report['blockers']);
        $this->assertTrue($report['reverb']['package_installed']);
        $this->assertTrue($report['reverb']['runtime_profile_configured']);
        $this->assertNotContains('reverb_package_missing', $report['blockers']);
        $this->assertNotContains('reverb_runtime_profile_not_configured', $report['blockers']);
        $this->assertContains('reverb_tls_and_public_host_not_verified', $report['blockers']);
        $this->assertContains('reverb_scaling_and_load_not_verified', $report['blockers']);
        $this->assertFalse($report['horizon']['dashboard_route_registered']);
        $this->assertTrue($report['reverb']['auth_endpoints']['central']);
        $this->assertTrue($report['reverb']['auth_endpoints']['tenant']);
        $this->assertSame('[REDACTED]', $report['reverb']['redacted_config']['app_key']);
        $this->assertSame('[REDACTED]', $report['reverb']['redacted_config']['app_secret']);
        $this->assertSame('[CONFIGURED]', $report['reverb']['redacted_config']['host']);

        foreach (['reverb-app-id-placeholder', 'reverb-key-placeholder', 'reverb-secret-placeholder', 'wss://reverb.fake-redaction.test'] as $rawValue) {
            $this->assertStringNotContainsString($rawValue, $output);
        }
    }

    public function test_Queue_worker_profile_catalog_covers_configured_queues_and_separates_reporting(): void
    {
        $catalog = $this->jsonWorkspaceFile('ops/m10/queue-worker-profiles.json');
        $configuredQueues = array_values(array_filter(array_map(
            'trim',
            explode(',', $this->envValue('PLATFORM_WORKER_QUEUES')),
        )));
        $ownership = $catalog['queue_ownership'];
        $catalogQueues = array_column($ownership, 'queue');

        sort($configuredQueues);
        sort($catalogQueues);

        $this->assertSame($configuredQueues, $catalogQueues);

        $reportBuild = collect($ownership)->firstWhere('queue', 'report-build');
        $checkout = collect($ownership)->firstWhere('queue', 'checkout-finalize');
        $rewardHigh = collect($ownership)->firstWhere('queue', 'reward-check-high');

        $this->assertSame('background', $reportBuild['priority_class']);
        $this->assertSame('critical', $checkout['priority_class']);
        $this->assertSame('high', $rewardHigh['priority_class']);
        $this->assertNotSame($reportBuild['profile'], $checkout['profile']);
        $this->assertNotSame($reportBuild['profile'], $rewardHigh['profile']);
    }

    public function test_Scheduler_workloads_are_registered_and_visible_for_local_evidence(): void
    {
        $exitCode = Artisan::call('platform:runtime:readiness', ['--format' => 'json']);
        $report = json_decode(Artisan::output(), true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($report);
        $this->assertSame([], $report['scheduler']['missing_required_workloads']);
        $this->assertSame('ready_local', $report['scheduler']['status']);

        $commands = implode("\n", array_column($report['scheduler']['registered_workloads'], 'command'));

        foreach ([
            'stock:reservations:expire',
            'stock:sold:sync',
            'reward:check',
            'commission:calculate',
            'platform:alerts:check',
        ] as $command) {
            $this->assertStringContainsString($command, $commands);
        }

        $this->assertTrue(Route::has('storage.local') || Route::getRoutes()->count() > 0);
    }

    public function test_Docs_scripts_and_compose_keep_runtime_hardening_boundary(): void
    {
        $readme = $this->workspaceFile('load-tests/README.md');
        $compose = $this->workspaceFile('compose.yaml');
        $runtimeDoc = $this->workspaceFile('ops/m10/runtime-hardening-readiness.md');
        $horizonDoc = $this->workspaceFile('ops/m10/horizon-queue-supervision.md');
        $reverbDoc = $this->workspaceFile('ops/m10/reverb-deployment-readiness.md');
        $schedulerDoc = $this->workspaceFile('ops/m10/scheduler-workload-runbook.md');
        $workerScript = $this->workspaceFile('scripts/platform-api-worker-once.sh');
        $runtimeScript = $this->workspaceFile('scripts/platform-runtime-readiness.sh');

        $this->assertStringContainsString('CDN_BASE_URL', $readme);
        $this->assertStringContainsString('IMAGE_PATH', $readme);
        $this->assertStringContainsString('TICKET_IMAGE_CDN_IMAGE_PATH', $readme);
        $this->assertStringContainsString('BASE_URL', $readme);
        $this->assertStringContainsString('intentionally ignores normal API `BASE_URL`', $readme);
        $this->assertStringContainsString('platform-api-worker:', $compose);
        $this->assertStringContainsString('platform-api-scheduler:', $compose);
        $this->assertStringContainsString('queue:work --once --tries=1 --timeout=30 --queue="$QUEUE"', $workerScript);
        $this->assertStringContainsString('docker compose exec platform-api php artisan platform:runtime:readiness --format=json', $runtimeScript);

        foreach ([$runtimeDoc, $horizonDoc, $reverbDoc, $schedulerDoc] as $doc) {
            $this->assertStringContainsString('production', strtolower($doc));
            $this->assertStringContainsString('docker compose', $doc);
        }
    }

    /**
     * @return array<string, mixed>
     */
    private function jsonWorkspaceFile(string $path): array
    {
        $decoded = json_decode($this->workspaceFile($path), true);

        $this->assertIsArray($decoded);

        return $decoded;
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

    private function envValue(string $key): string
    {
        foreach (explode("\n", $this->workspaceFile('apps/platform-api/.env.example')) as $line) {
            if (str_starts_with($line, $key.'=')) {
                return substr($line, strlen($key) + 1);
            }
        }

        $this->fail($key.' must exist in apps/platform-api/.env.example.');
    }
}
