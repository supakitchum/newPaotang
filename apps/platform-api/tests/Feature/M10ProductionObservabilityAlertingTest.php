<?php

namespace Tests\Feature;

use App\Models\PartnerAlertEvent;
use App\Models\PartnerDailyUsageSummary;
use App\Shared\Observability\ObservabilityCatalog;
use Database\Seeders\DatabaseSeeder;
use Illuminate\Foundation\Testing\RefreshDatabase;
use Illuminate\Support\Facades\Artisan;
use Symfony\Component\Console\Command\Command as SymfonyCommand;
use Tests\TestCase;

class M10ProductionObservabilityAlertingTest extends TestCase
{
    use RefreshDatabase;

    public function test_Observability_report_command_emits_safe_machine_readable_inventory(): void
    {
        $this->seed(DatabaseSeeder::class);
        config(['platform.alerts.webhook_url' => 'https://hooks.example.test/services/super-secret-token']);

        $exitCode = Artisan::call('platform:observability:report', ['--format' => 'json']);
        $output = Artisan::output();
        $report = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($report);
        $this->assertContains($report['status'], ['ready_local', 'degraded_local']);
        $this->assertFalse($report['boundary']['production_approved']);
        $this->assertTrue($report['schema_readiness']['partner_alert_events']);
        $this->assertTrue($report['schema_readiness']['partner_usage_events']);
        $this->assertTrue($report['schema_readiness']['partner_daily_usage_summaries']);
        $this->assertSame([], $report['summary']['missing_required_alert_policies']);
        $this->assertContains('partner_id', $report['metric_label_policy']);
        $this->assertContains('tenant_id', $report['metric_label_policy']);
        $this->assertStringNotContainsString('super-secret-token', $output);
        $this->assertStringContainsString('[REDACTED]', $output);
    }

    public function test_Default_alert_policies_are_seeded_for_each_demo_partner(): void
    {
        $this->seed(DatabaseSeeder::class);

        $catalog = new ObservabilityCatalog();
        $required = array_merge(['default_health'], $catalog->requiredAlertPolicyKeys());

        foreach (['par_demo_alpha', 'par_demo_beta', 'par_demo_gamma'] as $partnerId) {
            foreach ($required as $policyKey) {
                $this->assertDatabaseHas('partner_alert_policies', [
                    'partner_id' => $partnerId,
                    'policy_key' => $policyKey,
                    'status' => 'active',
                ]);
            }
        }
    }

    public function test_Alert_check_dry_run_includes_partner_tenant_labels_and_writes_no_events(): void
    {
        $this->seed(DatabaseSeeder::class);
        $this->insertHighErrorSummary();

        $exitCode = Artisan::call('platform:alerts:check', ['--dry-run' => true, '--format' => 'json']);
        $output = Artisan::output();
        $result = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($result);
        $this->assertTrue($result['dry_run']);
        $this->assertFalse($result['boundary']['production_approved']);
        $this->assertFalse($result['boundary']['external_delivery_attempted']);
        $this->assertSame(0, PartnerAlertEvent::query()->count());

        $apiPolicy = collect($result['results'])->firstWhere('policy_key', 'api_error_rate_high');

        $this->assertIsArray($apiPolicy);
        $this->assertSame('alert', $apiPolicy['state']);
        $this->assertSame('par_demo_alpha', $apiPolicy['labels']['partner_id']);
        $this->assertSame('ten_demo_alpha', $apiPolicy['labels']['tenant_id']);
        $this->assertSame('newpaotang', $apiPolicy['labels']['platform']);
    }

    public function test_Alert_check_can_write_safe_local_database_event_with_redacted_payload(): void
    {
        $this->seed(DatabaseSeeder::class);
        $this->insertHighErrorSummary();
        config([
            'platform.alerts.enabled' => true,
            'platform.alerts.webhook_url' => 'https://hooks.example.test/services/another-secret-token',
        ]);

        $exitCode = Artisan::call('platform:alerts:check', ['--format' => 'json']);
        $output = Artisan::output();
        $result = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($result);
        $this->assertFalse($result['dry_run']);
        $this->assertGreaterThanOrEqual(1, $result['summary']['events_delivered']);
        $this->assertDatabaseHas('partner_alert_events', [
            'partner_id' => 'par_demo_alpha',
            'tenant_id' => 'ten_demo_alpha',
            'policy_key' => 'api_error_rate_high',
            'status' => 'open',
            'channel' => 'database',
            'dry_run' => false,
        ]);

        $event = PartnerAlertEvent::query()
            ->where('partner_id', 'par_demo_alpha')
            ->where('policy_key', 'api_error_rate_high')
            ->firstOrFail();

        $payload = $event->payload_redacted_json;

        $this->assertIsArray($payload);
        $this->assertSame('[REDACTED]', $payload['channels']['webhook_url']);
        $this->assertStringNotContainsString('another-secret-token', json_encode($payload));
        $this->assertStringNotContainsString('another-secret-token', $output);
    }

    public function test_Env_and_ops_artifacts_keep_release_boundary_and_tenant_config_rules(): void
    {
        $env = file_get_contents(base_path('.env.example'));

        $this->assertIsString($env);

        foreach (['PLATFORM_OBSERVABILITY_ENABLED=', 'PLATFORM_ALERTS_ENABLED=', 'PLATFORM_ALERT_CHANNELS=', 'PLATFORM_ALERT_WEBHOOK_URL='] as $key) {
            $this->assertStringContainsString($key, $env);
        }

        foreach (['TENANT_LOGO', 'TENANT_THEME', 'TENANT_PAYMENT', 'TENANT_DOMAIN', 'TENANT_FEATURE', 'LOGO_URL', 'THEME_PRIMARY_COLOR', 'PAYMENT_CHANNEL'] as $forbidden) {
            $this->assertStringNotContainsString($forbidden, $env, $forbidden.' belongs in tenant database config, not environment templates.');
        }

        foreach ([
            'ops/m10/observability-signal-inventory.md',
            'ops/m10/alert-channel-runbook.md',
            'ops/m10/dashboards/platform-overview.json',
            'ops/m10/dashboards/partner-health.json',
        ] as $path) {
            $contents = $this->workspaceFile($path);

            $this->assertNotSame('', trim($contents));
        }
    }

    private function insertHighErrorSummary(): void
    {
        PartnerDailyUsageSummary::query()->create([
            'id' => 'pdu_m10_alpha_high_error',
            'partner_id' => 'par_demo_alpha',
            'tenant_id' => 'ten_demo_alpha',
            'usage_date' => now()->toDateString(),
            'api_request_count' => 100,
            'booking_request_count' => 0,
            'checkout_request_count' => 0,
            'order_count' => 0,
            'sold_ticket_count' => 0,
            'image_bandwidth_gb' => 0,
            'storage_gb' => 0,
            'queue_job_count' => 0,
            'rate_limited_count' => 0,
            'error_count' => 10,
            'sync_event_count' => 0,
            'labels_json' => [
                'platform' => 'newpaotang',
                'partner_id' => 'par_demo_alpha',
                'tenant_id' => 'ten_demo_alpha',
            ],
        ]);
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
