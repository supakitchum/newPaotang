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
use App\Models\ReportExportJob;
use App\Models\StockItem;
use App\Models\SyncOutbox;
use App\Models\Ticket;
use App\Models\WalletLedger;
use App\Shared\Audit\AuditLogger;
use App\Shared\Auth\AdminSessionContext;
use App\Shared\Idempotency\IdempotencyService;
use Illuminate\Http\Request;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Str;

class GrowthService
{
    private const TENANT_REPORT_KEYS = ['overview', 'sales', 'stock', 'wallet', 'commission', 'orders', 'customers', 'audit'];
    private const CENTRAL_REPORT_KEYS = ['overview', 'sales', 'stock', 'wallet', 'commission', 'settlement', 'partner_usage', 'audit'];
    private const EXPORT_FORMATS = ['csv', 'xlsx', 'pdf'];
    private const PAYOUT_METHODS = ['bank_transfer', 'manual_cash', 'wallet_credit'];
    private const RULE_TYPES = ['fixed_per_order', 'percent_sales', 'per_ticket'];

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
        return $this->listTenantRows($tenantId, 'affiliate_accounts', $queryParams, fn (object $row): array => $this->affiliateAccountResource($row));
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
        $errors = $this->basicNameErrors($normalized, 'name');

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
                if ($this->tenantCodeExists('affiliate_accounts', $tenantId, $normalized['code'])) {
                    return ['error' => 'resource_conflict'];
                }

                if ($normalized['customer_id'] !== null && ! Customer::where('tenant_id', $tenantId)->where('id', $normalized['customer_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                $affiliateId = 'aff_'.Str::ulid()->toBase32();
                $now = now();

                AffiliateAccount::query()->insert([
                    'id' => $affiliateId,
                    'tenant_id' => $tenantId,
                    'customer_id' => $normalized['customer_id'],
                    'code' => $normalized['code'],
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

                $this->auditAdmin($actor, $request, 'affiliate.created', 'affiliate_account', $affiliateId, $normalized, $tenantId);

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

                if (isset($normalized['code']) && $normalized['code'] !== $row->code && $this->tenantCodeExists('affiliate_accounts', $tenantId, $normalized['code'], $affiliateId)) {
                    return ['error' => 'resource_conflict'];
                }

                if (isset($normalized['customer_id']) && $normalized['customer_id'] !== null && ! Customer::where('tenant_id', $tenantId)->where('id', $normalized['customer_id'])->exists()) {
                    return ['error' => 'not_found'];
                }

                $updates = $this->onlyPresent($normalized, ['customer_id', 'code', 'name', 'phone', 'email', 'status', 'currency']);

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

                $updates = $this->onlyPresent($normalized, ['code', 'name', 'status', 'starts_at', 'ends_at']);

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
                if ($this->tenantCodeExists('affiliate_links', $tenantId, $normalized['code'])) {
                    return ['error' => 'resource_conflict'];
                }

                $relations = $this->validAffiliateLinkRelations($tenantId, $normalized);

                if ($relations !== null) {
                    return ['error' => $relations];
                }

                $linkId = 'afl_'.Str::ulid()->toBase32();
                $now = now();

                AffiliateLink::query()->insert([
                    'id' => $linkId,
                    'tenant_id' => $tenantId,
                    'affiliate_account_id' => $normalized['affiliate_account_id'],
                    'affiliate_program_id' => $normalized['affiliate_program_id'],
                    'code' => $normalized['code'],
                    'url' => $normalized['url'] ?? $this->affiliateUrl($normalized['code']),
                    'status' => $normalized['status'],
                    'metadata_json' => $this->jsonOrNull($normalized['metadata']),
                    'created_by_admin_id' => $actor->adminUser['id'],
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);

                $this->auditAdmin($actor, $request, 'affiliate_link.created', 'affiliate_link', $linkId, $normalized, $tenantId);

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

                if (isset($normalized['code']) && $normalized['code'] !== $row->code && $this->tenantCodeExists('affiliate_links', $tenantId, $normalized['code'], $linkId)) {
                    return ['error' => 'resource_conflict'];
                }

                $relations = $this->validAffiliateLinkRelations($tenantId, $merged);

                if ($relations !== null) {
                    return ['error' => $relations];
                }

                $updates = $this->onlyPresent($normalized, ['affiliate_account_id', 'affiliate_program_id', 'code', 'url', 'status']);

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

        return $this->listTenantRows($tenantId, 'affiliate_attributions', $mapped, fn (object $row): array => $this->affiliateAttributionResource($row));
    }

    public function affiliateAttribution(string $tenantId, string $attributionId): ?array
    {
        $row = AffiliateAttribution::where('tenant_id', $tenantId)->where('id', $attributionId)->first();

        return $row === null ? null : $this->affiliateAttributionResource($row);
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
        $query = CommissionTransaction::query()->where('tenant_id', $tenantId);

        foreach (['status', 'affiliate_account_id', 'order_id', 'commission_rule_id', 'transaction_type'] as $field) {
            if (($queryParams[$field] ?? null) !== null && trim((string) $queryParams[$field]) !== '') {
                $query->where($field, trim((string) $queryParams[$field]));
            }
        }

        return $this->paginated($query, $queryParams, fn (object $row): array => $this->commissionTransactionResource($row));
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
                    return ['resource' => $this->commissionTransactionResource($row), 'status' => 200];
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

                $resource = $this->commissionTransactionResource(CommissionTransaction::where('id', $commissionId)->first());
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

            $attribution = AffiliateAttribution::query()
                ->where('tenant_id', $lockedOrder->tenant_id)
                ->where('order_id', $lockedOrder->id)
                ->where('status', 'pending')
                ->lockForUpdate()
                ->first();

            if ($attribution === null) {
                $attribution = AffiliateAttribution::query()
                    ->where('tenant_id', $lockedOrder->tenant_id)
                    ->where('customer_id', $lockedOrder->customer_id)
                    ->where('status', 'pending')
                    ->orderByDesc('attributed_at')
                    ->orderByDesc('created_at')
                    ->lockForUpdate()
                    ->first();
            }

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
                    'status' => 'calculated',
                    'amount' => $amount,
                    'currency' => $rule->currency,
                    'idempotency_key' => 'commission:'.$lockedOrder->id.':'.$rule->id.':'.$affiliate->id,
                    'payload_hash' => $this->idempotency->payloadHash($payload),
                    'calculated_at' => $now,
                    'approved_by_admin_id' => null,
                    'approved_at' => null,
                    'metadata_json' => $this->jsonOrNull(['source' => 'paid_order']),
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
        return $this->removeMissing([
            'code' => $this->code($payload['code'] ?? $payload['name'] ?? 'program'),
            'name' => $this->stringOrMissing($payload, 'name', $creating),
            'status' => $this->status($payload['status'] ?? 'active'),
            'starts_at' => $this->nullableString($payload['starts_at'] ?? null),
            'ends_at' => $this->nullableString($payload['ends_at'] ?? null),
            'metadata' => is_array($payload['metadata'] ?? null) ? $payload['metadata'] : [],
        ], $payload, $creating, ['code', 'name', 'status', 'starts_at', 'ends_at', 'metadata']);
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
            'customers_count' => Customer::query()->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))->count(),
            'settlements_count' => PartnerSettlement::query()->when($tenantId !== null, fn ($query) => $query->where('tenant_id', $tenantId))->count(),
        ];
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

        foreach ((array) $row as $key => $value) {
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

    private function affiliateAccountResource(object $row, bool $includeCounts = false): array
    {
        $resource = [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'customer_id' => $row->customer_id,
            'code' => (string) $row->code,
            'name' => (string) $row->name,
            'phone' => $row->phone,
            'email' => $row->email,
            'status' => (string) $row->status,
            'wallet_balance' => $this->money((int) $row->wallet_balance_amount, (string) $row->currency),
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
        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'code' => (string) $row->code,
            'name' => (string) $row->name,
            'status' => (string) $row->status,
            'starts_at' => $this->iso($row->starts_at),
            'ends_at' => $this->iso($row->ends_at),
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function affiliateLinkResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'affiliate_program_id' => $row->affiliate_program_id,
            'code' => (string) $row->code,
            'url' => $row->url,
            'status' => (string) $row->status,
            'metadata' => $this->decodeJson($row->metadata_json),
            'created_at' => $this->iso($row->created_at),
            'updated_at' => $this->iso($row->updated_at),
        ];
    }

    private function affiliateAttributionResource(object $row): array
    {
        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
            'affiliate_link_id' => $row->affiliate_link_id,
            'affiliate_program_id' => $row->affiliate_program_id,
            'customer_id' => $row->customer_id,
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

        return [
            'id' => (string) $row->id,
            'tenant_id' => (string) $row->tenant_id,
            'affiliate_id' => (string) $row->affiliate_account_id,
            'affiliate_account_id' => (string) $row->affiliate_account_id,
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

    private function affiliateUrl(string $code): string
    {
        return 'https://newpaotang.local/a/'.$code;
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
