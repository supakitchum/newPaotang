<?php

namespace App\Modules\Growth\Services;

use App\Models\AffiliateAccount;
use App\Models\AffiliateAttribution;
use App\Models\AffiliateLink;
use App\Models\AffiliatePayout;
use App\Models\AffiliateProgram;
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
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Auth\CustomerSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use App\Support\CustomerNo;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class GrowthService
{
    private const TENANT_REPORT_KEYS = ['overview', 'sales', 'stock', 'wallet', 'commission', 'rewards', 'orders', 'customers', 'audit'];
    private const CENTRAL_REPORT_KEYS = ['overview', 'sales', 'stock', 'wallet', 'commission', 'rewards', 'settlement', 'partner_usage', 'audit'];
    private const EXPORT_FORMATS = ['csv', 'xlsx', 'pdf'];
    private const PAYOUT_METHODS = ['bank_transfer', 'manual_cash', 'wallet_credit'];
    private const RULE_TYPES = ['fixed_per_order', 'percent_sales', 'per_ticket'];
    private const AFFILIATE_CODE_LENGTH = 6;
    private const AFFILIATE_CODE_ALPHABET = 'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789';
    private const AFFILIATE_ATTRIBUTION_TTL_DAYS = 30;
    private const STARTER_AFFILIATE_PROGRAM_CODE = 'basic';
    private const STARTER_AFFILIATE_RULE_CODE = 'basic_com';
    private const DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT = 30000;
    private const DEFAULT_AFFILIATE_RULE_AMOUNT = 1000;

    public function __construct(
        private readonly AuditLogger $auditLogger,
        private readonly IdempotencyService $idempotency,
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
        $errors = $this->basicNameErrors($normalized, 'name');

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
                if ($normalized['customer_id'] !== null && ! Customer::where('tenant_id', $tenantId)->where('id', $normalized['customer_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                if ($normalized['customer_id'] !== null && $this->customerAffiliateAccount($tenantId, $normalized['customer_id']) !== null) {
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
                    'code' => $normalizedForWrite['code'],
                    'name' => $normalized['name'],
                    'phone' => $normalized['phone'],
                    'email' => $normalized['email'],
                    'status' => $normalized['status'],
                    'wallet_balance_amount' => 0,
                    'currency' => $normalized['currency'],
                    'payout_profile_json' => $this->jsonOrNull($normalized['payout_profile']),
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

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

                $updates = $this->onlyPresent($normalized, ['customer_id', 'name', 'phone', 'email', 'status', 'currency']);

                foreach (['payout_profile' => 'payout_profile_json', 'metadata' => 'metadata_json'] as $source => $target) {
                    if (array_key_exists($source, $normalized)) {
                        $updates[$target] = $this->jsonOrNull($normalized[$source]);
                    }
                }

                $updates['updated_at'] = now();
                AffiliateAccount::query()->where('tenant_id', $tenantId)->where('id', $affiliateId)->update($updates);
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
        return $this->archiveTenantRow($tenantId, $actor, $programId, $payload, $request, 'affiliate_programs', 'affiliate_program', 'affiliate_program.manage', 'admin.tenant.affiliate-programs.archive', 'affiliate_program.archived');
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
                $normalizedForWrite = [
                    ...$normalized,
                    'code' => $code,
                    'url' => $this->affiliateUrl($tenantId, $code),
                ];

                AffiliateLink::query()->insert([
                    'id' => $linkId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $normalized['affiliate_account_id'],
                    'affiliate_program_id' => $normalized['affiliate_program_id'],
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

                $updates = $this->onlyPresent($normalized, ['affiliate_account_id', 'affiliate_program_id', 'status']);

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
        ];
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

        if ($existing !== null) {
            $this->ensureCustomerAffiliateLink($tenantId, $existing);

            return ['resource' => $this->customerAffiliateOverview($tenantId, $customer), 'status' => 200];
        }

        $normalized = [
            'customer_id' => $customer->customerId(),
            'name' => trim((string) ($payload['name'] ?? $customerRow->name ?? 'Affiliate')),
            'phone' => $this->nullableString($payload['phone'] ?? $customerRow->phone ?? null),
            'email' => $this->nullableString($payload['email'] ?? $customerRow->email ?? null),
            'status' => 'active',
            'currency' => 'THB',
            'payout_profile' => is_array($payload['payout_profile'] ?? null) ? $payload['payout_profile'] : [],
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ];
        $errors = $this->basicNameErrors($normalized, 'name');

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
                if ($this->customerAffiliateAccount($tenantId, $customer->customerId()) !== null) {
                    return ['resource' => $this->customerAffiliateOverview($tenantId, $customer), 'status' => 200];
                }

                $affiliateId = 'aff_'.Str::ulid()->toBase32();
                $code = $this->randomAffiliateCode($tenantId);
                $now = now();

                AffiliateAccount::query()->insert([
                    'id' => $affiliateId,
                    'tenant_id' => $tenantId,
                    'customer_id' => $normalized['customer_id'],
                    'code' => $code,
                    'name' => $normalized['name'],
                    'phone' => $normalized['phone'],
                    'email' => $normalized['email'],
                    'status' => $normalized['status'],
                    'wallet_balance_amount' => 0,
                    'currency' => $normalized['currency'],
                    'payout_profile_json' => $this->jsonOrNull($normalized['payout_profile']),
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $affiliate = AffiliateAccount::query()->where('tenant_id', $tenantId)->where('id', $affiliateId)->first();

                if ($affiliate !== null) {
                    $this->ensureCustomerAffiliateLink($tenantId, $affiliate);
                }

                return ['resource' => $this->customerAffiliateOverview($tenantId, $customer), 'status' => 201];
            },
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

        return DB::transaction(function () use ($tenantId, $customer, $code, $payload, $request): array {
            if (! Customer::query()->where('tenant_id', $tenantId)->where('id', $customer->customerId())->where('status', 'active')->exists()) {
                return ['error' => 'not_found'];
            }

            $resolved = $this->resolveAffiliateReferralCode($tenantId, $code);

            if ($resolved === null) {
                return ['error' => 'not_found'];
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

            $registeredViaRef = filter_var($payload['registered'] ?? false, FILTER_VALIDATE_BOOLEAN);
            $visitorId = trim((string) ($payload['visitor_id'] ?? ''));

            if ($visitorId !== '' || $registeredViaRef) {
                $this->upsertAffiliateReferralVisit(
                    tenantId: $tenantId,
                    resolved: $resolved,
                    code: $code,
                    visitorKey: $visitorId === '' ? 'customer:'.$customer->customerId() : $this->referralVisitorKey($visitorId, $request),
                    request: $request,
                    landingUrl: $this->nullableString($payload['landing_url'] ?? null),
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
        });
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
            'currency' => $this->moneyCurrency($payload['amount'] ?? null),
            'payout_method' => (string) ($payload['payout_method'] ?? 'bank_transfer'),
            'bank_account' => $this->normalizeBankAccount($payload['bank_account'] ?? null),
            'admin_note' => $this->nullableString($payload['note'] ?? null),
        ];
        $errors = [];

        if ($normalized['amount'] <= 0) {
            $errors['amount'][] = 'The amount field must be greater than zero.';
        }

        if (! in_array($normalized['payout_method'], ['bank_transfer', 'wallet_credit'], true)) {
            $errors['payout_method'][] = 'The payout_method field is invalid.';
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
                    'bank_account_json' => $this->jsonOrNull($normalized['bank_account']),
                    'admin_note' => $normalized['admin_note'],
                    'idempotency_key' => null,
                    'payload_hash' => null,
                    'requested_by_admin_id' => null,
                    'approved_by_admin_id' => null,
                    'approved_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                return ['resource' => $this->payoutResource(AffiliatePayout::query()->where('tenant_id', $tenantId)->where('id', $payoutId)->first()), 'status' => 201];
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
        return $this->archiveTenantRow($tenantId, $actor, $ruleId, $payload, $request, 'commission_rules', 'commission_rule', 'commission_rule.manage', 'admin.tenant.commission-rules.archive', 'commission_rule.archived');
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

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->payoutResource($row));
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
            'bank_account' => is_array($payload['bank_account'] ?? null) ? $payload['bank_account'] : (is_array($payload['bank_account_json'] ?? null) ? $payload['bank_account_json'] : []),
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
                if (! AffiliateAccount::where('tenant_id', $tenantId)->where('id', $normalized['affiliate_account_id'])->where('status', '!=', 'archived')->exists()) {
                    return ['error' => 'not_found'];
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
                    'bank_account_json' => $this->jsonOrNull($normalized['bank_account']),
                    'admin_note' => $normalized['admin_note'],
                    'idempotency_key' => $idempotencyKey,
                    'payload_hash' => $this->idempotency->payloadHash($normalized),
                    'requested_by_admin_id' => $actor->adminUser['id'],
                    'approved_by_admin_id' => null,
                    'approved_at' => null,
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'payout.created', 'affiliate_payout', $payoutId, $normalized, $tenantId);

                return ['resource' => $this->payoutResource(AffiliatePayout::where('id', $payoutId)->first()), 'status' => 201];
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

                if ($row->status === 'approved') {
                    return ['resource' => $this->payoutResource($row), 'status' => 200];
                }

                if ($row->status !== 'pending') {
                    return ['error' => 'resource_conflict'];
                }

                AffiliatePayout::query()->where('tenant_id', $tenantId)->where('id', $payoutId)->update([
                    'status' => 'approved',
                    'approved_by_admin_id' => $actor->adminUser['id'],
                    'approved_at' => now(),
                    'admin_note' => $payload['note'] ?? $payload['reason'] ?? $row->admin_note,
                    'updated_at' => now(),
                ]);

                $resource = $this->payoutResource(AffiliatePayout::where('id', $payoutId)->first());
                $this->auditAdmin($actor, $request, 'payout.approved', 'affiliate_payout', $payoutId, $payload, $tenantId);

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
        $summary = $this->reportSummary($scope, $drilldownTenantId, $dateRange);
        $rows = $this->reportRows($scope, $drilldownTenantId, $reportKey, $queryParams, $dateRange, $limit);

        return [
            'report_key' => $reportKey,
            'scope' => $scope,
            'tenant_id' => $drilldownTenantId,
            'generated_at' => now()->toISOString(),
            'summary' => $summary,
            'rows' => $rows['rows'],
            'meta' => [
                'next_cursor' => $rows['next_cursor'],
                'has_more' => $rows['has_more'],
            ],
        ];
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
        $query = PartnerSettlement::query();

        foreach (['partner_id', 'tenant_id', 'status'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->settlementResource($row));
    }

    public function settlement(string $settlementId): ?array
    {
        $row = PartnerSettlement::find($settlementId);

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

                $resource = $this->settlementResource($row->refresh());
                $this->auditAdmin($actor, $request, 'settlement.approved', 'partner_settlement', $settlementId, $payload, (string) $row->tenant_id, (string) $row->partner_id);

                return ['resource' => $resource, 'status' => 200];
            },
        );
    }

    public function calculateCommissions(?string $orderId = null, ?string $tenantId = null, int $limit = 100): int
    {
        $query = Order::query()
            ->where(function ($builder): void {
                $builder->where('status', 'paid')->orWhere('payment_status', 'paid');
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

        foreach ($orders as $order) {
            $created += $this->calculateCommissionsForOrder($order);
        }

        return $created;
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

            $affiliate = AffiliateAccount::query()
                ->where('tenant_id', $lockedOrder->tenant_id)
                ->where('id', $attribution->affiliate_account_id)
                ->where('status', 'active')
                ->first();

            if ($affiliate === null) {
                return 0;
            }

            $programId = $attribution->affiliate_program_id === null ? null : (string) $attribution->affiliate_program_id;
            $linkId = $attribution->affiliate_link_id === null ? null : (string) $attribution->affiliate_link_id;

            if ($linkId !== null && ! AffiliateLink::where('tenant_id', $lockedOrder->tenant_id)->where('id', $linkId)->where('status', 'active')->exists()) {
                return 0;
            }

            if ($programId !== null && ! AffiliateProgram::where('tenant_id', $lockedOrder->tenant_id)->where('id', $programId)->where('status', 'active')->exists()) {
                return 0;
            }

            $rules = CommissionRule::query()
                ->where('tenant_id', $lockedOrder->tenant_id)
                ->where('status', 'active')
                ->where(function ($query) use ($affiliate): void {
                    $query->whereNull('affiliate_account_id')->orWhere('affiliate_account_id', $affiliate->id);
                })
                ->where(function ($query) use ($programId): void {
                    if ($programId === null) {
                        $query->whereNull('affiliate_program_id');
                    } else {
                        $query->whereNull('affiliate_program_id')->orWhere('affiliate_program_id', $programId);
                    }
                })
                ->orderBy('id')
                ->get()
                ->all();
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

                $amount = $this->commissionAmount($rule, $lockedOrder);

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
                    'currency' => $rule->currency,
                    'idempotency_key' => 'commission:'.$lockedOrder->id.':'.$rule->id.':'.$affiliate->id,
                    'payload_hash' => $this->idempotency->payloadHash($payload),
                    'calculated_at' => $now,
                    'approved_by_admin_id' => null,
                    'approved_at' => $now,
                    'metadata_json' => $this->jsonOrNull(['source' => 'paid_order', 'approval' => 'auto_paid_order']),
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->insertCommissionOutbox($payload, (string) $lockedOrder->tenant_id, (string) $lockedOrder->game_id, $transactionId);
                $created++;
            }

            if ($created > 0) {
                AffiliateAttribution::query()->where('tenant_id', $lockedOrder->tenant_id)->where('id', $attribution->id)->update([
                    'status' => 'converted',
                    'order_id' => $lockedOrder->id,
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

    private function pendingAttributionForPaidOrder(object $order): ?object
    {
        $orderAttributions = AffiliateAttribution::query()
            ->where('tenant_id', $order->tenant_id)
            ->where('order_id', $order->id)
            ->where('status', 'pending')
            ->orderByDesc('attributed_at')
            ->orderByDesc('created_at')
            ->lockForUpdate()
            ->get()
            ->all();
        $attribution = $this->firstUnexpiredAttribution($orderAttributions);

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
            ->orderByDesc('attributed_at')
            ->orderByDesc('created_at')
            ->lockForUpdate()
            ->get()
            ->all();

        return $this->firstUnexpiredAttribution($customerAttributions);
    }

    /**
     * @param array<int, object> $attributions
     */
    private function firstUnexpiredAttribution(array $attributions): ?object
    {
        foreach ($attributions as $attribution) {
            if (! $this->attributionExpired($attribution)) {
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

    private function attributionExpired(object $attribution): bool
    {
        $expiresAt = $this->decodeJson($attribution->metadata_json)['expires_at'] ?? null;

        if ($expiresAt === null || $expiresAt === '') {
            return false;
        }

        try {
            return Carbon::parse((string) $expiresAt)->lte(now());
        } catch (\Throwable) {
            return false;
        }
    }

    private function commissionAmount(object $rule, object $order): int
    {
        return match ((string) $rule->rule_type) {
            'percent_sales' => (int) round(((int) $order->total_amount * (int) $rule->rate_bps) / 10000),
            'per_ticket' => (int) Ticket::where('tenant_id', $order->tenant_id)->where('order_id', $order->id)->count() * (int) $rule->amount,
            default => (int) $rule->amount,
        };
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
            $payout = $this->scopedTable('affiliate_payouts', $tenant->tenant_id, $dateRange)->where('status', 'approved')->sum('amount');
            $summary = [
                'orders_count' => $this->scopedOrders($tenant->tenant_id, $dateRange)->where('payment_status', 'paid')->count(),
                'commission_count' => $this->scopedTable('commission_transactions', $tenant->tenant_id, $dateRange)->count(),
                'payout_count' => $this->scopedTable('affiliate_payouts', $tenant->tenant_id, $dateRange)->where('status', 'approved')->count(),
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

            $programId = $link->affiliate_program_id === null ? null : (string) $link->affiliate_program_id;

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

    /**
     * @return array<string, mixed>
     */
    private function customerRewardPayoutBankAccount(string $tenantId, string $customerId): array
    {
        $json = Customer::query()
            ->where('tenant_id', $tenantId)
            ->where('id', $customerId)
            ->value('reward_payout_bank_account_json');

        return $this->decodeJson($json);
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
                'reward_payout_bank_account_json' => $this->jsonOrNull($bankAccount),
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
            'payout_total' => $this->money((int) $this->scopedTable('affiliate_payouts', $tenantId, $dateRange)->sum('amount')),
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
            return $this->affiliateLinkResource($existing);
        }

        $code = $this->randomAffiliateCode($tenantId);
        $linkId = 'afl_'.Str::ulid()->toBase32();
        $now = now();

        AffiliateLink::query()->insert([
            'id' => $linkId,
            'tenant_id' => $tenantId,
            'affiliate_account_id' => $affiliate->id,
            'affiliate_program_id' => $this->defaultActiveAffiliateProgramId($tenantId),
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

        $now = now();
        $programId = $this->stableAffiliateDefaultId('afp', $tenantId.':'.self::STARTER_AFFILIATE_PROGRAM_CODE);

        DB::table('affiliate_programs')->insertOrIgnore([
            'id' => $programId,
            'tenant_id' => $tenantId,
            'code' => self::STARTER_AFFILIATE_PROGRAM_CODE,
            'name' => 'Basic Affiliate',
            'status' => 'active',
            'minimum_payout_amount' => self::DEFAULT_AFFILIATE_MINIMUM_PAYOUT_AMOUNT,
            'starts_at' => null,
            'ends_at' => null,
            'metadata_json' => $this->jsonOrNull(['source' => 'starter_default']),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $program = AffiliateProgram::query()
            ->where('tenant_id', $tenantId)
            ->where('code', self::STARTER_AFFILIATE_PROGRAM_CODE)
            ->where('status', 'active')
            ->first();

        if ($program === null) {
            return null;
        }

        DB::table('commission_rules')->insertOrIgnore([
            'id' => $this->stableAffiliateDefaultId('cmr', $tenantId.':'.self::STARTER_AFFILIATE_RULE_CODE),
            'tenant_id' => $tenantId,
            'affiliate_program_id' => (string) $program->id,
            'affiliate_account_id' => null,
            'code' => self::STARTER_AFFILIATE_RULE_CODE,
            'name' => 'BasicCom',
            'rule_type' => 'per_ticket',
            'amount' => self::DEFAULT_AFFILIATE_RULE_AMOUNT,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => $this->jsonOrNull(['source' => 'starter_default']),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        return $program;
    }

    private function stableAffiliateDefaultId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }

    /**
     * @return array<string, mixed>
     */
    private function customerAffiliatePayoutPolicy(string $tenantId, ?object $affiliate): array
    {
        $program = null;

        if ($affiliate !== null) {
            $programId = AffiliateLink::query()
                ->where('tenant_id', $tenantId)
                ->where('affiliate_account_id', $affiliate->id)
                ->where('status', 'active')
                ->whereNotNull('affiliate_program_id')
                ->orderByRaw('case when affiliate_program_id is null then 1 else 0 end')
                ->orderBy('id')
                ->value('affiliate_program_id');

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
            'available_balance' => $this->money(max(0, $approved - $requested), $currency),
            'converted_count' => $converted,
            'visitor_count' => $referralMetrics['visitor_count'],
            'registered_count' => $referralMetrics['registered_count'],
        ];
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
            'phone' => $row->phone,
            'email' => $row->email,
            'status' => (string) $row->status,
            'wallet_balance' => $this->money((int) $row->wallet_balance_amount, (string) $row->currency),
            'visitor_count' => $referralMetrics['visitor_count'],
            'registered_count' => $referralMetrics['registered_count'],
            'payout_profile' => $this->decodeJson($row->payout_profile_json),
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
            'calculated_at' => $this->iso($row->calculated_at),
            'approved_by_admin_id' => $row->approved_by_admin_id,
            'approved_at' => $this->iso($row->approved_at),
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function payoutResource(?object $row): array
    {
        if ($row === null) {
            return [];
        }

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'status' => (string) $row->status,
            'payout_method' => (string) $row->payout_method,
            'amount' => $this->money((int) $row->amount, (string) $row->currency),
            'bank_account' => $this->decodeJson($row->bank_account_json),
            'admin_note' => $row->admin_note,
            'requested_by_admin_id' => $row->requested_by_admin_id,
            'approved_by_admin_id' => $row->approved_by_admin_id,
            'approved_at' => $this->iso($row->approved_at),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
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
            'tenant_id' => (string) $row->tenant_id,
            'status' => (string) $row->status,
            'sales_amount' => $this->money((int) $row->sales_amount, (string) $row->currency),
            'commission_amount' => $this->money((int) $row->commission_amount, (string) $row->currency),
            'payout_amount' => $this->money((int) $row->payout_amount, (string) $row->currency),
            'net_amount' => $this->money((int) $row->net_amount, (string) $row->currency),
            'period_from' => $row->period_from,
            'period_to' => $row->period_to,
            'approved_by_admin_id' => $row->approved_by_admin_id,
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
