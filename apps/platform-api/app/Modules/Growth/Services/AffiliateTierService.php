<?php

namespace App\Modules\Growth\Services;

use App\Models\AffiliateAccount;
use App\Models\AffiliateLink;
use App\Models\AffiliateProgram;
use App\Models\AffiliateStoreNameClaim;
use App\Models\AffiliateStoreNameRequest;
use App\Models\AffiliateTierCampaign;
use App\Models\AffiliateTierCampaignResult;
use App\Models\AffiliateTierCampaignRule;
use App\Models\AffiliateTierCampaignStat;
use App\Models\AffiliateTierHistory;
use App\Models\AffiliateTierRateHistory;
use App\Models\CommissionRule;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Collection;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

class AffiliateTierService
{
    private const CAMPAIGN_TYPES = ['fixed_threshold', 'ranking'];
    private const MUTABLE_CAMPAIGN_STATUSES = ['draft', 'scheduled'];
    private const TIER_CODES = ['bronze', 'silver', 'gold', 'platinum', 'diamond'];

    /**
     * @var array<string, array{name: string, rank: int, commission: int, minimum_payout: int}>
     */
    private const DEFAULT_TIERS = [
        'bronze' => ['name' => 'Bronze', 'rank' => 1, 'commission' => 100, 'minimum_payout' => 30000],
        'silver' => ['name' => 'Silver', 'rank' => 2, 'commission' => 150, 'minimum_payout' => 25000],
        'gold' => ['name' => 'Gold', 'rank' => 3, 'commission' => 200, 'minimum_payout' => 20000],
        'platinum' => ['name' => 'Platinum', 'rank' => 4, 'commission' => 250, 'minimum_payout' => 15000],
        'diamond' => ['name' => 'Diamond', 'rank' => 5, 'commission' => 300, 'minimum_payout' => 10000],
    ];

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly CustomerNotificationDomainEventService $notifications,
    ) {
    }

    /**
     * @return array<string, AffiliateProgram>
     */
    public function ensureTenantTiers(string $tenantId): array
    {
        return DB::transaction(function () use ($tenantId): array {
            $this->lockTenantAffiliateConfiguration($tenantId);
            $now = now();
            $programs = [];

            foreach (self::DEFAULT_TIERS as $code => $defaults) {
                $program = AffiliateProgram::query()
                    ->where('tenant_id', $tenantId)
                    ->where('code', $code)
                    ->lockForUpdate()
                    ->first();

                if ($program === null) {
                    $program = AffiliateProgram::query()->create([
                        'id' => $this->stableId('afp', $tenantId.':'.$code),
                        'tenant_id' => $tenantId,
                        'code' => $code,
                        'name' => $defaults['name'],
                        'status' => 'active',
                        'tier_rank' => $defaults['rank'],
                        'minimum_payout_amount' => $defaults['minimum_payout'],
                        'commission_per_ticket_amount' => $defaults['commission'],
                        'metadata_json' => ['system_tier' => true],
                        'created_at' => $now,
                        'updated_at' => $now,
                    ]);
                } elseif ($program->tier_rank === null) {
                    $program->forceFill([
                        'tier_rank' => $defaults['rank'],
                        'commission_per_ticket_amount' => (int) ($program->commission_per_ticket_amount ?: $defaults['commission']),
                        'minimum_payout_amount' => (int) ($program->minimum_payout_amount ?: $defaults['minimum_payout']),
                        'status' => 'active',
                    ])->save();
                }

                $this->syncTierCommissionRule($program);
                $this->ensureTierRateHistory($program);
                $programs[$code] = $program->fresh();
            }

            return $programs;
        });
    }

    public function bronzeProgram(string $tenantId): AffiliateProgram
    {
        return $this->ensureTenantTiers($tenantId)['bronze'];
    }

    /**
     * @return array<string, array<int, string>>
     */
    public function storeNameErrors(string $tenantId, string $name, ?string $affiliateId = null): array
    {
        $displayName = $this->displayStoreName($name);
        $normalized = $this->normalizeStoreName($displayName);
        $errors = [];

        if ($displayName === '') {
            $errors['name'][] = 'The store name field is required for affiliate accounts.';
        } elseif (mb_strlen($displayName, 'UTF-8') > 120) {
            $errors['name'][] = 'The store name field must not be greater than 120 characters.';
        } elseif (preg_match('/\p{C}/u', $displayName) === 1) {
            $errors['name'][] = 'The store name contains unsupported invisible or control characters.';
        }

        if ($normalized !== '') {
            $query = AffiliateStoreNameClaim::query()
                ->where('tenant_id', $tenantId)
                ->where('normalized_name', $normalized);
            if ($affiliateId !== null) {
                $query->where('affiliate_account_id', '!=', $affiliateId);
            }
            if ($query->exists()) {
                $errors['name'][] = 'The store name has already been taken.';
            }
        }

        return $errors;
    }

    public function attachNewAffiliate(AffiliateAccount $affiliate, string $requestedName): bool
    {
        $tenantId = (string) $affiliate->tenant_id;
        $program = $this->bronzeProgram($tenantId);
        $displayName = $this->displayStoreName($requestedName);
        $normalized = $this->normalizeStoreName($displayName);
        $requestId = 'asr_'.Str::ulid()->toBase32();
        $now = now();

        $affiliate->forceFill([
            'affiliate_program_id' => $program->id,
            'name' => $displayName,
            'store_name_status' => 'pending',
            'store_name_normalized' => null,
            'store_name_approved_at' => null,
            'store_name_change_available_at' => null,
        ])->save();

        AffiliateStoreNameRequest::query()->create([
            'id' => $requestId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate->id,
            'request_type' => 'initial',
            'previous_name' => null,
            'requested_name' => $displayName,
            'normalized_name' => $normalized,
            'status' => 'pending',
            'submitted_at' => $now,
        ]);

        $claimed = DB::table('affiliate_store_name_claims')->insertOrIgnore([
            'id' => 'asn_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate->id,
            'request_id' => $requestId,
            'normalized_name' => $normalized,
            'status' => 'pending',
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        if ($claimed === 1) {
            DB::afterCommit(fn () => $this->notifications->affiliateStoreNameSubmitted(
                $tenantId,
                (string) $affiliate->id,
                $requestId,
                'initial',
            ));

            return true;
        }

        AffiliateStoreNameRequest::query()->whereKey($requestId)->delete();
        $affiliate->delete();

        return false;
    }

    /**
     * @return array<string, mixed>
     */
    public function overviewResource(AffiliateAccount $affiliate): array
    {
        $program = $this->currentProgram($affiliate);
        $pending = AffiliateStoreNameRequest::query()
            ->where('tenant_id', $affiliate->tenant_id)
            ->where('affiliate_account_id', $affiliate->id)
            ->where('status', 'pending')
            ->latest('submitted_at')
            ->first();
        $recent = AffiliateStoreNameRequest::query()
            ->where('tenant_id', $affiliate->tenant_id)
            ->where('affiliate_account_id', $affiliate->id)
            ->latest('submitted_at')
            ->first();

        return [
            'tier' => $this->tierResource($program),
            'store_name' => [
                'status' => (string) ($affiliate->store_name_status ?: 'approved'),
                'approved_name' => $affiliate->store_name_approved_at === null ? null : (string) $affiliate->name,
                'pending_name' => $pending?->requested_name,
                'pending_request_id' => $pending?->id,
                'admin_note' => $recent?->status === 'rejected' ? $recent->admin_note : null,
                'approved_at' => $affiliate->store_name_approved_at?->toIso8601String(),
                'change_available_at' => $affiliate->store_name_change_available_at?->toIso8601String(),
                'can_request_change' => $pending === null && (
                    $affiliate->store_name_approved_at === null
                    || $affiliate->store_name_change_available_at === null
                    || $affiliate->store_name_change_available_at->lte(now())
                ),
            ],
            'campaigns' => $this->customerCampaigns((string) $affiliate->tenant_id, (string) $affiliate->id),
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function requestStoreNameChange(string $tenantId, string $customerId, array $payload): array
    {
        $affiliate = AffiliateAccount::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->lockForUpdate()
            ->first();
        if ($affiliate === null) {
            return ['error' => 'not_found'];
        }

        $name = $this->displayStoreName((string) ($payload['name'] ?? $payload['store_name'] ?? ''));
        $errors = $this->storeNameErrors($tenantId, $name, (string) $affiliate->id);
        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        if (AffiliateStoreNameRequest::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliate->id)
            ->where('status', 'pending')
            ->exists()) {
            return ['error' => 'resource_conflict'];
        }

        $isInitial = $affiliate->store_name_approved_at === null;
        if (! $isInitial && $affiliate->store_name_change_available_at !== null && $affiliate->store_name_change_available_at->isFuture()) {
            return ['error' => 'validation_failed', 'errors' => [
                'name' => ['The store name can be changed again after '.$affiliate->store_name_change_available_at->toIso8601String().'.'],
            ]];
        }

        $requestId = 'asr_'.Str::ulid()->toBase32();
        $normalized = $this->normalizeStoreName($name);
        $now = now();
        AffiliateStoreNameRequest::query()->create([
            'id' => $requestId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate->id,
            'request_type' => $isInitial ? 'initial' : 'change',
            'previous_name' => $isInitial ? null : $affiliate->name,
            'requested_name' => $name,
            'normalized_name' => $normalized,
            'status' => 'pending',
            'submitted_at' => $now,
        ]);
        $claimed = DB::table('affiliate_store_name_claims')->insertOrIgnore([
            'id' => 'asn_'.Str::ulid()->toBase32(),
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate->id,
            'request_id' => $requestId,
            'normalized_name' => $normalized,
            'status' => 'pending',
            'created_at' => $now,
            'updated_at' => $now,
        ]);
        if ($claimed !== 1) {
            AffiliateStoreNameRequest::query()->whereKey($requestId)->delete();

            return ['error' => 'validation_failed', 'errors' => ['name' => ['The store name has already been taken.']]];
        }
        if ($isInitial) {
            $affiliate->forceFill(['name' => $name, 'store_name_status' => 'pending'])->save();
        }

        DB::afterCommit(fn () => $this->notifications->affiliateStoreNameSubmitted(
            $tenantId,
            (string) $affiliate->id,
            $requestId,
            $isInitial ? 'initial' : 'change',
        ));

        return ['resource' => $this->storeNameRequestResource(AffiliateStoreNameRequest::query()->findOrFail($requestId)), 'status' => 201];
    }

    /**
     * @param array<string, mixed> $query
     * @return array<string, mixed>
     */
    public function listStoreNameRequests(string $tenantId, array $query): array
    {
        $builder = AffiliateStoreNameRequest::query()
            ->with('affiliateAccount.customer')
            ->where('tenant_id', $tenantId)
            ->latest('submitted_at');
        $status = trim((string) ($query['status'] ?? ''));
        if ($status !== '') {
            $builder->where('status', $status);
        }
        $rows = $builder->limit(min(100, max(1, (int) ($query['limit'] ?? 50))))->get();

        return [
            'data' => $rows->map(fn (AffiliateStoreNameRequest $row): array => $this->storeNameRequestResource($row))->values()->all(),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function reviewStoreNameRequest(
        string $tenantId,
        AdminSessionContext $actor,
        string $requestId,
        bool $approve,
        array $payload,
        Request $request,
    ): array {
        $row = AffiliateStoreNameRequest::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($requestId)
            ->lockForUpdate()
            ->first();
        if ($row === null) {
            return ['error' => 'not_found'];
        }
        if ($row->status !== 'pending') {
            return ['resource' => $this->storeNameRequestResource($row), 'status' => 200];
        }

        $affiliate = AffiliateAccount::query()->where('tenant_id', $tenantId)->whereKey($row->affiliate_account_id)->lockForUpdate()->first();
        if ($affiliate === null) {
            return ['error' => 'not_found'];
        }
        $now = now();
        $note = $this->nullableString($payload['admin_note'] ?? $payload['reason'] ?? null);

        if (! $approve) {
            $row->forceFill([
                'status' => 'rejected',
                'admin_note' => $note,
                'reviewed_by_admin_id' => $actor->adminUser['id'],
                'reviewed_at' => $now,
            ])->save();
            AffiliateStoreNameClaim::query()->where('request_id', $row->id)->where('status', 'pending')->delete();
            if ($affiliate->store_name_approved_at === null) {
                $affiliate->forceFill(['store_name_status' => 'rejected'])->save();
            }
            DB::afterCommit(fn () => $this->notifications->affiliateStoreNameReviewed($tenantId, (string) $affiliate->id, false, (string) $row->id));
            $this->audit($actor, $request, 'affiliate.store_name.reject', 'affiliate_store_name_request', (string) $row->id, $payload, $tenantId);

            return ['resource' => $this->storeNameRequestResource($row->fresh()), 'status' => 200];
        }

        $claim = AffiliateStoreNameClaim::query()->where('request_id', $row->id)->where('status', 'pending')->lockForUpdate()->first();
        if ($claim === null) {
            return ['error' => 'resource_conflict'];
        }
        $previousNormalized = (string) ($affiliate->store_name_normalized ?? '');
        $row->forceFill([
            'status' => 'approved',
            'admin_note' => $note,
            'reviewed_by_admin_id' => $actor->adminUser['id'],
            'reviewed_at' => $now,
        ])->save();
        $claim->forceFill(['status' => 'approved'])->save();
        $affiliate->forceFill([
            'name' => $row->requested_name,
            'store_name_status' => 'approved',
            'store_name_normalized' => $row->normalized_name,
            'store_name_approved_at' => $now,
            'store_name_change_available_at' => $now->copy()->addMonthsNoOverflow(3),
        ])->save();
        if ($previousNormalized !== '' && $previousNormalized !== $row->normalized_name) {
            AffiliateStoreNameClaim::query()
                ->where('tenant_id', $tenantId)
                ->where('affiliate_account_id', $affiliate->id)
                ->where('normalized_name', $previousNormalized)
                ->delete();
        }
        DB::afterCommit(fn () => $this->notifications->affiliateStoreNameReviewed($tenantId, (string) $affiliate->id, true, (string) $row->id));
        $this->audit($actor, $request, 'affiliate.store_name.approve', 'affiliate_store_name_request', (string) $row->id, $payload, $tenantId);

        return ['resource' => $this->storeNameRequestResource($row->fresh()), 'status' => 200];
    }

    /**
     * @return array<string, mixed>
     */
    public function listTiers(string $tenantId): array
    {
        $tiers = collect($this->ensureTenantTiers($tenantId))->sortBy('tier_rank')->values();

        return ['data' => $tiers->map(fn (AffiliateProgram $tier): array => $this->tierResource($tier))->all()];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateTier(string $tenantId, AdminSessionContext $actor, string $code, array $payload, Request $request): array
    {
        if (! in_array($code, self::TIER_CODES, true)) {
            return ['error' => 'not_found'];
        }

        return DB::transaction(function () use ($tenantId, $actor, $code, $payload, $request): array {
            $this->ensureTenantTiers($tenantId);
            $this->lockTenantAffiliateConfiguration($tenantId);
            $program = AffiliateProgram::query()
                ->where('tenant_id', $tenantId)
                ->where('code', $code)
                ->whereNotNull('tier_rank')
                ->lockForUpdate()
                ->firstOrFail();
            $commission = $this->moneyAmount($payload['commission_per_ticket'] ?? $payload['commission_per_ticket_amount'] ?? null, (int) $program->commission_per_ticket_amount);
            $minimumPayout = $this->moneyAmount($payload['minimum_payout'] ?? $payload['minimum_payout_amount'] ?? null, (int) $program->minimum_payout_amount);
            $name = trim((string) ($payload['name'] ?? $program->name));
            $errors = [];
            if ($name === '') {
                $errors['name'][] = 'The name field is required.';
            }
            if ($commission < 0) {
                $errors['commission_per_ticket'][] = 'The commission per ticket must be zero or greater.';
            }
            if ($minimumPayout < 1) {
                $errors['minimum_payout'][] = 'The minimum payout must be greater than zero.';
            }
            if ($errors !== []) {
                return ['error' => 'validation_failed', 'errors' => $errors];
            }

            $previousCommission = (int) $program->commission_per_ticket_amount;
            $effectiveAt = now();
            $program->forceFill([
                'name' => $name,
                'commission_per_ticket_amount' => $commission,
                'minimum_payout_amount' => $minimumPayout,
                'status' => 'active',
            ])->save();
            $this->syncTierCommissionRule($program);
            if ($commission !== $previousCommission) {
                $this->recordTierRate($program, $effectiveAt, 'tier_update', [
                    'previous_commission_per_ticket_amount' => $previousCommission,
                    'updated_by_admin_id' => $actor->adminUser['id'],
                ]);
            }
            $this->audit($actor, $request, 'affiliate.tier.update', 'affiliate_program', (string) $program->id, $payload, $tenantId);

            return ['resource' => $this->tierResource($program->fresh()), 'status' => 200];
        });
    }

    /**
     * @param array<string, mixed> $query
     * @return array<string, mixed>
     */
    public function listCampaigns(string $tenantId, array $query = []): array
    {
        $this->activateDueCampaigns($tenantId);
        $builder = AffiliateTierCampaign::query()->with(['rules.targetProgram'])->where('tenant_id', $tenantId)->latest('starts_at');
        $status = trim((string) ($query['status'] ?? ''));
        if ($status !== '') {
            $builder->where('status', $status);
        }
        $rows = $builder->limit(min(100, max(1, (int) ($query['limit'] ?? 50))))->get();

        return [
            'data' => $rows->map(fn (AffiliateTierCampaign $campaign): array => $this->campaignResource($campaign, null, false))->all(),
            'meta' => ['next_cursor' => null, 'has_more' => false],
        ];
    }

    public function campaign(string $tenantId, string $campaignId): ?array
    {
        $campaign = AffiliateTierCampaign::query()->with(['rules.targetProgram'])->where('tenant_id', $tenantId)->whereKey($campaignId)->first();

        return $campaign === null ? null : $this->campaignResource($campaign, null, true);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createCampaign(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        return DB::transaction(function () use ($tenantId, $actor, $payload, $request): array {
            $this->lockTenantAffiliateConfiguration($tenantId);
            $normalized = $this->normalizeCampaignPayload($tenantId, $payload);
            if ($normalized['errors'] !== []) {
                return ['error' => 'validation_failed', 'errors' => $normalized['errors']];
            }
            if ($normalized['status'] === 'scheduled' && $this->campaignOverlaps($tenantId, $normalized['starts_at'], $normalized['ends_at'])) {
                return ['error' => 'validation_failed', 'errors' => ['starts_at' => ['The campaign period overlaps another scheduled or active tier campaign.']]];
            }

            $campaignId = 'atc_'.Str::ulid()->toBase32();
            $campaign = AffiliateTierCampaign::query()->create([
                'id' => $campaignId,
                'tenant_id' => $tenantId,
                'name' => $normalized['name'],
                'campaign_type' => $normalized['campaign_type'],
                'status' => $normalized['status'],
                'starts_at' => $normalized['starts_at'],
                'ends_at' => $normalized['ends_at'],
                'created_by_admin_id' => $actor->adminUser['id'],
                'metadata_json' => $normalized['metadata'],
            ]);
            $this->replaceCampaignRules($campaign, $normalized['rules']);
            $this->audit($actor, $request, 'affiliate.tier_campaign.create', 'affiliate_tier_campaign', $campaignId, $payload, $tenantId);

            return ['resource' => $this->campaignResource($campaign->fresh(['rules.targetProgram']), null, true), 'status' => 201];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateCampaign(string $tenantId, AdminSessionContext $actor, string $campaignId, array $payload, Request $request): array
    {
        return DB::transaction(function () use ($tenantId, $actor, $campaignId, $payload, $request): array {
            $this->lockTenantAffiliateConfiguration($tenantId);
            $campaign = AffiliateTierCampaign::query()->where('tenant_id', $tenantId)->whereKey($campaignId)->lockForUpdate()->first();
            if ($campaign === null) {
                return ['error' => 'not_found'];
            }
            if (! in_array((string) $campaign->status, self::MUTABLE_CAMPAIGN_STATUSES, true) || $campaign->starts_at->lte(now())) {
                return ['error' => 'resource_conflict'];
            }
            $merged = array_replace([
                'name' => $campaign->name,
                'campaign_type' => $campaign->campaign_type,
                'status' => $campaign->status,
                'starts_at' => $campaign->starts_at->toIso8601String(),
                'ends_at' => $campaign->ends_at->toIso8601String(),
                'metadata' => $campaign->metadata_json ?? [],
                'rules' => $campaign->rules()->with('targetProgram')->get()->map(fn (AffiliateTierCampaignRule $rule): array => [
                    'minimum_ticket_count' => $rule->minimum_ticket_count,
                    'rank_from' => $rule->rank_from,
                    'rank_to' => $rule->rank_to,
                    'target_tier_code' => $rule->targetProgram?->code,
                ])->all(),
            ], $payload);
            $normalized = $this->normalizeCampaignPayload($tenantId, $merged);
            if ($normalized['errors'] !== []) {
                return ['error' => 'validation_failed', 'errors' => $normalized['errors']];
            }
            if ($normalized['status'] === 'scheduled' && $this->campaignOverlaps($tenantId, $normalized['starts_at'], $normalized['ends_at'], $campaignId)) {
                return ['error' => 'validation_failed', 'errors' => ['starts_at' => ['The campaign period overlaps another scheduled or active tier campaign.']]];
            }
            $campaign->forceFill([
                'name' => $normalized['name'],
                'campaign_type' => $normalized['campaign_type'],
                'status' => $normalized['status'],
                'starts_at' => $normalized['starts_at'],
                'ends_at' => $normalized['ends_at'],
                'metadata_json' => $normalized['metadata'],
            ])->save();
            $this->replaceCampaignRules($campaign, $normalized['rules']);
            $this->audit($actor, $request, 'affiliate.tier_campaign.update', 'affiliate_tier_campaign', $campaignId, $payload, $tenantId);

            return ['resource' => $this->campaignResource($campaign->fresh(['rules.targetProgram']), null, true), 'status' => 200];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function finalizeCampaign(string $tenantId, string $campaignId, ?AdminSessionContext $actor = null, ?Request $request = null): array
    {
        return DB::transaction(function () use ($tenantId, $campaignId, $actor, $request): array {
            $this->lockTenantAffiliateConfiguration($tenantId);
            $campaign = AffiliateTierCampaign::query()->where('tenant_id', $tenantId)->whereKey($campaignId)->lockForUpdate()->first();
            if ($campaign === null) {
                return ['error' => 'not_found'];
            }
            if ($campaign->status === 'completed') {
                return ['resource' => $this->campaignResource($campaign->fresh(['rules.targetProgram']), null, true), 'status' => 200];
            }
            if ($campaign->status === 'cancelled') {
                return ['error' => 'resource_conflict'];
            }
            if (! in_array((string) $campaign->status, ['scheduled', 'active', 'processing'], true) || $campaign->ends_at->isFuture()) {
                return ['error' => 'resource_conflict'];
            }

            $campaign->forceFill(['status' => 'processing'])->save();
            $this->ensureTenantTiers($tenantId);
            $rules = $campaign->rules()->with('targetProgram')->orderBy('rule_order')->get();
            $stats = $this->campaignStats($campaign);
            $accounts = $this->campaignAccounts($campaign, $stats);
            $ranked = $this->rankAccounts($accounts, $stats);
            $now = now();

            foreach ($ranked as $entry) {
                /** @var AffiliateAccount $account */
                $account = $entry['account'];
                $previous = $this->currentProgram($account);
                $calculated = $campaign->campaign_type === 'fixed_threshold'
                    ? $this->fixedTierForTickets($rules, (int) $entry['ticket_count'])
                    : $this->rankingTierForRank($rules, (int) $entry['rank']);
                $applied = $previous;
                if ($campaign->campaign_type === 'fixed_threshold' && $calculated !== null) {
                    $applied = $calculated;
                } elseif ($campaign->campaign_type === 'ranking' && $calculated !== null && (int) $calculated->tier_rank > (int) $previous->tier_rank) {
                    $applied = $calculated;
                }
                $changed = (string) $applied->id !== (string) $previous->id;

                AffiliateTierCampaignStat::query()->updateOrCreate(
                    ['campaign_id' => $campaign->id, 'affiliate_account_id' => $account->id],
                    [
                        'id' => AffiliateTierCampaignStat::query()
                            ->where('campaign_id', $campaign->id)
                            ->where('affiliate_account_id', $account->id)
                            ->value('id') ?? 'ats_'.Str::ulid()->toBase32(),
                        'tenant_id' => $tenantId,
                        'ticket_count' => $entry['ticket_count'],
                        'reached_at' => $entry['reached_at'],
                        'reconciled_at' => $now,
                    ],
                );

                if ($changed) {
                    $account->forceFill(['affiliate_program_id' => $applied->id])->save();
                    AffiliateLink::query()
                        ->where('tenant_id', $tenantId)
                        ->where('affiliate_account_id', $account->id)
                        ->where('status', 'active')
                        ->update(['affiliate_program_id' => $applied->id, 'updated_at' => $now]);
                    AffiliateTierHistory::query()->create([
                        'id' => 'ath_'.Str::ulid()->toBase32(),
                        'tenant_id' => $tenantId,
                        'affiliate_account_id' => $account->id,
                        'campaign_id' => $campaign->id,
                        'previous_program_id' => $previous->id,
                        'new_program_id' => $applied->id,
                        'source' => 'campaign',
                        'ticket_count' => $entry['ticket_count'],
                        'rank' => $entry['rank'],
                        'effective_at' => $now,
                        'metadata_json' => ['campaign_type' => $campaign->campaign_type],
                    ]);
                    DB::afterCommit(fn () => $this->notifications->affiliateTierChanged(
                        $tenantId,
                        (string) $account->id,
                        (string) $previous->name,
                        (string) $applied->name,
                        (string) $campaign->id,
                    ));
                }

                $resultStatus = $changed ? 'applied' : ($calculated === null ? 'not_qualified' : 'unchanged');
                AffiliateTierCampaignResult::query()->updateOrCreate(
                    ['campaign_id' => $campaign->id, 'affiliate_account_id' => $account->id],
                    [
                        'id' => AffiliateTierCampaignResult::query()
                            ->where('campaign_id', $campaign->id)
                            ->where('affiliate_account_id', $account->id)
                            ->value('id') ?? 'atr_'.Str::ulid()->toBase32(),
                        'tenant_id' => $tenantId,
                        'ticket_count' => $entry['ticket_count'],
                        'rank' => $entry['rank'],
                        'reached_at' => $entry['reached_at'],
                        'previous_program_id' => $previous->id,
                        'calculated_program_id' => $calculated?->id,
                        'applied_program_id' => $applied->id,
                        'result_status' => $resultStatus,
                        'metadata_json' => ['campaign_type' => $campaign->campaign_type],
                        'finalized_at' => $now,
                    ],
                );

                if (! $changed) {
                    DB::afterCommit(fn () => $this->notifications->affiliateTierCampaignCompleted(
                        $tenantId,
                        (string) $account->id,
                        (string) $campaign->id,
                        (string) $campaign->name,
                        (string) $applied->name,
                        (int) $entry['ticket_count'],
                        $campaign->campaign_type === 'ranking' ? (int) $entry['rank'] : null,
                        $resultStatus,
                    ));
                }
            }

            $campaign->forceFill([
                'status' => 'completed',
                'finalized_at' => $now,
                'finalized_by_admin_id' => $actor?->adminUser['id'] ?? null,
            ])->save();
            if ($actor !== null && $request !== null) {
                $this->audit($actor, $request, 'affiliate.tier_campaign.finalize', 'affiliate_tier_campaign', $campaignId, [], $tenantId);
            }

            return ['resource' => $this->campaignResource($campaign->fresh(['rules.targetProgram']), null, true), 'status' => 200];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function cancelCampaign(string $tenantId, string $campaignId, AdminSessionContext $actor, Request $request): array
    {
        return DB::transaction(function () use ($tenantId, $campaignId, $actor, $request): array {
            $this->lockTenantAffiliateConfiguration($tenantId);
            $campaign = AffiliateTierCampaign::query()
                ->where('tenant_id', $tenantId)
                ->whereKey($campaignId)
                ->lockForUpdate()
                ->first();
            if ($campaign === null) {
                return ['error' => 'not_found'];
            }
            if ($campaign->status === 'cancelled') {
                return ['resource' => $this->campaignResource($campaign->fresh(['rules.targetProgram']), null, true), 'status' => 200];
            }
            if (in_array((string) $campaign->status, ['processing', 'completed'], true)) {
                return ['error' => 'resource_conflict'];
            }

            $campaign->forceFill(['status' => 'cancelled'])->save();
            $this->audit($actor, $request, 'affiliate.tier_campaign.cancel', 'affiliate_tier_campaign', $campaignId, [], $tenantId);

            return ['resource' => $this->campaignResource($campaign->fresh(['rules.targetProgram']), null, true), 'status' => 200];
        });
    }

    public function finalizeDueCampaigns(int $limit = 25): int
    {
        return $this->finalizeDueCampaignsBatch($limit)['finalized'];
    }

    /**
     * @return array{
     *     selected: int,
     *     succeeded: int,
     *     failed: int,
     *     finalized: int,
     *     failures: array<int, array{phase: string, campaign_id: string, tenant_id: string, exception: string}>
     * }
     */
    public function finalizeDueCampaignsBatch(int $limit = 25): array
    {
        $failures = [
            ...$this->activateDueCampaigns(),
            ...$this->notifyEndingSoonCampaigns(),
        ];
        $campaigns = AffiliateTierCampaign::query()
            ->whereIn('status', ['scheduled', 'active'])
            ->where('ends_at', '<=', now())
            ->orderBy('ends_at')
            ->limit(max(1, min(100, $limit)))
            ->get();
        $count = 0;
        foreach ($campaigns as $campaign) {
            try {
                $result = $this->finalizeCampaign((string) $campaign->tenant_id, (string) $campaign->id);
                if (($result['error'] ?? null) === null) {
                    $count++;
                } else {
                    $failures[] = [
                        'phase' => 'finalize',
                        'campaign_id' => (string) $campaign->id,
                        'tenant_id' => (string) $campaign->tenant_id,
                        'exception' => 'domain_error:'.(string) $result['error'],
                    ];
                }
            } catch (Throwable $exception) {
                report($exception);
                $failures[] = [
                    'phase' => 'finalize',
                    'campaign_id' => (string) $campaign->id,
                    'tenant_id' => (string) $campaign->tenant_id,
                    'exception' => $exception::class,
                ];
            }
        }

        return [
            'selected' => $campaigns->count(),
            'succeeded' => $count,
            'failed' => count($failures),
            'finalized' => $count,
            'failures' => $failures,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    public function customerCampaignList(string $tenantId, string $customerId): array
    {
        $affiliate = AffiliateAccount::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->where('status', 'active')
            ->first();

        return ['data' => $affiliate === null ? [] : $this->customerCampaigns($tenantId, (string) $affiliate->id)];
    }

    public function customerCampaign(string $tenantId, string $customerId, string $campaignId): ?array
    {
        $affiliate = AffiliateAccount::query()
            ->where('tenant_id', $tenantId)
            ->where('customer_id', $customerId)
            ->where('status', 'active')
            ->first();
        if ($affiliate === null) {
            return null;
        }
        $this->activateDueCampaigns($tenantId);
        $campaign = AffiliateTierCampaign::query()
            ->with(['rules.targetProgram'])
            ->where('tenant_id', $tenantId)
            ->whereKey($campaignId)
            ->whereIn('status', ['scheduled', 'active', 'completed'])
            ->first();

        return $campaign === null ? null : $this->campaignResource($campaign, (string) $affiliate->id, true);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function customerCampaigns(string $tenantId, string $affiliateId): array
    {
        $this->activateDueCampaigns($tenantId);
        return AffiliateTierCampaign::query()
            ->with(['rules.targetProgram'])
            ->where('tenant_id', $tenantId)
            ->whereIn('status', ['scheduled', 'active', 'completed'])
            ->latest('starts_at')
            ->limit(5)
            ->get()
            ->map(fn (AffiliateTierCampaign $campaign): array => $this->campaignResource($campaign, $affiliateId, true))
            ->all();
    }

    private function currentProgram(AffiliateAccount $affiliate): AffiliateProgram
    {
        $program = $affiliate->affiliate_program_id === null ? null : AffiliateProgram::query()
            ->where('tenant_id', $affiliate->tenant_id)
            ->whereKey($affiliate->affiliate_program_id)
            ->whereNotNull('tier_rank')
            ->first();
        if ($program !== null) {
            return $program;
        }
        $program = $this->bronzeProgram((string) $affiliate->tenant_id);
        $affiliate->forceFill(['affiliate_program_id' => $program->id])->save();

        return $program;
    }

    /**
     * @return array<string, mixed>
     */
    public function tierResource(AffiliateProgram $program): array
    {
        return [
            'id' => (string) $program->id,
            'code' => (string) $program->code,
            'name' => (string) $program->name,
            'rank' => (int) $program->tier_rank,
            'status' => (string) $program->status,
            'commission_per_ticket' => $this->money((int) $program->commission_per_ticket_amount),
            'minimum_payout' => $this->money((int) $program->minimum_payout_amount),
            'updated_at' => $program->updated_at?->toIso8601String(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function storeNameRequestResource(AffiliateStoreNameRequest $row): array
    {
        $row->loadMissing('affiliateAccount.customer');
        return [
            'id' => (string) $row->id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'affiliate_code' => (string) ($row->affiliateAccount?->code ?? ''),
            'customer_no' => (string) ($row->affiliateAccount?->customer?->customer_no ?? ''),
            'request_type' => (string) $row->request_type,
            'previous_name' => $row->previous_name,
            'requested_name' => (string) $row->requested_name,
            'status' => (string) $row->status,
            'admin_note' => $row->admin_note,
            'submitted_at' => $row->submitted_at?->toIso8601String(),
            'reviewed_at' => $row->reviewed_at?->toIso8601String(),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function campaignResource(AffiliateTierCampaign $campaign, ?string $affiliateId, bool $includeProgress): array
    {
        $campaign->loadMissing(['rules.targetProgram']);
        $resource = [
            'id' => (string) $campaign->id,
            'name' => (string) $campaign->name,
            'campaign_type' => (string) $campaign->campaign_type,
            'status' => (string) $campaign->status,
            'starts_at' => $campaign->starts_at?->toIso8601String(),
            'ends_at' => $campaign->ends_at?->toIso8601String(),
            'finalized_at' => $campaign->finalized_at?->toIso8601String(),
            'can_reduce_tier' => $campaign->campaign_type === 'fixed_threshold',
            'rules' => $campaign->rules->map(fn (AffiliateTierCampaignRule $rule): array => [
                'id' => (string) $rule->id,
                'minimum_ticket_count' => $rule->minimum_ticket_count,
                'rank_from' => $rule->rank_from,
                'rank_to' => $rule->rank_to,
                'target_tier' => $rule->targetProgram === null ? null : $this->tierResource($rule->targetProgram),
            ])->values()->all(),
        ];
        if (! $includeProgress) {
            return $resource;
        }

        if ($campaign->status === 'completed') {
            $results = AffiliateTierCampaignResult::query()
                ->with(['affiliateAccount', 'calculatedProgram', 'appliedProgram'])
                ->where('campaign_id', $campaign->id)
                ->orderBy('rank')
                ->limit(100)
                ->get();
            $own = $affiliateId === null ? null : $results->firstWhere('affiliate_account_id', $affiliateId);
            if ($affiliateId !== null && $own === null) {
                $own = AffiliateTierCampaignResult::query()
                    ->with(['calculatedProgram', 'appliedProgram'])
                    ->where('campaign_id', $campaign->id)
                    ->where('affiliate_account_id', $affiliateId)
                    ->first();
            }
            $resource['leaderboard'] = $results->map(fn (AffiliateTierCampaignResult $result): array => [
                'affiliate_code' => (string) ($result->affiliateAccount?->code ?? ''),
                'affiliate_name' => $this->leaderboardAffiliateName($result->affiliateAccount),
                'ticket_count' => (int) $result->ticket_count,
                'rank' => $result->rank,
                'is_current_affiliate' => $affiliateId !== null && (string) $result->affiliate_account_id === $affiliateId,
            ])->values()->all();
            $resource['my_progress'] = $own === null ? null : [
                'ticket_count' => (int) $own->ticket_count,
                'rank' => $own->rank,
                'result_status' => (string) $own->result_status,
                'projected_tier' => $own->appliedProgram === null
                    ? ($own->calculatedProgram === null ? null : $this->tierResource($own->calculatedProgram))
                    : $this->tierResource($own->appliedProgram),
            ];

            return $resource;
        }

        $stats = $this->campaignStats($campaign);
        $ranked = $this->rankAccounts($this->campaignAccounts($campaign, $stats), $stats);
        $resource['leaderboard'] = collect($ranked)->take(100)->map(fn (array $entry): array => [
            'affiliate_code' => (string) $entry['account']->code,
            'affiliate_name' => $this->leaderboardAffiliateName($entry['account']),
            'ticket_count' => (int) $entry['ticket_count'],
            'rank' => (int) $entry['rank'],
            'is_current_affiliate' => $affiliateId !== null && (string) $entry['account']->id === $affiliateId,
        ])->values()->all();
        $own = $affiliateId === null ? null : collect($ranked)->first(fn (array $entry): bool => (string) $entry['account']->id === $affiliateId);
        if ($own !== null) {
            $rules = $campaign->rules;
            $projected = $campaign->campaign_type === 'fixed_threshold'
                ? $this->fixedTierForTickets($rules, (int) $own['ticket_count'])
                : $this->rankingTierForRank($rules, (int) $own['rank']);
            $resource['my_progress'] = [
                'ticket_count' => (int) $own['ticket_count'],
                'rank' => (int) $own['rank'],
                'projected_tier' => $projected === null ? null : $this->tierResource($projected),
            ];
        } else {
            $resource['my_progress'] = null;
        }

        return $resource;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{name: string, campaign_type: string, status: string, starts_at: Carbon, ends_at: Carbon, metadata: array<string, mixed>, rules: array<int, array<string, mixed>>, errors: array<string, array<int, string>>}
     */
    private function normalizeCampaignPayload(string $tenantId, array $payload): array
    {
        $name = trim((string) ($payload['name'] ?? ''));
        $type = trim((string) ($payload['campaign_type'] ?? $payload['type'] ?? 'fixed_threshold'));
        $status = trim((string) ($payload['status'] ?? 'scheduled'));
        $errors = [];
        try {
            $startsAt = Carbon::parse((string) ($payload['starts_at'] ?? ''));
        } catch (\Throwable) {
            $startsAt = now();
            $errors['starts_at'][] = 'The starts_at field must be a valid date.';
        }
        try {
            $endsAt = Carbon::parse((string) ($payload['ends_at'] ?? ''));
        } catch (\Throwable) {
            $endsAt = now();
            $errors['ends_at'][] = 'The ends_at field must be a valid date.';
        }
        if ($name === '') {
            $errors['name'][] = 'The name field is required.';
        }
        if (! in_array($type, self::CAMPAIGN_TYPES, true)) {
            $errors['campaign_type'][] = 'The campaign_type field is invalid.';
        }
        if (! in_array($status, self::MUTABLE_CAMPAIGN_STATUSES, true)) {
            $errors['status'][] = 'The status field must be draft or scheduled.';
        }
        if ($endsAt->lte($startsAt)) {
            $errors['ends_at'][] = 'The ends_at field must be after starts_at.';
        }
        if ($status === 'scheduled' && $endsAt->lte(now())) {
            $errors['ends_at'][] = 'A scheduled campaign must end in the future.';
        }

        $programs = $this->ensureTenantTiers($tenantId);
        $rawRules = is_array($payload['rules'] ?? null) ? array_values($payload['rules']) : [];
        if ($rawRules === []) {
            $rawRules = $type === 'ranking'
                ? [
                    ['rank_from' => 1, 'rank_to' => 10, 'target_tier_code' => 'diamond'],
                    ['rank_from' => 11, 'rank_to' => 20, 'target_tier_code' => 'platinum'],
                ]
                : [
                    ['minimum_ticket_count' => 0, 'target_tier_code' => 'bronze'],
                    ['minimum_ticket_count' => 200, 'target_tier_code' => 'silver'],
                    ['minimum_ticket_count' => 300, 'target_tier_code' => 'gold'],
                    ['minimum_ticket_count' => 400, 'target_tier_code' => 'platinum'],
                    ['minimum_ticket_count' => 500, 'target_tier_code' => 'diamond'],
                ];
        }
        $rules = [];
        $ranges = [];
        foreach ($rawRules as $index => $rawRule) {
            if (! is_array($rawRule)) {
                $errors['rules'][] = 'Each campaign rule must be an object.';
                continue;
            }
            $targetTier = is_array($rawRule['target_tier'] ?? null) ? $rawRule['target_tier'] : [];
            $code = trim((string) ($rawRule['target_tier_code'] ?? $rawRule['tier_code'] ?? $targetTier['code'] ?? ''));
            if (! isset($programs[$code])) {
                $errors['rules'][] = 'Rule '.($index + 1).' has an invalid target tier.';
                continue;
            }
            if ($type === 'fixed_threshold') {
                $minimum = filter_var($rawRule['minimum_ticket_count'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 0]]);
                if ($minimum === false) {
                    $errors['rules'][] = 'Rule '.($index + 1).' must have a non-negative minimum_ticket_count.';
                    continue;
                }
                if ($minimum === 0 && $code !== 'bronze') {
                    $errors['rules'][] = 'The zero-ticket baseline must target the Bronze tier.';
                    continue;
                }
                if (isset($ranges['minimum:'.$minimum])) {
                    $errors['rules'][] = 'Fixed threshold values must be unique.';
                    continue;
                }
                $ranges['minimum:'.$minimum] = true;
                $rules[] = [
                    'minimum_ticket_count' => $minimum,
                    'target_program_id' => $programs[$code]->id,
                    'target_tier_rank' => (int) $programs[$code]->tier_rank,
                ];
                continue;
            }
            $from = filter_var($rawRule['rank_from'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            $to = filter_var($rawRule['rank_to'] ?? null, FILTER_VALIDATE_INT, ['options' => ['min_range' => 1]]);
            if ($from === false || $to === false || $to < $from) {
                $errors['rules'][] = 'Rule '.($index + 1).' must have a valid rank range.';
                continue;
            }
            foreach ($ranges as $range) {
                if ($from <= $range['to'] && $to >= $range['from']) {
                    $errors['rules'][] = 'Competition rank ranges must not overlap.';
                    continue 2;
                }
            }
            $ranges[] = ['from' => $from, 'to' => $to];
            $rules[] = [
                'rank_from' => $from,
                'rank_to' => $to,
                'target_program_id' => $programs[$code]->id,
                'target_tier_rank' => (int) $programs[$code]->tier_rank,
            ];
        }
        if ($type === 'fixed_threshold' && ! collect($rules)->contains(fn (array $rule): bool => (int) $rule['minimum_ticket_count'] === 0)) {
            $rules[] = [
                'minimum_ticket_count' => 0,
                'target_program_id' => $programs['bronze']->id,
                'target_tier_rank' => (int) $programs['bronze']->tier_rank,
            ];
        }
        usort($rules, fn (array $left, array $right): int => $type === 'fixed_threshold'
            ? ((int) $left['minimum_ticket_count'] <=> (int) $right['minimum_ticket_count'])
            : ((int) $left['rank_from'] <=> (int) $right['rank_from']));
        $previousTierRank = null;
        foreach ($rules as $rule) {
            $tierRank = (int) $rule['target_tier_rank'];
            if ($previousTierRank !== null) {
                if ($type === 'fixed_threshold' && $tierRank < $previousTierRank) {
                    $errors['rules'][] = 'Fixed-threshold target tiers must increase with ticket thresholds.';
                    break;
                }
                if ($type === 'ranking' && $tierRank > $previousTierRank) {
                    $errors['rules'][] = 'Competition target tiers must not increase for lower leaderboard positions.';
                    break;
                }
            }
            $previousTierRank = $tierRank;
        }

        return [
            'name' => $name,
            'campaign_type' => $type,
            'status' => $status,
            'starts_at' => $startsAt,
            'ends_at' => $endsAt,
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
            'rules' => array_map(function (array $rule): array {
                unset($rule['target_tier_rank']);

                return $rule;
            }, $rules),
            'errors' => $errors,
        ];
    }

    /**
     * @param array<int, array<string, mixed>> $rules
     */
    private function replaceCampaignRules(AffiliateTierCampaign $campaign, array $rules): void
    {
        AffiliateTierCampaignRule::query()->where('campaign_id', $campaign->id)->delete();
        $now = now();
        foreach ($rules as $index => $rule) {
            AffiliateTierCampaignRule::query()->create([
                'id' => 'acr_'.Str::ulid()->toBase32(),
                'tenant_id' => $campaign->tenant_id,
                'campaign_id' => $campaign->id,
                'target_program_id' => $rule['target_program_id'],
                'rule_order' => $index,
                'minimum_ticket_count' => $rule['minimum_ticket_count'] ?? null,
                'rank_from' => $rule['rank_from'] ?? null,
                'rank_to' => $rule['rank_to'] ?? null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    private function campaignOverlaps(string $tenantId, Carbon $startsAt, Carbon $endsAt, ?string $exceptId = null): bool
    {
        return AffiliateTierCampaign::query()
            ->where('tenant_id', $tenantId)
            ->whereIn('status', ['scheduled', 'active', 'processing'])
            ->when($exceptId !== null, fn ($query) => $query->where('id', '!=', $exceptId))
            ->where('starts_at', '<', $endsAt)
            ->where('ends_at', '>', $startsAt)
            ->exists();
    }

    /**
     * @return array<int, array{phase: string, campaign_id: string, tenant_id: string, exception: string}>
     */
    private function activateDueCampaigns(?string $tenantId = null): array
    {
        $campaigns = AffiliateTierCampaign::query()
            ->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))
            ->where('status', 'scheduled')
            ->where('starts_at', '<=', now())
            ->where('ends_at', '>', now())
            ->orderBy('starts_at')
            ->get();
        $failures = [];
        foreach ($campaigns as $campaign) {
            try {
                $activated = AffiliateTierCampaign::query()
                    ->whereKey($campaign->id)
                    ->where('status', 'scheduled')
                    ->update(['status' => 'active', 'updated_at' => now()]);
                if ($activated === 1) {
                    $this->notifyCampaignAffiliates($campaign, 'started');
                }
            } catch (Throwable $exception) {
                report($exception);
                $failures[] = [
                    'phase' => 'activate',
                    'campaign_id' => (string) $campaign->id,
                    'tenant_id' => (string) $campaign->tenant_id,
                    'exception' => $exception::class,
                ];
            }
        }

        return $failures;
    }

    /**
     * @return array<int, array{phase: string, campaign_id: string, tenant_id: string, exception: string}>
     */
    private function notifyEndingSoonCampaigns(): array
    {
        $campaigns = AffiliateTierCampaign::query()
            ->where('status', 'active')
            ->where('ends_at', '>', now())
            ->where('ends_at', '<=', now()->addDay())
            ->orderBy('ends_at')
            ->limit(100)
            ->get();
        $failures = [];
        foreach ($campaigns as $campaign) {
            try {
                $this->notifyCampaignAffiliates($campaign, 'ending_soon');
            } catch (Throwable $exception) {
                report($exception);
                $failures[] = [
                    'phase' => 'notify_ending_soon',
                    'campaign_id' => (string) $campaign->id,
                    'tenant_id' => (string) $campaign->tenant_id,
                    'exception' => $exception::class,
                ];
            }
        }

        return $failures;
    }

    private function notifyCampaignAffiliates(AffiliateTierCampaign $campaign, string $milestone): void
    {
        AffiliateAccount::query()
            ->where('tenant_id', $campaign->tenant_id)
            ->where('status', 'active')
            ->whereNotNull('customer_id')
            ->orderBy('id')
            ->pluck('id')
            ->each(fn (mixed $affiliateId) => $this->notifications->affiliateTierCampaignMilestone(
                (string) $campaign->tenant_id,
                (string) $affiliateId,
                (string) $campaign->id,
                (string) $campaign->name,
                $milestone,
            ));
    }

    /**
     * @return array<string, array{ticket_count: int, reached_at: mixed}>
     */
    private function campaignStats(AffiliateTierCampaign $campaign): array
    {
        return DB::table('affiliate_attributions')
            ->join('orders', function ($join): void {
                $join->on('orders.id', '=', 'affiliate_attributions.order_id')
                    ->on('orders.tenant_id', '=', 'affiliate_attributions.tenant_id');
            })
            ->join('tickets', function ($join): void {
                $join->on('tickets.order_id', '=', 'orders.id')
                    ->on('tickets.tenant_id', '=', 'orders.tenant_id');
            })
            ->where('affiliate_attributions.tenant_id', $campaign->tenant_id)
            ->whereIn('affiliate_attributions.status', ['pending', 'converted'])
            ->whereNotNull('affiliate_attributions.order_id')
            ->where('orders.payment_status', 'paid')
            ->whereNull('orders.cancelled_at')
            ->whereNull('orders.refunded_at')
            ->whereBetween('orders.paid_at', [$campaign->starts_at, $campaign->ends_at])
            ->groupBy('affiliate_attributions.affiliate_account_id')
            ->selectRaw('affiliate_attributions.affiliate_account_id, COUNT(tickets.id) as ticket_count, MAX(orders.paid_at) as reached_at')
            ->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->affiliate_account_id => [
                'ticket_count' => (int) $row->ticket_count,
                'reached_at' => $row->reached_at,
            ]])
            ->all();
    }

    /**
     * Fixed-threshold campaigns evaluate every active affiliate so zero sales can
     * reduce a tier to Bronze. Ranking campaigns contain sellers only.
     *
     * @param array<string, array{ticket_count: int, reached_at: mixed}> $stats
     * @return Collection<int, AffiliateAccount>
     */
    private function campaignAccounts(AffiliateTierCampaign $campaign, array $stats): Collection
    {
        $query = AffiliateAccount::query()
            ->where('tenant_id', $campaign->tenant_id)
            ->where('status', 'active')
            ->where('created_at', '<=', $campaign->ends_at)
            ->orderBy('code');

        if ($campaign->campaign_type === 'ranking') {
            $participantIds = array_keys(array_filter(
                $stats,
                fn (array $row): bool => (int) $row['ticket_count'] > 0,
            ));
            if ($participantIds === []) {
                return collect();
            }
            $query->whereIn('id', $participantIds);
        }

        return $query->get();
    }

    /**
     * @param Collection<int, AffiliateAccount> $accounts
     * @param array<string, array{ticket_count: int, reached_at: mixed}> $stats
     * @return array<int, array{account: AffiliateAccount, ticket_count: int, reached_at: mixed, rank: int}>
     */
    private function rankAccounts(Collection $accounts, array $stats): array
    {
        $rows = $accounts->map(fn (AffiliateAccount $account): array => [
            'account' => $account,
            'ticket_count' => (int) ($stats[(string) $account->id]['ticket_count'] ?? 0),
            'reached_at' => $stats[(string) $account->id]['reached_at'] ?? null,
        ])->all();
        usort($rows, function (array $left, array $right): int {
            $count = $right['ticket_count'] <=> $left['ticket_count'];
            if ($count !== 0) {
                return $count;
            }
            $leftReached = $left['reached_at'] === null ? PHP_INT_MAX : Carbon::parse($left['reached_at'])->getTimestamp();
            $rightReached = $right['reached_at'] === null ? PHP_INT_MAX : Carbon::parse($right['reached_at'])->getTimestamp();
            $reached = $leftReached <=> $rightReached;

            return $reached !== 0 ? $reached : strcmp((string) $left['account']->code, (string) $right['account']->code);
        });
        foreach ($rows as $index => &$row) {
            $row['rank'] = $index + 1;
        }

        return $rows;
    }

    private function fixedTierForTickets(Collection $rules, int $ticketCount): ?AffiliateProgram
    {
        $rule = $rules
            ->filter(fn (AffiliateTierCampaignRule $rule): bool => $rule->minimum_ticket_count !== null && $rule->minimum_ticket_count <= $ticketCount)
            ->sortByDesc('minimum_ticket_count')
            ->first();

        return $rule?->targetProgram;
    }

    private function rankingTierForRank(Collection $rules, int $rank): ?AffiliateProgram
    {
        $rule = $rules->first(fn (AffiliateTierCampaignRule $rule): bool => $rule->rank_from !== null
            && $rule->rank_to !== null
            && $rank >= $rule->rank_from
            && $rank <= $rule->rank_to);

        return $rule?->targetProgram;
    }

    private function syncTierCommissionRule(AffiliateProgram $program): void
    {
        $code = (string) $program->code.'_per_ticket';
        CommissionRule::query()->updateOrCreate(
            ['tenant_id' => $program->tenant_id, 'code' => $code],
            [
                'id' => CommissionRule::query()->where('tenant_id', $program->tenant_id)->where('code', $code)->value('id')
                    ?? $this->stableId('cmr', (string) $program->tenant_id.':'.$code),
                'affiliate_program_id' => $program->id,
                'affiliate_account_id' => null,
                'name' => $program->name.' commission per ticket',
                'rule_type' => 'per_ticket',
                'amount' => (int) $program->commission_per_ticket_amount,
                'rate_bps' => 0,
                'currency' => 'THB',
                'status' => 'active',
                'metadata_json' => ['system_tier' => true],
            ],
        );
    }

    private function lockTenantAffiliateConfiguration(string $tenantId): void
    {
        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::select(
                'SELECT pg_advisory_xact_lock(hashtextextended(CAST(? AS text), 0))',
                [$tenantId],
            );

            return;
        }

        DB::table('partner_tenants')
            ->where('id', $tenantId)
            ->lockForUpdate()
            ->first();
    }

    private function ensureTierRateHistory(AffiliateProgram $program): void
    {
        if (! Schema::hasTable('affiliate_tier_rate_history')) {
            return;
        }

        if (AffiliateTierRateHistory::query()
            ->where('tenant_id', $program->tenant_id)
            ->where('affiliate_program_id', $program->id)
            ->exists()) {
            return;
        }

        $this->recordTierRate(
            $program,
            $program->created_at ?? now(),
            'tier_initialization',
            ['initialized' => true],
        );
    }

    /**
     * @param array<string, mixed> $metadata
     */
    private function recordTierRate(
        AffiliateProgram $program,
        Carbon $effectiveAt,
        string $source,
        array $metadata = [],
    ): void {
        if (! Schema::hasTable('affiliate_tier_rate_history')) {
            return;
        }

        $latestEffectiveAt = AffiliateTierRateHistory::query()
            ->where('tenant_id', $program->tenant_id)
            ->where('affiliate_program_id', $program->id)
            ->orderByDesc('effective_at')
            ->value('effective_at');
        if ($latestEffectiveAt !== null) {
            $latest = Carbon::parse((string) $latestEffectiveAt);
            if ($effectiveAt->lte($latest)) {
                $effectiveAt = $latest->addMicrosecond();
            }
        }

        AffiliateTierRateHistory::query()->create([
            'id' => 'arh_'.Str::ulid()->toBase32(),
            'tenant_id' => $program->tenant_id,
            'affiliate_program_id' => $program->id,
            'commission_per_ticket_amount' => (int) $program->commission_per_ticket_amount,
            'source' => $source,
            'metadata_json' => $metadata,
            'effective_at' => $effectiveAt,
        ]);
    }

    private function leaderboardAffiliateName(?AffiliateAccount $account): string
    {
        if ($account === null) {
            return '';
        }
        $name = trim((string) $account->name);

        return $account->store_name_status === 'approved' && $name !== ''
            ? $name
            : (string) $account->code;
    }

    private function displayStoreName(string $name): string
    {
        return preg_replace('/\s+/u', ' ', trim($name)) ?? trim($name);
    }

    private function normalizeStoreName(string $name): string
    {
        $value = $this->displayStoreName($name);
        if (class_exists(\Normalizer::class)) {
            $value = \Normalizer::normalize($value, \Normalizer::FORM_KC) ?: $value;
        }

        return defined('MB_CASE_FOLD')
            ? mb_convert_case($value, MB_CASE_FOLD, 'UTF-8')
            : mb_strtolower($value, 'UTF-8');
    }

    private function moneyAmount(mixed $value, int $fallback): int
    {
        if (is_array($value)) {
            $value = $value['amount'] ?? $fallback;
        }
        if ($value === null || $value === '') {
            return $fallback;
        }

        return (int) $value;
    }

    /**
     * @return array{amount: int, currency: string}
     */
    private function money(int $amount): array
    {
        return ['amount' => $amount, 'currency' => 'THB'];
    }

    private function nullableString(mixed $value): ?string
    {
        $text = trim((string) ($value ?? ''));

        return $text === '' ? null : $text;
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function audit(AdminSessionContext $actor, Request $request, string $action, string $targetType, ?string $targetId, array $payload, string $tenantId): void
    {
        $this->auditLogger->logAdminWrite(
            $actor->adminUser['id'],
            $actor->activeScope(),
            $action,
            $targetType,
            $targetId,
            $payload,
            $tenantId,
            null,
            $request->header('X-Request-Id'),
            $request->ip(),
            $request->userAgent(),
        );
    }
}
