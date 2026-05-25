<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    private const DEFAULT_MINIMUM_PAYOUT_AMOUNT = 30000;
    private const DEFAULT_RULE_AMOUNT = 1000;

    public function up(): void
    {
        if (! Schema::hasColumn('affiliate_programs', 'minimum_payout_amount')) {
            Schema::table('affiliate_programs', function (Blueprint $table): void {
                $table->bigInteger('minimum_payout_amount')->default(self::DEFAULT_MINIMUM_PAYOUT_AMOUNT);
            });
        }

        foreach (DB::table('partner_tenants')->select('id')->orderBy('id')->get() as $tenant) {
            $this->ensureStarterAffiliateDefaults((string) $tenant->id);
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('affiliate_programs', 'minimum_payout_amount')) {
            Schema::table('affiliate_programs', function (Blueprint $table): void {
                $table->dropColumn('minimum_payout_amount');
            });
        }
    }

    private function ensureStarterAffiliateDefaults(string $tenantId): void
    {
        $now = now();
        $programId = $this->stableId('afp', $tenantId.':basic');

        DB::table('affiliate_programs')->insertOrIgnore([
            'id' => $programId,
            'tenant_id' => $tenantId,
            'code' => 'basic',
            'name' => 'Basic Affiliate',
            'status' => 'active',
            'starts_at' => null,
            'ends_at' => null,
            'minimum_payout_amount' => self::DEFAULT_MINIMUM_PAYOUT_AMOUNT,
            'metadata_json' => json_encode(['source' => 'starter_default'], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);

        $resolvedProgramId = DB::table('affiliate_programs')
            ->where('tenant_id', $tenantId)
            ->where('code', 'basic')
            ->value('id');

        if ($resolvedProgramId === null) {
            return;
        }

        DB::table('commission_rules')->insertOrIgnore([
            'id' => $this->stableId('cmr', $tenantId.':basic_com'),
            'tenant_id' => $tenantId,
            'affiliate_program_id' => (string) $resolvedProgramId,
            'affiliate_account_id' => null,
            'code' => 'basic_com',
            'name' => 'BasicCom',
            'rule_type' => 'per_ticket',
            'amount' => self::DEFAULT_RULE_AMOUNT,
            'rate_bps' => 0,
            'currency' => 'THB',
            'status' => 'active',
            'metadata_json' => json_encode(['source' => 'starter_default'], JSON_THROW_ON_ERROR),
            'created_by_admin_id' => null,
            'created_at' => $now,
            'updated_at' => $now,
        ]);
    }

    private function stableId(string $prefix, string $seed): string
    {
        return $prefix.'_'.substr(sha1($seed), 0, 20);
    }
};
