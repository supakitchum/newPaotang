<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('customers', 'reward_payout_bank_account_json')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->json('reward_payout_bank_account_json')->nullable()->after('avatar_url');
            });
        }
    }

    public function down(): void
    {
        if (Schema::hasColumn('customers', 'reward_payout_bank_account_json')) {
            Schema::table('customers', function (Blueprint $table): void {
                $table->dropColumn('reward_payout_bank_account_json');
            });
        }
    }
};
