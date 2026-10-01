<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            if (! Schema::hasColumn('customers', 'auto_reward_claim_enabled')) {
                $table->boolean('auto_reward_claim_enabled')->default(false)->after('reward_payout_bank_account_json');
            }

            if (! Schema::hasColumn('customers', 'auto_reward_claim_payout_method')) {
                $table->string('auto_reward_claim_payout_method')->nullable()->after('auto_reward_claim_enabled');
            }
        });
    }

    public function down(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            if (Schema::hasColumn('customers', 'auto_reward_claim_payout_method')) {
                $table->dropColumn('auto_reward_claim_payout_method');
            }

            if (Schema::hasColumn('customers', 'auto_reward_claim_enabled')) {
                $table->dropColumn('auto_reward_claim_enabled');
            }
        });
    }
};
