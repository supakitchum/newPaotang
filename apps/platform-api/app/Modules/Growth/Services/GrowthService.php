<?php

namespace App\Modules\Growth\Services;

use App\Models\AffiliateAccount;
use App\Models\AffiliateAttribution;
use App\Models\AffiliateLink;
use App\Models\AffiliatePayout;
use App\Models\AffiliateProgram;
use App\Models\AffiliateTierHistory;
use App\Models\AffiliateTierRateHistory;
use App\Models\Agent;
use App\Models\AgentQuota;
use App\Models\AuditLog;
use App\Models\CommissionRule;
use App\Models\CommissionTransaction;
use App\Models\Customer;
use App\Models\Game;
use App\Models\LocalStockItem;
use App\Models\Order;
use App\Models\PartnerSettlement;
use App\Models\PartnerTenant;
use App\Models\PartnerTenantDomain;
use App\Models\RewardClaim;
use App\Models\ReportExportJob;
use App\Models\StockItem;
use App\Models\SyncOutbox;
use App\Models\Ticket;
use App\Models\WalletLedger;
use App\Modules\Auth\Services\CustomerAuthService;
use App\Modules\Commerce\Services\WalletPostingService;
use App\Modules\Reward\Services\ThaiGovernmentLotteryRewardTemplate;
use App\Modules\CustomerNotifications\Services\CustomerNotificationDomainEventService;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use App\Modules\Rbac\Events\AdminMenuBadgesUpdated;
use App\Modules\TelegramNotifications\Services\CentralTelegramNotificationService;
use App\Support\CustomerNo;
use App\Support\EncryptedJsonPayload;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;
use Illuminate\Support\Str;
use Throwable;

class GrowthService
{
    private const TENANT_REPORT_KEYS = ['overview', 'sales', 'stock', 'wallet', 'topup_channels', 'commission', 'rewards', 'orders', 'customers', 'settlement', 'audit'];
    private const CENTRAL_REPORT_KEYS = ['daily', 'overview', 'sales', 'orders', 'customers', 'stock', 'wallet', 'topup_channels', 'commission', 'rewards', 'settlement', 'partner_usage', 'partners', 'audit'];
    private const CENTRAL_DRAW_REPORT_KEYS = ['daily', 'overview', 'sales', 'orders', 'stock', 'wallet', 'commission', 'rewards'];
    private const TENANT_DRAW_REPORT_KEYS = ['overview', 'sales', 'orders', 'stock', 'wallet', 'commission', 'rewards'];
    private const EXPORT_FORMATS = ['csv', 'xlsx', 'pdf'];
    private const PAYOUT_METHODS = ['bank_transfer', 'manual_cash', 'wallet_credit'];
    private const RULE_TYPES = ['fixed_per_order', 'percent_sales', 'per_ticket'];
    private const AFFILIATE_CODE_LENGTH = 6;
    private const AFFILIATE_CODE_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    private const AFFILIATE_ATTRIBUTION_TTL_DAYS = 30;
    private const STARTER_AFFILIATE_PROGRAM_CODE = 'bronze';
    private const DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT = 30000;

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly IdempotencyService $idempotency,
        private readonly CentralTelegramNotificationService $telegramNotifications,
        private readonly CustomerNotificationDomainEventService $customerNotificationEvents,
        private readonly AffiliateTierService $affiliateTiers,
        private readonly CustomerAuthService $customerAuth,
        private readonly WalletPostingService $walletPosting,
    ) {
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAgents(string $tenantId, array $queryParams): array
    {
        return $this->listTenantRows($tenantId, 'agents', $queryParams, fn (object $row): array => $this->agentResource($row));
    }

    /**
     * @return array<string, mixed>|null
     */
    public function agent(string $tenantId, string $agentId): ?array
    {
        $agent = Agent::query()->forTenant($tenantId)->where('id', $agentId)->first();

        return $agent === null ? null : $this->agentResource($agent, true);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createAgent(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $normalized = $this->normalizeAgentPayload($payload, true);
        $errors = $this->basicNameErrors($normalized, 'name');

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.agents.store',
            'agent.create',
            $normalized,
            function () use ($tenantId, $actor, $request, $normalized): array {
                $tenant = $this->tenantRow($tenantId);

                if ($tenant === null) {
                    return ['error' => 'not_found'];
                }

                if ($this->tenantCodeExists('agents', $tenantId, $normalized['code'])) {
                    return ['error' => 'resource_conflict'];
                }

                $agentId = 'agt_'.Str::ulid()->toBase32();
                $now = now();

                Agent::query()->insert([
                    'id' => $agentId,
                    'tenant_id' => $tenantId,
                    'partner_id' => (string) $tenant->partner_id,
                    'code' => $normalized['code'],
                    'name' => $normalized['name'],
                    'phone' => $normalized['phone'],
                    'email' => $normalized['email'],
                    'store_id' => $normalized['store_id'],
                    'status' => $normalized['status'],
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'agent.created', 'agent', $agentId, $normalized, $tenantId, (string) $tenant->partner_id);

                return ['resource' => $this->agent($tenantId, $agentId) ?? [], 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAgent(string $tenantId, AdminSessionContext $actor, string $agentId, array $payload, Request $request): array
    {
        $normalized = $this->normalizeAgentPayload($payload, false);

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.agents.update:'.$agentId,
            'agent.update',
            $normalized,
            function () use ($tenantId, $actor, $agentId, $request, $normalized): array {
                $agent = Agent::query()->where('tenant_id', $tenantId)->where('id', $agentId)->lockForUpdate()->first();

                if ($agent === null) {
                    return ['error' => 'not_found'];
                }

                if (isset($normalized['code']) && $normalized['code'] !== $agent->code && $this->tenantCodeExists('agents', $tenantId, $normalized['code'], $agentId)) {
                    return ['error' => 'resource_conflict'];
                }

                $updates = $this->onlyPresent($normalized, ['code', 'name', 'phone', 'email', 'store_id', 'status']);

                if (array_key_exists('metadata', $normalized)) {
                    $updates['metadata_json'] = $this->jsonOrNull($normalized['metadata']);
                }

                $updates['updated_at'] = now();
                Agent::query()->where('tenant_id', $tenantId)->where('id', $agentId)->update($updates);
                $this->auditAdmin($actor, $request, 'agent.updated', 'agent', $agentId, $normalized, $tenantId, (string) $agent->partner_id);

                return ['resource' => $this->agent($tenantId, $agentId) ?? [], 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAgentQuotas(string $tenantId, AdminSessionContext $actor, string $agentId, array $payload, Request $request): array
    {
        $normalized = [
            'game_id' => $this->nullableString($payload['game_id'] ?? null),
            'quota_count' => max(0, (int) ($payload['quota_count'] ?? data_get($payload, 'quota.count', 0))),
            'used_count' => max(0, (int) ($payload['used_count'] ?? data_get($payload, 'quota.used_count', 0))),
            'status' => $this->status($payload['status'] ?? 'active'),
            'payload' => is_array($payload['payload'] ?? null) ? $payload['payload'] : (is_array($payload['metadata'] ?? null) ? $payload['metadata'] : []),
        ];

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.agents.quotas:'.$agentId,
            'agent.quota.manage',
            $normalized,
            function () use ($tenantId, $actor, $agentId, $request, $normalized): array {
                $agent = Agent::query()->where('tenant_id', $tenantId)->where('id', $agentId)->lockForUpdate()->first();

                if ($agent === null) {
                    return ['error' => 'not_found'];
                }

                if ($normalized['game_id'] !== null && ! Game::where('id', $normalized['game_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                $quota = AgentQuota::query()
                    ->where('tenant_id', $tenantId)
                    ->where('agent_id', $agentId)
                    ->where('game_id', $normalized['game_id'])
                    ->lockForUpdate()
                    ->first();
                $quotaId = $quota === null ? 'agq_'.Str::ulid()->toBase32() : (string) $quota->id;
                $now = now();

                AgentQuota::query()->updateOrInsert(
                    ['id' => $quotaId],
                    [
                        'tenant_id' => $tenantId,
                        'agent_id' => $agentId,
                        'game_id' => $normalized['game_id'],
                        'quota_count' => $normalized['quota_count'],
                        'used_count' => $normalized['used_count'],
                        'status' => $normalized['status'],
                        'payload_json' => $this->jsonOrNull($normalized['payload']),
                        'updated_by_admin_id' => $actor->adminUser['id'],
                        'created_at' => $quota?->created_at ?? $now,
                        'updated_at' => $now,
                    ],
                );

                $this->auditAdmin($actor, $request, 'agent.quota_updated', 'agent', $agentId, $normalized, $tenantId, (string) $agent->partner_id);

                return ['resource' => $this->agent($tenantId, $agentId) ?? [], 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAffiliateAccounts(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? 'asc')) === 'desc' ? 'desc' : 'asc';
        $sortBy = (string) ($queryParams['sort_by'] ?? 'id');
        $sortColumns = [
            'id' => 'affiliate_accounts.id',
            'code' => 'affiliate_accounts.code',
            'customer_no' => 'customers.customer_no',
            'customer_id' => 'affiliate_accounts.customer_id',
            'customer_name' => 'customers.name',
            'visitor' => DB::raw('visitor_count'),
            'visitor_count' => DB::raw('visitor_count'),
            'registered' => DB::raw('registered_count'),
            'registered_count' => DB::raw('registered_count'),
            'wallet' => 'affiliate_accounts.wallet_balance_amount',
            'wallet_balance.amount' => 'affiliate_accounts.wallet_balance_amount',
            'status' => 'affiliate_accounts.status',
        ];
        $metrics = DB::table('affiliate_referral_visits')
            ->selectRaw('tenant_id, affiliate_account_id, COUNT(*) as visitor_count, COUNT(registered_at) as registered_count')
            ->where('tenant_id', $tenantId)
            ->groupBy('tenant_id', 'affiliate_account_id');
        $query = AffiliateAccount::query()
            ->from('affiliate_accounts')
            ->leftJoin('customers', function ($join) use ($tenantId): void {
                $join->on('customers.id', '=', 'affiliate_accounts.customer_id')
                    ->where('customers.tenant_id', '=', $tenantId);
            })
            ->leftJoinSub($metrics, 'referral_metrics', function ($join): void {
                $join->on('referral_metrics.tenant_id', '=', 'affiliate_accounts.tenant_id')
                    ->on('referral_metrics.affiliate_account_id', '=', 'affiliate_accounts.id');
            })
            ->where('affiliate_accounts.tenant_id', $tenantId)
            ->select([
                'affiliate_accounts.*',
                'customers.customer_no as customer_no',
                'customers.name as customer_name',
                DB::raw('COALESCE(referral_metrics.visitor_count, 0) as visitor_count'),
                DB::raw('COALESCE(referral_metrics.registered_count, 0) as registered_count'),
            ]);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('affiliate_accounts.status', trim((string) $queryParams['status']));
        }

        if (($queryParams['customer_id'] ?? null) !== null && trim((string) $queryParams['customer_id']) !== '') {
            $query->where('affiliate_accounts.customer_id', trim((string) $queryParams['customer_id']));
        }

        if (($queryParams['customer_no'] ?? $queryParams['member_no'] ?? null) !== null && trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no'])) !== '') {
            $query->where('customers.customer_no', 'like', '%'.strtoupper(trim((string) ($queryParams['customer_no'] ?? $queryParams['member_no']))).'%');
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('affiliate_accounts.id', '>', trim((string) $queryParams['cursor']));
        }

        $query->orderBy($sortColumns[$sortBy] ?? 'affiliate_accounts.id', $direction);

        if (($sortColumns[$sortBy] ?? 'affiliate_accounts.id') !== 'affiliate_accounts.id') {
            $query->orderBy('affiliate_accounts.id');
        }

        $rows = $query->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->affiliateAccountResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function affiliateAccount(string $tenantId, string $affiliateId): ?array
    {
        $row = AffiliateAccount::query()->forTenant($tenantId)->where('id', $affiliateId)->first();

        return $row === null ? null : $this->affiliateAccountResource($row, true);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createAffiliateAccount(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $normalized = $this->normalizeAffiliatePayload($payload, true);
        unset($normalized['code']);
        $errors = $this->affiliateTiers->storeNameErrors($tenantId, (string) ($normalized['name'] ?? ''));

        if (($normalized['customer_id'] ?? null) === null) {
            $errors['customer_id'][] = 'The customer_id field is required for affiliate accounts.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliates.store',
            'affiliate.create',
            $normalized,
            function () use ($tenantId, $actor, $request, $normalized): array {
                $customer = Customer::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $normalized['customer_id'])
                    ->lockForUpdate()
                    ->first();
                if ($customer === null) {
                    return ['error' => 'not_found'];
                }

                if ($this->customerAffiliateAccount($tenantId, $normalized['customer_id']) !== null) {
                    return ['error' => 'resource_conflict'];
                }

                $normalizedForWrite = [
                    ...$normalized,
                    'code' => $this->randomAffiliateCode($tenantId),
                ];
                $affiliateId = 'aff_'.Str::ulid()->toBase32();
                $now = now();

                AffiliateAccount::query()->insert([
                    'id' => $affiliateId,
                    'tenant_id' => $tenantId,
                    'customer_id' => $normalized['customer_id'],
                    'affiliate_program_id' => null,
                    'code' => $normalizedForWrite['code'],
                    'name' => $normalized['name'],
                    'store_name_status' => 'pending',
                    'store_name_normalized' => null,
                    'store_name_approved_at' => null,
                    'store_name_change_available_at' => null,
                    'phone' => $normalized['phone'],
                    'email' => $normalized['email'],
                    'status' => $normalized['status'],
                    'wallet_balance_amount' => 0,
                    'currency' => $normalized['currency'],
                    'payout_profile_json' => null,
                    'payout_profile_encrypted' => EncryptedJsonPayload::encrypt($normalized['payout_profile']),
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $affiliate = AffiliateAccount::query()->where('tenant_id', $tenantId)->whereKey($affiliateId)->first();
                if ($affiliate === null || ! $this->affiliateTiers->attachNewAffiliate($affiliate, $normalized['name'])) {
                    return ['error' => 'validation_failed', 'errors' => ['name' => ['The store name has already been taken.']]];
                }
                $this->ensureCustomerAffiliateLink($tenantId, $affiliate->fresh());
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliateRegistered(
                    $tenantId,
                    (string) $normalized['customer_id'],
                    $affiliateId,
                ));

                $this->auditAdmin($actor, $request, 'affiliate.created', 'affiliate_account', $affiliateId, $normalizedForWrite, $tenantId);

                return ['resource' => $this->affiliateAccount($tenantId, $affiliateId) ?? [], 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAffiliateAccount(string $tenantId, AdminSessionContext $actor, string $affiliateId, array $payload, Request $request): array
    {
        $normalized = $this->normalizeAffiliatePayload($payload, false);
        unset($normalized['code']);
        $errors = [];

        if (array_key_exists('customer_id', $normalized) && $normalized['customer_id'] === null) {
            $errors['customer_id'][] = 'The customer_id field is required for affiliate accounts.';
        }

        $current = AffiliateAccount::query()->where('tenant_id', $tenantId)->whereKey($affiliateId)->first();
        if ($current !== null && array_key_exists('name', $normalized) && trim((string) $normalized['name']) !== trim((string) $current->name)) {
            $errors['name'][] = 'Store names must be changed through the affiliate store name review workflow.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliates.update:'.$affiliateId,
            'affiliate.update',
            $normalized,
            function () use ($tenantId, $actor, $affiliateId, $request, $normalized): array {
                $row = AffiliateAccount::query()->where('tenant_id', $tenantId)->where('id', $affiliateId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }

                if (isset($normalized['customer_id']) && $normalized['customer_id'] !== null && ! Customer::where('tenant_id', $tenantId)->where('id', $normalized['customer_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                if (isset($normalized['customer_id']) && $normalized['customer_id'] !== (string) $row->customer_id && $this->customerAffiliateAccount($tenantId, $normalized['customer_id']) !== null) {
                    return ['error' => 'resource_conflict'];
                }

                $updates = $this->onlyPresent($normalized, ['customer_id', 'phone', 'email', 'status', 'currency']);

                if (array_key_exists('payout_profile', $normalized)) {
                    $updates['payout_profile_json'] = null;
                    $updates['payout_profile_encrypted'] = EncryptedJsonPayload::encrypt($normalized['payout_profile']);
                }
                if (array_key_exists('metadata', $normalized)) {
                    $updates['metadata_json'] = $this->jsonOrNull($normalized['metadata']);
                }

                $updates['updated_at'] = now();
                $previousStatus = (string) $row->status;
                $nextStatus = array_key_exists('status', $updates) ? (string) $updates['status'] : $previousStatus;
                AffiliateAccount::query()->where('tenant_id', $tenantId)->where('id', $affiliateId)->update($updates);
                if ($nextStatus !== $previousStatus) {
                    $transitionId = trim((string) $request->header('Idempotency-Key'));
                    if ($transitionId === '') {
                        $transitionId = hash('sha256', $affiliateId.':'.$previousStatus.':'.$nextStatus.':'.now()->format('U.u'));
                    }
                    DB::afterCommit(fn () => $this->customerNotificationEvents->affiliateAccountStatusChanged(
                        $tenantId,
                        $affiliateId,
                        $nextStatus,
                        $transitionId,
                    ));
                }
                $this->auditAdmin($actor, $request, 'affiliate.updated', 'affiliate_account', $affiliateId, $normalized, $tenantId);

                return ['resource' => $this->affiliateAccount($tenantId, $affiliateId) ?? [], 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAffiliatePrograms(string $tenantId, array $queryParams): array
    {
        return $this->listTenantRows($tenantId, 'affiliate_programs', $queryParams, fn (object $row): array => $this->affiliateProgramResource($row));
    }

    public function affiliateProgram(string $tenantId, string $programId): ?array
    {
        $row = AffiliateProgram::query()->forTenant($tenantId)->where('id', $programId)->first();

        return $row === null ? null : $this->affiliateProgramResource($row);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createAffiliateProgram(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $normalized = $this->normalizeProgramPayload($payload, true);
        $errors = $this->basicNameErrors($normalized, 'name');
        $errors = array_merge_recursive($errors, $this->programErrors($normalized));

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate-programs.store',
            'affiliate_program.manage',
            $normalized,
            function () use ($tenantId, $actor, $request, $normalized): array {
                if ($this->tenantCodeExists('affiliate_programs', $tenantId, $normalized['code'])) {
                    return ['error' => 'resource_conflict'];
                }

                $programId = 'afp_'.Str::ulid()->toBase32();
                $now = now();

                AffiliateProgram::query()->insert([
                    'id' => $programId,
                    'tenant_id' => $tenantId,
                    'code' => $normalized['code'],
                    'name' => $normalized['name'],
                    'status' => $normalized['status'],
                    'minimum_payout_amount' => $normalized['minimum_payout_amount'],
                    'starts_at' => $normalized['starts_at'],
                    'ends_at' => $normalized['ends_at'],
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'affiliate_program.created', 'affiliate_program', $programId, $normalized, $tenantId);

                return ['resource' => $this->affiliateProgram($tenantId, $programId) ?? [], 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAffiliateProgram(string $tenantId, AdminSessionContext $actor, string $programId, array $payload, Request $request): array
    {
        $normalized = $this->normalizeProgramPayload($payload, false);
        $errors = $this->programErrors($normalized);

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate-programs.update:'.$programId,
            'affiliate_program.manage',
            $normalized,
            function () use ($tenantId, $actor, $programId, $request, $normalized): array {
                $row = AffiliateProgram::query()->where('tenant_id', $tenantId)->where('id', $programId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }
                if ($row->tier_rank !== null || (bool) (($row->metadata_json ?? [])['system_tier'] ?? false)) {
                    return ['error' => 'resource_conflict'];
                }

                if (isset($normalized['code']) && $normalized['code'] !== $row->code && $this->tenantCodeExists('affiliate_programs', $tenantId, $normalized['code'], $programId)) {
                    return ['error' => 'resource_conflict'];
                }

                $updates = $this->onlyPresent($normalized, ['code', 'name', 'status', 'minimum_payout_amount', 'starts_at', 'ends_at']);

                if (array_key_exists('metadata', $normalized)) {
                    $updates['metadata_json'] = $this->jsonOrNull($normalized['metadata']);
                }

                $updates['updated_at'] = now();
                AffiliateProgram::query()->where('tenant_id', $tenantId)->where('id', $programId)->update($updates);
                $this->auditAdmin($actor, $request, 'affiliate_program.updated', 'affiliate_program', $programId, $normalized, $tenantId);

                return ['resource' => $this->affiliateProgram($tenantId, $programId) ?? [], 'status' => 200];
            },
        );
    }

    /**
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string}
     */
    public function archiveAffiliateProgram(string $tenantId, AdminSessionContext $actor, string $programId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate-programs.archive:'.$programId,
            'affiliate_program.manage',
            $payload,
            function () use ($tenantId, $actor, $programId, $payload, $request): array {
                $row = AffiliateProgram::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $programId)
                    ->lockForUpdate()
                    ->first();
                if ($row === null) {
                    return ['error' => 'not_found'];
                }
                if ($row->tier_rank !== null || (bool) (($row->metadata_json ?? [])['system_tier'] ?? false)) {
                    return ['error' => 'resource_conflict'];
                }
                if ($row->status === 'archived') {
                    return ['resource' => null, 'status' => 204];
                }

                $row->forceFill(['status' => 'archived', 'updated_at' => now()])->save();
                $this->auditAdmin(
                    $actor,
                    $request,
                    'affiliate_program.archived',
                    'affiliate_program',
                    $programId,
                    $payload,
                    $tenantId,
                );

                return ['resource' => null, 'status' => 204];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAffiliateLinks(string $tenantId, array $queryParams): array
    {
        $mapped = $queryParams;

        if (($mapped['affiliate_id'] ?? null) !== null) {
            $mapped['affiliate_account_id'] = $mapped['affiliate_id'];
        }

        return $this->listTenantRows($tenantId, 'affiliate_links', $mapped, fn (object $row): array => $this->affiliateLinkResource($row));
    }

    public function affiliateLink(string $tenantId, string $linkId): ?array
    {
        $row = AffiliateLink::where('tenant_id', $tenantId)->where('id', $linkId)->first();

        return $row === null ? null : $this->affiliateLinkResource($row);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createAffiliateLink(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $normalized = $this->normalizeLinkPayload($payload, true);
        unset($normalized['code'], $normalized['url']);
        $errors = [];

        if ($normalized['affiliate_account_id'] === '') {
            $errors['affiliate_id'][] = 'The affiliate_id field is required.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate-links.store',
            'affiliate_link.manage',
            $normalized,
            function () use ($tenantId, $actor, $request, $normalized): array {
                $relations = $this->validAffiliateLinkRelations($tenantId, $normalized);

                if ($relations !== null) {
                    return ['error' => $relations];
                }

                $code = $this->randomAffiliateCode($tenantId);
                $linkId = 'afl_'.Str::ulid()->toBase32();
                $now = now();
                $programId = $this->currentAffiliateProgramId($tenantId, $normalized['affiliate_account_id']);
                $normalizedForWrite = [
                    ...$normalized,
                    'affiliate_program_id' => $programId,
                    'code' => $code,
                    'url' => $this->affiliateUrl($tenantId, $code),
                ];

                AffiliateLink::query()->insert([
                    'id' => $linkId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $normalized['affiliate_account_id'],
                    'affiliate_program_id' => $programId,
                    'code' => $code,
                    'url' => $normalizedForWrite['url'],
                    'status' => $normalized['status'],
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'affiliate_link.created', 'affiliate_link', $linkId, $normalizedForWrite, $tenantId);

                return ['resource' => $this->affiliateLink($tenantId, $linkId) ?? [], 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAffiliateLink(string $tenantId, AdminSessionContext $actor, string $linkId, array $payload, Request $request): array
    {
        $normalized = $this->normalizeLinkPayload($payload, false);
        unset($normalized['code'], $normalized['url']);

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate-links.update:'.$linkId,
            'affiliate_link.manage',
            $normalized,
            function () use ($tenantId, $actor, $linkId, $request, $normalized): array {
                $row = AffiliateLink::query()->where('tenant_id', $tenantId)->where('id', $linkId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }

                $merged = array_merge([
                    'affiliate_account_id' => (string) $row->affiliate_account_id,
                    'affiliate_program_id' => $row->affiliate_program_id === null ? null : (string) $row->affiliate_program_id,
                ], $normalized);

                $relations = $this->validAffiliateLinkRelations($tenantId, $merged);

                if ($relations !== null) {
                    return ['error' => $relations];
                }

                $updates = $this->onlyPresent($normalized, ['affiliate_account_id', 'status']);
                if (($merged['status'] ?? $row->status) === 'active') {
                    $updates['affiliate_program_id'] = $this->currentAffiliateProgramId($tenantId, $merged['affiliate_account_id']);
                }

                if (array_key_exists('metadata', $normalized)) {
                    $updates['metadata_json'] = $this->jsonOrNull($normalized['metadata']);
                }

                $updates['updated_at'] = now();
                AffiliateLink::query()->where('tenant_id', $tenantId)->where('id', $linkId)->update($updates);
                $this->auditAdmin($actor, $request, 'affiliate_link.updated', 'affiliate_link', $linkId, $normalized, $tenantId);

                return ['resource' => $this->affiliateLink($tenantId, $linkId) ?? [], 'status' => 200];
            },
        );
    }

    /**
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string}
     */
    public function archiveAffiliateLink(string $tenantId, AdminSessionContext $actor, string $linkId, array $payload, Request $request): array
    {
        return $this->archiveTenantRow($tenantId, $actor, $linkId, $payload, $request, 'affiliate_links', 'affiliate_link', 'affiliate_link.manage', 'admin.tenant.affiliate-links.archive', 'affiliate_link.archived');
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAffiliateAttributions(string $tenantId, array $queryParams): array
    {
        $mapped = $queryParams;

        if (($mapped['affiliate_id'] ?? null) !== null) {
            $mapped['affiliate_account_id'] = $mapped['affiliate_id'];
        }

        $query = AffiliateAttribution::query()->where('tenant_id', $tenantId);

        foreach (['status', 'affiliate_account_id', 'customer_id', 'order_id', 'game_id'] as $field) {
            if (($mapped[$field] ?? null) !== null && trim((string) $mapped[$field]) !== '') {
                $query->where($field, trim((string) $mapped[$field]));
            }
        }

        $customerNo = trim((string) ($mapped['customer_no'] ?? $mapped['member_no'] ?? ''));

        if ($customerNo !== '') {
            $customerIds = Customer::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_no', 'ilike', '%'.$customerNo.'%')
                ->pluck('id')
                ->map(fn (mixed $id): string => (string) $id)
                ->all();

            $query->whereIn('customer_id', $customerIds === [] ? ['__no_customer_no_match__'] : $customerIds);
        }

        return $this->paginated($query, $mapped, fn (object $row): array => $this->affiliateAttributionResource($row));
    }

    public function affiliateAttribution(string $tenantId, string $attributionId): ?array
    {
        $row = AffiliateAttribution::where('tenant_id', $tenantId)->where('id', $attributionId)->first();

        return $row === null ? null : $this->affiliateAttributionResource($row);
    }

    /**
     * @return array<string, mixed>
     */
    public function customerAffiliateOverview(string $tenantId, CustomerSessionContext $customer): array
    {
        $affiliate = $this->customerAffiliateAccount($tenantId, $customer->customerId());
        $profile = $this->customerAffiliateProfileResource($tenantId, $customer->customerId());

        if ($affiliate === null) {
            return [
                'is_affiliate' => false,
                'affiliate' => null,
                'links' => [],
                'profile' => $profile,
                'payout_policy' => $this->customerAffiliatePayoutPolicy($tenantId, null),
                'stats' => $this->emptyCustomerAffiliateStats(),
                'commissions' => [],
                'payouts' => [],
            ];
        }

        return [
            'is_affiliate' => true,
            'affiliate' => $this->customerAffiliateAccountResource($affiliate),
            'links' => $this->customerAffiliateLinks((string) $affiliate->tenant_id, (string) $affiliate->id),
            'profile' => $profile,
            'payout_policy' => $this->customerAffiliatePayoutPolicy($tenantId, $affiliate),
            'stats' => $this->customerAffiliateStats($affiliate),
            'commissions' => $this->customerAffiliateCommissionRows((string) $affiliate->tenant_id, (string) $affiliate->id, 5),
            'payouts' => $this->customerAffiliatePayoutRows((string) $affiliate->tenant_id, (string) $affiliate->id, 5),
        ] + $this->affiliateTiers->overviewResource($affiliate);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function registerCustomerAffiliate(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $customerRow = Customer::query()->forTenant($tenantId)->where('id', $customer->customerId())->first();

        if ($customerRow === null) {
            return ['error' => 'not_found'];
        }

        $existing = $this->customerAffiliateAccount($tenantId, $customer->customerId());
        $normalized = [
            'customer_id' => $customer->customerId(),
            'name' => trim((string) ($payload['name'] ?? $payload['store_name'] ?? '')),
            'phone' => $this->nullableString($payload['phone'] ?? $customerRow->phone ?? null),
            'email' => $this->nullableString($payload['email'] ?? $customerRow->email ?? null),
            'status' => 'active',
            'currency' => 'THB',
            'payout_profile' => is_array($payload['payout_profile'] ?? null) ? $payload['payout_profile'] : [],
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ];
        $errors = $existing === null
            ? $this->affiliateTiers->storeNameErrors($tenantId, $normalized['name'])
            : [];

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->customerIdempotentWrite(
            $tenantId,
            $customer->customerId(),
            $request,
            'customer.affiliate.register',
            $normalized,
            function () use ($tenantId, $customer, $normalized): array {
                $customerRow = Customer::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $customer->customerId())
                    ->where('status', 'active')
                    ->lockForUpdate()
                    ->first();
                if ($customerRow === null) {
                    return ['error' => 'not_found'];
                }

                $existing = $this->customerAffiliateAccount($tenantId, $customer->customerId());
                if ($existing !== null) {
                    $this->ensureCustomerAffiliateLink($tenantId, $existing);

                    return ['resource' => $this->customerAffiliateOverview($tenantId, $customer), 'status' => 200];
                }

                $affiliateId = 'aff_'.Str::ulid()->toBase32();
                $code = $this->randomAffiliateCode($tenantId);
                $now = now();

                AffiliateAccount::query()->insert([
                    'id' => $affiliateId,
                    'tenant_id' => $tenantId,
                    'customer_id' => $normalized['customer_id'],
                    'affiliate_program_id' => null,
                    'code' => $code,
                    'name' => $normalized['name'],
                    'store_name_status' => 'pending',
                    'store_name_normalized' => null,
                    'store_name_approved_at' => null,
                    'store_name_change_available_at' => null,
                    'phone' => $normalized['phone'],
                    'email' => $normalized['email'],
                    'status' => $normalized['status'],
                    'wallet_balance_amount' => 0,
                    'currency' => $normalized['currency'],
                    'payout_profile_json' => null,
                    'payout_profile_encrypted' => EncryptedJsonPayload::encrypt($normalized['payout_profile']),
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $affiliate = AffiliateAccount::query()->where('tenant_id', $tenantId)->where('id', $affiliateId)->first();

                if ($affiliate !== null) {
                    if (! $this->affiliateTiers->attachNewAffiliate($affiliate, $normalized['name'])) {
                        return ['error' => 'validation_failed', 'errors' => ['name' => ['The store name has already been taken.']]];
                    }
                    $affiliate = AffiliateAccount::query()->where('tenant_id', $tenantId)->where('id', $affiliateId)->first();
                    $this->ensureCustomerAffiliateLink($tenantId, $affiliate);
                }
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliateRegistered(
                    $tenantId,
                    $customer->customerId(),
                    $affiliateId,
                ));

                return ['resource' => $this->customerAffiliateOverview($tenantId, $customer), 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function requestCustomerAffiliateStoreName(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $normalized = ['name' => trim((string) ($payload['name'] ?? $payload['store_name'] ?? ''))];

        return $this->customerIdempotentWrite(
            $tenantId,
            $customer->customerId(),
            $request,
            'customer.affiliate.store_name.request',
            $normalized,
            fn (): array => $this->affiliateTiers->requestStoreNameChange($tenantId, $customer->customerId(), $normalized),
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function customerAffiliateTierCampaigns(string $tenantId, CustomerSessionContext $customer): array
    {
        return $this->affiliateTiers->customerCampaignList($tenantId, $customer->customerId());
    }

    public function customerAffiliateTierCampaign(string $tenantId, CustomerSessionContext $customer, string $campaignId): ?array
    {
        return $this->affiliateTiers->customerCampaign($tenantId, $customer->customerId(), $campaignId);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAffiliateStoreNameRequests(string $tenantId, array $queryParams): array
    {
        return $this->affiliateTiers->listStoreNameRequests($tenantId, $queryParams);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function reviewAffiliateStoreNameRequest(string $tenantId, AdminSessionContext $actor, string $requestId, bool $approve, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate_store_name_requests.'.($approve ? 'approve' : 'reject'),
            'affiliate_name_review.manage',
            $payload + ['request_id' => $requestId],
            fn (): array => $this->affiliateTiers->reviewStoreNameRequest($tenantId, $actor, $requestId, $approve, $payload, $request),
        );
    }

    /**
     * @return array<string, mixed>
     */
    public function listAffiliateTiers(string $tenantId): array
    {
        return $this->affiliateTiers->listTiers($tenantId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAffiliateTier(string $tenantId, AdminSessionContext $actor, string $code, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate_tiers.update',
            'affiliate_tier.manage',
            $payload + ['code' => $code],
            fn (): array => $this->affiliateTiers->updateTier($tenantId, $actor, $code, $payload, $request),
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listAffiliateTierCampaigns(string $tenantId, array $queryParams): array
    {
        return $this->affiliateTiers->listCampaigns($tenantId, $queryParams);
    }

    public function affiliateTierCampaign(string $tenantId, string $campaignId): ?array
    {
        return $this->affiliateTiers->campaign($tenantId, $campaignId);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createAffiliateTierCampaign(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate_tier_campaigns.store',
            'affiliate_tier_campaign.manage',
            $payload,
            fn (): array => $this->affiliateTiers->createCampaign($tenantId, $actor, $payload, $request),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateAffiliateTierCampaign(string $tenantId, AdminSessionContext $actor, string $campaignId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate_tier_campaigns.update',
            'affiliate_tier_campaign.manage',
            $payload + ['campaign_id' => $campaignId],
            fn (): array => $this->affiliateTiers->updateCampaign($tenantId, $actor, $campaignId, $payload, $request),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function finalizeAffiliateTierCampaign(string $tenantId, AdminSessionContext $actor, string $campaignId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate_tier_campaigns.finalize',
            'affiliate_tier_campaign.manage',
            $payload + ['campaign_id' => $campaignId],
            fn (): array => $this->affiliateTiers->finalizeCampaign($tenantId, $campaignId, $actor, $request),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function cancelAffiliateTierCampaign(string $tenantId, AdminSessionContext $actor, string $campaignId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.affiliate_tier_campaigns.cancel',
            'affiliate_tier_campaign.manage',
            $payload + ['campaign_id' => $campaignId],
            fn (): array => $this->affiliateTiers->cancelCampaign($tenantId, $campaignId, $actor, $request),
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function trackAffiliateReferralVisit(string $tenantId, array $payload, Request $request): array
    {
        $code = trim((string) ($payload['ref'] ?? $payload['code'] ?? ''));
        $errors = [];

        if (! $this->isAffiliateCode($code)) {
            $errors['ref'][] = 'The ref field must be a 6-character Base62 affiliate code.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $resolved = $this->resolveAffiliateReferralCode($tenantId, $code);

        if ($resolved === null) {
            return ['error' => 'not_found'];
        }

        $visit = $this->upsertAffiliateReferralVisit(
            tenantId: $tenantId,
            resolved: $resolved,
            code: $code,
            visitorKey: $this->referralVisitorKey($payload['visitor_id'] ?? null, $request),
            request: $request,
            landingUrl: $this->nullableString($payload['landing_url'] ?? null),
            customerId: null,
            registered: false,
            incrementClick: true,
        );

        return [
            'resource' => [
                'tracked' => true,
                'visit_id' => $visit['id'],
                'affiliate_account_id' => $resolved['affiliate_account_id'],
                'affiliate_link_id' => $resolved['affiliate_link_id'],
            ],
            'status' => $visit['created'] ? 201 : 200,
        ];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function applyCustomerReferral(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $code = trim((string) ($payload['ref'] ?? $payload['code'] ?? ''));
        $errors = [];

        if (! $this->isAffiliateCode($code)) {
            $errors['ref'][] = 'The ref field must be a 6-character Base62 affiliate code.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $normalized = [
            'ref' => $code,
            'visitor_id' => trim((string) ($payload['visitor_id'] ?? '')),
            'registered' => filter_var($payload['registered'] ?? false, FILTER_VALIDATE_BOOLEAN),
            'landing_url' => $this->nullableString($payload['landing_url'] ?? null),
        ];

        return $this->customerIdempotentWrite(
            $tenantId,
            $customer->customerId(),
            $request,
            'customer.affiliate.referrals.apply',
            $normalized,
            function () use ($tenantId, $customer, $code, $normalized, $request): array {
            if (! Customer::query()->where('tenant_id', $tenantId)->where('id', $customer->customerId())->where('status', 'active')->exists()) {
                return ['error' => 'not_found'];
            }

            $resolved = $this->resolveAffiliateReferralCode($tenantId, $code);

            if ($resolved === null) {
                return ['error' => 'not_found'];
            }
            $affiliateOwnerId = AffiliateAccount::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $resolved['affiliate_account_id'])
                ->value('customer_id');
            if ($affiliateOwnerId !== null && (string) $affiliateOwnerId === $customer->customerId()) {
                return ['error' => 'validation_failed', 'errors' => [
                    'ref' => ['An Affiliate referral cannot be applied to its owner.'],
                ]];
            }

            $now = now();
            $expiresAt = $now->copy()->addDays(self::AFFILIATE_ATTRIBUTION_TTL_DAYS);
            $metadata = [
                'source' => 'ref',
                'ref_code' => $code,
                'resolved_from' => $resolved['source'],
                'ttl_days' => self::AFFILIATE_ATTRIBUTION_TTL_DAYS,
                'expires_at' => $expiresAt->toISOString(),
                'canonical_url' => $this->affiliateUrl($tenantId, $code),
            ];
            $attribution = AffiliateAttribution::query()
                ->where('tenant_id', $tenantId)
                ->where('customer_id', $customer->customerId())
                ->where('status', 'pending')
                ->whereNull('order_id')
                ->orderByDesc('attributed_at')
                ->orderByDesc('created_at')
                ->lockForUpdate()
                ->first();
            $status = 200;

            if ($attribution === null) {
                $attributionId = 'aat_'.Str::ulid()->toBase32();
                $status = 201;

                AffiliateAttribution::query()->insert([
                    'id' => $attributionId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $resolved['affiliate_account_id'],
                    'affiliate_link_id' => $resolved['affiliate_link_id'],
                    'affiliate_program_id' => $resolved['affiliate_program_id'],
                    'customer_id' => $customer->customerId(),
                    'order_id' => null,
                    'status' => 'pending',
                    'attributed_at' => $now,
                    'converted_at' => null,
                    'metadata_json' => $this->jsonOrNull($metadata),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
            } else {
                $attributionId = (string) $attribution->id;

                AffiliateAttribution::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $attributionId)
                    ->update([
                        'affiliate_account_id' => $resolved['affiliate_account_id'],
                        'affiliate_link_id' => $resolved['affiliate_link_id'],
                        'affiliate_program_id' => $resolved['affiliate_program_id'],
                        'order_id' => null,
                        'status' => 'pending',
                        'attributed_at' => $now,
                        'converted_at' => null,
                        'metadata_json' => $this->jsonOrNull($metadata),
                        'updated_at' => $now,
                    ]);
            }

            $registeredViaRef = (bool) $normalized['registered'];
            $visitorId = (string) $normalized['visitor_id'];

            if ($visitorId !== '' || $registeredViaRef) {
                $this->upsertAffiliateReferralVisit(
                    tenantId: $tenantId,
                    resolved: $resolved,
                    code: $code,
                    visitorKey: $visitorId === '' ? 'customer:'.$customer->customerId() : $this->referralVisitorKey($visitorId, $request),
                    request: $request,
                    landingUrl: $normalized['landing_url'],
                    customerId: $customer->customerId(),
                    registered: $registeredViaRef,
                    incrementClick: false,
                );
            }

            return [
                'resource' => [
                    'applied' => true,
                    'ref' => $code,
                    'expires_at' => $expiresAt->toISOString(),
                    'attribution' => $this->affiliateAttribution($tenantId, $attributionId) ?? [],
                ],
                'status' => $status,
            ];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function customerAffiliateCommissions(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $affiliate = $this->customerAffiliateAccount($tenantId, $customer->customerId());

        if ($affiliate === null) {
            return ['data' => [], 'meta' => ['next_cursor' => null, 'has_more' => false]];
        }

        $query = CommissionTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliate->id);

        foreach (['status', 'transaction_type', 'order_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->commissionTransactionResource($row));
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function customerAffiliatePayouts(string $tenantId, CustomerSessionContext $customer, array $queryParams): array
    {
        $affiliate = $this->customerAffiliateAccount($tenantId, $customer->customerId());

        if ($affiliate === null) {
            return ['data' => [], 'meta' => ['next_cursor' => null, 'has_more' => false]];
        }

        $query = AffiliatePayout::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliate->id);

        if (($queryParams['status'] ?? null) !== null && trim((string) $queryParams['status']) !== '') {
            $query->where('status', trim((string) $queryParams['status']));
        }

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->payoutResource($row));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createCustomerAffiliatePayout(string $tenantId, CustomerSessionContext $customer, array $payload, Request $request): array
    {
        $affiliate = $this->customerAffiliateAccount($tenantId, $customer->customerId());

        if ($affiliate === null) {
            return ['error' => 'not_found'];
        }

        $normalized = [
            'affiliate_account_id' => (string) $affiliate->id,
            'amount' => $this->moneyAmount($payload['amount'] ?? 0),
            'currency' => strtoupper((string) $affiliate->currency),
            'payout_method' => (string) ($payload['payout_method'] ?? 'bank_transfer'),
            'bank_account' => $this->normalizeBankAccount($payload['bank_account'] ?? null),
            'admin_note' => $this->nullableString($payload['note'] ?? null),
        ];
        $errors = [];
        $requestedCurrency = $this->moneyCurrency($payload['amount'] ?? null);

        if ($normalized['amount'] <= 0) {
            $errors['amount'][] = 'The amount field must be greater than zero.';
        }

        if (! in_array($normalized['payout_method'], ['bank_transfer', 'wallet_credit'], true)) {
            $errors['payout_method'][] = 'The payout_method field is invalid.';
        }
        if ($requestedCurrency !== $normalized['currency']) {
            $errors['amount'][] = 'The payout currency must match the Affiliate account currency.';
        }
        if ($normalized['payout_method'] === 'wallet_credit' && $normalized['currency'] !== 'THB') {
            $errors['payout_method'][] = 'Wallet credit payouts require THB currency.';
        }

        if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($normalized['bank_account'])) {
            $normalized['bank_account'] = $this->customerRewardPayoutBankAccount($tenantId, $customer->customerId());
        }

        if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($normalized['bank_account'])) {
            $errors['bank_account'][] = 'Please save a reward payout bank account before requesting an affiliate bank transfer.';
        }

        $minimumPayout = $this->customerAffiliateMinimumPayoutAmount($tenantId, $affiliate);

        if ($normalized['amount'] > 0 && $normalized['amount'] < $minimumPayout) {
            $errors['amount'][] = 'The amount field must be at least the affiliate program minimum payout amount.';
        }

        $available = (int) $this->customerAffiliateStats($affiliate)['available_balance']['amount'];

        if ($normalized['amount'] > $available) {
            $errors['amount'][] = 'The amount field exceeds available affiliate balance.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->customerIdempotentWrite(
            $tenantId,
            $customer->customerId(),
            $request,
            'customer.affiliate.payouts.store',
            $normalized,
            function () use ($tenantId, $customer, $affiliate, $normalized): array {
                $lockedAffiliate = AffiliateAccount::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $affiliate->id)
                    ->where('status', '!=', 'archived')
                    ->lockForUpdate()
                    ->first();
                if ($lockedAffiliate === null) {
                    return ['error' => 'not_found'];
                }
                $minimumPayout = $this->customerAffiliateMinimumPayoutAmount($tenantId, $lockedAffiliate);
                if ($normalized['amount'] < $minimumPayout) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'amount' => ['The amount field must be at least the affiliate program minimum payout amount.'],
                    ]];
                }
                $available = $this->affiliateAvailableBalance(
                    $tenantId,
                    (string) $lockedAffiliate->id,
                );
                if ($normalized['amount'] > $available) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'amount' => ['The amount field exceeds available affiliate balance.'],
                    ]];
                }

                $payoutId = 'pyo_'.Str::ulid()->toBase32();
                $now = now();

                if ($normalized['payout_method'] === 'bank_transfer' && $this->hasUsableBankAccount($normalized['bank_account'])) {
                    $this->storeCustomerRewardPayoutBankAccount($tenantId, $customer->customerId(), $normalized['bank_account']);
                }

                AffiliatePayout::query()->insert([
                    'id' => $payoutId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $normalized['affiliate_account_id'],
                    'status' => 'pending',
                    'payout_method' => $normalized['payout_method'],
                    'amount' => $normalized['amount'],
                    'currency' => $normalized['currency'],
                    'bank_account_json' => null,
                    'bank_account_encrypted' => EncryptedJsonPayload::encrypt($normalized['bank_account']),
                    'admin_note' => $normalized['admin_note'],
                    'idempotency_key' => null,
                    'payload_hash' => null,
                    'requested_by_admin_id' => null,
                    'approved_by_admin_id' => null,
                    'approved_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $resource = $this->payoutResource(AffiliatePayout::query()->where('tenant_id', $tenantId)->where('id', $payoutId)->first());
                $this->telegramNotifications->enqueue($tenantId, 'commission.submitted', 'affiliate_payout', $payoutId, $this->telegramPayoutVariables($tenantId, $resource));
                $this->queueTenantMenuBadgeBroadcast($tenantId, 'commission_transactions');
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliatePayoutUpdated($tenantId, $payoutId));

                return ['resource' => $resource, 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listCommissionRules(string $tenantId, array $queryParams): array
    {
        return $this->listTenantRows($tenantId, 'commission_rules', $queryParams, fn (object $row): array => $this->commissionRuleResource($row));
    }

    public function commissionRule(string $tenantId, string $ruleId): ?array
    {
        $row = CommissionRule::where('tenant_id', $tenantId)->where('id', $ruleId)->first();

        return $row === null ? null : $this->commissionRuleResource($row);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createCommissionRule(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $normalized = $this->normalizeCommissionRulePayload($payload, true);
        $errors = $this->commissionRuleErrors($normalized);
        if (($normalized['rule_type'] ?? null) === 'per_ticket') {
            $errors['rule_type'][] = 'Per-ticket commission is managed through Affiliate Tiers.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.commission-rules.store',
            'commission_rule.manage',
            $normalized,
            function () use ($tenantId, $actor, $request, $normalized): array {
                if ($this->tenantCodeExists('commission_rules', $tenantId, $normalized['code'])) {
                    return ['error' => 'resource_conflict'];
                }

                $relations = $this->validCommissionRuleRelations($tenantId, $normalized);

                if ($relations !== null) {
                    return ['error' => $relations];
                }

                $ruleId = 'cmr_'.Str::ulid()->toBase32();
                $now = now();

                CommissionRule::query()->insert([
                    'id' => $ruleId,
                    'tenant_id' => $tenantId,
                    'affiliate_program_id' => $normalized['affiliate_program_id'],
                    'affiliate_account_id' => $normalized['affiliate_account_id'],
                    'code' => $normalized['code'],
                    'name' => $normalized['name'],
                    'rule_type' => $normalized['rule_type'],
                    'amount' => $normalized['amount'],
                    'rate_bps' => $normalized['rate_bps'],
                    'currency' => $normalized['currency'],
                    'status' => $normalized['status'],
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'commission_rule.created', 'commission_rule', $ruleId, $normalized, $tenantId);

                return ['resource' => $this->commissionRule($tenantId, $ruleId) ?? [], 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function updateCommissionRule(string $tenantId, AdminSessionContext $actor, string $ruleId, array $payload, Request $request): array
    {
        $normalized = $this->normalizeCommissionRulePayload($payload, false);

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.commission-rules.update:'.$ruleId,
            'commission_rule.manage',
            $normalized,
            function () use ($tenantId, $actor, $ruleId, $request, $normalized): array {
                $row = CommissionRule::query()->where('tenant_id', $tenantId)->where('id', $ruleId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }
                if ((bool) (($row->metadata_json ?? [])['system_tier'] ?? false)) {
                    return ['error' => 'resource_conflict'];
                }

                $merged = array_merge([
                    'name' => (string) $row->name,
                    'code' => (string) $row->code,
                    'rule_type' => (string) $row->rule_type,
                    'amount' => (int) $row->amount,
                    'rate_bps' => (int) $row->rate_bps,
                    'affiliate_program_id' => $row->affiliate_program_id === null ? null : (string) $row->affiliate_program_id,
                    'affiliate_account_id' => $row->affiliate_account_id === null ? null : (string) $row->affiliate_account_id,
                ], $normalized);
                $errors = $this->commissionRuleErrors($merged);
                if (($merged['rule_type'] ?? null) === 'per_ticket') {
                    $errors['rule_type'][] = 'Per-ticket commission is managed through Affiliate Tiers.';
                }

                if ($errors !== []) {
                    return ['error' => 'validation_failed', 'errors' => $errors];
                }

                if (isset($normalized['code']) && $normalized['code'] !== $row->code && $this->tenantCodeExists('commission_rules', $tenantId, $normalized['code'], $ruleId)) {
                    return ['error' => 'resource_conflict'];
                }

                $relations = $this->validCommissionRuleRelations($tenantId, $merged);

                if ($relations !== null) {
                    return ['error' => $relations];
                }

                $updates = $this->onlyPresent($normalized, ['affiliate_program_id', 'affiliate_account_id', 'code', 'name', 'rule_type', 'amount', 'rate_bps', 'currency', 'status']);

                if (array_key_exists('metadata', $normalized)) {
                    $updates['metadata_json'] = $this->jsonOrNull($normalized['metadata']);
                }

                $updates['updated_at'] = now();
                CommissionRule::query()->where('tenant_id', $tenantId)->where('id', $ruleId)->update($updates);
                $this->auditAdmin($actor, $request, 'commission_rule.updated', 'commission_rule', $ruleId, $normalized, $tenantId);

                return ['resource' => $this->commissionRule($tenantId, $ruleId) ?? [], 'status' => 200];
            },
        );
    }

    /**
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string}
     */
    public function archiveCommissionRule(string $tenantId, AdminSessionContext $actor, string $ruleId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.commission-rules.archive:'.$ruleId,
            'commission_rule.manage',
            $payload,
            function () use ($tenantId, $actor, $ruleId, $payload, $request): array {
                $row = CommissionRule::query()->where('tenant_id', $tenantId)->whereKey($ruleId)->lockForUpdate()->first();
                if ($row === null) {
                    return ['error' => 'not_found'];
                }
                if ((bool) (($row->metadata_json ?? [])['system_tier'] ?? false)) {
                    return ['error' => 'resource_conflict'];
                }
                $row->forceFill(['status' => 'archived', 'updated_at' => now()])->save();
                $this->auditAdmin($actor, $request, 'commission_rule.archived', 'commission_rule', $ruleId, $payload, $tenantId);

                return ['resource' => null, 'status' => 204];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listCommissionTransactions(string $tenantId, array $queryParams): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);
        $direction = strtolower((string) ($queryParams['sort_dir'] ?? 'desc')) === 'asc' ? 'asc' : 'desc';
        $sortBy = (string) ($queryParams['sort_by'] ?? 'calculated_at');
        $sortColumns = [
            'id' => 'commission_transactions.id',
            'receiver_customer' => 'affiliate_accounts.customer_id',
            'receiver_customer.id' => 'affiliate_accounts.customer_id',
            'receiver_customer_no' => 'receiver_customers.customer_no',
            'receiver_member_no' => 'receiver_customers.customer_no',
            'receiver_user_id' => 'affiliate_accounts.customer_id',
            'affiliate_customer_id' => 'affiliate_accounts.customer_id',
            'buyer_customer' => 'orders.customer_id',
            'buyer_customer.id' => 'orders.customer_id',
            'buyer_customer_no' => 'buyer_customers.customer_no',
            'buyer_member_no' => 'buyer_customers.customer_no',
            'buyer_user_id' => 'orders.customer_id',
            'buyer_customer_id' => 'orders.customer_id',
            'amount' => 'commission_transactions.amount',
            'status' => 'commission_transactions.status',
            'calculated' => 'commission_transactions.calculated_at',
            'calculated_at' => 'commission_transactions.calculated_at',
            'approved_at' => 'commission_transactions.approved_at',
        ];
        $sortColumn = $sortColumns[$sortBy] ?? 'commission_transactions.calculated_at';
        $query = $this->commissionTransactionAdminQuery($tenantId);

        foreach (['status', 'affiliate_account_id', 'order_id', 'commission_rule_id', 'transaction_type'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where('commission_transactions.'.$field, trim((string) $queryParams[$field]));
            }
        }

        $receiverCustomerNo = trim((string) ($queryParams['receiver_customer_no'] ?? $queryParams['receiver_member_no'] ?? ''));
        if ($receiverCustomerNo !== '') {
            $query->where('receiver_customers.customer_no', 'like', '%'.strtoupper($receiverCustomerNo).'%');
        } else {
            $receiverUserId = trim((string) ($queryParams['receiver_user_id'] ?? $queryParams['affiliate_customer_id'] ?? ''));
            if ($receiverUserId !== '') {
                $query->where('affiliate_accounts.customer_id', 'like', '%'.$receiverUserId.'%');
            }
        }

        $buyerCustomerNo = trim((string) ($queryParams['buyer_customer_no'] ?? $queryParams['buyer_member_no'] ?? ''));
        if ($buyerCustomerNo !== '') {
            $query->where('buyer_customers.customer_no', 'like', '%'.strtoupper($buyerCustomerNo).'%');
        } else {
            $buyerUserId = trim((string) ($queryParams['buyer_user_id'] ?? $queryParams['buyer_customer_id'] ?? ''));
            if ($buyerUserId !== '') {
                $query->where('orders.customer_id', 'like', '%'.$buyerUserId.'%');
            }
        }

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('commission_transactions.id', $direction === 'desc' ? '<' : '>', trim((string) $queryParams['cursor']));
        }

        $query->orderBy($sortColumn, $direction);

        if ($sortColumn !== 'commission_transactions.id') {
            $query->orderBy('commission_transactions.id', $direction);
        }

        $rows = $query->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map(fn (object $row): array => $this->commissionTransactionResource($row), $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    /**
     * @return array<string, mixed>|null
     */
    public function commissionTransaction(string $tenantId, string $commissionId): ?array
    {
        $row = $this->commissionTransactionAdminQuery($tenantId)
            ->where('commission_transactions.id', $commissionId)
            ->first();

        return $row === null ? null : $this->commissionTransactionResource($row);
    }

    private function commissionTransactionAdminQuery(string $tenantId): mixed
    {
        return CommissionTransaction::query()
            ->from('commission_transactions')
            ->leftJoin('affiliate_accounts', function ($join) use ($tenantId): void {
                $join->on('affiliate_accounts.id', '=', 'commission_transactions.affiliate_account_id')
                    ->where('affiliate_accounts.tenant_id', '=', $tenantId);
            })
            ->leftJoin('customers as receiver_customers', function ($join) use ($tenantId): void {
                $join->on('receiver_customers.id', '=', 'affiliate_accounts.customer_id')
                    ->where('receiver_customers.tenant_id', '=', $tenantId);
            })
            ->leftJoin('orders', function ($join) use ($tenantId): void {
                $join->on('orders.id', '=', 'commission_transactions.order_id')
                    ->where('orders.tenant_id', '=', $tenantId);
            })
            ->leftJoin('customers as buyer_customers', function ($join) use ($tenantId): void {
                $join->on('buyer_customers.id', '=', 'orders.customer_id')
                    ->where('buyer_customers.tenant_id', '=', $tenantId);
            })
            ->where('commission_transactions.tenant_id', $tenantId)
            ->select([
                'commission_transactions.*',
                'affiliate_accounts.customer_id as receiver_customer_id',
                'affiliate_accounts.name as receiver_affiliate_name',
                'receiver_customers.customer_no as receiver_customer_no',
                'receiver_customers.name as receiver_customer_name',
                'receiver_customers.phone as receiver_customer_phone',
                'receiver_customers.email as receiver_customer_email',
                'orders.customer_id as buyer_customer_id',
                'buyer_customers.customer_no as buyer_customer_no',
                'buyer_customers.name as buyer_customer_name',
                'buyer_customers.phone as buyer_customer_phone',
                'buyer_customers.email as buyer_customer_email',
            ]);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function approveCommissionTransaction(string $tenantId, AdminSessionContext $actor, string $commissionId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.commission-transactions.approve:'.$commissionId,
            'commission.approve',
            $payload,
            function () use ($tenantId, $actor, $commissionId, $payload, $request): array {
                $row = CommissionTransaction::query()->where('tenant_id', $tenantId)->where('id', $commissionId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }

                if ($row->status === 'approved') {
                    return ['resource' => $this->commissionTransaction($tenantId, $commissionId) ?? $this->commissionTransactionResource($row), 'status' => 200];
                }

                if ($row->status !== 'calculated' || $row->transaction_type !== 'commission') {
                    return ['error' => 'resource_conflict'];
                }

                CommissionTransaction::query()->where('tenant_id', $tenantId)->where('id', $commissionId)->update([
                    'status' => 'approved',
                    'approved_by_admin_id' => $actor->adminUser['id'],
                    'approved_at' => now(),
                    'metadata_json' => $this->mergeJson($row->metadata_json, ['approval_note' => $payload['note'] ?? $payload['reason'] ?? null]),
                    'updated_at' => now(),
                ]);

                $resource = $this->commissionTransaction($tenantId, $commissionId) ?? [];
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliateCommissionAvailable(
                    $tenantId,
                    (string) $row->affiliate_account_id,
                    $commissionId,
                ));
                $this->auditAdmin($actor, $request, 'commission.approved', 'commission_transaction', $commissionId, $payload, $tenantId);

                return ['resource' => $resource, 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listPayouts(string $tenantId, array $queryParams): array
    {
        $query = AffiliatePayout::query()->where('tenant_id', $tenantId);

        foreach (['status', 'affiliate_account_id', 'payout_method'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        if (($queryParams['affiliate_id'] ?? null) !== null && trim((string) $queryParams['affiliate_id']) !== '') {
            $query->where('affiliate_account_id', trim((string) $queryParams['affiliate_id']));
        }

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->payoutResource($row, true));
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createPayout(string $tenantId, AdminSessionContext $actor, array $payload, Request $request): array
    {
        $payoutMethod = (string) ($payload['payout_method'] ?? 'bank_transfer');
        $normalized = [
            'affiliate_account_id' => trim((string) ($payload['affiliate_account_id'] ?? $payload['affiliate_id'] ?? '')),
            'amount' => $this->moneyAmount($payload['amount'] ?? 0),
            'currency' => $this->moneyCurrency($payload['amount'] ?? null),
            'payout_method' => $payoutMethod,
            'bank_account' => $this->normalizeBankAccount(
                is_array($payload['bank_account'] ?? null)
                    ? $payload['bank_account']
                    : $payload['bank_account_json'] ?? null,
            ),
            'admin_note' => $this->nullableString($payload['admin_note'] ?? $payload['note'] ?? null),
        ];
        $errors = [];

        if ($normalized['affiliate_account_id'] === '') {
            $errors['affiliate_id'][] = 'The affiliate_id field is required.';
        }

        if ($normalized['amount'] <= 0) {
            $errors['amount'][] = 'The amount field must be greater than zero.';
        }

        if (! in_array($normalized['payout_method'], self::PAYOUT_METHODS, true)) {
            $errors['payout_method'][] = 'The payout_method field is invalid.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.payouts.store',
            'payout.manage',
            $normalized,
            function () use ($tenantId, $actor, $request, $normalized): array {
                $affiliate = AffiliateAccount::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $normalized['affiliate_account_id'])
                    ->where('status', '!=', 'archived')
                    ->lockForUpdate()
                    ->first();
                if ($affiliate === null) {
                    return ['error' => 'not_found'];
                }
                if (strtoupper((string) $affiliate->currency) !== $normalized['currency']) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'amount' => ['The payout currency must match the Affiliate account currency.'],
                    ]];
                }
                if ($normalized['payout_method'] === 'wallet_credit' && $normalized['currency'] !== 'THB') {
                    return ['error' => 'validation_failed', 'errors' => [
                        'payout_method' => ['Wallet credit payouts require THB currency.'],
                    ]];
                }
                $bankAccount = $normalized['bank_account'];
                if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($bankAccount)) {
                    $payoutProfile = $this->affiliatePayoutProfile($affiliate);
                    $bankAccount = $this->normalizeBankAccount(
                        $payoutProfile['bank_account'] ?? $payoutProfile,
                    );
                }
                if (
                    $normalized['payout_method'] === 'bank_transfer'
                    && ! $this->hasUsableBankAccount($bankAccount)
                    && trim((string) $affiliate->customer_id) !== ''
                ) {
                    $bankAccount = $this->normalizeBankAccount(
                        $this->customerRewardPayoutBankAccount($tenantId, (string) $affiliate->customer_id),
                    );
                }
                if ($normalized['payout_method'] === 'bank_transfer' && ! $this->hasUsableBankAccount($bankAccount)) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'bank_account' => ['A bank name and account number are required for a bank transfer payout.'],
                    ]];
                }
                if ($normalized['amount'] > $this->affiliateAvailableBalance($tenantId, (string) $affiliate->id)) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'amount' => ['The amount field exceeds available affiliate balance.'],
                    ]];
                }

                $payoutId = 'pyo_'.Str::ulid()->toBase32();
                $idempotencyKey = (string) $request->header('Idempotency-Key');
                $now = now();

                AffiliatePayout::query()->insert([
                    'id' => $payoutId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $normalized['affiliate_account_id'],
                    'status' => 'pending',
                    'payout_method' => $normalized['payout_method'],
                    'amount' => $normalized['amount'],
                    'currency' => $normalized['currency'],
                    'bank_account_json' => null,
                    'bank_account_encrypted' => EncryptedJsonPayload::encrypt($bankAccount),
                    'admin_note' => $normalized['admin_note'],
                    'idempotency_key' => $idempotencyKey,
                    'payload_hash' => $this->idempotency->payloadHash($normalized),
                    'requested_by_admin_id' => $actor->adminUser['id'],
                    'approved_by_admin_id' => null,
                    'approved_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin(
                    $actor,
                    $request,
                    'payout.created',
                    'affiliate_payout',
                    $payoutId,
                    [...$normalized, 'bank_account' => $bankAccount],
                    $tenantId,
                );

                $resource = $this->payoutResource(AffiliatePayout::where('id', $payoutId)->first(), true);
                $this->telegramNotifications->enqueue($tenantId, 'commission.submitted', 'affiliate_payout', $payoutId, $this->telegramPayoutVariables($tenantId, $resource));
                $this->queueTenantMenuBadgeBroadcast($tenantId, 'commission_transactions');
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliatePayoutUpdated($tenantId, $payoutId));

                return ['resource' => $resource, 'status' => 201];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function approvePayout(string $tenantId, AdminSessionContext $actor, string $payoutId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.payouts.approve:'.$payoutId,
            'payout.manage',
            $payload,
            function () use ($tenantId, $actor, $payoutId, $payload, $request): array {
                $row = AffiliatePayout::query()->where('tenant_id', $tenantId)->where('id', $payoutId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }

                if (in_array((string) $row->status, ['approved', 'paid'], true)) {
                    return ['resource' => $this->payoutResource($row, true), 'status' => 200];
                }

                if ($row->status !== 'pending') {
                    return ['error' => 'resource_conflict'];
                }
                $affiliate = AffiliateAccount::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $row->affiliate_account_id)
                    ->where('status', '!=', 'archived')
                    ->lockForUpdate()
                    ->first();
                if ($affiliate === null) {
                    return ['error' => 'not_found'];
                }
                if ((int) $row->amount > $this->affiliateAvailableBalance(
                    $tenantId,
                    (string) $affiliate->id,
                    (string) $row->id,
                )) {
                    return ['error' => 'resource_conflict'];
                }

                $approvedAt = now();
                $status = 'approved';
                $walletId = null;
                $ledger = null;
                $paymentReference = null;
                if ((string) $row->payout_method === 'wallet_credit') {
                    $customerId = trim((string) $affiliate->customer_id);
                    if ($customerId === '' || strtoupper((string) $row->currency) !== 'THB') {
                        return ['error' => 'resource_conflict'];
                    }
                    $walletId = $this->customerAuth->ensurePrimaryWallet($tenantId, $customerId);
                    $ledger = $this->walletPosting->post(
                        $tenantId,
                        $walletId,
                        $customerId,
                        'credit',
                        (int) $row->amount,
                        'affiliate_payout',
                        (string) $row->id,
                        'affiliate-payout:'.(string) $row->id,
                        (string) $actor->adminUser['id'],
                        [
                            'affiliate_account_id' => (string) $affiliate->id,
                            'payout_method' => 'wallet_credit',
                        ],
                    );
                    $this->insertAffiliateWalletOutbox(
                        $tenantId,
                        $customerId,
                        $walletId,
                        (string) $row->id,
                        (int) $row->amount,
                        $ledger,
                        $request,
                    );
                    $status = 'paid';
                    $paymentReference = (string) $ledger['id'];
                }

                AffiliatePayout::query()->where('tenant_id', $tenantId)->where('id', $payoutId)->update([
                    'status' => $status,
                    'wallet_id' => $walletId,
                    'payout_ledger_id' => $ledger['id'] ?? null,
                    'payment_reference' => $paymentReference,
                    'approved_by_admin_id' => $actor->adminUser['id'],
                    'approved_at' => $approvedAt,
                    'paid_by_admin_id' => $status === 'paid' ? $actor->adminUser['id'] : null,
                    'paid_at' => $status === 'paid' ? $approvedAt : null,
                    'admin_note' => $payload['note'] ?? $payload['reason'] ?? $row->admin_note,
                    'updated_at' => $approvedAt,
                ]);

                $resource = $this->payoutResource(AffiliatePayout::where('id', $payoutId)->first(), true);
                $this->auditAdmin($actor, $request, 'payout.approved', 'affiliate_payout', $payoutId, $payload, $tenantId);
                $statusLabel = $status === 'paid' ? 'จ่ายเข้ากระเป๋าแล้ว' : 'อนุมัติแล้ว';
                $this->telegramNotifications->enqueue($tenantId, 'commission.status_updated', 'affiliate_payout', $payoutId, $this->telegramPayoutVariables($tenantId, $resource, $statusLabel, $actor->adminUser));
                $this->queueTenantMenuBadgeBroadcast($tenantId, 'commission_transactions');
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliatePayoutUpdated($tenantId, $payoutId));

                return ['resource' => $resource, 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function payPayout(string $tenantId, AdminSessionContext $actor, string $payoutId, array $payload, Request $request): array
    {
        $paymentReference = trim((string) (
            $payload['payment_reference']
            ?? $payload['transfer_reference']
            ?? $payload['reference']
            ?? ''
        ));
        $normalized = [
            'payment_reference' => $paymentReference,
            'reason' => $this->nullableString($payload['reason'] ?? $payload['note'] ?? null),
        ];

        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.payouts.pay:'.$payoutId,
            'payout.manage',
            $normalized,
            function () use ($tenantId, $actor, $payoutId, $normalized, $request): array {
                $row = AffiliatePayout::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $payoutId)
                    ->lockForUpdate()
                    ->first();
                if ($row === null) {
                    return ['error' => 'not_found'];
                }
                if ((string) $row->status === 'paid') {
                    if ((string) ($row->payment_reference ?? '') !== $normalized['payment_reference']) {
                        return ['error' => 'resource_conflict'];
                    }

                    return ['resource' => $this->payoutResource($row, true), 'status' => 200];
                }
                if ((string) $row->status !== 'approved' || (string) $row->payout_method === 'wallet_credit') {
                    return ['error' => 'resource_conflict'];
                }
                if (
                    (string) $row->payout_method === 'bank_transfer'
                    && ! $this->hasUsableBankAccount($this->affiliatePayoutBankAccount($row))
                ) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'bank_account' => ['The payout does not have a valid bank account snapshot.'],
                    ]];
                }
                $this->lockAffiliatePaymentReference(
                    $tenantId,
                    (string) $row->payout_method,
                    $normalized['payment_reference'],
                );
                if (AffiliatePayout::query()
                    ->where('tenant_id', $tenantId)
                    ->where('payout_method', $row->payout_method)
                    ->where('payment_reference', $normalized['payment_reference'])
                    ->where('id', '!=', $payoutId)
                    ->exists()) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'payment_reference' => ['The payment_reference has already been used for another payout.'],
                    ]];
                }

                $paidAt = now();
                $row->forceFill([
                    'status' => 'paid',
                    'payment_reference' => $normalized['payment_reference'],
                    'paid_by_admin_id' => $actor->adminUser['id'],
                    'paid_at' => $paidAt,
                    'admin_note' => $normalized['reason'] ?? $row->admin_note,
                    'updated_at' => $paidAt,
                ])->save();

                $resource = $this->payoutResource($row->fresh(), true);
                $this->auditAdmin($actor, $request, 'payout.paid', 'affiliate_payout', $payoutId, $normalized, $tenantId);
                $this->telegramNotifications->enqueue(
                    $tenantId,
                    'commission.status_updated',
                    'affiliate_payout',
                    $payoutId,
                    $this->telegramPayoutVariables($tenantId, $resource, 'จ่ายแล้ว', $actor->adminUser),
                );
                $this->queueTenantMenuBadgeBroadcast($tenantId, 'commission_transactions');
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliatePayoutUpdated($tenantId, $payoutId));

                return ['resource' => $resource, 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function rejectPayout(string $tenantId, AdminSessionContext $actor, string $payoutId, array $payload, Request $request): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            'admin.tenant.payouts.reject:'.$payoutId,
            'payout.manage',
            $payload,
            function () use ($tenantId, $actor, $payoutId, $payload, $request): array {
                $row = AffiliatePayout::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $payoutId)
                    ->lockForUpdate()
                    ->first();
                if ($row === null) {
                    return ['error' => 'not_found'];
                }
                if ($row->status === 'rejected') {
                    return ['resource' => $this->payoutResource($row, true), 'status' => 200];
                }
                if ($row->status !== 'pending') {
                    return ['error' => 'resource_conflict'];
                }

                $reason = $this->nullableString($payload['reason'] ?? $payload['note'] ?? null);
                if ($reason === null) {
                    return ['error' => 'validation_failed', 'errors' => [
                        'reason' => ['The reason field is required when rejecting a payout.'],
                    ]];
                }

                $row->forceFill([
                    'status' => 'rejected',
                    'admin_note' => $reason,
                    'updated_at' => now(),
                ])->save();

                $resource = $this->payoutResource($row->fresh(), true);
                $this->auditAdmin($actor, $request, 'payout.rejected', 'affiliate_payout', $payoutId, $payload, $tenantId);
                $this->telegramNotifications->enqueue(
                    $tenantId,
                    'commission.status_updated',
                    'affiliate_payout',
                    $payoutId,
                    $this->telegramPayoutVariables($tenantId, $resource, 'ปฏิเสธ', $actor->adminUser),
                );
                $this->queueTenantMenuBadgeBroadcast($tenantId, 'commission_transactions');
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliatePayoutUpdated($tenantId, $payoutId));

                return ['resource' => $resource, 'status' => 200];
            },
        );
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function report(string $scope, ?string $tenantId, string $reportKey, array $queryParams): array
    {
        $allowed = $scope === 'central' ? self::CENTRAL_REPORT_KEYS : self::TENANT_REPORT_KEYS;

        if (! in_array($reportKey, $allowed, true)) {
            return ['error' => 'not_found'];
        }

        if ($scope === 'tenant' && $tenantId === null) {
            return ['error' => 'not_found'];
        }

        $drilldownTenantId = $scope === 'central' ? $this->nullableString($queryParams['tenant_id'] ?? null) : $tenantId;
        $limit = $this->limit($queryParams['limit'] ?? null);
        $dateRange = $this->dateRange($queryParams);

        if ($scope === 'central') {
            return $this->centralReport($drilldownTenantId, $reportKey, $queryParams, $dateRange, $limit);
        }

        return $this->tenantReport((string) $drilldownTenantId, $reportKey, $queryParams, $dateRange, $limit);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array{resource?: array<string, mixed>, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    public function createReportExport(string $scope, ?string $tenantId, AdminSessionContext $actor, string $reportKey, array $payload, Request $request): array
    {
        $allowed = $scope === 'central' ? self::CENTRAL_REPORT_KEYS : self::TENANT_REPORT_KEYS;

        if (! in_array($reportKey, $allowed, true)) {
            return ['error' => 'not_found'];
        }

        $format = strtolower(trim((string) ($payload['format'] ?? '')));
        $errors = [];

        if (! in_array($format, self::EXPORT_FORMATS, true)) {
            $errors['format'][] = 'The format field must be one of csv, xlsx, or pdf.';
        }

        if ($errors !== []) {
            return ['error' => 'validation_failed', 'errors' => $errors];
        }

        $normalized = [
            'source' => 'report',
            'report_key' => $reportKey,
            'format' => $format,
            'tenant_id' => $scope === 'central' ? $this->nullableString($payload['tenant_id'] ?? null) : $tenantId,
            'game_id' => $this->reportExportSupportsGameFilter($scope, $reportKey)
                ? $this->nullableString($payload['game_id'] ?? ($payload['filters']['game_id'] ?? null))
                : null,
            'date_from' => $this->nullableString($payload['date_from'] ?? null),
            'date_to' => $this->nullableString($payload['date_to'] ?? null),
            'filters' => is_array($payload['filters'] ?? null) ? $payload['filters'] : [],
        ];
        $routeKey = $scope === 'central' ? 'admin.central.reports.exports:'.$reportKey : 'admin.tenant.reports.exports:'.$reportKey;

        return $this->adminIdempotentWrite(
            $scope,
            $tenantId,
            $actor,
            $request,
            $routeKey,
            'report.view',
            $normalized,
            function () use ($scope, $tenantId, $actor, $request, $normalized): array {
                if ($scope === 'tenant' && $tenantId === null) {
                    return ['error' => 'not_found'];
                }

                if ($normalized['tenant_id'] !== null && ! PartnerTenant::where('id', $normalized['tenant_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                if ($normalized['game_id'] !== null && ! Game::where('id', $normalized['game_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                $jobId = 'exj_'.Str::ulid()->toBase32();
                $now = now();
                $downloadUrl = 'https://exports.newpaotang.local/'.$jobId.'.'.$normalized['format'].'?signature=placeholder';

                ReportExportJob::query()->insert([
                    'id' => $jobId,
                    'scope' => $scope,
                    'tenant_id' => $normalized['tenant_id'],
                    'requested_by_admin_id' => $actor->adminUser['id'],
                    'source' => $normalized['source'],
                    'report_key' => $normalized['report_key'],
                    'format' => $normalized['format'],
                    'status' => 'ready',
                    'progress_percent' => 100,
                    'download_url' => $downloadUrl,
                    'error_code' => null,
                    'expires_at' => $now->copy()->addDay(),
                    'idempotency_key' => (string) $request->header('Idempotency-Key'),
                    'payload_hash' => $this->idempotency->payloadHash($normalized),
                    'filters_json' => $this->jsonOrNull($normalized),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'report_export.created', 'report_export_job', $jobId, $normalized, $normalized['tenant_id']);

                return ['resource' => $this->exportJobResource(ReportExportJob::where('id', $jobId)->first()), 'status' => 202];
            },
        );
    }

    public function exportJob(string $scope, ?string $tenantId, string $exportJobId): ?array
    {
        $query = ReportExportJob::query()->where('scope', $scope)->whereKey($exportJobId);

        if ($scope === 'tenant') {
            $query->where('tenant_id', $tenantId);
        }

        $row = $query->first();

        return $row === null ? null : $this->exportJobResource($row);
    }

    public function exportDownloadUrl(string $scope, ?string $tenantId, string $exportJobId): array
    {
        $job = $this->exportJob($scope, $tenantId, $exportJobId);

        if ($job === null) {
            return ['error' => 'not_found'];
        }

        if ($job['status'] !== 'ready' || $job['download_url'] === null) {
            return ['error' => 'resource_conflict'];
        }

        return ['download_url' => $job['download_url']];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array<string, mixed>
     */
    public function listSettlements(array $queryParams): array
    {
        $this->refreshSettlements($queryParams);
        $query = PartnerSettlement::query()->with(['partner', 'tenant', 'approvedByAdmin']);

        foreach (['partner_id', 'tenant_id', 'status'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->settlementResource($row));
    }

    public function settlement(string $settlementId): ?array
    {
        $row = PartnerSettlement::query()->with(['partner', 'tenant', 'approvedByAdmin'])->find($settlementId);

        return $row === null ? null : $this->settlementResource($row);
    }

    /**
     * @return array{resource?: array<string, mixed>, status?: int, error?: string}
     */
    public function approveSettlement(AdminSessionContext $actor, string $settlementId, array $payload, Request $request): array
    {
        return $this->adminIdempotentWrite(
            'central',
            null,
            $actor,
            $request,
            'admin.central.settlements.approve:'.$settlementId,
            'settlement.approve',
            $payload,
            function () use ($actor, $settlementId, $payload, $request): array {
                $row = PartnerSettlement::query()->whereKey($settlementId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }

                if ($row->status === 'approved') {
                    $row->loadMissing(['partner', 'tenant', 'approvedByAdmin']);

                    return ['resource' => $this->settlementResource($row), 'status' => 200];
                }

                if (! in_array((string) $row->status, ['draft', 'pending'], true)) {
                    return ['error' => 'resource_conflict'];
                }

                $row->forceFill([
                    'status' => 'approved',
                    'approved_by_admin_id' => $actor->adminUser['id'],
                    'approved_at' => now(),
                    'idempotency_key' => (string) $request->header('Idempotency-Key'),
                    'payload_hash' => $this->idempotency->payloadHash($payload),
                    'updated_at' => now(),
                ])->save();

                $resource = $this->settlementResource($row->refresh()->load(['partner', 'tenant', 'approvedByAdmin']));
                $this->auditAdmin($actor, $request, 'settlement.approved', 'partner_settlement', $settlementId, $payload, (string) $row->tenant_id, (string) $row->partner_id);

                return ['resource' => $resource, 'status' => 200];
            },
        );
    }

    public function calculateCommissions(?string $orderId = null, ?string $tenantId = null, int $limit = 100): int
    {
        return $this->calculateCommissionsBatch($orderId, $tenantId, $limit)['created'];
    }

    /**
     * @return array{
     *     selected: int,
     *     succeeded: int,
     *     failed: int,
     *     created: int,
     *     failures: array<int, array{order_id: string, tenant_id: string, exception: string}>
     * }
     */
    public function calculateCommissionsBatch(?string $orderId = null, ?string $tenantId = null, int $limit = 100): array
    {
        $query = Order::query()
            ->where(function ($builder): void {
                $builder->where('status', 'paid')->orWhere('payment_status', 'paid');
            })
            ->where(function ($builder): void {
                $builder
                    ->whereExists(function ($attributions): void {
                        $attributions
                            ->selectRaw('1')
                            ->from('affiliate_attributions')
                            ->whereColumn('affiliate_attributions.tenant_id', 'orders.tenant_id')
                            ->whereColumn('affiliate_attributions.order_id', 'orders.id')
                            ->where('affiliate_attributions.status', 'pending')
                            ->whereRaw(
                                'COALESCE(affiliate_attributions.attributed_at, affiliate_attributions.created_at) <= COALESCE(orders.paid_at, orders.created_at)',
                            );
                    })
                    ->orWhereExists(function ($attributions): void {
                        $attributions
                            ->selectRaw('1')
                            ->from('affiliate_attributions')
                            ->whereColumn('affiliate_attributions.tenant_id', 'orders.tenant_id')
                            ->whereColumn('affiliate_attributions.customer_id', 'orders.customer_id')
                            ->whereNull('affiliate_attributions.order_id')
                            ->where('affiliate_attributions.status', 'pending')
                            ->whereRaw(
                                'COALESCE(affiliate_attributions.attributed_at, affiliate_attributions.created_at) <= COALESCE(orders.paid_at, orders.created_at)',
                            );
                    });
            })
            ->orderBy('created_at')
            ->limit(max(1, min(500, $limit)));

        if ($orderId !== null && $orderId !== '') {
            $query->where('id', $orderId);
        }

        if ($tenantId !== null && $tenantId !== '') {
            $query->where('tenant_id', $tenantId);
        }

        $orders = $query->get()->all();
        $created = 0;
        $succeeded = 0;
        $failures = [];

        foreach ($orders as $order) {
            try {
                $this->bindAffiliateAttributionToPaidOrder(
                    (string) $order->id,
                    (string) $order->tenant_id,
                );
                $created += $this->calculateCommissionsForOrder($order);
                $succeeded++;
            } catch (Throwable $exception) {
                report($exception);
                $failures[] = [
                    'order_id' => (string) $order->id,
                    'tenant_id' => (string) $order->tenant_id,
                    'exception' => $exception::class,
                ];
            }
        }

        return [
            'selected' => count($orders),
            'succeeded' => $succeeded,
            'failed' => count($failures),
            'created' => $created,
            'failures' => $failures,
        ];
    }

    public function bindAffiliateAttributionToPaidOrder(string $orderId, string $tenantId): ?string
    {
        return DB::transaction(function () use ($orderId, $tenantId): ?string {
            $order = Order::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $orderId)
                ->lockForUpdate()
                ->first();
            if ($order === null || ($order->payment_status !== 'paid' && $order->status !== 'paid')) {
                return null;
            }

            $attribution = $this->pendingAttributionForPaidOrder($order);
            if ($attribution === null) {
                return null;
            }
            if ($this->isSelfReferralAttribution($attribution, $order)) {
                $this->rejectSelfReferralAttribution($attribution, $order);

                return null;
            }

            $metadata = $this->decodeJson($attribution->metadata_json);
            if (($metadata['commission_eligible_at_paid'] ?? null) === true) {
                return (string) $attribution->id;
            }

            $affiliate = AffiliateAccount::query()
                ->where('tenant_id', $tenantId)
                ->whereKey($attribution->affiliate_account_id)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();
            if ($affiliate === null) {
                $this->rejectAffiliateAttributionForOrder($attribution, $order, 'affiliate_inactive_at_payment');

                return null;
            }

            if (
                $attribution->affiliate_link_id !== null
                && AffiliateLink::query()
                    ->where('tenant_id', $tenantId)
                    ->whereKey($attribution->affiliate_link_id)
                    ->where('status', 'active')
                    ->lockForUpdate()
                    ->first() === null
            ) {
                $this->rejectAffiliateAttributionForOrder($attribution, $order, 'affiliate_link_inactive_at_payment');

                return null;
            }

            $programAtPayment = $this->affiliateProgramAtPayment($affiliate, $order);
            $program = AffiliateProgram::query()
                ->where('tenant_id', $tenantId)
                ->whereKey($programAtPayment->id)
                ->where('status', 'active')
                ->lockForUpdate()
                ->first();
            if ($program === null) {
                $this->rejectAffiliateAttributionForOrder($attribution, $order, 'affiliate_tier_inactive_at_payment');

                return null;
            }

            $ruleIds = CommissionRule::query()
                ->where('tenant_id', $tenantId)
                ->where('affiliate_program_id', $program->id)
                ->whereNull('affiliate_account_id')
                ->where('rule_type', 'per_ticket')
                ->where('status', 'active')
                ->orderBy('id')
                ->lockForUpdate()
                ->pluck('id')
                ->map(static fn (mixed $id): string => (string) $id)
                ->all();
            if ($ruleIds === []) {
                return null;
            }

            $metadata['commission_eligible_at_paid'] = true;
            $metadata['commission_bound_at'] = now()->toIso8601String();
            $metadata['commission_program_id_at_paid'] = (string) $program->id;
            $metadata['commission_rule_ids_at_paid'] = $ruleIds;
            AffiliateAttribution::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $attribution->id)
                ->where('status', 'pending')
                ->update([
                    'order_id' => $orderId,
                    'affiliate_program_id' => $program->id,
                    'metadata_json' => $this->jsonOrNull($metadata),
                    'updated_at' => now(),
                ]);

            return (string) $attribution->id;
        });
    }

    public function reverseCommissionsForOrder(string $orderId): int
    {
        $commissions = CommissionTransaction::query()
            ->where('order_id', $orderId)
            ->where('transaction_type', 'commission')
            ->orderBy('id')
            ->get()
            ->all();
        $created = 0;

        foreach ($commissions as $commission) {
            $created += DB::transaction(function () use ($commission): int {
                $exists = CommissionTransaction::query()
                    ->where('tenant_id', $commission->tenant_id)
                    ->where('order_id', $commission->order_id)
                    ->where('commission_rule_id', $commission->commission_rule_id)
                    ->where('affiliate_account_id', $commission->affiliate_account_id)
                    ->where('transaction_type', 'reversal')
                    ->lockForUpdate()
                    ->exists();

                if ($exists) {
                    return 0;
                }

                $reversalId = 'cmt_'.Str::ulid()->toBase32();
                $now = now();

                CommissionTransaction::query()->insert([
                    'id' => $reversalId,
                    'tenant_id' => $commission->tenant_id,
                    'affiliate_account_id' => $commission->affiliate_account_id,
                    'affiliate_attribution_id' => $commission->affiliate_attribution_id,
                    'order_id' => $commission->order_id,
                    'commission_rule_id' => $commission->commission_rule_id,
                    'original_commission_id' => $commission->id,
                    'transaction_type' => 'reversal',
                    'status' => 'reversed',
                    'amount' => -abs((int) $commission->amount),
                    'currency' => $commission->currency,
                    'idempotency_key' => 'reversal:'.$commission->id,
                    'payload_hash' => hash('sha256', 'reversal:'.$commission->id),
                    'calculated_at' => $now,
                    'approved_by_admin_id' => null,
                    'approved_at' => null,
                    'metadata_json' => $this->jsonOrNull(['original_commission_id' => (string) $commission->id]),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliateCommissionReversed(
                    (string) $commission->tenant_id,
                    (string) $commission->affiliate_account_id,
                    $reversalId,
                ));

                return 1;
            });
        }

        return $created;
    }

    private function calculateCommissionsForOrder(object $order): int
    {
        return DB::transaction(function () use ($order): int {
            $lockedOrder = Order::query()->where('id', $order->id)->lockForUpdate()->first();

            if ($lockedOrder === null || ! in_array((string) $lockedOrder->payment_status, ['paid'], true) && ! in_array((string) $lockedOrder->status, ['paid'], true)) {
                return 0;
            }

            $attribution = $this->pendingAttributionForPaidOrder($lockedOrder);

            if ($attribution === null) {
                return 0;
            }
            if ($this->isSelfReferralAttribution($attribution, $lockedOrder)) {
                $this->rejectSelfReferralAttribution($attribution, $lockedOrder);

                return 0;
            }
            if ($attribution->order_id === null) {
                AffiliateAttribution::query()
                    ->where('tenant_id', $lockedOrder->tenant_id)
                    ->where('id', $attribution->id)
                    ->whereNull('order_id')
                    ->update([
                        'order_id' => $lockedOrder->id,
                        'updated_at' => now(),
                    ]);
                $attribution->order_id = $lockedOrder->id;
            }

            $attributionMetadata = $this->decodeJson($attribution->metadata_json);
            $eligibleAtPayment = ($attributionMetadata['commission_eligible_at_paid'] ?? null) === true;
            $affiliate = AffiliateAccount::query()
                ->where('tenant_id', $lockedOrder->tenant_id)
                ->where('id', $attribution->affiliate_account_id)
                ->when(! $eligibleAtPayment, fn ($query) => $query->where('status', 'active'))
                ->first();

            if ($affiliate === null) {
                return 0;
            }

            $snapshotProgramId = trim((string) ($attributionMetadata['commission_program_id_at_paid'] ?? ''));
            $program = $snapshotProgramId === ''
                ? $this->affiliateProgramAtPayment($affiliate, $lockedOrder)
                : AffiliateProgram::query()
                    ->where('tenant_id', $lockedOrder->tenant_id)
                    ->whereKey($snapshotProgramId)
                    ->first();
            if ($program === null) {
                return 0;
            }
            $programId = (string) $program->id;
            $linkId = $attribution->affiliate_link_id === null ? null : (string) $attribution->affiliate_link_id;

            if (! $eligibleAtPayment && $linkId !== null && ! AffiliateLink::where('tenant_id', $lockedOrder->tenant_id)->where('id', $linkId)->where('status', 'active')->exists()) {
                return 0;
            }

            if (! $eligibleAtPayment && ! AffiliateProgram::where('tenant_id', $lockedOrder->tenant_id)->where('id', $programId)->where('status', 'active')->exists()) {
                return 0;
            }

            $snapshotRuleIds = array_values(array_filter(
                is_array($attributionMetadata['commission_rule_ids_at_paid'] ?? null)
                    ? $attributionMetadata['commission_rule_ids_at_paid']
                    : [],
                static fn (mixed $id): bool => is_string($id) && trim($id) !== '',
            ));
            $rules = CommissionRule::query()
                ->where('tenant_id', $lockedOrder->tenant_id)
                ->where('rule_type', 'per_ticket')
                ->whereNull('affiliate_account_id')
                ->where('affiliate_program_id', $programId)
                ->when(
                    $eligibleAtPayment && $snapshotRuleIds !== [],
                    fn ($query) => $query->whereIn('id', $snapshotRuleIds),
                    fn ($query) => $query->where('status', 'active'),
                )
                ->orderBy('id')
                ->get()
                ->all();
            $ticketCount = Ticket::query()
                ->where('tenant_id', $lockedOrder->tenant_id)
                ->where('order_id', $lockedOrder->id)
                ->count();
            $created = 0;

            foreach ($rules as $rule) {
                $exists = CommissionTransaction::query()
                    ->where('tenant_id', $lockedOrder->tenant_id)
                    ->where('order_id', $lockedOrder->id)
                    ->where('commission_rule_id', $rule->id)
                    ->where('affiliate_account_id', $affiliate->id)
                    ->where('transaction_type', 'commission')
                    ->exists();

                if ($exists) {
                    continue;
                }

                $commissionPerTicket = $this->affiliateCommissionRateAtPayment(
                    $program,
                    $lockedOrder,
                    (int) $rule->amount,
                );
                $amount = $ticketCount * $commissionPerTicket;

                if ($amount <= 0) {
                    continue;
                }

                $transactionId = 'cmt_'.Str::ulid()->toBase32();
                $now = now();
                $payload = [
                    'tenant_id' => (string) $lockedOrder->tenant_id,
                    'affiliate_account_id' => (string) $affiliate->id,
                    'order_id' => (string) $lockedOrder->id,
                    'commission_rule_id' => (string) $rule->id,
                    'commission_transaction_id' => $transactionId,
                    'amount' => $amount,
                    'ticket_count' => $ticketCount,
                    'tier_code' => $program?->code,
                    'commission_per_ticket_amount' => $commissionPerTicket,
                    'currency' => (string) $rule->currency,
                ];

                CommissionTransaction::query()->insert([
                    'id' => $transactionId,
                    'tenant_id' => $lockedOrder->tenant_id,
                    'affiliate_account_id' => $affiliate->id,
                    'affiliate_attribution_id' => $attribution->id,
                    'order_id' => $lockedOrder->id,
                    'commission_rule_id' => $rule->id,
                    'original_commission_id' => null,
                    'transaction_type' => 'commission',
                    'status' => 'approved',
                    'amount' => $amount,
                    'ticket_count' => $ticketCount,
                    'tier_code' => $program?->code,
                    'commission_per_ticket_amount' => $commissionPerTicket,
                    'currency' => $rule->currency,
                    'idempotency_key' => 'commission:'.$lockedOrder->id.':'.$rule->id.':'.$affiliate->id,
                    'payload_hash' => $this->idempotency->payloadHash($payload),
                    'calculated_at' => $now,
                    'approved_by_admin_id' => null,
                    'approved_at' => $now,
                    'metadata_json' => $this->jsonOrNull([
                        'source' => 'paid_order',
                        'approval' => 'auto_paid_order',
                        'tier_program_id' => $programId,
                        'tier_code' => $program?->code,
                        'ticket_count' => $ticketCount,
                        'commission_per_ticket_amount' => $commissionPerTicket,
                    ]),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->insertCommissionOutbox($payload, (string) $lockedOrder->tenant_id, (string) $lockedOrder->game_id, $transactionId);
                DB::afterCommit(fn () => $this->customerNotificationEvents->affiliateCommissionAvailable(
                    (string) $lockedOrder->tenant_id,
                    (string) $affiliate->id,
                    $transactionId,
                ));
                $created++;
            }

            if ($created > 0) {
                AffiliateAttribution::query()->where('tenant_id', $lockedOrder->tenant_id)->where('id', $attribution->id)->update([
                    'status' => 'converted',
                    'order_id' => $lockedOrder->id,
                    'affiliate_program_id' => $programId,
                    'converted_at' => now(),
                    'updated_at' => now(),
                ]);
            }

            return $created;
        });
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function insertCommissionOutbox(array $payload, string $tenantId, string $gameId, string $transactionId): void
    {
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => 'commission.calculated.v1',
            'event_version' => 1,
            'producer' => 'affiliate_commission',
            'tenant_id' => $tenantId,
            'partner_id' => null,
            'game_id' => $gameId,
            'aggregate_type' => 'commission_transaction',
            'aggregate_id' => $transactionId,
            'idempotency_key' => 'commission:'.$transactionId,
            'correlation_id' => $payload['order_id'],
            'payload_json' => json_encode($payload, JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    /**
     * @param array{id: string, wallet_id: string, balance_after: int} $ledger
     */
    private function insertAffiliateWalletOutbox(
        string $tenantId,
        string $customerId,
        string $walletId,
        string $payoutId,
        int $amount,
        array $ledger,
        Request $request,
    ): void {
        $eventId = 'evt_'.Str::ulid()->toBase32();
        $now = now();

        SyncOutbox::query()->insert([
            'id' => $eventId,
            'event_id' => $eventId,
            'event_type' => 'wallet.updated.v1',
            'event_version' => 1,
            'producer' => 'affiliate_payout',
            'tenant_id' => $tenantId,
            'partner_id' => null,
            'game_id' => null,
            'aggregate_type' => 'wallet',
            'aggregate_id' => $walletId,
            'idempotency_key' => 'affiliate-payout:'.$payoutId,
            'correlation_id' => $request->header('X-Request-Id'),
            'payload_json' => json_encode([
                'tenant_id' => $tenantId,
                'customer_id' => $customerId,
                'wallet_id' => $walletId,
                'ledger_id' => $ledger['id'],
                'entry_type' => 'credit',
                'amount' => $amount,
                'currency' => 'THB',
                'posted_balance' => $ledger['balance_after'],
                'reference_type' => 'affiliate_payout',
                'reference_id' => $payoutId,
            ], JSON_THROW_ON_ERROR),
            'status' => 'pending',
            'attempt_count' => 0,
            'available_at' => $now,
            'processed_at' => null,
            'last_error' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function pendingAttributionForPaidOrder(object $order): ?object
    {
        $paidAt = Carbon::parse($order->paid_at ?? $order->created_at ?? now());
        $orderAttributions = AffiliateAttribution::query()
            ->where('tenant_id', $order->tenant_id)
            ->where('order_id', $order->id)
            ->where('status', 'pending')
            ->whereRaw('COALESCE(attributed_at, created_at) <= ?', [$paidAt])
            ->orderByDesc('attributed_at')
            ->orderByDesc('created_at')
            ->lockForUpdate()
            ->get()
            ->all();
        $attribution = $this->firstUnexpiredAttribution($orderAttributions, $paidAt);

        if ($attribution !== null) {
            return $attribution;
        }

        if ($order->customer_id === null || $order->customer_id === '') {
            return null;
        }

        $customerAttributions = AffiliateAttribution::query()
            ->where('tenant_id', $order->tenant_id)
            ->where('customer_id', $order->customer_id)
            ->where('status', 'pending')
            ->whereNull('order_id')
            ->whereRaw('COALESCE(attributed_at, created_at) <= ?', [$paidAt])
            ->orderByDesc('attributed_at')
            ->orderByDesc('created_at')
            ->lockForUpdate()
            ->get()
            ->all();

        return $this->firstUnexpiredAttribution($customerAttributions, $paidAt);
    }

    private function isSelfReferralAttribution(object $attribution, object $order): bool
    {
        if ($order->customer_id === null || $order->customer_id === '') {
            return false;
        }

        $ownerCustomerId = AffiliateAccount::query()
            ->where('tenant_id', $order->tenant_id)
            ->where('id', $attribution->affiliate_account_id)
            ->value('customer_id');

        return $ownerCustomerId !== null
            && (string) $ownerCustomerId === (string) $order->customer_id;
    }

    private function rejectSelfReferralAttribution(object $attribution, object $order): void
    {
        $this->rejectAffiliateAttributionForOrder($attribution, $order, 'self_referral');
    }

    private function rejectAffiliateAttributionForOrder(object $attribution, object $order, string $reason): void
    {
        $metadata = $this->decodeJson($attribution->metadata_json);
        $metadata['rejection_reason'] = $reason;
        $metadata['rejected_order_id'] = (string) $order->id;

        AffiliateAttribution::query()
            ->where('tenant_id', $order->tenant_id)
            ->where('id', $attribution->id)
            ->where('status', 'pending')
            ->update([
                'order_id' => $order->id,
                'status' => 'rejected',
                'metadata_json' => $this->jsonOrNull($metadata),
                'updated_at' => now(),
            ]);
    }

    /**
     * @param array<int, object> $attributions
     */
    private function firstUnexpiredAttribution(array $attributions, Carbon $paidAt): ?object
    {
        foreach ($attributions as $attribution) {
            if (! $this->attributionExpiredAt($attribution, $paidAt)) {
                return $attribution;
            }

            AffiliateAttribution::query()
                ->where('tenant_id', $attribution->tenant_id)
                ->where('id', $attribution->id)
                ->where('status', 'pending')
                ->update([
                    'status' => 'expired',
                    'updated_at' => now(),
                ]);
        }

        return null;
    }

    private function attributionExpiredAt(object $attribution, Carbon $paidAt): bool
    {
        $expiresAt = $this->decodeJson($attribution->metadata_json)['expires_at'] ?? null;

        if ($expiresAt === null || $expiresAt === '') {
            return false;
        }

        try {
            return Carbon::parse((string) $expiresAt)->lte($paidAt);
        } catch (\Throwable) {
            return false;
        }
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function refreshSettlements(array $queryParams): void
    {
        $dateRange = $this->dateRange($queryParams);
        $periodFrom = $dateRange['from']?->toDateString() ?? now()->startOfMonth()->toDateString();
        $periodTo = $dateRange['to']?->toDateString() ?? now()->endOfMonth()->toDateString();
        $tenants = PartnerTenant::query()
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select('partner_tenants.id as tenant_id', 'partner_tenants.partner_id')
            ->when(($queryParams['partner_id'] ?? null) !== null && trim((string) $queryParams['partner_id']) !== '', fn ($query) => $query->where('partner_tenants.partner_id', trim((string) $queryParams['partner_id'])))
            ->when(($queryParams['tenant_id'] ?? null) !== null && trim((string) $queryParams['tenant_id']) !== '', fn ($query) => $query->where('partner_tenants.id', trim((string) $queryParams['tenant_id'])))
            ->orderBy('partner_tenants.id')
            ->get()
            ->all();

        foreach ($tenants as $tenant) {
            $sales = $this->scopedOrders($tenant->tenant_id, $dateRange)->where('payment_status', 'paid')->sum('total_amount');
            $commission = $this->scopedTable('commission_transactions', $tenant->tenant_id, $dateRange)->sum('amount');
            $payout = $this->scopedPaidAffiliatePayouts($tenant->tenant_id, $dateRange)->sum('amount');
            $summary = [
                'orders_count' => $this->scopedOrders($tenant->tenant_id, $dateRange)->where('payment_status', 'paid')->count(),
                'commission_count' => $this->scopedTable('commission_transactions', $tenant->tenant_id, $dateRange)->count(),
                'payout_count' => $this->scopedPaidAffiliatePayouts($tenant->tenant_id, $dateRange)->count(),
            ];
            $existing = PartnerSettlement::query()
                ->where('partner_id', $tenant->partner_id)
                ->where('tenant_id', $tenant->tenant_id)
                ->where('period_from', $periodFrom)
                ->where('period_to', $periodTo)
                ->first();
            $now = now();

            if ($existing !== null && $existing->status === 'approved') {
                continue;
            }

            PartnerSettlement::query()->updateOrInsert(
                [
                    'partner_id' => $tenant->partner_id,
                    'tenant_id' => $tenant->tenant_id,
                    'period_from' => $periodFrom,
                    'period_to' => $periodTo,
                ],
                [
                    'id' => $existing?->id ?? 'set_'.Str::ulid()->toBase32(),
                    'status' => $existing?->status ?? 'draft',
                    'sales_amount' => (int) $sales,
                    'commission_amount' => (int) $commission,
                    'payout_amount' => (int) $payout,
                    'net_amount' => (int) $sales - (int) $commission - (int) $payout,
                    'currency' => 'THB',
                    'summary_json' => $this->jsonOrNull($summary),
                    'created_at' => $existing?->created_at ?? $now,
                    'updated_at' => $now,
                ],
            );
        }
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $mutator
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    private function customerIdempotentWrite(string $tenantId, string $customerId, Request $request, string $routeKey, array $payload, callable $mutator): array
    {
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($tenantId, $customerId, $routeKey, $idempotencyKey, $payload, $mutator): array {
            $replay = $this->idempotency->replayOrConflict($tenantId, 'customer', $customerId, $routeKey, $idempotencyKey, $payload, null, true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'], 'status' => $replay['status']];
            }

            if ($replay === 'idempotency_conflict' || $replay === 'resource_conflict') {
                return ['error' => $replay];
            }

            $result = $mutator();

            if (($result['error'] ?? null) !== null) {
                return $result;
            }

            $status = (int) ($result['status'] ?? 200);
            $body = $result['resource'] ?? null;
            $this->idempotency->storeResponse($tenantId, 'customer', $customerId, $routeKey, $idempotencyKey, $payload, $status, is_array($body) ? $body : null);

            return $result;
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $mutator
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    private function tenantIdempotentWrite(string $tenantId, AdminSessionContext $actor, Request $request, string $routeKey, string $permissionCode, array $payload, callable $mutator): array
    {
        return $this->adminIdempotentWrite('tenant', $tenantId, $actor, $request, $routeKey, $permissionCode, $payload, $mutator);
    }

    /**
     * @param array<string, mixed> $payload
     * @param callable(): array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>} $mutator
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string, errors?: array<string, array<int, string>>}
     */
    private function adminIdempotentWrite(string $scope, ?string $tenantId, AdminSessionContext $actor, Request $request, string $routeKey, string $permissionCode, array $payload, callable $mutator): array
    {
        $actorType = $scope === 'central' ? 'central_admin' : 'tenant_admin';
        $idempotencyTenantId = $scope === 'central' ? null : $tenantId;
        $idempotencyKey = (string) $request->header('Idempotency-Key');

        return DB::transaction(function () use ($idempotencyTenantId, $actorType, $actor, $routeKey, $idempotencyKey, $payload, $permissionCode, $mutator): array {
            $replay = $this->idempotency->replayOrConflict($idempotencyTenantId, $actorType, $actor->adminUser['id'], $routeKey, $idempotencyKey, $payload, $permissionCode, true);

            if (is_array($replay)) {
                return ['resource' => $replay['body'], 'status' => $replay['status']];
            }

            if ($replay !== null) {
                return ['error' => $replay];
            }

            $result = $mutator();

            if (isset($result['error'])) {
                return $result;
            }

            $status = $result['status'] ?? 200;
            $body = $status === 204 ? null : ($result['resource'] ?? []);
            $this->idempotency->storeResponse($idempotencyTenantId, $actorType, $actor->adminUser['id'], $routeKey, $idempotencyKey, $payload, $status, $body, $permissionCode);

            return ['resource' => $body, 'status' => $status];
        });
    }

    /**
     * @return array{resource?: array<string, mixed>|null, status?: int, error?: string}
     */
    private function archiveTenantRow(string $tenantId, AdminSessionContext $actor, string $resourceId, array $payload, Request $request, string $table, string $targetType, string $permissionCode, string $routeKey, string $auditAction): array
    {
        return $this->tenantIdempotentWrite(
            $tenantId,
            $actor,
            $request,
            $routeKey.':'.$resourceId,
            $permissionCode,
            $payload,
            function () use ($tenantId, $actor, $resourceId, $payload, $request, $table, $targetType, $auditAction): array {
                $row = $this->queryForTable($table)->where('tenant_id', $tenantId)->where('id', $resourceId)->lockForUpdate()->first();

                if ($row === null) {
                    return ['error' => 'not_found'];
                }

                if ($row->status !== 'archived') {
                    $this->queryForTable($table)->where('tenant_id', $tenantId)->where('id', $resourceId)->update([
                        'status' => 'archived',
                        'updated_at' => now(),
                    ]);
                    $this->auditAdmin($actor, $request, $auditAction, $targetType, $resourceId, $payload, $tenantId);
                }

                return ['resource' => null, 'status' => 204];
            },
        );
    }

    private function tenantRow(string $tenantId): ?object
    {
        return PartnerTenant::find($tenantId);
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function listTenantRows(string $tenantId, string $table, array $queryParams, callable $resource): array
    {
        $query = $this->queryForTable($table)->where('tenant_id', $tenantId);

        foreach (['status', 'affiliate_account_id', 'customer_id', 'order_id', 'game_id'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        return $this->paginated($query, $queryParams, $resource);
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function paginated(mixed $query, array $queryParams, callable $resource): array
    {
        $limit = $this->limit($queryParams['limit'] ?? null);

        if (($queryParams['cursor'] ?? null) !== null && trim((string) $queryParams['cursor']) !== '') {
            $query->where('id', '>', trim((string) $queryParams['cursor']));
        }

        $rows = $query->orderBy('id')->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'data' => array_map($resource, $rows),
            'meta' => [
                'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
                'has_more' => $hasMore,
            ],
        ];
    }

    private function tenantCodeExists(string $table, string $tenantId, string $code, ?string $exceptId = null): bool
    {
        $query = $this->queryForTable($table)->where('tenant_id', $tenantId)->where('code', $code);

        if ($exceptId !== null) {
            $query->where('id', '!=', $exceptId);
        }

        return $query->exists();
    }

    private function uniqueTenantCode(string $table, string $tenantId, mixed $source, string $fallback): string
    {
        $base = $this->code($source);

        if ($base === 'resource') {
            $base = $fallback;
        }

        $candidate = $base;
        $suffix = 2;

        while ($this->tenantCodeExists($table, $tenantId, $candidate)) {
            $candidate = $base.'_'.$suffix;
            $suffix++;
        }

        return $candidate;
    }

    private function randomTenantCode(string $table, string $tenantId, string $prefix): string
    {
        do {
            $candidate = $prefix.'_'.Str::lower(Str::random(10));
        } while ($this->tenantCodeExists($table, $tenantId, $candidate));

        return $candidate;
    }

    private function randomAffiliateCode(string $tenantId): string
    {
        do {
            $candidate = $this->randomBase62(self::AFFILIATE_CODE_LENGTH);
        } while ($this->tenantAffiliateCodeExists($tenantId, $candidate));

        return $candidate;
    }

    private function randomBase62(int $length): string
    {
        $alphabetLength = strlen(self::AFFILIATE_CODE_ALPHABET) - 1;
        $value = '';

        for ($index = 0; $index < $length; $index++) {
            $value .= self::AFFILIATE_CODE_ALPHABET[random_int(0, $alphabetLength)];
        }

        return $value;
    }

    private function tenantAffiliateCodeExists(string $tenantId, string $code): bool
    {
        return $this->whereCodeEquals(AffiliateAccount::query()->where('tenant_id', $tenantId), $code)->exists()
            || $this->whereCodeEquals(AffiliateLink::query()->where('tenant_id', $tenantId), $code)->exists();
    }

    private function isAffiliateCode(string $code): bool
    {
        return preg_match('/\A[A-Za-z0-9]{'.self::AFFILIATE_CODE_LENGTH.'}\z/', $code) === 1;
    }

    private function whereCodeEquals(mixed $query, string $code): mixed
    {
        if (in_array(DB::connection()->getDriverName(), ['mysql', 'mariadb'], true)) {
            return $query->whereRaw('BINARY code = ?', [$code]);
        }

        return $query->where('code', $code);
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function basicNameErrors(array $payload, string $field): array
    {
        if (trim((string) ($payload[$field] ?? '')) === '') {
            return [$field => ['The '.$field.' field is required.']];
        }

        return [];
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function programErrors(array $payload): array
    {
        $errors = [];

        if (array_key_exists('minimum_payout_amount', $payload) && (int) $payload['minimum_payout_amount'] <= 0) {
            $errors['minimum_payout_amount'][] = 'The minimum_payout_amount field must be greater than zero.';
        }

        return $errors;
    }

    private function validAffiliateLinkRelations(string $tenantId, array $payload): ?string
    {
        if (! AffiliateAccount::where('tenant_id', $tenantId)->where('id', $payload['affiliate_account_id'])->where('status', '!=', 'archived')->exists()) {
            return 'not_found';
        }

        if (($payload['affiliate_program_id'] ?? null) !== null && ! AffiliateProgram::where('tenant_id', $tenantId)->where('id', $payload['affiliate_program_id'])->where('status', '!=', 'archived')->exists()) {
            return 'not_found';
        }

        return null;
    }

    private function currentAffiliateProgramId(string $tenantId, string $affiliateId): string
    {
        $affiliate = AffiliateAccount::query()
            ->where('tenant_id', $tenantId)
            ->whereKey($affiliateId)
            ->firstOrFail();
        if ($affiliate->affiliate_program_id !== null) {
            return (string) $affiliate->affiliate_program_id;
        }

        $bronze = $this->affiliateTiers->bronzeProgram($tenantId);
        $affiliate->forceFill(['affiliate_program_id' => $bronze->id])->save();

        return (string) $bronze->id;
    }

    private function affiliateProgramAtPayment(AffiliateAccount $affiliate, Order $order): AffiliateProgram
    {
        $paidAt = $order->paid_at ?? $order->created_at ?? now();
        $nextTierChange = AffiliateTierHistory::query()
            ->where('tenant_id', $affiliate->tenant_id)
            ->where('affiliate_account_id', $affiliate->id)
            ->where('effective_at', '>', $paidAt)
            ->orderBy('effective_at')
            ->orderBy('id')
            ->first(['previous_program_id']);
        $programId = $nextTierChange === null
            ? $affiliate->affiliate_program_id
            : $nextTierChange->previous_program_id;
        $program = $programId === null ? null : AffiliateProgram::query()
            ->where('tenant_id', $affiliate->tenant_id)
            ->whereKey($programId)
            ->whereNotNull('tier_rank')
            ->first();

        if ($program !== null) {
            return $program;
        }

        $bronze = $this->affiliateTiers->bronzeProgram((string) $affiliate->tenant_id);
        if ($affiliate->affiliate_program_id === null) {
            $affiliate->forceFill(['affiliate_program_id' => $bronze->id])->save();
        }

        return $bronze;
    }

    private function affiliateCommissionRateAtPayment(
        AffiliateProgram $program,
        Order $order,
        int $fallback,
    ): int {
        if (! Schema::hasTable('affiliate_tier_rate_history')) {
            return $fallback;
        }

        $paidAt = $order->paid_at ?? $order->created_at ?? now();
        $rate = AffiliateTierRateHistory::query()
            ->where('tenant_id', $program->tenant_id)
            ->where('affiliate_program_id', $program->id)
            ->where('effective_at', '<=', $paidAt)
            ->orderByDesc('effective_at')
            ->orderByDesc('id')
            ->value('commission_per_ticket_amount');

        return $rate === null ? $fallback : max(0, (int) $rate);
    }

    private function validCommissionRuleRelations(string $tenantId, array $payload): ?string
    {
        if (($payload['affiliate_account_id'] ?? null) !== null && ! AffiliateAccount::where('tenant_id', $tenantId)->where('id', $payload['affiliate_account_id'])->where('status', '!=', 'archived')->exists()) {
            return 'not_found';
        }

        if (($payload['affiliate_program_id'] ?? null) !== null && ! AffiliateProgram::where('tenant_id', $tenantId)->where('id', $payload['affiliate_program_id'])->where('status', '!=', 'archived')->exists()) {
            return 'not_found';
        }

        return null;
    }

    /**
     * @return array{source: string, affiliate_account_id: string, affiliate_link_id: string|null, affiliate_program_id: string|null}|null
     */
    private function resolveAffiliateReferralCode(string $tenantId, string $code): ?array
    {
        $linkQuery = AffiliateLink::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active');
        $link = $this->whereCodeEquals($linkQuery, $code)->first();

        if ($link !== null) {
            $affiliate = AffiliateAccount::query()
                ->where('tenant_id', $tenantId)
                ->where('id', $link->affiliate_account_id)
                ->where('status', 'active')
                ->first();

            if ($affiliate === null) {
                return null;
            }

            $programId = $this->currentAffiliateProgramId($tenantId, (string) $affiliate->id);
            if ((string) ($link->affiliate_program_id ?? '') !== $programId) {
                $link->forceFill(['affiliate_program_id' => $programId])->save();
            }

            if ($programId !== null && ! AffiliateProgram::query()->where('tenant_id', $tenantId)->where('id', $programId)->where('status', 'active')->exists()) {
                return null;
            }

            return [
                'source' => 'affiliate_link',
                'affiliate_account_id' => (string) $affiliate->id,
                'affiliate_link_id' => (string) $link->id,
                'affiliate_program_id' => $programId,
            ];
        }

        $affiliateQuery = AffiliateAccount::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active');
        $affiliate = $this->whereCodeEquals($affiliateQuery, $code)->first();

        if ($affiliate === null) {
            return null;
        }

        $primaryLink = $this->primaryAffiliateLink($tenantId, (string) $affiliate->id);

        return [
            'source' => $primaryLink === null ? 'affiliate_account' : 'affiliate_account_primary_link',
            'affiliate_account_id' => (string) $affiliate->id,
            'affiliate_link_id' => $primaryLink === null ? null : (string) $primaryLink->id,
            'affiliate_program_id' => $primaryLink === null || $primaryLink->affiliate_program_id === null ? null : (string) $primaryLink->affiliate_program_id,
        ];
    }

    private function referralVisitorKey(mixed $value, Request $request): string
    {
        $visitorId = trim((string) $value);

        if ($visitorId !== '' && strlen($visitorId) <= 128 && preg_match('/\A[A-Za-z0-9._:-]+\z/', $visitorId) === 1) {
            return $visitorId;
        }

        return 'anon:'.hash('sha256', (string) $request->ip().'|'.(string) $request->userAgent());
    }

    /**
     * @param array{source: string, affiliate_account_id: string, affiliate_link_id: string|null, affiliate_program_id: string|null} $resolved
     * @return array{id: string, created: bool}
     */
    private function upsertAffiliateReferralVisit(string $tenantId, array $resolved, string $code, string $visitorKey, Request $request, ?string $landingUrl, ?string $customerId, bool $registered, bool $incrementClick): array
    {
        return DB::transaction(function () use ($tenantId, $resolved, $code, $visitorKey, $request, $landingUrl, $customerId, $registered, $incrementClick): array {
            $now = now();
            $row = DB::table('affiliate_referral_visits')
                ->where('tenant_id', $tenantId)
                ->where('affiliate_account_id', $resolved['affiliate_account_id'])
                ->where('visitor_key', $visitorKey)
                ->lockForUpdate()
                ->first();
            $metadata = [
                'source' => 'ref',
                'resolved_from' => $resolved['source'],
                'ip_hash' => hash('sha256', (string) $request->ip()),
                'user_agent_hash' => hash('sha256', (string) $request->userAgent()),
            ];

            if ($row === null) {
                $visitId = 'afv_'.Str::ulid()->toBase32();

                DB::table('affiliate_referral_visits')->insert([
                    'id' => $visitId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $resolved['affiliate_account_id'],
                    'affiliate_link_id' => $resolved['affiliate_link_id'],
                    'affiliate_program_id' => $resolved['affiliate_program_id'],
                    'visitor_key' => $visitorKey,
                    'ref_code' => $code,
                    'customer_id' => $customerId,
                    'click_count' => 1,
                    'landing_url' => $landingUrl,
                    'clicked_at' => $now,
                    'last_clicked_at' => $now,
                    'registered_at' => $registered ? $now : null,
                    'metadata_json' => $this->jsonOrNull($metadata),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                return ['id' => $visitId, 'created' => true];
            }

            $updates = [
                'affiliate_link_id' => $resolved['affiliate_link_id'],
                'affiliate_program_id' => $resolved['affiliate_program_id'],
                'ref_code' => $code,
                'metadata_json' => $this->jsonOrNull($metadata),
                'updated_at' => $now,
            ];

            if ($incrementClick) {
                $updates['click_count'] = (int) $row->click_count + 1;
                $updates['last_clicked_at'] = $now;
            }

            if ($landingUrl !== null && $landingUrl !== '') {
                $updates['landing_url'] = $landingUrl;
            }

            if ($customerId !== null && $customerId !== '') {
                $updates['customer_id'] = $customerId;
            }

            if ($registered && $row->registered_at === null) {
                $updates['registered_at'] = $now;
            }

            DB::table('affiliate_referral_visits')->where('id', $row->id)->update($updates);

            return ['id' => (string) $row->id, 'created' => false];
        });
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, array<int, string>>
     */
    private function commissionRuleErrors(array $payload): array
    {
        $errors = $this->basicNameErrors($payload, 'name');

        if (! in_array((string) ($payload['rule_type'] ?? ''), self::RULE_TYPES, true)) {
            $errors['rule_type'][] = 'The rule_type field is invalid.';
        }

        if (($payload['rule_type'] ?? null) === 'percent_sales' && (int) ($payload['rate_bps'] ?? 0) <= 0) {
            $errors['rate_bps'][] = 'The rate_bps field must be greater than zero.';
        }

        if (in_array((string) ($payload['rule_type'] ?? ''), ['fixed_per_order', 'per_ticket'], true) && (int) ($payload['amount'] ?? 0) <= 0) {
            $errors['amount'][] = 'The amount field must be greater than zero.';
        }

        return $errors;
    }

    /**
     * @param array<string, mixed> $payload
     * @return array<string, mixed>
     */
    private function normalizeAgentPayload(array $payload, bool $creating): array
    {
        return $this->removeMissing([
            'code' => $this->code($payload['code'] ?? $payload['name'] ?? 'agent'),
            'name' => $this->stringOrMissing($payload, 'name', $creating),
            'phone' => $this->nullableString($payload['phone'] ?? null),
            'email' => $this->nullableString($payload['email'] ?? null),
            'store_id' => $this->nullableString($payload['store_id'] ?? null),
            'status' => $this->status($payload['status'] ?? 'active'),
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : (is_array($payload['metadata_json'] ?? null) ? $payload['metadata_json'] : []),
        ], $payload, $creating, ['code', 'name', 'phone', 'email', 'store_id', 'status', 'metadata']);
    }

    private function normalizeAffiliatePayload(array $payload, bool $creating): array
    {
        return $this->removeMissing([
            'customer_id' => $this->nullableString($payload['customer_id'] ?? null),
            'code' => $this->code($payload['code'] ?? $payload['name'] ?? 'affiliate'),
            'name' => $this->stringOrMissing($payload, 'name', $creating),
            'phone' => $this->nullableString($payload['phone'] ?? null),
            'email' => $this->nullableString($payload['email'] ?? null),
            'status' => $this->status($payload['status'] ?? 'active'),
            'currency' => strtoupper((string) ($payload['currency'] ?? 'THB')),
            'payout_profile' => is_array($payload['payout_profile'] ?? null) ? $payload['payout_profile'] : [],
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ], $payload, $creating, ['customer_id', 'code', 'name', 'phone', 'email', 'status', 'currency', 'payout_profile', 'metadata']);
    }

    private function normalizeProgramPayload(array $payload, bool $creating): array
    {
        $minimumPayout = $payload['minimum_payout_amount']
            ?? $payload['minimum_payout']
            ?? self::DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT;

        return $this->removeMissing([
            'code' => $this->code($payload['code'] ?? $payload['name'] ?? 'program'),
            'name' => $this->stringOrMissing($payload, 'name', $creating),
            'status' => $this->status($payload['status'] ?? 'active'),
            'minimum_payout_amount' => $this->moneyAmount($minimumPayout),
            'starts_at' => $this->nullableString($payload['starts_at'] ?? null),
            'ends_at' => $this->nullableString($payload['ends_at'] ?? null),
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ], $payload, $creating, ['code', 'name', 'status', 'minimum_payout_amount', 'starts_at', 'ends_at', 'metadata']);
    }

    private function normalizeLinkPayload(array $payload, bool $creating): array
    {
        return $this->removeMissing([
            'affiliate_account_id' => trim((string) ($payload['affiliate_account_id'] ?? $payload['affiliate_id'] ?? '')),
            'affiliate_program_id' => $this->nullableString($payload['affiliate_program_id'] ?? $payload['program_id'] ?? null),
            'code' => $this->code($payload['code'] ?? 'link'),
            'url' => $this->nullableString($payload['url'] ?? null),
            'status' => $this->status($payload['status'] ?? 'active'),
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ], $payload, $creating, ['affiliate_account_id', 'affiliate_program_id', 'code', 'url', 'status', 'metadata']);
    }

    private function normalizeCommissionRulePayload(array $payload, bool $creating): array
    {
        $ruleType = (string) ($payload['rule_type'] ?? 'fixed_per_order');
        $rateBps = (int) ($payload['rate_bps'] ?? round(((float) ($payload['percent'] ?? $payload['percentage'] ?? 0)) * 100));

        return $this->removeMissing([
            'affiliate_program_id' => $this->nullableString($payload['affiliate_program_id'] ?? $payload['program_id'] ?? null),
            'affiliate_account_id' => $this->nullableString($payload['affiliate_account_id'] ?? $payload['affiliate_id'] ?? null),
            'code' => $this->code($payload['code'] ?? $payload['name'] ?? 'commission-rule'),
            'name' => $this->stringOrMissing($payload, 'name', $creating),
            'rule_type' => in_array($ruleType, self::RULE_TYPES, true) ? $ruleType : $ruleType,
            'amount' => $this->moneyAmount($payload['amount'] ?? 0),
            'rate_bps' => max(0, $rateBps),
            'currency' => $this->moneyCurrency($payload['amount'] ?? null),
            'status' => $this->status($payload['status'] ?? 'active'),
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ], $payload, $creating, ['affiliate_program_id', 'affiliate_account_id', 'code', 'name', 'rule_type', 'amount', 'rate_bps', 'currency', 'status', 'metadata']);
    }

    /**
     * @param array<string, mixed> $normalized
     * @param array<string, mixed> $source
     * @param array<int, string> $keys
     * @return array<string, mixed>
     */
    private function removeMissing(array $normalized, array $source, bool $creating, array $keys): array
    {
        if ($creating) {
            return $normalized;
        }

        $result = [];

        foreach ($keys as $key) {
            if ($key === 'affiliate_account_id' && (array_key_exists('affiliate_account_id', $source) || array_key_exists('affiliate_id', $source))) {
                $result[$key] = $normalized[$key];
                continue;
            }

            if ($key === 'affiliate_program_id' && (array_key_exists('affiliate_program_id', $source) || array_key_exists('program_id', $source))) {
                $result[$key] = $normalized[$key];
                continue;
            }

            if ($key === 'minimum_payout_amount' && (array_key_exists('minimum_payout_amount', $source) || array_key_exists('minimum_payout', $source))) {
                $result[$key] = $normalized[$key];
                continue;
            }

            if ($key === 'payout_profile' && array_key_exists('payout_profile', $source)) {
                $result[$key] = $normalized[$key];
                continue;
            }

            if (array_key_exists($key, $source)) {
                $result[$key] = $normalized[$key];
            }
        }

        return $result;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function stringOrMissing(array $payload, string $key, bool $creating): mixed
    {
        if (! $creating && ! array_key_exists($key, $payload)) {
            return null;
        }

        return trim((string) ($payload[$key] ?? ''));
    }

    private function code(mixed $value): string
    {
        $value = trim((string) $value);

        if ($value === '') {
            $value = 'resource';
        }

        $slug = Str::slug($value, '_');

        return $slug === '' ? 'resource' : $slug;
    }

    private function status(mixed $value): string
    {
        $status = trim((string) $value);

        return $status === '' ? 'active' : $status;
    }

    private function nullableString(mixed $value): ?string
    {
        $value = trim((string) $value);

        return $value === '' ? null : $value;
    }

    /**
     * @param array<string, mixed> $normalized
     * @param array<int, string> $keys
     * @return array<string, mixed>
     */
    private function onlyPresent(array $normalized, array $keys): array
    {
        $updates = [];

        foreach ($keys as $key) {
            if (array_key_exists($key, $normalized)) {
                $updates[$key] = $normalized[$key];
            }
        }

        return $updates;
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function jsonOrNull(array $payload): ?string
    {
        return $payload === [] ? null : json_encode($payload, JSON_THROW_ON_ERROR);
    }

    private function mergeJson(mixed $json, array $payload): ?string
    {
        $decoded = $this->decodeJson($json);

        foreach ($payload as $key => $value) {
            if ($value !== null) {
                $decoded[$key] = $value;
            }
        }

        return $this->jsonOrNull($decoded);
    }

    /**
     * @return array<string, mixed>
     */
    private function decodeJson(mixed $json): array
    {
        if (is_array($json)) {
            return $json;
        }

        if ($json === null || $json === '') {
            return [];
        }

        $decoded = json_decode((string) $json, true);

        return is_array($decoded) ? $decoded : [];
    }

    /**
     * @return array<string, string>
     */
    private function normalizeBankAccount(mixed $value): array
    {
        if (! is_array($value)) {
            return [];
        }

        $normalized = [
            'bank_name' => trim((string) ($value['bank_name'] ?? $value['bank'] ?? '')),
            'account_name' => trim((string) ($value['account_name'] ?? $value['bank_deposit_name'] ?? '')),
            'account_number' => trim((string) ($value['account_number'] ?? $value['account_no'] ?? $value['bank_account_no'] ?? $value['bank_deposit_number'] ?? '')),
            'branch' => trim((string) ($value['branch'] ?? '')),
        ];

        return array_filter($normalized, fn (string $field): bool => $field !== '');
    }

    /**
     * @param array<string, mixed> $bankAccount
     */
    private function hasUsableBankAccount(array $bankAccount): bool
    {
        return trim((string) ($bankAccount['bank_name'] ?? '')) !== ''
            && trim((string) ($bankAccount['account_number'] ?? '')) !== '';
    }

    private function lockAffiliatePaymentReference(string $tenantId, string $method, string $reference): void
    {
        if (DB::connection()->getDriverName() === 'pgsql') {
            DB::select(
                'SELECT pg_advisory_xact_lock(hashtextextended(CAST(? AS text), 0))',
                ['affiliate-payout-reference:'.$tenantId.':'.$method.':'.$reference],
            );

            return;
        }

        DB::table('partner_tenants')
            ->where('id', $tenantId)
            ->lockForUpdate()
            ->first();
    }

    /**
     * @return array<string, mixed>
     */
    private function customerRewardPayoutBankAccount(string $tenantId, string $customerId): array
    {
        $customer = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->first([
                'reward_payout_bank_account_json',
                'reward_payout_bank_account_encrypted',
            ]);

        return $customer === null
            ? []
            : EncryptedJsonPayload::decrypt(
                $customer->reward_payout_bank_account_encrypted ?? null,
                $customer->reward_payout_bank_account_json ?? null,
            );
    }

    /**
     * @param array<string, mixed> $bankAccount
     */
    private function storeCustomerRewardPayoutBankAccount(string $tenantId, string $customerId, array $bankAccount): void
    {
        Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->update([
                'reward_payout_bank_account_json' => null,
                'reward_payout_bank_account_encrypted' => EncryptedJsonPayload::encrypt($bankAccount),
                'updated_at' => now(),
            ]);
    }

    /**
     * @return array<string, mixed>
     */
    private function customerAffiliateProfileResource(string $tenantId, string $customerId): array
    {
        return [
            'reward_payout_bank_account' => $this->customerRewardPayoutBankAccount($tenantId, $customerId),
        ];
    }

    private function money(int $amount, string $currency = 'THB'): array
    {
        return ['amount' => $amount, 'currency' => $currency];
    }

    private function moneyAmount(mixed $value): int
    {
        if (is_array($value)) {
            return (int) ($value['amount'] ?? 0);
        }

        return (int) $value;
    }

    private function moneyCurrency(mixed $value): string
    {
        if (is_array($value) && trim((string) ($value['currency'] ?? '')) !== '') {
            return strtoupper((string) $value['currency']);
        }

        return 'THB';
    }

    private function limit(mixed $value): int
    {
        $limit = (int) ($value ?? 20);

        return max(1, min(100, $limit));
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{from: Carbon|null, to: Carbon|null}
     */
    private function dateRange(array $queryParams): array
    {
        $from = $this->parseDate($queryParams['date_from'] ?? null, true);
        $to = $this->parseDate($queryParams['date_to'] ?? null, false);

        return ['from' => $from, 'to' => $to];
    }

    private function parseDate(mixed $value, bool $start): ?Carbon
    {
        $value = trim((string) $value);

        if ($value === '') {
            return null;
        }

        try {
            $date = Carbon::parse($value);

            return $start ? $date->startOfDay() : $date->endOfDay();
        } catch (\Throwable) {
            return null;
        }
    }

    private function scopedTable(string $table, ?string $tenantId, array $dateRange): mixed
    {
        $query = $this->queryForTable($table);

        if ($tenantId !== null) {
            $query->where('tenant_id', $tenantId);
        }

        if ($dateRange['from'] !== null) {
            $query->where('created_at', '>=', $dateRange['from']);
        }

        if ($dateRange['to'] !== null) {
            $query->where('created_at', '<=', $dateRange['to']);
        }

        return $query;
    }

    private function scopedPaidAffiliatePayouts(?string $tenantId, array $dateRange): mixed
    {
        $query = AffiliatePayout::query()->where('status', 'paid');

        if ($tenantId !== null) {
            $query->where('tenant_id', $tenantId);
        }
        if ($dateRange['from'] !== null) {
            $query->whereRaw(
                'COALESCE(paid_at, approved_at, created_at) >= ?',
                [$dateRange['from']],
            );
        }
        if ($dateRange['to'] !== null) {
            $query->whereRaw(
                'COALESCE(paid_at, approved_at, created_at) <= ?',
                [$dateRange['to']],
            );
        }

        return $query;
    }

    private function queryForTable(string $table): mixed
    {
        return match ($table) {
            'affiliate_accounts' => AffiliateAccount::query(),
            'affiliate_attributions' => AffiliateAttribution::query(),
            'affiliate_links' => AffiliateLink::query(),
            'affiliate_payouts' => AffiliatePayout::query(),
            'affiliate_programs' => AffiliateProgram::query(),
            'agents' => Agent::query(),
            'commission_rules' => CommissionRule::query(),
            'commission_transactions' => CommissionTransaction::query(),
            'orders' => Order::query(),
            'reward_claims' => RewardClaim::query(),
            'wallet_ledger' => WalletLedger::query(),
            default => throw new \InvalidArgumentException('Unsupported model-backed table: '.$table),
        };
    }

    private function scopedOrders(?string $tenantId, array $dateRange): mixed
    {
        return $this->scopedTable('orders', $tenantId, $dateRange);
    }

    /**
     * @param array<string, mixed> $queryParams
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<string, mixed>
     */
    private function centralReport(?string $tenantId, string $reportKey, array $queryParams, array $dateRange, int $limit): array
    {
        $gameId = $this->centralReportGameFilter($reportKey, $queryParams);
        $dateRange = $this->centralReportDateRange($reportKey, $dateRange, $gameId);
        $rows = $this->centralReportRows($tenantId, $reportKey, $dateRange, $limit, $gameId);

        return [
            'report_key' => $reportKey,
            'scope' => 'central',
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'generated_at' => now()->toISOString(),
            'summary' => $this->centralReportSummary($tenantId, $dateRange, $gameId),
            'sections' => $this->centralReportSections($tenantId, $reportKey, $dateRange, $limit, $gameId),
            'columns' => $this->centralReportColumns($reportKey),
            'rows' => $rows,
            'meta' => [
                'date_from' => $dateRange['from']?->toDateString(),
                'date_to' => $dateRange['to']?->toDateString(),
                'tenant_filter_applied' => $tenantId !== null,
                'game_filter_supported' => $this->centralReportSupportsGameFilter($reportKey),
                'game_filter_applied' => $gameId !== null,
                'game_id' => $gameId,
                'game' => $gameId !== null ? $this->centralReportGameMeta($gameId) : null,
                'limit' => $limit,
                'has_more' => count($rows) >= $limit,
                'next_cursor' => null,
                'group_by' => $this->nullableString($queryParams['group_by'] ?? null),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<string, mixed>
     */
    private function tenantReport(string $tenantId, string $reportKey, array $queryParams, array $dateRange, int $limit): array
    {
        $gameId = $this->tenantReportGameFilter($reportKey, $queryParams);
        $dateRange = $this->tenantReportDateRange($reportKey, $dateRange);
        $rows = $this->tenantReportRows($tenantId, $reportKey, $dateRange, $limit, $gameId);

        return [
            'report_key' => $reportKey,
            'scope' => 'tenant',
            'tenant_id' => $tenantId,
            'game_id' => $gameId,
            'generated_at' => now()->toISOString(),
            'summary' => $this->tenantReportSummary($tenantId, $dateRange, $gameId),
            'sections' => $this->tenantReportSections($tenantId, $reportKey, $dateRange, $limit, $gameId),
            'columns' => $this->tenantReportColumns($reportKey),
            'rows' => $rows,
            'meta' => [
                'date_from' => $dateRange['from']?->toDateString(),
                'date_to' => $dateRange['to']?->toDateString(),
                'game_filter_supported' => $this->tenantReportSupportsGameFilter($reportKey),
                'game_filter_applied' => $gameId !== null,
                'game_id' => $gameId,
                'game' => $gameId !== null ? $this->centralReportGameMeta($gameId) : null,
                'limit' => $limit,
                'has_more' => count($rows) >= $limit,
                'next_cursor' => null,
                'group_by' => $this->nullableString($queryParams['group_by'] ?? null),
            ],
        ];
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function tenantReportGameFilter(string $reportKey, array $queryParams): ?string
    {
        if (! $this->tenantReportSupportsGameFilter($reportKey)) {
            return null;
        }

        $gameId = $this->nullableString($queryParams['game_id'] ?? null);

        if ($gameId !== null || $reportKey !== 'overview') {
            return $gameId;
        }

        return $this->centralCurrentReportGameId();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array{from: Carbon|null, to: Carbon|null}
     */
    private function tenantReportDateRange(string $reportKey, array $dateRange): array
    {
        if ($reportKey === 'overview') {
            return ['from' => null, 'to' => null];
        }

        return $dateRange;
    }

    private function tenantReportSupportsGameFilter(string $reportKey): bool
    {
        return in_array($reportKey, self::TENANT_DRAW_REPORT_KEYS, true);
    }

    private function reportExportSupportsGameFilter(string $scope, string $reportKey): bool
    {
        return $scope === 'central'
            ? $this->centralReportSupportsGameFilter($reportKey)
            : $this->tenantReportSupportsGameFilter($reportKey);
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<string, mixed>
     */
    private function tenantReportSummary(string $tenantId, array $dateRange, ?string $gameId): array
    {
        $orders = $this->centralOrdersQuery($tenantId, $dateRange, $gameId);
        $paidOrders = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId);
        $ordersCount = (int) (clone $orders)->count();
        $paidOrdersCount = (int) (clone $paidOrders)->count();
        $salesTotal = (int) (clone $paidOrders)->sum('orders.total_amount');
        $walletInflow = $this->centralWalletFlowTotal($tenantId, $dateRange, 'inflow', $gameId);
        $walletOutflow = $this->centralWalletFlowTotal($tenantId, $dateRange, 'outflow', $gameId);

        return [
            'orders_count' => $ordersCount,
            'paid_orders_count' => $paidOrdersCount,
            'sales_total' => $this->money($salesTotal),
            'tickets_sold_count' => $this->centralPaidTicketsCount($tenantId, $dateRange, $gameId),
            'average_order_amount' => $this->money($paidOrdersCount > 0 ? (int) round($salesTotal / $paidOrdersCount) : 0),
            'paid_customer_count' => (int) (clone $paidOrders)->distinct('orders.customer_id')->count('orders.customer_id'),
            'stock_count' => $this->tenantLocalStockCount($tenantId, $gameId),
            'stock_total_count' => $this->tenantLocalStockCount($tenantId, $gameId),
            'stock_available_count' => $this->tenantLocalStockCount($tenantId, $gameId, 'available'),
            'stock_sold_count' => $this->tenantLocalStockCount($tenantId, $gameId, 'sold'),
            'wallet_ledger_total' => $this->money($this->tenantWalletLedgerTotal($tenantId, $dateRange, $gameId)),
            'wallet_inflow_total' => $this->money($walletInflow),
            'wallet_outflow_total' => $this->money($walletOutflow),
            'wallet_net_flow_total' => $this->money($walletInflow - $walletOutflow),
            'commission_total' => $this->money($this->centralCommissionTotal($tenantId, $dateRange, $gameId)),
            'payout_total' => $this->money((int) $this->scopedPaidAffiliatePayouts($tenantId, $dateRange)->sum('amount')),
            'reward_claims_count' => $this->centralDateScopedCount('reward_claims', $tenantId, $dateRange, 'created_at', $gameId),
            'reward_base_total' => $this->money($this->tenantRewardClaimSum($tenantId, $dateRange, 'COALESCE(base_prize_amount, prize_amount)', $gameId)),
            'reward_adjustment_total' => $this->money($this->tenantRewardClaimSum($tenantId, $dateRange, 'COALESCE(adjustment_amount, 0)', $gameId)),
            'reward_payout_total' => $this->money($this->centralRewardClaimTotal($tenantId, $dateRange, $gameId)),
            'customers_count' => Customer::query()->where('tenant_id', $tenantId)->count(),
            'new_customers_count' => $this->centralDateScopedCount('customers', $tenantId, $dateRange),
            'settlements_count' => PartnerSettlement::query()->where('tenant_id', $tenantId)->count(),
            'settlement_net_total' => $this->money($this->centralSettlementTotal($tenantId, $dateRange, 'net_amount')),
        ];
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantReportSections(string $tenantId, string $reportKey, array $dateRange, int $limit, ?string $gameId): array
    {
        return match ($reportKey) {
            'overview' => [
                $this->reportTableSection('Revenue summary', $this->tenantRevenueSummaryRows($tenantId, $dateRange, $gameId), $this->tenantReportColumns('overview')),
                $this->reportTableSection('Payment summary', $this->tenantRevenuePaymentRows($tenantId, $dateRange, $gameId), [
                    ['key' => 'payment_method', 'label' => 'Channel'],
                    ['key' => 'order_count', 'label' => 'Total count', 'type' => 'number'],
                    ['key' => 'sales_amount', 'label' => 'Total amount', 'type' => 'money'],
                ]),
            ],
            'sales' => [
                $this->reportTableSection('Sales by game', $this->centralSalesByGameRows($tenantId, $dateRange, 20, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ]),
                $this->reportTableSection('Payment method mix', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'payment_method', $gameId), [
                    ['key' => 'label', 'label' => 'Payment method'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Order status breakdown', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'status', $gameId), [
                    ['key' => 'label', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'sales_amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
            ],
            'orders' => [
                $this->reportTableSection('Order status breakdown', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'status', $gameId), [
                    ['key' => 'label', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'sales_amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Payment status breakdown', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'payment_status', $gameId), [
                    ['key' => 'label', 'label' => 'Payment status', 'type' => 'status'],
                    ['key' => 'sales_amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
            ],
            'customers' => [
                $this->reportTableSection('Customer status breakdown', $this->tenantStatusRows('customers', $tenantId, $dateRange), [
                    ['key' => 'label', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'row_count', 'label' => 'Customers', 'type' => 'number'],
                ]),
                $this->reportTableSection('Customer preferences', $this->tenantCustomerPreferenceRows($tenantId, $dateRange), [
                    ['key' => 'label', 'label' => 'Preference'],
                    ['key' => 'enabled_count', 'label' => 'Enabled', 'type' => 'number'],
                    ['key' => 'customer_count', 'label' => 'Customers', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
            ],
            'stock' => [
                $this->reportTableSection('Stock by game', $this->tenantLocalStockByGameRows($tenantId, 25, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'total_count', 'label' => 'Total', 'type' => 'number'],
                    ['key' => 'available_count', 'label' => 'Available', 'type' => 'number'],
                    ['key' => 'sold_count', 'label' => 'Sold', 'type' => 'number'],
                    ['key' => 'reserved_count', 'label' => 'Reserved', 'type' => 'number'],
                ]),
                $this->reportTableSection('Stock status breakdown', $this->tenantLocalStockStatusRows($tenantId, $gameId), [
                    ['key' => 'label', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'row_count', 'label' => 'Tickets', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Number segment coverage', $this->tenantLocalStockNumberSegmentRows($tenantId, $gameId), [
                    ['key' => 'segment', 'label' => 'Segment'],
                    ['key' => 'unique_count', 'label' => 'Unique numbers', 'type' => 'number'],
                    ['key' => 'sold_count', 'label' => 'Sold', 'type' => 'number'],
                    ['key' => 'available_count', 'label' => 'Available', 'type' => 'number'],
                ]),
            ],
            'wallet' => [
                $this->reportTableSection('Wallet flow by reference', $this->centralWalletReferenceRows($tenantId, $dateRange, 25, $gameId), [
                    ['key' => 'reference_type', 'label' => 'Reference'],
                    ['key' => 'inflow_amount', 'label' => 'Inflow', 'type' => 'money'],
                    ['key' => 'outflow_amount', 'label' => 'Outflow', 'type' => 'money'],
                    ['key' => 'net_amount', 'label' => 'Net', 'type' => 'money'],
                    ['key' => 'ledger_count', 'label' => 'Entries', 'type' => 'number'],
                ]),
                $this->reportTableSection('Wallet status breakdown', $this->tenantWalletStatusRows($tenantId, $dateRange, $gameId), [
                    ['key' => 'label', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'row_count', 'label' => 'Entries', 'type' => 'number'],
                ]),
            ],
            'topup_channels' => [
                $this->reportTableSection('Topup channel summary', $this->topupChannelSummaryRows($tenantId, $dateRange, $limit, false), $this->tenantReportColumns('topup_channels')),
            ],
            'commission' => [
                $this->reportTableSection('Commission by affiliate', $this->tenantCommissionByAffiliateRows($tenantId, $dateRange, 25, $gameId), [
                    ['key' => 'affiliate_name', 'label' => 'Affiliate'],
                    ['key' => 'affiliate_code', 'label' => 'Code'],
                    ['key' => 'commission_amount', 'label' => 'Commission', 'type' => 'money'],
                    ['key' => 'approved_amount', 'label' => 'Approved', 'type' => 'money'],
                    ['key' => 'pending_amount', 'label' => 'Pending', 'type' => 'money'],
                    ['key' => 'transaction_count', 'label' => 'Transactions', 'type' => 'number'],
                ]),
                $this->reportTableSection('Commission status mix', $this->centralMoneyStatusRows('commission_transactions', $tenantId, $dateRange, 'amount', $gameId), [
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'row_count', 'label' => 'Rows', 'type' => 'number'],
                ]),
            ],
            'rewards' => [
                $this->reportTableSection('Rewards by prize type', $this->tenantRewardPrizeTypeRows($tenantId, $dateRange, $gameId), [
                    ['key' => 'prize_label', 'label' => 'Prize type'],
                    ['key' => 'winner_user_count', 'label' => 'Winner users', 'type' => 'number'],
                    ['key' => 'winning_ticket_count', 'label' => 'Winning tickets', 'type' => 'number'],
                    ['key' => 'prize_amount', 'label' => 'Prize total', 'type' => 'money'],
                ]),
                $this->reportTableSection('Reward winners by prize type', $this->tenantRewardPrizeTypeWinnerRows($tenantId, $dateRange, 100, $gameId), [
                    ['key' => 'prize_label', 'label' => 'Prize type'],
                    ['key' => 'user_id', 'label' => 'User ID'],
                    ['key' => 'account', 'label' => 'Account'],
                    ['key' => 'ticket_number', 'label' => 'Ticket number'],
                    ['key' => 'ticket_count', 'label' => 'Ticket count', 'type' => 'number'],
                ]),
                $this->reportTableSection('Reward status mix', $this->centralMoneyStatusRows('reward_claims', $tenantId, $dateRange, 'prize_amount', $gameId), [
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'amount', 'label' => 'Prize', 'type' => 'money'],
                    ['key' => 'row_count', 'label' => 'Claims', 'type' => 'number'],
                ]),
                $this->reportTableSection('Reward payout methods', $this->tenantRewardMethodRows($tenantId, $dateRange, $gameId), [
                    ['key' => 'payout_method', 'label' => 'Payout method'],
                    ['key' => 'prize_amount', 'label' => 'Prize', 'type' => 'money'],
                    ['key' => 'claim_count', 'label' => 'Claims', 'type' => 'number'],
                    ['key' => 'approved_count', 'label' => 'Approved', 'type' => 'number'],
                    ['key' => 'rejected_count', 'label' => 'Rejected', 'type' => 'number'],
                ]),
                $this->reportTableSection('Rewards by game', $this->tenantRewardByGameRows($tenantId, $dateRange, 25, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'prize_amount', 'label' => 'Prize', 'type' => 'money'],
                    ['key' => 'claim_count', 'label' => 'Claims', 'type' => 'number'],
                    ['key' => 'approved_count', 'label' => 'Approved', 'type' => 'number'],
                    ['key' => 'rejected_count', 'label' => 'Rejected', 'type' => 'number'],
                ]),
            ],
            'settlement' => [
                $this->reportTableSection('Settlement status mix', $this->tenantSettlementStatusRows($tenantId, $dateRange), [
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'commission_amount', 'label' => 'Commission', 'type' => 'money'],
                    ['key' => 'payout_amount', 'label' => 'Payout', 'type' => 'money'],
                    ['key' => 'net_amount', 'label' => 'Net', 'type' => 'money'],
                    ['key' => 'row_count', 'label' => 'Rows', 'type' => 'number'],
                ]),
            ],
            'audit' => [
                $this->reportTableSection('Audit actions', $this->centralAuditActionRows($tenantId, $dateRange, 25), [
                    ['key' => 'action', 'label' => 'Action'],
                    ['key' => 'event_count', 'label' => 'Events', 'type' => 'number'],
                    ['key' => 'admin_count', 'label' => 'Admins', 'type' => 'number'],
                    ['key' => 'latest_at', 'label' => 'Latest', 'type' => 'datetime'],
                ]),
            ],
            default => [
                $this->reportTableSection('Sales by game', $this->centralSalesByGameRows($tenantId, $dateRange, 20, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ]),
                $this->reportTableSection('Local stock by game', $this->tenantLocalStockByGameRows($tenantId, 20, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'total_count', 'label' => 'Total', 'type' => 'number'],
                    ['key' => 'available_count', 'label' => 'Available', 'type' => 'number'],
                    ['key' => 'sold_count', 'label' => 'Sold', 'type' => 'number'],
                ]),
                $this->reportTableSection('Operational status overview', $this->tenantOverviewStatusRows($tenantId, $dateRange, $gameId), [
                    ['key' => 'area', 'label' => 'Area'],
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'row_count', 'label' => 'Count', 'type' => 'number'],
                ]),
            ],
        };
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantReportColumns(string $reportKey): array
    {
        return match ($reportKey) {
            'overview' => [
                ['key' => 'metric', 'label' => 'Metric'],
                ['key' => 'value', 'label' => 'Value'],
                ['key' => 'unit', 'label' => 'Unit'],
            ],
            'sales' => [
                ['key' => 'paid_at', 'label' => 'Paid at', 'type' => 'datetime'],
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'reference', 'label' => 'Order ref'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                ['key' => 'total_amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'payment_method', 'label' => 'Payment method'],
            ],
            'orders' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'paid_at', 'label' => 'Paid', 'type' => 'datetime'],
                ['key' => 'reference', 'label' => 'Order ref'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'payment_status', 'label' => 'Payment', 'type' => 'status'],
                ['key' => 'total_amount', 'label' => 'Amount', 'type' => 'money'],
            ],
            'customers' => [
                ['key' => 'created_at', 'label' => 'Joined', 'type' => 'datetime'],
                ['key' => 'name', 'label' => 'Customer'],
                ['key' => 'phone', 'label' => 'Phone'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'pin_set', 'label' => 'PIN set', 'type' => 'boolean'],
                ['key' => 'auto_reward', 'label' => 'Auto reward', 'type' => 'boolean'],
            ],
            'stock' => [
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                ['key' => 'full_number', 'label' => 'Number'],
                ['key' => 'front3', 'label' => 'Front 3'],
                ['key' => 'back3', 'label' => 'Back 3'],
                ['key' => 'back2', 'label' => 'Back 2'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'reserved_at', 'label' => 'Reserved', 'type' => 'datetime'],
                ['key' => 'sold_at', 'label' => 'Sold', 'type' => 'datetime'],
            ],
            'wallet' => [
                ['key' => 'posted_at', 'label' => 'Posted', 'type' => 'datetime'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'entry_type', 'label' => 'Type', 'type' => 'status'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'balance_after', 'label' => 'Balance after', 'type' => 'money'],
                ['key' => 'reference_type', 'label' => 'Reference'],
                ['key' => 'reference_id', 'label' => 'Reference ID'],
            ],
            'topup_channels' => [
                ['key' => 'channel', 'label' => 'Payment channel', 'type' => 'status'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'row_count', 'label' => 'Total count', 'type' => 'number'],
                ['key' => 'amount', 'label' => 'Total amount', 'type' => 'money'],
                ['key' => 'details', 'label' => 'More', 'type' => 'report-details'],
            ],
            'commission' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'affiliate_name', 'label' => 'Affiliate'],
                ['key' => 'transaction_type', 'label' => 'Type'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'approved_at', 'label' => 'Approved at', 'type' => 'datetime'],
            ],
            'rewards' => [
                ['key' => 'submitted_at', 'label' => 'Submitted', 'type' => 'datetime'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'reference', 'label' => 'Reference'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'payout_method', 'label' => 'Payout method'],
                ['key' => 'base_prize_amount', 'label' => 'Base prize', 'type' => 'money'],
                ['key' => 'adjustment_amount', 'label' => 'Adjustment', 'type' => 'money'],
                ['key' => 'prize_amount', 'label' => 'Prize', 'type' => 'money'],
            ],
            'settlement' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'period', 'label' => 'Period'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                ['key' => 'commission_amount', 'label' => 'Commission', 'type' => 'money'],
                ['key' => 'payout_amount', 'label' => 'Payout', 'type' => 'money'],
                ['key' => 'net_amount', 'label' => 'Net', 'type' => 'money'],
            ],
            'audit' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'scope_type', 'label' => 'Scope'],
                ['key' => 'actor_type', 'label' => 'Actor'],
                ['key' => 'actor_id', 'label' => 'Actor ID'],
                ['key' => 'action', 'label' => 'Action'],
                ['key' => 'target_type', 'label' => 'Target'],
                ['key' => 'ip_address', 'label' => 'IP'],
            ],
            default => [
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ['key' => 'stock_total_count', 'label' => 'Stock', 'type' => 'number'],
                ['key' => 'stock_sold_count', 'label' => 'Sold stock', 'type' => 'number'],
                ['key' => 'reward_payout_amount', 'label' => 'Rewards', 'type' => 'money'],
                ['key' => 'reward_claim_count', 'label' => 'Reward claims', 'type' => 'number'],
            ],
        };
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantReportRows(string $tenantId, string $reportKey, array $dateRange, int $limit, ?string $gameId): array
    {
        return match ($reportKey) {
            'sales' => $this->centralSalesOrderRows($tenantId, $dateRange, $limit, $gameId),
            'orders' => $this->centralOrderRows($tenantId, $dateRange, $limit, $gameId),
            'customers' => $this->centralCustomerRows($tenantId, $dateRange, $limit),
            'stock' => $this->tenantLocalStockRows($tenantId, $limit, $gameId),
            'wallet' => $this->centralWalletRows($tenantId, $dateRange, $limit, $gameId),
            'topup_channels' => $this->topupChannelSummaryRows($tenantId, $dateRange, $limit, false),
            'commission' => $this->centralCommissionRows($tenantId, $dateRange, $limit, $gameId),
            'rewards' => $this->centralRewardRows($tenantId, $dateRange, $limit, $gameId),
            'settlement' => $this->centralSettlementRows($tenantId, $dateRange, $limit),
            'audit' => $this->centralAuditRows($tenantId, $dateRange, $limit),
            default => $this->tenantOverviewRows($tenantId, $dateRange, $limit, $gameId),
        };
    }

    /**
     * @param array<string, mixed> $queryParams
     */
    private function centralReportGameFilter(string $reportKey, array $queryParams): ?string
    {
        if (! $this->centralReportSupportsGameFilter($reportKey)) {
            return null;
        }

        $gameId = $this->nullableString($queryParams['game_id'] ?? null);
        if ($gameId !== null || ! in_array($reportKey, ['daily', 'overview'], true)) {
            return $gameId;
        }

        if ($reportKey === 'overview') {
            return $this->centralCurrentReportGameId();
        }

        $hasDateFilter = $this->nullableString($queryParams['date_from'] ?? null) !== null
            || $this->nullableString($queryParams['date_to'] ?? null) !== null;

        return $hasDateFilter ? null : $this->centralCurrentReportGameId();
    }

    private function centralReportSupportsGameFilter(string $reportKey): bool
    {
        return in_array($reportKey, self::CENTRAL_DRAW_REPORT_KEYS, true);
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array{from: Carbon|null, to: Carbon|null}
     */
    private function centralReportDateRange(string $reportKey, array $dateRange, ?string $gameId): array
    {
        if (! in_array($reportKey, ['daily', 'overview'], true) || $gameId === null) {
            return $dateRange;
        }

        if ($reportKey === 'daily' && $dateRange['from'] !== null && $dateRange['to'] !== null) {
            return $dateRange;
        }

        $game = DB::table('games')
            ->where('id', $gameId)
            ->select(['sale_start_at', 'close_at', 'draw_at', 'created_at'])
            ->first();

        if ($game === null) {
            return $dateRange;
        }

        $gameDateRange = [
            'from' => Carbon::parse($game->sale_start_at ?? $game->created_at ?? $game->draw_at ?? now())->startOfDay(),
            'to' => Carbon::parse($game->close_at ?? $game->draw_at ?? now())->endOfDay(),
        ];

        if ($reportKey === 'overview') {
            return $gameDateRange;
        }

        return [
            'from' => $dateRange['from'] ?? $gameDateRange['from'],
            'to' => $dateRange['to'] ?? $gameDateRange['to'],
        ];
    }

    private function centralCurrentReportGameId(): ?string
    {
        $game = DB::table('games')
            ->where('status', 'open')
            ->orderByDesc('sale_start_at')
            ->orderByDesc('draw_at')
            ->first(['id']);

        if ($game !== null) {
            return (string) $game->id;
        }

        $game = DB::table('games')
            ->where('draw_at', '>=', now())
            ->orderBy('draw_at')
            ->first(['id']);

        if ($game !== null) {
            return (string) $game->id;
        }

        $game = DB::table('games')
            ->orderByDesc('draw_at')
            ->first(['id']);

        return $game === null ? null : (string) $game->id;
    }

    /**
     * @return array<string, mixed>|null
     */
    private function centralReportGameMeta(string $gameId): ?array
    {
        $game = DB::table('games')
            ->where('id', $gameId)
            ->select(['id', 'code', 'name', 'draw_at', 'status'])
            ->first();

        if (! $game) {
            return null;
        }

        return [
            'id' => (string) $game->id,
            'code' => (string) $game->code,
            'name' => (string) $game->name,
            'draw_at' => $this->iso($game->draw_at),
            'status' => (string) $game->status,
        ];
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<string, mixed>
     */
    private function centralReportSummary(?string $tenantId, array $dateRange, ?string $gameId): array
    {
        $paidOrders = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId);
        $salesTotal = (int) (clone $paidOrders)->sum('orders.total_amount');
        $paidOrdersCount = (int) (clone $paidOrders)->count();
        $ticketsSold = $this->centralPaidTicketsCount($tenantId, $dateRange, $gameId);
        $walletInflow = $this->centralWalletFlowTotal($tenantId, $dateRange, 'inflow', $gameId);
        $walletOutflow = $this->centralWalletFlowTotal($tenantId, $dateRange, 'outflow', $gameId);
        $rewardPayout = $this->centralRewardClaimTotal($tenantId, $dateRange, $gameId);
        $commissionTotal = $this->centralCommissionTotal($tenantId, $dateRange, $gameId);

        return [
            'paid_orders_count' => $paidOrdersCount,
            'sales_total' => $this->money($salesTotal),
            'tickets_sold_count' => $ticketsSold,
            'average_order_amount' => $this->money($paidOrdersCount > 0 ? (int) round($salesTotal / $paidOrdersCount) : 0),
            'paid_customer_count' => (int) (clone $paidOrders)->distinct('orders.customer_id')->count('orders.customer_id'),
            'selling_tenant_count' => (int) (clone $paidOrders)->distinct('orders.tenant_id')->count('orders.tenant_id'),
            'partners_total' => DB::table('partners')->count(),
            'active_partners_total' => DB::table('partners')->where('status', 'active')->count(),
            'tenants_total' => DB::table('partner_tenants')->when($tenantId !== null, fn ($query) => $query->where('id', $tenantId))->count(),
            'active_tenants_total' => DB::table('partner_tenants')->when($tenantId !== null, fn ($query) => $query->where('id', $tenantId))->where('status', 'active')->count(),
            'customers_total' => DB::table('customers')->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))->count(),
            'new_customers_count' => $this->centralDateScopedCount('customers', $tenantId, $dateRange),
            'stock_total_count' => DB::table('stock_items')
                ->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))
                ->when($gameId !== null, fn ($query) => $query->where('game_id', $gameId))
                ->count(),
            'stock_available_count' => DB::table('stock_items')
                ->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))
                ->when($gameId !== null, fn ($query) => $query->where('game_id', $gameId))
                ->where('status', 'available')
                ->count(),
            'wallet_inflow_total' => $this->money($walletInflow),
            'wallet_outflow_total' => $this->money($walletOutflow),
            'wallet_net_flow_total' => $this->money($walletInflow - $walletOutflow),
            'reward_claims_count' => $this->centralDateScopedCount('reward_claims', $tenantId, $dateRange, 'created_at', $gameId),
            'reward_payout_total' => $this->money($rewardPayout),
            'commission_total' => $this->money($commissionTotal),
            'affiliate_payout_total' => $this->money($this->centralAffiliatePayoutTotal($tenantId, $dateRange)),
            'settlement_net_total' => $this->money($this->centralSettlementTotal($tenantId, $dateRange, 'net_amount')),
            'audit_events_count' => $this->centralDateScopedCount('audit_logs', $tenantId, $dateRange),
        ];
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function centralReportSections(?string $tenantId, string $reportKey, array $dateRange, int $limit, ?string $gameId): array
    {
        return match ($reportKey) {
            'overview' => [
                $this->reportTableSection('Revenue summary', $this->centralRevenueSummaryRows($tenantId, $dateRange, $gameId), $this->centralReportColumns('overview')),
            ],
            'daily' => [
                $this->reportTableSection('Draw sales by partner', $this->centralDailySalesByPartnerRows($tenantId, $dateRange, 100, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Website'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'ticket_count', 'label' => 'Tickets sold', 'type' => 'number'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                ]),
                $this->reportTableSection('Top 10 back 2 numbers', $this->centralDailyTopNumberRows($tenantId, $dateRange, $gameId, 'back2'), [
                    ['key' => 'rank', 'label' => 'Rank', 'type' => 'number'],
                    ['key' => 'number', 'label' => 'Number'],
                    ['key' => 'ticket_count', 'label' => 'Tickets sold', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Top 10 back 3 numbers', $this->centralDailyTopNumberRows($tenantId, $dateRange, $gameId, 'back3'), [
                    ['key' => 'rank', 'label' => 'Rank', 'type' => 'number'],
                    ['key' => 'number', 'label' => 'Number'],
                    ['key' => 'ticket_count', 'label' => 'Tickets sold', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Top 10 front 3 numbers', $this->centralDailyTopNumberRows($tenantId, $dateRange, $gameId, 'front3'), [
                    ['key' => 'rank', 'label' => 'Rank', 'type' => 'number'],
                    ['key' => 'number', 'label' => 'Number'],
                    ['key' => 'ticket_count', 'label' => 'Tickets sold', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Set distribution', $this->centralDailySetDistributionRows($tenantId, $dateRange, $gameId), [
                    ['key' => 'label', 'label' => 'Set'],
                    ['key' => 'offered_set_count', 'label' => 'Offered sets', 'type' => 'number'],
                    ['key' => 'offered_percent', 'label' => 'Offered share', 'type' => 'percent'],
                    ['key' => 'sold_set_count', 'label' => 'Sold sets', 'type' => 'number'],
                    ['key' => 'sold_percent', 'label' => 'Sold share', 'type' => 'percent'],
                ]),
            ],
            'sales' => [
                $this->reportTableSection('Sales by partner store', $this->centralSalesByTenantRows($tenantId, $dateRange, 12, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'customer_count', 'label' => 'Customers', 'type' => 'number'],
                ]),
                $this->reportTableSection('Sales by game', $this->centralSalesByGameRows($tenantId, $dateRange, 12, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ]),
                $this->reportTableSection('Payment method mix', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'payment_method', $gameId), [
                    ['key' => 'label', 'label' => 'Payment method'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
            ],
            'orders' => [
                $this->reportTableSection('Order status breakdown', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'status', $gameId), [
                    ['key' => 'label', 'label' => 'Status'],
                    ['key' => 'sales_amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
                $this->reportTableSection('Payment status breakdown', $this->centralOrderBreakdownRows($tenantId, $dateRange, 'payment_status', $gameId), [
                    ['key' => 'label', 'label' => 'Payment status'],
                    ['key' => 'sales_amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                    ['key' => 'percent', 'label' => 'Share', 'type' => 'percent'],
                ]),
            ],
            'customers' => [
                $this->reportTableSection('New customers by partner store', $this->centralCustomersByTenantRows($tenantId, $dateRange, 20), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'customer_count', 'label' => 'New customers', 'type' => 'number'],
                    ['key' => 'with_pin_count', 'label' => 'PIN set', 'type' => 'number'],
                    ['key' => 'auto_reward_count', 'label' => 'Auto reward', 'type' => 'number'],
                ]),
            ],
            'stock' => [
                $this->reportTableSection('Stock by game', $this->centralStockByGameRows($tenantId, 20, $gameId), [
                    ['key' => 'game_name', 'label' => 'Game'],
                    ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                    ['key' => 'total_count', 'label' => 'Total', 'type' => 'number'],
                    ['key' => 'available_count', 'label' => 'Available', 'type' => 'number'],
                    ['key' => 'sold_count', 'label' => 'Sold', 'type' => 'number'],
                    ['key' => 'reserved_count', 'label' => 'Reserved', 'type' => 'number'],
                    ['key' => 'allocated_count', 'label' => 'Allocated', 'type' => 'number'],
                ]),
                $this->reportTableSection('Stock by partner store', $this->centralStockByTenantRows($tenantId, 20, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'total_count', 'label' => 'Total', 'type' => 'number'],
                    ['key' => 'available_count', 'label' => 'Available', 'type' => 'number'],
                    ['key' => 'sold_count', 'label' => 'Sold', 'type' => 'number'],
                ]),
            ],
            'wallet' => [
                $this->reportTableSection('Wallet flow by reference', $this->centralWalletReferenceRows($tenantId, $dateRange, 20, $gameId), [
                    ['key' => 'reference_type', 'label' => 'Reference'],
                    ['key' => 'inflow_amount', 'label' => 'Inflow', 'type' => 'money'],
                    ['key' => 'outflow_amount', 'label' => 'Outflow', 'type' => 'money'],
                    ['key' => 'net_amount', 'label' => 'Net', 'type' => 'money'],
                    ['key' => 'ledger_count', 'label' => 'Entries', 'type' => 'number'],
                ]),
                $this->reportTableSection('Wallet flow by partner store', $this->centralWalletByTenantRows($tenantId, $dateRange, 20, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'inflow_amount', 'label' => 'Inflow', 'type' => 'money'],
                    ['key' => 'outflow_amount', 'label' => 'Outflow', 'type' => 'money'],
                    ['key' => 'net_amount', 'label' => 'Net', 'type' => 'money'],
                ]),
            ],
            'topup_channels' => [
                $this->reportTableSection('Topup channel summary', $this->topupChannelSummaryRows($tenantId, $dateRange, $limit, true), $this->centralReportColumns('topup_channels')),
            ],
            'commission' => [
                $this->reportTableSection('Commission by partner store', $this->centralCommissionByTenantRows($tenantId, $dateRange, 20, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'commission_amount', 'label' => 'Commission', 'type' => 'money'],
                    ['key' => 'approved_amount', 'label' => 'Approved', 'type' => 'money'],
                    ['key' => 'pending_amount', 'label' => 'Pending', 'type' => 'money'],
                    ['key' => 'transaction_count', 'label' => 'Transactions', 'type' => 'number'],
                ]),
                $this->reportTableSection('Commission status mix', $this->centralMoneyStatusRows('commission_transactions', $tenantId, $dateRange, 'amount', $gameId), [
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                    ['key' => 'row_count', 'label' => 'Rows', 'type' => 'number'],
                ]),
            ],
            'rewards' => [
                $this->reportTableSection('Reward claims by partner store', $this->centralRewardsByTenantRows($tenantId, $dateRange, 20, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'prize_amount', 'label' => 'Prize', 'type' => 'money'],
                    ['key' => 'approved_amount', 'label' => 'Approved', 'type' => 'money'],
                    ['key' => 'rejected_count', 'label' => 'Rejected', 'type' => 'number'],
                    ['key' => 'claim_count', 'label' => 'Claims', 'type' => 'number'],
                ]),
                $this->reportTableSection('Reward status mix', $this->centralMoneyStatusRows('reward_claims', $tenantId, $dateRange, 'prize_amount', $gameId), [
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'amount', 'label' => 'Prize', 'type' => 'money'],
                    ['key' => 'row_count', 'label' => 'Claims', 'type' => 'number'],
                ]),
            ],
            'settlement' => [
                $this->reportTableSection('Settlement by partner store', $this->centralSettlementRows($tenantId, $dateRange, 25), $this->centralReportColumns('settlement')),
            ],
            'partner_usage' => [
                $this->reportTableSection('Usage by partner store', $this->centralUsageByTenantRows($tenantId, $dateRange, 25), $this->centralReportColumns('partner_usage')),
            ],
            'partners' => [
                $this->reportTableSection('Partner status mix', $this->centralPartnerStatusRows(), [
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'partner_count', 'label' => 'Partners', 'type' => 'number'],
                    ['key' => 'tenant_count', 'label' => 'Stores', 'type' => 'number'],
                ]),
            ],
            'audit' => [
                $this->reportTableSection('Audit actions', $this->centralAuditActionRows($tenantId, $dateRange, 25), [
                    ['key' => 'action', 'label' => 'Action'],
                    ['key' => 'event_count', 'label' => 'Events', 'type' => 'number'],
                    ['key' => 'admin_count', 'label' => 'Admins', 'type' => 'number'],
                    ['key' => 'latest_at', 'label' => 'Latest', 'type' => 'datetime'],
                ]),
            ],
            default => [
                $this->reportTableSection('Top partner stores by sales', $this->centralSalesByTenantRows($tenantId, $dateRange, 12, $gameId), [
                    ['key' => 'tenant_name', 'label' => 'Store'],
                    ['key' => 'partner_name', 'label' => 'Partner'],
                    ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                    ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                    ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ]),
                $this->reportTableSection('Operational status overview', $this->centralOverviewStatusRows($tenantId, $gameId), [
                    ['key' => 'area', 'label' => 'Area'],
                    ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                    ['key' => 'row_count', 'label' => 'Count', 'type' => 'number'],
                ]),
            ],
        };
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralReportColumns(string $reportKey): array
    {
        return match ($reportKey) {
            'overview' => [
                ['key' => 'metric', 'label' => 'Metric'],
                ['key' => 'value', 'label' => 'Value'],
                ['key' => 'unit', 'label' => 'Unit'],
            ],
            'daily' => [
                ['key' => 'tenant_name', 'label' => 'Website'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'ticket_count', 'label' => 'Tickets sold', 'type' => 'number'],
                ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
            ],
            'sales' => [
                ['key' => 'paid_at', 'label' => 'Paid at', 'type' => 'datetime'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'reference', 'label' => 'Order ref'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                ['key' => 'total_amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'payment_method', 'label' => 'Payment method'],
            ],
            'orders' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'paid_at', 'label' => 'Paid', 'type' => 'datetime'],
                ['key' => 'reference', 'label' => 'Order ref'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'payment_status', 'label' => 'Payment', 'type' => 'status'],
                ['key' => 'total_amount', 'label' => 'Amount', 'type' => 'money'],
            ],
            'customers' => [
                ['key' => 'created_at', 'label' => 'Joined', 'type' => 'datetime'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'name', 'label' => 'Customer'],
                ['key' => 'phone', 'label' => 'Phone'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'pin_set', 'label' => 'PIN set', 'type' => 'boolean'],
                ['key' => 'auto_reward', 'label' => 'Auto reward', 'type' => 'boolean'],
            ],
            'stock' => [
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'draw_at', 'label' => 'Draw date', 'type' => 'datetime'],
                ['key' => 'full_number', 'label' => 'Number'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'updated_at', 'label' => 'Updated', 'type' => 'datetime'],
            ],
            'wallet' => [
                ['key' => 'posted_at', 'label' => 'Posted', 'type' => 'datetime'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'entry_type', 'label' => 'Type', 'type' => 'status'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'balance_after', 'label' => 'Balance after', 'type' => 'money'],
                ['key' => 'reference_type', 'label' => 'Reference'],
            ],
            'topup_channels' => [
                ['key' => 'channel', 'label' => 'Payment channel', 'type' => 'status'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'row_count', 'label' => 'Total count', 'type' => 'number'],
                ['key' => 'amount', 'label' => 'Total amount', 'type' => 'money'],
                ['key' => 'details', 'label' => 'More', 'type' => 'report-details'],
            ],
            'commission' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'affiliate_name', 'label' => 'Affiliate'],
                ['key' => 'transaction_type', 'label' => 'Type'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
                ['key' => 'approved_at', 'label' => 'Approved at', 'type' => 'datetime'],
            ],
            'rewards' => [
                ['key' => 'submitted_at', 'label' => 'Submitted', 'type' => 'datetime'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'customer_name', 'label' => 'Customer'],
                ['key' => 'game_name', 'label' => 'Game'],
                ['key' => 'reference', 'label' => 'Reference'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'payout_method', 'label' => 'Payout method'],
                ['key' => 'base_prize_amount', 'label' => 'Base prize', 'type' => 'money'],
                ['key' => 'adjustment_amount', 'label' => 'Adjustment', 'type' => 'money'],
                ['key' => 'prize_amount', 'label' => 'Prize', 'type' => 'money'],
            ],
            'settlement' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'period', 'label' => 'Period'],
                ['key' => 'status', 'label' => 'Status', 'type' => 'status'],
                ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                ['key' => 'commission_amount', 'label' => 'Commission', 'type' => 'money'],
                ['key' => 'payout_amount', 'label' => 'Payout', 'type' => 'money'],
                ['key' => 'net_amount', 'label' => 'Net', 'type' => 'money'],
            ],
            'partner_usage' => [
                ['key' => 'usage_date', 'label' => 'Date'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'api_request_count', 'label' => 'API', 'type' => 'number'],
                ['key' => 'booking_request_count', 'label' => 'Bookings', 'type' => 'number'],
                ['key' => 'checkout_request_count', 'label' => 'Checkouts', 'type' => 'number'],
                ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ['key' => 'sold_ticket_count', 'label' => 'Sold tickets', 'type' => 'number'],
                ['key' => 'error_count', 'label' => 'Errors', 'type' => 'number'],
            ],
            'partners' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'partner_code', 'label' => 'Partner code'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'tenant_code', 'label' => 'Store code'],
                ['key' => 'partner_status', 'label' => 'Partner status', 'type' => 'status'],
                ['key' => 'tenant_status', 'label' => 'Store status', 'type' => 'status'],
            ],
            'audit' => [
                ['key' => 'created_at', 'label' => 'Created', 'type' => 'datetime'],
                ['key' => 'scope_type', 'label' => 'Scope'],
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'actor_type', 'label' => 'Actor'],
                ['key' => 'actor_id', 'label' => 'Actor ID'],
                ['key' => 'action', 'label' => 'Action'],
                ['key' => 'target_type', 'label' => 'Target'],
                ['key' => 'ip_address', 'label' => 'IP'],
            ],
            default => [
                ['key' => 'tenant_name', 'label' => 'Store'],
                ['key' => 'partner_name', 'label' => 'Partner'],
                ['key' => 'sales_amount', 'label' => 'Sales', 'type' => 'money'],
                ['key' => 'ticket_count', 'label' => 'Tickets', 'type' => 'number'],
                ['key' => 'order_count', 'label' => 'Orders', 'type' => 'number'],
                ['key' => 'customer_count', 'label' => 'Customers', 'type' => 'number'],
                ['key' => 'stock_total_count', 'label' => 'Stock', 'type' => 'number'],
                ['key' => 'reward_payout_amount', 'label' => 'Rewards', 'type' => 'money'],
                ['key' => 'wallet_net_amount', 'label' => 'Wallet net', 'type' => 'money'],
            ],
        };
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function centralReportRows(?string $tenantId, string $reportKey, array $dateRange, int $limit, ?string $gameId): array
    {
        return match ($reportKey) {
            'overview' => [],
            'daily' => $this->centralDailySalesByPartnerRows($tenantId, $dateRange, $limit, $gameId),
            'sales' => $this->centralSalesOrderRows($tenantId, $dateRange, $limit, $gameId),
            'orders' => $this->centralOrderRows($tenantId, $dateRange, $limit, $gameId),
            'customers' => $this->centralCustomerRows($tenantId, $dateRange, $limit),
            'stock' => $this->centralStockRows($tenantId, $limit, $gameId),
            'wallet' => $this->centralWalletRows($tenantId, $dateRange, $limit, $gameId),
            'topup_channels' => $this->topupChannelSummaryRows($tenantId, $dateRange, $limit, true),
            'commission' => $this->centralCommissionRows($tenantId, $dateRange, $limit, $gameId),
            'rewards' => $this->centralRewardRows($tenantId, $dateRange, $limit, $gameId),
            'settlement' => $this->centralSettlementRows($tenantId, $dateRange, $limit),
            'partner_usage' => $this->centralUsageRows($tenantId, $dateRange, $limit),
            'partners' => $this->centralPartnerRows($tenantId, $limit),
            'audit' => $this->centralAuditRows($tenantId, $dateRange, $limit),
            default => $this->centralOverviewRows($tenantId, $dateRange, $limit, $gameId),
        };
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantOverviewRows(string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $sales = collect($this->centralSalesByGameRows($tenantId, $dateRange, $limit, $gameId))->keyBy('game_id');
        $stock = collect($this->tenantLocalStockByGameRows($tenantId, $limit, $gameId))->keyBy('game_id');
        $rewards = collect($this->tenantRewardByGameRows($tenantId, $dateRange, $limit, $gameId))->keyBy('game_id');
        $gameIds = $sales->keys()->merge($stock->keys())->merge($rewards->keys())->unique()->take($limit);

        return $gameIds->map(function (string $id) use ($sales, $stock, $rewards): array {
            $sale = $sales[$id] ?? [];
            $stockRow = $stock[$id] ?? [];
            $reward = $rewards[$id] ?? [];

            return [
                'game_id' => $id,
                'game_name' => $sale['game_name'] ?? $stockRow['game_name'] ?? $reward['game_name'] ?? $id,
                'draw_at' => $sale['draw_at'] ?? $stockRow['draw_at'] ?? $reward['draw_at'] ?? null,
                'sales_amount' => $sale['sales_amount'] ?? $this->money(0),
                'ticket_count' => $sale['ticket_count'] ?? 0,
                'order_count' => $sale['order_count'] ?? 0,
                'stock_total_count' => $stockRow['total_count'] ?? 0,
                'stock_sold_count' => $stockRow['sold_count'] ?? 0,
                'reward_payout_amount' => $reward['prize_amount'] ?? $this->money(0),
                'reward_claim_count' => $reward['claim_count'] ?? 0,
            ];
        })->values()->all();
    }

    private function tenantLocalStockCount(string $tenantId, ?string $gameId, ?string $status = null): int
    {
        return (int) DB::table('local_stock_items')
            ->where('tenant_id', $tenantId)
            ->when($gameId !== null, fn ($query) => $query->where('game_id', $gameId))
            ->when($status !== null, fn ($query) => $query->where('status', $status))
            ->count();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantLocalStockRows(string $tenantId, int $limit, ?string $gameId): array
    {
        $query = DB::table('local_stock_items')
            ->leftJoin('games', 'games.id', '=', 'local_stock_items.game_id')
            ->select([
                'local_stock_items.id',
                'local_stock_items.game_id',
                'local_stock_items.full_number',
                'local_stock_items.front3',
                'local_stock_items.back3',
                'local_stock_items.back2',
                'local_stock_items.status',
                'local_stock_items.synced_at',
                'local_stock_items.reserved_at',
                'local_stock_items.sold_at',
                'local_stock_items.updated_at',
                'games.name as game_name',
                'games.draw_at',
            ])
            ->where('local_stock_items.tenant_id', $tenantId)
            ->orderByDesc('local_stock_items.updated_at')
            ->limit($limit);
        $this->applyCentralGameFilter($query, $gameId, 'local_stock_items.game_id');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'game_id' => (string) $row->game_id,
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'draw_at' => $this->iso($row->draw_at),
            'full_number' => (string) $row->full_number,
            'front3' => (string) ($row->front3 ?? '-'),
            'back3' => (string) ($row->back3 ?? '-'),
            'back2' => (string) ($row->back2 ?? '-'),
            'status' => (string) $row->status,
            'synced_at' => $this->iso($row->synced_at),
            'reserved_at' => $this->iso($row->reserved_at),
            'sold_at' => $this->iso($row->sold_at),
            'updated_at' => $this->iso($row->updated_at),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantLocalStockByGameRows(string $tenantId, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('local_stock_items')
            ->leftJoin('games', 'games.id', '=', 'local_stock_items.game_id')
            ->select([
                'local_stock_items.game_id',
                'games.name as game_name',
                'games.draw_at',
                DB::raw('COUNT(local_stock_items.id) as total_count'),
                DB::raw("SUM(CASE WHEN local_stock_items.status = 'available' THEN 1 ELSE 0 END) as available_count"),
                DB::raw("SUM(CASE WHEN local_stock_items.status = 'sold' THEN 1 ELSE 0 END) as sold_count"),
                DB::raw("SUM(CASE WHEN local_stock_items.status = 'reserved' THEN 1 ELSE 0 END) as reserved_count"),
            ])
            ->where('local_stock_items.tenant_id', $tenantId)
            ->groupBy('local_stock_items.game_id', 'games.name', 'games.draw_at')
            ->orderByDesc('games.draw_at')
            ->limit($limit);
        $this->applyCentralGameFilter($query, $gameId, 'local_stock_items.game_id');

        return $query->get()->map(fn (object $row): array => [
            'game_id' => (string) $row->game_id,
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'draw_at' => $this->iso($row->draw_at),
            'total_count' => (int) $row->total_count,
            'available_count' => (int) $row->available_count,
            'sold_count' => (int) $row->sold_count,
            'reserved_count' => (int) $row->reserved_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantLocalStockStatusRows(string $tenantId, ?string $gameId): array
    {
        $total = max(1, $this->tenantLocalStockCount($tenantId, $gameId));
        $query = DB::table('local_stock_items')
            ->select([DB::raw("COALESCE(status, 'unknown') as label"), DB::raw('COUNT(*) as row_count')])
            ->where('tenant_id', $tenantId)
            ->groupBy('label')
            ->orderByDesc('row_count');
        $this->applyCentralGameFilter($query, $gameId, 'game_id');

        return $query->get()->map(fn (object $row): array => [
            'label' => (string) $row->label,
            'row_count' => (int) $row->row_count,
            'percent' => round(((int) $row->row_count / $total) * 100, 2),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function tenantLocalStockNumberSegmentRows(string $tenantId, ?string $gameId): array
    {
        return collect([
            ['Front 3 digits', 'front3'],
            ['Back 3 digits', 'back3'],
            ['Back 2 digits', 'back2'],
        ])->map(function (array $segment) use ($tenantId, $gameId): array {
            [$label, $column] = $segment;
            $base = DB::table('local_stock_items')
                ->where('tenant_id', $tenantId)
                ->whereNotNull($column);
            $this->applyCentralGameFilter($base, $gameId, 'game_id');

            return [
                'segment' => $label,
                'unique_count' => (int) (clone $base)->distinct()->count($column),
                'sold_count' => (int) (clone $base)->where('status', 'sold')->count(),
                'available_count' => (int) (clone $base)->where('status', 'available')->count(),
            ];
        })->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantStatusRows(string $table, string $tenantId, array $dateRange, string $labelColumn = 'status', ?string $amountColumn = null, string $dateExpression = 'created_at', ?string $gameId = null, ?string $gameColumn = 'game_id'): array
    {
        $select = [
            DB::raw('COALESCE('.$labelColumn.", 'unknown') as label"),
            DB::raw('COUNT(*) as row_count'),
        ];

        if ($amountColumn !== null) {
            $select[] = DB::raw('SUM('.$amountColumn.') as amount');
        }

        $query = DB::table($table)
            ->select($select)
            ->where($table.'.tenant_id', $tenantId)
            ->groupBy('label')
            ->orderByDesc($amountColumn !== null ? 'amount' : 'row_count');

        if ($gameId !== null && $gameColumn !== null) {
            $query->where($gameColumn, $gameId);
        }

        $this->applyCentralDateRange($query, $dateRange, $dateExpression);

        return $query->get()->map(function (object $row) use ($amountColumn): array {
            $resource = [
                'label' => (string) $row->label,
                'row_count' => (int) $row->row_count,
            ];

            if ($amountColumn !== null) {
                $resource['amount'] = $this->money((int) $row->amount);
            }

            return $resource;
        })->all();
    }

    private function tenantWalletLedgerTotal(string $tenantId, array $dateRange, ?string $gameId): int
    {
        $query = DB::table('wallet_ledger')
            ->where('wallet_ledger.tenant_id', $tenantId);
        $this->applyCentralWalletGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)');

        return (int) $query->sum('wallet_ledger.amount');
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantWalletStatusRows(string $tenantId, array $dateRange, ?string $gameId): array
    {
        $query = DB::table('wallet_ledger')
            ->select([
                DB::raw("COALESCE(wallet_ledger.status, 'unknown') as label"),
                DB::raw('SUM(wallet_ledger.amount) as amount'),
                DB::raw('COUNT(*) as row_count'),
            ])
            ->where('wallet_ledger.tenant_id', $tenantId)
            ->groupBy('label')
            ->orderByDesc('amount');
        $this->applyCentralWalletGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'label' => (string) $row->label,
            'amount' => $this->money((int) $row->amount),
            'row_count' => (int) $row->row_count,
        ])->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantCustomerPreferenceRows(string $tenantId, array $dateRange): array
    {
        $base = DB::table('customers')->where('tenant_id', $tenantId);
        $this->applyCentralDateRange($base, $dateRange, 'customers.created_at');
        $total = max(1, (int) (clone $base)->count());

        return collect([
            ['PIN set', 'pin_set_at IS NOT NULL'],
            ['Auto reward enabled', 'auto_reward_claim_enabled = true'],
            ["Auto reward wallet", "auto_reward_claim_payout_method = 'wallet_credit'"],
            ["Auto reward bank transfer", "auto_reward_claim_payout_method = 'bank_transfer'"],
        ])->map(function (array $preference) use ($base, $total): array {
            [$label, $condition] = $preference;
            $enabled = (int) (clone $base)->whereRaw($condition)->count();

            return [
                'label' => $label,
                'enabled_count' => $enabled,
                'customer_count' => $total,
                'percent' => round(($enabled / $total) * 100, 2),
            ];
        })->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantCommissionByAffiliateRows(string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = DB::table('commission_transactions')
            ->leftJoin('affiliate_accounts', 'affiliate_accounts.id', '=', 'commission_transactions.affiliate_account_id')
            ->select([
                'commission_transactions.affiliate_account_id',
                'affiliate_accounts.name as affiliate_name',
                'affiliate_accounts.code as affiliate_code',
                DB::raw('SUM(commission_transactions.amount) as commission_amount'),
                DB::raw("SUM(CASE WHEN commission_transactions.status = 'approved' THEN commission_transactions.amount ELSE 0 END) as approved_amount"),
                DB::raw("SUM(CASE WHEN commission_transactions.status = 'approved' THEN 0 ELSE commission_transactions.amount END) as pending_amount"),
                DB::raw('COUNT(*) as transaction_count'),
            ])
            ->where('commission_transactions.tenant_id', $tenantId)
            ->groupBy('commission_transactions.affiliate_account_id', 'affiliate_accounts.name', 'affiliate_accounts.code')
            ->orderByDesc('commission_amount')
            ->limit($limit);
        $this->applyCentralCommissionGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(commission_transactions.approved_at, commission_transactions.calculated_at, commission_transactions.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'affiliate_name' => (string) ($row->affiliate_name ?? $row->affiliate_account_id),
            'affiliate_code' => (string) ($row->affiliate_code ?? '-'),
            'commission_amount' => $this->money((int) $row->commission_amount),
            'approved_amount' => $this->money((int) $row->approved_amount),
            'pending_amount' => $this->money((int) $row->pending_amount),
            'transaction_count' => (int) $row->transaction_count,
        ])->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantRewardMethodRows(string $tenantId, array $dateRange, ?string $gameId): array
    {
        $query = DB::table('reward_claims')
            ->select([
                DB::raw("COALESCE(payout_method, 'unknown') as payout_method"),
                DB::raw('SUM(prize_amount) as prize_amount'),
                DB::raw('COUNT(*) as claim_count'),
                DB::raw("SUM(CASE WHEN status IN ('approved', 'paid') THEN 1 ELSE 0 END) as approved_count"),
                DB::raw("SUM(CASE WHEN status = 'rejected' THEN 1 ELSE 0 END) as rejected_count"),
            ])
            ->where('tenant_id', $tenantId)
            ->groupBy('payout_method')
            ->orderByDesc('prize_amount');
        $this->applyCentralGameFilter($query, $gameId, 'game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(reward_claims.submitted_at, reward_claims.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'payout_method' => (string) $row->payout_method,
            'prize_amount' => $this->money((int) $row->prize_amount),
            'claim_count' => (int) $row->claim_count,
            'approved_count' => (int) $row->approved_count,
            'rejected_count' => (int) $row->rejected_count,
        ])->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantRewardByGameRows(string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = DB::table('reward_claims')
            ->leftJoin('games', 'games.id', '=', 'reward_claims.game_id')
            ->select([
                'reward_claims.game_id',
                'games.name as game_name',
                'games.draw_at',
                DB::raw('SUM(reward_claims.prize_amount) as prize_amount'),
                DB::raw('COUNT(*) as claim_count'),
                DB::raw("SUM(CASE WHEN reward_claims.status IN ('approved', 'paid') THEN 1 ELSE 0 END) as approved_count"),
                DB::raw("SUM(CASE WHEN reward_claims.status = 'rejected' THEN 1 ELSE 0 END) as rejected_count"),
            ])
            ->where('reward_claims.tenant_id', $tenantId)
            ->groupBy('reward_claims.game_id', 'games.name', 'games.draw_at')
            ->orderByDesc('games.draw_at')
            ->limit($limit);
        $this->applyCentralGameFilter($query, $gameId, 'reward_claims.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(reward_claims.submitted_at, reward_claims.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'game_id' => (string) $row->game_id,
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'draw_at' => $this->iso($row->draw_at),
            'prize_amount' => $this->money((int) $row->prize_amount),
            'claim_count' => (int) $row->claim_count,
            'approved_count' => (int) $row->approved_count,
            'rejected_count' => (int) $row->rejected_count,
        ])->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantRewardPrizeTypeRows(string $tenantId, array $dateRange, ?string $gameId): array
    {
        if (! Schema::hasTable('winning_tickets')) {
            return [];
        }

        $query = DB::table('winning_tickets')
            ->join('tickets', 'tickets.id', '=', 'winning_tickets.ticket_id')
            ->select([
                'winning_tickets.prize_type',
                'winning_tickets.amount',
                'winning_tickets.currency',
                'tickets.customer_id',
            ])
            ->where('winning_tickets.tenant_id', $tenantId);
        $this->applyCentralGameFilter($query, $gameId, 'winning_tickets.game_id');
        if ($gameId === null) {
            $this->applyCentralDateRange($query, $dateRange, 'winning_tickets.created_at');
        }

        return $query->get()
            ->groupBy(fn (object $row): string => (string) $row->prize_type)
            ->map(function ($rows, string $prizeType): array {
                $winnerUserCount = $rows
                    ->pluck('customer_id')
                    ->filter(fn (mixed $value): bool => $value !== null && $value !== '')
                    ->unique()
                    ->count();
                $prizeAmount = $rows->reduce(
                    fn (int $total, object $row): int => $total + $this->normalizeWinningTicketReportAmount($row),
                    0,
                );

                return [
                    'prize_type' => $prizeType,
                    'prize_label' => $this->rewardPrizeTypeReportLabel($prizeType),
                    'winner_user_count' => $winnerUserCount,
                    'winning_ticket_count' => $rows->count(),
                    'prize_amount' => $this->money($prizeAmount),
                ];
            })
            ->sortBy(fn (array $row): int => $this->rewardPrizeTypeSortOrder((string) $row['prize_type']))
            ->values()
            ->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantRewardPrizeTypeWinnerRows(string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        if (! Schema::hasTable('winning_tickets')) {
            return [];
        }

        $query = DB::table('winning_tickets')
            ->join('tickets', 'tickets.id', '=', 'winning_tickets.ticket_id')
            ->leftJoin('customers', 'customers.id', '=', 'tickets.customer_id')
            ->select([
                'winning_tickets.prize_type',
                'tickets.customer_id',
                'customers.customer_no',
                'customers.name as customer_name',
                'tickets.full_number',
                DB::raw('COUNT(winning_tickets.id) as ticket_count'),
            ])
            ->where('winning_tickets.tenant_id', $tenantId)
            ->groupBy('winning_tickets.prize_type', 'tickets.customer_id', 'customers.customer_no', 'customers.name', 'tickets.full_number')
            ->limit($limit);
        $this->applyCentralGameFilter($query, $gameId, 'winning_tickets.game_id');
        if ($gameId === null) {
            $this->applyCentralDateRange($query, $dateRange, 'winning_tickets.created_at');
        }

        return $query->get()
            ->map(fn (object $row): array => [
                'prize_type' => (string) $row->prize_type,
                'prize_label' => $this->rewardPrizeTypeReportLabel((string) $row->prize_type),
                'user_id' => (string) ($row->customer_no ?? $row->customer_id),
                'account' => (string) ($row->customer_name ?? $row->customer_id),
                'ticket_number' => (string) $row->full_number,
                'ticket_count' => (int) $row->ticket_count,
            ])
            ->sort(function (array $left, array $right): int {
                return ($this->rewardPrizeTypeSortOrder((string) $left['prize_type']) <=> $this->rewardPrizeTypeSortOrder((string) $right['prize_type']))
                    ?: ((int) $right['ticket_count'] <=> (int) $left['ticket_count'])
                    ?: ((string) $left['ticket_number'] <=> (string) $right['ticket_number']);
            })
            ->values()
            ->all();
    }

    private function rewardPrizeTypeReportLabel(string $type): string
    {
        return match ($type) {
            'first_prize' => 'First prize',
            'near_first_prize' => 'Near first prize',
            'second_prize' => 'Second prize',
            'third_prize' => 'Third prize',
            'fourth_prize' => 'Fourth prize',
            'fifth_prize' => 'Fifth prize',
            'front3' => 'Front 3 digits, 2 draws',
            'back3' => 'Back 3 digits, 2 draws',
            'back2' => 'Back 2 digits',
            default => Str::headline($type),
        };
    }

    private function rewardPrizeTypeSortOrder(string $type): int
    {
        return match ($type) {
            'first_prize' => 10,
            'near_first_prize' => 20,
            'second_prize' => 30,
            'third_prize' => 40,
            'fourth_prize' => 50,
            'fifth_prize' => 60,
            'front3' => 70,
            'back3' => 80,
            'back2' => 90,
            default => 999,
        };
    }

    private function normalizeWinningTicketReportAmount(object $row): int
    {
        return ThaiGovernmentLotteryRewardTemplate::normalizeStoredMinorAmount(
            (string) ($row->prize_type ?? ''),
            (int) ($row->amount ?? 0),
            (string) ($row->currency ?? ThaiGovernmentLotteryRewardTemplate::CURRENCY),
        );
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantSettlementStatusRows(string $tenantId, array $dateRange): array
    {
        $query = DB::table('partner_settlements')
            ->select([
                'status',
                DB::raw('SUM(sales_amount) as sales_amount'),
                DB::raw('SUM(commission_amount) as commission_amount'),
                DB::raw('SUM(payout_amount) as payout_amount'),
                DB::raw('SUM(net_amount) as net_amount'),
                DB::raw('COUNT(*) as row_count'),
            ])
            ->where('tenant_id', $tenantId)
            ->groupBy('status')
            ->orderByDesc('net_amount');
        $this->applyCentralDateRange($query, $dateRange, 'partner_settlements.created_at');

        return $query->get()->map(fn (object $row): array => [
            'status' => (string) $row->status,
            'sales_amount' => $this->money((int) $row->sales_amount),
            'commission_amount' => $this->money((int) $row->commission_amount),
            'payout_amount' => $this->money((int) $row->payout_amount),
            'net_amount' => $this->money((int) $row->net_amount),
            'row_count' => (int) $row->row_count,
        ])->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantOverviewStatusRows(string $tenantId, array $dateRange, ?string $gameId): array
    {
        $rows = [];

        foreach ([
            ['Orders', 'orders', 'status', 'orders.created_at', 'orders.game_id'],
            ['Local stock', 'local_stock_items', 'status', 'local_stock_items.created_at', 'local_stock_items.game_id'],
            ['Reward claims', 'reward_claims', 'status', 'reward_claims.created_at', 'reward_claims.game_id'],
            ['Wallet ledger', 'wallet_ledger', 'status', 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)', null],
            ['Commission', 'commission_transactions', 'status', 'commission_transactions.created_at', null],
        ] as [$area, $table, $labelColumn, $dateExpression, $gameColumn]) {
            foreach ($this->tenantStatusRows($table, $tenantId, $dateRange, $labelColumn, null, $dateExpression, $gameId, $gameColumn) as $row) {
                $rows[] = [
                    'area' => $area,
                    'status' => $row['label'],
                    'row_count' => $row['row_count'],
                ];
            }
        }

        return $rows;
    }

    private function tenantRewardClaimSum(string $tenantId, array $dateRange, string $expression, ?string $gameId): int
    {
        $query = DB::table('reward_claims')
            ->where('tenant_id', $tenantId)
            ->selectRaw('COALESCE(SUM('.$expression.'), 0) as aggregate');
        $this->applyCentralGameFilter($query, $gameId, 'game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(reward_claims.submitted_at, reward_claims.created_at)');

        return (int) $query->value('aggregate');
    }

    /**
     * @return array<string, mixed>
     */
    private function reportTableSection(string $title, array $rows, array $columns): array
    {
        return [
            'type' => 'table',
            'title' => $title,
            'columns' => $columns,
            'rows' => $rows,
        ];
    }

    private function applyCentralDateRange(mixed $query, array $dateRange, string $expression): void
    {
        if ($dateRange['from'] !== null) {
            $query->whereRaw($expression.' >= ?', [$dateRange['from']]);
        }

        if ($dateRange['to'] !== null) {
            $query->whereRaw($expression.' <= ?', [$dateRange['to']]);
        }
    }

    private function applyCentralTenantFilter(mixed $query, ?string $tenantId, string $column = 'tenant_id'): void
    {
        if ($tenantId !== null) {
            $query->where($column, $tenantId);
        }
    }

    private function applyCentralGameFilter(mixed $query, ?string $gameId, string $column = 'game_id'): void
    {
        if ($gameId !== null) {
            $query->where($column, $gameId);
        }
    }

    private function applyCentralCommissionGameFilter(mixed $query, ?string $gameId): void
    {
        if ($gameId === null) {
            return;
        }

        $query->whereExists(function ($subQuery) use ($gameId): void {
            $subQuery->selectRaw('1')
                ->from('orders')
                ->whereColumn('orders.id', 'commission_transactions.order_id')
                ->where('orders.game_id', $gameId);
        });
    }

    private function applyCentralWalletGameFilter(mixed $query, ?string $gameId): void
    {
        if ($gameId === null) {
            return;
        }

        $query->where(function ($query) use ($gameId): void {
            $query->whereExists(function ($subQuery) use ($gameId): void {
                $subQuery->selectRaw('1')
                    ->from('orders')
                    ->whereColumn('orders.id', 'wallet_ledger.reference_id')
                    ->where('wallet_ledger.reference_type', 'order')
                    ->where('orders.game_id', $gameId);
            })->orWhereExists(function ($subQuery) use ($gameId): void {
                $subQuery->selectRaw('1')
                    ->from('reward_claims')
                    ->whereColumn('reward_claims.id', 'wallet_ledger.reference_id')
                    ->where('wallet_ledger.reference_type', 'reward_claim')
                    ->where('reward_claims.game_id', $gameId);
            });
        });
    }

    private function applyPaidOrderFilter(mixed $query): void
    {
        $query->where(function ($query): void {
            $query->where('orders.payment_status', 'paid')
                ->orWhereNotNull('orders.paid_at')
                ->orWhereIn('orders.status', ['paid', 'completed']);
        });
    }

    private function centralPaidOrdersQuery(?string $tenantId, array $dateRange, ?string $gameId = null): mixed
    {
        $query = DB::table('orders');
        $this->applyPaidOrderFilter($query);
        $this->applyCentralTenantFilter($query, $tenantId, 'orders.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'orders.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');

        return $query;
    }

    private function centralOrdersQuery(?string $tenantId, array $dateRange, ?string $gameId = null): mixed
    {
        $query = DB::table('orders');
        $this->applyCentralTenantFilter($query, $tenantId, 'orders.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'orders.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'orders.created_at');

        return $query;
    }

    private function centralPaidTicketsCount(?string $tenantId, array $dateRange, ?string $gameId): int
    {
        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id');
        $this->applyPaidOrderFilter($query);
        $this->applyCentralTenantFilter($query, $tenantId, 'tickets.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'tickets.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');

        return (int) $query->count('tickets.id');
    }

    private function centralDateScopedCount(string $table, ?string $tenantId, array $dateRange, string $dateColumn = 'created_at', ?string $gameId = null): int
    {
        $query = DB::table($table);
        $this->applyCentralTenantFilter($query, $tenantId, $table.'.tenant_id');
        if ($gameId !== null) {
            if ($table === 'commission_transactions') {
                $this->applyCentralCommissionGameFilter($query, $gameId);
            } elseif ($table === 'wallet_ledger') {
                $this->applyCentralWalletGameFilter($query, $gameId);
            } else {
                $this->applyCentralGameFilter($query, $gameId, $table.'.game_id');
            }
        }
        $this->applyCentralDateRange($query, $dateRange, $table.'.'.$dateColumn);

        return (int) $query->count();
    }

    private function centralWalletFlowTotal(?string $tenantId, array $dateRange, string $direction, ?string $gameId): int
    {
        $query = DB::table('wallet_ledger');
        $this->applyCentralTenantFilter($query, $tenantId, 'wallet_ledger.tenant_id');
        $this->applyCentralWalletGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)');

        if ($direction === 'outflow') {
            $query->whereIn('entry_type', ['debit', 'hold']);
        } else {
            $query->whereNotIn('entry_type', ['debit', 'hold']);
        }

        return (int) $query->sum('amount');
    }

    private function centralRewardClaimTotal(?string $tenantId, array $dateRange, ?string $gameId): int
    {
        $query = DB::table('reward_claims');
        $this->applyCentralTenantFilter($query, $tenantId, 'reward_claims.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'reward_claims.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(reward_claims.paid_at, reward_claims.submitted_at, reward_claims.created_at)');

        return (int) $query->sum('prize_amount');
    }

    private function centralCommissionTotal(?string $tenantId, array $dateRange, ?string $gameId): int
    {
        $query = DB::table('commission_transactions');
        $this->applyCentralTenantFilter($query, $tenantId, 'commission_transactions.tenant_id');
        $this->applyCentralCommissionGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(commission_transactions.approved_at, commission_transactions.calculated_at, commission_transactions.created_at)');

        return (int) $query->sum('amount');
    }

    private function centralAffiliatePayoutTotal(?string $tenantId, array $dateRange): int
    {
        $query = DB::table('affiliate_payouts');
        $this->applyCentralTenantFilter($query, $tenantId, 'affiliate_payouts.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(affiliate_payouts.paid_at, affiliate_payouts.approved_at, affiliate_payouts.created_at)');
        $query->where('status', 'paid');

        return (int) $query->sum('amount');
    }

    private function centralSettlementTotal(?string $tenantId, array $dateRange, string $column): int
    {
        $query = DB::table('partner_settlements');
        $this->applyCentralTenantFilter($query, $tenantId, 'partner_settlements.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'partner_settlements.created_at');

        return (int) $query->sum($column);
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralOverviewRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $sales = collect($this->centralSalesByTenantRows($tenantId, $dateRange, $limit, $gameId))->keyBy('tenant_id');
        $stock = collect($this->centralStockByTenantRows($tenantId, $limit, $gameId))->keyBy('tenant_id');
        $wallet = collect($this->centralWalletByTenantRows($tenantId, $dateRange, $limit, $gameId))->keyBy('tenant_id');
        $rewards = collect($this->centralRewardsByTenantRows($tenantId, $dateRange, $limit, $gameId))->keyBy('tenant_id');
        $tenantIds = $sales->keys()->merge($stock->keys())->merge($wallet->keys())->merge($rewards->keys())->unique()->take($limit);

        return $tenantIds->map(function (string $id) use ($sales, $stock, $wallet, $rewards): array {
            $sale = $sales[$id] ?? [];
            $stockRow = $stock[$id] ?? [];
            $walletRow = $wallet[$id] ?? [];
            $reward = $rewards[$id] ?? [];

            return [
                'tenant_id' => $id,
                'tenant_name' => $sale['tenant_name'] ?? $stockRow['tenant_name'] ?? $walletRow['tenant_name'] ?? $reward['tenant_name'] ?? $id,
                'partner_name' => $sale['partner_name'] ?? $stockRow['partner_name'] ?? $walletRow['partner_name'] ?? $reward['partner_name'] ?? '-',
                'sales_amount' => $sale['sales_amount'] ?? $this->money(0),
                'ticket_count' => $sale['ticket_count'] ?? 0,
                'order_count' => $sale['order_count'] ?? 0,
                'customer_count' => $sale['customer_count'] ?? 0,
                'stock_total_count' => $stockRow['total_count'] ?? 0,
                'reward_payout_amount' => $reward['prize_amount'] ?? $this->money(0),
                'wallet_net_amount' => $walletRow['net_amount'] ?? $this->money(0),
            ];
        })->values()->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantRevenueSummaryRows(string $tenantId, array $dateRange, ?string $gameId): array
    {
        $paidOrders = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId);
        $paidOrderCount = (int) (clone $paidOrders)->count();
        $salesTotal = (int) (clone $paidOrders)->sum('orders.total_amount');
        $soldTickets = $this->centralPaidTicketsCount($tenantId, $dateRange, $gameId);
        $randomBoxTickets = 0;
        $winningTickets = $this->centralWinningTicketCount($tenantId, $dateRange, $gameId);
        $nonWinningTickets = $this->centralNonWinningTicketCount($tenantId, $dateRange, $gameId);
        $commissionTotal = $this->centralCommissionTotal($tenantId, $dateRange, $gameId);
        $revenueAfterCommission = $salesTotal - $commissionTotal;
        $randomBoxRevenue = 0;
        $cashbackActivityTotal = $this->centralActivityAwardTotal($tenantId, $dateRange, $gameId, 'cashback');
        $winningPrizeTotal = $this->centralWinningPrizeTotal($tenantId, $dateRange, $gameId);
        $netProfit = $revenueAfterCommission + $randomBoxRevenue - $cashbackActivityTotal - $winningPrizeTotal;
        $customerCount = (int) Customer::query()->where('tenant_id', $tenantId)->count();

        return [
            $this->reportMetricRow('Total orders', $paidOrderCount, 'orders'),
            $this->reportMetricRow('Total sold tickets', $soldTickets, 'tickets'),
            $this->reportMetricRow('Random-box sold tickets', $randomBoxTickets, 'tickets'),
            $this->reportMetricRow('Winning tickets', $winningTickets, 'tickets'),
            $this->reportMetricRow('Non-winning tickets', $nonWinningTickets, 'tickets'),
            $this->reportMetricRow('Lottery sales amount', $this->money($salesTotal)),
            $this->reportMetricRow('Revenue after commission', $this->money($revenueAfterCommission)),
            $this->reportMetricRow('Random-box revenue', $this->money($randomBoxRevenue)),
            $this->reportMetricRow('Cashback activities', $this->money($cashbackActivityTotal)),
            $this->reportMetricRow('Winning prize total', $this->money($winningPrizeTotal)),
            $this->reportMetricRow('Net profit', $this->money($netProfit)),
            $this->reportMetricRow('Total customers', $customerCount, 'customers'),
        ];
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function tenantRevenuePaymentRows(string $tenantId, array $dateRange, ?string $gameId): array
    {
        return $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId)
            ->select([
                DB::raw("COALESCE(orders.payment_method, 'unknown') as payment_method"),
                DB::raw('COUNT(orders.id) as order_count'),
                DB::raw('SUM(orders.total_amount) as sales_amount'),
            ])
            ->groupBy('payment_method')
            ->orderByDesc('sales_amount')
            ->get()
            ->map(fn (object $row): array => [
                'payment_method' => (string) $row->payment_method,
                'order_count' => (int) $row->order_count,
                'sales_amount' => $this->money((int) $row->sales_amount),
            ])
            ->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function centralRevenueSummaryRows(?string $tenantId, array $dateRange, ?string $gameId): array
    {
        $paidOrders = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId);
        $salesTotal = (int) (clone $paidOrders)->sum('orders.total_amount');
        $soldTickets = $this->centralPaidTicketsCount($tenantId, $dateRange, $gameId);
        $winningTickets = $this->centralWinningTicketCount($tenantId, $dateRange, $gameId);
        $winningPrizeTotal = $this->centralWinningPrizeTotal($tenantId, $dateRange, $gameId);
        $affiliateExpense = $this->centralCommissionTotal($tenantId, $dateRange, $gameId);
        $activityExpense = $this->centralActivityAwardTotal($tenantId, $dateRange, $gameId);
        $profit = $salesTotal - $winningPrizeTotal - $affiliateExpense - $activityExpense;

        return [
            $this->reportMetricRow('Sold tickets', $soldTickets, 'tickets'),
            $this->reportMetricRow('Winning tickets', $winningTickets, 'tickets'),
            $this->reportMetricRow('Non-winning tickets', max(0, $soldTickets - $winningTickets), 'tickets'),
            $this->reportMetricRow('Affiliate expenses', $this->money($affiliateExpense)),
            $this->reportMetricRow('Activity expenses', $this->money($activityExpense)),
            $this->reportMetricRow('Sales amount', $this->money($salesTotal)),
            $this->reportMetricRow('Winning prize total', $this->money($winningPrizeTotal)),
            $this->reportMetricRow('Profit', $this->money($profit)),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function reportMetricRow(string $metric, mixed $value, string $unit = ''): array
    {
        return [
            'metric' => $metric,
            'value' => $value,
            'unit' => $unit,
        ];
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     */
    private function centralWinningTicketCount(?string $tenantId, array $dateRange, ?string $gameId): int
    {
        if (! Schema::hasTable('winning_tickets')) {
            return 0;
        }

        $query = DB::table('winning_tickets');
        $this->applyCentralTenantFilter($query, $tenantId, 'winning_tickets.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'winning_tickets.game_id');
        if ($gameId === null) {
            $this->applyCentralDateRange($query, $dateRange, 'winning_tickets.created_at');
        }

        return (int) $query->distinct('winning_tickets.ticket_id')->count('winning_tickets.ticket_id');
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     */
    private function centralWinningPrizeTotal(?string $tenantId, array $dateRange, ?string $gameId): int
    {
        if (! Schema::hasTable('winning_tickets')) {
            return 0;
        }

        $query = DB::table('winning_tickets');
        $this->applyCentralTenantFilter($query, $tenantId, 'winning_tickets.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'winning_tickets.game_id');
        if ($gameId === null) {
            $this->applyCentralDateRange($query, $dateRange, 'winning_tickets.created_at');
        }

        return $query
            ->select(['winning_tickets.prize_type', 'winning_tickets.amount', 'winning_tickets.currency'])
            ->get()
            ->reduce(
                fn (int $total, object $row): int => $total + $this->normalizeWinningTicketReportAmount($row),
                0,
            );
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     */
    private function centralNonWinningTicketCount(?string $tenantId, array $dateRange, ?string $gameId): int
    {
        $query = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->where('tickets.status', 'non_winning');
        $this->applyPaidOrderFilter($query);
        $this->applyCentralTenantFilter($query, $tenantId, 'tickets.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'tickets.game_id');
        if ($gameId === null) {
            $this->applyCentralDateRange($query, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');
        }

        return (int) $query->count('tickets.id');
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     */
    private function centralActivityAwardTotal(?string $tenantId, array $dateRange, ?string $gameId, ?string $type = null): int
    {
        if (! Schema::hasTable('tenant_activity_awards')) {
            return 0;
        }

        $query = DB::table('tenant_activity_awards')
            ->whereIn('tenant_activity_awards.status', ['claimable', 'claimed', 'paid']);
        $this->applyCentralTenantFilter($query, $tenantId, 'tenant_activity_awards.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'tenant_activity_awards.game_id');
        if ($type !== null) {
            $query->where('tenant_activity_awards.type', $type);
        }
        if ($gameId === null) {
            $this->applyCentralDateRange($query, $dateRange, 'COALESCE(tenant_activity_awards.calculated_at, tenant_activity_awards.created_at)');
        }

        return (int) $query->sum('tenant_activity_awards.amount');
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDailySalesByPartnerRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $salesRows = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId)
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'orders.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('COUNT(orders.id) as order_count'),
                DB::raw('SUM(orders.total_amount) as sales_amount'),
            ])
            ->groupBy('orders.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderBy('partner_tenants.name');

        $ticketRows = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->select([
                'tickets.tenant_id',
                DB::raw('COUNT(tickets.id) as ticket_count'),
            ])
            ->groupBy('tickets.tenant_id');
        $this->applyPaidOrderFilter($ticketRows);
        $this->applyCentralTenantFilter($ticketRows, $tenantId, 'tickets.tenant_id');
        $this->applyCentralGameFilter($ticketRows, $gameId, 'tickets.game_id');
        $this->applyCentralDateRange($ticketRows, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');

        $ticketCounts = $ticketRows->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->tenant_id => (int) $row->ticket_count])
            ->all();

        return $salesRows->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'ticket_count' => (int) ($ticketCounts[(string) $row->tenant_id] ?? 0),
            'order_count' => (int) $row->order_count,
            'sales_amount' => $this->money((int) $row->sales_amount),
        ])
            ->sortByDesc('ticket_count')
            ->take($limit)
            ->values()
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDailyTopNumberRows(?string $tenantId, array $dateRange, ?string $gameId, string $segment): array
    {
        $expression = $this->dailyNumberExpression($segment);
        $total = max(1, $this->centralPaidTicketsCount($tenantId, $dateRange, $gameId));
        $rows = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->select([
                DB::raw($expression.' as number'),
                DB::raw('COUNT(tickets.id) as ticket_count'),
            ])
            ->groupBy('number')
            ->orderByDesc('ticket_count')
            ->orderBy('number')
            ->limit(10);
        $this->applyPaidOrderFilter($rows);
        $this->applyCentralTenantFilter($rows, $tenantId, 'tickets.tenant_id');
        $this->applyCentralGameFilter($rows, $gameId, 'tickets.game_id');
        $this->applyCentralDateRange($rows, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');

        return $rows->get()->values()->map(fn (object $row, int $index): array => [
            'rank' => $index + 1,
            'number' => (string) $row->number,
            'ticket_count' => (int) $row->ticket_count,
            'percent' => round(((int) $row->ticket_count / $total) * 100, 2),
        ])->all();
    }

    private function dailyNumberExpression(string $segment): string
    {
        return match ($segment) {
            'front3' => 'SUBSTR(tickets.full_number, 1, 3)',
            'back3' => match (DB::connection()->getDriverName()) {
                'sqlite' => 'SUBSTR(tickets.full_number, -3)',
                default => 'RIGHT(tickets.full_number, 3)',
            },
            default => match (DB::connection()->getDriverName()) {
                'sqlite' => 'SUBSTR(tickets.full_number, -2)',
                default => 'RIGHT(tickets.full_number, 2)',
            },
        };
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralDailySetDistributionRows(?string $tenantId, array $dateRange, ?string $gameId): array
    {
        $offeredRows = $this->centralDailyOfferedSetCounts($tenantId, $gameId);
        $soldCounts = $this->centralDailySoldSetCounts($tenantId, $dateRange, $gameId);
        $offeredTotal = max(1, array_sum(array_map(fn (array $row): int => (int) $row['offered_set_count'], $offeredRows)));
        $setSizes = array_unique([
            ...array_keys($offeredRows),
            ...array_keys($soldCounts),
        ]);
        sort($setSizes, SORT_NUMERIC);

        return array_map(function (int|string $setSize) use ($offeredRows, $soldCounts, $offeredTotal): array {
            $setSize = max(1, (int) $setSize);
            $offeredSetCount = (int) ($offeredRows[$setSize]['offered_set_count'] ?? 0);
            $soldSetCount = (int) ($soldCounts[$setSize]['sold_set_count'] ?? 0);

            return [
                'set_size' => $setSize,
                'label' => 'ชุด '.$setSize.' ใบ',
                'offered_set_count' => $offeredSetCount,
                'offered_percent' => round(($offeredSetCount / $offeredTotal) * 100, 2),
                'sold_set_count' => $soldSetCount,
                'sold_percent' => $offeredSetCount > 0 ? round(($soldSetCount / $offeredSetCount) * 100, 2) : 0.0,
            ];
        }, $setSizes);
    }

    /**
     * @return array<int, array{offered_set_count: int}>
     */
    private function centralDailyOfferedSetCounts(?string $tenantId, ?string $gameId): array
    {
        $numberCounts = DB::table('stock_items')
            ->select(['full_number', DB::raw('COUNT(stock_items.id) as set_size')])
            ->groupBy('full_number');
        $this->applyCentralTenantFilter($numberCounts, $tenantId, 'stock_items.tenant_id');
        $this->applyCentralGameFilter($numberCounts, $gameId, 'stock_items.game_id');

        return DB::query()
            ->fromSub($numberCounts, 'number_sets')
            ->select([
                'number_sets.set_size',
                DB::raw('COUNT(*) as offered_set_count'),
            ])
            ->groupBy('number_sets.set_size')
            ->orderBy('number_sets.set_size')
            ->get()
            ->mapWithKeys(fn (object $row): array => [
                max(1, (int) $row->set_size) => ['offered_set_count' => (int) $row->offered_set_count],
            ])
            ->all();
    }

    /**
     * @return array<int, array{sold_set_count: int, sold_ticket_count: int}>
     */
    private function centralDailySoldSetCounts(?string $tenantId, array $dateRange, ?string $gameId): array
    {
        if (! Schema::hasColumn('order_items', 'sale_price_rule_snapshot_json')) {
            return [];
        }

        $setSizeExpression = $this->orderItemSetSizeExpression();
        $query = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId)
            ->join('order_items', 'order_items.order_id', '=', 'orders.id')
            ->selectRaw($setSizeExpression.' as set_size')
            ->selectRaw('COUNT(order_items.id) as ticket_count')
            ->groupByRaw($setSizeExpression);

        $counts = [];
        foreach ($query->get() as $row) {
            $setSize = max(1, (int) $row->set_size);
            $ticketCount = max(0, (int) $row->ticket_count);
            $counts[$setSize] = [
                'sold_set_count' => $ticketCount === 0 ? 0 : max(1, (int) floor($ticketCount / $setSize)),
                'sold_ticket_count' => $ticketCount,
            ];
        }

        return $counts;
    }

    private function orderItemSetSizeExpression(): string
    {
        return match (DB::connection()->getDriverName()) {
            'pgsql' => "CASE WHEN order_items.sale_price_rule_snapshot_json->>'set_size' ~ '^[0-9]+$' THEN GREATEST((order_items.sale_price_rule_snapshot_json->>'set_size')::int, 1) ELSE 1 END",
            'mysql', 'mariadb' => "CASE WHEN JSON_UNQUOTE(JSON_EXTRACT(order_items.sale_price_rule_snapshot_json, '$.set_size')) REGEXP '^[0-9]+$' THEN GREATEST(CAST(JSON_UNQUOTE(JSON_EXTRACT(order_items.sale_price_rule_snapshot_json, '$.set_size')) AS UNSIGNED), 1) ELSE 1 END",
            'sqlite' => "CASE WHEN json_extract(order_items.sale_price_rule_snapshot_json, '$.set_size') IS NULL THEN 1 ELSE MAX(CAST(json_extract(order_items.sale_price_rule_snapshot_json, '$.set_size') AS INTEGER), 1) END",
            default => '1',
        };
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralSalesOrderRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId)
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->leftJoin('games', 'games.id', '=', 'orders.game_id')
            ->leftJoin('customers', 'customers.id', '=', 'orders.customer_id')
            ->leftJoin('order_items', 'order_items.order_id', '=', 'orders.id')
            ->select([
                'orders.id',
                'orders.reference',
                'orders.payment_method',
                'orders.total_amount',
                'orders.currency',
                'orders.paid_at',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                'games.name as game_name',
                'customers.name as customer_name',
                DB::raw('COUNT(order_items.id) as ticket_count'),
            ])
            ->groupBy('orders.id', 'orders.reference', 'orders.payment_method', 'orders.total_amount', 'orders.currency', 'orders.paid_at', 'partner_tenants.name', 'partners.name', 'games.name', 'customers.name')
            ->orderByRaw('COALESCE(orders.paid_at, orders.created_at) DESC')
            ->limit($limit);

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'paid_at' => $this->iso($row->paid_at),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'game_name' => (string) ($row->game_name ?? '-'),
            'reference' => (string) ($row->reference ?? $row->id),
            'customer_name' => (string) ($row->customer_name ?? '-'),
            'ticket_count' => (int) $row->ticket_count,
            'total_amount' => $this->money((int) $row->total_amount, (string) ($row->currency ?? 'THB')),
            'payment_method' => (string) $row->payment_method,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralOrderRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = $this->centralOrdersQuery($tenantId, $dateRange, $gameId)
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'orders.customer_id')
            ->select(['orders.*', 'partner_tenants.name as tenant_name', 'customers.name as customer_name'])
            ->orderByDesc('orders.created_at')
            ->limit($limit);

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'created_at' => $this->iso($row->created_at),
            'paid_at' => $this->iso($row->paid_at),
            'reference' => (string) ($row->reference ?? $row->id),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'customer_name' => (string) ($row->customer_name ?? $row->customer_id),
            'status' => (string) $row->status,
            'payment_status' => (string) $row->payment_status,
            'total_amount' => $this->money((int) $row->total_amount, (string) ($row->currency ?? 'THB')),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralCustomerRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('customers')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'customers.tenant_id')
            ->select(['customers.*', 'partner_tenants.name as tenant_name'])
            ->orderByDesc('customers.created_at')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'customers.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'customers.created_at');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'created_at' => $this->iso($row->created_at),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'name' => (string) ($row->name ?? trim((string) (($row->first_name ?? '').' '.($row->last_name ?? ''))) ?: $row->id),
            'phone' => (string) ($row->phone ?? '-'),
            'status' => (string) $row->status,
            'pin_set' => $row->pin_set_at !== null,
            'auto_reward' => (bool) ($row->auto_reward_claim_enabled ?? false),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralStockRows(?string $tenantId, int $limit, ?string $gameId): array
    {
        $query = DB::table('stock_items')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'stock_items.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'stock_items.partner_id')
            ->leftJoin('games', 'games.id', '=', 'stock_items.game_id')
            ->select(['stock_items.*', 'partner_tenants.name as tenant_name', 'partners.name as partner_name', 'games.name as game_name', 'games.draw_at'])
            ->orderByDesc('stock_items.updated_at')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'stock_items.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'stock_items.game_id');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'draw_at' => $this->iso($row->draw_at),
            'full_number' => (string) $row->full_number,
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'status' => (string) $row->status,
            'updated_at' => $this->iso($row->updated_at),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralWalletRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = DB::table('wallet_ledger')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'wallet_ledger.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'wallet_ledger.customer_id')
            ->select(['wallet_ledger.*', 'partner_tenants.name as tenant_name', 'customers.name as customer_name'])
            ->orderByRaw('COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at) DESC')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'wallet_ledger.tenant_id');
        $this->applyCentralWalletGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'posted_at' => $this->iso($row->posted_at ?? $row->created_at),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'customer_name' => (string) ($row->customer_name ?? $row->customer_id),
            'entry_type' => (string) $row->entry_type,
            'status' => (string) $row->status,
            'amount' => $this->money((int) $row->amount, (string) ($row->currency ?? 'THB')),
            'balance_after' => $this->money((int) $row->balance_after, (string) ($row->currency ?? 'THB')),
            'reference_type' => (string) ($row->reference_type ?? '-'),
        ])->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function topupChannelSummaryRows(?string $tenantId, array $dateRange, int $limit, bool $includeTenantDetail): array
    {
        if (! Schema::hasTable('topup_requests')) {
            return [];
        }

        $dateExpression = $this->topupReportDateExpression();
        $query = DB::table('topup_requests')
            ->select([
                DB::raw("COALESCE(NULLIF(topup_requests.channel, ''), 'unknown') as channel"),
                DB::raw("COALESCE(NULLIF(topup_requests.status, ''), 'unknown') as status"),
                DB::raw("COALESCE(NULLIF(topup_requests.currency, ''), 'THB') as currency"),
                DB::raw('COUNT(*) as row_count'),
                DB::raw('COALESCE(SUM(topup_requests.amount), 0) as amount'),
            ])
            ->groupBy('channel', 'status', 'currency')
            ->orderBy('channel')
            ->orderBy('status')
            ->limit($limit);

        $this->applyCentralTenantFilter($query, $tenantId, 'topup_requests.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, $dateExpression);

        return $query->get()->map(function (object $row) use ($tenantId, $dateRange, $includeTenantDetail): array {
            $channel = (string) $row->channel;
            $status = (string) $row->status;
            $currency = (string) $row->currency;

            return [
                'id' => implode(':', [$channel, $status, $currency]),
                'channel' => $this->topupChannelReportLabel($channel),
                'status' => $this->topupStatusReportLabel($status),
                'row_count' => (int) $row->row_count,
                'amount' => $this->money((int) $row->amount, $currency),
                'details' => (int) $row->row_count,
                'detail_title' => 'Topup channel details',
                'detail_columns' => $this->topupChannelDetailColumns($includeTenantDetail),
                'detail_rows' => $this->topupChannelDetailRows($tenantId, $dateRange, $channel, $status, $currency, 100, $includeTenantDetail),
            ];
        })->all();
    }

    /**
     * @param array{from: Carbon|null, to: Carbon|null} $dateRange
     * @return array<int, array<string, mixed>>
     */
    private function topupChannelDetailRows(?string $tenantId, array $dateRange, string $channel, string $status, string $currency, int $limit, bool $includeTenantDetail): array
    {
        $dateExpression = $this->topupReportDateExpression();
        $query = DB::table('topup_requests')
            ->leftJoin('customers', 'customers.id', '=', 'topup_requests.customer_id')
            ->leftJoin('payments', 'payments.id', '=', 'topup_requests.payment_id')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'topup_requests.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'topup_requests.id',
                'topup_requests.reference',
                'topup_requests.amount',
                'topup_requests.currency',
                'topup_requests.transfer_at',
                'topup_requests.reviewed_at',
                'topup_requests.created_at',
                'customers.customer_no',
                'customers.name as customer_name',
                'payments.id as payment_id',
                'payments.reference as payment_reference',
                'payments.provider_reference',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
            ])
            ->whereRaw("COALESCE(NULLIF(topup_requests.channel, ''), 'unknown') = ?", [$channel])
            ->whereRaw("COALESCE(NULLIF(topup_requests.status, ''), 'unknown') = ?", [$status])
            ->whereRaw("COALESCE(NULLIF(topup_requests.currency, ''), 'THB') = ?", [$currency])
            ->orderByRaw($dateExpression.' DESC')
            ->orderByDesc('topup_requests.id')
            ->limit($limit);

        $this->applyCentralTenantFilter($query, $tenantId, 'topup_requests.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, $dateExpression);

        return $query->get()->map(function (object $row) use ($includeTenantDetail): array {
            $base = [
                'ref' => (string) ($row->reference ?? $row->id),
                'customer_no' => (string) ($row->customer_no ?? $row->customer_name ?? $row->id),
                'order_number' => (string) ($row->provider_reference ?? $row->payment_reference ?? $row->payment_id ?? $row->id),
                'amount' => $this->money((int) $row->amount, (string) ($row->currency ?? 'THB')),
                'transacted_at' => $this->iso($row->transfer_at ?? $row->reviewed_at ?? $row->created_at),
            ];

            if (! $includeTenantDetail) {
                return $base;
            }

            return [
                'tenant_name' => (string) ($row->tenant_name ?? '-'),
                'partner_name' => (string) ($row->partner_name ?? '-'),
            ] + $base;
        })->all();
    }

    /**
     * @return array<int, array<string, string>>
     */
    private function topupChannelDetailColumns(bool $includeTenantDetail): array
    {
        $columns = [
            ['key' => 'ref', 'label' => 'Ref.'],
            ['key' => 'customer_no', 'label' => 'Customer code'],
            ['key' => 'order_number', 'label' => 'Order number'],
            ['key' => 'amount', 'label' => 'Amount', 'type' => 'money'],
            ['key' => 'transacted_at', 'label' => 'Transacted at', 'type' => 'datetime'],
        ];

        if (! $includeTenantDetail) {
            return $columns;
        }

        return [
            ['key' => 'tenant_name', 'label' => 'Store'],
            ['key' => 'partner_name', 'label' => 'Partner'],
            ...$columns,
        ];
    }

    private function topupReportDateExpression(): string
    {
        return 'COALESCE(topup_requests.transfer_at, topup_requests.reviewed_at, topup_requests.created_at)';
    }

    private function topupChannelReportLabel(string $channel): string
    {
        return match ($channel) {
            'qr', 'qr_payment', 'scan', 'scan_payment' => 'scan_payment',
            'credit', 'card', 'credit_card' => 'credit_card',
            'bank', 'bank_transfer' => 'bank_transfer',
            default => $channel,
        };
    }

    private function topupStatusReportLabel(string $status): string
    {
        return match ($status) {
            'succeeded', 'success' => 'succeeded',
            'cancelled', 'canceled' => 'cancelled',
            default => $status,
        };
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralCommissionRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = DB::table('commission_transactions')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'commission_transactions.tenant_id')
            ->leftJoin('affiliate_accounts', 'affiliate_accounts.id', '=', 'commission_transactions.affiliate_account_id')
            ->select(['commission_transactions.*', 'partner_tenants.name as tenant_name', 'affiliate_accounts.name as affiliate_name'])
            ->orderByRaw('COALESCE(commission_transactions.approved_at, commission_transactions.calculated_at, commission_transactions.created_at) DESC')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'commission_transactions.tenant_id');
        $this->applyCentralCommissionGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(commission_transactions.approved_at, commission_transactions.calculated_at, commission_transactions.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'created_at' => $this->iso($row->created_at),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'affiliate_name' => (string) ($row->affiliate_name ?? $row->affiliate_account_id),
            'transaction_type' => (string) $row->transaction_type,
            'status' => (string) $row->status,
            'amount' => $this->money((int) $row->amount, (string) ($row->currency ?? 'THB')),
            'approved_at' => $this->iso($row->approved_at),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralRewardRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId): array
    {
        $query = DB::table('reward_claims')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'reward_claims.tenant_id')
            ->leftJoin('customers', 'customers.id', '=', 'reward_claims.customer_id')
            ->leftJoin('games', 'games.id', '=', 'reward_claims.game_id')
            ->select(['reward_claims.*', 'partner_tenants.name as tenant_name', 'customers.name as customer_name', 'games.name as game_name'])
            ->orderByRaw('COALESCE(reward_claims.submitted_at, reward_claims.created_at) DESC')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'reward_claims.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'reward_claims.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(reward_claims.submitted_at, reward_claims.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'submitted_at' => $this->iso($row->submitted_at ?? $row->created_at),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'customer_name' => (string) ($row->customer_name ?? $row->customer_id),
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'reference' => (string) ($row->reference ?? $row->id),
            'status' => (string) $row->status,
            'payout_method' => (string) $row->payout_method,
            'base_prize_amount' => $this->money((int) ($row->base_prize_amount ?? $row->prize_amount), (string) ($row->currency ?? 'THB')),
            'adjustment_amount' => $this->money((int) ($row->adjustment_amount ?? 0), (string) ($row->currency ?? 'THB')),
            'prize_amount' => $this->money((int) $row->prize_amount, (string) ($row->currency ?? 'THB')),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralSettlementRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('partner_settlements')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'partner_settlements.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_settlements.partner_id')
            ->select(['partner_settlements.*', 'partner_tenants.name as tenant_name', 'partners.name as partner_name'])
            ->orderByDesc('partner_settlements.created_at')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'partner_settlements.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'partner_settlements.created_at');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'created_at' => $this->iso($row->created_at),
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'partner_name' => (string) ($row->partner_name ?? $row->partner_id),
            'period' => trim((string) ($row->period_from ?? '-').' - '.(string) ($row->period_to ?? '-')),
            'status' => (string) $row->status,
            'sales_amount' => $this->money((int) $row->sales_amount, (string) ($row->currency ?? 'THB')),
            'commission_amount' => $this->money((int) $row->commission_amount, (string) ($row->currency ?? 'THB')),
            'payout_amount' => $this->money((int) $row->payout_amount, (string) ($row->currency ?? 'THB')),
            'net_amount' => $this->money((int) $row->net_amount, (string) ($row->currency ?? 'THB')),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralUsageRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('partner_daily_usage_summaries')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'partner_daily_usage_summaries.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_daily_usage_summaries.partner_id')
            ->select(['partner_daily_usage_summaries.*', 'partner_tenants.name as tenant_name', 'partners.name as partner_name'])
            ->orderByDesc('partner_daily_usage_summaries.usage_date')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'partner_daily_usage_summaries.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'partner_daily_usage_summaries.usage_date');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'usage_date' => (string) $row->usage_date,
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'partner_name' => (string) ($row->partner_name ?? $row->partner_id),
            'api_request_count' => (int) $row->api_request_count,
            'booking_request_count' => (int) $row->booking_request_count,
            'checkout_request_count' => (int) $row->checkout_request_count,
            'order_count' => (int) $row->order_count,
            'sold_ticket_count' => (int) $row->sold_ticket_count,
            'error_count' => (int) $row->error_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralPartnerRows(?string $tenantId, int $limit): array
    {
        $query = DB::table('partner_tenants')
            ->join('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'partner_tenants.id',
                'partner_tenants.code as tenant_code',
                'partner_tenants.name as tenant_name',
                'partner_tenants.status as tenant_status',
                'partner_tenants.created_at',
                'partners.code as partner_code',
                'partners.name as partner_name',
                'partners.status as partner_status',
            ])
            ->orderByDesc('partner_tenants.created_at')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'partner_tenants.id');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'created_at' => $this->iso($row->created_at),
            'partner_name' => (string) $row->partner_name,
            'partner_code' => (string) $row->partner_code,
            'tenant_name' => (string) $row->tenant_name,
            'tenant_code' => (string) $row->tenant_code,
            'partner_status' => (string) $row->partner_status,
            'tenant_status' => (string) $row->tenant_status,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralAuditRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('audit_logs')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'audit_logs.tenant_id')
            ->select(['audit_logs.*', 'partner_tenants.name as tenant_name'])
            ->orderByDesc('audit_logs.created_at')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'audit_logs.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'audit_logs.created_at');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) $row->id,
            'created_at' => $this->iso($row->created_at),
            'scope_type' => (string) $row->scope_type,
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'actor_type' => (string) $row->actor_type,
            'actor_id' => (string) $row->actor_id,
            'action' => (string) $row->action,
            'target_type' => (string) ($row->target_type ?? '-'),
            'ip_address' => (string) ($row->ip_address ?? '-'),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralSalesByTenantRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId = null): array
    {
        $query = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId)
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'orders.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'orders.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('SUM(orders.total_amount) as sales_amount'),
                DB::raw('COUNT(DISTINCT orders.id) as order_count'),
                DB::raw('COUNT(DISTINCT orders.customer_id) as customer_count'),
            ])
            ->groupBy('orders.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('sales_amount')
            ->limit($limit);

        $ticketRows = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->select([
                'tickets.tenant_id',
                DB::raw('COUNT(tickets.id) as ticket_count'),
            ])
            ->groupBy('tickets.tenant_id');
        $this->applyPaidOrderFilter($ticketRows);
        $this->applyCentralTenantFilter($ticketRows, $tenantId, 'tickets.tenant_id');
        $this->applyCentralGameFilter($ticketRows, $gameId, 'tickets.game_id');
        $this->applyCentralDateRange($ticketRows, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');

        $ticketCounts = $ticketRows->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->tenant_id => (int) $row->ticket_count])
            ->all();

        return $query->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'sales_amount' => $this->money((int) $row->sales_amount),
            'order_count' => (int) $row->order_count,
            'ticket_count' => (int) ($ticketCounts[(string) $row->tenant_id] ?? 0),
            'customer_count' => (int) $row->customer_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralSalesByGameRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId = null): array
    {
        $query = $this->centralPaidOrdersQuery($tenantId, $dateRange, $gameId)
            ->leftJoin('games', 'games.id', '=', 'orders.game_id')
            ->select([
                'orders.game_id',
                'games.name as game_name',
                'games.draw_at',
                DB::raw('SUM(orders.total_amount) as sales_amount'),
                DB::raw('COUNT(DISTINCT orders.id) as order_count'),
            ])
            ->groupBy('orders.game_id', 'games.name', 'games.draw_at')
            ->orderByDesc('sales_amount')
            ->limit($limit);

        $ticketRows = DB::table('tickets')
            ->join('orders', 'orders.id', '=', 'tickets.order_id')
            ->select([
                'tickets.game_id',
                DB::raw('COUNT(tickets.id) as ticket_count'),
            ])
            ->groupBy('tickets.game_id');
        $this->applyPaidOrderFilter($ticketRows);
        $this->applyCentralTenantFilter($ticketRows, $tenantId, 'tickets.tenant_id');
        $this->applyCentralGameFilter($ticketRows, $gameId, 'tickets.game_id');
        $this->applyCentralDateRange($ticketRows, $dateRange, 'COALESCE(orders.paid_at, orders.created_at)');

        $ticketCounts = $ticketRows->get()
            ->mapWithKeys(fn (object $row): array => [(string) $row->game_id => (int) $row->ticket_count])
            ->all();

        return $query->get()->map(fn (object $row): array => [
            'game_id' => (string) $row->game_id,
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'draw_at' => $this->iso($row->draw_at),
            'sales_amount' => $this->money((int) $row->sales_amount),
            'order_count' => (int) $row->order_count,
            'ticket_count' => (int) ($ticketCounts[(string) $row->game_id] ?? 0),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralOrderBreakdownRows(?string $tenantId, array $dateRange, string $column, ?string $gameId = null): array
    {
        $query = $this->centralOrdersQuery($tenantId, $dateRange, $gameId)
            ->select([
                DB::raw('COALESCE('.$column.", 'unknown') as label"),
                DB::raw('SUM(total_amount) as sales_amount'),
                DB::raw('COUNT(*) as order_count'),
            ])
            ->groupBy('label')
            ->orderByDesc('order_count');
        $total = max(1, (int) $this->centralOrdersQuery($tenantId, $dateRange, $gameId)->count());

        return $query->get()->map(fn (object $row): array => [
            'label' => (string) $row->label,
            'sales_amount' => $this->money((int) $row->sales_amount),
            'order_count' => (int) $row->order_count,
            'percent' => round(((int) $row->order_count / $total) * 100, 2),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralCustomersByTenantRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('customers')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'customers.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'customers.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('COUNT(customers.id) as customer_count'),
                DB::raw('SUM(CASE WHEN customers.pin_set_at IS NULL THEN 0 ELSE 1 END) as with_pin_count'),
                DB::raw('SUM(CASE WHEN customers.auto_reward_claim_enabled THEN 1 ELSE 0 END) as auto_reward_count'),
            ])
            ->groupBy('customers.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('customer_count')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'customers.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'customers.created_at');

        return $query->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'customer_count' => (int) $row->customer_count,
            'with_pin_count' => (int) $row->with_pin_count,
            'auto_reward_count' => (int) $row->auto_reward_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralStockByGameRows(?string $tenantId, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('stock_items')
            ->leftJoin('games', 'games.id', '=', 'stock_items.game_id')
            ->select([
                'stock_items.game_id',
                'games.name as game_name',
                'games.draw_at',
                DB::raw('COUNT(stock_items.id) as total_count'),
                DB::raw("SUM(CASE WHEN stock_items.status = 'available' THEN 1 ELSE 0 END) as available_count"),
                DB::raw("SUM(CASE WHEN stock_items.status = 'sold' THEN 1 ELSE 0 END) as sold_count"),
                DB::raw("SUM(CASE WHEN stock_items.status = 'reserved' THEN 1 ELSE 0 END) as reserved_count"),
                DB::raw("SUM(CASE WHEN stock_items.status = 'allocated' THEN 1 ELSE 0 END) as allocated_count"),
            ])
            ->groupBy('stock_items.game_id', 'games.name', 'games.draw_at')
            ->orderByDesc('games.draw_at')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'stock_items.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'stock_items.game_id');

        return $query->get()->map(fn (object $row): array => [
            'game_id' => (string) $row->game_id,
            'game_name' => (string) ($row->game_name ?? $row->game_id),
            'draw_at' => $this->iso($row->draw_at),
            'total_count' => (int) $row->total_count,
            'available_count' => (int) $row->available_count,
            'sold_count' => (int) $row->sold_count,
            'reserved_count' => (int) $row->reserved_count,
            'allocated_count' => (int) $row->allocated_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralStockByTenantRows(?string $tenantId, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('stock_items')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'stock_items.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'stock_items.partner_id')
            ->select([
                'stock_items.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('COUNT(stock_items.id) as total_count'),
                DB::raw("SUM(CASE WHEN stock_items.status = 'available' THEN 1 ELSE 0 END) as available_count"),
                DB::raw("SUM(CASE WHEN stock_items.status = 'sold' THEN 1 ELSE 0 END) as sold_count"),
            ])
            ->whereNotNull('stock_items.tenant_id')
            ->groupBy('stock_items.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('total_count')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'stock_items.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'stock_items.game_id');

        return $query->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'total_count' => (int) $row->total_count,
            'available_count' => (int) $row->available_count,
            'sold_count' => (int) $row->sold_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralWalletReferenceRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('wallet_ledger')
            ->select([
                DB::raw("COALESCE(reference_type, 'manual') as reference_type"),
                DB::raw("SUM(CASE WHEN entry_type IN ('debit', 'hold') THEN 0 ELSE amount END) as inflow_amount"),
                DB::raw("SUM(CASE WHEN entry_type IN ('debit', 'hold') THEN amount ELSE 0 END) as outflow_amount"),
                DB::raw("SUM(CASE WHEN entry_type IN ('debit', 'hold') THEN -amount ELSE amount END) as net_amount"),
                DB::raw('COUNT(*) as ledger_count'),
            ])
            ->groupBy('reference_type')
            ->orderByDesc('ledger_count')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'wallet_ledger.tenant_id');
        $this->applyCentralWalletGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'reference_type' => (string) $row->reference_type,
            'inflow_amount' => $this->money((int) $row->inflow_amount),
            'outflow_amount' => $this->money((int) $row->outflow_amount),
            'net_amount' => $this->money((int) $row->net_amount),
            'ledger_count' => (int) $row->ledger_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralWalletByTenantRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('wallet_ledger')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'wallet_ledger.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'wallet_ledger.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw("SUM(CASE WHEN entry_type IN ('debit', 'hold') THEN 0 ELSE amount END) as inflow_amount"),
                DB::raw("SUM(CASE WHEN entry_type IN ('debit', 'hold') THEN amount ELSE 0 END) as outflow_amount"),
                DB::raw("SUM(CASE WHEN entry_type IN ('debit', 'hold') THEN -amount ELSE amount END) as net_amount"),
            ])
            ->groupBy('wallet_ledger.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('net_amount')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'wallet_ledger.tenant_id');
        $this->applyCentralWalletGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(wallet_ledger.posted_at, wallet_ledger.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'inflow_amount' => $this->money((int) $row->inflow_amount),
            'outflow_amount' => $this->money((int) $row->outflow_amount),
            'net_amount' => $this->money((int) $row->net_amount),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralCommissionByTenantRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('commission_transactions')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'commission_transactions.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'commission_transactions.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('SUM(amount) as commission_amount'),
                DB::raw("SUM(CASE WHEN commission_transactions.status = 'approved' THEN amount ELSE 0 END) as approved_amount"),
                DB::raw("SUM(CASE WHEN commission_transactions.status = 'approved' THEN 0 ELSE amount END) as pending_amount"),
                DB::raw('COUNT(*) as transaction_count'),
            ])
            ->groupBy('commission_transactions.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('commission_amount')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'commission_transactions.tenant_id');
        $this->applyCentralCommissionGameFilter($query, $gameId);
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(commission_transactions.approved_at, commission_transactions.calculated_at, commission_transactions.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'commission_amount' => $this->money((int) $row->commission_amount),
            'approved_amount' => $this->money((int) $row->approved_amount),
            'pending_amount' => $this->money((int) $row->pending_amount),
            'transaction_count' => (int) $row->transaction_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralRewardsByTenantRows(?string $tenantId, array $dateRange, int $limit, ?string $gameId = null): array
    {
        $query = DB::table('reward_claims')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'reward_claims.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_tenants.partner_id')
            ->select([
                'reward_claims.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('SUM(prize_amount) as prize_amount'),
                DB::raw("SUM(CASE WHEN reward_claims.status IN ('approved', 'paid') THEN prize_amount ELSE 0 END) as approved_amount"),
                DB::raw("SUM(CASE WHEN reward_claims.status = 'rejected' THEN 1 ELSE 0 END) as rejected_count"),
                DB::raw('COUNT(*) as claim_count'),
            ])
            ->groupBy('reward_claims.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('prize_amount')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'reward_claims.tenant_id');
        $this->applyCentralGameFilter($query, $gameId, 'reward_claims.game_id');
        $this->applyCentralDateRange($query, $dateRange, 'COALESCE(reward_claims.submitted_at, reward_claims.created_at)');

        return $query->get()->map(fn (object $row): array => [
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant_name ?? $row->tenant_id),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'prize_amount' => $this->money((int) $row->prize_amount),
            'approved_amount' => $this->money((int) $row->approved_amount),
            'rejected_count' => (int) $row->rejected_count,
            'claim_count' => (int) $row->claim_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralMoneyStatusRows(string $table, ?string $tenantId, array $dateRange, string $amountColumn, ?string $gameId = null): array
    {
        $query = DB::table($table)
            ->select(['status', DB::raw('SUM('.$amountColumn.') as amount'), DB::raw('COUNT(*) as row_count')])
            ->groupBy('status')
            ->orderByDesc('amount');
        $this->applyCentralTenantFilter($query, $tenantId, $table.'.tenant_id');
        if ($table === 'reward_claims') {
            $this->applyCentralGameFilter($query, $gameId, 'reward_claims.game_id');
        } elseif ($table === 'commission_transactions') {
            $this->applyCentralCommissionGameFilter($query, $gameId);
        }
        $this->applyCentralDateRange($query, $dateRange, $table.'.created_at');

        return $query->get()->map(fn (object $row): array => [
            'status' => (string) $row->status,
            'amount' => $this->money((int) $row->amount),
            'row_count' => (int) $row->row_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralUsageByTenantRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('partner_daily_usage_summaries')
            ->leftJoin('partner_tenants', 'partner_tenants.id', '=', 'partner_daily_usage_summaries.tenant_id')
            ->leftJoin('partners', 'partners.id', '=', 'partner_daily_usage_summaries.partner_id')
            ->select([
                'partner_daily_usage_summaries.tenant_id',
                'partner_tenants.name as tenant_name',
                'partners.name as partner_name',
                DB::raw('SUM(api_request_count) as api_request_count'),
                DB::raw('SUM(booking_request_count) as booking_request_count'),
                DB::raw('SUM(checkout_request_count) as checkout_request_count'),
                DB::raw('SUM(order_count) as order_count'),
                DB::raw('SUM(sold_ticket_count) as sold_ticket_count'),
                DB::raw('SUM(error_count) as error_count'),
            ])
            ->groupBy('partner_daily_usage_summaries.tenant_id', 'partner_tenants.name', 'partners.name')
            ->orderByDesc('api_request_count')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'partner_daily_usage_summaries.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'partner_daily_usage_summaries.usage_date');

        return $query->get()->map(fn (object $row): array => [
            'id' => (string) ($row->tenant_id ?? 'central'),
            'usage_date' => 'selected range',
            'tenant_name' => (string) ($row->tenant_name ?? '-'),
            'partner_name' => (string) ($row->partner_name ?? '-'),
            'api_request_count' => (int) $row->api_request_count,
            'booking_request_count' => (int) $row->booking_request_count,
            'checkout_request_count' => (int) $row->checkout_request_count,
            'order_count' => (int) $row->order_count,
            'sold_ticket_count' => (int) $row->sold_ticket_count,
            'error_count' => (int) $row->error_count,
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralPartnerStatusRows(): array
    {
        return DB::table('partners')
            ->leftJoin('partner_tenants', 'partner_tenants.partner_id', '=', 'partners.id')
            ->select([
                'partners.status',
                DB::raw('COUNT(DISTINCT partners.id) as partner_count'),
                DB::raw('COUNT(partner_tenants.id) as tenant_count'),
            ])
            ->groupBy('partners.status')
            ->orderByDesc('partner_count')
            ->get()
            ->map(fn (object $row): array => [
                'status' => (string) $row->status,
                'partner_count' => (int) $row->partner_count,
                'tenant_count' => (int) $row->tenant_count,
            ])
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralAuditActionRows(?string $tenantId, array $dateRange, int $limit): array
    {
        $query = DB::table('audit_logs')
            ->select([
                'action',
                DB::raw('COUNT(*) as event_count'),
                DB::raw('COUNT(DISTINCT actor_id) as admin_count'),
                DB::raw('MAX(created_at) as latest_at'),
            ])
            ->groupBy('action')
            ->orderByDesc('event_count')
            ->limit($limit);
        $this->applyCentralTenantFilter($query, $tenantId, 'audit_logs.tenant_id');
        $this->applyCentralDateRange($query, $dateRange, 'audit_logs.created_at');

        return $query->get()->map(fn (object $row): array => [
            'action' => (string) $row->action,
            'event_count' => (int) $row->event_count,
            'admin_count' => (int) $row->admin_count,
            'latest_at' => $this->iso($row->latest_at),
        ])->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function centralOverviewStatusRows(?string $tenantId, ?string $gameId): array
    {
        $rows = [];
        foreach ([
            ['Partners', 'partners', 'status', null],
            ['Partner stores', 'partner_tenants', 'status', $tenantId === null ? null : ['id', $tenantId]],
            ['Games', 'games', 'status', $gameId === null ? null : ['id', $gameId]],
            ['Stock', 'stock_items', 'status', $tenantId === null ? null : ['tenant_id', $tenantId]],
            ['Reward claims', 'reward_claims', 'status', $tenantId === null ? null : ['tenant_id', $tenantId]],
        ] as [$area, $table, $column, $filter]) {
            $query = DB::table($table)
                ->select([$column.' as status', DB::raw('COUNT(*) as row_count')])
                ->groupBy($column)
                ->orderByDesc('row_count');
            if (is_array($filter)) {
                $query->where($filter[0], $filter[1]);
            }
            if ($gameId !== null && in_array($table, ['stock_items', 'reward_claims'], true)) {
                $query->where('game_id', $gameId);
            }
            foreach ($query->get() as $row) {
                $rows[] = [
                    'area' => $area,
                    'status' => (string) $row->status,
                    'row_count' => (int) $row->row_count,
                ];
            }
        }

        return $rows;
    }

    /**
     * @return array<string, mixed>
     */
    private function reportSummary(string $scope, ?string $tenantId, array $dateRange): array
    {
        return [
            'orders_count' => $this->scopedOrders($tenantId, $dateRange)->count(),
            'sales_total' => $this->money((int) $this->scopedOrders($tenantId, $dateRange)->where('payment_status', 'paid')->sum('total_amount')),
            'stock_count' => $scope === 'central'
                ? StockItem::query()->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))->count()
                : LocalStockItem::where('tenant_id', $tenantId)->count(),
            'wallet_ledger_total' => $this->money((int) $this->scopedTable('wallet_ledger', $tenantId, $dateRange)->sum('amount')),
            'commission_total' => $this->money((int) $this->scopedTable('commission_transactions', $tenantId, $dateRange)->sum('amount')),
            'payout_total' => $this->money((int) $this->scopedPaidAffiliatePayouts($tenantId, $dateRange)->sum('amount')),
            'reward_claims_count' => $this->scopedTable('reward_claims', $tenantId, $dateRange)->count(),
            'reward_base_total' => $this->money($this->rewardClaimSum($tenantId, $dateRange, 'COALESCE(base_prize_amount, prize_amount)')),
            'reward_adjustment_total' => $this->money($this->rewardClaimSum($tenantId, $dateRange, 'COALESCE(adjustment_amount, 0)')),
            'reward_payout_total' => $this->money((int) $this->scopedTable('reward_claims', $tenantId, $dateRange)->sum('prize_amount')),
            'customers_count' => Customer::query()->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))->count(),
            'settlements_count' => PartnerSettlement::query()->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))->count(),
        ];
    }

    private function rewardClaimSum(?string $tenantId, array $dateRange, string $expression): int
    {
        return (int) $this->scopedTable('reward_claims', $tenantId, $dateRange)
            ->selectRaw('COALESCE(SUM('.$expression.'), 0) as aggregate')
            ->value('aggregate');
    }

    /**
     * @param array<string, mixed> $queryParams
     * @return array{rows: array<int, array<string, mixed>>, next_cursor: string|null, has_more: bool}
     */
    private function reportRows(string $scope, ?string $tenantId, string $reportKey, array $queryParams, array $dateRange, int $limit): array
    {
        $cursor = $this->nullableString($queryParams['cursor'] ?? null);
        $query = match ($reportKey) {
            'stock' => $scope === 'central'
                ? StockItem::query()->when($tenantId !== null, fn ($builder) => $builder->where('tenant_id', $tenantId))
                : LocalStockItem::query()->where('tenant_id', $tenantId),
            'wallet' => $this->scopedTable('wallet_ledger', $tenantId, $dateRange),
            'commission' => $this->scopedTable('commission_transactions', $tenantId, $dateRange),
            'rewards' => $this->scopedTable('reward_claims', $tenantId, $dateRange)
                ->select([
                    'id',
                    'tenant_id',
                    'game_id',
                    'status',
                    'base_prize_amount',
                    'adjustment_amount',
                    'prize_amount',
                    'currency',
                    'tenant_price_rule_id',
                    'price_rule_snapshot_json',
                    'created_at',
                    'updated_at',
                ]),
            'customers' => Customer::query()->when($tenantId !== null, fn ($builder) => $builder->where('tenant_id', $tenantId)),
            'audit' => AuditLog::query()->when($tenantId !== null, fn ($builder) => $builder->where('tenant_id', $tenantId)),
            'settlement' => PartnerSettlement::query()->when($tenantId !== null, fn ($builder) => $builder->where('tenant_id', $tenantId)),
            'partner_usage' => PartnerTenant::query()->select(['id', 'partner_id', 'code', 'name', 'status', 'created_at', 'updated_at']),
            default => $this->scopedOrders($tenantId, $dateRange),
        };

        if ($cursor !== null) {
            $query->where('id', '>', $cursor);
        }

        $rows = $query->orderBy('id')->limit($limit + 1)->get()->all();
        $hasMore = count($rows) > $limit;
        $rows = array_slice($rows, 0, $limit);

        return [
            'rows' => array_map(fn (object $row): array => $this->genericRowResource($row), $rows),
            'next_cursor' => $hasMore && $rows !== [] ? (string) end($rows)->id : null,
            'has_more' => $hasMore,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function genericRowResource(object $row): array
    {
        $resource = [];
        $attributes = method_exists($row, 'getAttributes') ? $row->getAttributes() : (array) $row;

        foreach ($attributes as $key => $value) {
            if (str_ends_with((string) $key, '_json')) {
                $resource[str_replace('_json', '', (string) $key)] = $this->decodeJson($value);
                continue;
            }

            $resource[(string) $key] = $value;
        }

        return $resource;
    }

    private function agentResource(object $row, bool $includeQuotas = false): array
    {
        $resource = [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'partner_id' => (string) $row->partner_id,
            'code' => (string) $row->code,
            'name' => (string) $row->name,
            'phone' => $row->phone,
            'email' => $row->email,
            'store_id' => $row->store_id,
            'status' => (string) $row->status,
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];

        if ($includeQuotas) {
            $resource['quotas'] = AgentQuota::query()
                ->where('tenant_id', $row->tenant_id)
                ->where('agent_id', $row->id)
                ->orderBy('id')
                ->get()
                ->map(fn (object $quota): array => [
                    'id' => (string) $quota->id,
                    'game_id' => $quota->game_id,
                    'quota_count' => (int) $quota->quota_count,
                    'used_count' => (int) $quota->used_count,
                    'status' => (string) $quota->status,
                    'payload' => $this->decodeJson($quota->payload_json),
                    'updated_at' => $this->iso($quota->updated_at),
                ])
                ->all();
        }

        return $resource;
    }

    private function customerAffiliateAccount(string $tenantId, string $customerId): ?object
    {
        return AffiliateAccount::query()
            ->forTenant($tenantId)
            ->where('customer_id', $customerId)
            ->where('status', '!=', 'archived')
            ->orderBy('created_at')
            ->first();
    }

    /**
     * @return array<string, mixed>
     */
    private function customerAffiliateAccountResource(object $row): array
    {
        return $this->affiliateAccountResource($row, true) + [
            'links' => $this->customerAffiliateLinks((string) $row->tenant_id, (string) $row->id),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function customerAffiliateLinks(string $tenantId, string $affiliateId, int $limit = 5): array
    {
        return $this->activeAffiliateLinksQuery($tenantId, $affiliateId)
            ->limit($limit)
            ->get()
            ->map(fn (object $row): array => $this->affiliateLinkResource($row))
            ->all();
    }

    private function activeAffiliateLinksQuery(string $tenantId, string $affiliateId): mixed
    {
        return AffiliateLink::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->where('status', 'active')
            ->orderByRaw('case when affiliate_program_id is null then 1 else 0 end')
            ->orderBy('id');
    }

    private function primaryAffiliateLink(string $tenantId, string $affiliateId): ?object
    {
        return $this->activeAffiliateLinksQuery($tenantId, $affiliateId)->first();
    }

    private function ensureCustomerAffiliateLink(string $tenantId, object $affiliate): ?array
    {
        $existing = $this->primaryAffiliateLink($tenantId, (string) $affiliate->id);

        if ($existing !== null) {
            $programId = $affiliate->affiliate_program_id ?? $this->defaultActiveAffiliateProgramId($tenantId);
            if ($programId !== null && (string) ($existing->affiliate_program_id ?? '') !== (string) $programId) {
                AffiliateLink::query()->whereKey($existing->id)->update([
                    'affiliate_program_id' => $programId,
                    'updated_at' => now(),
                ]);
                $existing = AffiliateLink::query()->whereKey($existing->id)->first();
            }

            return $this->affiliateLinkResource($existing);
        }

        $code = $this->randomAffiliateCode($tenantId);
        $linkId = 'afl_'.Str::ulid()->toBase32();
        $now = now();

        AffiliateLink::query()->insert([
            'id' => $linkId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate->id,
            'affiliate_program_id' => $affiliate->affiliate_program_id ?? $this->defaultActiveAffiliateProgramId($tenantId),
            'code' => $code,
            'url' => $this->affiliateUrl($tenantId, $code),
            'status' => 'active',
            'metadata_json' => $this->jsonOrNull(['source' => 'customer_self_service']),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $created = AffiliateLink::query()->where('tenant_id', $tenantId)->where('id', $linkId)->first();

        return $created === null ? null : $this->affiliateLinkResource($created);
    }

    private function defaultActiveAffiliateProgramId(string $tenantId): ?string
    {
        $program = $this->defaultActiveAffiliateProgram($tenantId);

        return $program === null ? null : (string) $program->id;
    }

    private function defaultActiveAffiliateProgram(string $tenantId): ?object
    {
        $program = AffiliateProgram::query()
            ->where('tenant_id', $tenantId)
            ->where('code', self::STARTER_AFFILIATE_PROGRAM_CODE)
            ->where('status', 'active')
            ->first();

        if ($program !== null) {
            return $program;
        }

        $program = AffiliateProgram::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->orderBy('id')
            ->first();

        if ($program !== null) {
            return $program;
        }

        return $this->ensureStarterAffiliateDefaults($tenantId);
    }

    private function ensureStarterAffiliateDefaults(string $tenantId): ?object
    {
        if (! PartnerTenant::query()->where('id', $tenantId)->exists()) {
            return null;
        }

        return $this->affiliateTiers->bronzeProgram($tenantId);
    }

    /**
     * @return array<string, mixed>
     */
    private function customerAffiliatePayoutPolicy(string $tenantId, ?object $affiliate): array
    {
        $program = null;

        if ($affiliate !== null) {
            $programId = $affiliate->affiliate_program_id;

            if ($programId === null) {
                $programId = AffiliateLink::query()
                    ->where('tenant_id', $tenantId)
                    ->where('affiliate_account_id', $affiliate->id)
                    ->where('status', 'active')
                    ->whereNotNull('affiliate_program_id')
                    ->orderBy('id')
                    ->value('affiliate_program_id');
            }

            if ($programId !== null) {
                $program = AffiliateProgram::query()
                    ->where('tenant_id', $tenantId)
                    ->where('id', $programId)
                    ->where('status', 'active')
                    ->first();
            }
        }

        $program ??= $this->defaultActiveAffiliateProgram($tenantId);
        $minimum = $program === null
            ? self::DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT
            : (int) ($program->minimum_payout_amount ?? self::DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT);

        return [
            'program_id' => $program === null ? null : (string) $program->id,
            'program_code' => $program === null ? null : (string) $program->code,
            'program_name' => $program === null ? null : (string) $program->name,
            'minimum_payout' => $this->money($minimum),
            'minimum_payout_amount' => $this->money($minimum),
        ];
    }

    private function customerAffiliateMinimumPayoutAmount(string $tenantId, object $affiliate): int
    {
        return (int) $this->customerAffiliatePayoutPolicy($tenantId, $affiliate)['minimum_payout']['amount'];
    }

    /**
     * @return array<string, mixed>
     */
    private function emptyCustomerAffiliateStats(): array
    {
        return [
            'total_commission' => $this->money(0),
            'approved_commission' => $this->money(0),
            'pending_commission' => $this->money(0),
            'requested_payout' => $this->money(0),
            'available_balance' => $this->money(0),
            'converted_count' => 0,
            'visitor_count' => 0,
            'registered_count' => 0,
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function customerAffiliateStats(object $affiliate): array
    {
        $tenantId = (string) $affiliate->tenant_id;
        $affiliateId = (string) $affiliate->id;
        $currency = (string) $affiliate->currency;
        $total = (int) CommissionTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->sum('amount');
        $approved = (int) CommissionTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->where(function ($query): void {
                $query->where('status', 'approved')->orWhere('transaction_type', 'reversal');
            })
            ->sum('amount');
        $pending = (int) CommissionTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->where('status', 'calculated')
            ->sum('amount');
        $requested = (int) AffiliatePayout::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->whereIn('status', ['pending', 'approved', 'paid'])
            ->sum('amount');
        $converted = (int) AffiliateAttribution::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->where('status', 'converted')
            ->count();
        $referralMetrics = $this->affiliateReferralMetricCounts($tenantId, $affiliateId);

        return [
            'total_commission' => $this->money($total, $currency),
            'approved_commission' => $this->money($approved, $currency),
            'pending_commission' => $this->money($pending, $currency),
            'requested_payout' => $this->money($requested, $currency),
            'available_balance' => $this->money(
                $this->affiliateAvailableBalance($tenantId, $affiliateId),
                $currency,
            ),
            'converted_count' => $converted,
            'visitor_count' => $referralMetrics['visitor_count'],
            'registered_count' => $referralMetrics['registered_count'],
        ];
    }

    private function affiliateAvailableBalance(
        string $tenantId,
        string $affiliateId,
        ?string $excludePayoutId = null,
    ): int {
        $approved = (int) CommissionTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->where(function ($query): void {
                $query->where('status', 'approved')->orWhere('transaction_type', 'reversal');
            })
            ->sum('amount');
        $payouts = AffiliatePayout::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->whereIn('status', ['pending', 'approved', 'paid'])
            ->when(
                $excludePayoutId !== null,
                fn ($query) => $query->where('id', '!=', $excludePayoutId),
            )
            ->sum('amount');

        return max(0, $approved - (int) $payouts);
    }

    /**
     * @return array{visitor_count: int, registered_count: int}
     */
    private function affiliateReferralMetricCounts(string $tenantId, string $affiliateId): array
    {
        $row = DB::table('affiliate_referral_visits')
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->selectRaw('COUNT(*) as visitor_count, COUNT(registered_at) as registered_count')
            ->first();

        return [
            'visitor_count' => (int) ($row->visitor_count ?? 0),
            'registered_count' => (int) ($row->registered_count ?? 0),
        ];
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function customerAffiliateCommissionRows(string $tenantId, string $affiliateId, int $limit): array
    {
        return CommissionTransaction::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get()
            ->map(fn (object $row): array => $this->commissionTransactionResource($row))
            ->all();
    }

    /**
     * @return array<int, array<string, mixed>>
     */
    private function customerAffiliatePayoutRows(string $tenantId, string $affiliateId, int $limit): array
    {
        return AffiliatePayout::query()
            ->where('tenant_id', $tenantId)
            ->where('affiliate_account_id', $affiliateId)
            ->orderByDesc('created_at')
            ->orderByDesc('id')
            ->limit($limit)
            ->get()
            ->map(fn (object $row): array => $this->payoutResource($row))
            ->all();
    }

    private function affiliateAccountResource(object $row, bool $includeCounts = false): array
    {
        $primaryLink = $this->primaryAffiliateLink((string) $row->tenant_id, (string) $row->id);
        $primaryLinkResource = $primaryLink === null ? null : $this->affiliateLinkResource($primaryLink);
        $referralUrl = $primaryLinkResource['canonical_url'] ?? $this->affiliateUrl((string) $row->tenant_id, (string) $row->code);
        $referralMetrics = isset($row->visitor_count, $row->registered_count)
            ? ['visitor_count' => (int) $row->visitor_count, 'registered_count' => (int) $row->registered_count]
            : $this->affiliateReferralMetricCounts((string) $row->tenant_id, (string) $row->id);
        $customerName = $row->customer_name ?? null;
        $customerNo = $row->customer_no ?? null;

        if (($customerName === null || $customerName === '' || $customerNo === null || $customerNo === '') && $row->customer_id !== null) {
            $customer = Customer::query()
                ->where('tenant_id', $row->tenant_id)
                ->where('id', $row->customer_id)
                ->first();
            $customerName = $customerName === null || $customerName === '' ? $customer?->name : $customerName;
            $customerNo = $customerNo === null || $customerNo === '' ? $customer?->customer_no : $customerNo;
        }

        $displayCustomerNo = $row->customer_id === null ? null : CustomerNo::display($customerNo, (string) $row->customer_id);
        $resource = [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'customer_id' => $row->customer_id,
            'customer_no' => $displayCustomerNo,
            'member_no' => $displayCustomerNo,
            'customer_name' => $customerName,
            'customer' => $row->customer_id === null ? null : [
                'id' => (string) $row->customer_id,
                'customer_no' => $displayCustomerNo,
                'member_no' => $displayCustomerNo,
                'name' => $customerName,
            ],
            'code' => (string) $row->code,
            'primary_link' => $primaryLinkResource,
            'referral_url' => $referralUrl,
            'canonical_url' => $referralUrl,
            'name' => (string) $row->name,
            'store_name_status' => (string) ($row->store_name_status ?? 'approved'),
            'store_name_approved_at' => $this->iso($row->store_name_approved_at ?? null),
            'store_name_change_available_at' => $this->iso($row->store_name_change_available_at ?? null),
            'affiliate_program_id' => $row->affiliate_program_id ?? null,
            'phone' => $row->phone,
            'email' => $row->email,
            'status' => (string) $row->status,
            'wallet_balance' => $this->money((int) $row->wallet_balance_amount, (string) $row->currency),
            'visitor_count' => $referralMetrics['visitor_count'],
            'registered_count' => $referralMetrics['registered_count'],
            'payout_profile' => $this->affiliatePayoutProfile($row),
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];

        if ($includeCounts) {
            $resource['links_count'] = AffiliateLink::where('tenant_id', $row->tenant_id)->where('affiliate_account_id', $row->id)->count();
            $resource['commission_total'] = $this->money((int) CommissionTransaction::where('tenant_id', $row->tenant_id)->where('affiliate_account_id', $row->id)->sum('amount'), (string) $row->currency);
        }

        return $resource;
    }

    private function affiliateProgramResource(object $row): array
    {
        $minimumPayout = (int) ($row->minimum_payout_amount ?? self::DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT);

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'code' => (string) $row->code,
            'name' => (string) $row->name,
            'status' => (string) $row->status,
            'tier_rank' => $row->tier_rank === null ? null : (int) $row->tier_rank,
            'commission_per_ticket' => $this->money((int) ($row->commission_per_ticket_amount ?? 0)),
            'minimum_payout' => $this->money($minimumPayout),
            'minimum_payout_amount' => $this->money($minimumPayout),
            'starts_at' => $this->iso($row->starts_at),
            'ends_at' => $this->iso($row->ends_at),
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function affiliateLinkResource(object $row): array
    {
        $canonicalUrl = $this->affiliateUrl((string) $row->tenant_id, (string) $row->code);

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'affiliate_program_id' => $row->affiliate_program_id,
            'code' => (string) $row->code,
            'url' => $canonicalUrl,
            'canonical_url' => $canonicalUrl,
            'legacy_url' => $row->url !== null && $row->url !== $canonicalUrl ? $row->url : null,
            'status' => (string) $row->status,
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function affiliateAttributionResource(object $row): array
    {
        $customer = $row->customer_id === null
            ? null
            : Customer::query()->where('tenant_id', $row->tenant_id)->where('id', $row->customer_id)->first();
        $customerNo = $customer === null ? null : CustomerNo::display($customer->customer_no ?? null, (string) $customer->id);

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'affiliate_link_id' => $row->affiliate_link_id,
            'affiliate_program_id' => $row->affiliate_program_id,
            'customer_id' => $row->customer_id,
            'customer_no' => $customerNo,
            'member_no' => $customerNo,
            'order_id' => $row->order_id,
            'status' => (string) $row->status,
            'attributed_at' => $this->iso($row->attributed_at),
            'converted_at' => $this->iso($row->converted_at),
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function commissionRuleResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_program_id' => $row->affiliate_program_id,
            'affiliate_id' => $row->affiliate_account_id,
            'affiliate_account_id' => $row->affiliate_account_id,
            'code' => (string) $row->code,
            'name' => (string) $row->name,
            'rule_type' => (string) $row->rule_type,
            'amount' => $this->money((int) $row->amount, (string) $row->currency),
            'rate_bps' => (int) $row->rate_bps,
            'status' => (string) $row->status,
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function commissionTransactionResource(?object $row): array
    {
        if ($row === null) {
            return [];
        }

        $receiverCustomerId = $row->receiver_customer_id ?? null;
        $buyerCustomerId = $row->buyer_customer_id ?? null;
        $receiverCustomerNo = $receiverCustomerId === null ? null : CustomerNo::display($row->receiver_customer_no ?? null, (string) $receiverCustomerId);
        $buyerCustomerNo = $buyerCustomerId === null ? null : CustomerNo::display($row->buyer_customer_no ?? null, (string) $buyerCustomerId);
        $receiverCustomerName = $row->receiver_customer_name ?? $row->receiver_affiliate_name ?? null;
        $buyerCustomerName = $row->buyer_customer_name ?? null;

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'receiver_user_id' => $receiverCustomerId,
            'buyer_user_id' => $buyerCustomerId,
            'receiver_customer_no' => $receiverCustomerNo,
            'buyer_customer_no' => $buyerCustomerNo,
            'receiver_member_no' => $receiverCustomerNo,
            'buyer_member_no' => $buyerCustomerNo,
            'receiver_customer' => $receiverCustomerId === null ? null : [
                'id' => (string) $receiverCustomerId,
                'customer_no' => $receiverCustomerNo,
                'member_no' => $receiverCustomerNo,
                'name' => $receiverCustomerName,
                'phone' => $row->receiver_customer_phone ?? null,
                'email' => $row->receiver_customer_email ?? null,
            ],
            'buyer_customer' => $buyerCustomerId === null ? null : [
                'id' => (string) $buyerCustomerId,
                'customer_no' => $buyerCustomerNo,
                'member_no' => $buyerCustomerNo,
                'name' => $buyerCustomerName,
                'phone' => $row->buyer_customer_phone ?? null,
                'email' => $row->buyer_customer_email ?? null,
            ],
            'affiliate_attribution_id' => $row->affiliate_attribution_id,
            'order_id' => (string) $row->order_id,
            'commission_rule_id' => (string) $row->commission_rule_id,
            'original_commission_id' => $row->original_commission_id,
            'transaction_type' => (string) $row->transaction_type,
            'status' => (string) $row->status,
            'amount' => $this->money((int) $row->amount, (string) $row->currency),
            'ticket_count' => $row->ticket_count === null ? null : (int) $row->ticket_count,
            'tier_code' => $row->tier_code ?? null,
            'commission_per_ticket' => $row->commission_per_ticket_amount === null
                ? null
                : $this->money((int) $row->commission_per_ticket_amount, (string) $row->currency),
            'calculated_at' => $this->iso($row->calculated_at),
            'approved_by_admin_id' => $row->approved_by_admin_id,
            'approved_at' => $this->iso($row->approved_at),
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function payoutResource(?object $row, bool $revealBankAccount = false): array
    {
        if ($row === null) {
            return [];
        }

        $bankAccount = $this->affiliatePayoutBankAccount($row);
        if (! $revealBankAccount) {
            $bankAccount = EncryptedJsonPayload::maskedBankAccount($bankAccount);
        }

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'status' => (string) $row->status,
            'payout_method' => (string) $row->payout_method,
            'amount' => $this->money((int) $row->amount, (string) $row->currency),
            'bank_account' => $bankAccount,
            'admin_note' => $row->admin_note,
            'requested_by_admin_id' => $row->requested_by_admin_id,
            'approved_by_admin_id' => $row->approved_by_admin_id,
            'approved_at' => $this->iso($row->approved_at),
            'wallet_id' => $row->wallet_id ?? null,
            'payout_ledger_id' => $row->payout_ledger_id ?? null,
            'payment_reference' => $row->payment_reference ?? null,
            'paid_by_admin_id' => $row->paid_by_admin_id ?? null,
            'paid_at' => $this->iso($row->paid_at ?? null),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    /**
     * @return array<string, mixed>
     */
    private function affiliatePayoutBankAccount(object $row): array
    {
        return EncryptedJsonPayload::decrypt(
            $row->bank_account_encrypted ?? null,
            $row->bank_account_json ?? null,
        );
    }

    /**
     * @return array<string, mixed>
     */
    private function affiliatePayoutProfile(object $row): array
    {
        return EncryptedJsonPayload::decrypt(
            $row->payout_profile_encrypted ?? null,
            $row->payout_profile_json ?? null,
        );
    }

    /**
     * @param array<string, mixed> $payout
     * @return array<string, mixed>
     */
    private function telegramPayoutVariables(string $tenantId, array $payout, ?string $statusLabel = null, ?array $adminUser = null): array
    {
        $affiliateId = (string) ($payout['affiliate_account_id'] ?? $payout['affiliate_id'] ?? '');
        $affiliate = $affiliateId === ''
            ? null
            : AffiliateAccount::query()->where('tenant_id', $tenantId)->whereKey($affiliateId)->first();
        $amount = (int) ($payout['amount']['amount'] ?? 0);
        $method = (string) ($payout['payout_method'] ?? '');
        $reason = trim((string) ($payout['admin_note'] ?? ''));
        $isStatusUpdate = $statusLabel !== null && $statusLabel !== '';

        return [
            'event' => [
                'title' => $isStatusUpdate ? 'ตรวจสอบรายการถอนคอมมิชชันแล้ว' : 'มีรายการคอมมิชชันรอตรวจสอบ',
                'occurred_at' => $this->telegramNotifications->occurredAt($isStatusUpdate ? ($payout['approved_at'] ?? $payout['updated_at'] ?? null) : ($payout['created_at'] ?? null)),
            ],
            'tenant' => ['name' => $this->telegramNotifications->tenantName($tenantId)],
            'admin' => $this->telegramNotifications->adminVariables($adminUser),
            'commission' => [
                'customer_name' => (string) ($affiliate?->name ?? $affiliateId),
                'type_label' => match ($method) {
                    'wallet_credit' => 'ฝากคอมเข้ากระเป๋า',
                    'manual_cash' => 'จ่ายคอมเงินสด',
                    default => 'ถอนคอมมิชชัน',
                },
                'reference' => (string) ($payout['id'] ?? ''),
                'amount_baht' => $this->telegramNotifications->baht($amount),
                'status_label' => $statusLabel ?? 'รอตรวจสอบ',
                'reason' => $reason === '' ? '' : 'หมายเหตุ: '.$reason,
            ],
        ];
    }

    private function exportJobResource(?object $row): array
    {
        if ($row === null) {
            return [];
        }

        return [
            'id' => (string) $row->id,
            'source' => (string) $row->source,
            'report_key' => $row->report_key,
            'scope' => (string) $row->scope,
            'tenant_id' => $row->tenant_id,
            'format' => (string) $row->format,
            'status' => (string) $row->status,
            'progress_percent' => (int) $row->progress_percent,
            'download_url' => $row->download_url,
            'error_code' => $row->error_code,
            'expires_at' => $this->iso($row->expires_at),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function settlementResource(?object $row): array
    {
        if ($row === null) {
            return [];
        }

        return [
            'id' => (string) $row->id,
            'partner_id' => (string) $row->partner_id,
            'partner_name' => (string) ($row->partner?->name ?? ''),
            'partner_code' => (string) ($row->partner?->code ?? ''),
            'tenant_id' => (string) $row->tenant_id,
            'tenant_name' => (string) ($row->tenant?->name ?? ''),
            'tenant_code' => (string) ($row->tenant?->code ?? ''),
            'status' => (string) $row->status,
            'sales_amount' => $this->money((int) $row->sales_amount, (string) $row->currency),
            'commission_amount' => $this->money((int) $row->commission_amount, (string) $row->currency),
            'payout_amount' => $this->money((int) $row->payout_amount, (string) $row->currency),
            'net_amount' => $this->money((int) $row->net_amount, (string) $row->currency),
            'period_from' => $row->period_from,
            'period_to' => $row->period_to,
            'approved_by_admin_id' => $row->approved_by_admin_id,
            'approved_by_admin_name' => (string) ($row->approvedByAdmin?->name ?? ''),
            'approved_at' => $this->iso($row->approved_at),
            'summary' => $this->decodeJson($row->summary_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function affiliateUrl(string $tenantId, string $code): string
    {
        return $this->storefrontRootUrl($tenantId).'/?ref='.rawurlencode($code);
    }

    private function storefrontRootUrl(string $tenantId): string
    {
        $host = PartnerTenantDomain::query()
            ->where('tenant_id', $tenantId)
            ->where('status', 'active')
            ->orderByDesc('is_primary')
            ->orderBy('id')
            ->value('host');

        if ($host === null || trim((string) $host) === '') {
            return 'https://newpaotang.local';
        }

        return 'https://'.trim((string) $host, '/');
    }

    private function iso(mixed $value): ?string
    {
        if ($value === null || $value === '') {
            return null;
        }

        try {
            return Carbon::parse((string) $value)->toISOString();
        } catch (\Throwable) {
            return (string) $value;
        }
    }

    private function queueTenantMenuBadgeBroadcast(string $tenantId, string $source): void
    {
        if (DB::transactionLevel() > 0) {
            DB::afterCommit(fn (): mixed => AdminMenuBadgesUpdated::dispatch('tenant', $tenantId, $source));

            return;
        }

        AdminMenuBadgesUpdated::dispatch('tenant', $tenantId, $source);
    }

    /**
     * @param array<string, mixed> $payload
     */
    private function auditAdmin(AdminSessionContext $actor, Request $request, string $action, string $targetType, ?string $targetId, array $payload, ?string $tenantId = null, ?string $partnerId = null): void
    {
        $this->auditLogger->logAdminWrite(
            $actor->adminUser['id'],
            $actor->activeScope(),
            $action,
            $targetType,
            $targetId,
            $payload,
            $tenantId,
            $partnerId,
            $request->header('X-Request-Id'),
            $request->ip(),
            $request->userAgent(),
        );
    }
}
