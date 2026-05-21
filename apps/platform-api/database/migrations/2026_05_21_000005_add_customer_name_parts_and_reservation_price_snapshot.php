<?php

use Illuminate\Database\Migrations\Migration;
use Illuminate\Database\Schema\Blueprint;
use Illuminate\Support\Facades\Schema;

return new class extends Migration
{
    public function up(): void
    {
        Schema::table('customers', function (Blueprint $table): void {
            $table->string('first_name')->nullable()->after('name');
            $table->string('last_name')->nullable()->after('first_name');
        });

        Schema::table('stock_reservation_items', function (Blueprint $table): void {
            $table->unsignedBigInteger('price_amount')->nullable()->after('status');
            $table->string('currency', 3)->nullable()->after('price_amount');
            $table->json('sale_price_rule_snapshot_json')->nullable()->after('currency');
        });
    }

    public function down(): void
    {
        Schema::table('stock_reservation_items', function (Blueprint $table): void {
            $table->dropColumn(['price_amount', 'currency', 'sale_price_rule_snapshot_json']);
        });

        Schema::table('customers', function (Blueprint $table): void {
            $table->dropColumn(['first_name', 'last_name']);
        });
    }
};
