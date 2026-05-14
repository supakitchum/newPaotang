<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('games', function (Blueprint $table): void {
            $table->timestampTz('sale_start_at')->nullable()->after('name');
            $table->index(['status', 'sale_start_at', 'close_at']);
        });

        DB::table('games')
            ->whereNull('sale_start_at')
            ->update(['sale_start_at' => DB::raw('created_at')]);

        Schema::table('partner_quotas', function (Blueprint $table): void {
            $table->timestampTz('sale_start_at')->nullable()->after('allocated_count');
            $table->timestampTz('sale_close_at')->nullable()->after('sale_start_at');
            $table->index(['partner_id', 'game_id', 'sale_start_at', 'sale_close_at'], 'partner_quotas_sale_window_index');
        });
    }

    public function down(): void
    {
        Schema::table('partner_quotas', function (Blueprint $table): void {
            $table->dropIndex('partner_quotas_sale_window_index');
            $table->dropColumn(['sale_start_at', 'sale_close_at']);
        });

        Schema::table('games', function (Blueprint $table): void {
            $table->dropIndex(['status', 'sale_start_at', 'close_at']);
            $table->dropColumn('sale_start_at');
        });
    }
};
