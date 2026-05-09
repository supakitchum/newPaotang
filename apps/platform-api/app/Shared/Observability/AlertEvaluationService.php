<?php

namespace App\Shared\Observability;

use App\Models\AuditLog;
use App\Models\Partner;
use App\Models\PartnerAlertEvent;
use App\Models\PartnerAlertPolicy;
use App\Models\PartnerDailyUsageSummary;
use App\Models\RewardCheckItem;
use App\Models\SyncInbox;
use App\Models\SyncOutbox;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Log;
use Illuminate\Support\Str;

class AlertEvaluationService
{
    public function __construct(
        private readonly ObservabilityCatalog $catalog,
        private readonly ObservabilityRedactor $redactor,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function evaluate(bool $dryRun): array
    {
        $startedAt = now();
        $events = [];
        $results = [];
        $partners = Partner::query()->with(['tenants'])->orderBy('id')->get()->all();

        foreach ($partners as $partner) {
            $tenantIds = $partner->tenants->pluck('id')->map(fn ($id): string => (string) $id)->all();
            $primaryTenantId = $tenantIds[0] ?? null;
            $policies = PartnerAlertPolicy::query()
                ->where('partner_id', $partner->id)
                ->whereIn('policy_key', $this->catalog->requiredAlertPolicyKeys())
                ->get()
                ->keyBy('policy_key');

            foreach ($this->catalog->requiredAlertPolicyKeys() as $policyKey) {
                $policy = $policies->get($policyKey);
                $result = $this->evaluatePolicy($partner, $tenantIds, $primaryTenantId, $policyKey, $policy);
                $results[] = $result;

                if ($result['state'] !== 'alert') {
                    continue;
                }

                if ($dryRun) {
                    $events[] = [
                        'policy_key' => $policyKey,
                        'partner_id' => (string) $partner->id,
                        'tenant_id' => $primaryTenantId,
                        'delivery' => 'dry_run',
                    ];

                    continue;
                }

                if (! (bool) config('platform.alerts.enabled')) {
                    $events[] = [
                        'policy_key' => $policyKey,
                        'partner_id' => (string) $partner->id,
                        'tenant_id' => $primaryTenantId,
                        'delivery' => 'disabled',
                    ];

                    continue;
                }

                $events[] = $this->writeAlertEvent($result, $policy);
            }
        }

        return [
            'status' => 'ok',
            'dry_run' => $dryRun,
            'generated_at' => $startedAt->toISOString(),
            'boundary' => [
                'local_dev_verifiable' => true,
                'external_delivery_attempted' => false,
                'production_approved' => false,
            ],
            'summary' => [
                'partners_evaluated' => count($partners),
                'policies_evaluated' => count($results),
                'alerts_detected' => count(array_filter($results, fn (array $result): bool => $result['state'] === 'alert')),
                'events_delivered' => count(array_filter($events, fn (array $event): bool => ($event['delivery'] ?? null) === 'database')),
            ],
            'results' => $results,
            'events' => $events,
            'channels' => [
                'local' => ['database', 'log'],
                'external' => 'blocked_until_credentials_and_production_secret_management_exist',
            ],
        ];
    }

    /**
     * @param array<int, string> $tenantIds
     * @return array<string, mixed>
     */
    private function evaluatePolicy(Partner $partner, array $tenantIds, ?string $primaryTenantId, string $policyKey, ?PartnerAlertPolicy $policy): array
    {
        $definition = $this->catalog->defaultAlertPolicies()[$policyKey] ?? [];
        $labels = $this->labels($partner, $primaryTenantId, (string) ($definition['metric'] ?? $policyKey));

        if ($policy === null) {
            return $this->result($partner, $primaryTenantId, $policyKey, 'missing_policy', 'warning', $labels, [
                'reason' => 'Required policy is not present for this partner.',
            ]);
        }

        if ($policy->status !== 'active') {
            return $this->result($partner, $primaryTenantId, $policyKey, 'paused', (string) $policy->severity, $labels, [
                'reason' => 'Policy is not active.',
                'policy_status' => (string) $policy->status,
            ], $policy);
        }

        return match ($policyKey) {
            'api_error_rate_high' => $this->evaluateApiErrorRate($partner, $primaryTenantId, $policy, $labels),
            'booking_fail_rate_high' => $this->evaluateRequestFailureRate($partner, $primaryTenantId, $policy, $labels, 'booking_request_count'),
            'checkout_fail_rate_high' => $this->evaluateRequestFailureRate($partner, $primaryTenantId, $policy, $labels, 'checkout_request_count'),
            'sync_lag_high' => $this->evaluateSyncLag($partner, $primaryTenantId, $policy, $labels),
            'queue_lag_high' => $this->evaluateQueueLag($partner, $primaryTenantId, $policy, $labels),
            'reward_check_failure' => $this->evaluateRewardFailures($partner, $tenantIds, $primaryTenantId, $policy, $labels),
            'permission_denied_spike' => $this->evaluateAuditSpike($partner, $primaryTenantId, $policy, $labels, 'permission_denied', 'count'),
            'cross_tenant_access_attempt' => $this->evaluateAuditSpike($partner, $primaryTenantId, $policy, $labels, 'cross_tenant_access_attempt', 'count'),
            default => $this->result($partner, $primaryTenantId, $policyKey, 'no_data', (string) $policy->severity, $labels, [
                'reason' => 'No local evaluator is wired for this policy yet.',
            ], $policy),
        };
    }

    /**
     * @param array<string, mixed> $labels
     * @return array<string, mixed>
     */
    private function evaluateApiErrorRate(Partner $partner, ?string $tenantId, PartnerAlertPolicy $policy, array $labels): array
    {
        $summary = $this->latestSummary((string) $partner->id, $tenantId);

        if ($summary === null || $summary->api_request_count === 0) {
            return $this->result($partner, $tenantId, (string) $policy->policy_key, 'no_data', (string) $policy->severity, $labels, [
                'reason' => 'No API request summary exists for this partner yet.',
            ], $policy);
        }

        $threshold = $this->thresholdRate($policy, 0.05);
        $minimumRequests = $this->thresholdInteger($policy, 'minimum_requests', 20);
        $rate = $summary->error_count / max($summary->api_request_count, 1);
        $state = $summary->api_request_count >= $minimumRequests && $rate >= $threshold ? 'alert' : 'ok';

        return $this->result($partner, $tenantId, (string) $policy->policy_key, $state, (string) $policy->severity, $labels, [
            'api_request_count' => $summary->api_request_count,
            'error_count' => $summary->error_count,
            'rate' => round($rate, 4),
            'threshold' => $threshold,
            'minimum_requests' => $minimumRequests,
        ], $policy);
    }

    /**
     * @param array<string, mixed> $labels
     * @return array<string, mixed>
     */
    private function evaluateRequestFailureRate(Partner $partner, ?string $tenantId, PartnerAlertPolicy $policy, array $labels, string $requestColumn): array
    {
        $summary = $this->latestSummary((string) $partner->id, $tenantId);

        if ($summary === null || (int) $summary->{$requestColumn} === 0) {
            return $this->result($partner, $tenantId, (string) $policy->policy_key, 'no_data', (string) $policy->severity, $labels, [
                'reason' => 'No dedicated request counter exists for this policy yet.',
                'request_counter' => $requestColumn,
            ], $policy);
        }

        $threshold = $this->thresholdRate($policy, 0.05);
        $minimumRequests = $this->thresholdInteger($policy, 'minimum_requests', 20);
        $requestCount = (int) $summary->{$requestColumn};
        $rate = $summary->error_count / max($requestCount, 1);
        $state = $requestCount >= $minimumRequests && $rate >= $threshold ? 'alert' : 'ok';

        return $this->result($partner, $tenantId, (string) $policy->policy_key, $state, (string) $policy->severity, $labels, [
            'request_count' => $requestCount,
            'error_count' => $summary->error_count,
            'rate' => round($rate, 4),
            'threshold' => $threshold,
            'minimum_requests' => $minimumRequests,
        ], $policy);
    }

    /**
     * @param array<string, mixed> $labels
     * @return array<string, mixed>
     */
    private function evaluateSyncLag(Partner $partner, ?string $tenantId, PartnerAlertPolicy $policy, array $labels): array
    {
        $seconds = $this->thresholdInteger($policy, 'pending_older_than_seconds', 300);
        $cutoff = now()->subSeconds($seconds);
        $pending = SyncInbox::query()
            ->where('partner_id', $partner->id)
            ->where('status', 'pending')
            ->where('created_at', '<', $cutoff)
            ->count()
            + SyncOutbox::query()
                ->where('partner_id', $partner->id)
                ->where('status', 'pending')
                ->where('created_at', '<', $cutoff)
                ->count();

        return $this->result($partner, $tenantId, (string) $policy->policy_key, $pending > 0 ? 'alert' : 'ok', (string) $policy->severity, $labels, [
            'pending_older_than_seconds' => $seconds,
            'pending_count' => $pending,
        ], $policy);
    }

    /**
     * @param array<string, mixed> $labels
     * @return array<string, mixed>
     */
    private function evaluateQueueLag(Partner $partner, ?string $tenantId, PartnerAlertPolicy $policy, array $labels): array
    {
        $seconds = $this->thresholdInteger($policy, 'pending_older_than_seconds', 300);
        $cutoff = time() - $seconds;
        $available = time();
        $row = DB::selectOne('select count(*) as aggregate from jobs where available_at <= ? and created_at <= ?', [$available, $cutoff]);
        $pending = (int) ($row->aggregate ?? 0);

        return $this->result($partner, $tenantId, (string) $policy->policy_key, $pending > 0 ? 'alert' : 'ok', (string) $policy->severity, $labels, [
            'pending_older_than_seconds' => $seconds,
            'pending_count' => $pending,
        ], $policy);
    }

    /**
     * @param array<int, string> $tenantIds
     * @param array<string, mixed> $labels
     * @return array<string, mixed>
     */
    private function evaluateRewardFailures(Partner $partner, array $tenantIds, ?string $tenantId, PartnerAlertPolicy $policy, array $labels): array
    {
        if ($tenantIds === []) {
            return $this->result($partner, $tenantId, (string) $policy->policy_key, 'no_data', (string) $policy->severity, $labels, [
                'reason' => 'Partner has no tenants.',
            ], $policy);
        }

        $window = $this->windowSeconds($policy, 300);
        $failed = RewardCheckItem::query()
            ->whereIn('tenant_id', $tenantIds)
            ->where('status', 'failed')
            ->where('updated_at', '>=', now()->subSeconds($window))
            ->count();

        return $this->result($partner, $tenantId, (string) $policy->policy_key, $failed > 0 ? 'alert' : 'ok', (string) $policy->severity, $labels, [
            'failed_items' => $failed,
            'window_seconds' => $window,
        ], $policy);
    }

    /**
     * @param array<string, mixed> $labels
     * @return array<string, mixed>
     */
    private function evaluateAuditSpike(Partner $partner, ?string $tenantId, PartnerAlertPolicy $policy, array $labels, string $actionNeedle, string $thresholdKey): array
    {
        $window = $this->windowSeconds($policy, 300);
        $threshold = $this->thresholdInteger($policy, $thresholdKey, $actionNeedle === 'cross_tenant_access_attempt' ? 1 : 10);
        $count = AuditLog::query()
            ->where('partner_id', $partner->id)
            ->where('action', 'like', '%'.$actionNeedle.'%')
            ->where('created_at', '>=', now()->subSeconds($window))
            ->count();

        return $this->result($partner, $tenantId, (string) $policy->policy_key, $count >= $threshold ? 'alert' : 'ok', (string) $policy->severity, $labels, [
            'count' => $count,
            'threshold' => $threshold,
            'window_seconds' => $window,
        ], $policy);
    }

    private function latestSummary(string $partnerId, ?string $tenantId): ?PartnerDailyUsageSummary
    {
        $query = PartnerDailyUsageSummary::query()
            ->where('partner_id', $partnerId)
            ->orderByDesc('usage_date');

        if ($tenantId !== null) {
            $query->where('tenant_id', $tenantId);
        }

        return $query->first();
    }

    /**
     * @param array<string, mixed> $labels
     * @param array<string, mixed> $evidence
     * @return array<string, mixed>
     */
    private function result(Partner $partner, ?string $tenantId, string $policyKey, string $state, string $severity, array $labels, array $evidence, ?PartnerAlertPolicy $policy = null): array
    {
        return [
            'policy_key' => $policyKey,
            'policy_id' => $policy?->id,
            'partner_id' => (string) $partner->id,
            'tenant_id' => $tenantId,
            'state' => $state,
            'severity' => $severity,
            'labels' => $labels,
            'evidence' => $this->redactor->redact($evidence),
        ];
    }

    /**
     * @param array<string, mixed> $result
     * @return array<string, mixed>
     */
    private function writeAlertEvent(array $result, ?PartnerAlertPolicy $policy): array
    {
        $now = now();
        $eventId = 'ale_'.Str::ulid()->toBase32();
        $payload = $this->redactor->redact([
            'result' => $result,
            'channels' => [
                'configured' => config('platform.alerts.channels', []),
                'webhook_url' => config('platform.alerts.webhook_url'),
                'external_delivery_enabled' => config('platform.alerts.external_delivery_enabled'),
            ],
        ]);

        PartnerAlertEvent::query()->create([
            'id' => $eventId,
            'partner_id' => $result['partner_id'],
            'tenant_id' => $result['tenant_id'],
            'alert_policy_id' => $policy?->id,
            'policy_key' => $result['policy_key'],
            'severity' => $result['severity'],
            'status' => 'open',
            'channel' => 'database',
            'title' => 'Alert policy triggered: '.$result['policy_key'],
            'message' => 'Local database alert event generated by platform:alerts:check.',
            'labels_json' => $result['labels'],
            'payload_redacted_json' => $payload,
            'dry_run' => false,
            'triggered_at' => $now,
            'delivered_at' => $now,
        ]);

        Log::warning('Platform alert policy triggered', $payload);

        return [
            'id' => $eventId,
            'policy_key' => $result['policy_key'],
            'partner_id' => $result['partner_id'],
            'tenant_id' => $result['tenant_id'],
            'delivery' => 'database',
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function labels(Partner $partner, ?string $tenantId, string $metric): array
    {
        return [
            'platform' => 'newpaotang',
            'environment' => (string) config('platform.observability.environment'),
            'module' => $this->moduleForMetric($metric),
            'partner_id' => (string) $partner->id,
            'tenant_id' => $tenantId,
            'deployment_mode' => 'shared',
            'package' => null,
            'endpoint' => null,
            'queue' => null,
            'game_id' => null,
        ];
    }

    private function moduleForMetric(string $metric): string
    {
        if (str_contains($metric, 'reward')) {
            return 'reward';
        }

        if (str_contains($metric, 'sync')) {
            return 'partner_sync';
        }

        if (str_contains($metric, 'queue')) {
            return 'queue';
        }

        if (str_contains($metric, 'permission') || str_contains($metric, 'cross_tenant')) {
            return 'security';
        }

        if (str_contains($metric, 'checkout')) {
            return 'checkout_wallet';
        }

        if (str_contains($metric, 'booking')) {
            return 'booking';
        }

        return 'platform_api';
    }

    private function thresholdRate(PartnerAlertPolicy $policy, float $default): float
    {
        $config = $policy->config_json ?? [];
        $threshold = is_array($config['threshold'] ?? null) ? $config['threshold'] : [];

        return (float) ($threshold['rate'] ?? $default);
    }

    private function thresholdInteger(PartnerAlertPolicy $policy, string $key, int $default): int
    {
        $config = $policy->config_json ?? [];
        $threshold = is_array($config['threshold'] ?? null) ? $config['threshold'] : [];

        return (int) ($threshold[$key] ?? $default);
    }

    private function windowSeconds(PartnerAlertPolicy $policy, int $default): int
    {
        $config = $policy->config_json ?? [];

        return (int) ($config['window_seconds'] ?? $default);
    }
}
