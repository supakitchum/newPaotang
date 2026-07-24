<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Carbon;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    /**
     * @var array<int, array{code: string, name: string, rank: int, commission: int, minimum_payout: int}>
     */
    private array $tiers = [
        ['code' => 'bronze', 'name' => 'Bronze', 'rank' => 1, 'commission' => 100, 'minimum_payout' => 30000],
        ['code' => 'silver', 'name' => 'Silver', 'rank' => 2, 'commission' => 150, 'minimum_payout' => 25000],
        ['code' => 'gold', 'name' => 'Gold', 'rank' => 3, 'commission' => 200, 'minimum_payout' => 20000],
        ['code' => 'platinum', 'name' => 'Platinum', 'rank' => 4, 'commission' => 250, 'minimum_payout' => 15000],
        ['code' => 'diamond', 'name' => 'Diamond', 'rank' => 5, 'commission' => 300, 'minimum_payout' => 10000],
    ];

    public function up(): void
    {
        Schema::table('affiliate_programs', function (Blueprint $table): void {
            $table->unsignedSmallInteger('tier_rank')->nullable()->after('status');
            $table->bigInteger('commission_per_ticket_amount')->default(0)->after('minimum_payout_amount');
            $table->index(['tenant_id', 'tier_rank', 'status'], 'affiliate_programs_tier_index');
        });

        Schema::table('affiliate_accounts', function (Blueprint $table): void {
            $table->string('affiliate_program_id', 30)->nullable()->after('customer_id');
            $table->string('store_name_status')->default('approved')->after('name');
            $table->string('store_name_normalized')->nullable()->after('store_name_status');
            $table->timestampTz('store_name_approved_at')->nullable()->after('store_name_normalized');
            $table->timestampTz('store_name_change_available_at')->nullable()->after('store_name_approved_at');
            $table->foreign('affiliate_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->index(['tenant_id', 'store_name_status'], 'affiliate_accounts_store_name_status_index');
            $table->index(['tenant_id', 'affiliate_program_id'], 'affiliate_accounts_program_index');
        });

        Schema::table('commission_transactions', function (Blueprint $table): void {
            $table->unsignedInteger('ticket_count')->nullable()->after('amount');
            $table->string('tier_code')->nullable()->after('ticket_count');
            $table->bigInteger('commission_per_ticket_amount')->nullable()->after('tier_code');
        });

        Schema::create('affiliate_store_name_requests', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('request_type')->default('initial');
            $table->string('previous_name')->nullable();
            $table->string('requested_name');
            $table->string('normalized_name');
            $table->string('status')->default('pending');
            $table->text('admin_note')->nullable();
            $table->string('reviewed_by_admin_id', 30)->nullable();
            $table->timestampTz('submitted_at');
            $table->timestampTz('reviewed_at')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('reviewed_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'submitted_at'], 'affiliate_store_name_requests_status_index');
            $table->index(['tenant_id', 'affiliate_account_id', 'status'], 'affiliate_store_name_requests_account_index');
        });

        Schema::create('affiliate_store_name_claims', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('request_id', 30)->nullable();
            $table->string('normalized_name');
            $table->string('status')->default('pending');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('request_id')->references('id')->on('affiliate_store_name_requests')->nullOnDelete();
            $table->unique(['tenant_id', 'normalized_name'], 'affiliate_store_name_claims_unique');
            $table->index(['tenant_id', 'affiliate_account_id', 'status'], 'affiliate_store_name_claims_account_index');
        });

        Schema::create('affiliate_tier_campaigns', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('name');
            $table->string('campaign_type');
            $table->string('status')->default('draft');
            $table->timestampTz('starts_at');
            $table->timestampTz('ends_at');
            $table->timestampTz('finalized_at')->nullable();
            $table->string('created_by_admin_id', 30)->nullable();
            $table->string('finalized_by_admin_id', 30)->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('created_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->foreign('finalized_by_admin_id')->references('id')->on('admin_users')->nullOnDelete();
            $table->index(['tenant_id', 'status', 'starts_at'], 'affiliate_tier_campaigns_status_index');
            $table->index(['tenant_id', 'ends_at', 'status'], 'affiliate_tier_campaigns_due_index');
        });

        Schema::create('affiliate_tier_campaign_rules', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('campaign_id', 30);
            $table->string('target_program_id', 30);
            $table->unsignedSmallInteger('rule_order')->default(0);
            $table->unsignedInteger('minimum_ticket_count')->nullable();
            $table->unsignedInteger('rank_from')->nullable();
            $table->unsignedInteger('rank_to')->nullable();
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('campaign_id')->references('id')->on('affiliate_tier_campaigns')->cascadeOnDelete();
            $table->foreign('target_program_id')->references('id')->on('affiliate_programs')->restrictOnDelete();
            $table->index(['campaign_id', 'rule_order'], 'affiliate_tier_campaign_rules_order_index');
        });

        Schema::create('affiliate_tier_campaign_stats', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('campaign_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->unsignedInteger('ticket_count')->default(0);
            $table->timestampTz('reached_at')->nullable();
            $table->timestampTz('reconciled_at');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('campaign_id')->references('id')->on('affiliate_tier_campaigns')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->unique(['campaign_id', 'affiliate_account_id'], 'affiliate_tier_campaign_stats_unique');
            $table->index(['tenant_id', 'campaign_id', 'ticket_count'], 'affiliate_tier_campaign_stats_count_index');
        });

        Schema::create('affiliate_tier_campaign_results', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('campaign_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->unsignedInteger('ticket_count')->default(0);
            $table->unsignedInteger('rank')->nullable();
            $table->timestampTz('reached_at')->nullable();
            $table->string('previous_program_id', 30)->nullable();
            $table->string('calculated_program_id', 30)->nullable();
            $table->string('applied_program_id', 30)->nullable();
            $table->string('result_status');
            $table->json('metadata_json')->nullable();
            $table->timestampTz('finalized_at');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('campaign_id')->references('id')->on('affiliate_tier_campaigns')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('previous_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('calculated_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('applied_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->unique(['campaign_id', 'affiliate_account_id'], 'affiliate_tier_campaign_results_unique');
            $table->index(['tenant_id', 'campaign_id', 'rank'], 'affiliate_tier_campaign_results_rank_index');
        });

        Schema::create('affiliate_tier_history', function (Blueprint $table): void {
            $table->string('id', 30)->primary();
            $table->string('tenant_id', 30);
            $table->string('affiliate_account_id', 30);
            $table->string('campaign_id', 30)->nullable();
            $table->string('previous_program_id', 30)->nullable();
            $table->string('new_program_id', 30);
            $table->string('source')->default('campaign');
            $table->unsignedInteger('ticket_count')->default(0);
            $table->unsignedInteger('rank')->nullable();
            $table->json('metadata_json')->nullable();
            $table->timestampTz('effective_at');
            $table->timestampsTz();

            $table->foreign('tenant_id')->references('id')->on('partner_tenants')->cascadeOnDelete();
            $table->foreign('affiliate_account_id')->references('id')->on('affiliate_accounts')->cascadeOnDelete();
            $table->foreign('campaign_id')->references('id')->on('affiliate_tier_campaigns')->nullOnDelete();
            $table->foreign('previous_program_id')->references('id')->on('affiliate_programs')->nullOnDelete();
            $table->foreign('new_program_id')->references('id')->on('affiliate_programs')->restrictOnDelete();
            $table->index(['tenant_id', 'affiliate_account_id', 'effective_at'], 'affiliate_tier_history_account_index');
        });

        $this->seedTiers();
        $this->backfillStoreNames();
    }

    public function down(): void
    {
        Schema::dropIfExists('affiliate_tier_history');
        Schema::dropIfExists('affiliate_tier_campaign_results');
        Schema::dropIfExists('affiliate_tier_campaign_stats');
        Schema::dropIfExists('affiliate_tier_campaign_rules');
        Schema::dropIfExists('affiliate_tier_campaigns');
        Schema::dropIfExists('affiliate_store_name_claims');
        Schema::dropIfExists('affiliate_store_name_requests');

        Schema::table('commission_transactions', function (Blueprint $table): void {
            $table->dropColumn(['ticket_count', 'tier_code', 'commission_per_ticket_amount']);
        });

        Schema::table('affiliate_accounts', function (Blueprint $table): void {
            $table->dropForeign(['affiliate_program_id']);
            $table->dropIndex('affiliate_accounts_store_name_status_index');
            $table->dropIndex('affiliate_accounts_program_index');
            $table->dropColumn([
                'affiliate_program_id',
                'store_name_status',
                'store_name_normalized',
                'store_name_approved_at',
                'store_name_change_available_at',
            ]);
        });

        Schema::table('affiliate_programs', function (Blueprint $table): void {
            $table->dropIndex('affiliate_programs_tier_index');
            $table->dropColumn(['tier_rank', 'commission_per_ticket_amount']);
        });
    }

    private function seedTiers(): void
    {
        $now = now();
        $tenantIds = DB::table('partner_tenants')->pluck('id')->map(fn (mixed $id): string => (string) $id)->all();

        foreach ($tenantIds as $tenantId) {
            $programIds = [];
            foreach ($this->tiers as $tier) {
                $programId = (string) (DB::table('affiliate_programs')
                    ->where('tenant_id', $tenantId)
                    ->where('code', $tier['code'])
                    ->value('id') ?? $this->stableId('afp', $tenantId.':'.$tier['code']));
                $programIds[$tier['code']] = $programId;
                DB::table('affiliate_programs')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'code' => $tier['code']],
                    [
                        'id' => $programId,
                        'name' => $tier['name'],
                        'status' => 'active',
                        'tier_rank' => $tier['rank'],
                        'minimum_payout_amount' => $tier['minimum_payout'],
                        'commission_per_ticket_amount' => $tier['commission'],
                        'starts_at' => null,
                        'ends_at' => null,
                        'metadata_json' => json_encode(['system_tier' => true], JSON_THROW_ON_ERROR),
                        'created_by_admin_id' => null,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ],
                );

                $ruleCode = $tier['code'].'_per_ticket';
                $ruleId = (string) (DB::table('commission_rules')
                    ->where('tenant_id', $tenantId)
                    ->where('code', $ruleCode)
                    ->value('id') ?? $this->stableId('cmr', $tenantId.':'.$ruleCode));
                DB::table('commission_rules')->updateOrInsert(
                    ['tenant_id' => $tenantId, 'code' => $ruleCode],
                    [
                        'id' => $ruleId,
                        'affiliate_program_id' => $programId,
                        'affiliate_account_id' => null,
                        'name' => $tier['name'].' commission per ticket',
                        'rule_type' => 'per_ticket',
                        'amount' => $tier['commission'],
                        'rate_bps' => 0,
                        'currency' => 'THB',
                        'status' => 'active',
                        'metadata_json' => json_encode(['system_tier' => true], JSON_THROW_ON_ERROR),
                        'created_by_admin_id' => null,
                        'created_at' => $now,
                        'updated_at' => $now,
                    ],
                );
            }

            DB::table('commission_rules')
                ->where('tenant_id', $tenantId)
                ->where(function ($query): void {
                    $query->where('rule_type', '!=', 'per_ticket')
                        ->orWhereNotIn('code', array_map(fn (array $tier): string => $tier['code'].'_per_ticket', $this->tiers));
                })
                ->update(['status' => 'archived', 'updated_at' => $now]);
            DB::table('affiliate_programs')
                ->where('tenant_id', $tenantId)
                ->where('code', 'basic')
                ->update(['status' => 'archived', 'updated_at' => $now]);
            DB::table('affiliate_accounts')
                ->where('tenant_id', $tenantId)
                ->update(['affiliate_program_id' => $programIds['bronze'], 'updated_at' => $now]);
            DB::table('affiliate_links')
                ->where('tenant_id', $tenantId)
                ->where('status', 'active')
                ->update(['affiliate_program_id' => $programIds['bronze'], 'updated_at' => $now]);
        }
    }

    private function backfillStoreNames(): void
    {
        $now = now();
        $accounts = DB::table('affiliate_accounts')->orderBy('created_at')->orderBy('id')->get();

        foreach ($accounts as $account) {
            $normalized = $this->normalizeName((string) $account->name);
            $approvedAt = $account->created_at === null ? $now : Carbon::parse($account->created_at);
            $claimed = $normalized !== '' && DB::table('affiliate_store_name_claims')
                ->where('tenant_id', $account->tenant_id)
                ->where('normalized_name', $normalized)
                ->exists();

            if ($normalized !== '' && ! $claimed) {
                DB::table('affiliate_accounts')->where('id', $account->id)->update([
                    'store_name_status' => 'approved',
                    'store_name_normalized' => $normalized,
                    'store_name_approved_at' => $approvedAt,
                    'store_name_change_available_at' => $approvedAt->copy()->addMonthsNoOverflow(3),
                    'updated_at' => $now,
                ]);
                DB::table('affiliate_store_name_claims')->insert([
                    'id' => $this->stableId('asn', (string) $account->tenant_id.':'.$normalized),
                    'tenant_id' => $account->tenant_id,
                    'affiliate_account_id' => $account->id,
                    'request_id' => null,
                    'normalized_name' => $normalized,
                    'status' => 'approved',
                    'created_at' => $now,
                    'updated_at' => $now,
                ]);
                continue;
            }

            $requestId = $this->stableId('asr', (string) $account->tenant_id.':'.(string) $account->id.':migration');
            DB::table('affiliate_accounts')->where('id', $account->id)->update([
                'store_name_status' => 'pending',
                'store_name_normalized' => null,
                'updated_at' => $now,
            ]);
            DB::table('affiliate_store_name_requests')->insertOrIgnore([
                'id' => $requestId,
                'tenant_id' => $account->tenant_id,
                'affiliate_account_id' => $account->id,
                'request_type' => 'initial',
                'previous_name' => null,
                'requested_name' => (string) $account->name,
                'normalized_name' => $normalized,
                'status' => 'pending',
                'admin_note' => $normalized === '' ? 'Store name is empty and requires review.' : 'Duplicate store name found during migration; review is required.',
                'reviewed_by_admin_id' => null,
                'submitted_at' => $approvedAt,
                'reviewed_at' => null,
                'created_at' => $now,
                'updated_at' => $now,
            ]);
        }
    }

    private function normalizeName(string $name): string
    {
        $value = preg_replace('/\s+/u', ' ', trim($name)) ?? trim($name);
        if (class_exists(\Normalizer::class)) {
            $value = \Normalizer::normalize($value, \Normalizer::FORM_KC) ?: $value;
        }

        return defined('MB_CASE_FOLD')
            ? mb_convert_case($value, MB_CASE_FOLD, 'UTF-8')
            : mb_strtolower($value, 'UTF-8');
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
};
