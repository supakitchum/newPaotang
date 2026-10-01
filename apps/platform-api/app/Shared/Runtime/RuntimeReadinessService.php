<?php

namespace App\Shared\Runtime;

use Illuminate\Console\Scheduling\Schedule;
use Illuminate\Support\Facades\Route;

class RuntimeReadinessService
{
    public function __construct(private readonly Schedule $schedule)
    {
    }

    /**
     * @return array<string, mixed>
     */
    public function report(): array
    {
        $queue = $this->queueReadiness();
        $horizon = $this->horizonReadiness();
        $reverb = $this->reverbReadiness();
        $scheduler = $this->schedulerReadiness();
        $helpers = $this->helperReadiness();
        $blockers = $this->blockers($queue, $horizon, $reverb, $scheduler, $helpers);

        return [
            'status' => $blockers === [] ? 'ready_local' : 'blocked_external',
            'generated_at' => now()->toISOString(),
            'production_approved' => false,
            'boundary' => [
                'local_dev_verifiable' => true,
                'dry_run' => true,
                'external_services_called' => false,
                'long_lived_processes_started' => false,
                'horizon_dashboard_publicly_exposed' => false,
                'reverb_public_websocket_approved' => false,
                'staging_approved' => false,
                'production_approved' => false,
                'client_delivery_approved' => false,
            ],
            'queue_workers' => $queue,
            'horizon' => $horizon,
            'reverb' => $reverb,
            'scheduler' => $scheduler,
            'helpers' => $helpers,
            'blockers' => $blockers,
            'docker_validation_commands' => [
                'docker compose exec platform-api php artisan platform:runtime:readiness --format=json',
                'docker compose run --rm platform-api php artisan schedule:list',
                'docker compose run --rm platform-api php artisan queue:work --once --tries=1 --timeout=30 --queue=default',
                'docker compose run --rm platform-api php artisan list',
                'docker compose --profile worker --profile scheduler --profile realtime config --quiet',
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function queueReadiness(): array
    {
        $configuredQueues = $this->configuredWorkerQueues();
        $catalog = $this->queueProfileCatalog();
        $catalogQueues = array_column($catalog['queue_ownership'], 'queue');
        $missing = array_values(array_diff($configuredQueues, $catalogQueues));
        $extra = array_values(array_diff($catalogQueues, $configuredQueues));
        $criticalQueues = array_values(array_filter(
            $catalog['queue_ownership'],
            fn (array $queue): bool => in_array($queue['priority_class'] ?? '', ['critical', 'high'], true),
        ));
        $reportQueues = array_values(array_filter(
            $catalog['queue_ownership'],
            fn (array $queue): bool => in_array($queue['queue'] ?? '', ['report-build', 'usage-metering', 'partner-monitoring'], true),
        ));

        $blockers = [];

        if ($missing !== []) {
            $blockers[] = 'queue_profile_catalog_missing_configured_queues';
        }

        if ($extra !== []) {
            $blockers[] = 'queue_profile_catalog_has_unknown_queues';
        }

        return [
            'status' => $blockers === [] ? 'ready_local' : 'catalog_mismatch',
            'connection' => (string) config('queue.default'),
            'configured_queue_count' => count($configuredQueues),
            'configured_queues' => $configuredQueues,
            'catalog_path' => 'ops/m10/queue-worker-profiles.json',
            'catalog_valid' => $catalog['valid'],
            'worker_profiles' => $catalog['worker_profiles'],
            'queue_ownership' => $catalog['queue_ownership'],
            'missing_configured_queues' => $missing,
            'unknown_catalog_queues' => $extra,
            'critical_queue_count' => count($criticalQueues),
            'reporting_monitoring_queue_count' => count($reportQueues),
            'separation_policy' => [
                'booking_checkout_reward_critical_path_separate_from_reporting' => true,
                'report_build_not_shared_with_booking_checkout_reward_critical' => true,
                'bounded_validation_only' => true,
            ],
            'blockers' => array_merge($blockers, $catalog['blockers']),
        ];
    }

    /**
     * @return array<int, string>
     */
    private function configuredWorkerQueues(): array
    {
        $queues = config('platform.runtime.worker_queues');

        if (! is_array($queues)) {
            return [];
        }

        return array_values(array_filter(array_map(
            fn (mixed $queue): string => trim((string) $queue),
            $queues,
        )));
    }

    /**
     * @return array{valid: bool, worker_profiles: array<int, array<string, mixed>>, queue_ownership: array<int, array<string, mixed>>, blockers: array<int, string>}
     */
    private function queueProfileCatalog(): array
    {
        $path = $this->workspacePath('ops/m10/queue-worker-profiles.json');

        if (! is_file($path)) {
            return [
                'valid' => false,
                'worker_profiles' => [],
                'queue_ownership' => [],
                'blockers' => ['queue_profile_catalog_missing'],
            ];
        }

        $decoded = json_decode((string) file_get_contents($path), true);

        if (! is_array($decoded)) {
            return [
                'valid' => false,
                'worker_profiles' => [],
                'queue_ownership' => [],
                'blockers' => ['queue_profile_catalog_invalid_json'],
            ];
        }

        $profiles = is_array($decoded['worker_profiles'] ?? null) ? $decoded['worker_profiles'] : [];
        $ownership = is_array($decoded['queue_ownership'] ?? null) ? $decoded['queue_ownership'] : [];

        return [
            'valid' => $profiles !== [] && $ownership !== [],
            'worker_profiles' => $profiles,
            'queue_ownership' => $ownership,
            'blockers' => $profiles !== [] && $ownership !== [] ? [] : ['queue_profile_catalog_incomplete'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function horizonReadiness(): array
    {
        $packageInstalled = class_exists('Laravel\\Horizon\\Horizon');
        $configPresent = is_file(base_path('config/horizon.php'));

        return [
            'status' => $packageInstalled && $configPresent ? 'ready_local' : 'blocked_external',
            'package_installed' => $packageInstalled,
            'config_present' => $configPresent,
            'dashboard_route_registered' => $this->routeUriExists('horizon'),
            'dashboard_access_policy' => 'local/dev only until Horizon package, auth guard, network restriction, and production access policy are approved.',
            'supervisor_policy' => 'Use process-manager-managed Horizon supervisors per queue profile; do not share report-build workers with booking/checkout/reward critical queues.',
            'blockers' => array_values(array_filter([
                $packageInstalled ? null : 'horizon_package_missing',
                $configPresent ? null : 'horizon_config_missing',
                'horizon_supervisor_not_configured',
                'horizon_dashboard_access_policy_not_verified',
                'horizon_production_process_manager_missing',
            ])),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function reverbReadiness(): array
    {
        $packageInstalled = class_exists('Laravel\\Reverb\\Application');
        $runtimeProfileConfigured = $this->reverbRuntimeProfileConfigured();
        $configured = [
            'app_id' => trim((string) config('platform.realtime.app_id')) !== '',
            'app_key' => trim((string) config('platform.realtime.admin_key')) !== '',
            'app_secret' => trim((string) config('platform.realtime.admin_secret')) !== '',
            'host' => trim((string) config('platform.realtime.host')) !== '',
            'port' => trim((string) config('platform.realtime.port')) !== '',
            'scheme' => trim((string) config('platform.realtime.scheme')) !== '',
        ];
        $adminRoutes = [
            'central' => $this->routeUriExists('api/v1/admin/central/realtime/auth'),
            'tenant' => $this->routeUriExists('api/v1/admin/tenant/realtime/auth'),
        ];
        $blockers = array_values(array_filter([
            $packageInstalled ? null : 'reverb_package_missing',
            $adminRoutes['central'] && $adminRoutes['tenant'] ? null : 'reverb_admin_auth_routes_missing',
            $runtimeProfileConfigured ? null : 'reverb_runtime_profile_not_configured',
            'reverb_tls_and_public_host_not_verified',
            'reverb_scaling_and_load_not_verified',
        ]));

        return [
            'status' => $blockers === [] ? 'ready_local' : 'blocked_external',
            'package_installed' => $packageInstalled,
            'runtime_profile_configured' => $runtimeProfileConfigured,
            'configured' => $configured,
            'redacted_config' => [
                'app_id' => $this->configuredPlaceholder($configured['app_id']),
                'app_key' => $this->configuredPlaceholder($configured['app_key'], sensitive: true),
                'app_secret' => $this->configuredPlaceholder($configured['app_secret'], sensitive: true),
                'host' => $this->configuredPlaceholder($configured['host']),
                'port' => $this->configuredPlaceholder($configured['port']),
                'scheme' => $this->configuredPlaceholder($configured['scheme']),
            ],
            'auth_endpoints' => $adminRoutes,
            'auth_boundary' => 'Existing admin realtime auth endpoints sign private/presence channels and remain API-compatible; no public websocket delivery is approved by this slice.',
            'blockers' => $blockers,
        ];
    }

    private function reverbRuntimeProfileConfigured(): bool
    {
        $compose = $this->workspacePath('compose.yaml');

        if (! is_file($compose)) {
            return false;
        }

        $contents = (string) file_get_contents($compose);

        return str_contains($contents, 'platform-api-reverb:')
            && str_contains($contents, 'profiles: ["realtime"]')
            && str_contains($contents, 'php artisan reverb:start');
    }

    /**
     * @return array<string, mixed>
     */
    private function schedulerReadiness(): array
    {
        $events = array_map(fn (object $event): array => $this->scheduleEventResource($event), $this->schedule->events());
        $scheduledCommands = array_column($events, 'command');
        $requiredCommands = [
            'stock:reservations:expire',
            'stock:sold:sync',
            'reward:check',
            'commission:calculate',
            'platform:alerts:check',
        ];
        $missing = array_values(array_filter(
            $requiredCommands,
            fn (string $command): bool => ! collect($scheduledCommands)->contains(fn (string $scheduled): bool => str_contains($scheduled, $command)),
        ));

        return [
            'status' => $missing === [] ? 'ready_local' : 'missing_registered_workloads',
            'registered_workload_count' => count($events),
            'registered_workloads' => $events,
            'required_workloads' => $requiredCommands,
            'missing_required_workloads' => $missing,
            'safe_registration_policy' => [
                'local_dev_only' => true,
                'uses_without_overlapping' => true,
                'mutating_workloads_are_idempotent_or_chunk_limited' => true,
            ],
            'blockers' => $missing === [] ? [] : ['scheduler_required_workloads_missing'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function scheduleEventResource(object $event): array
    {
        $summary = method_exists($event, 'getSummaryForDisplay') ? (string) $event->getSummaryForDisplay() : (string) ($event->description ?? '');
        $expression = method_exists($event, 'getExpression') ? (string) $event->getExpression() : (string) ($event->expression ?? '');
        $command = trim(str_replace([PHP_BINARY, base_path('artisan')], '', (string) ($event->command ?? $summary)));

        return [
            'command' => trim($command),
            'expression' => $expression,
            'summary' => $summary,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function helperReadiness(): array
    {
        $helpers = [
            'scripts/platform-api-worker-once.sh',
            'scripts/platform-api-schedule-list.sh',
            'scripts/platform-runtime-readiness.sh',
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
            'blockers' => $missing === [] ? [] : ['runtime_helper_missing_or_not_docker_only'],
        ];
    }

    private function helperUsesDockerOnly(string $relativePath): bool
    {
        $path = $this->workspacePath($relativePath);

        if (! is_file($path)) {
            return false;
        }

        $contents = (string) file_get_contents($path);

        return str_contains($contents, 'docker compose')
            && ! preg_match('/^\\s*(php|composer|artisan|npm|node|vite|nuxt)\\s/m', $contents);
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

    private function configuredPlaceholder(bool $configured, bool $sensitive = false): ?string
    {
        if (! $configured) {
            return null;
        }

        return $sensitive ? '[REDACTED]' : '[CONFIGURED]';
    }

    private function routeUriExists(string $uri): bool
    {
        return collect(Route::getRoutes())->contains(fn ($route): bool => trim((string) $route->uri(), '/') === trim($uri, '/'));
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
