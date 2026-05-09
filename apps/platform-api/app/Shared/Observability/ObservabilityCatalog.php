<?php

namespace App\Shared\Observability;

class ObservabilityCatalog
{
    /**
     * @return array<int, string>
     */
    public function defaultUsageMeters(): array
    {
        return [
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
    }

    /**
     * @return array<string, array<string, mixed>>
     */
    public function defaultAlertPolicies(): array
    {
        return [
            'default_health' => [
                'severity' => 'warning',
                'metric' => 'partner_health_status',
                'threshold' => ['health_status' => ['critical']],
                'window_seconds' => 300,
                'description' => 'Partner health check moved to a critical state.',
                'data_source' => 'partner_health_checks',
            ],
            'api_error_rate_high' => [
                'severity' => 'critical',
                'metric' => 'api_error_rate',
                'threshold' => ['rate' => 0.05, 'minimum_requests' => 20],
                'window_seconds' => 300,
                'description' => 'API error rate exceeded the local policy threshold.',
                'data_source' => 'partner_daily_usage_summaries.error_count/api_request_count',
            ],
            'booking_fail_rate_high' => [
                'severity' => 'warning',
                'metric' => 'booking_failure_rate',
                'threshold' => ['rate' => 0.05, 'minimum_requests' => 20],
                'window_seconds' => 300,
                'description' => 'Booking failures exceeded the local policy threshold where counters exist.',
                'data_source' => 'partner_daily_usage_summaries',
            ],
            'checkout_fail_rate_high' => [
                'severity' => 'critical',
                'metric' => 'checkout_failure_rate',
                'threshold' => ['rate' => 0.03, 'minimum_requests' => 20],
                'window_seconds' => 300,
                'description' => 'Checkout failures exceeded the local policy threshold where counters exist.',
                'data_source' => 'partner_daily_usage_summaries',
            ],
            'sync_lag_high' => [
                'severity' => 'warning',
                'metric' => 'sync_pending_age',
                'threshold' => ['pending_older_than_seconds' => 300, 'minimum_pending' => 1],
                'window_seconds' => 300,
                'description' => 'Partner inbox/outbox rows stayed pending beyond the local threshold.',
                'data_source' => 'sync_inbox, sync_outbox',
            ],
            'queue_lag_high' => [
                'severity' => 'warning',
                'metric' => 'queue_pending_age',
                'threshold' => ['pending_older_than_seconds' => 300, 'minimum_pending' => 1],
                'window_seconds' => 300,
                'description' => 'Laravel queue jobs stayed available beyond the local threshold.',
                'data_source' => 'jobs',
            ],
            'reward_check_failure' => [
                'severity' => 'critical',
                'metric' => 'reward_check_failed_items',
                'threshold' => ['failed_items' => 1],
                'window_seconds' => 300,
                'description' => 'Reward checking produced failed items for a tenant.',
                'data_source' => 'reward_check_items',
            ],
            'permission_denied_spike' => [
                'severity' => 'warning',
                'metric' => 'permission_denied_count',
                'threshold' => ['count' => 10],
                'window_seconds' => 300,
                'description' => 'Permission denied audit events exceeded the local threshold.',
                'data_source' => 'audit_logs',
            ],
            'cross_tenant_access_attempt' => [
                'severity' => 'critical',
                'metric' => 'cross_tenant_access_attempt_count',
                'threshold' => ['count' => 1],
                'window_seconds' => 300,
                'description' => 'Cross-tenant access attempts were recorded.',
                'data_source' => 'audit_logs',
            ],
            'image_cdn_hit_ratio_low' => [
                'severity' => 'warning',
                'metric' => 'image_cdn_hit_ratio',
                'threshold' => ['ratio_below' => 0.90],
                'window_seconds' => 300,
                'description' => 'CDN hit ratio needs production CDN analytics before real evaluation.',
                'data_source' => 'Cloudflare/CDN analytics production gate',
            ],
            'storage_quota_near_limit' => [
                'severity' => 'warning',
                'metric' => 'storage_quota_ratio',
                'threshold' => ['ratio_above' => 0.80],
                'window_seconds' => 3600,
                'description' => 'Storage quota evaluation requires object storage usage feed.',
                'data_source' => 'R2/S3 usage production gate',
            ],
            'api_rate_limit_exceeded' => [
                'severity' => 'warning',
                'metric' => 'rate_limited_count',
                'threshold' => ['count' => 50],
                'window_seconds' => 300,
                'description' => 'Rate-limited request count exceeded the local policy threshold where counters exist.',
                'data_source' => 'partner_daily_usage_summaries.rate_limited_count',
            ],
            'payment_callback_failure' => [
                'severity' => 'critical',
                'metric' => 'payment_callback_failure_count',
                'threshold' => ['count' => 1],
                'window_seconds' => 300,
                'description' => 'Payment callback failure evaluation uses webhook callback rows where present.',
                'data_source' => 'webhook_callbacks',
            ],
        ];
    }

    /**
     * @return array<int, string>
     */
    public function requiredAlertPolicyKeys(): array
    {
        return [
            'api_error_rate_high',
            'booking_fail_rate_high',
            'checkout_fail_rate_high',
            'sync_lag_high',
            'queue_lag_high',
            'reward_check_failure',
            'permission_denied_spike',
            'cross_tenant_access_attempt',
        ];
    }

    /**
     * @return array<int, string>
     */
    public function metricLabelKeys(): array
    {
        return [
            'platform',
            'environment',
            'module',
            'partner_id',
            'tenant_id',
            'deployment_mode',
            'package',
            'endpoint',
            'queue',
            'game_id',
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    public function signalInventory(): array
    {
        return [
            $this->signal('api', 'API request/error/latency', 'partial', 'health endpoints, access logs, partner_daily_usage_summaries', 'docker compose exec platform-api php artisan platform:observability:report --format=json', 'External APM/edge latency is a production integration gate.'),
            $this->signal('database', 'PostgreSQL health', 'ready_local', 'platform:smoke database check', 'docker compose exec platform-api php artisan platform:smoke', null),
            $this->signal('cache', 'Redis/Valkey cache health', 'ready_local', 'platform:smoke cache check', 'docker compose exec platform-api php artisan platform:smoke', null),
            $this->signal('queue', 'Queue lag and failed job readiness', 'partial', 'jobs, failed_jobs, platform worker command path', 'docker compose run --rm platform-api php artisan queue:work --once --tries=1', 'Horizon dashboard and production queue supervision remain open gates.'),
            $this->signal('partner_sync', 'Partner inbox/outbox lag', 'ready_local', 'sync_inbox, sync_outbox', 'docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json', null),
            $this->signal('booking', 'Booking failure readiness', 'partial', 'partner_daily_usage_summaries and application logs', 'docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json', 'Dedicated booking failure counters are not yet production-fed.'),
            $this->signal('checkout', 'Checkout/wallet failure readiness', 'partial', 'partner_daily_usage_summaries and application logs', 'docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json', 'Dedicated checkout failure counters are not yet production-fed.'),
            $this->signal('reward', 'Reward checking failure readiness', 'ready_local', 'reward_check_items', 'docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json', null),
            $this->signal('support_access', 'Support access audit readiness', 'ready_local', 'support_impersonation_events, support_impersonation_blocked_actions, audit_logs', 'docker compose exec platform-api php artisan platform:observability:report --format=json', null),
            $this->signal('security', 'Permission denied and cross-tenant signal readiness', 'partial', 'audit_logs', 'docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json', 'Production edge/WAF security events remain external integration gates.'),
            $this->signal('usage_billing', 'Usage metering and daily summary sink', 'ready_local', 'partner_usage_meters, partner_usage_events, partner_daily_usage_summaries', 'docker compose exec platform-api php artisan platform:observability:report --format=json', null),
            $this->signal('cdn_images', 'Ticket image CDN metrics', 'blocked_external', 'Cloudflare/CDN/R2 analytics', 'Run CDN/R2 slice validation after credentials and test image path exist.', 'Cloudflare/CDN/R2 integration remains an open release gate.'),
        ];
    }

    /**
     * @return array<int, array<string, string>>
     */
    public function externalIntegrationBlockers(): array
    {
        return [
            ['integration' => 'webhook', 'status' => 'placeholder_only', 'owner' => 'Coordinator/Production Ops', 'blocker' => 'Real webhook URL and secret management are not available in this workspace.'],
            ['integration' => 'email', 'status' => 'placeholder_only', 'owner' => 'Coordinator/Production Ops', 'blocker' => 'SMTP/provider credentials and delivery verification are not available in this workspace.'],
            ['integration' => 'sentry', 'status' => 'placeholder_only', 'owner' => 'Coordinator/Production Ops', 'blocker' => 'Sentry DSN/project and production secret management remain open gates.'],
            ['integration' => 'grafana', 'status' => 'template_only', 'owner' => 'Coordinator/Production Ops', 'blocker' => 'Grafana datasource, token, and managed dashboard import are not available in this workspace.'],
            ['integration' => 'datadog_new_relic', 'status' => 'template_only', 'owner' => 'Coordinator/Production Ops', 'blocker' => 'Vendor account/API keys and production agent deployment remain open gates.'],
            ['integration' => 'cloudflare_cdn_r2', 'status' => 'blocked_external', 'owner' => 'Coordinator/Production Ops', 'blocker' => 'Cloudflare account/API, WAF/rate-limit rules, R2 bucket, and real ticket-image path remain separate release gates.'],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function signal(string $key, string $name, string $status, string $dataSource, string $validationCommand, ?string $blocker): array
    {
        return [
            'key' => $key,
            'name' => $name,
            'status' => $status,
            'owner' => 'Backend/Ops',
            'data_source' => $dataSource,
            'local_dev_validation' => $validationCommand,
            'production_blocker' => $blocker,
        ];
    }
}
