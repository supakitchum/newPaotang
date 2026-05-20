<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('partner_stock_allocations', function (Blueprint $table): void {
            $table->json('supply_layer_ids_json')->nullable()->after('allocation_percent_basis_points');
        });
    }

    public function down(): void
    {
        Schema::table('partner_stock_allocations', function (Blueprint $table): void {
            $table->dropColumn('supply_layer_ids_json');
        });
    }
};
