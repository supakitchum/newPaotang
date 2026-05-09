<?php

namespace App\Shared\Migration;

class MigrationRehearsalReadinessService
{
    /**
     * @return array<string, mixed>
     */
    public function report(bool $dryRun): array
    {
        $strategy = $this->strategyReadiness();
        $fixtures = $this->fixtureReadiness();
        $snapshots = $this->snapshotReadiness();
        $cutover = $this->cutoverReadiness();
        $rollback = $this->rollbackReadiness();
        $secrets = $this->secretBoundary();
        $helpers = $this->helperReadiness();
        $blockers = $this->blockers($strategy, $fixtures, $snapshots, $cutover, $rollback, $secrets, $helpers);

        if (! $dryRun) {
            array_unshift($blockers, 'dry_run_required_for_local_rehearsal');
        }

        return [
            'status' => $blockers === [] ? 'ready_local' : 'blocked_external',
            'generated_at' => now()->toISOString(),
            'production_approved' => false,
            'boundary' => [
                'local_dev_verifiable' => true,
                'dry_run' => $dryRun,
                'synthetic_seeded_data_only' => true,
                'external_services_called' => false,
                'long_lived_processes_started' => false,
                'destructive_production_operations_attempted' => false,
                'old_data_payloads_loaded' => false,
                'staging_approved' => false,
                'production_approved' => false,
                'client_delivery_approved' => false,
                'production_cutover_approved' => false,
                'production_rollback_approved' => false,
            ],
            'old_data_migration_strategy' => $strategy,
            'rehearsal_fixtures' => $fixtures,
            'snapshot_requirements' => $snapshots,
            'cutover' => $cutover,
            'rollback' => $rollback,
            'production_secret_boundary' => $secrets,
            'helpers' => $helpers,
            'blockers' => array_values(array_unique($blockers)),
            'docker_validation_commands' => [
                'docker compose exec platform-api php artisan platform:migration:rehearsal --dry-run --format=json',
                'docker compose run --rm platform-api php artisan migrate:status',
                'docker compose exec platform-api php artisan platform:smoke --no-seed-login',
                'docker compose exec platform-api php artisan platform:runtime:readiness --format=json',
                'docker compose run --rm platform-api php artisan schedule:list',
                'docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default',
                'docker compose run --rm platform-api php artisan list',
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function strategyReadiness(): array
    {
        $artifact = 'ops/m10/old-data-migration-strategy.md';

        return [
            'status' => is_file($this->workspacePath($artifact)) ? 'ready_local' : 'artifact_missing',
            'artifact' => $artifact,
            'supported_source_categories' => [
                'partners_and_tenants',
                'domains_and_branding',
                'admin_users_roles_and_menus',
                'customers',
                'wallet_balances_and_ledger_reconciliation_inputs',
                'games_stock_allocations_and_local_stock',
                'orders_tickets_payments_and_topups',
                'reward_results_claims_agents_affiliates_reports',
            ],
            'unsupported_or_unknown_categories' => [
                'raw_passwords_or_password_hash_reuse',
                'unversioned_event_payloads',
                'base64_ticket_images',
                'production_payment_provider_secrets',
                'unmapped_legacy_statuses',
                'records_without_tenant_or_partner_identity',
            ],
            'mapping_policy' => [
                'tenant_identity_required' => true,
                'current_platform_tables_are_target' => true,
                'status_mapping_must_be_explicit' => true,
                'unknown_records_go_to_reject_report' => true,
            ],
            'idempotency_policy' => [
                'stable_legacy_source_key_required' => true,
                'replay_updates_same_target_record' => true,
                'payload_hash_conflicts_are_rejected' => true,
                'outbox_inbox_events_keep_event_id_or_idempotency_key' => true,
            ],
            'redaction_policy' => [
                'customer_pii_not_emitted_in_readiness' => true,
                'old_data_payloads_not_emitted_in_readiness' => true,
                'secrets_reported_as_configured_or_redacted_only' => true,
            ],
            'blockers' => is_file($this->workspacePath($artifact)) ? [] : ['old_data_migration_strategy_artifact_missing'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function fixtureReadiness(): array
    {
        $artifact = 'ops/m10/migration-rehearsal-fixtures.md';
        $seeders = [
            'apps/platform-api/database/seeders/DatabaseSeeder.php',
            'apps/platform-api/database/seeders/DefaultRbacMenuSeeder.php',
            'apps/platform-api/database/seeders/BootstrapAdminSeeder.php',
            'apps/platform-api/database/seeders/DemoTenantSeeder.php',
        ];
        $missingSeeders = array_values(array_filter($seeders, fn (string $path): bool => ! is_file($this->workspacePath($path))));
        $blockers = [];

        if (! is_file($this->workspacePath($artifact))) {
            $blockers[] = 'migration_rehearsal_fixture_boundary_missing';
        }

        if ($missingSeeders !== []) {
            $blockers[] = 'local_seed_rehearsal_seeders_missing';
        }

        return [
            'status' => $blockers === [] ? 'ready_local' : 'fixture_boundary_missing',
            'artifact' => $artifact,
            'synthetic_seeded_data_only' => true,
            'real_old_data_dumps_committed' => false,
            'seeders_checked' => $seeders,
            'missing_seeders' => $missingSeeders,
            'fixture_sources' => [
                'DatabaseSeeder',
                'DefaultRbacMenuSeeder',
                'BootstrapAdminSeeder',
                'DemoTenantSeeder',
                'feature_test_factories_and_fixtures',
            ],
            'blockers' => $blockers,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function snapshotReadiness(): array
    {
        $artifact = 'ops/m10/snapshot-requirements.md';

        return [
            'status' => 'blocked_external',
            'artifact' => $artifact,
            'artifact_present' => is_file($this->workspacePath($artifact)),
            'database_snapshot' => [
                'required' => true,
                'scope' => 'PostgreSQL schema, tenant data, ledger/order/reward/report state, outbox/inbox, audit, monitoring state.',
                'local_rehearsal_boundary' => 'Use migrate:fresh --seed only for local/test rehearsal; never as production rollback.',
            ],
            'object_storage_metadata_snapshot' => [
                'required' => true,
                'scope' => 'Ticket image keys, variants, CDN policy metadata, bucket prefixes, and ownership map only.',
                'raw_objects_required_in_repo' => false,
            ],
            'blockers' => array_values(array_filter([
                is_file($this->workspacePath($artifact)) ? null : 'snapshot_requirements_artifact_missing',
                'real_database_snapshot_missing',
                'real_object_storage_metadata_snapshot_missing',
                'restore_rehearsal_evidence_missing',
            ])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function cutoverReadiness(): array
    {
        $artifact = 'ops/m10/cutover-runbook.md';
        $configured = [
            'release_image_tag' => trim((string) config('platform.migration_rehearsal.release_image_tag')) !== '',
            'migration_source_type' => trim((string) config('platform.migration_rehearsal.source_type')) !== '',
        ];

        return [
            'status' => 'blocked_external',
            'artifact' => $artifact,
            'artifact_present' => is_file($this->workspacePath($artifact)),
            'configured' => $configured,
            'redacted_config' => [
                'release_image_tag' => $this->configuredPlaceholder($configured['release_image_tag']),
                'migration_source_type' => $this->configuredPlaceholder($configured['migration_source_type']),
            ],
            'operator_checkpoints' => [
                'preflight',
                'release_tag_and_image_boundary',
                'queue_pause_or_drain_decision',
                'tenant_maintenance_decision',
                'dry_run_then_production_safe_migration_boundary',
                'health_smoke_runtime_readiness_checks',
                'cloudflare_cdn_r2_checkpoints',
                'monitoring_alert_checkpoint',
                'abort_criteria',
                'evidence_capture',
            ],
            'blockers' => array_values(array_filter([
                is_file($this->workspacePath($artifact)) ? null : 'cutover_runbook_missing',
                $configured['release_image_tag'] ? null : 'release_image_tag_not_verified',
                'production_cutover_window_not_approved',
                'staging_rehearsal_not_completed',
                'cloudflare_cdn_r2_production_evidence_missing',
                'production_monitoring_alert_channels_not_verified',
            ])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function rollbackReadiness(): array
    {
        $artifact = 'ops/m10/rollback-drill-runbook.md';
        $configured = [
            'previous_image_tag' => trim((string) config('platform.migration_rehearsal.previous_image_tag')) !== '',
        ];

        return [
            'status' => 'blocked_external',
            'artifact' => $artifact,
            'artifact_present' => is_file($this->workspacePath($artifact)),
            'configured' => $configured,
            'redacted_config' => [
                'previous_image_tag' => $this->configuredPlaceholder($configured['previous_image_tag']),
            ],
            'drill_requirements' => [
                'previous_image_tag',
                'database_backward_compatibility_boundary',
                'feature_flag_off_switch',
                'queue_pause_resume_boundary',
                'tenant_maintenance_boundary',
                'object_storage_rollback_or_repair_boundary',
                'post_rollback_health_smoke_checks',
                'residual_repair_tasks_for_coordinator_review',
            ],
            'blockers' => array_values(array_filter([
                is_file($this->workspacePath($artifact)) ? null : 'rollback_drill_runbook_missing',
                $configured['previous_image_tag'] ? null : 'previous_image_tag_missing',
                'production_db_backward_compatibility_not_verified',
                'object_storage_rollback_plan_not_verified',
                'rollback_rehearsal_not_executed',
            ])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function secretBoundary(): array
    {
        $artifact = 'ops/m10/production-secret-boundary.md';
        $configured = [
            'source_dsn' => trim((string) config('platform.migration_rehearsal.source_dsn')) !== '',
            'source_token' => trim((string) config('platform.migration_rehearsal.source_token')) !== '',
            'object_storage_bucket' => trim((string) config('platform.migration_rehearsal.object_storage_bucket')) !== '',
            'secret_reference' => trim((string) config('platform.migration_rehearsal.secret_reference')) !== '',
        ];

        return [
            'status' => 'blocked_external',
            'artifact' => $artifact,
            'artifact_present' => is_file($this->workspacePath($artifact)),
            'configured' => $configured,
            'redacted_config' => [
                'source_dsn' => $this->configuredPlaceholder($configured['source_dsn'], sensitive: true),
                'source_token' => $this->configuredPlaceholder($configured['source_token'], sensitive: true),
                'object_storage_bucket' => $this->configuredPlaceholder($configured['object_storage_bucket']),
                'secret_reference' => $this->configuredPlaceholder($configured['secret_reference'], sensitive: true),
            ],
            'required_external_owner' => 'Coordinator/Ops approved secret manager outside committed files.',
            'placeholder_only' => true,
            'blockers' => array_values(array_filter([
                is_file($this->workspacePath($artifact)) ? null : 'production_secret_boundary_artifact_missing',
                'production_secret_management_missing',
                'migration_source_credentials_missing',
                'real_old_data_source_missing',
            ])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function helperReadiness(): array
    {
        $helpers = [
            'scripts/platform-migration-rehearsal.sh',
            'scripts/platform-cutover-preflight.sh',
            'scripts/platform-rollback-drill.sh',
        ];
        $items = array_map(fn (string $path): array => [
            'path' => $path,
            'exists' => is_file($this->workspacePath($path)),
            'docker_only' => $this->helperUsesDockerOnly($path),
        ], $helpers);
        $missing = array_values(array_filter($items, fn (array $item): bool => ! $item['exists'] || ! $item['docker_only']));

        return [
            'status' => $missing === [] ? 'ready_local' : 'helper_missing_or_not_docker_only',
            'items' => $items,
            'blockers' => $missing === [] ? [] : ['migration_helper_missing_or_not_docker_only'],
        ];
    }

    /**
     * @param array<string, mixed> ...$sections
     * @return array<int, string>
     */
    private function blockers(array ...$sections): array
    {
        $blockers = [];

        foreach ($sections as $section) {
            if (is_array($section['blockers'] ?? null)) {
                $blockers = array_merge($blockers, $section['blockers']);
            }
        }

        return array_values(array_unique($blockers));
    }

    private function helperUsesDockerOnly(string $relativePath): bool
    {
        $path = $this->workspacePath($relativePath);

        if (! is_file($path)) {
            return false;
        }

        $contents = (string) file_get_contents($path);

        return str_contains($contents, 'docker compose')
            && ! preg_match('/^\\s*(php|composer|artisan|npm|node|vite|nuxt|psql|pg_dump)\\s/m', $contents);
    }

    private function configuredPlaceholder(bool $configured, bool $sensitive = false): ?string
    {
        if (! $configured) {
            return null;
        }

        return $sensitive ? '[REDACTED]' : '[CONFIGURED]';
    }

    private function workspacePath(string $relativePath): string
    {
        $roots = array_filter([
            env('WORKSPACE_ROOT'),
            '/workspace',
            dirname(base_path(), 2),
        ]);

        foreach ($roots as $root) {
            $path = rtrim((string) $root, '/').'/'.$relativePath;

            if (file_exists($path)) {
                return $path;
            }
        }

        return dirname(base_path(), 2).'/'.$relativePath;
    }
}
