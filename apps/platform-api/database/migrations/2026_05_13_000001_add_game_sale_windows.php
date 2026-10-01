<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\DB;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        if (! Schema::hasColumn('games', 'sale_start_at')) {
            Schema::table('games', function (Blueprint $table): void {
                $table->timestampTz('sale_start_at')->nullable()->after('name');
            });
        }

        DB::table('games')
            ->whereNull('sale_start_at')
            ->update(['sale_start_at' => DB::raw('created_at')]);

        DB::statement('CREATE INDEX IF NOT EXISTS games_sale_window_index ON games (status, sale_start_at, close_at)');

        if (! Schema::hasColumn('partner_quotas', 'sale_start_at')) {
            Schema::table('partner_quotas', function (Blueprint $table): void {
                $table->timestampTz('sale_start_at')->nullable()->after('allocated_count');
            });
        }

        if (! Schema::hasColumn('partner_quotas', 'sale_close_at')) {
            Schema::table('partner_quotas', function (Blueprint $table): void {
                $table->timestampTz('sale_close_at')->nullable()->after('sale_start_at');
            });
        }

        DB::statement('CREATE INDEX IF NOT EXISTS partner_quotas_sale_window_index ON partner_quotas (partner_id, game_id, sale_start_at, sale_close_at)');
    }

    public function down(): void
    {
        DB::statement('DROP INDEX IF EXISTS partner_quotas_sale_window_index');
        DB::statement('DROP INDEX IF EXISTS games_sale_window_index');

        if (Schema::hasColumn('partner_quotas', 'sale_start_at') || Schema::hasColumn('partner_quotas', 'sale_close_at')) {
            Schema::table('partner_quotas', function (Blueprint $table): void {
                $columns = array_values(array_filter([
                    Schema::hasColumn('partner_quotas', 'sale_start_at') ? 'sale_start_at' : null,
                    Schema::hasColumn('partner_quotas', 'sale_close_at') ? 'sale_close_at' : null,
                ]));

                $table->dropColumn($columns);
            });
        }

        if (Schema::hasColumn('games', 'sale_start_at')) {
            Schema::table('games', function (Blueprint $table): void {
                $table->dropColumn('sale_start_at');
            });
        }
    }
};
