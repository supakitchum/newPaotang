<?php

namespace App\Shared\Observability;

use App\Models\Partner;
use App\Models\PartnerAlertEvent;
use App\Models\PartnerAlertPolicy;
use App\Models\PartnerDailyUsageSummary;
use App\Models\PartnerHealthCheck;
use App\Models\PartnerMonitoringProfile;
use App\Models\PartnerUsageEvent;
use App\Models\PartnerUsageMeter;
use Illuminate\Support\Facades\Schema;

class ObservabilityReportService
{
    public function __construct(
        private readonly ObservabilityCatalog $catalog,
        private readonly ObservabilityRedactor $redactor,
    ) {
    }

    /**
     * @return array<string, mixed>
     */
    public function report(): array
    {
        $missingPolicies = $this->missingRequiredAlertPolicies();

        return [
            'status' => $missingPolicies === [] ? 'ready_local' : 'degraded_local',
            'generated_at' => now()->toISOString(),
            'boundary' => [
                'local_dev_verifiable' => true,
                'staging_approved' => false,
                'production_approved' => false,
                'client_delivery_approved' => false,
            ],
            'environment' => [
                'name' => (string) config('platform.observability.environment'),
                'enabled' => (bool) config('platform.observability.enabled'),
                'metrics_label' => (string) config('platform.observability.metrics_label'),
            ],
            'summary' => [
                'partners' => Partner::query()->count(),
                'active_monitoring_profiles' => PartnerMonitoringProfile::query()->where('status', 'active')->count(),
                'active_usage_meters' => PartnerUsageMeter::query()->where('status', 'active')->count(),
                'active_alert_policies' => PartnerAlertPolicy::query()->where('status', 'active')->count(),
                'health_checks' => PartnerHealthCheck::query()->count(),
                'usage_events' => PartnerUsageEvent::query()->count(),
                'daily_usage_summaries' => PartnerDailyUsageSummary::query()->count(),
                'alert_events' => PartnerAlertEvent::query()->count(),
                'missing_required_alert_policies' => $missingPolicies,
            ],
            'schema_readiness' => [
                'partner_usage_events' => Schema::hasTable('partner_usage_events'),
                'partner_daily_usage_summaries' => Schema::hasTable('partner_daily_usage_summaries'),
                'partner_alert_events' => Schema::hasTable('partner_alert_events'),
            ],
            'signals' => $this->catalog->signalInventory(),
            'required_alert_policies' => $this->catalog->requiredAlertPolicyKeys(),
            'metric_label_policy' => $this->catalog->metricLabelKeys(),
            'alert_channels' => $this->redactor->redact([
                'enabled' => (bool) config('platform.alerts.enabled'),
                'local_channels' => ['database', 'log'],
                'configured_channels' => config('platform.alerts.channels', []),
                'external_delivery_enabled' => (bool) config('platform.alerts.external_delivery_enabled'),
                'webhook_url' => config('platform.alerts.webhook_url'),
                'production_placeholders' => ['webhook', 'email', 'sentry', 'grafana', 'datadog', 'new_relic'],
            ]),
            'redaction' => [
                'rule' => 'Payloads are recursively redacted by sensitive key name before report or alert delivery.',
                'sensitive_key_count' => count(config('platform.audit.sensitive_keys', [])),
            ],
            'external_integration_blockers' => $this->catalog->externalIntegrationBlockers(),
            'docker_validation_commands' => [
                'docker compose exec platform-api php artisan platform:observability:report --format=json',
                'docker compose exec platform-api php artisan platform:alerts:check --dry-run --format=json',
            ],
        ];
    }

    /**
     * @return array<string, array<int, string>>
     */
    private function missingRequiredAlertPolicies(): array
    {
        $required = $this->catalog->requiredAlertPolicyKeys();
        $missing = [];

        $partners = Partner::query()->orderBy('id')->get(['id'])->all();

        foreach ($partners as $partner) {
            $present = PartnerAlertPolicy::query()
                ->where('partner_id', $partner->id)
                ->whereIn('policy_key', $required)
                ->pluck('policy_key')
                ->all();

            $diff = array_values(array_diff($required, $present));

            if ($diff !== []) {
                $missing[(string) $partner->id] = $diff;
            }
        }

        return $missing;
    }
}
