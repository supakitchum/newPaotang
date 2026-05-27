<?php

namespace App\Modules\AdminOperations\Services;

use App\Models\Customer;
use App\Models\CustomerAuthSession;
use App\Models\Game;
use App\Models\Order;
use App\Models\Partner;
use App\Models\PartnerAlertEvent;
use App\Models\PartnerAlertPolicy;
use App\Models\PartnerBillingPlan;
use App\Models\PartnerBillingPlanBinding;
use App\Models\PartnerDailyUsageSummary;
use App\Models\PartnerHealthCheck;
use App\Models\PartnerMonitoringProfile;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\PartnerTenantSetting;
use App\Models\PartnerUsageMeter;
use App\Models\PlatformSystemSetting;
use App\Models\SyncInbox;
use App\Models\SyncOutbox;
use App\Models\TenantPriceRule;
use App\Models\Wallet;
use App\Models\WebhookCallback;
use App\Modules\Reward\Services\TenantRewardPriceRuleService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Tenancy\TenantHostNormalizer;
use App\Support\CustomerNo;
use App\Support\YoutubeLiveUrl;
use Illuminate\Database\Eloquent\Builder;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Hash;
use Illuminate\Support\Str;

class BoMenuCompletionService
{
    private const ACTIVE_ARCHIVE_STATUSES = ['active', 'archived'];
    private const ACTIVE_PAUSED_ARCHIVED_STATUSES = ['active', 'paused', 'archived'];
    private const ACTIVE_PAUSED_SUSPENDED_ARCHIVED_STATUSES = ['active', 'paused', 'suspended', 'archived'];
    private const BILLING_BINDING_STATUSES = ['trial', 'active', 'past_due', 'suspended', 'cancelled'];
    private const DOMAIN_STATUSES = ['pending_verification', 'dns_verified', 'ssl_pending', 'active', 'failed', 'suspended', 'archived'];
    private const DOMAIN_TYPES = ['subdomain', 'custom_domain'];
    private const HEALTH_STATUSES = ['healthy', 'warning', 'critical', 'suspended', 'unknown'];
    private const MEMBER_STATUSES = ['active', 'pending_verification', 'suspended', 'disabled'];
    private const ALERT_EVENT_STATUSES = ['open', 'acknowledged', 'resolved', 'suppressed'];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly TenantRewardPriceRuleService $rewardPriceRules,
    ) {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listPartnerMonitoring(array $queryParams): array
    {
        $query = PartnerMonitoringProfile::query()
            ->with('partner')
            ->orderBy('id');

        $this->whereString($query, 'partner_id', $queryParams['partner_id'] ?? null);
        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->monitoringProfileResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findPartnerMonitoring(string $profileId): ?array
    {
        $profile = PartnerMonitoringProfile::query()
            ->with('partner')
            ->where('id', $profileId)
            ->first();

        return $profile === null ? null : $this->monitoringProfileResource($profile);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updatePartnerMonitoring(string $profileId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $profile = PartnerMonitoringProfile::query()->where('id', $profileId)->first();

        if ($profile === null) {
            return ['error' => 'not_found'];
        }

        $updates = [];
        $errors = [];

        if (array_key_exists('status', $payload)) {
            $status = trim((string) $payload['status']);

            if (! in_array($status, self::ACTIVE_PAUSED_SUSPENDED_ARCHIVED_STATUSES, true)) {
                $errors['status'][] = 'The status field is invalid.';
            } else {
                $updates['status'] = $status;
            }
        }

        if (array_key_exists('health_status', $payload)) {
            $healthStatus = trim((string) $payload['health_status']);

            if (! in_array($healthStatus, self::HEALTH_STATUSES, true)) {
                $errors['health_status'][] = 'The health_status field is invalid.';
            } else {
                $updates['health_status'] = $healthStatus;
            }
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($profile, $profileId, $updates, $payload, $actor, $request): array {
            if ($updates !== []) {
                PartnerMonitoringProfile::query()->where('id', $profileId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'partner_monitoring.updated', 'partner_monitoring_profile', $profileId, $payload, partnerId: (string) $profile->partner_id);

            return ['resource' => $this->findPartnerMonitoring($profileId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listPartnerUsage(array $queryParams): array
    {
        $query = PartnerUsageMeter::query()
            ->with('partner')
            ->orderBy('id');

        $this->whereString($query, 'partner_id', $queryParams['partner_id'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->usageMeterResource($row, $queryParams));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findPartnerUsage(string $usageMeterId): ?array
    {
        $meter = PartnerUsageMeter::query()
            ->with('partner')
            ->where('id', $usageMeterId)
            ->first();

        return $meter === null ? null : $this->usageMeterResource($meter, []);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updatePartnerUsage(string $usageMeterId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $meter = PartnerUsageMeter::query()->where('id', $usageMeterId)->first();

        if ($meter === null) {
            return ['error' => 'not_found'];
        }

        $updates = [];
        $errors = [];

        if (array_key_exists('status', $payload)) {
            $status = trim((string) $payload['status']);

            if (! in_array($status, self::ACTIVE_PAUSED_ARCHIVED_STATUSES, true)) {
                $errors['status'][] = 'The status field is invalid.';
            } else {
                $updates['status'] = $status;
            }
        }

        foreach (['value', 'limit_value'] as $field) {
            if (! array_key_exists($field, $payload)) {
                continue;
            }

            if ($payload[$field] === null && $field === 'limit_value') {
                $updates[$field] = null;
                continue;
            }

            $value = filter_var($payload[$field], FILTER_VALIDATE_INT);

            if ($value === false || $value < 0) {
                $errors[$field][] = 'The '.$field.' field must be a non-negative integer.';
            } else {
                $updates[$field] = $value;
            }
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($meter, $usageMeterId, $updates, $payload, $actor, $request): array {
            if ($updates !== []) {
                PartnerUsageMeter::query()->where('id', $usageMeterId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'partner_usage.updated', 'partner_usage_meter', $usageMeterId, $payload, partnerId: (string) $meter->partner_id);

            return ['resource' => $this->findPartnerUsage($usageMeterId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listBillingPlans(array $queryParams): array
    {
        $query = PartnerBillingPlan::query()->orderBy('id');
        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->billingPlanResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findBillingPlan(string $billingPlanId): ?array
    {
        $plan = PartnerBillingPlan::query()->where('id', $billingPlanId)->first();

        return $plan === null ? null : $this->billingPlanResource($plan);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createBillingPlan(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->billingPlanPayload($payload, true);
        $errors = $this->billingPlanErrors($normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (PartnerBillingPlan::query()->where('code', $normalized['code'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($normalized, $payload, $actor, $request): array {
            $id = 'bpl_'.Str::ulid()->toBase32();
            PartnerBillingPlan::query()->create(array_merge($normalized, [
                'id' => $id,
                'created_at' => now(),
                'updated_at' => now(),
            ]));

            $this->audit($actor, $request, 'billing_plan.created', 'partner_billing_plan', $id, $payload);

            return ['resource' => $this->findBillingPlan($id)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateBillingPlan(string $billingPlanId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $plan = PartnerBillingPlan::query()->where('id', $billingPlanId)->first();

        if ($plan === null) {
            return ['error' => 'not_found'];
        }

        $updates = $this->billingPlanPayload($payload, false);
        $errors = $this->billingPlanErrors($updates, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('code', $updates)
            && PartnerBillingPlan::query()->where('code', $updates['code'])->where('id', '!=', $billingPlanId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($billingPlanId, $updates, $payload, $actor, $request): array {
            if ($updates !== []) {
                PartnerBillingPlan::query()->where('id', $billingPlanId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'billing_plan.updated', 'partner_billing_plan', $billingPlanId, $payload);

            return ['resource' => $this->findBillingPlan($billingPlanId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listBillingBindings(array $queryParams): array
    {
        $query = PartnerBillingPlanBinding::query()
            ->with('partner')
            ->orderBy('id');

        $this->whereString($query, 'partner_id', $queryParams['partner_id'] ?? null);
        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->billingBindingResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findBillingBinding(string $bindingId): ?array
    {
        $binding = PartnerBillingPlanBinding::query()
            ->with('partner')
            ->where('id', $bindingId)
            ->first();

        return $binding === null ? null : $this->billingBindingResource($binding);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateBillingBinding(string $bindingId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $binding = PartnerBillingPlanBinding::query()->where('id', $bindingId)->first();

        if ($binding === null) {
            return ['error' => 'not_found'];
        }

        $updates = [];
        $errors = [];

        if (array_key_exists('billing_plan_code', $payload)) {
            $code = trim((string) $payload['billing_plan_code']);

            if ($code === '') {
                $errors['billing_plan_code'][] = 'The billing_plan_code field is required.';
            } else {
                $updates['billing_plan_code'] = $code;
            }
        }

        if (array_key_exists('status', $payload)) {
            $status = trim((string) $payload['status']);

            if (! in_array($status, self::BILLING_BINDING_STATUSES, true)) {
                $errors['status'][] = 'The status field is invalid.';
            } else {
                $updates['status'] = $status;
            }
        }

        if (array_key_exists('effective_at', $payload)) {
            if ($payload['effective_at'] === null || trim((string) $payload['effective_at']) === '') {
                $updates['effective_at'] = null;
            } else {
                try {
                    $updates['effective_at'] = Carbon::parse((string) $payload['effective_at']);
                } catch (\Throwable) {
                    $errors['effective_at'][] = 'The effective_at field must be a valid datetime.';
                }
            }
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($binding, $bindingId, $updates, $payload, $actor, $request): array {
            if ($updates !== []) {
                PartnerBillingPlanBinding::query()->where('id', $bindingId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'billing_binding.updated', 'partner_billing_plan_binding', $bindingId, $payload, partnerId: (string) $binding->partner_id);

            return ['resource' => $this->findBillingBinding($bindingId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listAlertPolicies(array $queryParams): array
    {
        $query = PartnerAlertPolicy::query()
            ->with('partner')
            ->orderBy('id');

        $this->whereString($query, 'partner_id', $queryParams['partner_id'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->alertPolicyResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findAlertPolicy(string $alertPolicyId): ?array
    {
        $policy = PartnerAlertPolicy::query()
            ->with('partner')
            ->where('id', $alertPolicyId)
            ->first();

        return $policy === null ? null : $this->alertPolicyResource($policy);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createAlertPolicy(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->alertPolicyPayload($payload, true);
        $errors = $this->alertPolicyErrors($normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            PartnerAlertPolicy::query()
                ->where('partner_id', $normalized['partner_id'])
                ->where('policy_key', $normalized['policy_key'])
                ->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($normalized, $payload, $actor, $request): array {
            $id = 'pal_'.Str::ulid()->toBase32();
            PartnerAlertPolicy::query()->create(array_merge($normalized, [
                'id' => $id,
                'created_at' => now(),
                'updated_at' => now(),
            ]));

            $this->audit($actor, $request, 'alert_policy.created', 'partner_alert_policy', $id, $payload, partnerId: $normalized['partner_id']);

            return ['resource' => $this->findAlertPolicy($id)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAlertPolicy(string $alertPolicyId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $policy = PartnerAlertPolicy::query()->where('id', $alertPolicyId)->first();

        if ($policy === null) {
            return ['error' => 'not_found'];
        }

        $updates = $this->alertPolicyPayload($payload, false);
        $errors = $this->alertPolicyErrors($updates, false, (string) $policy->partner_id);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $partnerId = $updates['partner_id'] ?? (string) $policy->partner_id;
        $policyKey = $updates['policy_key'] ?? (string) $policy->policy_key;

        if (
            PartnerAlertPolicy::query()
                ->where('partner_id', $partnerId)
                ->where('policy_key', $policyKey)
                ->where('id', '!=', $alertPolicyId)
                ->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($alertPolicyId, $updates, $payload, $actor, $request, $partnerId): array {
            if ($updates !== []) {
                PartnerAlertPolicy::query()->where('id', $alertPolicyId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'alert_policy.updated', 'partner_alert_policy', $alertPolicyId, $payload, partnerId: $partnerId);

            return ['resource' => $this->findAlertPolicy($alertPolicyId)];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listAlertEvents(array $queryParams): array
    {
        $query = PartnerAlertEvent::query()
            ->with('partner')
            ->orderBy('id');

        $this->whereString($query, 'partner_id', $queryParams['partner_id'] ?? null);
        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->alertEventResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findAlertEvent(string $alertEventId): ?array
    {
        $event = PartnerAlertEvent::query()
            ->with('partner')
            ->where('id', $alertEventId)
            ->first();

        return $event === null ? null : $this->alertEventResource($event);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string}
     */
    public function changeAlertEventStatus(string $alertEventId, string $status, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $event = PartnerAlertEvent::query()->where('id', $alertEventId)->first();

        if ($event === null) {
            return ['error' => 'not_found'];
        }

        return DB::transaction(function () use ($event, $alertEventId, $status, $payload, $actor, $request): array {
            PartnerAlertEvent::query()->where('id', $alertEventId)->update([
                'status' => $status,
                'updated_at' => now(),
            ]);

            $this->audit(
                $actor,
                $request,
                'alert_event.'.$status,
                'partner_alert_event',
                $alertEventId,
                $payload,
                tenantId: $event->tenant_id,
                partnerId: (string) $event->partner_id,
            );

            return ['resource' => $this->findAlertEvent($alertEventId)];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function systemSettings(): array
    {
        $this->ensureDefaultSystemSettings();

        $rows = PlatformSystemSetting::query()->orderBy('key')->get()->all();

        return $this->systemSettingsResource($rows);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateSystemSettings(array $payload, AdminSessionContext $actor, Request $request): array
    {
        $settings = $this->systemSettingUpdates($payload);

        if ($settings === []) {
            return ['resource' => $this->systemSettings()];
        }

        return DB::transaction(function () use ($settings, $payload, $actor, $request): array {
            foreach ($settings as $key => $value) {
                PlatformSystemSetting::query()->updateOrCreate(
                    ['key' => $key],
                    [
                        'id' => $this->stableId('pss', $key),
                        'value_json' => $value,
                        'status' => 'active',
                        'updated_at' => now(),
                    ],
                );
            }

            $this->audit($actor, $request, 'system_settings.updated', 'platform_system_settings', 'platform_system_settings', $payload);

            return ['resource' => $this->systemSettings()];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listWebhookLogs(array $queryParams): array
    {
        $query = WebhookCallback::query()->orderBy('id');

        $this->whereString($query, 'provider', $queryParams['provider'] ?? null);
        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->webhookLogResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findWebhookLog(string $webhookLogId): ?array
    {
        $log = WebhookCallback::query()->where('id', $webhookLogId)->first();

        return $log === null ? null : $this->webhookLogResource($log);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listPriceRules(string $tenantId, array $queryParams): array
    {
        $gameId = trim((string) ($queryParams['game_id'] ?? '')) ?: $this->latestOpenPriceRuleGameId();

        if ($gameId === null) {
            return [
                'data' => [],
                'meta' => [
                    'next_cursor' => null,
                    'has_more' => false,
                    'default_game_id' => null,
                    'live_settings' => $this->tenantLiveSettings($tenantId),
                ],
            ];
        }

        return $this->paginateArrayRows(
            $this->rewardPriceRules->settingRows($tenantId, $gameId),
            $queryParams,
            [
                'default_game_id' => $gameId,
                'live_settings' => $this->tenantLiveSettings($tenantId),
            ],
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function tenantLiveSettings(string $tenantId): array
    {
        $centralUrl = $this->centralWaitingResultYoutubeUrl();
        $tenantUrl = trim((string) (PartnerTenantSetting::query()
            ->where('tenant_id', $tenantId)
            ->value('waiting_result_youtube_url') ?? ''));
        $resolvedUrl = $tenantUrl !== '' ? $tenantUrl : $centralUrl;

        return [
            'id' => 'tenant_reward_live_settings',
            'tenant_id' => $tenantId,
            'waiting_result_youtube_url' => $resolvedUrl,
            'waiting_result_youtube_embed_url' => YoutubeLiveUrl::embedUrl($resolvedUrl),
            'tenant_override_youtube_url' => $tenantUrl,
            'central_default_youtube_url' => $centralUrl,
            'source' => $tenantUrl !== '' ? 'tenant_override' : ($centralUrl !== '' ? 'central_default' : 'not_configured'),
            'updated_at' => PartnerTenantSetting::query()
                ->where('tenant_id', $tenantId)
                ->value('updated_at'),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateTenantLiveSettings(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $value = $this->liveSettingsPayloadValue($payload);

        if ($value === null) {
            return ['error' => 'validation_failed', 'errors' => [
                'waiting_result_youtube_url' => ['The waiting_result_youtube_url field is required.'],
            ]];
        }

        if (! YoutubeLiveUrl::isAllowedOrEmpty($value)) {
            return ['error' => 'validation_failed', 'errors' => [
                'waiting_result_youtube_url' => ['The waiting_result_youtube_url field must be a valid YouTube URL.'],
            ]];
        }

        return DB::transaction(function () use ($tenantId, $payload, $actor, $request, $value): array {
            $settings = $this->ensureTenantSettingsForLiveSettings($tenantId);

            if ($settings === null) {
                return ['error' => 'not_found'];
            }

            $url = trim($value);
            PartnerTenantSetting::query()->where('tenant_id', $tenantId)->update([
                'waiting_result_youtube_url' => $url === '' ? null : $url,
                'config_version' => ((int) $settings->config_version) + 1,
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'price_rule.live_settings.updated', 'partner_tenant_setting', $tenantId, $payload, tenantId: $tenantId);

            return ['resource' => $this->tenantLiveSettings($tenantId)];
        });
    }

    /**
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listPriceRuleGames(string $tenantId): array
    {
        $defaultGameId = $this->latestOpenPriceRuleGameId();
        $rows = Game::query()
            ->orderByRaw("CASE WHEN status = 'open' THEN 0 ELSE 1 END")
            ->orderByDesc('draw_at')
            ->limit(100)
            ->get()
            ->map(fn (object $game): array => $this->priceRuleGameResource($game, $defaultGameId))
            ->all();

        return [
            'data' => $rows,
            'meta' => ['default_game_id' => $defaultGameId],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findPriceRule(string $tenantId, string $priceRuleId): ?array
    {
        $setting = $this->rewardPriceRules->settingRow($tenantId, $priceRuleId);

        if ($setting !== null) {
            return $setting;
        }

        $rule = TenantPriceRule::query()
            ->forTenant($tenantId)
            ->where('id', $priceRuleId)
            ->first();

        return $rule === null ? null : $this->priceRuleResource($rule);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createPriceRule(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        if (array_key_exists('partner_payout_amount', $payload)) {
            return DB::transaction(function () use ($tenantId, $payload, $actor, $request): array {
                $result = $this->rewardPriceRules->savePayoutSetting($tenantId, '', $payload);

                if (isset($result['error'])) {
                    return $result;
                }

                $targetId = (string) ($result['resource']['tenant_price_rule_id'] ?? $result['resource']['id'] ?? '');
                $this->audit($actor, $request, 'price_rule.updated', 'tenant_price_rule', $targetId, $payload, tenantId: $tenantId);

                return $result;
            });
        }

        $normalized = $this->priceRulePayload($tenantId, $payload, true);
        $errors = $this->priceRuleErrors($tenantId, $normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (TenantPriceRule::query()->forTenant($tenantId)->where('code', $normalized['code'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $normalized, $payload, $actor, $request): array {
            $id = 'prr_'.Str::ulid()->toBase32();
            TenantPriceRule::query()->create(array_merge($normalized, [
                'id' => $id,
                'tenant_id' => $tenantId,
                'created_at' => now(),
                'updated_at' => now(),
            ]));

            $this->audit($actor, $request, 'price_rule.created', 'tenant_price_rule', $id, $payload, tenantId: $tenantId);

            return ['resource' => $this->findPriceRule($tenantId, $id)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updatePriceRule(string $tenantId, string $priceRuleId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        if ($this->rewardPriceRules->settingIdentityFromId($priceRuleId) !== null || array_key_exists('partner_payout_amount', $payload)) {
            return DB::transaction(function () use ($tenantId, $priceRuleId, $payload, $actor, $request): array {
                $result = $this->rewardPriceRules->savePayoutSetting($tenantId, $priceRuleId, $payload);

                if (isset($result['error'])) {
                    return $result;
                }

                $targetId = (string) ($result['resource']['tenant_price_rule_id'] ?? $result['resource']['id'] ?? $priceRuleId);
                $this->audit($actor, $request, 'price_rule.updated', 'tenant_price_rule', $targetId, $payload, tenantId: $tenantId);

                return $result;
            });
        }

        $rule = TenantPriceRule::query()->forTenant($tenantId)->where('id', $priceRuleId)->first();

        if ($rule === null) {
            return ['error' => 'not_found'];
        }

        $updates = $this->priceRulePayload($tenantId, $payload, false);
        $validationPayload = array_merge([
            'tenant_id' => (string) $rule->tenant_id,
            'game_id' => $rule->game_id,
            'code' => (string) $rule->code,
            'name' => (string) $rule->name,
            'rule_type' => (string) $rule->rule_type,
            'base_source' => (string) ($rule->base_source ?? TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD),
            'price_amount' => (int) $rule->price_amount,
            'adjustment_amount' => (int) ($rule->adjustment_amount ?? $rule->price_amount ?? 0),
            'adjustment_bps' => $rule->adjustment_bps,
            'currency' => (string) $rule->currency,
            'status' => (string) $rule->status,
            'conditions_json' => $this->arrayValue($rule->conditions_json),
        ], $updates);
        $errors = $this->priceRuleErrors($tenantId, $validationPayload, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('code', $updates)
            && TenantPriceRule::query()->forTenant($tenantId)->where('code', $updates['code'])->where('id', '!=', $priceRuleId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $priceRuleId, $updates, $payload, $actor, $request): array {
            if ($updates !== []) {
                TenantPriceRule::query()->forTenant($tenantId)->where('id', $priceRuleId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'price_rule.updated', 'tenant_price_rule', $priceRuleId, $payload, tenantId: $tenantId);

            return ['resource' => $this->findPriceRule($tenantId, $priceRuleId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function archivePriceRule(string $tenantId, string $priceRuleId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        if (TenantPriceRule::query()->forTenant($tenantId)->where('id', $priceRuleId)->doesntExist()) {
            return ['error' => 'not_found'];
        }

        return DB::transaction(function () use ($tenantId, $priceRuleId, $payload, $actor, $request): array {
            TenantPriceRule::query()->forTenant($tenantId)->where('id', $priceRuleId)->update([
                'status' => 'archived',
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'price_rule.archived', 'tenant_price_rule', $priceRuleId, $payload, tenantId: $tenantId);

            return ['resource' => [], 'status' => 204];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listMembers(string $tenantId, array $queryParams): array
    {
        $query = Customer::query()
            ->select('customers.*')
            ->selectSub(
                CustomerAuthSession::query()
                    ->selectRaw('MAX(last_used_at)')
                    ->whereColumn('customer_auth_sessions.tenant_id', 'customers.tenant_id')
                    ->whereColumn('customer_auth_sessions.customer_id', 'customers.id'),
                'last_online_at',
            )
            ->selectSub(
                Order::query()
                    ->selectRaw('COUNT(*)')
                    ->whereColumn('orders.tenant_id', 'customers.tenant_id')
                    ->whereColumn('orders.customer_id', 'customers.id'),
                'order_count_sort',
            )
            ->selectSub(
                Order::query()
                    ->selectRaw('COALESCE(SUM(total_amount), 0)')
                    ->whereColumn('orders.tenant_id', 'customers.tenant_id')
                    ->whereColumn('orders.customer_id', 'customers.id')
                    ->where('status', 'paid'),
                'lifetime_spend_sort',
            )
            ->forTenant($tenantId)
            ->with('wallets');

        $q = trim((string) ($queryParams['q'] ?? ''));

        if ($q !== '') {
            $query->where(function (Builder $nested) use ($q): void {
                $nested->where('name', 'like', '%'.$q.'%')
                    ->orWhere('phone', 'like', '%'.$q.'%')
                    ->orWhere('email', 'like', '%'.$q.'%')
                    ->orWhere('customer_no', 'like', '%'.strtoupper($q).'%')
                    ->orWhere('id', 'like', '%'.$q.'%');
            });
        }

        $this->whereString($query, 'status', $queryParams['status'] ?? null);

        if (is_string($queryParams['registered_from'] ?? null) && trim((string) $queryParams['registered_from']) !== '') {
            $query->whereDate('created_at', '>=', (string) $queryParams['registered_from']);
        }

        if (is_string($queryParams['registered_to'] ?? null) && trim((string) $queryParams['registered_to']) !== '') {
            $query->whereDate('created_at', '<=', (string) $queryParams['registered_to']);
        }

        $this->applyMemberSort($query, $queryParams);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->memberResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findMember(string $tenantId, string $memberId): ?array
    {
        $member = Customer::query()
            ->forTenant($tenantId)
            ->with('wallets')
            ->where('id', $memberId)
            ->first();

        return $member === null ? null : $this->memberResource($member);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createMember(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $normalized = $this->memberPayload($tenantId, $payload, true);
        $errors = $this->memberErrors($tenantId, $normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (Customer::query()->forTenant($tenantId)->where('phone', $normalized['phone'])->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $normalized, $payload, $actor, $request): array {
            $id = 'cus_'.Str::ulid()->toBase32();
            Customer::query()->create(array_merge($normalized, [
                'id' => $id,
                'tenant_id' => $tenantId,
                'customer_no' => $this->newCustomerNo($tenantId),
                'created_at' => now(),
                'updated_at' => now(),
            ]));

            $this->audit($actor, $request, 'member.created', 'customer', $id, $payload, tenantId: $tenantId);

            return ['resource' => $this->findMember($tenantId, $id)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateMember(string $tenantId, string $memberId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        if (Customer::query()->forTenant($tenantId)->where('id', $memberId)->doesntExist()) {
            return ['error' => 'not_found'];
        }

        $updates = $this->memberPayload($tenantId, $payload, false);
        $errors = $this->memberErrors($tenantId, $updates, false);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('phone', $updates)
            && Customer::query()->forTenant($tenantId)->where('phone', $updates['phone'])->where('id', '!=', $memberId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $memberId, $updates, $payload, $actor, $request): array {
            if ($updates !== []) {
                Customer::query()->forTenant($tenantId)->where('id', $memberId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'member.updated', 'customer', $memberId, $payload, tenantId: $tenantId);

            return ['resource' => $this->findMember($tenantId, $memberId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function changeMemberStatus(string $tenantId, string $memberId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        if (Customer::query()->forTenant($tenantId)->where('id', $memberId)->doesntExist()) {
            return ['error' => 'not_found'];
        }

        $status = trim((string) ($payload['status'] ?? ''));
        $reason = trim((string) ($payload['reason'] ?? ''));
        $errors = [];

        if (! in_array($status, self::MEMBER_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if ($reason === '') {
            $errors['reason'][] = 'The reason field is required.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return DB::transaction(function () use ($tenantId, $memberId, $status, $payload, $actor, $request): array {
            Customer::query()->forTenant($tenantId)->where('id', $memberId)->update([
                'status' => $status,
                'updated_at' => now(),
            ]);

            $this->audit($actor, $request, 'member.status_changed', 'customer', $memberId, $payload, tenantId: $tenantId);

            return ['resource' => $this->findMember($tenantId, $memberId)];
        });
    }

    /**
     * @return array<string, mixed>
     */
    public function tenantMonitoring(string $tenantId): array
    {
        $tenant = PartnerTenant::query()->where('id', $tenantId)->first();
        $profile = $tenant === null
            ? null
            : PartnerMonitoringProfile::query()->where('partner_id', $tenant->partner_id)->first();

        $healthChecks = $tenant === null
            ? []
            : PartnerHealthCheck::query()
                ->where('partner_id', $tenant->partner_id)
                ->where(function (Builder $query) use ($tenantId): void {
                    $query->where('tenant_id', $tenantId)->orWhereNull('tenant_id');
                })
                ->orderBy('check_key')
                ->get()
                ->all();

        return [
            'id' => $profile?->id ?? $this->stableId('mon', $tenantId),
            'tenant_id' => $tenantId,
            'status' => $profile?->status ?? 'active',
            'created_at' => $profile?->created_at,
            'updated_at' => $profile?->updated_at,
            'partner_id' => $tenant?->partner_id,
            'health_status' => $profile?->health_status ?? 'unknown',
            'checks' => array_map(fn (object $check): array => [
                'id' => (string) $check->id,
                'tenant_id' => $check->tenant_id,
                'partner_id' => (string) $check->partner_id,
                'check_key' => (string) $check->check_key,
                'health_status' => (string) $check->health_status,
                'checked_at' => $check->checked_at,
            ], $healthChecks),
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function tenantUsage(string $tenantId, array $queryParams): array
    {
        $query = PartnerDailyUsageSummary::query()
            ->forTenant($tenantId)
            ->orderByDesc('usage_date')
            ->orderBy('id');

        if (is_string($queryParams['date_from'] ?? null) && trim((string) $queryParams['date_from']) !== '') {
            $query->whereDate('usage_date', '>=', (string) $queryParams['date_from']);
        }

        if (is_string($queryParams['date_to'] ?? null) && trim((string) $queryParams['date_to']) !== '') {
            $query->whereDate('usage_date', '<=', (string) $queryParams['date_to']);
        }

        $rows = $query->limit(31)->get()->all();

        return [
            'id' => $this->stableId('tus', $tenantId),
            'tenant_id' => $tenantId,
            'status' => 'active',
            'created_at' => null,
            'updated_at' => null,
            'date_from' => $queryParams['date_from'] ?? null,
            'date_to' => $queryParams['date_to'] ?? null,
            'summaries' => array_map(fn (object $row): array => $this->dailyUsageResource($row), $rows),
            'totals' => $this->usageTotals($rows),
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listTenantDomains(string $tenantId, array $queryParams): array
    {
        $query = PartnerTenantDomain::query()
            ->forTenant($tenantId)
            ->with('partner')
            ->orderBy('id');

        $this->whereString($query, 'status', $queryParams['status'] ?? null);
        $this->whereString($query, 'type', $queryParams['type'] ?? null);

        return $this->paginate($query, $queryParams, fn (object $row): array => $this->tenantDomainResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function findTenantDomain(string $tenantId, string $domainId): ?array
    {
        $domain = PartnerTenantDomain::query()
            ->forTenant($tenantId)
            ->with('partner')
            ->where('id', $domainId)
            ->first();

        return $domain === null ? null : $this->tenantDomainResource($domain);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createTenantDomain(string $tenantId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $tenant = PartnerTenant::query()->where('id', $tenantId)->first();

        if ($tenant === null) {
            return ['error' => 'not_found'];
        }

        $normalized = $this->tenantDomainPayload($tenantId, (string) $tenant->partner_id, $payload, true);
        $errors = $this->tenantDomainErrors($tenantId, $normalized, true);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (PartnerTenantDomain::query()->whereIn('host', TenantHostNormalizer::variants($normalized['host']))->exists()) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $normalized, $payload, $actor, $request): array {
            $id = 'dom_'.Str::ulid()->toBase32();

            if (($normalized['is_primary'] ?? false) === true) {
                PartnerTenantDomain::query()->forTenant($tenantId)->update(['is_primary' => false, 'updated_at' => now()]);
            }

            PartnerTenantDomain::query()->create(array_merge($normalized, [
                'id' => $id,
                'created_at' => now(),
                'updated_at' => now(),
            ]));

            $this->audit($actor, $request, 'domain.created', 'partner_tenant_domain', $id, $payload, tenantId: $tenantId, partnerId: (string) $normalized['partner_id']);

            return ['resource' => $this->findTenantDomain($tenantId, $id)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateTenantDomain(string $tenantId, string $domainId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $domain = PartnerTenantDomain::query()->forTenant($tenantId)->where('id', $domainId)->first();

        if ($domain === null) {
            return ['error' => 'not_found'];
        }

        $updates = $this->tenantDomainPayload($tenantId, (string) $domain->partner_id, $payload, false, $domain);
        $errors = $this->tenantDomainErrors($tenantId, $updates, false, $domain);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (
            array_key_exists('host', $updates)
            && PartnerTenantDomain::query()->whereIn('host', TenantHostNormalizer::variants($updates['host']))->where('id', '!=', $domainId)->exists()
        ) {
            return ['error' => 'resource_conflict'];
        }

        return DB::transaction(function () use ($tenantId, $domainId, $domain, $updates, $payload, $actor, $request): array {
            if (($updates['is_primary'] ?? false) === true) {
                PartnerTenantDomain::query()->forTenant($tenantId)->where('id', '!=', $domainId)->update(['is_primary' => false, 'updated_at' => now()]);
            }

            if ($updates !== []) {
                PartnerTenantDomain::query()->forTenant($tenantId)->where('id', $domainId)->update(array_merge($updates, ['updated_at' => now()]));
            }

            $this->audit($actor, $request, 'domain.updated', 'partner_tenant_domain', $domainId, $payload, tenantId: $tenantId, partnerId: (string) $domain->partner_id);

            return ['resource' => $this->findTenantDomain($tenantId, $domainId)];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function removeTenantDomain(string $tenantId, string $domainId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $domain = PartnerTenantDomain::query()->forTenant($tenantId)->where('id', $domainId)->first();

        if ($domain === null) {
            return ['error' => 'not_found'];
        }

        return DB::transaction(function () use ($tenantId, $domainId, $domain, $payload, $actor, $request): array {
            PartnerTenantDomain::query()->forTenant($tenantId)->where('id', $domainId)->delete();

            $this->audit($actor, $request, 'domain.removed', 'partner_tenant_domain', $domainId, $payload, tenantId: $tenantId, partnerId: (string) $domain->partner_id);

            return ['resource' => [], 'status' => 204];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function verifyTenantDomain(string $tenantId, string $domainId, array $payload, AdminSessionContext $actor, Request $request): array
    {
        $domain = PartnerTenantDomain::query()->forTenant($tenantId)->where('id', $domainId)->first();

        if ($domain === null) {
            return ['error' => 'not_found'];
        }

        $now = now();
        $localOnly = $this->isLocalOnlyHost((string) $domain->host);
        $updates = ['cloudflare_readiness_checked_at' => $now];
        $dnsReady = $localOnly || $domain->dns_verified_at !== null || $this->truthyPayload($payload, ['dns_verified', 'dns_ready']);
        $sslReady = $localOnly || $domain->ssl_ready_at !== null || $this->truthyPayload($payload, ['ssl_ready', 'https_ready']);
        $proxyReady = $localOnly || $domain->cloudflare_proxy_verified_at !== null || $this->truthyPayload($payload, ['cloudflare_proxy_verified', 'proxy_verified']);
        $httpsReady = $localOnly || $domain->https_enforced_at !== null || $this->truthyPayload($payload, ['https_enforced']);

        if ($dnsReady && $domain->dns_verified_at === null) {
            $updates['dns_verified_at'] = $now;
        }

        if ($sslReady && $domain->ssl_ready_at === null) {
            $updates['ssl_ready_at'] = $now;
        }

        if ($proxyReady && $domain->cloudflare_proxy_verified_at === null) {
            $updates['cloudflare_proxy_verified_at'] = $now;
        }

        if ($httpsReady && $domain->https_enforced_at === null) {
            $updates['https_enforced_at'] = $now;
        }

        $derivedStatus = match (true) {
            $dnsReady && $sslReady && $proxyReady && $httpsReady => 'active',
            $dnsReady && ! $sslReady => 'ssl_pending',
            $dnsReady => 'dns_verified',
            default => 'pending_verification',
        };
        $requestedStatus = array_key_exists('status', $payload) ? trim((string) $payload['status']) : '';

        if ($requestedStatus !== '') {
            if (! in_array($requestedStatus, self::DOMAIN_STATUSES, true)) {
                return ['error' => 'validation_failed', 'errors' => ['status' => ['The status field is invalid.']]];
            }

            if ($requestedStatus === 'active' && ! ($dnsReady && $sslReady && $proxyReady && $httpsReady)) {
                return ['error' => 'validation_failed', 'errors' => ['status' => ['Active domains require DNS, SSL, Cloudflare proxy, and HTTPS readiness.']]];
            }

            $updates['status'] = $requestedStatus;
        } else {
            $updates['status'] = $derivedStatus;
        }

        if ($updates['status'] === 'active' && $domain->verified_at === null) {
            $updates['verified_at'] = $now;
        }

        return DB::transaction(function () use ($tenantId, $domainId, $domain, $updates, $payload, $actor, $request): array {
            PartnerTenantDomain::query()->forTenant($tenantId)->where('id', $domainId)->update(array_merge($updates, ['updated_at' => now()]));

            $this->audit($actor, $request, 'domain.verification_requested', 'partner_tenant_domain', $domainId, $payload, tenantId: $tenantId, partnerId: (string) $domain->partner_id);

            return ['resource' => $this->findTenantDomain($tenantId, $domainId), 'status' => 202];
        });
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    public function listSyncLogs(?string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $direction = trim((string) ($queryParams['direction'] ?? ''));
        $rows = [];

        if ($direction === '' || $direction === 'outbox') {
            $query = SyncOutbox::query()->orderByDesc('created_at')->orderByDesc('id');

            if ($tenantId !== null) {
                $query->forTenant($tenantId);
            }

            $this->whereString($query, 'status', $queryParams['status'] ?? null);
            $this->applySyncCursor($query, $queryParams['cursor'] ?? null);
            $rows = array_merge($rows, array_map(fn (object $row): array => $this->syncOutboxResource($row), $query->limit($limit + 1)->get()->all()));
        }

        if ($direction === '' || $direction === 'inbox') {
            $query = SyncInbox::query()->orderByDesc('created_at')->orderByDesc('id');

            if ($tenantId !== null) {
                $query->forTenant($tenantId);
            }

            $this->whereString($query, 'status', $queryParams['status'] ?? null);
            $this->applySyncCursor($query, $queryParams['cursor'] ?? null);
            $rows = array_merge($rows, array_map(fn (object $row): array => $this->syncInboxResource($row), $query->limit($limit + 1)->get()->all()));
        }

        usort($rows, fn (array $left, array $right): int => [$right['created_at']?->timestamp ?? 0, $right['id']] <=> [$left['created_at']?->timestamp ?? 0, $left['id']]);

        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);
        $last = $rows === [] ? null : $rows[array_key_last($rows)];

        return [
            'data' => $rows,
            'meta' => [
                'next_cursor' => $hasMore && $last !== null ? $this->syncCursor($last) : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function paginate(Builder $query, array $queryParams, callable $resource): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $cursor = $queryParams['cursor'] ?? null;

        if (is_string($cursor) && trim($cursor) !== '') {
            $query->where($query->getModel()->getTable().'.id', '>', trim($cursor));
        }

        $rows = $query->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map($resource, $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) $rows[array_key_last($rows)]->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $rows
     * @param array<string, mixed> $queryParams
     * @param array<string, mixed> $meta
     * @return array{data: array<int, array<string, mixed>>, meta: array<string, mixed>}
     */
    private function paginateArrayRows(array $rows, array $queryParams, array $meta = []): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $cursor = is_string($queryParams['cursor'] ?? null) ? trim((string) $queryParams['cursor']) : '';

        if ($cursor !== '') {
            $rows = array_values(array_filter($rows, fn (array $row): bool => strcmp((string) ($row['id'] ?? ''), $cursor) > 0));
        }

        $pageRows = array_slice($rows, 0, $limit + 1);
        $hasMore = count($pageRows) > $limit;
        $pageRows = array_slice($pageRows, 0, $limit);

        return [
            'data' => $pageRows,
            'meta' => array_merge($meta, [
                'next_cursor' => $hasMore && $pageRows !== [] ? (string) $pageRows[array_key_last($pageRows)]['id'] : null,
                'has_more' => $hasMore,
            ]),
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function applyMemberSort(Builder $query, array $queryParams): void
    {
        $sortBy = (string) ($queryParams['sort_by'] ?? 'id');
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc';
        $columns = [
            'id' => 'customers.id',
            'customer_no' => 'customers.customer_no',
            'member_no' => 'customers.customer_no',
            'name' => 'customers.name',
            'phone' => 'customers.phone',
            'email' => 'customers.email',
            'status' => 'customers.status',
            'online_status' => 'last_online_at',
            'last_online_at' => 'last_online_at',
            'last_login_at' => 'customers.last_login_at',
            'order_count' => 'order_count_sort',
            'lifetime_spend.amount' => 'lifetime_spend_sort',
            'created_at' => 'customers.created_at',
            'updated_at' => 'customers.updated_at',
        ];
        $column = $columns[$sortBy] ?? 'customers.id';

        $query->reorder($column, $direction);

        if ($column !== 'customers.id') {
            $query->orderBy('customers.id');
        }
    }

    private function whereString(Builder $query, string $column, mixed $value): void
    {
        if (is_string($value) && trim($value) !== '') {
            $query->where($column, trim($value));
        }
    }

    private function limit(mixed $value): int
    {
        $limit = filter_var($value, FILTER_VALIDATE_INT);

        if ($limit === false) {
            return 50;
        }

        return max(1, min(100, $limit));
    }

    /**
     * @return array<string, mixed>
     */
    private function monitoringProfileResource(object $profile): array
    {
        $healthChecks = PartnerHealthCheck::query()
            ->where('partner_id', $profile->partner_id)
            ->orderBy('check_key')
            ->get()
            ->all();

        return [
            'id' => (string) $profile->id,
            'tenant_id' => null,
            'status' => (string) $profile->status,
            'created_at' => $profile->created_at,
            'updated_at' => $profile->updated_at,
            'partner_id' => (string) $profile->partner_id,
            'partner' => $this->partnerSummary($profile->partner ?? null),
            'health_status' => (string) $profile->health_status,
            'checks' => array_map(fn (object $check): array => [
                'id' => (string) $check->id,
                'tenant_id' => $check->tenant_id,
                'check_key' => (string) $check->check_key,
                'health_status' => (string) $check->health_status,
                'checked_at' => $check->checked_at,
            ], $healthChecks),
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    private function usageMeterResource(object $meter, array $queryParams): array
    {
        $summaries = PartnerDailyUsageSummary::query()
            ->where('partner_id', $meter->partner_id)
            ->when(is_string($queryParams['date_from'] ?? null) && trim((string) $queryParams['date_from']) !== '', function (Builder $query) use ($queryParams): void {
                $query->whereDate('usage_date', '>=', (string) $queryParams['date_from']);
            })
            ->when(is_string($queryParams['date_to'] ?? null) && trim((string) $queryParams['date_to']) !== '', function (Builder $query) use ($queryParams): void {
                $query->whereDate('usage_date', '<=', (string) $queryParams['date_to']);
            })
            ->orderByDesc('usage_date')
            ->limit(7)
            ->get()
            ->all();

        return [
            'id' => (string) $meter->id,
            'tenant_id' => null,
            'status' => (string) $meter->status,
            'created_at' => $meter->created_at,
            'updated_at' => $meter->updated_at,
            'partner_id' => (string) $meter->partner_id,
            'partner' => $this->partnerSummary($meter->partner ?? null),
            'meter_key' => (string) $meter->meter_key,
            'value' => (int) $meter->value,
            'limit_value' => $meter->limit_value === null ? null : (int) $meter->limit_value,
            'recent_summaries' => array_map(fn (object $row): array => $this->dailyUsageResource($row), $summaries),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function billingPlanResource(object $plan): array
    {
        return [
            'id' => (string) $plan->id,
            'tenant_id' => null,
            'status' => (string) $plan->status,
            'created_at' => $plan->created_at,
            'updated_at' => $plan->updated_at,
            'code' => (string) $plan->code,
            'name' => (string) $plan->name,
            'monthly_fee' => [
                'amount' => (int) $plan->monthly_fee_amount,
                'currency' => (string) $plan->currency,
            ],
            'features' => $this->arrayValue($plan->features_json),
            'limits' => $this->arrayValue($plan->limits_json),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function billingBindingResource(object $binding): array
    {
        return [
            'id' => (string) $binding->id,
            'tenant_id' => null,
            'status' => (string) $binding->status,
            'created_at' => $binding->created_at,
            'updated_at' => $binding->updated_at,
            'partner_id' => (string) $binding->partner_id,
            'partner' => $this->partnerSummary($binding->partner ?? null),
            'billing_plan_code' => (string) $binding->billing_plan_code,
            'effective_at' => $binding->effective_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function alertPolicyResource(object $policy): array
    {
        return [
            'id' => (string) $policy->id,
            'tenant_id' => null,
            'status' => (string) $policy->status,
            'created_at' => $policy->created_at,
            'updated_at' => $policy->updated_at,
            'partner_id' => (string) $policy->partner_id,
            'partner' => $this->partnerSummary($policy->partner ?? null),
            'policy_key' => (string) $policy->policy_key,
            'severity' => (string) $policy->severity,
            'config' => $this->arrayValue($policy->config_json),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function alertEventResource(object $event): array
    {
        return [
            'id' => (string) $event->id,
            'tenant_id' => $event->tenant_id,
            'status' => (string) $event->status,
            'created_at' => $event->created_at,
            'updated_at' => $event->updated_at,
            'partner_id' => (string) $event->partner_id,
            'partner' => $this->partnerSummary($event->partner ?? null),
            'alert_policy_id' => $event->alert_policy_id,
            'policy_key' => (string) $event->policy_key,
            'severity' => (string) $event->severity,
            'channel' => (string) $event->channel,
            'title' => (string) $event->title,
            'message' => $event->message,
            'labels' => $this->arrayValue($event->labels_json),
            'payload' => $this->auditLogger->redactPayload($this->arrayValue($event->payload_redacted_json)),
            'dry_run' => (bool) $event->dry_run,
            'triggered_at' => $event->triggered_at,
            'delivered_at' => $event->delivered_at,
        ];
    }

    /**
     * @param array<int, object> $rows
     * @return array<string, mixed>
     */
    private function systemSettingsResource(array $rows): array
    {
        $settings = [];
        $createdAt = null;
        $updatedAt = null;

        foreach ($rows as $row) {
            $settings[(string) $row->key] = $row->value_json;
            $createdAt ??= $row->created_at;
            $updatedAt = $row->updated_at;
        }

        return [
            'id' => 'platform_system_settings',
            'tenant_id' => null,
            'status' => 'active',
            'created_at' => $createdAt,
            'updated_at' => $updatedAt,
            'settings' => $settings,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function webhookLogResource(object $log): array
    {
        return [
            'id' => (string) $log->id,
            'tenant_id' => null,
            'status' => (string) $log->status,
            'created_at' => $log->created_at,
            'updated_at' => $log->updated_at,
            'domain' => (string) $log->domain,
            'provider' => (string) $log->provider,
            'callback_key' => (string) $log->callback_key,
            'payload_hash' => (string) $log->payload_hash,
            'payment_id' => $log->payment_id,
            'topup_request_id' => $log->topup_request_id,
            'payload' => $this->auditLogger->redactPayload($this->arrayValue($log->payload_json)),
            'response' => $this->auditLogger->redactPayload($this->arrayValue($log->response_json)),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function priceRuleResource(object $rule): array
    {
        $adjustmentAmount = (int) ($rule->adjustment_amount ?? $rule->price_amount ?? 0);
        $adjustmentBps = $rule->adjustment_bps === null ? null : (int) $rule->adjustment_bps;
        $currency = (string) $rule->currency;
        $preview = $this->rewardPriceRules->previewRule($rule);

        return [
            'id' => (string) $rule->id,
            'tenant_id' => (string) $rule->tenant_id,
            'status' => (string) $rule->status,
            'created_at' => $rule->created_at,
            'updated_at' => $rule->updated_at,
            'game_id' => $rule->game_id,
            'code' => (string) $rule->code,
            'name' => (string) $rule->name,
            'rule_type' => (string) $rule->rule_type,
            'base_source' => (string) ($rule->base_source ?? TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD),
            'price' => [
                'amount' => $adjustmentAmount,
                'currency' => $currency,
            ],
            'adjustment' => [
                'amount' => $adjustmentAmount,
                'currency' => $currency,
                'bps' => $adjustmentBps,
            ],
            'conditions' => $this->arrayValue($rule->conditions_json),
            'reward_preview' => $preview,
            'reporting' => [
                'base_source' => TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD,
                'snapshot_fields' => ['base_prize_amount', 'adjustment_amount', 'prize_amount', 'tenant_price_rule_id', 'price_rule_snapshot'],
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function priceRuleGameResource(object $game, ?string $defaultGameId): array
    {
        $code = (string) ($game->code ?? '');
        $name = (string) ($game->name ?? $game->id);
        $status = (string) $game->status;

        return [
            'id' => (string) $game->id,
            'game_id' => (string) $game->id,
            'code' => $code,
            'name' => $name,
            'label' => trim(($code !== '' ? $code.' - ' : '').$name).($status === 'open' ? ' (Current)' : ''),
            'status' => $status,
            'is_current' => $status === 'open',
            'is_default' => $defaultGameId !== null && (string) $game->id === $defaultGameId,
            'sale_start_at' => $game->sale_start_at,
            'draw_at' => $game->draw_at,
            'close_at' => $game->close_at,
        ];
    }

    private function latestOpenPriceRuleGameId(): ?string
    {
        $id = Game::query()
            ->where('status', 'open')
            ->orderByDesc('draw_at')
            ->value('id');

        return $id === null ? null : (string) $id;
    }

    /**
     * @return array<string, mixed>
     */
    private function tenantDomainResource(object $domain): array
    {
        return [
            'id' => (string) $domain->id,
            'tenant_id' => (string) $domain->tenant_id,
            'status' => (string) $domain->status,
            'created_at' => $domain->created_at,
            'updated_at' => $domain->updated_at,
            'partner_id' => (string) $domain->partner_id,
            'partner' => $this->partnerSummary($domain->partner ?? null),
            'host' => (string) $domain->host,
            'type' => (string) $domain->type,
            'is_primary' => (bool) $domain->is_primary,
            'verified_at' => $domain->verified_at,
            'ssl_ready_at' => $domain->ssl_ready_at,
            'dns_verified_at' => $domain->dns_verified_at,
            'cloudflare_proxy_verified_at' => $domain->cloudflare_proxy_verified_at,
            'https_enforced_at' => $domain->https_enforced_at,
            'cloudflare_readiness_checked_at' => $domain->cloudflare_readiness_checked_at,
            'readiness' => [
                'dns_verified' => $domain->dns_verified_at !== null,
                'ssl_ready' => $domain->ssl_ready_at !== null,
                'cloudflare_proxy_verified' => $domain->cloudflare_proxy_verified_at !== null,
                'https_enforced' => $domain->https_enforced_at !== null,
                'local_only' => $this->isLocalOnlyHost((string) $domain->host),
            ],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function syncOutboxResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => $row->tenant_id,
            'status' => (string) $row->status,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
            'direction' => 'outbox',
            'event_id' => (string) $row->event_id,
            'event_type' => (string) $row->event_type,
            'event_version' => (int) $row->event_version,
            'producer' => (string) $row->producer,
            'consumer' => null,
            'partner_id' => $row->partner_id,
            'game_id' => $row->game_id,
            'aggregate_type' => $row->aggregate_type,
            'aggregate_id' => $row->aggregate_id,
            'attempt_count' => (int) $row->attempt_count,
            'available_at' => $row->available_at,
            'processed_at' => $row->processed_at,
            'last_error' => $row->last_error,
            'payload' => $this->auditLogger->redactPayload($this->arrayValue($row->payload_json)),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function syncInboxResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => $row->tenant_id,
            'status' => (string) $row->status,
            'created_at' => $row->created_at,
            'updated_at' => $row->updated_at,
            'direction' => 'inbox',
            'event_id' => (string) $row->event_id,
            'event_type' => (string) $row->event_type,
            'event_version' => (int) $row->event_version,
            'producer' => null,
            'consumer' => (string) $row->consumer,
            'partner_id' => $row->partner_id,
            'game_id' => $row->game_id,
            'aggregate_type' => null,
            'aggregate_id' => null,
            'attempt_count' => null,
            'available_at' => null,
            'processed_at' => $row->processed_at,
            'last_error' => $row->last_error,
            'payload_hash' => $row->payload_hash,
            'payload' => [],
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function memberResource(object $member): array
    {
        $wallets = $member->relationLoaded('wallets') ? $member->wallets : Wallet::query()->forTenant((string) $member->tenant_id)->where('customer_id', $member->id)->get();
        $orderCount = Order::query()->forTenant((string) $member->tenant_id)->where('customer_id', $member->id)->count();
        $lifetimeSpend = (int) Order::query()
            ->forTenant((string) $member->tenant_id)
            ->where('customer_id', $member->id)
            ->where('status', 'paid')
            ->sum('total_amount');
        $onlineCutoff = now()->subMinutes(2);
        $lastOnlineAt = $member->last_online_at ?? CustomerAuthSession::query()
            ->forTenant((string) $member->tenant_id)
            ->where('customer_id', $member->id)
            ->max('last_used_at');
        $isOnline = CustomerAuthSession::query()
            ->forTenant((string) $member->tenant_id)
            ->where('customer_id', $member->id)
            ->whereNull('revoked_at')
            ->where('access_expires_at', '>', now())
            ->where('last_used_at', '>=', $onlineCutoff)
            ->exists();

        return [
            'id' => (string) $member->id,
            'tenant_id' => (string) $member->tenant_id,
            'customer_no' => CustomerNo::display($member->customer_no ?? null, (string) $member->id),
            'member_no' => CustomerNo::display($member->customer_no ?? null, (string) $member->id),
            'name' => (string) $member->name,
            'phone' => (string) $member->phone,
            'email' => $member->email,
            'status' => (string) $member->status,
            'is_online' => $isOnline,
            'online_status' => $isOnline ? 'online' : 'offline',
            'last_online_at' => $lastOnlineAt,
            'wallets' => collect($wallets)->map(fn (object $wallet): array => [
                'id' => (string) $wallet->id,
                'tenant_id' => (string) $wallet->tenant_id,
                'customer_id' => (string) $wallet->customer_id,
                'status' => (string) $wallet->status,
                'balance' => [
                    'amount' => (int) $wallet->balance_amount,
                    'currency' => (string) $wallet->currency,
                ],
            ])->values()->all(),
            'order_count' => $orderCount,
            'lifetime_spend' => [
                'amount' => $lifetimeSpend,
                'currency' => 'THB',
            ],
            'last_login_at' => $member->last_login_at,
            'created_at' => $member->created_at,
            'updated_at' => $member->updated_at,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function dailyUsageResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => $row->tenant_id,
            'partner_id' => (string) $row->partner_id,
            'usage_date' => (string) $row->usage_date,
            'api_request_count' => (int) $row->api_request_count,
            'booking_request_count' => (int) $row->booking_request_count,
            'checkout_request_count' => (int) $row->checkout_request_count,
            'order_count' => (int) $row->order_count,
            'sold_ticket_count' => (int) $row->sold_ticket_count,
            'image_bandwidth_gb' => (float) $row->image_bandwidth_gb,
            'storage_gb' => (float) $row->storage_gb,
            'queue_job_count' => (int) $row->queue_job_count,
            'rate_limited_count' => (int) $row->rate_limited_count,
            'error_count' => (int) $row->error_count,
            'sync_event_count' => (int) $row->sync_event_count,
            'labels' => $this->arrayValue($row->labels_json),
        ];
    }

    /**
     * @param array<int, object> $rows
     * @return array<string, int|float>
     */
    private function usageTotals(array $rows): array
    {
        $totals = [
            'api_request_count' => 0,
            'booking_request_count' => 0,
            'checkout_request_count' => 0,
            'order_count' => 0,
            'sold_ticket_count' => 0,
            'image_bandwidth_gb' => 0.0,
            'storage_gb' => 0.0,
            'queue_job_count' => 0,
            'rate_limited_count' => 0,
            'error_count' => 0,
            'sync_event_count' => 0,
        ];

        foreach ($rows as $row) {
            foreach ($totals as $key => $value) {
                $totals[$key] = $value + ($key === 'image_bandwidth_gb' || $key === 'storage_gb' ? (float) $row->{$key} : (int) $row->{$key});
            }
        }

        return $totals;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function partnerSummary(?object $partner): ?array
    {
        if ($partner === null) {
            return null;
        }

        return [
            'id' => (string) $partner->id,
            'code' => (string) $partner->code,
            'name' => (string) $partner->name,
            'status' => (string) $partner->status,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function billingPlanPayload(array $payload, bool $creating): array
    {
        $name = trim((string) ($payload['name'] ?? ''));
        $code = trim((string) ($payload['code'] ?? ''));

        if ($creating && $name === '' && $code !== '') {
            $name = str($code)->replace(['_', '-'], ' ')->title()->toString();
        }

        if ($creating && $code === '') {
            $code = $name !== '' ? Str::slug($name, '_') : 'plan_'.strtolower(Str::ulid()->toBase32());
        }

        $updates = [];

        foreach (['code' => $code, 'name' => $name] as $key => $value) {
            if ($creating || array_key_exists($key, $payload)) {
                $updates[$key] = $value;
            }
        }

        if ($creating || array_key_exists('status', $payload)) {
            $updates['status'] = trim((string) ($payload['status'] ?? 'active'));
        }

        if ($creating || array_key_exists('monthly_fee_amount', $payload)) {
            $updates['monthly_fee_amount'] = max(0, (int) ($payload['monthly_fee_amount'] ?? 0));
        }

        if ($creating || array_key_exists('currency', $payload)) {
            $updates['currency'] = strtoupper(trim((string) ($payload['currency'] ?? 'THB'))) ?: 'THB';
        }

        if ($creating || array_key_exists('features', $payload)) {
            $updates['features_json'] = $payload['features'] ?? [];
        }

        if ($creating || array_key_exists('limits', $payload)) {
            $updates['limits_json'] = $payload['limits'] ?? [];
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function billingPlanErrors(array $payload, bool $creating = true): array
    {
        $errors = [];

        if (($creating || array_key_exists('code', $payload)) && ($payload['code'] ?? '') === '') {
            $errors['code'][] = 'The code field is required.';
        }

        if (($creating || array_key_exists('name', $payload)) && ($payload['name'] ?? '') === '') {
            $errors['name'][] = 'The name field is required.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::ACTIVE_ARCHIVE_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('currency', $payload) && strlen((string) $payload['currency']) !== 3) {
            $errors['currency'][] = 'The currency field must be a 3-letter code.';
        }

        foreach (['features_json', 'limits_json'] as $field) {
            if (array_key_exists($field, $payload) && ! is_array($payload[$field])) {
                $errors[$field][] = 'The '.$field.' field must be an object or array.';
            }
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function alertPolicyPayload(array $payload, bool $creating): array
    {
        $updates = [];

        foreach (['partner_id', 'policy_key', 'status', 'severity'] as $field) {
            if ($creating || array_key_exists($field, $payload)) {
                $updates[$field] = trim((string) ($payload[$field] ?? match ($field) {
                    'status' => 'active',
                    'severity' => 'warning',
                    default => '',
                }));
            }
        }

        if ($creating || array_key_exists('config', $payload)) {
            $updates['config_json'] = $payload['config'] ?? [];
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function alertPolicyErrors(array $payload, bool $creating, ?string $existingPartnerId = null): array
    {
        $errors = [];
        $partnerId = $payload['partner_id'] ?? $existingPartnerId;

        if (($partnerId ?? '') === '' || Partner::query()->where('id', $partnerId)->doesntExist()) {
            $errors['partner_id'][] = 'The partner_id field must reference an existing partner.';
        }

        if (($payload['policy_key'] ?? ($creating ? '' : 'existing')) === '') {
            $errors['policy_key'][] = 'The policy_key field is required.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::ACTIVE_PAUSED_ARCHIVED_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('config_json', $payload) && ! is_array($payload['config_json'])) {
            $errors['config'][] = 'The config field must be an object or array.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function priceRulePayload(string $tenantId, array $payload, bool $creating): array
    {
        $name = trim((string) ($payload['name'] ?? ''));
        $code = trim((string) ($payload['code'] ?? ''));

        if ($creating && $name === '' && $code !== '') {
            $name = str($code)->replace(['_', '-'], ' ')->title()->toString();
        }

        if ($creating && $code === '') {
            $code = $name !== '' ? Str::slug($name, '_') : 'price_'.strtolower(Str::ulid()->toBase32());
        }

        $updates = [];

        foreach (['code' => $code, 'name' => $name] as $key => $value) {
            if ($creating || array_key_exists($key, $payload)) {
                $updates[$key] = $value;
            }
        }

        foreach (['game_id', 'rule_type', 'base_source', 'status', 'currency'] as $field) {
            if ($creating || array_key_exists($field, $payload)) {
                $updates[$field] = match ($field) {
                    'game_id' => trim((string) ($payload[$field] ?? '')) ?: null,
                    'rule_type' => trim((string) ($payload[$field] ?? TenantRewardPriceRuleService::RULE_TYPE_AMOUNT_DELTA)),
                    'base_source' => trim((string) ($payload[$field] ?? TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD)),
                    'status' => trim((string) ($payload[$field] ?? 'active')),
                    'currency' => strtoupper(trim((string) ($payload[$field] ?? 'THB'))) ?: 'THB',
                };
            }
        }

        if ($creating || array_key_exists('adjustment_amount', $payload) || array_key_exists('price_amount', $payload)) {
            $adjustmentAmount = (int) ($payload['adjustment_amount'] ?? $payload['price_amount'] ?? $payload['amount'] ?? 0);
            $updates['adjustment_amount'] = $adjustmentAmount;
            $updates['price_amount'] = max(0, abs($adjustmentAmount));
        }

        if ($creating || array_key_exists('adjustment_bps', $payload)) {
            $updates['adjustment_bps'] = ($payload['adjustment_bps'] ?? null) === null || $payload['adjustment_bps'] === ''
                ? null
                : (int) $payload['adjustment_bps'];
        }

        if ($creating || array_key_exists('conditions', $payload)) {
            $updates['conditions_json'] = $payload['conditions'] ?? [];
        }

        $updates['tenant_id'] = $tenantId;

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function priceRuleErrors(string $tenantId, array $payload, bool $creating = true): array
    {
        $errors = [];

        if (($payload['tenant_id'] ?? $tenantId) !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the active tenant.';
        }

        if (($creating || array_key_exists('code', $payload)) && ($payload['code'] ?? '') === '') {
            $errors['code'][] = 'The code field is required.';
        }

        if (($creating || array_key_exists('name', $payload)) && ($payload['name'] ?? '') === '') {
            $errors['name'][] = 'The name field is required.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::ACTIVE_ARCHIVE_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (array_key_exists('game_id', $payload) && $payload['game_id'] !== null && trim((string) $payload['game_id']) !== '' && ! Game::whereKey((string) $payload['game_id'])->exists()) {
            $errors['game_id'][] = 'The game_id field must reference an existing game.';
        }

        if (array_key_exists('base_source', $payload) && $payload['base_source'] !== TenantRewardPriceRuleService::BASE_SOURCE_CENTRAL_REWARD) {
            $errors['base_source'][] = 'The base_source field must be central_reward.';
        }

        if (array_key_exists('rule_type', $payload) && ! in_array($payload['rule_type'], [TenantRewardPriceRuleService::RULE_TYPE_AMOUNT_DELTA, TenantRewardPriceRuleService::RULE_TYPE_PERCENT_DELTA, 'fixed_price'], true)) {
            $errors['rule_type'][] = 'The rule_type field must be a reward adjustment type.';
        }

        if (array_key_exists('conditions_json', $payload) && ! is_array($payload['conditions_json'])) {
            $errors['conditions'][] = 'The conditions field must be an object or array.';
        }

        return $this->mergeFieldErrors($errors, $this->rewardPriceRules->validateRulePayload($payload));
    }

    /**
     * @param array<string, array<int, string>> $base
     * @param array<string, array<int, string>> $extra
     * @return array<string, array<int, string>>
     */
    private function mergeFieldErrors(array $base, array $extra): array
    {
        foreach ($extra as $field => $messages) {
            $base[$field] = array_values(array_merge($base[$field] ?? [], $messages));
        }

        return $base;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function tenantDomainPayload(string $tenantId, string $partnerId, array $payload, bool $creating, ?object $existing = null): array
    {
        $updates = [];

        if ($creating || array_key_exists('host', $payload)) {
            $updates['host'] = $this->normalizeHost($payload['host'] ?? '');
        }

        if ($creating || array_key_exists('type', $payload)) {
            $updates['type'] = trim((string) ($payload['type'] ?? 'custom_domain')) ?: 'custom_domain';
        }

        if ($creating || array_key_exists('status', $payload)) {
            $updates['status'] = trim((string) ($payload['status'] ?? 'pending_verification')) ?: 'pending_verification';
        }

        if ($creating || array_key_exists('is_primary', $payload)) {
            $updates['is_primary'] = filter_var($payload['is_primary'] ?? false, FILTER_VALIDATE_BOOLEAN, FILTER_NULL_ON_FAILURE) ?? false;
        }

        $updates['tenant_id'] = $tenantId;
        $updates['partner_id'] = $partnerId;

        if ($creating && $this->isLocalOnlyHost($updates['host'] ?? '')) {
            $updates['dns_verified_at'] = now();
            $updates['ssl_ready_at'] = now();
            $updates['cloudflare_proxy_verified_at'] = now();
            $updates['https_enforced_at'] = now();
            $updates['cloudflare_readiness_checked_at'] = now();
            $updates['verified_at'] = now();
            $updates['status'] = $payload['status'] ?? 'active';
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function tenantDomainErrors(string $tenantId, array $payload, bool $creating, ?object $existing = null): array
    {
        $errors = [];
        $host = $payload['host'] ?? $existing?->host;

        if (($payload['tenant_id'] ?? $tenantId) !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the active tenant.';
        }

        if (($payload['partner_id'] ?? $existing?->partner_id ?? '') === '') {
            $errors['partner_id'][] = 'The partner_id field is required.';
        }

        if (($creating || array_key_exists('host', $payload)) && ! $this->validHost((string) $host)) {
            $errors['host'][] = 'The host field must be a valid lowercase hostname.';
        }

        if (array_key_exists('type', $payload) && ! in_array($payload['type'], self::DOMAIN_TYPES, true)) {
            $errors['type'][] = 'The type field is invalid.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::DOMAIN_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        if (($payload['status'] ?? null) === 'active' && ! $this->domainCanBeActive((string) $host, $payload, $existing)) {
            $errors['status'][] = 'Active domains require DNS, SSL, Cloudflare proxy, and HTTPS readiness.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function memberPayload(string $tenantId, array $payload, bool $creating): array
    {
        $updates = [];

        foreach (['name', 'phone', 'email'] as $field) {
            if ($creating || array_key_exists($field, $payload)) {
                $value = $payload[$field] ?? null;
                $updates[$field] = $value === null ? null : trim((string) $value);
            }
        }

        if ($creating || array_key_exists('status', $payload)) {
            $updates['status'] = trim((string) ($payload['status'] ?? 'active'));
        }

        if (array_key_exists('password', $payload) && trim((string) $payload['password']) !== '') {
            $updates['password_hash'] = Hash::make((string) $payload['password']);
        }

        $updates['tenant_id'] = $tenantId;

        return $updates;
    }

    private function newCustomerNo(string $tenantId): string
    {
        $tenantCode = PartnerTenant::query()->where('id', $tenantId)->value('code');

        do {
            $customerNo = CustomerNo::generate(is_string($tenantCode) ? $tenantCode : null, $tenantId);
        } while (Customer::query()->where('customer_no', $customerNo)->exists());

        return $customerNo;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function memberErrors(string $tenantId, array $payload, bool $creating): array
    {
        $errors = [];

        if (($payload['tenant_id'] ?? $tenantId) !== $tenantId) {
            $errors['tenant_id'][] = 'The tenant_id field must match the active tenant.';
        }

        if ($creating && trim((string) ($payload['name'] ?? '')) === '') {
            $errors['name'][] = 'The name field is required.';
        }

        if ($creating && trim((string) ($payload['phone'] ?? '')) === '') {
            $errors['phone'][] = 'The phone field is required.';
        }

        if (($payload['email'] ?? null) !== null && $payload['email'] !== '' && filter_var((string) $payload['email'], FILTER_VALIDATE_EMAIL) === false) {
            $errors['email'][] = 'The email field must be a valid email address.';
        }

        if (array_key_exists('status', $payload) && ! in_array($payload['status'], self::MEMBER_STATUSES, true)) {
            $errors['status'][] = 'The status field is invalid.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function systemSettingUpdates(array $payload): array
    {
        $raw = is_array($payload['settings'] ?? null) ? $payload['settings'] : $payload;
        $settings = [];

        foreach ($raw as $key => $value) {
            $normalizedKey = trim((string) $key);

            if ($normalizedKey === '' || in_array($normalizedKey, ['id', 'tenant_id', 'status', 'created_at', 'updated_at'], true)) {
                continue;
            }

            $settings[$normalizedKey] = $value;
        }

        return $settings;
    }

    private function normalizeHost(mixed $value): string
    {
        return TenantHostNormalizer::normalize((string) $value);
    }

    private function validHost(string $host): bool
    {
        if ($host === 'localhost') {
            return true;
        }

        if (filter_var($host, FILTER_VALIDATE_IP) !== false) {
            return true;
        }

        if (strlen($host) > 253 || ! str_contains($host, '.')) {
            return false;
        }

        return preg_match('/^(?=.{1,253}$)([a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?\.)+[a-z0-9](?:[a-z0-9-]{0,61}[a-z0-9])?$/', $host) === 1;
    }

    private function isLocalOnlyHost(string $host): bool
    {
        return $host === 'localhost'
            || str_ends_with($host, '.localhost')
            || str_ends_with($host, '.test')
            || str_ends_with($host, '.local')
            || str_starts_with($host, '127.')
            || str_starts_with($host, '10.')
            || str_starts_with($host, '192.168.');
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function domainCanBeActive(string $host, array $payload, ?object $existing): bool
    {
        if ($this->isLocalOnlyHost($host)) {
            return true;
        }

        return ($existing?->dns_verified_at !== null || array_key_exists('dns_verified_at', $payload) || $this->truthyPayload($payload, ['dns_verified', 'dns_ready']))
            && ($existing?->ssl_ready_at !== null || array_key_exists('ssl_ready_at', $payload) || $this->truthyPayload($payload, ['ssl_ready', 'https_ready']))
            && ($existing?->cloudflare_proxy_verified_at !== null || array_key_exists('cloudflare_proxy_verified_at', $payload) || $this->truthyPayload($payload, ['cloudflare_proxy_verified', 'proxy_verified']))
            && ($existing?->https_enforced_at !== null || array_key_exists('https_enforced_at', $payload) || $this->truthyPayload($payload, ['https_enforced']));
    }

    /**
     * @param array<string, mixed> $payload
     * @param array<int, string> $keys
     */
    private function truthyPayload(array $payload, array $keys): bool
    {
        foreach ($keys as $key) {
            if (! array_key_exists($key, $payload)) {
                continue;
            }

            $value = $payload[$key];

            if (is_bool($value)) {
                return $value;
            }

            if (is_numeric($value)) {
                return ((int) $value) === 1;
            }

            if (in_array(strtolower(trim((string) $value)), ['1', 'true', 'yes', 'verified', 'ready', 'active'], true)) {
                return true;
            }
        }

        return false;
    }

    private function applySyncCursor(Builder $query, mixed $cursor): void
    {
        if (! is_string($cursor) || trim($cursor) === '') {
            return;
        }

        $parts = explode('|', trim($cursor), 3);

        if (count($parts) !== 3) {
            return;
        }

        try {
            $createdAt = Carbon::parse($parts[0]);
        } catch (\Throwable) {
            return;
        }

        $id = $parts[2];

        $query->where(function (Builder $nested) use ($createdAt, $id): void {
            $nested->where('created_at', '<', $createdAt)
                ->orWhere(function (Builder $sameTimestamp) use ($createdAt, $id): void {
                    $sameTimestamp->where('created_at', '=', $createdAt)->where('id', '<', $id);
                });
        });
    }

    /**
     * @param array<string, mixed> $row
     */
    private function syncCursor(array $row): string
    {
        $createdAt = $row['created_at'];
        $timestamp = $createdAt instanceof Carbon ? $createdAt->toISOString() : (string) $createdAt;

        return $timestamp.'|'.$row['direction'].'|'.$row['id'];
    }

    private function ensureDefaultSystemSettings(): void
    {
        foreach ([
            'platform_name' => 'NewPaotang',
            'admin_api_version' => 'v1',
            'bo_menu_completion_backend_gaps' => 'implemented',
            'waiting_result_youtube_url' => '',
        ] as $key => $value) {
            PlatformSystemSetting::query()->firstOrCreate(
                ['key' => $key],
                [
                    'id' => $this->stableId('pss', $key),
                    'value_json' => $value,
                    'status' => 'active',
                    'created_at' => now(),
                    'updated_at' => now(),
                ],
            );
        }
    }

    private function centralWaitingResultYoutubeUrl(): string
    {
        $value = PlatformSystemSetting::query()
            ->where('key', 'waiting_result_youtube_url')
            ->where('status', 'active')
            ->first()
            ?->value_json;

        return is_string($value) ? trim($value) : '';
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function liveSettingsPayloadValue(array $payload): ?string
    {
        $settings = is_array($payload['settings'] ?? null) ? $payload['settings'] : [];
        $live = is_array($payload['live'] ?? null) ? $payload['live'] : [];

        foreach (['waiting_result_youtube_url', 'youtube_live_url'] as $key) {
            if (array_key_exists($key, $settings)) {
                return is_scalar($settings[$key]) || $settings[$key] === null ? (string) ($settings[$key] ?? '') : null;
            }

            if (array_key_exists($key, $live)) {
                return is_scalar($live[$key]) || $live[$key] === null ? (string) ($live[$key] ?? '') : null;
            }

            if (array_key_exists($key, $payload)) {
                return is_scalar($payload[$key]) || $payload[$key] === null ? (string) ($payload[$key] ?? '') : null;
            }
        }

        return null;
    }

    private function ensureTenantSettingsForLiveSettings(string $tenantId): ?PartnerTenantSetting
    {
        $tenant = PartnerTenant::query()->whereKey($tenantId)->first();

        if ($tenant === null) {
            return null;
        }

        $settings = PartnerTenantSetting::query()
            ->where('tenant_id', $tenantId)
            ->lockForUpdate()
            ->first();

        if ($settings !== null) {
            return $settings;
        }

        $now = now();
        PartnerTenantSetting::query()->create([
            'id' => $this->stableId('pts', $tenantId),
            'tenant_id' => $tenantId,
            'site_name' => (string) $tenant->name,
            'display_name' => null,
            'locale' => 'th-TH',
            'timezone' => 'Asia/Bangkok',
            'support_email' => null,
            'support_phone' => null,
            'default_title' => (string) $tenant->name,
            'title_template' => null,
            'default_description' => null,
            'default_keywords_json' => json_encode([], JSON_THROW_ON_ERROR),
            'robots_default' => 'index,follow',
            'sitemap_enabled' => true,
            'robots_enabled' => true,
            'maintenance_active' => false,
            'maintenance_mode' => null,
            'maintenance_message' => null,
            'maintenance_expected_end_at' => null,
            'maintenance_retry_after_seconds' => null,
            'maintenance_allowed_routes_json' => json_encode([], JSON_THROW_ON_ERROR),
            'maintenance_blocked_route_patterns_json' => json_encode([], JSON_THROW_ON_ERROR),
            'api_base_url' => '/api/v1',
            'realtime_url' => null,
            'asset_cdn_base_url' => null,
            'waiting_result_youtube_url' => null,
            'config_version' => 1,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return PartnerTenantSetting::query()->where('tenant_id', $tenantId)->first();
    }

    /**
     * @param mixed $value
     * @return array<string|int, mixed>
     */
    private function arrayValue(mixed $value): array
    {
        if (is_array($value)) {
            return $value;
        }

        if (is_string($value) && $value !== '') {
            $decoded = json_decode($value, true);

            return is_array($decoded) ? $decoded : [];
        }

        return [];
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(
        AdminSessionContext $actor,
        Request $request,
        string $action,
        string $targetType,
        ?string $targetId,
        array $payload,
        ?string $tenantId = null,
        ?string $partnerId = null,
    ): void {
        $this->auditLogger->logAdminWrite(
            actorId: (string) $actor->adminUser['id'],
            scopeType: $actor->activeScope(),
            action: $action,
            targetType: $targetType,
            targetId: $targetId,
            payload: $payload,
            tenantId: $tenantId,
            partnerId: $partnerId,
            requestId: $request->header('X-Request-Id'),
            ipAddress: $request->ip(),
            userAgent: $request->userAgent(),
        );
    }
}
