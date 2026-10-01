<?php

namespace Tests\Feature;

use Illuminate\Support\Facades\Artisan;
use Symfony\Component\Console\Command\Command as SymfonyCommand;
use Tests\TestCase;

class M10MigrationRehearsalCutoverRollbackTest extends TestCase
{
    public function test_Migration_rehearsal_command_emits_safe_machine_readable_report(): void
    {
        config([
            'platform.migration_rehearsal.source_type' => 'legacy-postgres-redaction-source',
            'platform.migration_rehearsal.source_dsn' => 'postgres://legacy-user:legacy-password@legacy-prod.internal/newpaotang',
            'platform.migration_rehearsal.source_token' => 'legacy-source-token-placeholder',
            'platform.migration_rehearsal.object_storage_bucket' => 'legacy-ticket-image-bucket',
            'platform.migration_rehearsal.secret_reference' => 'secret-manager/prod/migration',
            'platform.migration_rehearsal.release_image_tag' => 'paotang-api:release-redaction',
            'platform.migration_rehearsal.previous_image_tag' => 'paotang-api:previous-redaction',
        ]);

        $exitCode = Artisan::call('platform:migration:rehearsal', ['--dry-run' => true, '--format' => 'json']);
        $output = Artisan::output();
        $report = json_decode($output, true);

        $this->assertSame(SymfonyCommand::SUCCESS, $exitCode);
        $this->assertIsArray($report);
        $this->assertSame('blocked_external', $report['status']);
        $this->assertFalse($report['production_approved']);
        $this->assertTrue($report['boundary']['dry_run']);
        $this->assertTrue($report['boundary']['local_dev_verifiable']);
        $this->assertTrue($report['boundary']['synthetic_seeded_data_only']);
        $this->assertFalse($report['boundary']['external_services_called']);
        $this->assertFalse($report['boundary']['destructive_production_operations_attempted']);
        $this->assertFalse($report['boundary']['old_data_payloads_loaded']);
        $this->assertFalse($report['boundary']['production_approved']);
        $this->assertSame('ready_local', $report['old_data_migration_strategy']['status']);
        $this->assertSame('ready_local', $report['rehearsal_fixtures']['status']);
        $this->assertSame('blocked_external', $report['snapshot_requirements']['status']);
        $this->assertSame('blocked_external', $report['cutover']['status']);
        $this->assertSame('blocked_external', $report['rollback']['status']);
        $this->assertSame('blocked_external', $report['production_secret_boundary']['status']);
        $this->assertSame('ready_local', $report['helpers']['status']);
        $this->assertTrue($report['rehearsal_fixtures']['synthetic_seeded_data_only']);
        $this->assertFalse($report['rehearsal_fixtures']['real_old_data_dumps_committed']);
        $this->assertContains('real_old_data_source_missing', $report['blockers']);
        $this->assertContains('real_database_snapshot_missing', $report['blockers']);
        $this->assertContains('real_object_storage_metadata_snapshot_missing', $report['blockers']);
        $this->assertContains('production_secret_management_missing', $report['blockers']);
        $this->assertContains('staging_rehearsal_not_completed', $report['blockers']);
        $this->assertContains('rollback_rehearsal_not_executed', $report['blockers']);
        $this->assertContains('docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json', $report['docker_validation_commands']);
        $this->assertSame('[REDACTED]', $report['production_secret_boundary']['redacted_config']['source_dsn']);
        $this->assertSame('[REDACTED]', $report['production_secret_boundary']['redacted_config']['source_token']);
        $this->assertSame('[CONFIGURED]', $report['production_secret_boundary']['redacted_config']['object_storage_bucket']);
        $this->assertSame('[REDACTED]', $report['production_secret_boundary']['redacted_config']['secret_reference']);
        $this->assertSame('[CONFIGURED]', $report['cutover']['redacted_config']['release_image_tag']);
        $this->assertSame('[CONFIGURED]', $report['rollback']['redacted_config']['previous_image_tag']);

        foreach ([
            'legacy-postgres-redaction-source',
            'postgres://legacy-user:legacy-password@legacy-prod.internal/newpaotang',
            'legacy-source-token-placeholder',
            'legacy-ticket-image-bucket',
            'secret-manager/prod/migration',
            'paotang-api:release-redaction',
            'paotang-api:previous-redaction',
        ] as $rawValue) {
            $this->assertStringNotContainsString($rawValue, $output);
        }
    }

    public function test_Rehearsal_runbooks_and_scripts_preserve_local_dev_boundary(): void
    {
        $docs = [
            'ops/m10/old-data-migration-strategy.md',
            'ops/m10/migration-rehearsal-runbook.md',
            'ops/m10/migration-rehearsal-fixtures.md',
            'ops/m10/cutover-runbook.md',
            'ops/m10/rollback-drill-runbook.md',
            'ops/m10/snapshot-requirements.md',
            'ops/m10/production-secret-boundary.md',
        ];

        foreach ($docs as $path) {
            $doc = $this->workspaceFile($path);

            $this->assertStringContainsString('docker compose', $doc, $path);
            $this->assertStringContainsString('production', strtolower($doc), $path);
        }

        $strategy = $this->workspaceFile('ops/m10/old-data-migration-strategy.md');
        $fixtures = $this->workspaceFile('ops/m10/migration-rehearsal-fixtures.md');
        $cutover = $this->workspaceFile('ops/m10/cutover-runbook.md');
        $rollback = $this->workspaceFile('ops/m10/rollback-drill-runbook.md');
        $snapshots = $this->workspaceFile('ops/m10/snapshot-requirements.md');
        $secrets = $this->workspaceFile('ops/m10/production-secret-boundary.md');

        $this->assertStringContainsString('idempotency', strtolower($strategy));
        $this->assertStringContainsString('reject report', strtolower($strategy));
        $this->assertStringContainsString('synthetic and seeded data only', $fixtures);
        $this->assertStringContainsString('previous image tag', $rollback);
        $this->assertStringContainsString('feature flag', $rollback);
        $this->assertStringContainsString('queue pause', $rollback);
        $this->assertStringContainsString('tenant maintenance', $rollback);
        $this->assertStringContainsString('preflight', $cutover);
        $this->assertStringContainsString('abort criteria', strtolower($cutover));
        $this->assertStringContainsString('object-storage metadata snapshot', strtolower($snapshots));
        $this->assertStringContainsString('[REDACTED]', $secrets);
        $this->assertStringContainsString('production_approved=false', $strategy);
    }

    public function test_Helper_scripts_docs_and_env_keep_migration_rehearsal_docker_only(): void
    {
        $scripts = [
            'scripts/platform-migration-rehearsal.sh',
            'scripts/platform-cutover-preflight.sh',
            'scripts/platform-rollback-drill.sh',
        ];

        foreach ($scripts as $path) {
            $script = $this->workspaceFile($path);

            $this->assertStringContainsString('docker compose', $script, $path);
            $this->assertStringNotContainsString("\nphp artisan", $script, $path);
            $this->assertStringNotContainsString("\ncomposer ", $script, $path);
            $this->assertStringNotContainsString("\npsql ", $script, $path);
            $this->assertStringNotContainsString("\npg_dump ", $script, $path);
        }

        $consoleDoc = $this->workspaceFile('docs/backend-console-commands.md');
        $m10Doc = $this->workspaceFile('docs/m10-deployment-monitoring-load-test.md');
        $env = $this->workspaceFile('apps/platform-api/.env.example');

        $this->assertStringContainsString('platform:migration:rehearsal', $consoleDoc);
        $this->assertStringContainsString('platform:migration:rehearsal', $m10Doc);
        $this->assertStringContainsString('MIGRATION_REHEARSAL_SOURCE_TYPE=', $env);
        $this->assertStringContainsString('MIGRATION_REHEARSAL_SOURCE_DSN=', $env);
        $this->assertStringContainsString('MIGRATION_REHEARSAL_SOURCE_TOKEN=', $env);
        $this->assertStringContainsString('PLATFORM_RELEASE_IMAGE_TAG=', $env);
        $this->assertStringContainsString('PLATFORM_PREVIOUS_IMAGE_TAG=', $env);
        $this->assertStringNotContainsString('TENANT_LOGO', $env);
        $this->assertStringNotContainsString('TENANT_THEME', $env);
        $this->assertStringNotContainsString('TENANT_PAYMENT', $env);
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
